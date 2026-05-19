{ lib, inputs, ... }:
let
  # -----------------------------------------------------------------
  # Shared variables to keep the Nix code DRY and clean
  # -----------------------------------------------------------------
  frappeImage = "frappe/erpnext:v15";
  frappeNginxImage = "frappe/erpnext-nginx:v15";
  
  commonVolumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
  commonOptions = [ "--network=erpnext-net" ];

  erpnext = { config, pkgs, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops.secrets."erpnext.env" = {
      sopsFile = ../secrets/erpnext.env;
      format = "dotenv";
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -"
    ];

    virtualisation.docker.enable = true;
    
    # -----------------------------------------------------------------
    # THE OFFICIAL FRAPPE MICROSERVICE ARCHITECTURE
    # -----------------------------------------------------------------
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        
        # --- 1. DATABASES & CACHES ---
        erpnext-db = {
          image = "mariadb:10.6"; # Frappe officially recommends 10.6
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          environment = {
            MYSQL_DATABASE = "frappe";
            MYSQL_USER = "frappe";
          };
          volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
          extraOptions = commonOptions;
        };

        erpnext-redis-cache = { image = "redis:7-alpine"; extraOptions = commonOptions; };
        erpnext-redis-queue = { image = "redis:7-alpine"; extraOptions = commonOptions; };
        erpnext-redis-socketio = { image = "redis:7-alpine"; extraOptions = commonOptions; };

        # --- 2. CORE BACKEND ---
        erpnext-backend = {
          image = frappeImage;
          dependsOn = [ "erpnext-db" "erpnext-redis-cache" "erpnext-redis-queue" "erpnext-redis-socketio" ];
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          volumes = commonVolumes;
          extraOptions = commonOptions;
        };

        # --- 3. FRONTEND (Nginx) ---
        erpnext-frontend = {
          image = frappeNginxImage;
          dependsOn = [ "erpnext-backend" "erpnext-websocket" ];
          ports = [ "8001:8080" ]; # Expose to host on 8001
          environment = {
            BACKEND = "erpnext-backend:8000";
            SOCKETIO = "erpnext-websocket:9000";
            UPSTREAM_REAL_IP_ADDRESS = "127.0.0.1";
            FRAPPE_SITE_NAME_HEADER = "erp.yourdomain.com"; # Replace with your actual domain
          };
          volumes = commonVolumes;
          extraOptions = commonOptions;
        };

        # --- 4. REAL-TIME WEBSOCKETS ---
        erpnext-websocket = {
          image = frappeImage;
          dependsOn = [ "erpnext-redis-socketio" ];
          cmd = [ "node" "/home/frappe/frappe-bench/apps/frappe/socketio.js" ];
          volumes = commonVolumes;
          extraOptions = commonOptions;
        };

        # --- 5. BACKGROUND WORKERS ---
        erpnext-queue-default = {
          image = frappeImage;
          dependsOn = [ "erpnext-backend" ];
          cmd = [ "bench" "worker" "--queue" "default" ];
          volumes = commonVolumes;
          extraOptions = commonOptions;
        };

        erpnext-queue-short = {
          image = frappeImage;
          dependsOn = [ "erpnext-backend" ];
          cmd = [ "bench" "worker" "--queue" "short" ];
          volumes = commonVolumes;
          extraOptions = commonOptions;
        };

        erpnext-queue-long = {
          image = frappeImage;
          dependsOn = [ "erpnext-backend" ];
          cmd = [ "bench" "worker" "--queue" "long" ];
          volumes = commonVolumes;
          extraOptions = commonOptions;
        };

        erpnext-scheduler = {
          image = frappeImage;
          dependsOn = [ "erpnext-backend" ];
          cmd = [ "bench" "schedule" ];
          volumes = commonVolumes;
          extraOptions = commonOptions;
        };
      };
    };

    # -----------------------------------------------------------------
    # AUTOMATED CONFIGURATION HOOK
    # -----------------------------------------------------------------
    # This completely eliminates the need for manual 'bench set-config' commands.
    # It executes right before the backend container boots up.
    systemd.services."docker-erpnext-backend".preStart = ''
      mkdir -p /var/lib/erpnext/sites
      
      echo -e "frappe\nerpnext" > /var/lib/erpnext/sites/apps.txt
      
      cat > /var/lib/erpnext/sites/common_site_config.json << 'EOF'
      {
        "db_host": "erpnext-db",
        "db_port": 3306,
        "redis_cache": "redis://erpnext-redis-cache:6379",
        "redis_queue": "redis://erpnext-redis-queue:6379",
        "redis_socketio": "redis://erpnext-redis-socketio:6379",
        "socketio_port": 9000
      }
      EOF
      
      chown -R 1000:1000 /var/lib/erpnext/sites
    '';

    # Create the Docker network
    systemd.services."docker-network-erpnext-net" = {
      description = "Create Docker Network erpnext-net";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${config.virtualisation.docker.package}/bin/docker network create erpnext-net";
        ExecStop = "${config.virtualisation.docker.package}/bin/docker network rm erpnext-net";
      };
    };
  };

  targetHosts = [ "server" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = erpnext;
  });
}