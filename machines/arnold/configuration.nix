{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (self.infra) domain;
in
{
  imports = [
    self.nixosModules.custom-firewall
    self.nixosModules.custom-nginx
    self.nixosModules.custom-grafana
    self.nixosModules.custom-loki
    self.nixosModules.custom-prometheus

    ./modules/kanidm
    ./modules/coredns.nix
  ];

  ewood = {
    # Perl is required for the wifi clan service
    perlless.forbidPerl = false;
    grafana.enable = true;
    nginx = {
      enable = true;
      domain = domain;
      commonVirtualHostOptions = {
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
      };
    };
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
      "${config.services.tailscale.interfaceName}" = {
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

        # Buffering settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;

        proxy_headers_hash_bucket_size 256;
        proxy_headers_hash_max_size 2048;
      '';
    };
    alloy = {
      enable = true;
    };
  };
  environment.etc."alloy/loki.alloy".text =
    let
      _elseif = index: ''{{ else if eq $value \"${toString index}\" }}'';
      _if = index: ''{{ if eq $value \"${toString index}\" }}'';
      _end = ''{{ end }}'';
      elseblock = index: replacement: "${_elseif index}${replacement}";
      ifblock = index: replacement: "${_if index}${replacement}";
      createTemplateLine =
        list:
        "${
          lib.concatStrings (
            lib.imap0 (
              index: replacement: if index == 0 then ifblock index replacement else elseblock index replacement
            ) list
          )
        }${_end}";
    in
    ''
      loki.write "default" {
        endpoint {
          url = "https://loki.${domain}/loki/api/v1/push"
          tls_config {
            cert_file = sys.env("LOKI_CERT_FILE")
            key_file  = sys.env("LOKI_KEY_FILE")
          }
        }
      }

      // discovery.relabel  "journal" {
      loki.relabel  "journal" {
        forward_to = [loki.process.journal.receiver]
        rule {
          source_labels = ["_BOOT_id"]
          target_label  = "boot_id"
        }
        rule {
          source_labels = ["SYSLOG_FACILITY"]
          target_label  = "facility"
        }
        rule {
          source_labels = ["SYSLOG_IDENTIFIER"]
          target_label  = "facility_label"
        }
        rule {
          source_labels = ["_HOSTNAME"]
          target_label  = "hostname"
        }
        rule {
          source_labels = ["MESSAGE"]
          target_label  = "msg"
        }
        rule {
          source_labels = ["PRIORITY"]
          target_label  = "priority"
        }
        rule {
          source_labels = ["PRIORITY"]
          target_label  = "priority_label"
        }
        rule {
          source_labels = ["_TRANSPORT"]
          target_label  = "transport"
        }
        rule {
          source_labels = ["_SYSTEMD_UNIT"]
          target_label  = "unit"
        }
      }

      loki.process "journal" {
        forward_to    = [loki.write.default.receiver]

        stage.json {
          expressions = {
            boot_id = "_BOOT_ID",
            facility = "SYSLOG_FACILITY",
            // facility_label = "SYSLOG_FACILITY",
            identifier = "SYSLOG_IDENTIFIER",
            instance_name = "_HOSTNAME",
            msg = "MESSAGE",
            priority = "PRIORITY",
            // priority_label = "PRIORITY",
            transport = "_TRANSPORT",
            unit = "_SYSTEMD_UNIT",
          }
        }

        stage.template {
            source   = "priority_label"
            template = "{{- $value:= .priority -}}${
              createTemplateLine [
                "emergency"
                "alert"
                "critical"
                "error"
                "warning"
                "notice"
                "info"
                "debug"
              ]
            }"
        }

        stage.template {
          source   = "facility_label"
          template = "{{- $value:= .facility -}}${
            createTemplateLine [
              "kern" # Kernel messages
              "user" # User-level messages
              "mail" # Mail system	Archaic POSIX still supported and sometimes used (for more mail(1))
              "daemon" # System daemons	All daemons, including systemd and its subsystems
              "auth" # Security/authorization messages	Also watch for different facility 10
              "syslog" # Messages generated internally by syslogd	For syslogd implementations (not used by systemd, see facility 3)
              "lpr" # Line printer subsystem (archaic subsystem)
              "news" # Network news subsystem (archaic subsystem)
              "uucp" # UUCP subsystem (archaic subsystem)
              "clock" # Clock daemon	systemd-timesyncd
              "authpriv" # Security/authorization messages	Also watch for different facility 4
              "ftp" # FTP daemon
              "-" # NTP subsystem
              "-" # Log audit
              "-" # Log alert
              "cron" # Scheduling daemon
              "local0" # Local use 0 (local0)
              "local1" # Local use 1 (local1)
              "local2" # Local use 2 (local2)
              "local3" # Local use 3 (local3)
              "local4" # Local use 4 (local4)
              "local5" # Local use 5 (local5)
              "local6" # Local use 6 (local6)
              "local7" # Local use 7 (local7)
            ]
          }"
        }

        stage.labels {
          values = {
            "boot_id" = "",
            "facility" = "",
            "facility_label" = "",
            "identifier" = "",
            "instance_name" = "",
            "priority" = "",
            "priority_label" = "",
            "transport" = "",
            "unit" = "",
          }
        }

        stage.output {
          source = "msg"
        }

        stage.label_keep {
          values = [
            "boot_id",
            "facility",
            "facility_label",
            "identifier",
            "instance_name",
            "priority",
            "priority_label",
            "transport",
            "unit",

            // Alloy specific tags
            "component",
            "job",
            "service_name",
          ]
        }

        stage.match {
          selector = "{identifier=\"nginx_access\"}"

          stage.regex {
            source = "msg"
            expression = `^(?P<remote_addr>[\w\.:]+) - (?P<remote_user>[^ ]*) \[(?P<timestamp>.*)\] "(?P<host>[^ ]*)" "(?P<method>[^ ]*) (?P<request_url>[^ ]*) (?P<request_http_protocol>[^ ]*)" (?P<status>[\d]+) (?P<bytes_out>[\d]+) "(?P<http_referer>[^"]*)" "(?P<user_agent>[^"]*)" (?P<request_time>[\d]+\.[\d]+)`
          }

          // TODO: geoip on remote_addr

          stage.template {
            source   = "level"
            template = "{{ $status := (int .status) }}{{ if ge $status 500 }}error{{ else if ge $status 400 }}warn{{ else }}info{{ end }}"
          }

          stage.labels {
            values = {
              remote_addr = "",
              // remote_user = "",
              // timestamp = "",
              host = "",
              method = "",
              // request_url = "",
              // request_http_protocol = "",
              status = "",
              // bytes_out = "",
              // http_refer = "",
              // user_agent = "",
              // request_time = "",
              level = "",
            }
          }
        }
      }

      loki.source.journal "read"  {
        format_as_json = true
        forward_to    = [loki.process.journal.receiver]
        labels        = {component = "loki.source.journal"}
      }
    '';

  environment.etc."alloy/prometheus.alloy".text = ''
    prometheus.remote_write "default" {
      endpoint {
        url = "https://prometheus.${domain}/api/v1/write"
        tls_config {
          cert_file = sys.env("PROMETHEUS_CERT_FILE")
          key_file  = sys.env("PROMETHEUS_KEY_FILE")
          // ca_file =  "${config.clan.core.vars.generators."prometheus-ca".files."cert".path}"
        }
      }
    }

    prometheus.exporter.self "example" {}

    prometheus.exporter.unix "default" { }

    prometheus.scrape "default" {
      targets    = prometheus.exporter.self.example.targets

      forward_to = [prometheus.remote_write.default.receiver]
    }
  '';
  systemd.services.alloy = {
    serviceConfig = {
      Environment = [
        "LOKI_CERT_FILE=${config.clan.core.vars.generators."alloy-loki-client".files."fullchain".path}"
        "LOKI_KEY_FILE=%d/LOKI_KEY"
        "PROMETHEUS_CERT_FILE=${
          config.clan.core.vars.generators."alloy-prometheus-client".files."fullchain".path
        }"
        "PROMETHEUS_KEY_FILE=%d/PROMETHEUS_KEY"
      ];
      LoadCredential = [
        "LOKI_KEY:${config.clan.core.vars.generators."alloy-loki-client".files."key".path}"
        "PROMETHEUS_KEY:${config.clan.core.vars.generators."alloy-prometheus-client".files."key".path}"
      ];

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
