{
  options,
  config,
  lib,
  ...
}:
let
  inherit (builtins)
    getAttr
    attrValues
    concatStringsSep
    removeAttrs
    listToAttrs
    ;
  inherit (lib) types;
  inherit (lib.options) mkOption;
  inherit (lib.attrsets) filterAttrs nameValuePair;
  inherit (lib.trivial) const;
  inherit (lib.lists) flatten optional;
  inherit (lib.modules) mkIf;

  interfaceSubmodule =
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.coercedTo types.str (s: [ s ]) (types.listOf types.str);
          default = [ name ];
          description = "Interface names";
          defaultText = "Name of the attribute.";
        };

        blockFromLAN = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Block system from accessing any LAN device through this interfaces.
              A LAN device is with an ip (v4/v6) in the private range.
            '';
          };
        };

        # Common options from nixos.firewall.interfaces.<name>.
        inherit (options.networking.firewall)
          allowedUDPPorts
          allowedUDPPortRanges
          allowedTCPPorts
          allowedTCPPortRanges
          ;
      };
    };

  getInterfaces =
    role: filterAttrs (const (interface: interface.${role}.enable or false)) cfg.interfaces;
  getInterfaceNames = interfaces: flatten (map (getAttr "name") (attrValues interfaces));

  cleanCustomInterface =
    interface:
    removeAttrs interface [
      "name"
      "blockFromLAN"
    ];
  customInterFaceToInterfaces =
    customInterface:
    let
      interface = cleanCustomInterface customInterface;
    in
    (map (name: nameValuePair name interface)) customInterface.name;
  firewallInterfaces = listToAttrs (
    flatten (map customInterFaceToInterfaces (attrValues cfg.interfaces))
  );

  cfg = config.ewood.firewall;
  lcfg = config.networking.firewall;
in
{

  options.ewood.firewall = {
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule interfaceSubmodule);
      default = { };
    };
  };

  config = mkIf (cfg.interfaces != { }) {
    assertions = [
      {
        assertion = lcfg.enable && config.networking.nftables.enable;
        message = "custom-firwall depends on nftables, please enable nftables";
      }
    ];

    warnings = optional (
      !lcfg.enable
    ) "custom-firewall imported and configured but firewall is not actived.";

    networking = {
      firewall.interfaces = firewallInterfaces;
      nftables.tables = {
        "block-from-lan" =
          let
            interfaces = getInterfaces "blockFromLAN";
            interfaceNames = getInterfaceNames interfaces;
          in
          mkIf (interfaceNames != [ ]) {
            family = "inet";
            content = ''
              set ifnames {
                type ifname
                elements = {${concatStringsSep ", " interfaceNames}}
              }

              chain forward {
                type filter hook output priority filter;

                # enable flow offloading for better throughput
                # ip protocol { tcp, udp } flow offload @f

                # Allow established/related connections
                ct state related,established accept

                # Drop packets with private IP addresses (RFC 1918) going to WAN from any interface
                oifname @ifnames ip daddr {
                  10.0.0.0/8,
                  172.16.0.0/12,
                  192.168.0.0/16
                } drop comment "Block private IPv4 ranges from WAN"

                # Drop IPv6 ULA (Unique Local Address) range going to WAN from any interface
                oifname @ifnames ip6 daddr fc00::/7 drop comment "Block private IPv6 ranges from WAN"
              }
            '';
          };
      };
    };
  };
}
