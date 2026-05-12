{ lib, ... }:
let
  cloudflared = { ... }: {
    services.cloudflared = {
      enable = true;
      tunnels = {
        "2815841f-6d4d-4fb5-adf0-5c82ecab3238" = {
          credentialsFile = "/home/sudha/.cloudflared/2815841f-6d4d-4fb5-adf0-5c82ecab3238.json";
          
          ingress = {
            "erp.protoplast.in" = "http://localhost:8002";
            # (Remove the "*" = "http_status:404"; from here if you still have it)
          };
          
          # PUT THIS BACK HERE: The dedicated NixOS fallback rule
          default = "http_status:404";
        };
      };
    };
  };

  dolibarr = { ... }: {
    services.dolibarr = {
      enable = true;
      domain = "erp.protoplast.in"; 
      
      database = {
        createLocally = true;
      };

      nginx = {
        forceSSL = false;
        enableACME = false;
      };

      # 1. Hardcode the correct public URL so Dolibarr stops guessing
      settings = {
        dolibarr_main_url_root = "https://erp.protoplast.in";
        dolibarr_main_force_https = "1";
      };
    };

    # 2. Trick Nginx & PHP into knowing they are behind an HTTPS proxy
    services.nginx.virtualHosts."erp.protoplast.in" = {
      listen = [ { addr = "127.0.0.1"; port = 8002; } ];
      extraConfig = ''
        fastcgi_param HTTPS on;
        fastcgi_param SERVER_PORT 443;
        fastcgi_param HTTP_X_FORWARDED_PROTO https;
      '';
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