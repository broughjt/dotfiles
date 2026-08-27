{
  # Assembles AGENTS.md from the two portable fragments and one machine
  # section. The machine section goes between them: "Getting tools" tells agents
  # to reach for Nix, which is only true because the machine section says the
  # machine has it.
  #
  # Anything else that assembles these fragments -- a sprite, provisioned
  # outside Nix -- has to keep that order.
  assembleAgentInstructions =
    { pkgs, machine }:
    pkgs.runCommand "AGENTS.md" { } ''
      {
        cat ${../../agents/instructions/preamble.md}
        echo
        cat ${machine}
        echo
        cat ${../../agents/instructions/conventions.md}
      } > "$out"
    '';
}
