{
  inputs,
  lib,
  config,
  options,
  pkgs,
  ...
}:
let
  inherit (builtins) attrNames map;
  inherit (lib) types;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkOption;

  inherit (config.users) users;

  sopsSecrets = config.sops.secrets;
  sopsRegularSecrets = (filterAttrs (_: v: !v.neededForUsers) sopsSecrets) != { };
  sopsSecretsForUsers = (filterAttrs (_: v: v.neededForUsers) sopsSecrets) != { };

  useSystemdActivation =
    (options.systemd ? sysusers && config.systemd.sysusers.enable)
    || (options.services ? userborn && config.services.userborn.enable);

  sopsSystemdInstallSecrets = (sopsRegularSecrets && useSystemdActivation);
  sopsSystemdInstallSecretsForUsers = (sopsSecretsForUsers && useSystemdActivation);
  sopsActivationScriptssetupSecrets = (sopsRegularSecrets && !useSystemdActivation);
  sopsActivationScriptsSetupSecretsForUsers = (sopsSecretsForUsers && !useSystemdActivation);

  persistentSopsPath = "${cfg.path}/data/var/lib/sops-nix";

  cfg = config.ewood.persistence;
in
{

  imports = [
    inputs.preservation.nixosModules.preservation
  ];

  options.ewood.persistence = {
    enable = mkOption {
      type = types.bool;
      default = config.fileSystems."/".fsType == "tmpfs";
      defaultText = ''config.fileSystems."/".fsType == "tmpfs"'';
      description = ''
        Preserve data/state/cache when using an ephemeral root filsystem.
      '';
    };
    path = mkOption {
      type = types.path;
      default = "/nix/persist";
      description = ''
        Deafult persistent directory
      '';
    };
    users = mkOption {
      type = types.listOf types.string;
      default =
        let
          normalUsers = filterAttrs (_: user: user.isNormalUser) users;
        in
        [ "root" ] ++ (attrNames normalUsers);
      defaultText = ''All normal users and root'';
      description = ''
        Users of which to preserve the home directory.
      '';
    };
  };

  config = mkIf cfg.enable {
    preservation = {
      enable = mkDefault true;
      preserveAt = {
        "${cfg.path}/users" = {
          directories = map (user: {
            directory = users.${user}.home;
            inherit user;
            inherit (users.${user}) group;
            configureParent = true;

          }) cfg.users;
        };
        "${cfg.path}/data" = {
          directories = [
            {
              directory = "/var/log";
              configureParent = true;
            }
          ];
        };
        "${cfg.path}/state" = {
          directories = [
            {
              directory = "/var/lib/systemd/timesync";
              configureParent = true;
            }
          ];
        };
      };
    };

    # Link sops dir
    # Needs to happen earlier then normal persistance services.
    #
    # Based on:
    #   - https://github.com/Mic92/sops-nix/blob/8d215e1c981be3aa37e47aeabd4e61bb069548fd/modules/sops/default.nix
    #   - https://github.com/Mic92/sops-nix/blob/8d215e1c981be3aa37e47aeabd4e61bb069548fd/modules/sops/secrets-for-users/default.nix
    systemd.services = {
      link-sops-dir = lib.mkIf (sopsSystemdInstallSecrets || sopsSystemdInstallSecretsForUsers) {
        wantedBy =
          (lib.optional sopsSystemdInstallSecrets "sops-install-secrets.service")
          ++ (lib.optional sopsSystemdInstallSecretsForUsers "sops-install-secrets-for-users.service");
        before =
          (lib.optional sopsSystemdInstallSecrets "sops-install-secrets.service")
          ++ (lib.optional sopsSystemdInstallSecretsForUsers "sops-install-secrets-for-users.service");
        unitConfig.DefaultDependencies = "no";

        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "link-sops-nix-dir" ''
            mkdir -p /var/lib
            rm -rf /var/lib/sops-nix
            ln -sfn "${persistentSopsPath}"  -t /var/lib
          '';
        };
      };
    };

    system.activationScripts =
      mkIf (sopsActivationScriptssetupSecrets || sopsActivationScriptsSetupSecretsForUsers)
        {
          linkSopsDir = {
            # Run after /dev has been mounted
            deps = [ "specialfs" ];
            text = ''
              # Needed by sops setupSecrets/setupSecretsForUsers
              [ -e /run/current-system ] || echo setting up keys...
              rm -rf /var/lib/sops-nix
              ln -sfn ${persistentSopsPath} -t /var/lib
            '';
          };
          setupSecrets.deps = mkIf sopsActivationScriptssetupSecrets [ "linkSopsDir" ];
          setupSecretsForUsers.deps = mkIf sopsActivationScriptsSetupSecretsForUsers [ "linkSopsDir" ];
        };
  };
}
