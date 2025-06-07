{
  self,
  config,
  lib,
  ...
}:
let
  cfg = config.services.grafana;
in
{
  preservation.preserveAt = lib.modules.mkIf cfg.enable (
    self.lib.helpers.mkPreserveData config {
      directory = cfg.dataDir;
      user = "grafana";
      group = "grafana";
    }
  );
}
