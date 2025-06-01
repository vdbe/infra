{ ... }:
let
  clanModules = {
    sshd = import ./sshd { };
  };
in
{
  clan = {
    modules = clanModules;
  };
}
