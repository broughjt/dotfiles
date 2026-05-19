{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  homeManagerUser = config.home-manager.users.${user};
  kakConfigPath = homeManagerUser.xdg.configFile."kak/kakrc".source;
  kakInitCommand = "source ${pkgs.kakoune}/share/kak/kakrc; source ${kakConfigPath}";

  # Keep Kakoune's Home Manager-rendered config store-backed. Kakoune has no
  # direct --config flag, so the wrapper skips default startup, explicitly loads
  # the normal runtime bootstrap, then loads the generated config from
  # /nix/store.  The runtime bootstrap still provides Kakoune's standard
  # autoload/colorscheme behavior. Disabling the XDG kakrc symlink below
  # prevents it from re-sourcing the generated config through
  # $XDG_CONFIG_HOME/kak/kakrc.
  kakounePackage = pkgs.symlinkJoin {
    name = "kakoune-store-backed-config";
    paths = [ pkgs.kakoune ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/kak" \
        --add-flags "-n" \
        --add-flags ${lib.escapeShellArg "-E ${lib.escapeShellArg kakInitCommand}"}
    '';
  };
in
{
  home-manager.users.${user} = {
    home.packages = [
      kakounePackage
      pkgs.kakoune-lsp
    ];

    programs.kakoune = {
      enable = true;
      package = null;
      extraConfig = ''
        eval %sh{kak-lsp}
        lsp-enable

        map global user l ':enter-user-mode lsp<ret>' -docstring 'LSP mode'

        map global goto d <esc>:lsp-definition<ret> -docstring 'LSP definition'
        map global goto r <esc>:lsp-references<ret> -docstring 'LSP references'
        map global goto y <esc>:lsp-type-definition<ret> -docstring 'LSP type definition'

        map global insert <tab> '<a-;>:try lsp-snippets-select-next-placeholders catch %{ execute-keys -with-hooks <lt>tab> }<ret>' -docstring 'Select next snippet placeholder'

        map global object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
        map global object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
        map global object f '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
        map global object t '<a-semicolon>lsp-object Class Interface Module Namespace Struct<ret>' -docstring 'LSP class or module'
        map global object d '<a-semicolon>lsp-diagnostic-object error warning<ret>' -docstring 'LSP errors and warnings'
        map global object D '<a-semicolon>lsp-diagnostic-object error<ret>' -docstring 'LSP errors'
      '';
    };

    # The wrapper above reads this generated file directly from the Nix store.
    xdg.configFile."kak/kakrc".enable = false;
  };
}
