pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-web-minimal";
  version = "0.5.0";

  src = pkgs.fetchFromGitHub {
    owner = "drsh4dow";
    repo = "pi-web-minimal";
    rev = "4c97e90233cfbfa34dfdb4961a7470dbbb99b830";
    hash = "sha256-9sWKhcv3moy6jZMJQ4XArotUrMzScXZf1h7mRTprN70=";
  };

  npmDepsHash = "sha256-LS2CwYubAX0nFBkhWaOjVO8KznxhwmsWtV4/Rxn4On4=";
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
