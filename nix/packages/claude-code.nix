{
  lib,
  pkgs,
  oauthTokenFile ? null,
}:

let
  agentToolPath = lib.makeBinPath [
    pkgs.python3
  ];
  # `claude setup-token` mints a long-lived token intended for headless
  # machines. Read a file containing the token.
  #
  # The -r guard means a missing file falls back to ordinary interactive
  # authentication instead of breaking claude, and exporting from a wrapper
  # rather than a shell profile keeps it working for non-interactive invocations
  # like `ssh case1 claude -p ...`.
  oauthTokenWrapperArgs = lib.optionalString (oauthTokenFile != null) ''
    --run ${lib.escapeShellArg ''
      if [ -r ${lib.escapeShellArg oauthTokenFile} ]; then
        CLAUDE_CODE_OAUTH_TOKEN=$(cat ${lib.escapeShellArg oauthTokenFile})
        export CLAUDE_CODE_OAUTH_TOKEN
      fi
    ''} \
  '';
in
pkgs.symlinkJoin {
  name = "claude-code-agent-tools";
  paths = [ pkgs.llm-agents.claude-code ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    rm -f "$out/bin/claude"
    makeWrapper ${pkgs.llm-agents.claude-code}/bin/claude "$out/bin/claude" \
      --prefix PATH : ${lib.escapeShellArg agentToolPath} \
      ${oauthTokenWrapperArgs}--add-flags --dangerously-skip-permissions
  '';
}
