{ lib, ... }:
let
  plasma = { pkgs, ... }:
  {
    services = {
      desktopManager.plasma6.enable = true;
      displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
    };

    environment.systemPackages = with pkgs; [
      # KDE
      kdePackages.plasma-browser-integration
      kdePackages.kcalc
      kdePackages.kcharselect
      kdePackages.kclock
      kdePackages.kcolorchooser
      kdePackages.kolourpaint
      kdePackages.ksystemlog
      kdePackages.sddm-kcm
      kdePackages.ktorrent
      kdiff3
      kdePackages.isoimagewriter
      kdePackages.partitionmanager
      kdePackages.filelight
      kdePackages.kdeconnect-kde
      # Non-KDE graphical packages
      hardinfo2
      wayland-utils
      wl-clipboard
    ];
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };

  targetHosts = [ "cosmoslaptop" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = plasma;
  });
}
