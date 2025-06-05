{
  self,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    self.nixosModules.custom-firewall
    self.nixosModules.custom-nginx

    ./modules/kanidm
  ];

  ewood = {
    # Perl is required for the wifi clan service
    perlless.forbidPerl = false;
    nginx.enable = true;
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
