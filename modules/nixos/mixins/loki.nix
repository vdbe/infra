{
  self,
  config,
  lib,
  ...
}:
let
  cfg = config.services.loki;
in
{
  preservation.preserveAt = lib.modules.mkIf cfg.enable (
    self.lib.helpers.mkPreserveData config {
      directory = cfg.dataDir;
      user = "loki";
      group = "loki";
    }
  );
}
