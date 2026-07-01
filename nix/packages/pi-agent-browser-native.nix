pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-agent-browser-native";
  version = "0.2.63";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "4c9cd84125da67fd524d9ad6497fb40785731555";
    hash = "sha256-VfF+FN0UnPfaSP6fkOhxP+fllWTOQrW0RMAqo+OREbE=";
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
