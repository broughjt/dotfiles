pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "rpiv-todo";
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
      packages/rpiv-todo/package.json \
      packages/rpiv-todo/README.md \
      packages/rpiv-todo/LICENSE \
      packages/rpiv-todo/index.ts \
      packages/rpiv-todo/todo.ts \
      packages/rpiv-todo/todo-overlay.ts \
      packages/rpiv-todo/locales \
      packages/rpiv-todo/state \
      packages/rpiv-todo/tool \
      packages/rpiv-todo/view \
      $out/
    runHook postInstall
  '';
}
