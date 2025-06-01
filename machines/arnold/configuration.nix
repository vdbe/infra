{
  self,
  config,
  lib,
  ...
}:
{
  imports = [
    self.nixosModules.default
  ];

  hardware = {
    # enableAllFirmware = false;
  };

  users = {
    mutableUsers = false;
    users = {
      user = {
        isNormalUser = true;
        password = "toor123";
        openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
        extraGroups = [ "wheel" ];
      };
    };
  };
}
