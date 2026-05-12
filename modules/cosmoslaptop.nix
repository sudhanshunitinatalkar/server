{ inputs, lib, ... }:
{
  # We push this entire hardware + disk definition into the cosmoslaptop bucket
  configurations.nixos."cosmoslaptop".module = { config, modulesPath, ... }: {
    # 1. DISKO LAYOUT (1GB EFI + Remaining EXT4)
    # This replaces the need for manual 'fileSystems' entries or UUIDs.
    disko.devices = {
      disk = {
        main = {
          # Change this to match your actual disk path (e.g., /dev/sda or /dev/nvme0n1)
          device = lib.mkDefault "/dev/nvme0n1"; 
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
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

    # 2. CORE HARDWARE DRIVERS
    # These ensure the kernel can actually talk to your NVMe and USB controllers.
    imports = [ 
      inputs.disko.nixosModules.disko
      (modulesPath + "/installer/scan/not-detected.nix") 
    ];

    boot.initrd.availableKernelModules = [ 
      "nvme" "xhci_pci" "usb_storage" "usbhid" "sd_mod" 
    ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-amd" ];
    boot.extraModulePackages = [ ];

    # 3. PLATFORM IDENTITY
    # This defines the architecture without hardcoding machine-specific IDs.
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}