{
  pkgs,
  emacsPackages,
}:

emacsPackages.trivialBuild {
  pname = "lean4-mode";
  version = "1.1.2-unstable-2025-06-01-1388f9d";

  src = pkgs.fetchFromGitHub {
    owner = "leanprover-community";
    repo = "lean4-mode";
    rev = "1388f9d1429e38a39ab913c6daae55f6ce799479";
    hash = "sha256-6XFcyqSTx1CwNWqQvIc25cuQMwh3YXnbgr5cDiOCxBk=";
  };

  packageRequires = with emacsPackages; [
    compat
    dash
    lsp-mode
    magit-section
  ];

  postInstall = ''
    cp -r data "$out/share/emacs/site-lisp/"
  '';
}
