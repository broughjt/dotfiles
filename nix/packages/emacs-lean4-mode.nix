{
  pkgs,
  emacsPackages,
}:

emacsPackages.trivialBuild {
  pname = "lean4-mode";
  version = "0-unstable-2026-03-07-b0aad81";

  src = pkgs.fetchFromGitHub {
    owner = "ultronozm";
    repo = "lean4-mode";
    rev = "b0aad81b30c234e6af1b21f700e7188670727a98";
    hash = "sha256-QCFRyTkrRobjrwqHwuDkGVp5FGWNDBGq8X6jcPSotNo=";
  };

  packageRequires = with emacsPackages; [
    magit-section
    markdown-mode
  ];

  postInstall = ''
    cp -r data "$out/share/emacs/site-lisp/"
  '';
}

# Official lsp-mode based lean4-mode. Keep this around as an easy rollback
# target if the Eglot fork is too stale or otherwise misbehaves.
#
# emacsPackages.trivialBuild {
#   pname = "lean4-mode";
#   version = "1.1.2-unstable-2025-06-01-1388f9d";
#
#   src = pkgs.fetchFromGitHub {
#     owner = "leanprover-community";
#     repo = "lean4-mode";
#     rev = "1388f9d1429e38a39ab913c6daae55f6ce799479";
#     hash = "sha256-6XFcyqSTx1CwNWqQvIc25cuQMwh3YXnbgr5cDiOCxBk=";
#   };
#
#   packageRequires = with emacsPackages; [
#     compat
#     dash
#     lsp-mode
#     magit-section
#   ];
#
#   patches = [ ./emacs-lean4-mode-inlay-refresh.patch ];
#
#   postInstall = ''
#     cp -r data "$out/share/emacs/site-lisp/"
#   '';
# }
