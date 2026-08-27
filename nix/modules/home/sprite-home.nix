{
  config,
  lib,
  pkgs,
  ...
}:

let
  agentInstructions = import ../../packages/agent-instructions.nix;
  claudeCodePackage = pkgs.callPackage ../../packages/claude-code.nix { };
  codexPackage = pkgs.callPackage ../../packages/codex.nix { };
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

  # Entries that must beat the profile symlink farm below. The wrapper is the
  # only one: a direct in-sprite `home-manager switch` needs the synthesized
  # USER that the profile's own home-manager does not set.
  localBinFiles = {
    ".local/bin/home-manager".source = "${spriteHomeManagerPackage}/bin/home-manager";
  };
  managedLocalBinNames = map (lib.removePrefix ".local/bin/") (lib.attrNames localBinFiles);
in
{
  # Sprites have no systemd user manager.
  systemd.user.enable = false;

  personal.userName = "sprite";

  home = {
    username = "sprite";
    homeDirectory = "/home/sprite";
    stateVersion = "26.05";
    packages = [
      claudeCodePackage
      codexPackage
      # Left unwrapped, and ~/.config/gh deliberately unmanaged, so `gh auth
      # login` can write both config.yml and hosts.yml. murph's wrapper exists
      # to keep the token in its keyring and hosts.yml in ~/local/hacks;
      # a sprite has neither, and its authentication is manual per sprite.
      pkgs.gh
    ];
    sessionPath = [ "${config.home.profileDirectory}/bin" ];

    file =
      skillFiles
      // localBinFiles
      // {
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

  # Nothing hooks direnv into `sprite exec`, which runs no shell startup files.
  # This serves interactive sessions and anything invoking `direnv exec`; an
  # agent still enters a project's toolchain with `nix develop -c`.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

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

  # sprite exec hands agents a fixed PATH of ~/.local/bin, /.sprite/bin, then
  # the system directories, and reads no shell startup files, so nothing in the
  # Nix profile is reachable from it. Linking the profile's bin directory into
  # ~/.local/bin exposes these packages to agents and, because ~/.local/bin
  # comes first, shadows the base image's /.sprite/bin shims for every name Nix
  # provides. That replaces deleting anything from Fly's root-owned tree, whose
  # contents the platform may restore.
  home.activation.linkProfileBinaries = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    profileBin=${lib.escapeShellArg "${config.home.profileDirectory}/bin"}
    localBin="$HOME/.local/bin"

    run mkdir -p "$localBin"

    for target in "$profileBin"/*; do
      if [[ ! -e "$target" ]]; then
        continue
      fi
      name="$(basename "$target")"
      # Names declared through home.file own themselves.
      case " ${lib.concatStringsSep " " managedLocalBinNames} " in
        *" $name "*) continue ;;
      esac
      run ln -sfnT "$target" "$localBin/$name"
    done

    # Drop links for names the profile no longer provides. A dangling link into
    # the profile can only have been left by an earlier run of this farm.
    for link in "$localBin"/*; do
      if [[ ! -L "$link" ]]; then
        continue
      fi
      case "$(readlink "$link")" in
        "$profileBin"/*)
          if [[ ! -e "$link" ]]; then
            run rm -f "$link"
          fi
          ;;
      esac
    done
  '';

  # Fly's stock identity lives here. Git otherwise reads both this legacy
  # global file and Home Manager's $XDG_CONFIG_HOME/git/config.
  home.activation.removeLegacyGitConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run rm -f "$HOME/.gitconfig"
  '';
}
