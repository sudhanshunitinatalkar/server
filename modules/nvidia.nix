{ ... }:
{
  configurations.nixos."cosmoslaptop".module = { config, ... }: {
    hardware.graphics.enable = true;
    hardware.graphics.enable32Bit = true;

    boot.kernelParams = [
      "nvidia.NVreg_PreserveVideoMemoryAllocations=0"
    ];

    # Load drivers for both AMD iGPU and NVIDIA dGPU
    services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      dynamicBoost.enable = true;
      nvidiaSettings = true;
      
      # We have access to 'config' here because of the lambda signature above
      package = config.boot.kernelPackages.nvidiaPackages.beta;

      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;
        amdgpuBusId = "PCI:5:0:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

#   configurations.nixos."cosmos-wsl".module = { pkgs, ... }: {
#     # Let WSL pass through the Windows GPU driver into the container.
#     wsl.useWindowsDriver = true;

#     # OpenGL/Vulkan userspace libraries
#     hardware.graphics.enable = true;

#     # CUDA support via the stub library
#     environment.systemPackages = with pkgs; [
#       cudaPackages.cudatoolkit
#     ];

#     environment.sessionVariables = {
#       LD_LIBRARY_PATH = "/usr/lib/wsl/lib:$LD_LIBRARY_PATH";
#     };
#   };
}