{ self, ... }:
let
  inherit (self.lib.helpers) exposeModules gatherModules;
  scopes = [
    ./custom
    ./defaults
    ./profiles
  ];
  allModules = gatherModules scopes;

  nixosModules = (exposeModules ./. allModules) // {
    default = {
      imports = [
        ./custom
        ./defaults
      ];
    };
  };

in
{
  flake = {
    inherit nixosModules;
  };
}
