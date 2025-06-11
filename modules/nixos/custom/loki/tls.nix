{
  pkgs,
  config,
  lib,
  self,
  ...
}:
let
  lcfg = config.services.loki;
  generators = config.clan.core.vars.generators;

  certWitRoot =
    cert:
    pkgs.runCommandNoCCLocal "${cert}-with-root" { } ''
      cat ${generators.${cert}.files."fullchain".path} ${generators."root-ca".files."cert".path} > $out
    '';

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

  # https://github.com/grafana/dskit/blob/c9115f6be261892a1ee2dd31af6664deb758784c/crypto/tls/tls.go#L28-L38
  tls_client_config =
    let
      cert = getCert "loki-loki-server-client";
    in
    {
      tls_server_name = "localhost";
      tls_ca_path = config.clan.core.vars.generators."loki-server-ca".files."cert".path;

      tls_cert_path = cert."fullchain";
      tls_key_path = cert.key;
    };

  tls_server_config =
    let
      cert = getCert "loki-server-cert";
    in
    {
      client_ca_file = config.clan.core.vars.generators."loki-server-ca".files."cert".path;
      client_auth_type = "RequireAndVerifyClientCert";

      cert_file = cert."fullchain";
      key_file = cert.key;
    };

  # https://github.com/grafana/dskit/blob/c9115f6be261892a1ee2dd31af6664deb758784c/grpcclient/grpcclient.go#L27-L58
  grpc_client_config = {
    tls_enabled = true;
    grpc_compression = "snappy";
  } // tls_client_config;

in
{
  config = {
    assertions = [
      {
        assertion = config.users.users ? loki && config.users.users ? nginx;
        message = ''
          Not all required users for sops exist, deploying will crash sops
        '';
      }
    ];

    services.loki = {
      configuration = {
        # https://github.com/grafana/dskit/blob/c9115f6be261892a1ee2dd31af6664deb758784c/server/server.go#L77-L163
        server = {
          # grpc_listen_address = "localhost";
          http_tls_config = tls_server_config // {
            # client_auth_type = "NoClientCert";
            # client_auth_type = "RequestClientCert";
            # client_auth_type = "RequireAnyClientCert";
            # client_auth_type = "VerifyClientCertIfGiven";
            # client_auth_type = "RequireAndVerifyClientCert";
          };
          grpc_tls_config = tls_server_config;
        };

        frontend = {
          inherit grpc_client_config;
        };

        query_scheduler = {
          inherit grpc_client_config;
        };

        frontend_worker = {
          query_frontend_grpc_client = grpc_client_config;
          query_scheduler_grpc_client = grpc_client_config;
        };

        compactor_grpc_client = grpc_client_config;

        pattern_ingester = {
          client_config = {
            inherit grpc_client_config;
          };
        };

        ingester_client = {
          inherit grpc_client_config;
        };
      };
    };

    clan.core.vars.generators = {
      # Used for mtls auth between:
      # - nginx -> loki
      # - loki -> loki
      loki-server-ca = self.lib.generators.mkRootCA pkgs {
        pathlen = 0;
        subj = "/O=Infra/OU=Loki/L=${config.clan.core.machineName}/CN=Loki Server Root CA";
      };
      loki-server-cert = self.lib.generators.mkSignedCert pkgs {
        signer = "loki-server-ca";
        restartUnits = [ "loki.service" ];
        owner = "loki";
        group = "loki";

        subj = "/O=Infra/OU=Loki/L=${config.clan.core.machineName}/CN=localhost";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=serverAuth
          subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1
        '';
      };
      loki-loki-server-client = self.lib.generators.mkSignedCert pkgs {
        signer = "loki-server-ca";
        restartUnits = [ "loki.service" ];
        owner = "loki";
        group = "loki";

        subj = "/O=Infra/OU=Loki/L=${config.clan.core.machineName}/CN=Loki Client";
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
