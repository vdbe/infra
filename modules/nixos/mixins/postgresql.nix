{
  self,
  config,
  lib,
  ...
}:
let
  cfg = config.services.postgresql;
in
{
  preservation.preserveAt = lib.modules.mkIf cfg.enable (
    self.lib.helpers.mkPreserveData config {
      directory = cfg.dataDir;
      user = "postgres";
      group = "postgres";
    }
  );
}
