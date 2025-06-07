# TODO: ingergrate with `self.nixosModules.custom-nginx`
# might need to add a domain option for it in the nginx module
{
  config,
  options,
  lib,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkDefault mkMerge mkIf;
  inherit (lib.trivial) warnIfNot;
  inherit (lib.lists) optionals;

  cfg = config.ewood.grafana;
  lcfg = config.services.grafana;
in
{
  options.ewood.grafana = {
    enable = mkEnableOption "grafana";
    setupDatabase = mkOption {
      type = types.bool;
      default = true;
      description = "Setup the grafana database";
    };
    setupNginxReverseProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Setup the nginx reverseProxy";
    };
    socket = mkOption {
      type = types.bool;
      default = true;
      description = "Use a socket instead of inet";
    };
  };

  config = mkIf cfg.enable {
    assertions =
      [
        (mkIf (lcfg.enable && cfg.enable && cfg.setupDatabase) {
          assertion = config.services.postgresql.enable;
          message = "Grafana is enabled with database setup but postgresql is not enabled, please enable this";
        })
      ]
      ++ optionals cfg.setupNginxReverseProxy [
        {
          assertion = options.ewood ? nginx;
          message = "The grafana module request the nginx module, please import it";
        }
        {
          assertion = config.ewood.nginx.enable;
          message = "grafana reverse proxy enabled but nginx is not enabled";
        }
      ];
    users.groups = {
      "grafana-socket" = {
        gid = 60578; # https://systemd.io/UIDS-GIDS/#summary
        members = [
          config.systemd.services.grafana.serviceConfig.User
          config.services.nginx.user
        ];
      };
    };

    ewood.nginx.reverseProxies."grafana" =
      let
        server = lcfg.settings.server;
        addresses =
          if server.protocol == "socket" then
            "unix:${server.socket}"
          else
            "${server.http_addr}:${server.http_port}";
      in
      mkIf cfg.setupNginxReverseProxy {
        inherit addresses;
        protocol = if server.protocol == "https" then "https" else "http";
      };

    services = {
      postgresql = {
        enable = mkDefault true;

        ensureDatabases = [
          "grafana"
        ];

        ensureUsers = [
          {
            name = "grafana";
            ensureDBOwnership = true;
          }
        ];
      };

      grafana = {
        enable = mkDefault true;

        settings = {
          server = mkMerge [
            (mkIf cfg.socket (mkDefault {
              # TODO: configure root_url
              # root_url = if (config.ewood.nginx.domain == null) then
              protocol = "socket";
              socket_gid = config.users.groups."grafana-socket".gid;
              http_addr = "127.0.0.1";
              http_port = 3000;
            }))

            (
              let
                nginxDomain = config.ewood.nginx.domain;
                nginxDomainIsSet = nginxDomain != null;
                warning =
                  warnIfNot nginxDomainIsSet
                    "Could not set `services.grafana.settings.domain` since `ewood.nginx.domain` is not set"
                    nginxDomainIsSet;
              in
              mkIf (cfg.setupNginxReverseProxy && warning) {
                domain = "grafana.${nginxDomain}";
              }
            )
          ];

          database = mkDefault {
            type = "postgres";
            host = "/run/postgresql";
            name = "grafana";
            user = "grafana";
            # No point in ssl over unix a socket
            ssl_mode = "disable";
          };

          analytics = {
            reporting_enabled = false;
            check_for_updates = false;
          };
          security = {
            cookie_secure = true;
          };
          users = {
            allow_signup = false;
          };
          "auth.anonymous".enabled = false;
        };
      };
    };
  };
}
