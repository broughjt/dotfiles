pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-theme-sync";
  version = "0.3.0";

  src = pkgs.fetchFromGitHub {
    owner = "sherif-fanous";
    repo = "pi-theme-sync";
    rev = "550c1dde8c737461415f1d4c1c4142afefaa3f0c";
    hash = "sha256-4CGv5W2WRU6dQzDt9yaA5U+97M8eVYbw0qd7dM1WcG0=";
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
