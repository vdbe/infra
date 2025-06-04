{ self, ... }:
let
  clanModules = {
    sshd = import ./sshd { };
    acme = import ./acme { inherit self; };
    cloudflare-tunnel = import ./cloudflare-tunnel { inherit self; };
  };
in
{
  clan = {
    modules = clanModules;
  };
}
