{ lib, config, pkgs, ... }:
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

  dolibarr_native = { ... }: {
    # Provide the database password securely
    environment.etc."dolibarr-db-pass".text = "dolibarr_secret_database_pass";

    services.dolibarr = {
      enable = true;
      domain = "erp.protoplast.in";

      # Use local native MariaDB and the CORRECT password file option
      database = {
        createLocally = true;
        type = "mysql";
        passwordFile = "/etc/dolibarr-db-pass"; 
      };

      settings = {
        dolibarr_main_url_root = "https://erp.protoplast.in";
        dolibarr_main_force_https = lib.mkForce true;
      };

      # RAM OPTIMIZATION: Dial down the PHP workers
      poolConfig = {
        "pm" = "dynamic";
        "pm.max_children" = 10;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 3;
      };

      # Configure Nginx entirely inside the Dolibarr module
      nginx = {
        forceSSL = false;
        enableACME = false;
        
        listen = [ { addr = "127.0.0.1"; port = 8002; } ];
        
        # Bypasses the Cloudflare infinite redirect loop
        locations."~ [^/]\\.php(/|$)" = {
          fastcgiParams = {
            "HTTPS" = "on";
            "SERVER_PORT" = "443";
            "HTTP_X_FORWARDED_PROTO" = "https";
          };
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
        dolibarr_native 
        cloudflared
      ];
    };
  });
}