{
  config,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  homeManagerUser = config.home-manager.users.${user};
  localDirectory = config.defaultDirectories.localDirectory;
  gpgHomedir = "${homeManagerUser.xdg.dataHome}/gnupg";
  # Durable GnuPG state lives outside the ephemeral GNUPGHOME. The keybox and
  # trustdb are written via temp+rename, so they must live inside a persisted
  # directory rather than be individually bind-mounted by impermanence.
  gpgKeyboxPath = "${localDirectory}/state/gnupg/pubring.kbx";
  gpgTrustdbPath = "${localDirectory}/state/gnupg/trustdb.gpg";
  gpgConfigPath = homeManagerUser.home.file."${gpgHomedir}/gpg.conf".source;
  gpgAgentConfigPath = homeManagerUser.home.file."${gpgHomedir}/gpg-agent.conf".source;

  # Home Manager renders gpg.conf and gpg-agent.conf from these modules:
  # - https://github.com/nix-community/home-manager/blob/e4419d3123b780d5f4c0bceeace450424387638c/modules/programs/gpg.nix
  # - https://github.com/nix-community/home-manager/blob/e4419d3123b780d5f4c0bceeace450424387638c/modules/services/gpg-agent.nix
  # Keep those generated files in the Nix store and point the GnuPG tools at
  # them instead of symlinking declarative config into the mutable keyring DB.
  # GPG warns about /nix/store being group-writable for builders, so the wrapper
  # suppresses that known-safe store-path permission warning.
  gnupgWithStoreBackedConfig = pkgs.symlinkJoin {
    name = "gnupg-store-backed-config";
    paths = [ pkgs.gnupg ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for program in gpg gpg-agent gpgconf gpg-connect-agent gpgsm dirmngr; do
        if [ -x "$out/bin/$program" ]; then
          wrapProgram "$out/bin/$program" \
            --set GNUPGHOME ${gpgHomedir}
        fi
      done

      wrapProgram "$out/bin/gpg" \
        --add-flags "--no-permission-warning" \
        --add-flags "--homedir ${gpgHomedir}" \
        --add-flags "--options ${gpgConfigPath}" \
        --add-flags "--no-default-keyring" \
        --add-flags "--keyring ${gpgKeyboxPath}" \
        --add-flags "--trustdb-name ${gpgTrustdbPath}"

      wrapProgram "$out/bin/gpg-agent" \
        --add-flags "--options ${gpgAgentConfigPath}"
    '';
  };
in
{
  home-manager.users.${user} = {
    home.packages = with pkgs; [ pinentry-gnome3 ];

    # TODO: Does this belong here?
    services.ssh-agent.enable = pkgs.stdenv.isLinux;

    programs.gpg = {
      enable = true;
      package = gnupgWithStoreBackedConfig;
      homedir = gpgHomedir;
    };

    # Keep GPG's declarative config store-backed. The homedir remains mutable
    # only for key material, public keyrings, trust DBs, revocation certs, and
    # GnuPG-managed state.
    home.file."${gpgHomedir}/gpg.conf".enable = false;
    home.file."${gpgHomedir}/gpg-agent.conf".enable = false;

    services.gpg-agent = {
      enable = pkgs.stdenv.isLinux;
      pinentry.package = pkgs.pinentry-gnome3;
      # https://superuser.com/questions/624343/keep-gnupg-credentials-cached-for-entire-user-session
      defaultCacheTtl = 34560000;
      maxCacheTtl = 34560000;
    };
  };
}
