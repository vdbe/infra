{
  self,
  config,
  lib,
  ...
}:
{
  ewood = {
    # Perl is required for the wifi clan service
    perlless.forbidPerl = false;
    firewall.interfaces = {
      "end0" = {
        roles = [ "blockFromLAN" ];
      };
      "wlan0" = {
        roles = [ "blockFromLAN" ];
      };
    };
    # Proxy to a python http server to test everyting
    nginx = {
      enable = true;
      reverseProxies = {
        "test.ewood.dev" = {
          addresses = "127.0.0.1:8000";
          protocol = "http";
          virtualHostOptions = {
            enableACME = true;
            acmeRoot = null;

            addSSL = true;
            # forceSSL = true;

            locations."/" = {
              proxyWebsockets = true;
            };
          };
        };
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
