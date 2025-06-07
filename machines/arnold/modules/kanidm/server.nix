{
  self,
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (self.infra) domain;
  inherit (lib.strings) concatLines;
  generators = config.clan.core.vars.generators;

  extraKanidmCommands = [
    "person validity expire-at '1970-01-01T00:00:00+00:00'"
    "group add-members idm_admins vdbe"
  ];

  enableServer = true;
  cfg = config.services.kanidm;
in
{
  ewood.nginx = {
    enable = true;
    reverseProxies = {
      ${cfg.serverSettings.domain} = mkIf cfg.enableServer {
        addresses = cfg.serverSettings.bindaddress;
        protocol = "https";
      };
    };
  };

  environment.etc."kanidm/chain.pem" = mkIf cfg.enableServer {
    source = generators."kanidm-server-cert".files."fullchain".path;
  };

  services.kanidm = {
    inherit enableServer;
    package = pkgs.kanidmWithSecretProvisioning;

    serverSettings = {
      domain = "idm.${domain}";
      origin = "https://idm.${domain}";
      tls_chain = "/etc/kanidm/chain.pem";
      tls_key = generators."kanidm-server-cert".files."key".path;
    };

    provision = {
      enable = true;
      adminPasswordFile = generators."kanidm-passwords".files."admin".path;
      idmAdminPasswordFile = generators."kanidm-passwords".files."idm-admin".path;

    };
  };

  systemd.services = {
    "kanidm" = {
      # Otherwise secrets could be missing due to race conditions
      after = [ "sops-install-secrets.service" ];
    };

    "kanidm-setup-commands" = mkIf (extraKanidmCommands != [ ]) {
      wantedBy = [ "kanidm.service" ];
      after = [ "kanidm.service" ];
      preStart = ''
        ${lib.getExe pkgs.curlMinimal} --silent \
          --cacert ${generators."root-ca".files."cert".path} \
          $KANIDM_URL/status
      '';

      serviceConfig = self.lib.templates.systemd.serviceConfig // {
        # serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        LoadCredential = "KANIDM_PASSWORD_FILE:${generators."kanidm-passwords".files."idm-admin".path}";
        RuntimeDirectory = "kanidm-setup-commands";
        Environment = [
          "KANIDM_DEBUG=false"
          "KANIDM_PASSWORD_FILE=/run/credentials/%N.service/KANIDM_PASSWORD_FILE"
          "KANIDM_NAME=idm_admin"
          "KANIDM_TOKEN_CACHE_PATH=/run/%N/kanidm_tokens"
          "KANIDM_URL=https://${cfg.serverSettings.bindaddress}"
          "HOME=/run/%N"
        ];
        ReadWritePaths = [ "/run/%N" ];
        ExecStart =
          let
            # NOTE: this copies everything including server
            kanidm = "${pkgs.kanidm}/bin/kanidm";
          in
          pkgs.writeShellScript "extra-kanidm-setup-commands" ''
            export KANIDM_PASSWORD="$(cat "$KANIDM_PASSWORD_FILE")"
            export KANIDM_TOKEN_CACHE_PATH=/run/kanidm-setup-commands/kanidm_tokens

            ${kanidm} login
            ${concatLines (map (command: "${kanidm} ${command}") extraKanidmCommands)}
          '';

        RestrictAddressFamilies = [
          # "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
  };

  clan.core.vars.generators =
    let
      commonOptions = {
        owner = "kanidm";
        group = "kanidm";
        restartUnits = [ "kanidm.service" ];
      };
    in
    {
      "kanidm-passwords" = self.lib.generators.mkPasswords pkgs {
        "idm-admin".file = commonOptions;
        "admin".file = commonOptions;
      };
      "kanidm-server-cert" = self.lib.generators.mkSignedCert pkgs {
        signer = "root-ca";
        inherit (commonOptions) owner group;

        subj = "/O=Infra/OU=Kanidm/L=${config.clan.core.machineName}/CN=localhost";
        extfile = ''
          basicConstraints=critical,CA:FALSE
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=serverAuth
          subjectAltName=IP:127.0.0.1
        '';
      };
    };
}
