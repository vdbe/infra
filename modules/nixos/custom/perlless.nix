# Based on https://github.com/NixOS/nixpkgs/blob/4bc6bf6ac8da0095fc866d8a9131bceafc525915/nixos/modules/profiles/perlless.nix

{
  inputs,
  lib,
  config,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;

  cfg = config.ewood.perlless;
in
{

  imports = [
    inputs.preservation.nixosModules.preservation
  ];

  options.ewood.perlless = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Remove as much perl as possible from the system
      '';
    };
    forbidPerl = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Forbid perl as a dependency
      '';
    };
  };

  config = mkIf cfg.enable {
    # Remove perl from activation
    boot.initrd.systemd.enable = lib.mkDefault true;
    system.etc.overlay.enable = lib.mkDefault true;
    services.userborn.enable = lib.mkDefault true;

    # Random perl remnants
    system.tools.nixos-generate-config.enable = lib.mkDefault false;
    programs.less.lessopen = lib.mkDefault null;
    programs.command-not-found.enable = lib.mkDefault false;
    boot.enableContainers = lib.mkDefault false;
    boot.loader.grub.enable = lib.mkDefault false;
    environment.defaultPackages = lib.mkDefault [ ];
    documentation.info.enable = lib.mkDefault false;
    documentation.nixos.enable = lib.mkDefault false;

    # Check that the system does not contain a Nix store path that contains the
    # string "perl".
    system.forbiddenDependenciesRegexes = mkIf cfg.forbidPerl [ "perl" ];
  };
}
