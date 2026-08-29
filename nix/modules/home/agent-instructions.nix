{
  config,
  lib,
  pkgs,
  ...
}:

let
  agentInstructions = import ../../packages/agent-instructions.nix;
in
{
  options.agentInstructions = {
    machineFile = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression "../../agents/machines/murph.md";
      description = ''
        The `## This machine` section for this host, spliced between the two
        portable instruction fragments. There is deliberately no default: a
        host that hands agents instructions has to describe itself truthfully.
      '';
    };

    file = lib.mkOption {
      type = lib.types.path;
      default = agentInstructions.assembleAgentInstructions {
        inherit pkgs;
        machine = config.agentInstructions.machineFile;
      };
      defaultText = lib.literalMD "the instructions assembled around `machineFile`";
      description = ''
        The assembled user-global agent instructions. Claude Code and Codex read
        this same file under the two different names each expects.
      '';
    };
  };
}
