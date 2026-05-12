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
          };
          default = "http_status:404";
        };
      };
    };
  };

  ledgersmb_purist = { pkgs, config, ... }: {
    # 1. Enable the official LedgerSMB service
    services.ledgersmb = {
      enable = true;
    };

    # 2. PostgreSQL is required for LedgerSMB (The data integrity engine)
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      settings = {
        # Optimized for 4GB RAM
        shared_buffers = "256MB";
        work_mem = "16MB";
      };
    };

    # 3. Nginx Bridge for Cloudflare
    services.nginx = {
      enable = true;
      virtualHosts."erp.protoplast.in" = {
        listen = [ { addr = "127.0.0.1"; port = 8002; } ];
        locations."/" = {
          # LedgerSMB's Starman backend typically listens on port 5762
          proxyPass = "http://127.0.0.1:5762";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
      };
    };
  };

  targetHosts = [ "server" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = { ... }: {
      imports = [ 
        ledgersmb_purist 
        cloudflared
      ];
    };
  });
}