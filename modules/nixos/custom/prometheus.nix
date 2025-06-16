{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  lcfg = config.services.prometheus;
  generators = config.clan.core.vars.generators;

  reverseProxy = config.ewood.nginx.reverseProxies."prometheus";
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
    ewood.nginx.reverseProxies."prometheus" =
      let
        client = getCert "nginx-promtheus-server-client";
        cert = getCert "prometheus-nginx-cert";
      in
      {
        addresses = "localhost:${builtins.toString lcfg.port}";
        protocol = "https";

        virtualHostOptions = {
          enableACME = false;
          sslCertificate = cert.cert;
          sslCertificateKey = cert.key;
          extraConfig = ''
            # Enable upstream server validation
            proxy_ssl_trusted_certificate ${
              # Nginx doesn't trust the system defined CA bundle,
              # so the trusted cert need to include the root cert
              generators."prometheus-server-ca".files."cert".path
            };
            proxy_ssl_verify on;
            proxy_ssl_verify_depth 1;
            proxy_ssl_name localhost;

            # mTLS upstream: provide client cert/key
            proxy_ssl_certificate     ${client.fullchain};
            proxy_ssl_certificate_key  ${client.key};

            # # mTLS auth
            ssl_client_certificate ${generators."prometheus-ca".files."cert".path};
            ssl_verify_client on;
            ssl_verify_depth 1;

            # Don't think this is needed since wrong certs seem to error with
            # '400 The SSL certificate error' but better safe then sorry
            if ($ssl_client_verify != "SUCCESS") {
              return 403 "Client certificate verification failed: $ssl_client_verify";
            }
          '';

          locations = {
            "= /api/v1/write" = {
              priority = 100;
              inherit proxyPass;

              extraConfig = ''
                if ($ssl_client_s_dn !~ "CN=alloy_client.*") {
                    return 403 "Access Denied: Only loki pushers are allowed to push logs.";
                }

                # Just to reduce the noise
                if ($status = "204") {
                    access_log off;
                }
                access_log off;
              '';
            };
            "~ ^/api/v1/(query|label|rules|status/buildinfo)" = {
              priority = 150;
              proxyWebsockets = true;
              inherit proxyPass;
              extraConfig = ''
                if ($ssl_client_s_dn !~ "CN=grafana_client.*") {
                    return 403 "Access Denied: Only prometheus queries are allowed to query logs.";
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
      prometheus = {
        enable = lib.mkDefault true;
        # scrapeConfigs = prometheusScrapeConfigs;
        # Errors on `/run/credentials/prometheus.service/KEY_FILE` for full checks
        checkConfig = "syntax-only";
        webExternalUrl = "https://${reverseProxy.domain}";
        listenAddress = "localhost";
        extraFlags = [
          "--web.enable-remote-write-receiver"
        ];

        webConfigFile =
          let
            cert = getCert "prometheus-server-cert";
          in
          (pkgs.formats.yaml { }).generate "prometheus-exporter-webConfigFile" {
            tls_server_config = {
              client_ca_file = config.clan.core.vars.generators."prometheus-server-ca".files."cert".path;

              cert_file = cert."cert";
              key_file = cert."key";

              client_auth_type = "RequireAndVerifyClientCert";
              # client_auth_type = "VerifyClientCertIfGiven";
            };
          };
      };
      grafana = {
        provision = {
          enable = lib.mkDefault true;

          datasources.settings = {
            datasources = [
              (lib.mkIf config.services.prometheus.enable {
                name = "Prometheus";
                type = "prometheus";
                url = "https://localhost";
                jsonData = {
                  serverName = "${reverseProxy.domain}";
                  tlsAuth = true;
                  tlsAuthWithCACert = true;
                  httpHeaderName1 = "Host";
                };
                secureJsonData = {
                  httpHeaderValue1 = "${reverseProxy.domain}";
                  # tlsCACert = "$__file{${config.clan.core.vars.generators."prometheus-ca".files."cert".path}}";
                  tlsClientCert = "$__file{${
                    config.clan.core.vars.generators."grafana-prometheus-client".files."cert".path
                  }}";
                  tlsClientKey = "$__file{${
                    config.clan.core.vars.generators."grafana-prometheus-client".files."key".path
                  }}";
                };
              })
            ];
          };
        };
      };
    };
    clan.core.vars.generators = {
      # Used for mtls auth between
      # alloy -> nginx:prometheus
      prometheus-ca = self.lib.generators.mkRootCA pkgs {
        pathlen = 0;
        subj = "/O=Infra/OU=Prometheus/L=${config.clan.core.machineName}/CN=Prometheus Root CA";
      };

      # Used for mtls auth between:
      # - nginx -> prometheus
      prometheus-server-ca = self.lib.generators.mkRootCA pkgs {
        pathlen = 0;
        subj = "/O=Infra/OU=Prometheus/L=${config.clan.core.machineName}/CN=Prometheus Server Root CA";
      };
      "prometheus-nginx-cert" = self.lib.generators.mkSignedCert pkgs {
        signer = "root-ca";
        owner = "nginx";
        group = "nginx";
        restartUnits = [ "nginx.service" ];

        subj = "/O=Infra/OU=Prometheus/L=${config.clan.core.machineName}/CN=${reverseProxy.domain}";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=serverAuth
          subjectAltName=DNS:${reverseProxy.domain}
        '';
      };
      prometheus-server-cert = self.lib.generators.mkSignedCert pkgs {
        signer = "prometheus-server-ca";
        restartUnits = [ "prometheus.service" ];
        owner = "prometheus";
        group = "prometheus";

        subj = "/O=Infra/OU=Prometheus/L=${config.clan.core.machineName}/CN=localhost";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=serverAuth
          subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1
        '';
      };
      nginx-promtheus-server-client = self.lib.generators.mkSignedCert pkgs {
        signer = "prometheus-server-ca";
        restartUnits = [ "loki.service" ];
        owner = "nginx";
        group = "nginx";

        subj = "/O=Infra/OU=Prometheus/L=${config.clan.core.machineName}/CN=Nginx Client";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=clientAuth
          subjectAltName=DNS:localhost
        '';
      };
      alloy-prometheus-client = self.lib.generators.mkSignedCert pkgs {
        # We want these clients to access any of our loki servers (I think)
        signer = "prometheus-ca";
        restartUnits = [ "nginx.service" ];

        subj = "/O=Infra/OU=Loki/L=${config.clan.core.machineName}/CN=alloy_client";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=clientAuth
          subjectAltName=DNS:localhost
        '';
      };
      grafana-prometheus-client = self.lib.generators.mkSignedCert pkgs {
        # We want these clients to access any of our loki servers (I think)
        signer = "prometheus-ca";
        owner = "grafana";
        group = "grafana";
        restartUnits = [ "grafana.service" ];

        subj = "/O=Infra/OU=prometheus/L=${config.clan.core.machineName}/CN=grafana_client";
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
