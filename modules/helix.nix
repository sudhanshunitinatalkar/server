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
in
{
  configurations.home."sudha@cosmoslaptop".module = helix;
}
