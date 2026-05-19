{ lib, inputs, config, pkgs, ... }:

let
  # Using image tags provided in your uploaded compose.yaml
  frappeImage = "frappe/erpnext:v16.18.3";
  
  # Ensure the docker network exists before containers start
  mkNetwork = "docker network create frappe_network || true";

in {
  # 1. Enable Docker
  virtualisation.docker.enable = true;

  # 2. Secret Management via sops-nix
  sops.secrets."erpnext.env" = {
    sopsFile = ../secrets/erpnext.env;
    format = "dotenv";
  };

  # 3. Create persistent storage on the host
  systemd.tmpfiles.rules = [
    "d /var/lib/erpnext/sites 0755 1000 1000 -"
    "d /var/lib/erpnext/mysql 0755 999 999 -"
    "d /var/lib/erpnext/logs 0755 1000 1000 -"
  ];

  # 4. Declarative Containers
  virtualisation.oci-containers.containers = {
    erpnext-db = {
      image = "mariadb:11.8";
      networks = [ "frappe_network" ];
      environment = { MYSQL_ROOT_PASSWORD = "admin"; MARIADB_ROOT_PASSWORD = "admin"; };
      volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
    };

    erpnext-backend = {
      image = frappeImage;
      networks = [ "frappe_network" ];
      volumes = [ 
        "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
        "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
      ];
      environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      environment = { DB_HOST = "erpnext-db"; DB_PORT = "3306"; };
    };

    erpnext-frontend = {
      image = frappeImage;
      networks = [ "frappe_network" ];
      ports = [ "8080:8080" ];
      volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
      cmd = [ "nginx-entrypoint.sh" ];
      environment = { BACKEND = "erpnext-backend:8000"; SOCKETIO = "erpnext-websocket:9000"; };
    };
  };

  # 5. Network Initialization
  systemd.services."docker-network-frappe_network" = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.docker ];
    script = mkNetwork;
  };
}