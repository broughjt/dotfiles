pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-agent-browser-native";
  version = "0.2.42";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "6a1e387bcf4e7c11a0a0610a359f2d592a099532";
    hash = "sha256-4LPhHMF0szO3Z8b2h2o+d740Sa76XrV61s08gSIYE7g=";
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
