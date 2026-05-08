pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "rpiv-pi";
  version = "1.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "juicesharp";
    repo = "rpiv-mono";
    rev = "917af977a95ea1f30784e123c464f80a86ed28b5";
    hash = "sha256-YqA/weruyA4Pyz0z64iZJG3C15FLNOuY0TDDQTr65zc=";
  };

  patches = [ ./rpiv-pi-web-minimal.patch ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r \
      packages/rpiv-pi/package.json \
      packages/rpiv-pi/README.md \
      packages/rpiv-pi/LICENSE \
      packages/rpiv-pi/extensions \
      packages/rpiv-pi/skills \
      packages/rpiv-pi/agents \
      packages/rpiv-pi/scripts \
      $out/
    runHook postInstall
  '';
}
