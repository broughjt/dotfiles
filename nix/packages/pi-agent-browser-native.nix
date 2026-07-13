pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-agent-browser-native";
  version = "0.2.66";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "67488b0ebf450157abd6be01e5bcfc80c4c5c615";
    hash = "sha256-Y7GYq41kIrBIhPiZ8e2TtonVgte1n4LmFJsvot0FHB8=";
  };

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-5d8TMEL0SweGB73yefa+dhyMAIiSY4YjD9dcgCuhxcI=";
  postPatch = ''
    cp ${../../pi/pi-agent-browser-native-package-lock.json} package-lock.json
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/scripts
    cp scripts/config.mjs scripts/doctor.mjs $out/scripts/
    cp -r \
      dist \
      platform-smoke.config.mjs \
      package.json \
      README.md \
      CHANGELOG.md \
      LICENSE \
      docs \
      $out/
    runHook postInstall
  '';
}
