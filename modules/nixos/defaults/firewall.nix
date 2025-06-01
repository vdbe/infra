{ lib, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  networking = {
    firewall.enable = mkDefault true;
    nftables.enable = mkDefault true;
  };
}
