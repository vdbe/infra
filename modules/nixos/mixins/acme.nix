{
  self,
  config,
  lib,
  ...
}:
let
  cfg = config.security.acme;
in
{
  preservation.preserveAt = lib.modules.mkIf (cfg.certs != { }) (
    self.lib.helpers.mkPreserveState config {
      directory = "/var/lib/acme";
      user = "acme";
      group = "acme";
    }
  );
}
