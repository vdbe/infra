{ self, ... }:
let
  domain = self.inputs.infra.infra.domain;

  oauth2VarsDirectory = "../../vars/per-machine/arnold/kanidm-oauth2";
  client_id = "cloudflare-zero-trust";
in
{

  data = {
    sops_file.cloudflare_zero_trust_oidc_client_secret = {
      source_file = "${oauth2VarsDirectory}/cloudflare-zero-trust/secret";
      input_type = "raw";
    };

    cloudflare_zero_trust_access_identity_providers."domain" = {
      # account_id = "\${ local.cloudflare_account_id }";
      zone_id = "\${ local.cloudflare_zone_id }";

    };
  };

  resource = {
    cloudflare_zero_trust_access_identity_provider."kanidm" = {
      name = "kanidm";
      type = "oidc";
      zone_id = "\${ local.cloudflare_zone_id }";

      config = {
        claims = [ ];
        scopes = [
          "openid"
          "email"
          "profile"
        ];

        inherit client_id;
        client_secret = "\${ data.sops_file.cloudflare_zero_trust_oidc_client_secret.raw }";
        auth_url = "https://idm.${domain}/ui/oauth2";
        token_url = "https://idm.${domain}/oauth2/token";
        certs_url = "https://idm.${domain}/oauth2/openid/${client_id}/public_key.jwk";
        pkce_enabled = true;
      };

      scim_config = {
        enable = false;
        identity_update_behavior = "automatic";
        user_deprovision = true;
        seat_deprovision = true;
      };
    };
  };
}
