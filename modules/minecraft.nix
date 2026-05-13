{ inputs, lib, pkgs, ... }: # <-- Added 'inputs' here
let
  # Playit Agent Module
  playit = { ... }: {
    imports = [ inputs.playit-nixos-module.nixosModules.default ]; 
    services.playit = {
      enable = true;
      # Pointing directly to the generated secret file in your home directory.
      secretPath = "/home/sudha/.config/playit_gg/playit.toml"; 
    };
  };

  # Minecraft Server Module
  minecraft = { pkgs, ... }: {
    services.minecraft-server = {
      enable = true;
      eula = true; # Required by Mojang
      openFirewall = true; # Opens port 25565 by default
      package = pkgs.minecraft-server; 
      
      # Configure server.properties
      serverProperties = {
        server-port = 25565;
        online-mode = false; # Disables account verification to allow TLauncher/offline clients
        motd = "NixOS Minecraft Server";
      };
    };
  };

  targetHosts = [ "server" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = { ... }: {
      imports = [ 
        minecraft 
        playit
      ];
    };
  });
}