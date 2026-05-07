pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-web-minimal";
  version = "0.4.0";

  src = pkgs.fetchFromGitHub {
    owner = "drsh4dow";
    repo = "pi-web-minimal";
    rev = "2927328def03d8b908a3f7e1b64e524434aa2ff7";
    hash = "sha256-RpUi4y3WhCpliFfim7G2xryCEuf+eV0sy0mVMdVT80c=";
  };

  npmDepsHash = "sha256-6rV/tLQR5SKd9zqnJ+DACSYfTzTYqzFDdnxmonxRVvk=";
  postPatch = ''
    cp ${../../pi/pi-web-minimal-package-lock.json} package-lock.json
  '';
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r package.json README.md index.ts extensions lib node_modules $out/
    runHook postInstall
  '';
}
