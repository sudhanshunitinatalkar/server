{ lib, ... }:
let
  ssh = { ... }: {
    services.openssh = {
      enable = true;
      
      settings = {
        # Disable SSH root login
        PermitRootLogin = "no";
        
        # Enforce SSH keys by disabling password authentication
        PasswordAuthentication = true;
        
        # Disable keyboard-interactive authentication (often used as a fallback for passwords)
        KbdInteractiveAuthentication = true;
      };
    };
  };

  targetHosts = [ "server" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = ssh;
  });
}