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
            "*" = "http_status:404";
          };
        };
      };
    };
  };

  dolibarr_app = { ... }: {
    # This natively spins up Docker containers using NixOS declarations
    virtualisation.oci-containers.containers = {
      
      # 1. The Database Container
      dolibarr-db = {
        image = "mariadb:10.6";
        environment = {
          MYSQL_ROOT_PASSWORD = "strong_root_password"; # Change this
          MYSQL_USER = "dolibarr";
          MYSQL_PASSWORD = "dolibarr_db_password";      # Change this
          MYSQL_DATABASE = "dolibarr";
        };
        # Mounts the database data to your host so it persists across reboots
        volumes = [ "/var/lib/dolibarr/db:/var/lib/mysql" ];
      };

      # 2. The Dolibarr Application Container
      dolibarr-app = {
        image = "tuxgasy/dolibarr:latest"; # The most actively maintained Dolibarr image
        ports = [ "127.0.0.1:8002:80" ];   # Exposes it strictly to localhost for Cloudflare
        dependsOn = [ "dolibarr-db" ];
        environment = {
          DOLI_DB_HOST = "dolibarr-db";
          DOLI_DB_USER = "dolibarr";
          DOLI_DB_PASSWORD = "dolibarr_db_password";    # Must match the DB password above
          DOLI_DB_NAME = "dolibarr";
          
          # This completely bypasses the Cloudflare reverse-proxy confusion
          DOLI_URL_ROOT = "https://erp.protoplast.in";
          DOLI_PROD = "1";
          DOLI_HTTPS = "1";
        };
        # Mounts your ERP documents and custom modules to the host
        volumes = [
          "/var/lib/dolibarr/html:/var/www/html"
          "/var/lib/dolibarr/docs:/var/www/documents"
        ];
      };
    };
  };

  targetHosts = [ "server" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = { ... }: {
      imports = [ 
        dolibarr_app 
        cloudflared
      ];
    };
  });
}