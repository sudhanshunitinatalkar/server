Perfect. Here's everything you need.

---

## `erpnext.nix`

```nix
{ lib, inputs, ... }:

let
  frappeImage = "frappe/erpnext:v16.18.3";
  frappeNetwork = "frappe_network";

  erpnext = { config, pkgs, ... }: {

    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops = {
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets."erpnext.env" = {
        sopsFile = ../secrets/erpnext.env;
        format = "dotenv";
      };
    };

    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    # Create the docker bridge network before any container starts
    systemd.services."docker-network-frappe" = {
      description = "Create frappe_network docker bridge network";
      before = [
        "docker-erpnext-db.service"
        "docker-erpnext-backend.service"
        "docker-erpnext-frontend.service"
        "docker-erpnext-websocket.service"
        "docker-erpnext-queue-short.service"
        "docker-erpnext-queue-long.service"
        "docker-erpnext-scheduler.service"
        "docker-erpnext-redis-cache.service"
        "docker-erpnext-redis-queue.service"
      ];
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if ! /run/current-system/sw/bin/docker network inspect ${frappeNetwork} > /dev/null 2>&1; then
          /run/current-system/sw/bin/docker network create --driver bridge ${frappeNetwork}
        fi
      '';
    };

    # Prepare host directories with correct ownership
    systemd.services."erpnext-init-dirs" = {
      description = "Initialize ERPNext host directories";
      before = [
        "docker-erpnext-backend.service"
        "docker-erpnext-frontend.service"
      ];
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /var/lib/erpnext/sites
        mkdir -p /var/lib/erpnext/logs
        mkdir -p /var/lib/erpnext/mysql
        mkdir -p /var/lib/erpnext/redis-queue
        chown -R 1000:1000 /var/lib/erpnext/sites
        chown -R 1000:1000 /var/lib/erpnext/logs
      '';
    };

    virtualisation.oci-containers.containers = {

      erpnext-db = {
        image = "mariadb:11.8";
        networks = [ frappeNetwork ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
        volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
        cmd = [
          "--character-set-server=utf8mb4"
          "--collation-server=utf8mb4_unicode_ci"
          "--skip-character-set-client-handshake"
        ];
        extraOptions = [
          "--health-cmd=healthcheck.sh --connect --innodb_initialized"
          "--health-start-period=5s"
          "--health-interval=5s"
          "--health-timeout=5s"
          "--health-retries=5"
        ];
      };

      erpnext-redis-cache = {
        image = "redis:6.2-alpine";
        networks = [ frappeNetwork ];
      };

      erpnext-redis-queue = {
        image = "redis:6.2-alpine";
        networks = [ frappeNetwork ];
        volumes = [ "/var/lib/erpnext/redis-queue:/data" ];
      };

      erpnext-backend = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-db" "erpnext-redis-cache" "erpnext-redis-queue" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-websocket = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" ];
        cmd = [ "node" "/home/frappe/frappe-bench/apps/frappe/socketio.js" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-frontend = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" "erpnext-websocket" ];
        cmd = [ "nginx-entrypoint.sh" ];
        ports = [ "8080:8080" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-queue-short = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" ];
        cmd = [ "bench" "worker" "--queue" "short,default" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-queue-long = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" ];
        cmd = [ "bench" "worker" "--queue" "long,default,short" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-scheduler = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" ];
        cmd = [ "bench" "schedule" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

    };
  };

  targetHosts = [ "server" ];
in {
  configurations.nixos = lib.genAttrs targetHosts (name: {
    module = erpnext;
  });
}
```

---

## `secrets/erpnext.env` (plaintext sample — encrypt this with sops before committing)

```dotenv
# MariaDB
MYSQL_ROOT_PASSWORD=changeme_strong_root_password
MARIADB_ROOT_PASSWORD=changeme_strong_root_password

# ERPNext DB connection (used by backend/workers)
DB_HOST=erpnext-db
DB_PORT=3306

# Redis
REDIS_CACHE=erpnext-redis-cache:6379
REDIS_QUEUE=erpnext-redis-queue:6379
FRAPPE_REDIS_CACHE=redis://erpnext-redis-cache:6379
FRAPPE_REDIS_QUEUE=redis://erpnext-redis-queue:6379

# Socketio
SOCKETIO_PORT=9000

# Frontend
BACKEND=erpnext-backend:8000
SOCKETIO=erpnext-websocket:9000
FRAPPE_SITE_NAME_HEADER=erp.protoplast.in
UPSTREAM_REAL_IP_ADDRESS=127.0.0.1
UPSTREAM_REAL_IP_HEADER=X-Forwarded-For
UPSTREAM_REAL_IP_RECURSIVE=off
PROXY_READ_TIMEOUT=120
CLIENT_MAX_BODY_SIZE=50m

# ERPNext admin (used only in bench new-site, not read by containers at runtime)
# Keep here for reference — you'll paste it into the command below
ERPNEXT_ADMIN_PASSWORD=changeme_strong_admin_password
```

Encrypt it with:
```bash
sops --encrypt --in-place secrets/erpnext.env
```

---

## First-boot configurator command (run once after all containers are up)

**Step 1 — write `common_site_config.json` into the sites volume:**
```bash
sudo docker exec -it erpnext-backend bash -c "
  bench set-config -g db_host erpnext-db &&
  bench set-config -gp db_port 3306 &&
  bench set-config -g redis_cache 'redis://erpnext-redis-cache:6379' &&
  bench set-config -g redis_queue 'redis://erpnext-redis-queue:6379' &&
  bench set-config -g redis_socketio 'redis://erpnext-redis-queue:6379' &&
  bench set-config -gp socketio_port 9000 &&
  bench set-config -g chromium_path /usr/bin/chromium-headless-shell
"
```

**Step 2 — create the site:**
```bash
sudo docker exec -it erpnext-backend bench new-site \
  --mariadb-user-host-login-scope='%' \
  --admin-password=changeme_strong_admin_password \
  --db-root-username=root \
  --db-root-password=changeme_strong_root_password \
  --install-app erpnext \
  --set-default \
  erp.protoplast.in
```

---

## Notes

- **Order matters:** run Step 1 before Step 2. Step 1 produces `common_site_config.json` which `bench new-site` depends on.
- **First deploy only:** you never need to run these again unless you wipe the `sites` volume.
- **Cloudflare Tunnel:** point your tunnel to `http://localhost:8080`. The `FRAPPE_SITE_NAME_HEADER` is already set to `erp.protoplast.in` in the env, so Frappe will resolve the correct site from the host header Cloudflare forwards.
- **`/run/secrets/erpnext.env`** is the path sops-nix writes the decrypted secret to at runtime — that's what the `environmentFiles` entries reference.