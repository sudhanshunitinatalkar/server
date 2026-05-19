{ lib, inputs, ... }:

let
  erpnext = { config, pkgs, ... }: {
    # 1. Import SOPS for secret management
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # 2. Configure SOPS
    sops = {
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets."erpnext.env" = {
        sopsFile = ../secrets/erpnext.env;
        format = "dotenv";
      };
    };

    # 3. Enable Docker
    virtualisation.docker.enable = true;

    # 4. Persistent Storage (Host path)
    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -"
      "d /var/lib/erpnext/logs 0755 1000 1000 -"
    ];

    # 5. Network Initialization
    systemd.services."docker-network-frappe_network" = {
      description = "Create Docker Network frappe_network";
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.docker ];
      script = "docker network create frappe_network || true";
      serviceConfig.Type = "oneshot";
    };

    # 6. Declarative OCI Containers
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        erpnext-db = {
          image = "mariadb:11.8";
          networks = [ "frappe_network" ];
          environment = { MYSQL_ROOT_PASSWORD = "admin"; MARIADB_ROOT_PASSWORD = "admin"; };
          volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
        };

        erpnext-backend = {
          image = "frappe/erpnext:v16.18.3";
          networks = [ "frappe_network" ];
          volumes = [ 
            "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
            "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
          ];
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          environment = { DB_HOST = "erpnext-db"; DB_PORT = "3306"; };
        };

        erpnext-frontend = {
          image = "frappe/erpnext:v16.18.3";
          networks = [ "frappe_network" ];
          ports = [ "8080:8080" ];
          volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
          cmd = [ "nginx-entrypoint.sh" ];
          environment = { BACKEND = "erpnext-backend:8000"; SOCKETIO = "erpnext-websocket:9000"; };
        };
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