# The handoff CLI, for the agents whose skills run it. Requires pkgs.handoff
# from the handoff overlay.
{ pkgs, ... }:

{
  home.packages = [ pkgs.handoff ];
}
