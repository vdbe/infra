{
  self,
  config,
  lib,
  ...
}:
let
  inherit (lib.modules) mkDefault mkIf;

  cfg = config.services.tailscale;
in
{
  services.tailscale = {
    disableTaildrop = mkDefault true;
    openFirewall = mkDefault true;
  };

  preservation.preserveAt = mkIf cfg.enable (
    self.lib.helpers.mkPreserveState config {
      directory = "/var/lib/tailscale";
    }
  );
}
