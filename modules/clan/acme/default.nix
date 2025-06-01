{ self, ... }:
{
  _class = "clan.service";
  manifest.name = "infra/acme";

  roles.client = {
    interface =
      { lib, ... }:
      {
        options = {
          email = lib.options.mkOption {
            type = lib.types.str;
            default = "admin+acme@${self.infra.domain}";
          };
        };
      };
    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            ...
          }:
          {
            security.acme = {
              acceptTerms = true;
              defaults = {
                inherit (settings) email;

                dnsProvider = "cloudflare";
                dnsResolver = "1.1.1.1";
                enableDebugLogs = true;
                credentialFiles =
                  let
                    inherit (config.clan.core.vars.generators."acme-cloudflare") files;
                  in
                  {
                    "CF_API_EMAIL_FILE" = files."api_email".path;
                    "CF_DNS_API_TOKEN_FILE" = files."dns_api_token".path;
                    "CF_ZONE_API_TOKEN_FILE" = files."zone_api_token".path;
                  };
              };
            };

            clan.core.vars.generators = {
              # NOTE: Bad practice to evaluate outside of clan.core for generators
              acme-cloudflare = lib.modules.mkIf (config.security.acme.certs != { }) {
                files = {
                  api_email = {
                    owner = "acme";
                    group = "acme";
                    # group = "nginx";
                  };
                  dns_api_token = {
                    owner = "acme";
                    group = "acme";
                    # group = "nginx";
                  };
                  zone_api_token = {
                    owner = "acme";
                    group = "acme";
                    # group = "nginx";
                  };
                };
                prompts = {
                  api_email = {
                    persist = true;
                    description = "email used for cloudflare login";
                  };
                  dns_api_token = {
                    type = "hidden";
                    persist = true;
                    description = ''
                      - Zone -> Dns -> Edit
                      - Include -> Specific Zone -> `SECRET_DOMAIN`
                      - DNS:Edit permission
                    '';
                  };
                  zone_api_token = {
                    type = "hidden";
                    persist = true;
                    description = ''
                      - Zone -> Zone -> Read
                      - Include -> Specific Zone -> `SECRET_DOMAIN`
                      - Zone:Read permission
                    '';
                  };
                };
              };
            };
          };
      };

  };
}
