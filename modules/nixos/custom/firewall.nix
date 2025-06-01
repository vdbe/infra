{ config, lib, ... }:
let
  roles = [
    "blockFromLAN"
  ];

  interfaceNames =
    role: builtins.attrNames (lib.filterAttrs (n: v: builtins.elem role v.roles) cfg.interfaces);

  interfaceSubModule =
    { name, ... }:
    {
      options = {
        ifname = lib.mkOption {
          type = lib.types.str;
          default = name;
        };

        # TODO: Document roles
        roles = lib.mkOption {
          type = lib.types.listOf (lib.types.enum roles);
          default = [ ];
        };
      };
      config = { };
    };
  cfg = config.ewood.firewall;
in
{

  options.ewood.firewall = {
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule interfaceSubModule);
      default = { };
    };
  };

  config = {
    networking.nftables.tables = {
      "block-from-lan" =
        let
          interfaces = interfaceNames "blockFromLAN";
        in
        lib.mkIf (interfaces != [ ]) {
          family = "inet";
          content = ''
            set ifnames {
              type ifname
              elements = {${builtins.concatStringsSep ", " interfaces}}
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
}
