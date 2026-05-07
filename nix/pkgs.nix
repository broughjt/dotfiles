{
  nixpkgs,
  emacs-overlay,
  llm-agents-nix,
}:

system:

import nixpkgs {
  inherit system;
  overlays = [
    llm-agents-nix.overlays.default
  ]
  ++ (with emacs-overlay.overlays; [
    emacs
    package
  ]);
  config.allowUnfree = true;
}
