{
  self,
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;

  cfg = config.ewood.root-ca;
in
{
  options.ewood.root-ca = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Allow this system to depend on infra's root certificate.
      '';
    };

    include = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Add infra's root certificate as a trusted certificate
      '';
    };
  };

  config = mkIf cfg.enable {
    security.pki.certificateFiles = mkIf cfg.include [
      config.clan.core.vars.generators."root-ca".files."cert".path
    ];

    clan.core.vars.generators = {
      root-ca = self.lib.generators.mkRootCA pkgs {
        share = true;

        pathlen = 3;
        subj = "/O=Infra/OU=Headquarters/CN=Infra Root CA";
      };
    };
  };
}
