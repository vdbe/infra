{
  self,
  config,
  lib,
  ...
}:
let
  cfg = config.services.prometheus;
in
{
  preservation.preserveAt = lib.modules.mkIf cfg.enable (
    self.lib.helpers.mkPreserveData config {
      directory = "/var/lib/${cfg.stateDir}";
      user = "prometheus";
      group = "prometheus";
    }
  );
}
