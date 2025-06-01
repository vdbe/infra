{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  options = {
    foo = lib.mkOption {
      type = lib.types.anything;
    };
  };

  config = rec {
    _module.args =
      let
        inherit (pkgs.stdenv) system;
        mapInputsForSystem =
          system: inputs:
          builtins.mapAttrs (
            inputName: input:
            (
              if input._type == "flake" then
                (builtins.mapAttrs (attrName: attr: (attr.${system} or attr)) input)
              else
                input
            )
          ) inputs;

        inputs' = mapInputsForSystem system inputs;
      in
      {
        inherit inputs';
        self' = inputs'.self;
        mypkgs = inputs'.mypkgs.legacyPackages;

      };

    foo = _module.args;
  };
}
