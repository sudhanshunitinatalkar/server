{ inputs, lib, ... }:
let
  disko = { config, modulesPath, ... }: {
    disko.devices = {
      disk = {
        main = {
          device = lib.mkDefault "/dev/sda"; 
          type = "disk";
          content = {
            type = "gpt"; # <-- Back to modern GPT
            partitions = {
              boot = {
                size = "1M";
                type = "EF02"; # GRUB core goes here
              };
              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };

    imports = [ 
      inputs.disko.nixosModules.disko
      (modulesPath + "/installer/scan/not-detected.nix") 
    ];

    boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "usb_storage" "usbhid" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-intel" ]; 
    boot.extraModulePackages = [ ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  targetHosts = [ "cosmosserver" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = disko;
  });
}