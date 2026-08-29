{
  config,
  lib,
  ...
}:

{
  options.agentInstructions = {
    machineFile = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression "../../agents/machines/murph.md";
      description = ''
        The `## This machine` section for this host.
      '';
    };

    text = lib.mkOption {
      type = lib.types.lines;
      default = lib.concatStringsSep "\n" [
        (builtins.readFile ../../../agents/instructions/preamble.md)
        (builtins.readFile config.agentInstructions.machineFile)
        (builtins.readFile ../../../agents/instructions/conventions.md)
      ];
      defaultText = lib.literalMD "User-global agent instructions.";
      description = ''
        User-global agent instructions.
      '';
    };
  };
}
