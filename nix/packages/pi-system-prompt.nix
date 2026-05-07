pkgs:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-system-prompt";
  version = "0.1.2";

  src = pkgs.fetchFromGitHub {
    owner = "jandrikus";
    repo = "pi-system-prompt";
    rev = "554623e9c913f866d3bc94d3a2620d26a1feded7";
    hash = "sha256-zLLF0IlSqoQtSEebEq2t5kInq7mQDjhwUIB5jLwpXyA=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r package.json README.md LICENSE extensions $out/
    runHook postInstall
  '';
}
