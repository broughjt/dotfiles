{ lib, ... }:

{
  # Swap is compressed in memory
  # murph would potentially want a disk device for hibernation
  swapDevices = lib.mkForce [ ];

  zramSwap.enable = true;
}
