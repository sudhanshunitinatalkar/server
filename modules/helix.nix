{ ... }:
let
  helix = { ... }:{
    programs.helix = {
      enable = true;
      settings = {
        keys.insert = {
          "C-c" = "normal_mode"; # Press Ctrl + C to escape instantly
        };
      };
    };
  };

  targetUserHosts = [
    "sudha@cosmoslaptop"
    "sudha@cosmosserver"
  ]
in
{
  configurations.home = lib.genAttrs targetUserHosts (name: {
    module = helix;
  });
}
