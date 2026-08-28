rec {
  caches = {
    numtide = {
      substituter = "https://cache.numtide.com";
      publicKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
    };
    nixCommunity = {
      substituter = "https://nix-community.cachix.org";
      publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    };
    nixos = {
      substituter = "https://cache.nixos.org";
      publicKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
    };
  };

  nixSettings = {
    accept-flake-config = true;
    use-xdg-base-directories = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = with caches; [
      numtide.substituter
      nixos.substituter
      nixCommunity.substituter
    ];
    trusted-public-keys = with caches; [
      numtide.publicKey
      nixos.publicKey
      nixCommunity.publicKey
    ];
  };

  nixpkgsConfig = {
    allowUnfree = true;
  };

}
