{ lib, inputs, ... }:

let
  frappeImage = "frappe/erpnext:v16.18.3";
  frappeNetwork = "frappe_network";

  erpnext = { config, pkgs, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops = {
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets."erpnext.env" = {
        sopsFile = ../secrets/erpnext.env;
        format = "dotenv";
      };
    };

    virtualisation.docker.enable = true;

    # Persistent storage and configuration initialization
    systemd.services."docker-erpnext-backend" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      preStart = ''
        mkdir -p /var/lib/erpnext/sites
        # Load secrets from sops and export them to a temporary file
        source ${config.sops.secrets."erpnext.env".path}
        
        # Write config using the secret values
        cat > /var/lib/erpnext/sites/common_site_config.json << EOF
        {
          "db_host": "erpnext-db",
          "db_port": 3306,
          "redis_cache": "redis://erpnext-redis-cache:6379",
          "redis_queue": "redis://erpnext-redis-queue:6379"
        }
        EOF
        echo -e "frappe\nerpnext" > /var/lib/erpnext/sites/apps.txt
        chown -R 1000:1000 /var/lib/erpnext/sites
      '';
    };

    virtualisation.oci-containers.containers = {
      erpnext-db = { 
        image = "mariadb:11.8"; 
        networks = [ frappeNetwork ]; 
        # Referencing secrets via sops file
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
        volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ]; 
      };
      
      erpnext-backend = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs" ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
        environment = { DB_HOST = "erpnext-db"; };
      };

      erpnext-frontend = { 
        image = frappeImage; 
        networks = [ frappeNetwork ]; 
        ports = [ "8080:8080" ]; 
        volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ]; 
        cmd = [ "nginx-entrypoint.sh" ]; 
        environment = { BACKEND = "erpnext-backend:8000"; }; 
      };
    };
  };

  targetHosts = [ "server" ];
in {
  configurations.nixos = lib.genAttrs targetHosts (name: { module = erpnext; });
}