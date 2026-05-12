{ inputs, ... }:
let
  sudha_cli = { pkgs, lib, ... }:{
    nixpkgs.config.allowUnfree = true;
    home.username = "sudha";
    home.homeDirectory = "/home/sudha";
    home.stateVersion = "25.11";
    programs.home-manager.enable = true;
    home.packages = with pkgs; [
      tree
      util-linux
      wget
      curl
      git
      gptfdisk
      htop
      fastfetch
      android-tools
      sops
      pciutils
      mosquitto
      nixd
      nil
      cloudflared
      cachix
      python3
      espeak-ng
      uv
      pulseaudio 
      alsa-utils
      pipewire
      netcat-gnu
      unrar
      gh
      jq
      
    ];
    
    programs.git = {
      enable = true;
      settings.user = {
        name = "sudhanshunitinatalkar";
        email = "atalkarsudhanshu@proton.me";
      };
    };
  };
  
  sudha_gui = { pkgs, lib, ... }:{
    home.packages = with pkgs; [
      telegram-desktop
      steam-run
      prusa-slicer
      libreoffice-fresh
      vscode
      unrar
      affine
      vlc
      google-chrome
      discord
    ];

    home.activation.refreshKDEAppMenu = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          /run/current-system/sw/bin/kbuildsycoca6 || true
        '';
  };
in
{
  configurations.home."sudha@cosmoslaptop" = {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;  
    module = { imports = [ sudha_cli sudha_gui ]; };
  };  
  configurations.home."sudha@cosmos_server".module = sudha_cli;
}
