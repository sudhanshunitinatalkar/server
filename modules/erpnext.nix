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

    # Persistent storage setup
    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -"
      "d /var/lib/erpnext/logs 0755 1000 1000 -"
      "d /var/lib/erpnext/redis 0755 999 999 -"
    ];

    # Ensure network exists
    systemd.services."docker-network-frappe_network" = {
      wantedBy = [ "multi-user.target" ];
      script = "docker network create ${frappeNetwork} || true";
      serviceConfig.Type = "oneshot";
    };

    virtualisation.oci-containers.containers = {
      # --- Infrastructure ---
      erpnext-db = {
        image = "mariadb:11.8";
        networks = [ frappeNetwork ];
        environment = { MYSQL_ROOT_PASSWORD = "admin"; MARIADB_ROOT_PASSWORD = "admin"; };
        volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
      };
      erpnext-redis-cache = { image = "redis:6.2-alpine"; networks = [ frappeNetwork ]; };
      erpnext-redis-queue = { image = "redis:6.2-alpine"; networks = [ frappeNetwork ]; volumes = [ "/var/lib/erpnext/redis:/data" ]; };

      # --- Backend ---
      erpnext-backend = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs" ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
        environment = { DB_HOST = "erpnext-db"; DB_PORT = "3306"; };
      };

      # --- Frontend/Websocket ---
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
      };

      # --- Workers/Scheduler ---
      erpnext-queue-long = { image = frappeImage; networks = [ frappeNetwork ]; volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ]; cmd = [ "bench" "worker" "--queue" "long,default,short" ]; };
      erpnext-queue-short = { image = frappeImage; networks = [ frappeNetwork ]; volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ]; cmd = [ "bench" "worker" "--queue" "short,default" ]; };
      erpnext-scheduler = { image = frappeImage; networks = [ frappeNetwork ]; volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ]; cmd = [ "bench" "schedule" ]; };
    };
  };

  targetHosts = [ "server" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = erpnext;
  });
}