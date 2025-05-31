{
  inputs,
  lib,
  config,
  ...
}:
let
  inherit (builtins) attrNames map;
  inherit (lib) types;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkOption;

  inherit (config.users) users;

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

  };
}
