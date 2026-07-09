pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-agent-browser-native";
  version = "0.2.65";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "5b274b6c3a0779a7e17aec0ae72e491b08572a56";
    hash = "sha256-fKPhQNGoXtJkdyP4JGzeVAG5YKdMISJPiiD4FFJFGhk=";
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
