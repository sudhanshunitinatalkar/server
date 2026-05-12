{ lib, config, pkgs, ... }:
let
  cloudflared = { ... }: {
    services.cloudflared = {
      enable = true;
      tunnels = {
        "2815841f-6d4d-4fb5-adf0-5c82ecab3238" = {
          credentialsFile = "/home/sudha/.cloudflared/2815841f-6d4d-4fb5-adf0-5c82ecab3238.json";
          ingress = {
            "erp.protoplast.in" = "http://localhost:8002";
          };
          default = "http_status:404";
        };
      };
    };
  };

  weberp_native = { ... }: {
    # 1. Lightweight Database
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ "weberp" ];
      ensureUsers = [{
        name = "weberp";
        ensurePermissions = { "weberp.*" = "ALL PRIVILEGES"; };
      }];
    };

    # 2. PHP-FPM configured for your 4GB RAM system
    services.phpfpm.pools.weberp = {
      user = "weberp";
      group = "nginx";
      phpPackage = pkgs.php83.buildEnv {
        # webERP only needs these basic extensions
        extensions = ({ enabled, all }: enabled ++ [ all.mysqli all.gd all.gettext ]);
      };
      settings = {
        "pm" = "dynamic";
        "pm.max_children" = 10;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 3;
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        
        # Cloudflare HTTPS Injection
        "env[HTTPS]" = "on";
        "env[SERVER_PORT]" = "443";
        "env[HTTP_X_FORWARDED_PROTO]" = "https";
      };
    };

    # 3. Nginx (No fighting, just serving raw files)
    services.nginx = {
      enable = true;
      virtualHosts."erp.protoplast.in" = {
        listen = [ { addr = "127.0.0.1"; port = 8002; } ];
        root = "/var/www/weberp";
        locations."/" = {
          index = "index.php";
        };
        locations."~ \\.php$" = {
          extraConfig = ''
            fastcgi_pass unix:${config.services.phpfpm.pools.weberp.socket};
            fastcgi_index index.php;
            include ${pkgs.nginx}/conf/fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          '';
        };
      };
    };

    # 4. Give webERP its own secure user on the system
    users.users.weberp = {
      isSystemUser = true;
      group = "nginx";
    };
  };

  targetHosts = [ "server" ];
in
{
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = { ... }: {
      imports = [ 
        weberp_native 
        cloudflared
      ];
    };
  });
}