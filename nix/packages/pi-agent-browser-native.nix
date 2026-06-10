pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-agent-browser-native";
  version = "0.2.46";

  src = pkgs.fetchFromGitHub {
    owner = "fitchmultz";
    repo = "pi-agent-browser-native";
    rev = "6ea72bdb407b324977bc8e402e4d0576dbf36c1b";
    hash = "sha256-s7ZzcfxGITvO87cqSExHpAXrHGp47UkDQAYgkEJROBE=";
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
