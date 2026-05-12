{ ... }:
let
  server = { pkgs, ... }: {
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" "pipe-operators" ];
      trusted-users = [ "root" "sudha" ];
    };
    
    programs.nix-ld.enable = true;
    
    nixpkgs.config.allowUnfree = true;
    system.stateVersion = "25.11";

    hardware.bluetooth.enable = true;

    networking = {
      networkmanager.enable = true;
      firewall.enable = false;
    };

    time.timeZone = "Asia/Kolkata";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "us";

    users.users.sudha = {
      isNormalUser = true;
      extraGroups = [ "wheel" "dialout" "docker" ];
    };

    services = {
      printing.enable = true;
      pipewire = {
        enable = true;
        pulse.enable = true;
        # ADD THESE THREE LINES:
        alsa.enable = true;
        alsa.support32Bit = true;
        wireplumber.enable = true; # The modern session manager that handles dynamic routing
      };
      openssh.enable = true;
      avahi = {
        enable = true;
        nssmdns4 = true; # Allows the laptop (and all nodes) to resolve .local
      };
    };
    
    virtualisation.docker = {
      enable = true;
    };

    environment.systemPackages = with pkgs; [
      tree 
      util-linux 
      vim 
      wget 
      curl 
      git 
      gptfdisk 
      htop 
      pciutils 
      home-manager
      cloudflared
    ];
  };
in
{
  # Server-specific node definition
  configurations.nixos."server".module = {
    imports = [
      server
      ({ pkgs, ... }: { # 2. ADDED: Added 'config' to the arguments so it can be used below
        boot = {
          kernelPackages = pkgs.linuxPackages_latest;
          loader = {
            grub = {
              enable = true;
              efiSupport = false; # Explicitly disabling EFI
              # devices = [ "/dev/sda" ]; # <-- ADD THIS BACK: Tells GRUB to install to the MBR of the 500GB drive
            };
          };
        };
        networking.hostName = "server"; 
        services.avahi = {
          enable = true;
          nssmdns4 = true; # Allows software to use Avahi to resolve .local domains
          publish = {
            enable = true;
            addresses = true;
            workstation = true;
          };
        };
      })
    ];
  };
}