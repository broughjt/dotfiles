pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-agent-browser-native";
  version = "0.5.0";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "fc051c4542fdad78b5a84b72919ee73966d8e71f";
    hash = "sha256-Cn/2cQOyGZPnHTgydxrqVvwzAHoiqvLpmj9P6TbqQe0=";
  };

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-KiNtXRrCJad6yYiSMIPh9rrvOIuOJ9ejNZE/CJ/8hOc=";
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
