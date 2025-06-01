{
  self,
  config,
  lib,
  ...
}:
{
  ewood = {
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
