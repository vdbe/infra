{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (self.infra) domain;
in
{
  imports = [
    self.nixosModules.custom-firewall
    self.nixosModules.custom-nginx
    self.nixosModules.custom-grafana

    ./modules/kanidm
    ./modules/coredns.nix
  ];

  ewood = {
    # Perl is required for the wifi clan service
    perlless.forbidPerl = false;
    grafana.enable = true;
    nginx = {
      enable = true;
      domain = domain;
      commonVirtualHostOptions = {
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
      };
    };
    firewall.interfaces = {
      "lan" = {
        name = [
          "end0"
          "wlan0"
        ];
        blockFromLAN.enable = true;
        allowedTCPPorts = [
          443
        ];
      };
    };
  };

  services = {
    nginx = {
      commonHttpConfig = ''
        # Get real ip
        set_real_ip_from  localhost;
        real_ip_header CF-Connecting-IP;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      '';
    };
    # grafana = {
    #   # settings.server.root_url = "https://grafana.${domain}";
    # };
  };

  users = {
    mutableUsers = false;
    users = {
      user = {
        isNormalUser = true;
        openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;

        extraGroups = [ "wheel" ];
      };
    };
  };

}
