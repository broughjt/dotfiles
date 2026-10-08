"""Tests for handoff.py. Run with `python3 -m unittest discover -s scripts`
inside `nix develop`, which provides Python, bash and git."""

from __future__ import annotations

import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest

import handoff
from handoff import Check, Outcome


def write_checks(arc: Path, text: str) -> None:
    (arc / handoff.CHECKS).write_text(textwrap.dedent(text))


class ParseChecks(unittest.TestCase):
    def load(self, text: str) -> list[Check]:
        return handoff.parse_checks(handoff.tomllib.loads(textwrap.dedent(text)))

    def test_defaults_and_order(self) -> None:
        checks = self.load(
            """
            [second]
            claim = "two"
            run = "true"
            timeout = 5

            [first]
            claim = "one"
            run = "false"
            """
        )
        self.assertEqual([check.id for check in checks], ["second", "first"])
        self.assertEqual(checks[0], Check("second", "two", "true", 5.0))
        self.assertEqual(checks[1].timeout, handoff.DEFAULT_TIMEOUT)

    def test_rejects_bad_entries(self) -> None:
        for text in (
            '[x]\nrun = "true"\n',  # no claim
            '[x]\nclaim = "c"\n',  # no run
            '[x]\nclaim = "c"\nrun = "true"\nexpect = 0\n',  # unknown key
            '[x]\nclaim = "c"\nrun = "true"\ntimeout = 0\n',
            'x = 1\n',  # not a table
            '[x\n',  # not TOML
        ):
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.load(text)

    def test_parser_raises_without_printing(self) -> None:
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr), self.assertRaisesRegex(ValueError, "x: claim"):
            handoff.parse_checks({"x": {"run": "true"}})
        self.assertEqual(stderr.getvalue(), "")


class RunCheck(unittest.TestCase):
    def run_shell(self, run: str, **kwargs) -> handoff.Result:
        return handoff.run_check(Check("x", "claim", run, **kwargs))

    def test_exit_codes(self) -> None:
        self.assertIs(self.run_shell("exit 0").outcome, Outcome.TRUE)
        self.assertIs(self.run_shell("exit 1").outcome, Outcome.FALSE)
        for code in (2, 3, 4, 255):
            result = self.run_shell(f"exit {code}")
            self.assertIs(result.outcome, Outcome.UNKNOWN)
            self.assertEqual(result.exit, code)

    def test_output_is_interleaved_and_preserved(self) -> None:
        result = self.run_shell("echo out; echo err >&2; seq 1 100")
        lines = result.output.splitlines()
        self.assertEqual(lines, ["out", "err", *(str(number) for number in range(1, 101))])
        self.assertTrue(result.output.endswith("100\n"))

    def test_stdin_is_closed(self) -> None:
        self.assertIs(self.run_shell("read line").outcome, Outcome.FALSE)

    def test_timeout_kills_children(self) -> None:
        with tempfile.NamedTemporaryFile() as marker:
            # The subshell outlives bash -c unless the process group is killed.
            result = self.run_shell(
                f"echo started; (sleep 1; echo leaked > {marker.name}) & sleep 30",
                timeout=0.5,
            )
            self.assertIs(result.outcome, Outcome.TIMEOUT)
            self.assertIsNone(result.exit)
            self.assertEqual(result.output, "started\n")
            subprocess.run(["sleep", "1.5"])
            self.assertEqual(Path(marker.name).read_text(), "")


