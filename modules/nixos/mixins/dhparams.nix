{
  self,
  lib,
  config,
  ...
}:
let
  cfg = config.security.dhparams;
in
{
  preservation.preserveAt = lib.modules.mkIf cfg.enable (
    self.lib.helpers.mkPreserveState config cfg.path
  );
}
