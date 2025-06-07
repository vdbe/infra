{
  inputs,
  lib,
  ...

}:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkDefault;

  # cfg = config.ewood.profiles.server;
in
{
  imports = [
    inputs.srvos.nixosModules.server
  ];

  options.ewood.profiles.server = {
    enable = mkEnableOption "server profile" // {
      default = true;
      readOnly = true;
    };
  };

  config = {
    ewood = {
      perlless.enable = mkDefault true;
    };

    system.etc.overlay = {
      enable = mkDefault true;
      mutable = mkDefault false;
    };

    # None default nixos options
    facter.detected.graphics.enable = mkDefault false;
  };
}
