{ self, ... }:

let
  inherit (self.infra) domain;
in
{
  imports = [
    ./server.nix
    ./oauth2.nix
  ];

  services.kanidm.provision = {
    persons = {
      "vdbe" = {
        displayName = "vdbe";
        legalName = "vdbe";
        mailAddresses = [ "vdbe@${domain}" ];

        groups = [
          "cf-zero-trust.access"
          "grafana.server-admins"
        ];
      };
    };
  };
}
