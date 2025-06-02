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
  ];

  ewood = {
    # Perl is required for the wifi clan service
    perlless.forbidPerl = false;
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
    nginx = {
      enable = true;
      reverseProxies = {
        # Proxy to a python http server for testing
        "test.ewood.dev" = {
          addresses = "127.0.0.1:8000";
          protocol = "http";
          virtualHostOptions = {
            enableACME = false;
            acmeRoot = null;
            sslCertificate =
              config.clan.core.vars.generators."nginx-server-test.ewood.dev".files."fullchain".path;
            sslCertificateKey = config.clan.core.vars.generators."nginx-server-test.ewood.dev".files."key".path;

            addSSL = true;
            forceSSL = true;

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

  clan.core.vars.generators = {
    "nginx-server-test.ewood.dev" = self.lib.generators.mkSignedCert pkgs {
      signer = "root-ca";
      owner = "nginx";
      group = "nginx";

      subj = "/O=Infra/CN=test.ewood.dev";
      extfile = ''
        basicConstraints=critical,CA:FALSE
        keyUsage=critical,digitalSignature,keyEncipherment
        extendedKeyUsage=serverAuth
        subjectAltName=DNS:test.ewood.dev
      '';
    };
  };
}
