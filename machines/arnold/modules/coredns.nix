{
  config,
  lib,
  self,
  pkgs,
  mypkgs,
  ...
}:
let
  inherit (builtins) elem mapAttrs split;
  inherit (lib.trivial) const;
  inherit (lib.attrsets) filterAttrs recursiveUpdate mapAttrsToList;
  inherit (lib.lists) last;
  inherit (lib.strings) removeSuffix;

  inherit (self.infra) domain tailnet;
  inherit (self.clanInternals) inventory;

  tailScaleInterfaceName = config.services.tailscale.interfaceName;

  machinesWithTaiscaleTag = filterAttrs (const (
    machine: elem "tailscale" machine.tags
  )) inventory.machines;

  transformedTailmachines = mapAttrs (const (
    machine:
    recursiveUpdate machine {
      # Remove possible user from targetHost
      # TODO: remove possible port from targetHost
      deploy.targetHost = last (split "@" machine.deploy.targetHost);
    }
  )) machinesWithTaiscaleTag;

  tailMachinesCNAMES = mapAttrsToList (const (
    machine:
    let
      alias = removeSuffix ".${domain}" machine.deploy.targetHost;
    in
    "${alias} IN CNAME ${machine.name}.${tailnet}."
  )) transformedTailmachines;

  mkCNAME =
    alias: machine: "${alias} IN CNAME ${transformedTailmachines.${machine}.deploy.targetHost}.";

  file = pkgs.writeText "${domain}.db" ''
    $TTL 3600

    @   IN  SOA ns.${domain}. admin.${domain}. (
            2025052601 ; serial
            3600       ; refresh
            1800       ; retry
            604800     ; expire
            60         ; minimum
    )

      IN  NS ns.${domain}.

    ns IN CNAME ${config.networking.hostName}.${tailnet}.
    ${lib.concatLines tailMachinesCNAMES}

    ${mkCNAME "grafana" "arnold"}
    ${mkCNAME "prometheus" "arnold"}
    ${mkCNAME "idm" "arnold"}
  '';

in
{
  ewood = {
    firewall.interfaces = {
      ${tailScaleInterfaceName} = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };
    };
  };

  services = {
    coredns = {
      package = pkgs.coredns.overrideAttrs (old: {
        version = "git-vdbe";
        src = pkgs.fetchFromGitHub {
          owner = "vdbe";
          repo = "coredns";
          rev = "873de9032df3bd47ecc5be0ac2af0b7b1aed0218";
          # sha256 = pkgs.lib.fakeSha256;
          sha256 = "sha256-uAaLpjd0U/NW1b3nUeCAA/FxE4NIM7AFOwynkCd/cbE=";
        };

        vendorHash = "sha256-f0KeZ6XAcjWB9wCAO3dbp307PmmAWgtbBkwpeEm6FOk=";

      });
      enable = true;
      config = ''
        "${domain}:53" {
          bind ${tailScaleInterfaceName}
          errors
          log
          file ${file} ${domain} {
            fallthrough
          }
          forward . 1.1.1.1 1.0.0.1
          cache 30
          loop
          # reload
          loadbalance
        }
      '';
    };
  };

  systemd.services.coredns = {
    after = [
      "tailscaled.service"
    ];
    requires = [
      "tailscaled.service"
    ];
    serviceConfig = {
      ExecStartPre = "${lib.getExe mypkgs.wait-online} --interface ${tailScaleInterfaceName} --ipv4 --ipv6";
    };
  };

}
