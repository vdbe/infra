{
  description = "My infra";

  inputs = {
    systems.url = "github:nix-systems/default";

    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    clan.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
    clan.inputs.nixpkgs.follows = "nixpkgs";
    clan.inputs.systems.follows = "systems";
    clan.inputs.flake-parts.follows = "flake-parts";

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
      ];
    };
}
