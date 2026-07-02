{ llmAgentsOverlay }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.personal.userName;
  uid = toString config.users.users.${user}.uid;
  localDirectory = config.defaultDirectories.localDirectory;

  # Codex's CODEX_HOME replaces the default ~/.codex tree. Keep durable user
  # state here, but redirect noisy generated stores below into ~/local/cache.
  codexHomeDir = "${localDirectory}/state/codex";
  codexSqliteDir = "${codexHomeDir}/sqlite";
  codexCacheDir = "${localDirectory}/cache/codex";
  codexRuntimeCacheDir = "${codexCacheDir}/cache";
  codexLogDir = "${codexCacheDir}/log";
  codexTmpDir = "${codexCacheDir}/tmp";
  codexSystemSkillsDir = "${codexCacheDir}/system-skills";
  codexStandalonePackagesDir = "${codexCacheDir}/standalone-packages";

  codexEnvironment = {
    CODEX_HOME = codexHomeDir;
    CODEX_SQLITE_HOME = codexSqliteDir;
  };

  agentToolPath = lib.makeBinPath [
    pkgs.nodejs
    pkgs.python3
  ];
  codexPackage = pkgs.writeShellScriptBin "codex" ''
    set -euo pipefail

    export CODEX_HOME=${lib.escapeShellArg codexHomeDir}
    export CODEX_SQLITE_HOME=${lib.escapeShellArg codexSqliteDir}
    export PATH=${lib.escapeShellArg agentToolPath}:''${PATH:-}

    exec ${pkgs.llm-agents.codex}/bin/codex \
      --config ${lib.escapeShellArg "log_dir=${builtins.toJSON codexLogDir}"} \
      --config ${lib.escapeShellArg "sqlite_home=${builtins.toJSON codexSqliteDir}"} \
      "$@"
  '';
in
{
  nixpkgs.overlays = [ llmAgentsOverlay ];

  systemd.services."user@${uid}" = {
    overrideStrategy = "asDropin";
    environment = codexEnvironment;
  };

  systemd.services."home-manager-${user}".environment = codexEnvironment;

  # Codex stores config, auth, history, sessions, plugins, skills, logs, caches,
  # and SQLite state under CODEX_HOME by default. Persist CODEX_HOME as the
  # user-owned ~/.codex equivalent, while keeping logs/caches/tmp/system-skill
  # cache and Nix-unmanaged standalone updater payloads ephemeral.
  system.activationScripts.prepareCodexState = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg codexHomeDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg codexSqliteDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg codexCacheDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg codexRuntimeCacheDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg codexLogDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg codexTmpDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg codexSystemSkillsDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg codexStandalonePackagesDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg (codexHomeDir + "/skills")}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg (codexHomeDir + "/packages")}

      rm -rf ${lib.escapeShellArg (codexHomeDir + "/cache")}
      ln -sfnT ${lib.escapeShellArg codexRuntimeCacheDir} ${lib.escapeShellArg (codexHomeDir + "/cache")}
      rm -rf ${lib.escapeShellArg (codexHomeDir + "/log")}
      ln -sfnT ${lib.escapeShellArg codexLogDir} ${lib.escapeShellArg (codexHomeDir + "/log")}
      rm -rf ${lib.escapeShellArg (codexHomeDir + "/tmp")}
      ln -sfnT ${lib.escapeShellArg codexTmpDir} ${lib.escapeShellArg (codexHomeDir + "/tmp")}
      rm -rf ${lib.escapeShellArg (codexHomeDir + "/skills/.system")}
      ln -sfnT ${lib.escapeShellArg codexSystemSkillsDir} ${
        lib.escapeShellArg (codexHomeDir + "/skills/.system")
      }
      rm -rf ${lib.escapeShellArg (codexHomeDir + "/packages/standalone")}
      ln -sfnT ${lib.escapeShellArg codexStandalonePackagesDir} ${
        lib.escapeShellArg (codexHomeDir + "/packages/standalone")
      }
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${codexHomeDir} 0700 ${user} users -"
    "d ${codexSqliteDir} 0700 ${user} users -"
    "d ${codexCacheDir} 0700 ${user} users -"
    "d ${codexRuntimeCacheDir} 0700 ${user} users -"
    "d ${codexLogDir} 0700 ${user} users -"
    "d ${codexTmpDir} 0700 ${user} users -"
    "d ${codexSystemSkillsDir} 0700 ${user} users -"
    "d ${codexStandalonePackagesDir} 0700 ${user} users -"
    "d ${codexHomeDir}/skills 0700 ${user} users -"
    "d ${codexHomeDir}/packages 0700 ${user} users -"
    "L+ ${codexHomeDir}/cache - - - - ${codexRuntimeCacheDir}"
    "L+ ${codexHomeDir}/log - - - - ${codexLogDir}"
    "L+ ${codexHomeDir}/tmp - - - - ${codexTmpDir}"
    "L+ ${codexHomeDir}/skills/.system - - - - ${codexSystemSkillsDir}"
    "L+ ${codexHomeDir}/packages/standalone - - - - ${codexStandalonePackagesDir}"
  ];

  home-manager.users.${user} = {
    home.packages = [ codexPackage ];
    home.sessionVariables = codexEnvironment;
  };
}
