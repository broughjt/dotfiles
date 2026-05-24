{
  runCommand,
  todoist-cli,
}:

runCommand "todoist-cli-pi-skill-${todoist-cli.version}" { } ''
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"

  work="$TMPDIR/work"
  mkdir -p "$work"
  cd "$work"

  ${todoist-cli}/bin/td skill install pi --local >/dev/null

  install -D -m 0444 \
    .pi/skills/todoist-cli/SKILL.md \
    "$out/skills/todoist-cli/SKILL.md"
''
