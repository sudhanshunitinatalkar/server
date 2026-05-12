{ lib, ... }:
let
  tsModule = { ... }: {
    services.tailscale.enable = true;
  };
  targetHosts = [ cosmosserver ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = tsModule;
  });
}