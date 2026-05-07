{ config, ... }:

{
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "client";
}
