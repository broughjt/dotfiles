pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-agent-browser-native";
  version = "0.2.72";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "211a012c9b199d758768e8ba729f35e11e661f65";
    hash = "sha256-LMVvFkxiDN90lcTX54FmrwM0N/lLV+IJaCWzveHqpm8=";
  };

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-l1MzXUkhrp2u5LcWEJHMtcQbRFCKpxQgjSL5PlxFiBI=";
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
