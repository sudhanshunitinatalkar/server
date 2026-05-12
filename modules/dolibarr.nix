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

  dolibarr_app = { ... }: {
    virtualisation.oci-containers = {
      # Explicitly use Docker instead of Podman
      backend = "docker"; 
      
      containers = {
        dolibarr-db = {
          image = "mariadb:10.6";
          environment = {
            # Allows MariaDB to boot completely raw without any passwords
            MYSQL_ALLOW_EMPTY_PASSWORD = "yes";
          };
          volumes = [ "/var/lib/dolibarr/db:/var/lib/mysql" ];
        };

        dolibarr-app = {
          # Using the official sponsored Dolibarr image
          image = "dolibarr/dolibarr:latest"; 
          ports = [ "127.0.0.1:8002:80" ];
          dependsOn = [ "dolibarr-db" ];
          environment = {
            # We REMOVED the database passwords so the Web Installer triggers.
            # We KEPT the HTTPS variables to prevent the Cloudflare infinite redirect loop.
            DOLI_URL_ROOT = "https://erp.protoplast.in";
            DOLI_PROD = "1";
            DOLI_HTTPS = "1";
          };
          volumes = [
            "/var/lib/dolibarr/html:/var/www/html"
            "/var/lib/dolibarr/docs:/var/www/documents"
          ];
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
        dolibarr_app 
        cloudflared
      ];
    };
  });
}