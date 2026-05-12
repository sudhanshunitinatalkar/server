{ lib, ... }:
let
  
  
  targetHosts = [ 
    # "server" 
  ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = cloudflare_tunnel;
  });
}