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

  ewood = {
    perlless.enable = true;
  };

  system.etc.overlay = {
    enable = lib.mkDefault true;
    mutable = lib.mkDefault false;
  };

  # None default nixos options
  facter.detected.graphics.enable = lib.mkDefault false;

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
