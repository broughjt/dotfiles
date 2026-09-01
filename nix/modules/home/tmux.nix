{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.tmux;
in
{
  options.programs.tmux = {
    resurrectDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/tmux/resurrect";
      defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/tmux/resurrect"'';
      description = "Directory where tmux-resurrect stores saved sessions.";
    };

    copyCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Command tmux-yank pipes copied text into. Reaching the system clipboard
        is a property of the graphical session rather than of tmux, so the
        profile that owns the session selects this. When null, tmux-yank falls
        back to its own platform detection.
      '';
    };
  };

  config.programs.tmux = {
    enable = true;
    sensibleOnTop = true;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    mouse = true;
    historyLimit = 50000;
    terminal = "tmux-256color";
    extraConfig = ''
      # Preserve modified keys such as Shift-Enter through supporting terminals.
      set -s extended-keys on
      set -s extended-keys-format csi-u
      set -as terminal-features 'xterm*:extkeys'
    '';
    plugins = with pkgs.tmuxPlugins; [
      (
        if cfg.copyCommand == null then
          yank
        else
          {
            plugin = yank;
            extraConfig = ''
              set -g @copy_command '${cfg.copyCommand}'
            '';
          }
      )
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-dir '${cfg.resurrectDirectory}'
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
