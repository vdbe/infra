{
  lib,
  options,
  config,
  ...
}:
let
  inherit (builtins)
    hasAttr
    catAttrs
    attrValues
    all
    ;
  inherit (lib.lists) optionals unique;

  getUniqSecretAttrs = attrName: unique (catAttrs "owner" (attrValues config.sops.secrets));

  secretUsers = getUniqSecretAttrs "owner";
  secretGroups = getUniqSecretAttrs "group";

in
{
  assertions = optionals (hasAttr "sops" options) [
    {
      assertion = all (user: hasAttr "${user}" config.users.users) secretUsers;
      message = ''
        `sops.secrets` depends on a not existing user.
      '';
    }
    {
      assertion = all (group: hasAttr "${group}" config.users.groups) secretGroups;
      message = ''
        `sops.secrets` depends on a not existing group.
      '';
    }
  ];
}
