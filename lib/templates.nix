let
  systemd = {
    serviceConfig = {

      BindReadOnlyPaths = [
        "/nix/store"
      ];
      ReadWritePaths = [ ];

      CapabilityBoundingSet = [ "" ]; # Capabilities(7)
      DevicePolicy = "closed";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateIPC = true;
      PrivateMounts = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProcSubset = "pid";
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "full"; # "full" | "strict"
      RemoveIPC = true;
      RestrictAddressFamilies = "none"; # [ "AF_UNIX" "AF_INET" "AF_INET6" ]
      RestrictNamespaces = true; # namespaces(7)
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" ];
      UMask = "0077";
    };

  };
in
{
  inherit
    systemd
    ;
}
