{
  self,
  config,
  lib,
  ...
}:
let
  cfg = config.services.kanidm;
in
{
  preservation.preserveAt = lib.modules.mkIf cfg.enableServer (
    self.lib.helpers.mkPreserveData config {
      directory = "/var/lib/kanidm";
      user = "kanidm";
      group = "kanidm";
    }
  );
}
