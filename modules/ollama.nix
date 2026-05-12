{ lib, ... }:
let
  ollama_cuda = { pkgs, ... }:
  {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
    };
  };
  targetHosts = [ "cosmoslaptop" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = ollama_cuda;
  });
}