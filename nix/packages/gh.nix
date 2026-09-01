{
  lib,
  pkgs,
  tokenFile ? null,
}:

# gh reads GH_TOKEN in preference to any stored credential. Upstream documents
# `gh auth login --with-token` as taking a classic token and recommends GH_TOKEN
# for fine-grained ones, whose per-resource scoping otherwise confuses commands
# that touch anything outside the token's repositories.
#
# The -r guard means a missing file falls back to gh's ordinary stored
# credentials, and wrapping the binary rather than exporting from a shell
# profile keeps the token visible to non-interactive invocations -- including
# the git credential helper, which is how HTTPS pushes authenticate.
if tokenFile == null then
  pkgs.gh
else
  pkgs.symlinkJoin {
    name = "gh-with-token";
    paths = [ pkgs.gh ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/gh"
      makeWrapper ${pkgs.gh}/bin/gh "$out/bin/gh" \
        --run ${lib.escapeShellArg ''
          if [ -r ${lib.escapeShellArg tokenFile} ]; then
            GH_TOKEN=$(cat ${lib.escapeShellArg tokenFile})
            export GH_TOKEN
          fi
        ''}
    '';
    # symlinkJoin does not inherit meta from `paths`, so the wrapper loses gh's
    # mainProgram. `programs.gh.gitCredentialHelper` resolves the package with
    # `lib.getExe`, which warns and falls back to guessing without it.
    meta = pkgs.gh.meta;
  }
