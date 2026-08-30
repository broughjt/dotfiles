{
  config,
  ...
}:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
  codexHomeDirectory = config.home-manager.users.${user}.codex.configDirectory;

  # Codex offers no configuration knob for these, unlike log_dir and
  # sqlite_home, so the only way to keep them out of the persisted CODEX_HOME
  # is to symlink them at their fixed names. Everything below is rebuildable:
  # a runtime cache, scratch files, the cache of system skills Codex ships, and
  # the standalone updater payloads Nix does not manage.
  codexCacheDirectory = "${localDirectory}/cache/codex";
  redirects = {
    "cache" = "${codexCacheDirectory}/cache";
    "tmp" = "${codexCacheDirectory}/tmp";
    "skills/.system" = "${codexCacheDirectory}/system-skills";
    "packages/standalone" = "${codexCacheDirectory}/standalone-packages";
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${codexCacheDirectory} 0700 ${user} users -"
    # Parents of the redirected names, inside the persisted CODEX_HOME.
    "d ${codexHomeDirectory}/skills 0700 ${user} users -"
    "d ${codexHomeDirectory}/packages 0700 ${user} users -"
  ]
  ++ builtins.concatLists (
    builtins.attrValues (
      builtins.mapAttrs (name: target: [
        "d ${target} 0700 ${user} users -"
        "L+ ${codexHomeDirectory}/${name} - - - - ${target}"
      ]) redirects
    )
  );
}
