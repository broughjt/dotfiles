{
  config,
  lib,
  pkgs,
  ...
}:

let
  agentInstructions = import ../../packages/agent-instructions.nix;
  claudeCodePackage = pkgs.callPackage ../../packages/claude-code.nix { };
  spriteHomeManagerPackage = pkgs.writeShellScriptBin "home-manager" ''
    export USER="''${USER:-$(${pkgs.coreutils}/bin/id -un)}"
    exec ${config.programs.home-manager.package}/bin/home-manager "$@"
  '';

  instructionsSource = agentInstructions.assembleAgentInstructions {
    inherit pkgs;
    machine = ../../../agents/machines/sprite.md;
  };
  upstreamInstructions = ../../../agents/machines/upstream/codex-agents.md;

  skillsSource = builtins.path {
    name = "skills";
    path = ../../../agents/skills;
  };
  skillNames = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsSource)
  );
  skillFiles = lib.listToAttrs (
    lib.concatMap (
      name:
      map
        (agent: {
          name = ".${agent}/skills/${name}";
          value.source = skillsSource + "/${name}";
        })
        [
          "claude"
          "codex"
        ]
    ) skillNames
  );
in
{
  # Sprites have no systemd user manager.
  systemd.user.enable = false;

  personal.userName = "sprite";

  home = {
    username = "sprite";
    homeDirectory = "/home/sprite";
    stateVersion = "26.05";
    packages = [ claudeCodePackage ];
    sessionPath = [ "${config.home.profileDirectory}/bin" ];

    # sprite exec reads no shell startup files, but ~/.local/bin is already on
    # its fixed PATH. Expose the two Nix-managed entry points needed there.
    file = skillFiles // {
      ".local/bin/claude" = {
        force = true;
        source = "${claudeCodePackage}/bin/claude";
      };
      ".local/bin/home-manager".source = "${spriteHomeManagerPackage}/bin/home-manager";

      ".claude/CLAUDE.md" = {
        force = true;
        source = instructionsSource;
      };
      ".codex/AGENTS.md" = {
        force = true;
        source = instructionsSource;
      };
    };
  };

  xdg.enable = true;
  programs.home-manager.enable = true;

  # Home Manager's Fish module enables man-db cache generation by default,
  # which would create a top-level ~/.manpath symlink merely for completions.
  programs.man.generateCaches = false;

  # The automatic generators execute Fish once per installed package. In an
  # unsandboxed single-user Nix build, Fish creates its XDG tree at Nix's
  # synthetic HOME=/homeless-shelter on the sprite's real root filesystem;
  # the next stdenv build then refuses that impurity. Package-provided Fish
  # completions remain available without these man-page-derived completions.
  programs.fish.generateCompletions = false;

  # Fly owns the stock config.fish, but it contains only its prompt, colours,
  # and opt-in language-manager environment. The Nix-first sprite profile
  # deliberately replaces it with the shared Home Manager Fish module.
  xdg.configFile."fish/config.fish".force = true;

  # Verify the base image text before the forced Home Manager link replaces
  # it. A managed symlink on subsequent generations has already passed this
  # check on its first activation.
  home.activation.checkSpriteInstructions = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    instructions="$HOME/.codex/AGENTS.md"
    if [[ ! -L "$instructions" ]]; then
      if [[ ! -f "$instructions" ]]; then
        echo "error: expected the sprite base image's instructions at $instructions" >&2
        exit 1
      fi
      if ! cmp -s ${lib.escapeShellArg upstreamInstructions} "$instructions"; then
        diff -u ${lib.escapeShellArg upstreamInstructions} "$instructions" >&2 || true
        echo "error: the sprite base image's instructions have changed; update the vendored copy first" >&2
        exit 1
      fi
    fi
  '';

  # Fly's stock identity lives here. Git otherwise reads both this legacy
  # global file and Home Manager's $XDG_CONFIG_HOME/git/config.
  home.activation.removeLegacyGitConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run rm -f "$HOME/.gitconfig"
  '';
}
