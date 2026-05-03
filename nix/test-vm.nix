{ ... }:
{
  imports = [ ./nextcloud-node.nix ];

  networking.firewall.allowedTCPPorts = [ 22 ];

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
}
