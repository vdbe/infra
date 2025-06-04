{ inputs, ... }:
{
  imports = [
    ./checks.nix
    ./clan.nix
    ./devshells.nix
    ./formatter.nix
  ];

  flake = {
    infra = {
      domain = "ewood.dev";
    };
    inherit inputs;
  };
}
