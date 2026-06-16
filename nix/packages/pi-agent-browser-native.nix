pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-agent-browser-native";
  version = "0.2.51";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "b2ff7637f8c0ae4a680719b37cd9b7c44fc03780";
    hash = "sha256-HwgT/hCKSLZGWXVzAEp/Bi46URSuzU34E7MqFYLmnxo=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r \
      extensions \
      scripts \
      docs \
      platform-smoke.config.mjs \
      package.json \
      README.md \
      CHANGELOG.md \
      LICENSE \
      $out/
    runHook postInstall
  '';
}
