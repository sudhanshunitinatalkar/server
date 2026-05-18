{ lib, inputs, ... }:
let
  erpnext = { config, ... }: {
    
    # 1. Import SOPS
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # 2. Configure SOPS for this specific secret
    sops.secrets."erpnext.env" = {
      sopsFile = ../secrets/erpnext.env;
      format = "dotenv";
    };

    # 3. Ensure Docker volumes exist with the correct non-root permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -"
    ];

    # Ensure Docker is enabled
    virtualisation.docker.enable = true;
    
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        erpnext-db = {
          image = "mariadb:10.11";
          
          # 1. EXPOSE TO HOST LOCALLY: This allows the app to reach the DB 
          # without exposing your DB to the public internet.
          ports = [ "127.0.0.1:3306:3306" ];
          
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          environment = {
            MYSQL_DATABASE = "frappe";
            MYSQL_USER = "frappe";
          };
          volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
        };

        erpnext-app = {
          image = "frappe/erpnext:v15";
          dependsOn = [ "erpnext-db" ];
          
          # 2. THIS NOW WORKS: Host 8000 is mapped to Container 8080
          ports = [ "8000:8000" ];
          
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          environment = {
            # 3. USE DOCKER BRIDGE IP: In default Docker bridge networking, 
            # 172.17.0.1 routes traffic from the container back to the host machine.
            DB_HOST = "172.17.0.1"; 
            DB_PORT = "3306";
            DB_NAME = "frappe";
            DB_USER = "frappe";
          };
          volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
          
        };
      };
    };
  };

  targetHosts = [ 
    "server" 
  ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = erpnext;
  });
}