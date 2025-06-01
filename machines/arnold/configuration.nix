{
  self,
  config,
  lib,
  ...
}:
{
  ewood = {
    # Perl is required for the wifi clan service
    perlless.forbidPerl = false;
    firewall.interfaces = {
      "end0" = {
        roles = [ "blockFromLAN" ];
      };
      "wlan0" = {
        roles = [ "blockFromLAN" ];
      };
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
