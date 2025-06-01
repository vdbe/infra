{ lib, ... }:
{
  nix = {
    channel.enable = lib.modules.mkDefault false;
    settings.trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
