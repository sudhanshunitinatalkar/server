{ inputs, lib, ... }: 
let
  # Create a small module that imports the one from your other flake
  app-integration = { ... }: {
    imports = [ 
      inputs.my-app-flake.nixosModules.default 
    ];
  };

  targetHosts = [ "server" ];
in
{
  # Attach it to the "server" host just like you did with your other modules
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = app-integration;
  });
}