pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "rpiv-ask-user-question";
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
      packages/rpiv-ask-user-question/package.json \
      packages/rpiv-ask-user-question/README.md \
      packages/rpiv-ask-user-question/LICENSE \
      packages/rpiv-ask-user-question/index.ts \
      packages/rpiv-ask-user-question/ask-user-question.ts \
      packages/rpiv-ask-user-question/locales \
      packages/rpiv-ask-user-question/state \
      packages/rpiv-ask-user-question/tool \
      packages/rpiv-ask-user-question/view \
      $out/
    runHook postInstall
  '';
}
