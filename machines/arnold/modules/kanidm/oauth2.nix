{
  self,
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (builtins) head;
  inherit (lib.strings) splitString;

  inherit (self.infra) domain;
  domainSld = head (splitString "." domain);

  generators = config.clan.core.vars.generators;
in
{
  services.kanidm.provision = {
    groups = {
      "cf-zero-trust.access".members = [ ];
    };

    systems.oauth2 = {
      cloudflare-zero-trust = {
        displayName = "Cloudflare Zero Trust";
        originUrl = "https://${domainSld}.cloudflareaccess.com/cdn-cgi/access/callback";
        originLanding = "https://${domainSld}.cloudflareaccess.com";
        basicSecretFile = generators."kanidm-oauth2".files."cloudflare-zero-trust".path;
        preferShortUsername = true;
        scopeMaps."cf-zero-trust.access" = [
          "openid"
          "email"
          "profile"
        ];
      };
    };
  };

  clan.core.vars.generators = {
    kanidm-oauth2 = self.lib.generators.mkPasswords pkgs {
      "cloudflare-zero-trust" = {
        file = {
          restartUnits = [ "kanidm.service" ];
          owner = "kanidm";
          group = "kanidm";
        };
      };
    };
  };
}
