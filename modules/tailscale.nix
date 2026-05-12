{ lib, ... }:
let
  tsModule = { ... }: {
    services.tailscale.enable = true;
  };
  targetHosts = [ ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = tsModule;
  });
}