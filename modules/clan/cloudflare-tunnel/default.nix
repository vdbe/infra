# Can't provision tunnel with terraform since the uuid is required to import `cloudflare_zero_trust_tunnel_cloudflared`
# and I want to be able to apply without a .tfstate present
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
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            ...
          }:
          {
            services.cloudflared = {
              enable = true;
              tunnels = {
                "${settings.tunnel_id}" = {
                  credentialsFile = config.clan.core.vars.generators."cloudflared".files."credentials".path;
                  default = "http_status:404";
                };
              };
            };

            clan.core.vars.generators = {
              "cloudflared" = {
                files = {
                  "credentials" = {
                    restartUnits = [ "cloudflared-tunnel-${settings.tunnel_id}.service" ];
                  };
                };
                prompts = {
                  "credentials" = {
                    persist = true;
                    type = "hidden";
                    description = ''
                      The file in ~/.cloudflared/<tunnel id>.json in ~/.cloudflared,
                      created by `cloudflared tunnel create <tunnel name>`.
                    '';
                  };
                };

                script = ''
                  cat $prompts/credentials

                '';
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
            "account-id" = {
              deploy = false;
            };
            "zone-id" = {
              deploy = false;
            };
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
