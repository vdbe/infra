{
  pkgs,
  lib,
  config,
  self,
  ...
}:
let
  lcfg = config.services.loki;
  generators = config.clan.core.vars.generators;

  reverseProxy = config.ewood.nginx.reverseProxies."loki";
  proxyPass = "https://${reverseProxy.domain}";

  getCert =
    generator:
    let
      files = generators.${generator}.files;
    in
    {
      cert = files."cert".path;
      chain = files."chain".path;
      fullchain = files."fullchain".path;
      key = files."key".path;
    };
in
{
  config = {
    ewood.nginx.reverseProxies."loki" = {
      addresses = "${lcfg.configuration.server.http_listen_address}:${builtins.toString lcfg.configuration.server.http_listen_port}";
      protocol = "https";

      virtualHostOptions =
        let
          client = getCert "nginx-loki-server-client";
          cert = getCert "loki-nginx-cert";
        in
        {
          enableACME = false;
          sslCertificate = cert.cert;
          sslCertificateKey = cert.key;

          # TODO: Use self signed cert
          extraConfig = ''
            # Enable upstream server validation
            proxy_ssl_trusted_certificate ${
              # Nginx doesn't trust the system defined CA bundle,
              # so the trusted cert need to include the root cert
              generators."loki-server-ca".files."cert".path
            };
            proxy_ssl_verify on;
            proxy_ssl_verify_depth 1;
            proxy_ssl_name localhost;

            # mTLS upstream: provide client cert/key
            proxy_ssl_certificate     ${client.fullchain};
            proxy_ssl_certificate_key  ${client.key};


            # mTLS auth
            ssl_client_certificate ${generators."loki-ca".files."cert".path};
            ssl_verify_client on;
            ssl_verify_depth 1;

            # Don't think this is needed since wrong certs seem to error with
            # '400 The SSL certificate error' but better safe then sorry
            if ($ssl_client_verify != "SUCCESS") {
              return 403 "Client certificate verification failed: $ssl_client_verify";
            }
          '';

          locations = {
            # https://grafana.com/docs/loki/latest/reference/loki-http-api/
            "= /loki/api/v1/push" = {
              priority = 100;
              proxyWebsockets = true;
              inherit proxyPass;
              extraConfig = ''
                if ($ssl_client_s_dn !~ "CN=alloy_client.*") {
                    return 403 "Access Denied: Only Loki pushers are allowed to push logs.";
                }
              '';
            };

            # TODO: Alerts from loki?
            "~ ^/loki/api/v1/(query|label|index|patterns|tail|detected_labels|detected_fields)" = {
              priority = 150;
              proxyWebsockets = true;
              inherit proxyPass;
              extraConfig = ''
                if ($ssl_client_s_dn !~ "CN=grafana_client.*") {
                    return 403 "Access Denied: Only Loki queries are allowed to query logs.";
                }
              '';
            };

            "/" = lib.mkForce {
              extraConfig = ''
                return 403 "Access Denied";
              '';
            };
          };
        };
    };

    services = {
      grafana = {
        provision = {
          enable = lib.mkDefault true;

          datasources.settings = {
            datasources = [
              (lib.mkIf config.services.loki.enable {
                name = "Loki";
                type = "loki";
                url = "https://localhost";
                jsonData = {
                  serverName = "${reverseProxy.domain}";
                  tlsAuth = true;
                  tlsAuthWithCACert = true;
                  httpHeaderName1 = "Host";
                };
                secureJsonData = {
                  httpHeaderValue1 = "${reverseProxy.domain}";
                  # tlsCACert = "$__file{${config.clan.core.vars.generators."loki-ca".files."cert".path}}";
                  tlsClientCert = "$__file{${
                    config.clan.core.vars.generators."grafana-loki-client".files."cert".path
                  }}";
                  tlsClientKey = "$__file{${
                    config.clan.core.vars.generators."grafana-loki-client".files."key".path
                  }}";
                };
              })
            ];
          };
        };
      };

    };

    clan.core.vars.generators = {
      # Used for mtls auth between:
      # - grafana -> nginx:loki
      # - alloy-> nginx:loki
      loki-ca = self.lib.generators.mkRootCA pkgs {
        share = true;

        pathlen = 0;
        subj = "/O=Infra/OU=Loki/L=${config.clan.core.machineName}/CN=Loki Root CA";
      };
      "loki-nginx-cert" = self.lib.generators.mkSignedCert pkgs {
        signer = "root-ca";
        owner = "nginx";
        group = "nginx";
        restartUnits = [ "nginx.service" ];

        subj = "/O=Infra/OU=Loki/L=${config.clan.core.machineName}/CN=${reverseProxy.domain}";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=serverAuth
          subjectAltName=DNS:${reverseProxy.domain}
        '';
      };
      nginx-loki-server-client = self.lib.generators.mkSignedCert pkgs {
        signer = "loki-server-ca";
        owner = "nginx";
        group = "nginx";
        restartUnits = [ "nginx.service" ];

        subj = "/O=Infra/OU=Loki/L=${config.clan.core.machineName}/CN=Nginx Client";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=clientAuth
          subjectAltName=DNS:localhost
        '';
      };
      alloy-loki-client = self.lib.generators.mkSignedCert pkgs {
        # We want these clients to access any of our loki servers (I think)
        signer = "loki-ca";
        restartUnits = [ "nginx.service" ];

        subj = "/O=Infra/OU=Loki/L=${config.clan.core.machineName}/CN=alloy_client";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=clientAuth
          subjectAltName=DNS:localhost
        '';
      };
      grafana-loki-client = self.lib.generators.mkSignedCert pkgs {
        # We want these clients to access any of our loki servers (I think)
        signer = "loki-ca";
        owner = "grafana";
        group = "grafana";
        restartUnits = [ "grafana.service" ];

        subj = "/O=Infra/OU=Loki/L=${config.clan.core.machineName}/CN=grafana_client";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=clientAuth
          subjectAltName=DNS:localhost
        '';
      };
    };
  };
}
