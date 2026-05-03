{ self, pkgs, ... }:
{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = "localhost";
    config = {
      adminpassFile = toString (pkgs.writeText "adminpass" "admin");
      dbtype = "sqlite";
    };
    # Map appid -> derivation. linkFarm exposes $out at nix-apps/rhwpviewer.
    extraApps = {
      rhwpviewer = self.packages.${pkgs.stdenv.hostPlatform.system}.rhwp-viewer;
    };
    extraAppsEnable = true;
  };

  # Listen on all interfaces so the host port-forward reaches it.
  services.nginx.virtualHosts."localhost".listen = [
    {
      addr = "0.0.0.0";
      port = 80;
    }
  ];
  networking.firewall.allowedTCPPorts = [
    22
    80
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };
  users.users.root.initialPassword = "root";

  # Only applied when building the `vm` attr (`*.config.system.build.vm`).
  virtualisation.vmVariant.virtualisation = {
    forwardPorts = [
      {
        from = "host";
        host.port = 8080;
        guest.port = 80;
      }
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    memorySize = 2048;
    diskSize = 4096;
  };

  system.stateVersion = "25.11";
}
