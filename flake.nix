{
  description = "My infra";

  inputs = {
    systems.url = "github:nix-systems/default";

    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    clan.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
    clan.inputs.nixpkgs.follows = "nixpkgs";
    clan.inputs.systems.follows = "systems";
    clan.inputs.flake-parts.follows = "flake-parts";

    mypkgs.url = "github:vdbe/flake-pkgs";
    # mypkgs.url = "git+file:///home/user/dev/flake-pkgs";
    mypkgs.inputs.nixpkgs.follows = "nixpkgs";
    mypkgs.inputs.flake-compat.follows = "";

    srvos.url = "github:nix-community/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    preservation.url = "github:nix-community/preservation";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      systems,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      imports = [
        ./flake
        ./lib
        ./modules
      ];
    };
}
