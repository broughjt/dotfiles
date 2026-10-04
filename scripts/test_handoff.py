"""Tests for handoff.py. Run with `python3 -m unittest discover -s scripts`
inside `nix develop`, which provides tomli-w and git."""

from __future__ import annotations

import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

import handoff
from handoff import Check, Outcome


def write_checks(arc: Path, text: str) -> None:
    (arc / handoff.CHECKS).write_text(textwrap.dedent(text))


class LoadChecks(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = Path(tempfile.mkdtemp())
        self.path = self.directory / handoff.CHECKS

    def load(self, text: str) -> list[Check]:
        self.path.write_text(textwrap.dedent(text))
        return handoff.load_checks(self.path)

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
            with self.subTest(text=text), self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
                self.load(text)


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

    def test_output_is_interleaved_and_tailed(self) -> None:
        result = self.run_shell("echo out; echo err >&2; seq 1 100")
        lines = result.output.splitlines()
        self.assertEqual(len(lines), handoff.OUTPUT_LINES)
        self.assertEqual(lines[-1], "100")
        self.assertIn("err", self.run_shell("echo out; echo err >&2").output)

    def test_stdin_is_closed(self) -> None:
        self.assertIs(self.run_shell("read line").outcome, Outcome.FALSE)

    def test_timeout_is_unknown_and_kills_children(self) -> None:
        with tempfile.NamedTemporaryFile() as marker:
            # The subshell outlives bash -c unless the process group is killed.
            result = self.run_shell(
                f"echo started; (sleep 1; echo leaked > {marker.name}) & sleep 30",
                timeout=0.5,
            )
            self.assertIs(result.outcome, Outcome.TIMEOUT)
            self.assertIsNone(result.exit)
            self.assertEqual(result.output, "started")
            subprocess.run(["sleep", "1.5"])
            self.assertEqual(Path(marker.name).read_text(), "")


class Results(unittest.TestCase):
    """Results round-trip through the file and git, and flips are reported."""

    def setUp(self) -> None:
        self.repository = Path(tempfile.mkdtemp())
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "user.name", "test")
        self.arc = self.repository / "arc"
        self.arc.mkdir()
        (self.arc / handoff.START).write_text("")

    def git(self, *arguments: str) -> None:
        subprocess.run(["git", "-C", str(self.repository), *arguments], check=True, capture_output=True)

    def check(self) -> tuple[str, int]:
        arguments = handoff.argparse.Namespace(repository=self.repository, arc=None)
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout), self.assertRaises(SystemExit) as exited:
            handoff.command_check(arguments)
        return stdout.getvalue(), exited.exception.code

    def test_results_round_trip(self) -> None:
        write_checks(
            self.arc,
            """
            [yes]
            claim = "holds"
            run = "echo fine"

            [slow]
            claim = "slow"
            run = "sleep 5"
            timeout = 0.2
            """
        )
        self.assertIsNone(handoff.committed_results(self.repository, "arc"))
        _, code = self.check()
        self.assertEqual(code, 1)
        self.git("add", "-A")
        self.git("commit", "-qm", "results")
        previous = handoff.committed_results(self.repository, "arc")
        self.assertEqual(previous.host, handoff.socket.gethostname())
        self.assertEqual(previous.results["yes"], handoff.Result(Outcome.TRUE, previous.results["yes"].duration, "fine", 0))
        self.assertEqual(previous.results["slow"], handoff.Result(Outcome.TIMEOUT, previous.results["slow"].duration, ""))

    def test_flips_are_reported_against_the_commit(self) -> None:
        write_checks(
            self.arc,
            """
            [regresses]
            claim = "will regress"
            run = "true"

            [recovers]
            claim = "will recover"
            run = "echo broken; exit 1"

            [steady]
            claim = "stays true, output changes"
            run = "date +%N"
            """
        )
        self.check()
        self.git("add", "-A")
        self.git("commit", "-qm", "results")
        write_checks(
            self.arc,
            """
            [regresses]
            claim = "will regress"
            run = "echo now broken; exit 1"

            [recovers]
            claim = "will recover"
            run = "true"

            [steady]
            claim = "stays true, output changes"
            run = "date +%N"

            [added]
            claim = "new"
            run = "true"
            """
        )
        # An uncommitted run in between must not become "previous".
        self.check()
        output, code = self.check()
        self.assertEqual(code, 1)
        self.assertIn("false    regresses", output)
        self.assertIn("was true on", output)
        self.assertIn("now broken", output)
        self.assertIn("true     recovers", output)
        self.assertIn("was false on", output)
        self.assertIn("before:", output)
        self.assertIn("broken", output)
        self.assertIn("new since the last commit", output)
        self.assertNotIn("steady\n         ", output.replace("stays true, output changes", "steady"))

    def test_requires_a_named_arc_when_ambiguous(self) -> None:
        (self.repository / "other").mkdir()
        (self.repository / "other" / handoff.START).write_text("")
        with contextlib.redirect_stderr(io.StringIO()):
            _, code = self.check()
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
