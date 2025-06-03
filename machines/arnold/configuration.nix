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

    ./modules/kanidm.nix
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
