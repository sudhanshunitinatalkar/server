
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

sudo docker exec -it erpnext-backend bash -c "
  touch /home/frappe/frappe-bench/sites/common_site_config.json &&
  echo '{}' > /home/frappe/frappe-bench/sites/common_site_config.json
"

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