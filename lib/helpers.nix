{ lib, ... }:
let
  inherit (builtins)
    map
    isList
    isAttrs
    listToAttrs
    replaceStrings
    isFunction
    stringLength
    substring
    throw
    ;

  inherit (lib.modules) mkDefault;
  inherit (lib.lists) flatten;

  gatherModules =
    scopes:
    scopes
    ++ (flatten (
      map (
        scope:
        let
          scope' = import scope;
          imports =
            if (isAttrs scope') then
              scope'.imports
            else if (isFunction scope') then
              (scope' { }).imports
            else
              throw "Invalid module structure for ${scope}";
        in
        imports
      ) scopes
    ));

  # TODO: Documentation
  exposeModules =
    let
      removeSuffix =
        # Suffix to remove if it matches
        suffix:
        # Input string
        str:
        let
          sufLen = stringLength suffix;
          sLen = stringLength str;
        in
        if sufLen <= sLen && suffix == substring (sLen - sufLen) sufLen str then
          substring 0 (sLen - sufLen) str
        else
          str;
    in
    # Map 1:1 between paths and modules
    baseDir: paths:
    let
      prefix = stringLength (toString baseDir) + 1;

      toPair = path: {
        name = replaceStrings [ "/" ] [ "-" ] (
          removeSuffix ".nix" (substring prefix 1000000 (toString path))
        );
        value = path;
      };
    in
    listToAttrs (map toPair paths);

  mkPreserve =
    preserveAt: paths:
    let
      paths' = if isList paths then paths else [ paths ];
    in
    {
      "${preserveAt}" = {
        directories = map (
          path:
          let
            # TODO: implement a way to also preserve files.
            attrs = if isAttrs path then path else { directory = path; };
          in
          {
            configureParent = mkDefault true;
          }
          // attrs
        ) paths';
      };
    };

  mkPreserveData = config: mkPreserve "${config.ewood.persistence.path}/data";
  mkPreserveState = config: mkPreserve "${config.ewood.persistence.path}/state";
  mkPreserveCache = config: mkPreserve "${config.ewood.persistence.path}/cache";

in

{
  inherit
    gatherModules
    exposeModules
    mkPreserve
    mkPreserveData
    mkPreserveState
    mkPreserveCache
    ;
}
