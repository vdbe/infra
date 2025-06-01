{
  config,
  lib,
  ...
}:
let
  inherit (builtins) mapAttrs listToAttrs;
  inherit (lib) types;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.strings) optionalString;
  inherit (lib.attrsets) filterAttrs nameValuePair;

  # Inspired by https://github.com/getchoo/borealis/blob/44d41d8f0dfa9e2d76aed7fa4c1b87b1b1af0276/modules/nixos/custom/proxies.nix
  reverseProxySubmodule =
    { config, name, ... }:
    {
      options = {
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
            proxyPass = mkIf (config.addresses != null) (mkDefault "${config.protocol}://${name}");
          };
        };

      };
    };

  reverseProxiesUpstreams = mapAttrs (_: settings: {
    servers = listToAttrs (map (address: nameValuePair address { }) settings.addresses);
  }) (filterAttrs (_: settings: settings.addresses != null) cfg.reverseProxies);

  cfg = config.ewood.nginx;
in
{
  options.ewood.nginx = {
    enable = mkEnableOption "nginx";
    statusPage = (mkEnableOption "status page") // {
      default = true;
    };
    accessLogToJournal = (mkEnableOption "Send access logs to the journal") // {
      default = true;
    };
    reverseProxies = mkOption {
      type = types.attrsOf (types.submodule reverseProxySubmodule);
      default = { };
      description = "An attribute set describing services to proxy.";

    };
  };

  config = {
    services.nginx = {
      enable = mkDefault true;
      statusPage = mkIf cfg.statusPage (mkDefault true);

      commonHttpConfig = optionalString cfg.accessLogToJournal ''
        # Custom log format that includes `$request_time`
        # See https://nginx.org/en/docs/http/ngx_http_log_module.html
        log_format main '$remote_addr - $remote_user [$time_local] "$host" "$request" '
          '$status $body_bytes_sent "$http_referer" '
          '"$http_user_agent" $request_time';

        # Send access logs to the journal
        # - using the log format `main`
        # - with the tag nginx_access to filter it from normal `nginx.service` logs
        #   `nohostname` is required for the tag to be recognized
        # You can filter on logs with `journalctl -t nginx_access`
        access_log syslog:server=unix:/dev/log,nohostname,tag=nginx_access main;

        # TODO: decide if I want error logs with a tag or default behaviour which is alread to the journal
        #error_log syslog:server=unix:/dev/log,nohostname,tag=nginx_error;
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
          listen = [ { addr = "unix:/var/run/nginx/nginx.sock"; } ];
          locations."/nginx_status" = {
            extraConfig = ''
              allow unix:;
            '';
          };
        };
        # };
      } // (lib.mapAttrs (lib.const (lib.getAttr "virtualHostOptions")) cfg.reverseProxies);
    };

    systemd.services.nginx = {
      serviceConfig = {
        # Create the /var/run dir for the nginx localhost socket
        RuntimeDirectory = "nginx";
      };
    };

    security = {
      acme.acceptTerms = true;
      dhparams = {
        enable = mkDefault true;
        params.nginx = { };
      };
    };
  };
}
