pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-web-access";
  version = "0.10.7";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-web-access";
    rev = "v${version}";
    hash = "sha256-D9no4SLigH/t3/WfirixMbTEjcEwZwJXld8j7pwBCew=";
  };

  npmDepsHash = "sha256-QKmgVmIvqLbqnUmKBKniT0CvNIgZWZ9mUkha0LJMMVQ=";
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r package.json README.md CHANGELOG.md *.ts skills node_modules $out/
    runHook postInstall
  '';
}
