{ self, ... }:
let
  cloudflareVarsDirectory = "../../vars/shared/cloudflare";
  domain = self.inputs.infra.infra.domain;
in
{

  terraform = {
    required_providers = {
      cloudflare = {
        source = "cloudflare/cloudflare";
        version = "~> 5.5";
      };
    };
  };

  provider = {
    cloudflare = {
      api_token = "\${ local.cloudflare_api_token }";
    };
  };

  locals = {
    cloudflare_api_token = "\${ ephemeral.sops_file.cloudflare_api_token.raw }";
    cloudflare_account_id = "\${ data.cloudflare_zones.domain.result[0].account.id }";
    cloudflare_zone_id = "\${ data.cloudflare_zones.domain.result[0].id }";
  };

  ephemeral = {
    sops_file.cloudflare_api_token = {
      source_file = "${cloudflareVarsDirectory}/api-token/secret";
      input_type = "raw";
    };
  };

  data = {
    cloudflare_zones."domain" = {
      name = domain;
    };
  };
}
