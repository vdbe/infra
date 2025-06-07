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
  inherit (lib.modules) mkIf;

  inherit (self.infra) domain;
  domainSld = head (splitString "." domain);
  getBasicSecretPath = system: config.clan.core.vars.generators."kanidm-oauth2".files.${system}.path;

in
{
  services = {
    kanidm.provision = {
      groups = {
        "cf-zero-trust.access".members = [
          "grafana.access"
        ];

        "grafana.server-admins".members = [ ];
        "grafana.admins".members = [
          "grafana.server-admins"
        ];
        "grafana.editors".members = [
          "grafana.admins"
        ];
        "grafana.viewers".members = [
          "grafana.editors"
        ];
        "grafana.access".members = [
          "grafana.viewers"
        ];
      };

      systems.oauth2 = {
        cloudflare-zero-trust = {
          displayName = "Cloudflare Zero Trust";
          originUrl = "https://${domainSld}.cloudflareaccess.com/cdn-cgi/access/callback";
          originLanding = "https://${domainSld}.cloudflareaccess.com";
          basicSecretFile = getBasicSecretPath "cloudflare-zero-trust";
          preferShortUsername = true;
          scopeMaps."cf-zero-trust.access" = [
            "openid"
            "email"
            "profile"
          ];
        };
        grafana = {
          displayName = "Grafana";
          originUrl = "https://grafana.${domain}/login/generic_oauth";
          originLanding = "https://grafana.${domain}/";
          basicSecretFile = getBasicSecretPath "grafana";
          preferShortUsername = true;
          scopeMaps."grafana.access" = [
            "openid"
            "email"
            "profile"
            "groups"
          ];
          claimMaps."grafana_role" = {
            joinType = "array";
            valuesByGroup = {
              "grafana.server-admins" = [
                "GrafanaAdmin"
              ];
              "grafana.admins" = [
                "Admin"
              ];
              "grafana.editors" = [
                "Editor"
              ];
              "grafana.viewers" = [
                "Viewer"
              ];
            };
          };
        };
      };
    };

    grafana = {
      settings = {
        security = {
          disable_initial_admin_creation = true;
        };

        auth.disable_login_form = true;
        "auth.basic".enabled = false;
        "auth.generic_oauth" =
          let
            idm = "https://${config.services.kanidm.serverSettings.domain}";
          in
          {
            enabled = true;
            auto_login = true;
            allow_signup = true;
            allow_assign_grafana_admin = true;
            icon = "signin";
            name = "Kanidm";
            client_id = "grafana";
            client_secret = "$__file{/run/credentials/grafana.service/GENERIC_OAUTH_CLIENT_KEY}";
            use_pkce = true;
            use_refresh_token = true;
            scopes = "openid,email,profile,groups";
            login_attribute_path = "preferred_username";
            auth_url = "${idm}/ui/oauth2";
            token_url = "${idm}/oauth2/token";
            api_url = "${idm}/oauth2/openid/grafana/userinfo";
            groups_attribute_path = "groups";
            role_attribute_path = "contains(grafana_role[*], 'GrafanaAdmin') && 'GrafanaAdmin' || contains(grafana_role[*], 'Admin') && 'Admin' || contains(grafana_role[*], 'Editor') && 'Editor' || contains(grafana_role[*], 'Viewer') && 'Viewer' || 'NoAccess'";
            role_attribute_strict = true;
            # signout_redirect_url = "${auth}/" # https://github.com/kanidm/kanidm/issues/1997
          };

      };
    };
  };

  systemd.services.grafana = mkIf config.services.grafana.enable {
    serviceConfig = {
      LoadCredential = "GENERIC_OAUTH_CLIENT_KEY:${getBasicSecretPath "grafana"}";
    };
  };

  clan.core.vars.generators = {
    kanidm-oauth2 =
      let
        commonFile = {
          owner = "kanidm";
          group = "kanidm";
        };
      in
      self.lib.generators.mkPasswords pkgs {
        "cloudflare-zero-trust" = {
          # Cloudflare is not a fan of the symbols
          symbols = false;
          file = commonFile // {
            restartUnits = [ "kanidm.service" ];
          };
        };
        "grafana" = {
          file = commonFile // {
            restartUnits = [
              "kanidm.service"
              "grafana.service"
            ];
          };
        };
      };
  };
}