class CheckCommand(unittest.TestCase):
    """Exercise the CLI and verify checks never persist or compare results."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.repository = Path(directory.name)
        subprocess.run(["git", "init", "-q", str(self.repository)], check=True)
        self.arc = self.repository / "arc"
        self.arc.mkdir()
        (self.arc / handoff.START).write_text("")

    def check(self, *arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(Path(handoff.__file__).resolve()),
             "--repository", str(self.repository), "check", *arguments],
            capture_output=True, text=True,
        )

    def snapshot(self) -> dict:
        return {
            str(path.relative_to(self.repository)): path.read_bytes()
            for path in self.repository.rglob("*") if path.is_file()
        }

    def test_reports_all_outcomes_without_writing_or_comparing(self) -> None:
        write_checks(self.arc, '''
            [yes]
            claim = "holds"
            run = "echo hidden"

            [no]
            claim = "does not hold"
            run = "echo failed; exit 1"

            [unknown]
            claim = "cannot observe"
            run = "echo unavailable; exit 3"

            [slow]
            claim = "times out"
            run = "echo waiting; sleep 5"
            timeout = 0.1
        ''')
        for existing_results in (False, True):
            with self.subTest(existing_results=existing_results):
                if existing_results:
                    (self.arc / "results.toml").write_text("deliberately invalid TOML")
                    log = self.arc / "log" / "previous"
                    log.mkdir(parents=True)
                    (log / "results.toml").write_text("also invalid")
                before = self.snapshot()
                for _ in range(2):
                    result = self.check()
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertEqual(result.stdout.splitlines()[0].split(), ["ID", "CLAIM", "RESULT", "DURATION"])
                    self.assertRegex(result.stdout, r"yes\s+holds\s+true\s+\d+\.\ds")
                    self.assertRegex(
                        result.stdout.splitlines()[-1],
                        r"^host: .+, duration: \d+\.\ds, summary: 1 true, 1 false, 1 unknown, 1 timeout$",
                    )
                    for expected in ("true", "false", "unknown", "timeout", "failed",
                                     "unavailable", "waiting", "exit 1", "exit 3", "after 0.1s"):
                        self.assertIn(expected, result.stdout)
                    for absent in ("hidden", "before:", "previous results", "was true", "was false"):
                        self.assertNotIn(absent, result.stdout)
                    self.assertEqual(result.stderr, "")
                    self.assertEqual(self.snapshot(), before)

    def test_success_and_empty_checks(self) -> None:
        for contents in ('[yes]\nclaim = "holds"\nrun = "true"\n', ""):
            with self.subTest(contents=contents):
                write_checks(self.arc, contents)
                result = self.check("arc")
                self.assertEqual(result.returncode, 0, result.stderr)
                if not contents:
                    self.assertIn("no checks", result.stdout)

    def test_report_shows_only_the_output_tail(self) -> None:
        write_checks(self.arc, '[x]\nclaim = "fails"\nrun = "seq 1 100; exit 1"\n')
        result = self.check()
        self.assertEqual(result.returncode, 1, result.stderr)
        output_lines = [line.strip() for line in result.stdout.splitlines() if line.startswith("           ")]
        self.assertEqual(output_lines, [str(number) for number in range(81, 101)])

    def test_arc_selection(self) -> None:
        write_checks(self.arc, "")
        other = self.repository / "other"
        other.mkdir()
        (other / handoff.START).write_text("")
        self.assertEqual(self.check().returncode, 2)
        self.assertEqual(self.check("arc").returncode, 0)
        self.assertEqual(self.check("missing").returncode, 2)

    def test_explicit_check_does_not_require_start(self) -> None:
        write_checks(self.arc, "")
        (self.arc / handoff.START).unlink()
        self.assertEqual(self.check("arc").returncode, 0)
        self.assertEqual(self.check().returncode, 2)

    def test_missing_or_invalid_checks(self) -> None:
        result = self.check()
        self.assertEqual(result.returncode, 2)
        self.assertIn("checks.toml", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        write_checks(self.arc, "[broken")
        result = self.check()
        self.assertEqual(result.returncode, 2)
        self.assertNotIn("Traceback", result.stderr)

    def test_invalid_timeout_is_a_usage_error(self) -> None:
        for timeout in ("true", "nan", "inf", "-inf", "0", "-1"):
            with self.subTest(timeout=timeout):
                write_checks(self.arc, f'[x]\nclaim = "holds"\nrun = "true"\ntimeout = {timeout}\n')
                result = self.check()
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("timeout must be", result.stderr)


class Lint(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.repository = Path(directory.name)
        subprocess.run(["git", "init", "-q", str(self.repository)], check=True)
        self.arc = self.repository / "arc"
        self.arc.mkdir()
        for name in handoff.STATE_FILES:
            (self.arc / name).write_text("")
        # This command must never execute during lint.
        write_checks(self.arc, '[x]\nclaim = "example"\nrun = "touch SHOULD_NOT_EXIST"\n')

    def lint(self, *arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(Path(handoff.__file__).resolve()),
             "--repository", str(self.repository), "lint", *arguments],
            cwd=self.arc, capture_output=True, text=True,
        )

    def checkpoint(self, name: str, results: str = "") -> Path:
        entry = self.arc / "log" / name
        entry.mkdir(parents=True)
        (entry / "entry.md").write_text("checkpoint")
        (entry / "results.toml").write_text(results)
        return entry

    def test_new_arc_is_valid_and_read_only(self) -> None:
        before = {p.relative_to(self.arc): p.read_bytes() for p in self.arc.rglob("*") if p.is_file()}
        result = self.lint()
        self.assertEqual(result.returncode, 0, result.stderr)
        after = {p.relative_to(self.arc): p.read_bytes() for p in self.arc.rglob("*") if p.is_file()}
        self.assertEqual(before, after)

    def test_reports_multiple_defects_including_missing_start(self) -> None:
        (self.arc / "start.md").unlink()
        (self.arc / "arc.md").unlink()
        (self.arc / "arc.md").mkdir()
        write_checks(self.arc, '[x]\nrun = "true"\n')
        entry = self.checkpoint("1", "[broken")
        (entry / "entry.md").unlink()
        result = self.lint("arc")
        self.assertEqual(result.returncode, 1, result.stderr)
        for text in ("start.md", "arc.md", "checks.toml", "entry.md", "results.toml", "5 lint errors"):
            self.assertIn(text, result.stdout)
        self.assertNotIn("Traceback", result.stderr)

    def test_incomplete_latest_checkpoint_is_not_ignored(self) -> None:
        self.checkpoint("1")
        latest = self.checkpoint("2")
        (latest / "results.toml").unlink()
        diagnostics = handoff.lint_arc(self.arc)
        self.assertEqual([d.path for d in diagnostics], [latest / "results.toml"])

    def test_canonical_checkpoint_names(self) -> None:
        self.checkpoint("1")
        self.checkpoint("10")
        invalid = ("01", "0001", "0", "yesterday", "١", "²", "-1")
        for name in invalid:
            self.checkpoint(name)
        (self.arc / "log" / "2").write_text("")
        diagnostics = handoff.lint_arc(self.arc)
        self.assertEqual({d.path.name for d in diagnostics}, {*invalid, "2"})

    def test_log_must_be_a_directory(self) -> None:
        (self.arc / "log").write_text("")
        self.assertEqual(self.lint().returncode, 1)

    def test_explicit_arc_cannot_escape_repository(self) -> None:
        for name in ("..", ".git", "../arc", str(self.arc)):
            with self.subTest(name=name):
                self.assertEqual(self.lint(name).returncode, 2)

    def test_repository_detection_supports_worktrees_and_rejects_subdirectories(self) -> None:
        self.assertTrue(handoff.is_git_repository(self.repository))
        self.assertFalse(handoff.is_git_repository(self.arc))
        subprocess.run(
            ["git", "-C", str(self.repository), "-c", "user.name=Test",
             "-c", "user.email=test@example.com", "commit", "--allow-empty", "-qm", "Initialize"],
            check=True,
        )
        worktree = self.repository / "linked"
        subprocess.run(
            ["git", "-C", str(self.repository), "worktree", "add", "--detach", str(worktree)],
            check=True, capture_output=True,
        )
        self.assertTrue((worktree / ".git").is_file())
        self.assertTrue(handoff.is_git_repository(worktree))


if __name__ == "__main__":
    unittest.main()
