{
  clan.core.vars.generators = {
    "cloudflare" = {
      share = true;
      files = {
        "api-token" = {
          deploy = false;
        };
      };
      prompts."api-token" = {
        persist = true;
        description = ''
          # Zerro trust oauth2
            - Acount -> Access: Organizations, Identity Providers, and Groups Write -> Edit

          # Tunnels
            - Acount -> Cloudflare Tunnel -> Edit
            - Account -> Access: Apps and Policies -> Edit # TODO: Check
            - Zone -> DNS -> Edit
        '';
      };
    };
    # TODO: limit scope
    "tailscale-oauth" = {
      share = true;
      files = {
        "client-id" = {
          deploy = false;
        };
        "client-secret" = {
          deploy = false;
        };
      };
      prompts = {
        "client-id" = {
          persist = true;
        };
        "client-secret" = {
          type = "hidden";
          persist = true;
        };
      };
    };
  };
}
