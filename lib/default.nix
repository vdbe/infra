# following https://github.com/isabelroses/dotfiles/blob/27e8ebf9ba55234909a4f31d883f34f00dbc28e5/modules/flake/lib/default.nix
#
# following https://github.com/NixOS/nixpkgs/blob/77ee426a4da240c1df7e11f48ac6243e0890f03e/lib/default.nix
# as a rough template we can create our own extensible lib and expose it to the flake
# we can then use that elsewhere like our hosts
{ lib, ... }:
let
  clanLib = lib.fixedPoints.makeExtensible (final: {
    helpers = import ./helpers.nix { inherit lib; };

    # we have to rexport the functions we want to use, but don't want to refer to the whole lib
    # "path". e.g. gardenLib.hardware.isx86Linux can be shortened to gardenLib.isx86Linux
    # NOTE: never rexport templates
  });

  # I want to absorb the evergarden lib into the garden lib. We don't do this
  # with nixpkgs lib to keep it pure as it is used else where and leads to many
  # breakages
  ext = lib.fixedPoints.composeManyExtensions [
    # (_: _: inputs.flake-parts.lib)
  ];

  # we need to extend gardenLib with the nixpkgs lib to get the full set of functions
  # if we do it the otherway around we will get errors saying mkMerge and so on don't exist
  finalLib = clanLib.extend ext;
in
{
  # expose our custom lib to the flake
  flake.lib = finalLib;
}
