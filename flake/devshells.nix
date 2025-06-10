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

            #
            pkgs.sops
            pkgs.age-plugin-yubikey

            (pkgs.python3.withPackages (
              py-pkgs: with py-pkgs; [
                python-lsp-server
                ruff
              ]
            ))
            pkgs.uv
            (pkgs.pulumi.withPackages (
              pulumi-pkgs: with pulumi-pkgs; [
                pulumi-python
              ]
            ))
            # pkgs.pulumi-bin
            # pkgs.pulumiPackages.pulumi-python
          ];

          env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.libz
          ];

          shellHook = ''
            echo test123
            function cleanup_key_file() {
              rm -f $SOPS_AGE_KEY_FILE
            }

            SOPS_AGE_KEY_FILE=$(mktemp)
            trap cleanup_key_file EXIT
            echo "age: $SOPS_AGE_KEY_FILE"

            sops decrypt ${../vars/shared/terraform/age-key.txt/secret} --output "$SOPS_AGE_KEY_FILE"
            export SOPS_AGE_KEY_FILE
          '';
        };
      };
    };
}
