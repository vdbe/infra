{ self, lib, ... }:
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
    foldl'
    getAttr
    mapAttrs
    ;

  inherit (lib.modules) mkDefault evalModules;
  inherit (lib.lists) flatten;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.trivial) mergeAttrs const;

  clanLib = self.clanInternals.clanLib;
  inventory = self.clanInternals.inventory;
  inherit (self) inputs;

  importedModuleWithInstances =
    (clanLib.inventory.mapInstances {
      flakeInputs = inputs;
      inherit inventory;
      localModuleSet = self.clan.modules;
    }).importedModuleWithInstances;

  getMachinesSettings =
    instance: role:
    let
      instance' = importedModuleWithInstances.${instance};

      # Options
      interface = instance'.resolvedModule.roles.${role}.interface;

      # Config
      settings = instance'.instanceRoles.${role};
      defaultSettings = settings.settings;
      machinesSettings = mapAttrs (const (getAttr "settings")) settings.machines;

      evaluateMachineSettings =
        machineSettings:
        evalModules {
          modules = [
            interface
            defaultSettings
            machineSettings
          ];
        };
    in
    mapAttrs (const (settings: getAttr "config" (evaluateMachineSettings settings))) machinesSettings;

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

  # Opposite of builtins.keepAttrs
  keepAttrs =
    names: attrs:
    foldl' mergeAttrs { } (
      map (name: optionalAttrs (attrs ? ${name}) { ${name} = attrs.${name}; }) names
    );

in

{
  inherit
    gatherModules
    exposeModules
    mkPreserve
    mkPreserveData
    mkPreserveState
    mkPreserveCache
    keepAttrs
    getMachinesSettings
    ;
}
