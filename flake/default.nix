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
      tailnet = "tail71527.ts.net";
    };
    inherit inputs;
  };
}
