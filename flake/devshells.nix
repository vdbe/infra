_: {
  perSystem =
    {
      self',
      pkgs,
      inputs',
      ...
    }:
    {
      devShells = {
        default = pkgs.mkShellNoCC {
          packages = [
            # We want to make sure we have the same
            # Nix behavior across machines
            pkgs.nix

            inputs'.clan.packages.default

            # Nix tools
            pkgs.nixd
            pkgs.statix
            self'.formatter
          ];
        };
      };
    };
}
