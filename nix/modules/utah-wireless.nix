{ config, ... }:

let
  unid = config.personal.utahUnid;

  # Root of the chain that radius.utah.edu presents during the EAP handshake.
  # Pinning it is what makes PEAP-MSCHAPv2 safe here. Without CA validation any
  # rogue access point broadcasting these SSIDs can complete the outer tunnel,
  # capture the inner MSCHAPv2 challenge/response and crack it offline to the
  # uNID password's NT hash. `domain-suffix-match` additionally requires the
  # server certificate to name radius.utah.edu, so a certificate issued by this
  # CA for some other host cannot stand in for the RADIUS server.
  utahRootCertificate = "${./utah-root-ca.pem}";

  utahEnterpriseAuth = {
    eap = "peap;";
    phase2-auth = "mschapv2";
    identity = "${unid}@utah.edu";
    # Sent in the clear to route the request; the real identity travels inside
    # the TLS tunnel.
    anonymous-identity = "anonymous@utah.edu";
    ca-cert = utahRootCertificate;
    domain-suffix-match = "radius.utah.edu";
    password-flags = 1;
  };

  utahNetwork =
    {
      id,
      uuid,
      ssid,
      priority,
    }:
    {
      connection = {
        inherit id uuid;
        type = "wifi";
        autoconnect = true;
        autoconnect-priority = priority;
      };

      wifi = {
        inherit ssid;
        mode = "infrastructure";
      };

      wifi-security.key-mgmt = "wpa-eap";

      "802-1x" = utahEnterpriseAuth;

      ipv4.method = "auto";
      ipv6 = {
        method = "auto";
        addr-gen-mode = "default";
      };
    };
in
{
  # Unlike the other wireless networks on this host, which are ad-hoc profiles
  # living in the persisted /etc/NetworkManager/system-connections, the
  # University of Utah networks are declared here and rendered from the store.
  networking.networkmanager.ensureProfiles.profiles = {
    eduroam = utahNetwork {
      id = "eduroam";
      uuid = "a2430cf5-e858-4d3a-a7f5-761377885218";
      ssid = "eduroam";
      priority = 20;
    };

    # UConnect terminates on the same RADIUS servers behind the same CA, so it
    # takes identical settings. Kept at a lower priority as a fallback for spots
    # where eduroam is weak. Its acceptance of PEAP is inferred from the shared
    # RADIUS deployment rather than confirmed by a live handshake.
    UConnect = utahNetwork {
      id = "UConnect";
      uuid = "f888cc3c-93e3-4649-81ee-f680cf3a936a";
      ssid = "UConnect";
      priority = 10;
    };
  };
}
