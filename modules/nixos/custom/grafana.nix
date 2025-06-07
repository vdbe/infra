# TODO: ingergrate with `self.nixosModules.custom-nginx`
# might need to add a domain option for it in the nginx module
{
  config,
  lib,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkDefault mkIf;

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
    socket = mkOption {
      type = types.bool;
      default = true;
      description = "Use a socket instead of inet";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lcfg.enable && cfg.enable && cfg.setupDatabase && config.services.postgresql.enable;
        message = "Grafana is enabled with database setup but postgresql is not enabled, please enable this";
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
          server = mkIf cfg.socket (mkDefault {
            # TODO: configure root_url
            protocol = "socket";
            # domain = config.mymodules.targetHost;
            socket_gid = config.users.groups."grafana-socket".gid;
            http_addr = "127.0.0.1";
            http_port = 3000;
          });

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
