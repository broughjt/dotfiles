{ config, pkgs, ... }:

{
  home-manager.users.${config.personal.userName} = {
    home.packages = with pkgs; [
      kakoune-lsp
    ];

    programs.kakoune = {
      enable = true;
      colorSchemePackage = pkgs.writeText "ibm-5153-cga-black.kak" ''
        set-face global Default rgb:c4c4c4,rgb:000000
        set-face global PrimarySelection rgb:000000,rgb:c4c4c4
        set-face global SecondarySelection rgb:000000,rgb:4e4e4e
        set-face global PrimaryCursor rgb:000000,rgb:c4c4c4+b
        set-face global SecondaryCursor rgb:000000,rgb:4e4e4e+b
        set-face global LineNumbers rgb:4e4e4e,rgb:000000
        set-face global LineNumberCursor rgb:ffffff,rgb:000000+b
        set-face global MenuForeground rgb:000000,rgb:c4c4c4
        set-face global MenuBackground rgb:c4c4c4,rgb:000000
        set-face global MenuInfo rgb:4ef3f3,rgb:000000
        set-face global Information rgb:000000,rgb:4ef3f3
        set-face global Error rgb:000000,rgb:dc4e4e
        set-face global DiagnosticError rgb:dc4e4e,rgb:000000
        set-face global DiagnosticWarning rgb:f3f34e,rgb:000000
        set-face global DiagnosticHint rgb:4ef3f3,rgb:000000
        set-face global DiagnosticInfo rgb:4e4edc,rgb:000000
        set-face global StatusLine rgb:000000,rgb:c4c4c4
        set-face global StatusLineMode rgb:000000,rgb:f3f34e+b
        set-face global StatusLineInfo rgb:000000,rgb:4ef3f3
        set-face global StatusLineValue rgb:000000,rgb:4edc4e
        set-face global StatusCursor rgb:000000,rgb:c4c4c4
        set-face global Prompt rgb:000000,rgb:c4c4c4+b
        set-face global MatchingChar rgb:000000,rgb:f3f34e
        set-face global Search rgb:000000,rgb:f3f34e
        set-face global Whitespace rgb:4e4e4e,rgb:000000
        set-face global BufferPadding rgb:4e4e4e,rgb:000000

        set-face global value rgb:4edc4e,rgb:000000
        set-face global type rgb:4ef3f3,rgb:000000
        set-face global variable rgb:c4c4c4,rgb:000000
        set-face global module rgb:4e4edc,rgb:000000
        set-face global function rgb:f34ef3,rgb:000000
        set-face global string rgb:4edc4e,rgb:000000
        set-face global keyword rgb:dc4e4e,rgb:000000+b
        set-face global operator rgb:f3f34e,rgb:000000
        set-face global attribute rgb:4ef3f3,rgb:000000
        set-face global comment rgb:4e4e4e,rgb:000000+i
        set-face global documentation rgb:4e4e4e,rgb:000000+i
        set-face global meta rgb:c47e00,rgb:000000
        set-face global builtin rgb:4e4edc,rgb:000000+b

        set-face global title rgb:4e4edc,rgb:000000+b
        set-face global header rgb:f34ef3,rgb:000000+b
        set-face global mono rgb:4edc4e,rgb:000000
        set-face global block rgb:c4c4c4,rgb:4e4e4e
        set-face global link rgb:4ef3f3,rgb:000000+u
        set-face global bullet rgb:dc4e4e,rgb:000000
        set-face global list rgb:c4c4c4,rgb:000000
      '';
      config.colorScheme = "ibm-5153-cga-black";
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
  };
}
