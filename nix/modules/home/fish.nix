{ pkgs, ... }:

{
  home.packages = with pkgs; [ eza ];

  programs.fish = {
    enable = true;
    interactiveShellInit = "fish_vi_key_bindings";
    shellAliases.ls = "eza --group-directories-first";
  };
}
