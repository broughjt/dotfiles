{ config, pkgs, ... }:

let
  # Keep VLC useful as a desktop app without making recent-file history or the
  # first-run network privacy prompt into state we need to persist. VLC still
  # writes ephemeral Qt geometry and an empty media-library file under
  # ~/local/{config,share}/vlc.
  vlcPackage = pkgs.symlinkJoin {
    name = "vlc-xdg-friendly";
    paths = [ pkgs.vlc ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/vlc" "$out/bin/qvlc"
      makeWrapper ${pkgs.vlc}/bin/vlc "$out/bin/vlc" \
        --add-flags "--no-qt-recentplay" \
        --add-flags "--no-qt-privacy-ask" \
        --add-flags "--no-metadata-network-access"
      makeWrapper ${pkgs.vlc}/bin/vlc "$out/bin/qvlc" \
        --add-flags "-I qt" \
        --add-flags "--no-qt-recentplay" \
        --add-flags "--no-qt-privacy-ask" \
        --add-flags "--no-metadata-network-access"

      if [ -e "$out/share/applications/vlc.desktop" ]; then
        rm -f "$out/share/applications/vlc.desktop"
        substitute ${pkgs.vlc}/share/applications/vlc.desktop "$out/share/applications/vlc.desktop" \
          --replace-fail ${pkgs.vlc}/bin/vlc "$out/bin/vlc"
      fi
    '';
  };
in
{
  home-manager.users.${config.personal.userName}.home.packages = [
    vlcPackage
  ];
}
