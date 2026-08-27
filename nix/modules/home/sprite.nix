{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;

  # sprite hardcodes $HOME/.sprites and has no environment variable to relocate
  # it, so give it a private HOME the way browser-tools.nix does for
  # agent-browser rather than creating a ~/.sprites dotfile. Only the .sprites
  # subtree is persisted; see murph-user-persistence.nix.
  spriteStateDir = "${localDirectory}/state/sprite";
  spriteHomeDir = "${spriteStateDir}/home";
  spriteConfigDir = "${spriteHomeDir}/.sprites";

  # nixpkgs ships the binary without shell completions even though it can
  # generate them. Generating them here rather than through overrideAttrs
  # avoids pkgs.sprite's custom installPhase, which never runs postInstall.
  # sprite creates its config directory on any invocation, so give the
  # generator a throwaway HOME.
  spritePackage = pkgs.symlinkJoin {
    name = "sprite-local-state";
    paths = [ pkgs.sprite ];
    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.installShellFiles
    ];
    postBuild = ''
      rm -f "$out/bin/sprite"
      makeWrapper ${pkgs.sprite}/bin/sprite "$out/bin/sprite" \
        --set HOME ${lib.escapeShellArg spriteHomeDir}

      export HOME=$(mktemp -d)
      installShellCompletion --cmd sprite \
        --fish <(${pkgs.sprite}/bin/sprite completion fish)
    '';
  };
in
{
  system.activationScripts.prepareSpriteState = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg spriteStateDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg spriteHomeDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg spriteConfigDir}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${spriteStateDir} 0700 ${user} users -"
    "d ${spriteHomeDir} 0700 ${user} users -"
    "d ${spriteConfigDir} 0700 ${user} users -"
  ];

  home-manager.users.${user}.home.packages = [ spritePackage ];
}
