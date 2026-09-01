{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.gh.tokenFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/home/jackson/.config/gh/token";
    description = ''
      Path to a file holding a GitHub personal access token, exported as
      GH_TOKEN by the gh wrapper. Useful on headless hosts, where it also
      reaches the git credential helper so HTTPS pushes use the same token.
      Null leaves gh to its ordinary stored credentials.
    '';
  };

  config.programs.gh = {
    enable = true;

    package = pkgs.callPackage ../../packages/gh.nix {
      inherit (config.gh) tokenFile;
    };

    # A host holding an outbound SSH key pushes over ssh. A host authenticating
    # through gh.tokenFile holds no key and overrides this to https.
    settings.git_protocol = lib.mkDefault "ssh";
  };
}
