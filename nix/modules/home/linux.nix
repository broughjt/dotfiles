{
  homeDirectories,
  homeFish,
  homeGit,
  personal,
}:

{
  config,
  pkgs,
  ...
}:

let
  localDirectory = config.defaultDirectories.localDirectory;
in
{
  imports = [
    personal
    homeDirectories
    homeFish
    homeGit
  ];

  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
  home.homeDirectory = config.defaultDirectories.homeDirectory;

  xdg = {
    enable = true;
    binHome = "${localDirectory}/bin";
    cacheHome = "${localDirectory}/cache";
    configHome = "${localDirectory}/config";
    dataHome = "${localDirectory}/share";
    stateHome = "${localDirectory}/state";
  };

  home.packages = with pkgs; [
    fd
    go-grip
    jq
    killall
    lldb
    ripgrep
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  services.ssh-agent.enable = true;

  # Home Manager's fish module enables man-db cache generation by default so
  # fish can complete `man` topics via `apropos`. That creates a top-level
  # ~/.manpath symlink. Keep man pages available, but skip the per-user man-db
  # cache to avoid the home dotfile.
  programs.man.generateCaches = false;

  programs.git = {
    signing.key = "1BA5F1335AB45105";
    signing.signByDefault = config.programs.gpg.enable;
  };

  home.file."local/secrets/ssh/id_ed25519.pub" = {
    force = true;
    text = config.personal.sshPublicKey + "\n";
  };

  programs.tmux = {
    enable = true;
    sensibleOnTop = true;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    mouse = true;
    historyLimit = 50000;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = yank;
        extraConfig = ''
          set -g @copy_command '${pkgs.wl-clipboard}/bin/wl-copy'
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-dir '${localDirectory}/hacks/tmux/resurrect/resurrect'
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];
  };
}
