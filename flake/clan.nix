{ self, inputs, ... }:
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
          tags = [
            "server"
            "wifi"
            # "acme"
          ];
        };
      };

      services = {
        importer = {
          "base".roles.default = {
            tags = [ "all" ];
            extraModules = [ self.nixosModules.default ];
          };
          "server".roles.default = {
            tags = [ "server" ];
            extraModules = [ self.nixosModules.profiles-server ];
          };
        };
        sshd."default" = {
          roles.server.tags = [ "all" ];
        };
      };

      instances = {
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
      };
    };
  };
}
