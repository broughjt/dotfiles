pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-theme-sync";
  version = "0.4.2";

  src = pkgs.fetchFromGitHub {
    owner = "sherif-fanous";
    repo = "pi-theme-sync";
    rev = "636d1a47fdc9cf424413bfb36ac2581957d6ca3a";
    hash = "sha256-FkvjAFmyPV07jwQ/wwkK30N+X71Kt4x+B9Oqf6DunRI=";
  };

  postPatch = ''
    substituteInPlace src/config.ts \
      --replace-fail 'import type { ExtensionContext } from "@earendil-works/pi-coding-agent";' 'import { type ExtensionContext, getAgentDir } from "@earendil-works/pi-coding-agent";' \
      --replace-fail 'import { homedir } from "node:os";' "" \
      --replace-fail '  global: path.join(homedir(), ".pi", "agent", "theme-sync.json"),' '  global: path.join(getAgentDir(), "theme-sync.json"),'
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r \
      package.json \
      README.md \
      CHANGELOG.md \
      LICENSE \
      src \
      $out/
    runHook postInstall
  '';
}
