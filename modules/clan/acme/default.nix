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
                    getFilePath = file: config.clan.core.vars.generators."acme-cloudflare".files.${file}.path;
                  in
                  {
                    "CF_API_EMAIL_FILE" = getFilePath "api_email";
                    "CF_DNS_API_TOKEN_FILE" = getFilePath "dns_api_token";
                    "CF_ZONE_API_TOKEN_FILE" = getFilePath "zone_api_token";
                  };
              };
            };

            clan.core.vars.generators = {
              acme-cloudflare =
                let
                  mkPrompt = type: description: {
                    file = {
                      owner = "acme";
                      group = "acme";
                    };
                    prompt = {
                      inherit type description;
                    };
                  };
                in
                self.lib.generators.mkPrompts {
                  "api_email" = mkPrompt "line" "Email used for cloudflare login";
                  "dns_api_token" = mkPrompt "hidden" ''
                    - Zone -> Dns -> Edit
                    - Include -> Specific Zone -> `SECRET_DOMAIN`
                    - DNS:Edit permission
                  '';
                  "zone_api_token" = mkPrompt "hidden" ''
                    - Zone -> Zone -> Read
                    - Include -> Specific Zone -> `SECRET_DOMAIN`
                    - Zone:Read permission
                  '';

                };
            };
          };
      };

  };
}
