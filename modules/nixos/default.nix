{ self, ... }:
let
  inherit (self.lib.helpers) exposeModules gatherModules;
  scopes = [
    ./custom
    ./defaults
    ./mixins
    ./profiles
  ];
  allModules = exposeModules ./. (gatherModules scopes);

  nixosModules = allModules // {
    default = {
      imports = [
        allModules.defaults
        allModules.mixins

        # allModules.custom
      ];
    };
  };

in
{
  flake = {
    inherit nixosModules;
  };
}
