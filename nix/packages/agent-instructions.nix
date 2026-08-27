{
  # Assembles AGENTS.md from the two portable fragments and one machine
  # section. The machine section goes between them: "Getting tools" tells agents
  # to reach for Nix, which is only true because the machine section says the
  # machine has it.
  #
  # A sprite's copy is built by this same function, with machines/sprite.md as
  # the machine section, and travels there in the sprite-provision payload.
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
