{ lib, inputs, ... }:
let
  erpnext = { config, pkgs, ... }: {
    
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # 1. Secret Management
    sops.secrets."erpnext.env" = {
      sopsFile = ../secrets/erpnext.env;
      format = "dotenv";
    };

    # 2. Host Directories for Persistent Data
    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -"
    ];

    # 3. Enable Docker Backend
    virtualisation.docker.enable = true;
    
    # 4. Declarative OCI Containers
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        
        # Redis is required by Frappe for Cache, Queue, and SocketIO
        erpnext-redis = {
          image = "redis:7-alpine";
          extraOptions = [ "--network=erpnext-net" ];
        };

        # MariaDB Database Container
        erpnext-db = {
          image = "mariadb:10.11";
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          environment = {
            MYSQL_DATABASE = "frappe";
            MYSQL_USER = "frappe";
          };
          volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
          extraOptions = [ "--network=erpnext-net" ];
        };

        # Main ERPNext/Frappe Application
        erpnext-app = {
          image = "frappe/erpnext:v15";
          dependsOn = [ "erpnext-db" "erpnext-redis" ];
          # Host Port 8001 mapped to Container Port 8000
          ports = [ "8001:8000" ];
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          environment = {
            DB_HOST = "erpnext-db"; 
            DB_PORT = "3306";
            DB_NAME = "frappe";
            DB_USER = "frappe";
            REDIS_CACHE = "redis://erpnext-redis:6379";
            REDIS_QUEUE = "redis://erpnext-redis:6379";
            REDIS_SOCKETIO = "redis://erpnext-redis:6379";
          };
          volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
          extraOptions = [ "--network=erpnext-net" ]; 
        };
      };
    };

    # 5. Automatically create the custom Docker network
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