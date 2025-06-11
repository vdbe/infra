args:
let
  inherit (args)
    config
    lib
    clan-core
    self
    ;

  inherit (lib.modules) mkDefault;
  inherit (lib.lists) optional;
  inherit (clan-core) clanModules;
  inherit (self) nixosModules;

  etcOverlay = config.system.etc.overlay;
in
{
  imports =
    [
      # For self.nixosModules
      ./args.nix
      ./clan.nix
      ./firewall.nix
      ./nix.nix
      ./generators.nix
      ./checks.nix
    ]
    ++ (
      if (args ? clan-core) then
        [
          # Normal imports

          # Always usefull in emergencies
          clanModules.root-password

          # Keep same machine-id on reinstalls
          clanModules.machine-id

          nixosModules.custom-persistence
          nixosModules.custom-perlless
          nixosModules.custom-root-ca
        ]
      else
        [ ]
    );

  options = {
    foo = lib.mkOption {
      type = lib.types.anything;
      description = "Debug option";
    };
  };

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

    users.mutableUsers = mkDefault false;

    # See https://github.com/NixOS/nixpkgs/issues/383179
    # Should be fixed on a next systemd version: https://github.com/NixOS/nixpkgs/issues/383179#issuecomment-2729028492
    systemd.services.userborn = {
      before = [ "systemd-oomd.socket" ];
    };
  };
}
