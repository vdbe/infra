{ ... }:
let
in
{
  _class = "clan.service";
  manifest.name = "infra/acme";

  roles.default = {
    interface =
      { lib, ... }:
      let
        inherit (lib) types;

        nullOrStr = types.nullOr types.str;

        originRequestSubmodule =
          { ... }:
          {
            # TODO: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared_config#nested-schema-for-configorigin_request
            options = {
              http_host_header = lib.mkOption {
                type = nullOrStr;
                default = null;
                example = "www.example.org";
              };
              origin_server_name = lib.mkOption {
                type = nullOrStr;
                default = null;
                example = "www.example.org";
              };
            };
          };

        ingressSubmodule =
          { name, ... }:
          {
            options = {
              hostname = lib.mkOption {
                type = nullOrStr;
                default = name;
                example = "www.example.org";
              };
              service = lib.mkOption {
                type = nullOrStr;
                default = "https://localhost";
                description = "Protocol and address of destination server.";
              };
              path = lib.mkOption {
                type = nullOrStr;
                default = null;
                example = "status";
              };
              origin_request = lib.mkOption {
                type = types.nullOr (types.submodule originRequestSubmodule);
                default = {
                  origin_server_name = name;
                };
              };
            };
          };

      in
      {
        options = {
          # Can maybe remove this once is fixed and release https://github.com/cloudflare/terraform-provider-cloudflare/issues/5524
          tunnel_id = lib.options.mkOption {
            type = types.str;
            description = "TunnelID filed in credentials files";
          };
          ingress = lib.mkOption {
            type = types.attrsOf (types.submodule ingressSubmodule);
            default = { };
          };

          origin_request = lib.mkOption {
            type = types.nullOr (types.submodule originRequestSubmodule);
            default = null;
          };

          default = lib.mkOption {
            type = types.submodule ingressSubmodule;
            description = ''
              Catch-all service if no ingress matches.

              See `service`.
            '';
            default = {
              hostname = null;
              service = "http_status:404";
              origin_request = {
                origin_server_name = null;
              };
            };
          };
        };
      };

    perInstance =
      { machine, ... }:
      {
        nixosModule =
          {
            self,
            config,
            lib,
            pkgs,
            ...
          }:
          {
            # We don't use the nixos.services module since it doesn't allow authenticatian via token
            systemd = {
              targets = {
                cloudflared-tunnel = {
                  requires = [ "cloudflared-tunnel.service" ];
                  after = [ "cloudflared-tunnel.service" ];
                  unitConfig.StopWhenUnneeded = true;
                };
              };

              services = {
                cloudflared-tunnel = {
                  after = [
                    "network.target"
                    "network-online.target"
                    "nss-lookup.target"
                  ];
                  wants = [
                    "network.target"
                    "network-online.target"
                    "nss-lookup.target"
                  ];
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig = self.lib.templates.systemd.serviceConfig // {
                    # Fails because network-online and nss-lookup targets don't mean you can resolve to an upstreams dns
                    Restart = "on-failure";
                    RestartSec = "5";

                    DynamicUser = true;
                    Environment = "TUNNEL_TOKEN_FILE=%d/TUNNEL_TOKEN";
                    LoadCredential = "TUNNEL_TOKEN:${
                      config.clan.core.vars.generators."cloudflared".files."tunnel-token".path
                    }";
                    ExecStart = "${lib.getExe pkgs.cloudflared} tunnel run";
                    RestrictAddressFamilies = [
                      # "AF_UNIX"
                      "AF_INET"
                      "AF_INET6"
                    ];
                  };
                };
              };
            };

            clan.core.vars.generators = {
              "cloudflared" = {
                files = {
                  "tunnel-token" = {
                    restartUnits = [ "cloudflared-tunnel.service" ];
                  };
                };
                prompts = {
                  "tunnel-token" = {
                    persist = true;
                    type = "hidden";
                    description = ''
                      `cloudflared tunnel token infra-${machine.name}`
                    '';
                  };
                };
              };
            };
          };
      };
  };

  perMachine = {
    nixosModule = {
      clan.core.vars.generators = {
        "cloudflare" = {
          share = true;
          files = {
            "api-token" = {
              deploy = false;
            };
          };
        };
        "terraform" = {
          share = true;
          files = {
            "age-key.txt" = {
              deploy = false;
            };
          };
        };
      };
    };
  };
}
