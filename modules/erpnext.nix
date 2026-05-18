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

    # Ensure Docker is enabled
    virtualisation.docker.enable = true;
    
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        erpnext-db = {
          image = "mariadb:10.11";
          
          # INJECT SECRETS HERE: NixOS will securely map the decrypted RAM file to the container
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          
          # Only non-sensitive data remains in the public code
          environment = {
            MYSQL_DATABASE = "frappe";
            MYSQL_USER = "frappe";
          };
          volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
        };

        erpnext-app = {
          image = "frappe/erpnext:v15";
          dependsOn = [ "erpnext-db" ];
          ports = [ "8000:8080" ];
          
          # INJECT SECRETS HERE TOO: Both containers can read the same secure .env file
          environmentFiles = [ config.sops.secrets."erpnext.env".path ];
          
          environment = {
            DB_HOST = "127.0.0.1";
            DB_PORT = "3306";
            DB_NAME = "frappe";
            DB_USER = "frappe";
          };
          volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
          extraOptions = [ "--network=host" ];
        };
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