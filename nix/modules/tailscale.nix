{ ... }:

{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
    extraSetFlags = [ "--ssh" ];
  };
}
