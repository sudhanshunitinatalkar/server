{ lib, ... }:
let
  cloudflared = { ... }: {
    services.cloudflared = {
      enable = true;
      tunnels = {
        # Using the same UUID from your filebrowser.nix
        "7513def7-e0e2-400d-b63e-7e01ee6e3938" = {
          credentialsFile = "/home/sudha/.cloudflared/7513def7-e0e2-400d-b63e-7e01ee6e3938.json";
          ingress = {
            # Replace with your desired ERPNext domain
            "erp.protoplast.in" = "http://localhost:8000";
            
            # Fallback rule
            default = "http_status:404";
          };
        };
      };
    };
  };

  erpnext = { ... }: {
    # Ensure Docker is enabled for the OCI backend
    virtualisation.docker.enable = true;

    virtualisation.oci-containers = {
      backend = "docker"; 
      
      containers = {
        erpnext-db = {
          image = "mariadb:10.11";
          environment = {
            MYSQL_ROOT_PASSWORD = "your_secure_root_password";
            MYSQL_DATABASE = "frappe";
            MYSQL_USER = "frappe";
            MYSQL_PASSWORD = "your_frappe_password";
          };
          # Mounts database data to your host HDD so it persists reboots
          volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
          # Run on the host network so localhost routing works easily
          extraOptions = [ "--network=host" ];
        };

        erpnext-app = {
          image = "frappe/erpnext:v15";
          dependsOn = [ "erpnext-db" ];
          # We map the container's 8080 port to the host's 8000 port for Cloudflare
          ports = [ "8000:8080" ]; 
          environment = {
            DB_HOST = "127.0.0.1";
            DB_PORT = "3306";
            DB_NAME = "frappe";
            DB_USER = "frappe";
            DB_PASSWORD = "your_frappe_password";
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
    module = { ... }: {
      imports = [ 
        erpnext 
        cloudflared
      ];
    };
  });
}