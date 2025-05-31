{
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  # Prevent host becoming unreachable on wifi after some time.
  networking.useDHCP = lib.mkDefault true;

  nixpkgs = {
    overlays = [
      # Workaround: https://github.com/NixOS/nixpkgs/issues/154163
      # modprobe: FATAL: Module sun4i-drm not found in directory
      (_: super: {
        makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
      })
    ];
  };

  boot.supportedFilesystems.zfs = lib.mkForce false;
  sdImage.compressImage = false;

  environment.systemPackages = [
    pkgs.libraspberrypi
    pkgs.raspberrypi-eeprom
  ];

  fileSystems = lib.mkForce {
    "/" = {
      fsType = "tmpfs";
      options = [
        "size=2G"
        "defaults"
        "mode=755"
      ];

    };
    "/nix" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      neededForBoot = true;
      options = [
        "noatime"
        "defaults"
      ];
    };
    "/boot" = {
      device = "/nix/boot";
      fsType = "none";
      options = [
        "bind"
        "noatime"
        "defaults"
      ];
    };
  };

  nixpkgs.hostPlatform = "aarch64-linux";

  system.stateVersion = "25.11";
}
