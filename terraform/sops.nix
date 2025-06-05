{
  terraform = {
    required_providers = {
      sops = {
        # TODO: switched back to upstream once changes have been merged
        source = "vdbe/sops";
        version = "~> 1.3.0";
      };
    };
  };
}
