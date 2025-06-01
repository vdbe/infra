# Based on: https://git.clan.lol/clan/clan-core/src/commit/6b1340d775c04f0ec3c340a2b48a37e4fad07de0/clanServices/admin/default.nix
{ ... }:
let
  inherit (builtins) attrValues;
in
{
  _class = "clan.service";
  manifest.name = "infra/sshd";
  manifest.categories = [
    "System"
    "Network"
  ];

  roles.server = {
    interface =
      { lib, ... }:
      let
        inherit (lib) types;
        inherit (lib.options) mkOption mkEnableOption;

      in
      {
        options = {
          allowedKeys = mkOption {
            default = { };
            type = types.attrsOf types.str;
            description = "The allowed public keys for ssh access to the admin user";
            example = {
              "key_1" = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD...";
            };
          };
          userCAs = mkOption {
            default = { };
            type = types.attrsOf types.str;
            description = "The allowed public keys for ssh access to the admin user";
            example = {
              "key_1" = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD...";
            };
          };
          sshd-command = {
            enable = (mkEnableOption "sshd-command") // {
              default = true;
            };
            templates = mkOption {
              type = types.attrsOf types.anything;
              default = {
                principals = {
                  sshd-command = {
                    command = "principals";
                    tokens = [
                      "%U"
                      "%u"
                    ];
                  };
                  extraFrontMatter = {
                    search_domains = [ ];
                  };
                  tera = ''
                    {% macro principals(fqdn) -%}
                    {{ fqdn }}
                    {{ user.name }}@{{ fqdn }}
                        {%- for group in user.groups  %}
                            {%- if group.gid >= 1000 %}
                    @{{- group.name }}@{{ fqdn }}
                            {%- endif %}
                        {%- endfor -%}
                    {%- endmacro principals -%}

                    {{- self::principals(fqdn=hostname) }}
                    {% for search_domain in search_domains  %}
                    {{- self::principals(fqdn=hostname ~ "." ~ search_domain) }}
                    {%  endfor -%}
                  '';
                };

              };

            };
          };
        };
      };

    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            inputs,
            mypkgs,
            ...
          }:
          let
            inherit (lib.modules) mkDefault mkIf;
            inherit (lib.attrsets) optionalAttrs recursiveUpdate;
            inherit (lib.lists) unique;

            templates = settings.sshd-command.templates;

            searchDomains = lib.lists.unique (
              config.clan.sshd.certificate.searchDomains
              ++ (lib.lists.optional (config.networking.domain != null) config.networking.domain)
            );
          in
          {
            imports = [
              inputs.mypkgs.nixosModules.sshd-command
            ];

            services.openssh = {
              extraConfig = ''
                TrustedUserCAKeys /etc/ssh/trusted_user_ca
                AuthorizedPrincipalsCommandUser nobody
              '';

              sshd-command = mkIf settings.sshd-command.enable {
                enable = mkDefault true;
                # package = mkDefault mypkgs.sshd-command;

                templates = recursiveUpdate templates (
                  optionalAttrs (templates.principals.extraFrontMatter ? search_domains) {
                    principals.extraFrontMatter.search_domains = unique (
                      templates.principals.extraFrontMatter.search_domains ++ searchDomains
                    );

                  }
                );
              };
            };

            environment.etc = {
              # location taken from: https://github.com/NixOS/nixpkgs/blob/738f925e84c0d049b83fa19ace6b02584615f117/nixos/modules/security/pam.nix#L1367-L1371
              "ssh/trusted_user_ca".text = lib.strings.concatLines (attrValues settings.userCAs);
            };

            users.users.root.openssh.authorizedKeys.keys = attrValues settings.allowedKeys;
          };
      };
  };

}
