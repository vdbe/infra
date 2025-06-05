{
  self,
  lib,
  ...
}:
let

  inherit (builtins) mapAttrs attrValues listToAttrs;
  inherit (lib.lists) flatten;
  inherit (lib.attrsets) nameValuePair;
  inherit (lib.strings) hasSuffix removeSuffix;

  domain = self.inputs.infra.infra.domain;
  machineTunnelSettings = self.lib.getMachinesSettings "tunnel" "default";

  cloudflare_dns_records = listToAttrs (
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
              nameValuePair "${recordName}-cname" {
                zone_id = "\${ local.cloudflare_zone_id }";
                name = recordName;
                content = "\${ cloudflare_zero_trust_tunnel_cloudflared_config.${tunnelName}.tunnel_id }.cfargotunnel.com";

                comment = "created-by:terraform-infra-tunnels";

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
in
{
  resource = {
    cloudflare_dns_record = cloudflare_dns_records;

    # cloudflare_zero_trust_tunnel_cloudflared = mapAttrs (name: settings: {
    #   name = "infra-${name}";
    #   account_id = "\${ local.cloudflare_account_id }";
    #   config_src = "cloudflare";
    # }) machineTunnelSettings;

    cloudflare_zero_trust_tunnel_cloudflared_config = mapAttrs (name: settings: {
      tunnel_id = settings.tunnel_id;
      account_id = "\${ local.cloudflare_account_id }";
      source = "cloudflare";

      config = {
        ingress = (attrValues settings.ingress) ++ [ settings.default ];
        inherit (settings) origin_request;
      };

    }) machineTunnelSettings;
  };

  # data = {
  #   # Waiting on: https://github.com/cloudflare/terraform-provider-cloudflare/issues/5524
  #   # Should be in next release
  #   cloudflare_zero_trust_tunnel_cloudflared = {
  #     test = {
  #       account_id = "\${ local.cloudflare_account_id }";
  #       filter = {
  #         name = "infra-buckbeak";
  #         was_active_at = "2025-06-05T10:00:00Z";
  #         was_inactive_at = "2025-06-05T10:00:00Z";
  #       };
  #     };
  #   };
  # };

}
