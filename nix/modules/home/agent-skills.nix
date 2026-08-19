{ config, lib, ... }:

let
  user = config.personal.userName;
  homeDirectory = config.defaultDirectories.homeDirectory;

  # Codex and Pi both discover user-global Agent Skills here. The complete
  # directory is immutable and Nix-managed; no mutable skill state is kept.
  skillsSource = builtins.path {
    name = "skills";
    path = ../../../agents/skills;
  };
  agentsDir = "${homeDirectory}/.agents";
  userSkillsDir = "${agentsDir}/skills";
in
{
  system.activationScripts.prepareAgentSkills = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg agentsDir}
      rm -rf ${lib.escapeShellArg userSkillsDir}
      ln -sfnT ${lib.escapeShellArg skillsSource} ${lib.escapeShellArg userSkillsDir}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${agentsDir} 0700 ${user} users -"
    "L+ ${userSkillsDir} - - - - ${skillsSource}"
  ];
}
