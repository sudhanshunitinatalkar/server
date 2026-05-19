{ lib, inputs, ... }:
let
  # Official images from the repo you provided
  frappeImage = "frappe/erpnext:v16.18.3";
  
  commonVolumes = [
    "erpnext_sites:/home/frappe/frappe-bench/sites"
    "erpnext_logs:/home/frappe/frappe-bench/logs"
  ];
  commonNetwork = [ "frappe_network" ];

  erpnext = { config, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops.secrets."erpnext.env" = {
      sopsFile = ../secrets/erpnext.env;
      format = "dotenv";
    };

    virtualisation.docker.enable = true;

    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        # Databases & Caches
        erpnext-db = {
          image = "mariadb:11.8";
          networks = commonNetwork;
          environment = { MYSQL_ROOT_PASSWORD = "admin"; MARIADB_ROOT_PASSWORD = "admin"; };
          volumes = [ "erpnext_db_data:/var/lib/mysql" ];
        };
        erpnext-redis-cache = { image = "redis:6.2-alpine"; networks = commonNetwork; };
        erpnext-redis-queue = { 
          image = "redis:6.2-alpine"; 
          networks = commonNetwork; 
          volumes = [ "erpnext_redis_data:/data" ];
        };

        # Application Backend
        erpnext-backend = {
          image = frappeImage;
          networks = commonNetwork;
          volumes = commonVolumes;
          environment = { DB_HOST = "erpnext-db"; DB_PORT = "3306"; };
        };

        # Frontend Proxy
        erpnext-frontend = {
          image = frappeImage;
          networks = commonNetwork;
          ports = [ "8080:8080" ];
          volumes = commonVolumes;
          environment = { BACKEND = "erpnext-backend:8000"; SOCKETIO = "erpnext-websocket:9000"; };
          cmd = [ "nginx-entrypoint.sh" ];
        };

        # Background Workers & Scheduler
        erpnext-websocket = { image = frappeImage; networks = commonNetwork; volumes = commonVolumes; cmd = [ "node" "/home/frappe/frappe-bench/apps/frappe/socketio.js" ]; };
        erpnext-queue-long = { image = frappeImage; networks = commonNetwork; volumes = commonVolumes; cmd = [ "bench" "worker" "--queue" "long,default,short" ]; };
        erpnext-queue-short = { image = frappeImage; networks = commonNetwork; volumes = commonVolumes; cmd = [ "bench" "worker" "--queue" "short,default" ]; };
        erpnext-scheduler = { image = frappeImage; networks = commonNetwork; volumes = commonVolumes; cmd = [ "bench" "schedule" ]; };
      };
    };

    # Auto-initialize network and persistent volumes
    systemd.services."docker-network-frappe_network" = {
      description = "Create Docker Network frappe_network";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${config.virtualisation.docker.package}/bin/docker network create frappe_network";
      };
    };
  };

  targetHosts = [ "server" ];
in {
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = erpnext;
  });
}