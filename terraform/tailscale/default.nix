# TODO: add more acls based on tag
# - server:nginx
# - server:dns
{
  self,
  config,
  lib,
  ...
}:
let
  inherit (builtins) elem mapAttrs filter;
  inherit (lib.trivial) const;
  inherit (lib.attrsets) filterAttrs mapAttrs' nameValuePair;

  inherit (self.inputs.infra) infra;
  inherit (self.inputs.infra.clanInternals) inventory;

  tailscaleVarsDirectory = "../../vars/shared/tailscale-oauth";
  usefulTags = [
    "server"
    "personal"
  ];

  filterTags = filter (tag: elem tag usefulTags);

  machinesWithTaiscaleTag = filterAttrs (const (
    machine: elem "tailscale" machine.tags
  )) inventory.machines;
  mkAcl = src: dst: { inherit src dst; };
  inherit (config.ewood.tailscale.tags) tags;

  machines = mapAttrs' (const (machine: nameValuePair machine.name machine)) machinesWithTaiscaleTag;
in
{
  imports = [
    ./interface.nix
  ];

  terraform = {
    required_providers = {
      tailscale = {
        source = "tailscale/tailscale";
        version = "~> 0.20";
      };
    };
  };

  locals = {
    # tailscale_api_key = "\${ ephemeral.sops_file.tailscale_api_token.raw }";
    tailscale_client_id = "\${ ephemeral.sops_file.tailscale_client_id.raw }";
    tailscale_client_secret = "\${ ephemeral.sops_file.tailscale_client_secret.raw }";
  };

  provider = {
    tailscale = {
      # api_key = "\${ local.tailscale_api_key }";
      oauth_client_id = "\${ local.tailscale_client_id }";
      oauth_client_secret = "\${ local.tailscale_client_secret }";
      tailnet = infra.tailnet;
    };
  };

  ephemeral = {
    sops_file.tailscale_client_id = {
      source_file = "${tailscaleVarsDirectory}/client-id/secret";
      input_type = "raw";
    };
    sops_file.tailscale_client_secret = {
      source_file = "${tailscaleVarsDirectory}/client-secret/secret";
      input_type = "raw";
    };
  };

  ewood.tailscale = {
    tailnet = infra.tailnet;

    tags.tagNames = [
      "managed-by-infra-terraform"
    ] ++ usefulTags;

    acl.acls = [
      (mkAcl tags.personal "*:*")
      (mkAcl tags.server "${tags.server}:*")
    ];

    # devices = { };
    devices = mapAttrs (const (machine: {
      tags = [ tags."managed-by-infra-terraform" ] ++ (map (tag: tags.${tag}) (filterTags machine.tags));
    })) machines;

  };

  resource = {
    tailscale_dns_preferences."default" = {
      magic_dns = true;
    };

    tailscale_dns_split_nameservers."domain" = {
      domain = infra.domain;
      nameservers = config.ewood.tailscale.devices."arnold".addresses;
    };
  };
}
