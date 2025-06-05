{

  imports = [
    ./provider.nix
    ./tunnels.nix
    ./zero-trust-oauth2.nix
  ];

  data = {
    cloudflare_dns_records.infra-terraform = {
      zone_id = "\${ local.cloudflare_zone_id }";
      comment = {
        # present = "present";
        startswith = "created-by:terraform-infra";
      };
    };
  };
}
