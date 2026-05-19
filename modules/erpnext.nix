# erpnext.nix
{ lib, inputs, config, pkgs, ... }:
let
  erpnext = { config, pkgs, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # Allow overriding ERPNext version via config.erpnext.version
    options.erpnext.version = lib.mkOption {
      type = lib.types.str;
      default = "v16.18.3";
      description = "Frappe/ERPNext Docker image tag";
    };

    config = {
      sops = {
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        secrets."erpnext/env" = {
          sopsFile = ../secrets/erpnext.env;
          format = "dotenv";
        };
      };

      environment.etc."erpnext/docker-compose.yml" = {
        text = builtins.toJSON {
          version = "3.8";
          services = {
            db = {
              image = "mariadb:11.8";
              command = [
                "--character-set-server=utf8mb4"
                "--collation-server=utf8mb4_unicode_ci"
                "--skip-character-set-client-handshake"
              ];
              environment = {
                MYSQL_ROOT_PASSWORD = "\${MYSQL_ROOT_PASSWORD}";
              };
              volumes = [ "/var/lib/erpnext/db:/var/lib/mysql" ];
              restart = "unless-stopped";
              healthcheck = {
                test = [ "CMD" "mysqladmin" "ping" "-h" "localhost" "--password=\${MYSQL_ROOT_PASSWORD}" ];
                interval = "10s";
                timeout = "5s";
                retries = 5;
              };
            };
            redis-cache = {
              image = "redis:6.2-alpine";
              restart = "unless-stopped";
            };
            redis-queue = {
              image = "redis:6.2-alpine";
              volumes = [ "/var/lib/erpnext/redis-queue:/data" ];
              restart = "unless-stopped";
            };
            configurator = {
              image = "frappe/erpnext:${config.erpnext.version}";
              entrypoint = [ "bash" "-c" ];
              command = ''
                ls -1 apps > sites/apps.txt;
                bench set-config -g db_host db;
                bench set-config -gp db_port 3306;
                bench set-config -g redis_cache "redis://redis-cache:6379";
                bench set-config -g redis_queue "redis://redis-queue:6379";
                bench set-config -g redis_socketio "redis://redis-queue:6379";
                bench set-config -gp socketio_port 9000;
                bench set-config -g chromium_path /usr/bin/chromium-headless-shell;
              '';
              environment = {
                DB_HOST = "db";
                DB_PORT = "3306";
                REDIS_CACHE = "redis-cache:6379";
                REDIS_QUEUE = "redis-queue:6379";
                SOCKETIO_PORT = "9000";
              };
              volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
              depends_on = {
                db = { condition = "service_healthy"; };
                redis-cache = { condition = "service_started"; };
                redis-queue = { condition = "service_started"; };
              };
              restart = "on-failure";
            };
            create-site = {
              image = "frappe/erpnext:${config.erpnext.version}";
              entrypoint = [ "bash" "-c" ];
              command = ''
                wait-for-it -t 120 db:3306;
                wait-for-it -t 120 redis-cache:6379;
                wait-for-it -t 120 redis-queue:6379;
                export start=$(date +%s);
                until [[ -n $(grep -hs ^ sites/common_site_config.json | jq -r ".db_host // empty") ]] && \
                      [[ -n $(grep -hs ^ sites/common_site_config.json | jq -r ".redis_cache // empty") ]] && \
                      [[ -n $(grep -hs ^ sites/common_site_config.json | jq -r ".redis_queue // empty") ]]; do
                  echo "Waiting for sites/common_site_config.json...";
                  sleep 5;
                  if (( $(date +%s) - start > 120 )); then
                    echo "Timeout: common_site_config.json not found";
                    exit 1;
                  fi;
                done;
                echo "Creating site frontend";
                bench new-site \
                  --mariadb-user-host-login-scope='%' \
                  --admin-password="''${ADMIN_PASSWORD}" \
                  --db-root-username=root \
                  --db-root-password="''${MYSQL_ROOT_PASSWORD}" \
                  --install-app erpnext \
                  --set-default frontend;
              '';
              environment = {
                ADMIN_PASSWORD = "\${ADMIN_PASSWORD}";
                MYSQL_ROOT_PASSWORD = "\${MYSQL_ROOT_PASSWORD}";
              };
              volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
              depends_on = { configurator = { condition = "service_completed_successfully"; }; };
              restart = "no";
            };
            backend = {
              image = "frappe/erpnext:${config.erpnext.version}";
              volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
              depends_on = { configurator = { condition = "service_completed_successfully"; }; };
              restart = "unless-stopped";
            };
            frontend = {
              image = "frappe/erpnext:${config.erpnext.version}";
              command = [ "nginx-entrypoint.sh" ];
              environment = {
                BACKEND = "backend:8000";
                SOCKETIO = "websocket:9000";
                FRAPPE_SITE_NAME_HEADER = "erp.protoplast.in";
                UPSTREAM_REAL_IP_ADDRESS = "127.0.0.1";
                UPSTREAM_REAL_IP_HEADER = "X-Forwarded-For";
                PROXY_READ_TIMEOUT = "120";
                CLIENT_MAX_BODY_SIZE = "50m";
              };
              volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
              depends_on = [ "backend" "websocket" ];
              ports = [ "8080:8080" ];
              restart = "unless-stopped";
            };
            websocket = {
              image = "frappe/erpnext:${config.erpnext.version}";
              command = [ "node" "/home/frappe/frappe-bench/apps/frappe/socketio.js" ];
              volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
              depends_on = { configurator = { condition = "service_completed_successfully"; }; };
              restart = "unless-stopped";
            };
            queue-short = {
              image = "frappe/erpnext:${config.erpnext.version}";
              command = [ "bench" "worker" "--queue" "short,default" ];
              volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
              depends_on = { configurator = { condition = "service_completed_successfully"; }; };
              restart = "unless-stopped";
            };
            queue-long = {
              image = "frappe/erpnext:${config.erpnext.version}";
              command = [ "bench" "worker" "--queue" "long,default,short" ];
              volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
              depends_on = { configurator = { condition = "service_completed_successfully"; }; };
              restart = "unless-stopped";
            };
            scheduler = {
              image = "frappe/erpnext:${config.erpnext.version}";
              command = [ "bench" "schedule" ];
              volumes = [ "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites" ];
              depends_on = { configurator = { condition = "service_completed_successfully"; }; };
              restart = "unless-stopped";
            };
          };
        };
      };

      systemd.services.erpnext = {
        description = "ERPNext Docker Compose Stack";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" "docker.service" ];
        requires = [ "docker.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "/etc/erpnext";
          EnvironmentFile = config.sops.secrets."erpnext/env".path;
          ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f /etc/erpnext/docker-compose.yml up -d";
          ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f /etc/erpnext/docker-compose.yml down";
          ExecReload = "${pkgs.docker-compose}/bin/docker-compose -f /etc/erpnext/docker-compose.yml restart";
          Restart = "no";
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