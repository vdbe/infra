{ self, lib, ... }:
let
  inherit (builtins) mapAttrs attrValues listToAttrs;
  inherit (lib.lists) flatten;
  inherit (lib.attrsets) mapAttrsToList nameValuePair;
  inherit (lib.strings) hasSuffix removeSuffix;

  domain = self.inputs.infra.infra.domain;
  machineTunnelSettings = self.lib.getMachinesSettings "tunnel" "default";
in
{
  terraform = {
    required_providers = {
      cloudflare = {
        source = "cloudflare/cloudflare";
        version = "~> 5";
      };
    };
  };

  provider = {
    cloudflare = {
      api_token = "\${ local.api_token }";
    };
  };

  locals = {
    api_token = "\${ ephemeral.sops_file.cloudflare_api_token.raw }";
    account_id = "\${ data.sops_file.cloudflare_account_id.raw }";
    zone_id = "\${ data.sops_file.cloudflare_zone_id.raw }";
  };

  ephemeral = {
    sops_file.cloudflare_api_token = {
      source_file = "../../vars/shared/cloudflare/api-token/secret";
      input_type = "raw";
    };
  };

  data = {
    sops_file = {
      cloudflare_account_id = {
        source_file = "../../vars/shared/cloudflare/account-id/secret";
        input_type = "raw";
      };
      cloudflare_zone_id = {
        source_file = "../../vars/shared/cloudflare/zone-id/secret";
        input_type = "raw";
      };
    };
  };

  import = flatten (
    mapAttrsToList (name: settings: [
      {
        to = "cloudflare_zero_trust_tunnel_cloudflared.${name}";
        id = "\${ local.account_id }/${settings.tunnel_id}";

      }
    ]) machineTunnelSettings
  );

  resource = {
    cloudflare_dns_record = listToAttrs (
      flatten (
        attrValues (
          mapAttrs (
            tunnelName: settings:
            let
              # Get every ingress for our domain
              ingresses = lib.filter (
                ingress: (ingress.hostname != null) && (hasSuffix domain ingress.hostname)
              ) ((attrValues settings.ingress) ++ [ settings.default ]);
              # name = removeSuffix domain settings.hostname;

              mkDnsRecord =
                ingress:
                let
                  recordName = removeSuffix ".${domain}" ingress.hostname;
                in
                nameValuePair "${tunnelName}-${recordName}" {
                  zone_id = "\${ local.zone_id }";
                  name = recordName;
                  content = "\${ cloudflare_zero_trust_tunnel_cloudflared_config.${tunnelName}.tunnel_id }.cfargotunnel.com";

                  type = "CNAME";
                  ttl = 1;
                  proxied = true;
                };
            in
            map mkDnsRecord ingresses
          ) machineTunnelSettings
        )
      )
    );

    cloudflare_zero_trust_tunnel_cloudflared = mapAttrs (name: settings: {
      inherit name;
      account_id = "\${ local.account_id }";
      config_src = "cloudflare";
    }) machineTunnelSettings;

    cloudflare_zero_trust_tunnel_cloudflared_config = mapAttrs (name: settings: {
      inherit (settings) tunnel_id;
      account_id = "\${ local.account_id }";
      source = "cloudflare";

      config = {
        ingress = (attrValues settings.ingress) ++ [ settings.default ];
        inherit (settings) origin_request;
      };

    }) machineTunnelSettings;
  };
}
