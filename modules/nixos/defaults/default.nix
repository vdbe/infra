args:
let
  inherit (args) config lib clan-core;

  inherit (lib.modules) mkDefault;
  inherit (lib.lists) optional;
  inherit (clan-core) clanModules;

  etcOverlay = config.system.etc.overlay;
in
{
  imports =
    [
      # For self.nixosModules
      ./args.nix
      ./clan.nix
      ./nix.nix
    ]
    ++ (
      if (args ? clan-core) then
        [
          # Normal imports

          # Always usefull in emergencies
          clanModules.root-password
          clanModules.machine-id
        ]
      else
        [ ]
    );

  config = {
    assertions = optional (etcOverlay.enable && !etcOverlay.mutable) {
      assertion = config.environment.etc."machine-id".enable or false;
      message = "/etc/machine-id needs to be set when using an immutable etc overlay";
    };

    boot.tmp = {
      useTmpfs = mkDefault true;
      # Enable huge pages on tmpfs for better performance
      tmpfsHugeMemoryPages = "within_size";
    };
    zramSwap.enable = mkDefault true;

    security.sudo.wheelNeedsPassword = mkDefault false;

    # See https://github.com/NixOS/nixpkgs/issues/383179
    # Should be fixed on a next systemd version: https://github.com/NixOS/nixpkgs/issues/383179#issuecomment-2729028492
    systemd.services.userborn = {
      before = [ "systemd-oomd.socket" ];
    };
  };
}
