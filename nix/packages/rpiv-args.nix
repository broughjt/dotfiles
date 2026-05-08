pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "rpiv-args";
  version = "1.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "juicesharp";
    repo = "rpiv-mono";
    rev = "917af977a95ea1f30784e123c464f80a86ed28b5";
    hash = "sha256-YqA/weruyA4Pyz0z64iZJG3C15FLNOuY0TDDQTr65zc=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r \
      packages/rpiv-args/package.json \
      packages/rpiv-args/README.md \
      packages/rpiv-args/LICENSE \
      packages/rpiv-args/index.ts \
      packages/rpiv-args/args.ts \
      $out/
    runHook postInstall
  '';
}
