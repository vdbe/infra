{
  self,
  inputs',
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) mapAttrs listToAttrs;
  inherit (lib) types;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.strings) optionalString hasSuffix;
  inherit (lib.attrsets)
    filterAttrs
    nameValuePair
    mapAttrs'
    recursiveUpdate
    getLib
    ;
  inherit (lib.trivial) const;

  ngxPrometheusExporter = inputs'.ngx-prometheus-exporter.packages.default.override {
    nginx = config.services.nginx.package;
  };
  ngxPrometheusExporterModule = "${getLib ngxPrometheusExporter}/lib/libngx_prometheus_exporter.so";

  # Inspired by https://github.com/getchoo/borealis/blob/44d41d8f0dfa9e2d76aed7fa4c1b87b1b1af0276/modules/nixos/custom/proxies.nix
  reverseProxySubmodule =
    { config, name, ... }:
    {
      options = {
        domain = mkOption {
          type = types.str;
          description = "Address to proxy.";
        };
        addresses = mkOption {
          type = types.nullOr (types.coercedTo types.str (s: [ s ]) (types.listOf types.str));
          default = null;
          description = "Address to proxy.";
        };

        protocol = mkOption {
          type = types.enum [
            "http"
            "https"
          ];
          default = "http";
          description = "Protocol used to connect to the proxy.";
        };

        virtualHostOptions = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          internal = true;
        };
      };
      config = {
        virtualHostOptions = {
          locations."/" = {
            proxyPass = mkIf (config.addresses != null) (mkDefault "${config.protocol}://${config.domain}");
          };
        };
        domain =
          if (cfg.domain == null || hasSuffix cfg.domain name) then name else "${name}.${cfg.domain}";
      };
    };

  commonOptions = {
    virtualHostOptions = cfg.commonVirtualHostOptions;
  };
  reverseProxies = mapAttrs' (const (
    attrs: nameValuePair attrs.domain (recursiveUpdate commonOptions attrs)
  )) cfg.reverseProxies;

  reverseProxiesUpstreams = mapAttrs (_: settings: {
    servers = listToAttrs (map (address: nameValuePair address { }) settings.addresses);
  }) (filterAttrs (_: settings: settings.addresses != null) reverseProxies);

  cfg = config.ewood.nginx;
  lcfg = config.services.nginx;
in
{
  options.ewood.nginx = {
    enable = mkEnableOption "nginx";
    domain = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Default domain to use";
    };
    statusPage = (mkEnableOption "status page") // {
      default = true;
    };
    accessLogToJournal = (mkEnableOption "Send access logs to the journal") // {
      default = true;
    };
    commonVirtualHostOptions = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };
    reverseProxies = mkOption {
      type = types.attrsOf (types.submodule reverseProxySubmodule);
      default = { };
      description = "An attribute set describing services to proxy.";

    };
  };

  config = {
    users.groups."nginx-socket" = {
      gid = 60579; # https://systemd.io/UIDS-GIDS/#summary
      members = [
        config.services.nginx.user
        "user"
      ];
    };

    services.nginx = {
      enable = mkDefault true;
      statusPage = mkIf cfg.statusPage (mkDefault true);

      prependConfig = ''
        load_module "${ngxPrometheusExporterModule}";
      '';

      commonHttpConfig = optionalString cfg.accessLogToJournal ''
        # Custom log format that includes `$request_time`
        # See https://nginx.org/en/docs/http/ngx_http_log_module.html
        # log_format main '$remote_addr - $remote_user [$time_local] "$host" "$request" '
        #   '$status $body_bytes_sent "$http_referer" '
        #   '"$http_user_agent" $request_time';

        # Send access logs to the journal
        # - using the log format `main`
        # - with the tag nginx_access to filter it from normal `nginx.service` logs
        #   `nohostname` is required for the tag to be recognized
        # You can filter on logs with `journalctl -t nginx_access`
        # access_log syslog:server=unix:/dev/log,nohostname,tag=nginx_access main;

        # TODO: decide if I want error logs with a tag or default behaviour which is alread to the journal
        #error_log syslog:server=unix:/dev/log,nohostname,tag=nginx_error;
        log_format main '$remote_addr - $remote_user [$time_local] "$host" "$request" '
          '$status $body_bytes_sent "$http_referer" '
          '"$http_user_agent" $request_time';
        access_log syslog:server=unix:/dev/log,nohostname,tag=nginx_access main;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';

      # Enable all recommendations
      recommendedTlsSettings = mkDefault true;
      recommendedOptimisation = mkDefault true;
      recommendedProxySettings = mkDefault true;
      recommendedBrotliSettings = mkDefault true;
      recommendedGzipSettings = mkDefault true;
      recommendedZstdSettings = mkDefault true;
      recommendedUwsgiSettings = mkDefault true;

      resolver.addresses =
        let
          isIPv6 = addr: builtins.match ".*:.*:.*" addr != null;
          escapeIPv6 = addr: if isIPv6 addr then "[${addr}]" else addr;
          cloudflare = [
            "1.1.1.1"
            "2606:4700:4700::1111"
          ];
          resolvers =
            if config.networking.nameservers == [ ] then cloudflare else config.networking.nameservers;
        in
        map escapeIPv6 resolvers;

      sslDhparam = config.security.dhparams.params.nginx.path;

      # Configure reverse procies
      upstreams = reverseProxiesUpstreams;
      virtualHosts = {
        # No need to expose this to the entire system
        "localhost" = mkIf cfg.statusPage {
          listen = [
            { addr = "unix:/var/run/nginx/nginx.sock"; }
            # NOTE: alloy can't scrape from unix sockets
            # TODO: TLS?
            { addr = "[::1]"; }
            { addr = "127.0.0.1"; }
          ];
          locations."/nginx_status" = {
            extraConfig = ''
              allow unix:;
            '';
          };
          locations."/metrics" = {
            extraConfig = ''
              allow unix:;
              allow 127.0.0.1;
              allow ::1;
              deny all;

              access_log off;
              prometheus_exporter on;
            '';
          };

        };
      } // (lib.mapAttrs (lib.const (lib.getAttr "virtualHostOptions")) reverseProxies);
    };

    systemd.services = mkIf lcfg.enable {
      nginx = {
        serviceConfig = {
          # Create the /var/run dir for the nginx localhost socket
          RuntimeDirectory = "nginx";
          Requires = "nginx-socket-chgrp";
        };
      };

      nginx-socket-chgrp = {
        wantedBy = [ "nginx.service" ];
        after = [ "nginx.service" ];
        preStart = ''
          while [ ! -S /var/run/nginx/nginx.sock ]; do sleep 1; done
        '';
        # TODO: Adjus limitations for `prestart`
        # serviceConfig = self.lib.templates.systemd.serviceConfig // {
        serviceConfig = {
          Type = "oneshot";
          User = "nginx";
          Group = "nginx-socket";
          PrivateUsers = "self";
          ExecStart = "${pkgs.coreutils}/bin/chgrp nginx-socket /run/nginx/nginx.sock";
          # CapabilityBoundingSet = [
          #   "CAP_CHOWN"
          # ];
          # SystemCallFilter = [
          #   "@chown"
          #   "@file-system"
          #   "@resources"
          #   "@basic-io"
          #   "@io-event"
          #   "@network-io"
          #   "@process"
          # ];
        };
      };
    };

    security = {
      dhparams = {
        enable = mkDefault true;
        params.nginx = { };
      };
    };
  };
}
