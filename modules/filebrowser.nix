{ lib, ... }:
let
  cloudflared = { ... }: {
    services.cloudflared = {
      enable = true;
      tunnels = {
        # Replace this UUID with your actual tunnel UUID
        "00000000-0000-0000-0000-000000000000" = {
          # Make sure the credentials file exists at this path and is readable by the cloudflared service
          credentialsFile = "/home/sudha/.cloudflared/00000000-0000-0000-0000-000000000000.json";
          
          ingress = {
            # Replace "files.yourdomain.com" with your actual Cloudflare domain route
            "files.yourdomain.com" = "http://localhost:8001";
          };
          
          # Fallback rule if the hostname doesn't match
          default = "http_status:404";
        };
      };
    };
  };

  filebrowser = { ... }: {
    services.filebrowser = {
      enable = true;
      settings = {
        port = 8001;
        address = "127.0.0.1";
      };
    };
  };

  targetHosts = [ 
    # "server" 
  ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = { ... }: {
      imports = [ 
        filebrowser 
        cloudflared
      ];
    };
  });
}