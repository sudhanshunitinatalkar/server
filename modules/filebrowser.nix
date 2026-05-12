{ lib, ... }:
let
  fb = { ... }: {
    services.filebrowser = {
      enable = true;
      settings = {
        port = 8001;
        address = "127.0.0.1";
      };
    };
  };

  targetHosts = [ "cosmosserver" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = fb;
  });
}