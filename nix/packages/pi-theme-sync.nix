pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-theme-sync";
  version = "0.3.1";

  src = pkgs.fetchFromGitHub {
    owner = "sherif-fanous";
    repo = "pi-theme-sync";
    rev = "3670bf8785ee5ce4966fd1bde63f26e39337c22b";
    hash = "sha256-iZnkzR4nW30hTp9v6MpYUjwdS5u09cg2wNWF6xkyLWQ=";
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
