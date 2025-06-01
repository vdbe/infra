{ self, ... }:
let
  inherit (self.lib.helpers) exposeModules gatherModules;
  scopes = [
    ./custom
    ./defaults
    ./mixins
    ./profiles
  ];
  allModules = gatherModules scopes;

  nixosModules = (exposeModules ./. allModules) // {
    default = {
      imports = [
        ./custom
        ./defaults
        ./mixins
      ];
    };
  };

in
{
  flake = {
    inherit nixosModules;
  };
}
