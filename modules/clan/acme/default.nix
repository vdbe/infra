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
            assertions = [
              {
                # Can't check this inside clan.core.vars.generators since it
                # will start evaluting parts of the nixos configuration leading
                # to errors from missing files (which need to be generated) or
                # infinite recusion
                assertion = config.security.acme.certs != { };
                message = ''
                  acme clan module enabled without acme certs!
                  This will crash sops-nix because the acme user is missing
                '';
              }
            ];
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
              acme-cloudflare = {
                files = {
                  api_email = {
                    owner = "acme";
                    group = "acme";
                  };
                  dns_api_token = {
                    owner = "acme";
                    group = "acme";
                  };
                  zone_api_token = {
                    owner = "acme";
                    group = "acme";
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
