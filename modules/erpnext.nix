{ lib, inputs, ... }:

let
  frappeImage = "frappe/erpnext:v16.18.3";
  frappeNetwork = "frappe_network";

  erpnext = { config, pkgs, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops.secrets."erpnext.env" = {
      sopsFile = ../secrets/erpnext.env;
      format = "dotenv";
    };

    virtualisation.docker.enable = true;

    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -"
      "d /var/lib/erpnext/logs 0755 1000 1000 -"
    ];

    # Robust network creation
    systemd.services."docker-network-frappe_network" = {
      wantedBy = [ "multi-user.target" ];
      script = "docker network create ${frappeNetwork} || true";
      serviceConfig.Type = "oneshot";
    };

    # The Logic Engine: Ensures config and permissions are perfect BEFORE backend starts
    systemd.services."docker-erpnext-backend" = {
      preStart = ''
        mkdir -p /var/lib/erpnext/sites
        echo -e "frappe\nerpnext" > /var/lib/erpnext/sites/apps.txt
        cat > /var/lib/erpnext/sites/common_site_config.json << EOF
        {
          "db_host": "erpnext-db",
          "db_port": 3306,
          "redis_cache": "redis://erpnext-redis-cache:6379",
          "redis_queue": "redis://erpnext-redis-queue:6379",
          "redis_socketio": "redis://erpnext-redis-queue:6379"
        }
        EOF
        chown -R 1000:1000 /var/lib/erpnext/sites
      '';
    };

    virtualisation.oci-containers.containers = {
      erpnext-db = { 
        image = "mariadb:11.8"; 
        networks = [ frappeNetwork ]; 
        environment = { MYSQL_ROOT_PASSWORD = "admin"; }; 
        volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ]; 
      };
      erpnext-redis-cache = { image = "redis:6.2-alpine"; networks = [ frappeNetwork ]; };
      erpnext-redis-queue = { image = "redis:6.2-alpine"; networks = [ frappeNetwork ]; };

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
        environment = { BACKEND = "erpnext-backend:8000"; SOCKETIO = "erpnext-websocket:9000"; }; 
      };
      
      erpnext-websocket = { 
        image = frappeImage; 
        networks = [ frappeNetwork ]; 
        volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ]; 
        cmd = [ "node" "/home/frappe/frappe-bench/apps/frappe/socketio.js" ]; 
        environment = { FRAPPE_REDIS_CACHE = "redis://erpnext-redis-cache:6379"; };
      };
      
      erpnext-queue-long = { image = frappeImage; networks = [ frappeNetwork ]; volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ]; cmd = [ "bench" "worker" "--queue" "long,default,short" ]; };
      erpnext-scheduler = { image = frappeImage; networks = [ frappeNetwork ]; volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ]; cmd = [ "bench" "schedule" ]; };
    };
  };

  targetHosts = [ 
    "server" 
    ];
in {
  configurations.nixos = lib.genAttrs targetHosts (name: { module = erpnext; });
}