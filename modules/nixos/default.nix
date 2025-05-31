{ self, lib, ... }:
let
  scopes = [
    ./custom
    ./defaults
  ];
  all =
    scopes
    ++ (lib.flatten (
      builtins.map (
        scope:
        let
          scope' = import scope;
          imports =
            if (builtins.isAttrs scope') then
              scope'.imports
            else if (builtins.isFunction scope') then
              (scope' { }).imports
            else
              builtins.throw "Invalid module structure for ${scope}";
        in
        imports
      ) scopes
    ));

  nixosModules = (self.lib.helpers.exposeModules ./. all) // {
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
