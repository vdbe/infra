args:
let
  inherit (args) lib;

  inherit (lib.modules) mkDefault;
in
{
  imports = [
    ./args.nix
  ];

  config = {
    boot.tmp = {
      useTmpfs = mkDefault true;
      # Enable huge pages on tmpfs for better performance
      tmpfsHugeMemoryPages = "within_size";
    };
    zramSwap.enable = mkDefault true;
  };
}
