{
  pkgs,
  config,
  lib,
  self,
  ...
}:
let
  lcfg = config.services.loki;

  socketAddr = "/run/loki/loki.sock:3100";
in
{
  config = {
    services.loki = {
      package = pkgs.grafana-loki.overrideAttrs (old: {
        src = /home/user/dev/loki;
      });
      enable = true;
      extraFlags = [ "--config.expand-env=true" ];

      configuration = {
        server = {
          http_listen_port = 3100;
          grpc_listen_port = 9095;
          http_listen_network = "unix";
          http_listen_address = "/run/loki/loki_http.sock";
          grpc_listen_network = "unix";
          grpc_listen_address = "/run/loki/loki_grpc.sock";
          log_level = "warn";

          # TODO: increase message sizes https://github.com/grafana/loki/issues/6182#issuecomment-2262208039
          "http_server_read_timeout" = "600s";
          "http_server_write_timeout" = "600s";
          "grpc_server_max_recv_msg_size" = 8388608;
          "grpc_server_max_send_msg_size" = 8388608;
        };

        auth_enabled = false;

        common = {
          # instance_interface_names = [
          #   "lo"
          # ];
          path_prefix = lcfg.dataDir;
          storage = {
            filesystem = {
              chunks_directory = "${lcfg.dataDir}/chunks";
              rules_directory = "${lcfg.dataDir}/rules";
            };
          };
          replication_factor = 1;
          ring = {
            # instance_addr = "127.0.0.1";
            # instance_addr = "unix:/var/run/loki/loki.sock:3100";
            # instance_network = "unix";
            instance_addr = "unix:///run/loki/loki_grpc.sock";
            kvstore = {
              store = "inmemory";
            };
          };
        };

        schema_config = {
          configs = [
            {
              from = "2024-04-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };

        # common = {
        #   path_prefix = lcfg.dataDir;
        #   storage = {
        #     filesystem = {
        #       chunks_directory = "${lcfg.dataDir}/chunks";
        #       rules_directory = "${lcfg.dataDir}/rules";
        #     };
        #   };
        #   replication_factor = 1;
        #   ring = {
        #     # instance_addr = "127.0.0.1";
        #     kvstore = {
        #       store = "inmemory";
        #     };
        #   };
        # };

        query_range = {
          results_cache = {
            cache = {
              embedded_cache = {
                enabled = true;
                max_size_mb = 100;
              };
            };
          };
        };

        ingester = {
          # lifecycler = {
          #   # TODO: ipv6
          #   enable_inet6 = false;
          # };

          # Any chunk not receiving new logs in this time will be flushed
          chunk_idle_period = "1h";
          # All chunks will be flushed when they hit this age, default is 1h
          # max_chunk_age = "1h";
          # Loki will attempt to build chunks up to 1.5MB, flushing first if chunk_idle_period or max_chunk_age is reached first
          chunk_target_size = 1048576;
          # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
          chunk_retain_period = "30s";

          query_store_max_look_back_period = "0s";
          # TODO: https://grafana.com/docs/loki/latest/operations/storage/wal/
          wal = {
            enabled = false;
          };
        };

        ingester_client = {
          remote_timeout = "10s";
        };

        limits_config = {
          # reject_old_samples = true;
          reject_old_samples = false;
          reject_old_samples_max_age = "168h";
          max_label_names_per_series = 35;
        };

        pattern_ingester = {
          enabled = true;
          # metric_aggregation = {
          #   enabled = true;
          #   loki_address = "localhost:3100";
          # };
        };

        frontend = {
          encoding = "protobuf";
        };

        analytics = {
          reporting_enabled = false;
        };

        # TODO:
        # chunk_store_config = {
        #   max_look_back_period = "0s";
        # };

        # TODO:
        # compactor = {
        #   working_directory = "${lcfg.dataDir}/compactor-work";
        #   shared_store = "filesystem";
        #   compactor_ring.kvstore.store = "inmemory";
        # };
      };

    };

    systemd.services = {
      "loki" = {
        serviceConfig = {
          RuntimeDirectory = "loki";
          RuntimeDirectoryMode = "0750";
          ExecStartPost = "${pkgs.coreutils}/bin/ln -s /run/loki/loki_grpc.sock:9095 /run/loki/loki_grpc.sock";
        };
      };
    };
  };
}
