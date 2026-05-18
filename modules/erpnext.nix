{ lib, inputs, ... }:
let
  erpnext = { config, ... }: {
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
    
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        erpnext-db = {
          image = "mariadb:10.11";
          # Expose locally
          ports = [ "127.0.0.1:3306:3306" ];
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          environment = {
            MYSQL_DATABASE = "frappe";
            MYSQL_USER = "frappe";
          };
          volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
          extraOptions = [ "--network=erpnext-net" ]; # <--- ADDED
        };

        erpnext-app = {
          image = "frappe/erpnext:v15";
          dependsOn = [ "erpnext-db" ];
          ports = [ "8000:8000" ];
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          environment = {
            DB_HOST = "erpnext-db"; # <--- CHANGED TO CONTAINER NAME
            DB_PORT = "3306";
            DB_NAME = "frappe";
            DB_USER = "frappe";
          };
          volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
          extraOptions = [ "--network=erpnext-net" ]; # <--- ADDED
        };
      };
    };

    # Automatically create the custom Docker network
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

  targetHosts = [ 
    # "server" 
    ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = erpnext;
  });
}