{
  config,
  lib,
  pkgs,
  ...
}:

let
  gpgHomedir = "${config.xdg.dataHome}/gnupg";
  gpgStateDirectory = config.gpg.stateDirectory;
  # GnuPG rewrites the keybox and trustdb via temporary files and rename, so a
  # host that relocates them must supply one shared state directory rather than
  # separate paths that might be mounted individually.
  gpgKeyboxPath = "${gpgStateDirectory}/pubring.kbx";
  gpgTrustdbPath = "${gpgStateDirectory}/trustdb.gpg";
  gpgConfigPath = config.home.file."${gpgHomedir}/gpg.conf".source;
  gpgAgentConfigPath = config.home.file."${gpgHomedir}/gpg-agent.conf".source;

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
  options.gpg.stateDirectory = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = ''
      Directory for the mutable public keybox and trust database. When null,
      GnuPG keeps both inside {option}`programs.gpg.homedir`. Setting this
      option enables a wrapper that relocates them while continuing to read
      Home Manager's generated configuration directly from the Nix store.
    '';
  };

  config = lib.mkMerge [
    {
      programs.gpg = {
        enable = true;
        homedir = gpgHomedir;
      };

      services.gpg-agent = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        enable = true;
        pinentry.package = pkgs.pinentry-gnome3;
        # https://superuser.com/questions/624343/keep-gnupg-credentials-cached-for-entire-user-session
        defaultCacheTtl = 34560000;
        maxCacheTtl = 34560000;
      };
    }

    (lib.mkIf (gpgStateDirectory != null) {
      programs.gpg.package = gnupgWithStoreBackedConfig;

      # Keep GPG's declarative config store-backed. The homedir remains mutable
      # only for key material, public keyrings, trust DBs, revocation certs, and
      # GnuPG-managed state.
      home.file."${gpgHomedir}/gpg.conf".enable = false;
      home.file."${gpgHomedir}/gpg-agent.conf".enable = false;
    })
  ];
}
