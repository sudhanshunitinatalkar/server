{ lib, ... }:
let
  tsModule = { ... }: {
    services.tailscale.enable = true;
  };
  targetHosts = [ 
    # "server" 
  ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = tsModule;
  });
}