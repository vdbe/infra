{
  description = "A very basic flake";

  inputs = {
    # WARN: This handling of `path:` is a Nix 2.26 feature. The Flake won't work on versions prior to it
    # https://github.com/NixOS/nix/pull/10089
    infra.url = "path:../.";

    systems.follows = "infra/systems";
    nixpkgs.follows = "infra/nixpkgs";
    flake-parts.follows = "infra/flake-parts";

    terranix.url = "github:vdbe/terranix/feat/ephemeral";
    terranix.inputs.systems.follows = "systems";
    terranix.inputs.nixpkgs.follows = "nixpkgs";
    terranix.inputs.flake-parts.follows = "flake-parts";
  };

  outputs =
    inputs@{
      self,
      systems,
      flake-parts,
      terranix,
      nixpkgs,
      infra,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      imports = [
        terranix.flakeModule
      ];

      perSystem =
        {
          self',
          pkgs,
          system,
          lib,
          ...
        }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          packages = {
            import-terraform = pkgs.writeShellApplication {
              name = "import-terraform";
              runtimeInputs = [ pkgs.jq ];
              text = builtins.readFile ./import.bash;
            };
          };

          # terraformConfiguration = terranix.lib.terranixConfiguration {
          #   inherit system pkgs;
          #   extraArgs = {
          #     inherit inputs;
          #   };
          #   modules = [
          #     inputs.self.terranixModules.core
          #   ];
          # };
          terranix = {
            terranixConfigurations = {
              terraform = {
                terraformWrapper = {
                  package = pkgs.terraform;
                  extraRuntimeInputs = [
                    pkgs.sops
                    pkgs.age-plugin-yubikey
                  ];
                  prefixText =
                    let
                      encryptedKeyFile = "../../vars/shared/terraform/age-key.txt/secret";
                      keyFile' = "\"$PWD/key.txt\"";
                    in
                    ''
                      # Load in terraform key file
                      function load_key_file() {
                        KEY_FILE="$(realpath ${keyFile'})"
                        touch "$KEY_FILE";
                        chmod 600 "$KEY_FILE"

                        echo "[+] Loading $KEY_FILE"
                        KEY_FILE="$(realpath ${keyFile'})"

                        sops decrypt "${encryptedKeyFile}" --output "$KEY_FILE"
                        SOPS_AGE_KEY_FILE="$KEY_FILE"
                        export SOPS_AGE_KEY_FILE
                      }

                      function cleanup_key_file() {
                        rm -f "$KEY_FILE"
                        echo "[+] Removing $KEY_FILE"
                      }

                      if [[ "$1" == "apply" ]]; then
                        trap cleanup_key_file EXIT
                        load_key_file
                        export SOPS_AGE_KEY_FILE

                        ${lib.getExe self'.packages.import-terraform}
                      fi
                    '';
                };

                modules = [
                  {
                    _module.args = {
                      inherit self;
                    };
                  }

                  ./sops.nix
                  ./cloudflare
                  ./tailscale
                ];
              };
            };
          };
        };

      flake =
        { lib, ... }:
        let
          inherit (builtins) mapAttrs getAttr;
          inherit (lib.trivial) const;
          inherit (lib.modules) evalModules;

          clanLib = infra.clanInternals.clanLib;
          inventory = inputs.infra.clanInternals.inventory;

          importedModuleWithInstances =
            (clanLib.inventory.mapInstances {
              flakeInputs = inputs;
              inherit inventory;
              localModuleSet = infra.clan.modules;
            }).importedModuleWithInstances;

          getMachinesSettings =
            instance: role:
            let
              instance' = importedModuleWithInstances.${instance};

              # Options
              interface = instance'.resolvedModule.roles.${role}.interface;

              # Config
              settings = instance'.instanceRoles.${role};
              defaultSettings = settings.settings;
              machinesSettings = mapAttrs (const (getAttr "settings")) settings.machines;

              evaluateMachineSettings =
                machineSettings:
                evalModules {
                  modules = [
                    interface
                    defaultSettings
                    machineSettings
                  ];
                };
            in
            builtins.mapAttrs (const (
              settings: getAttr "config" (evaluateMachineSettings settings)
            )) machinesSettings;
        in
        {
          lib = {
            inherit getMachinesSettings;
          };

          machineTunnelSettings = self.lib.getMachinesSettings "tunnel" "default";
          inherit inputs;
        };
    };

}
