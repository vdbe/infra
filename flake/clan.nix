{ self, inputs, ... }:
let
  inherit (self.infra) domain;
in
{
  imports = [
    inputs.clan.flakeModules.default
  ];
  clan = {
    meta.name = "__CHANGE_ME__";
    inherit self;
    specialArgs = {
      inherit inputs;
    };

    inventory = {
      machines = {
        arnold = {
          deploy.targetHost = "arnold.tailscale.${domain}";
          tags = [
            "server"
            "wifi"
            "acme"
            "tunnel"
            "tailscale"
          ];
        };
      };

      services = {
        sshd."default" = {
          roles.server.tags = [ "all" ];
        };
      };

      instances = {
        "base" = {
          module = {
            name = "importer";
            input = "clan";
          };
          roles.default = {
            tags."all" = { };
            extraModules = [ self.nixosModules.default ];
          };
        };
        "server" = {
          module = {
            name = "importer";
            input = "clan";
          };
          roles.default = {
            tags."server" = { };
            extraModules = [ self.nixosModules.profiles-server ];
          };
        };
        "tailsale" = {
          module = {
            name = "importer";
            input = "clan";
          };
          roles.default = {
            tags."tailscale" = { };
            extraModules = [
              {
                services.tailscale.enable = true;
              }
            ];
          };
        };
        "sshd" = {
          module.name = "sshd";
          roles."server" = {
            settings =
              let
                sshKeys = {
                  "yubikey-5-nfc-01" =
                    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPozrPzzJpzXoDLvnp/bYd7Jj7jWsP7GKfuLmcvQxy7pAAAAFHNzaDp5dWJpa2V5LTUtbmZjLTAx ssh:yubikey-5-nfc-01";
                  "yubikey-5-nfc-02" =
                    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIC7OWf8mT9DjB73bAwbk5W9Kmf2nlpuGK6e08+FiuOWvAAAAFHNzaDp5dWJpa2V5LTUtbmZjLTAy ssh:yubikey-5-nfc-02";
                };
              in
              {
                allowedKeys = sshKeys;
                userCAs = sshKeys;
              };
            tags."all" = { };
          };
        };

        "wifi" = {
          module = {
            name = "wifi";
            input = "clan";
          };
          roles."default" = {
            tags."wifi" = { };
            settings = {
              networks."home".enable = true;
            };
          };
        };

        "acme" = {
          module.name = "acme";
          roles."client" = {
            tags."acme" = { };
          };
        };

        "tunnel" = {
          module.name = "cloudflare-tunnel";
          roles."default" = {
            tags."tunnel" = { };
            machines."arnold".settings = {
              tunnel_id = "be3bb077-8fb7-4948-b014-2791e6185ff5";
              ingress = {
                "idm.${domain}" = { };
                "grafana.${domain}" = {};
              };
            };
          };
        };
      };
    };
  };
}
