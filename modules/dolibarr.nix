{ lib, ... }:
let
  cloudflared = { ... }: {
    services.cloudflared = {
      enable = true;
      tunnels = {
        # Using the same UUID from your example
        "2815841f-6d4d-4fb5-adf0-5c82ecab3238" = {
          credentialsFile = "/home/sudha/.cloudflared/2815841f-6d4d-4fb5-adf0-5c82ecab3238.json";
          
          ingress = {
            # Route the ERP domain to the internal Nginx port
            "erp.protoplast.in" = "http://localhost:8002";
            
            # Cloudflared REQUIRES a catch-all rule at the end, or the service will fail to start
            "*" = "http_status:404";
          };
        };
      };
    };
  };

  dolibarr = { ... }: {
    services.dolibarr = {
      enable = true;
      domain = "erp.protoplast.in"; 
      
      # Automatically provision and configure a local PostgreSQL database
      database = {
        createLocally = true;
      };

      # Disable forced SSL since Cloudflare is handling the HTTPS wrapper
      nginx = {
        forceSSL = false;
      };
    };

    # Explicitly tell Nginx to listen on localhost so the Cloudflare tunnel can reach it
    services.nginx.virtualHosts."erp.protoplast.in" = {
      listen = [ { addr = "127.0.0.1"; port = 8002; } ];
    };
  };

  targetHosts = [ 
    "server" 
  ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = { ... }: {
      imports = [ 
        dolibarr 
        cloudflared
      ];
    };
  });
}