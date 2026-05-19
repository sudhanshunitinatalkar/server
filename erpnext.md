Here is exactly how to start this up.

Because we moved back to the host-level Docker implementation, the startup process is extremely straightforward. However, there is one critical step specific to the Frappe Docker architecture: starting the container doesn't automatically create a "Site" (the actual ERPNext instance). You have to initialize the site manually the first time.

### 1. The Sample `erpnext.env` File

Create your secret file at `server/secrets/erpnext.env`.

The MariaDB container and the ERPNext container both read this file, so the `MYSQL_PASSWORD` and `DB_PASSWORD` must exactly match so they can talk to each other.

```env
Here is exactly how to start this up.

Because we moved back to the host-level Docker implementation, the startup process is extremely straightforward. However, there is one critical step specific to the Frappe Docker architecture: starting the container doesn't automatically create a "Site" (the actual ERPNext instance). You have to initialize the site manually the first time.

### 1. The Sample `erpnext.env` File

Create your secret file at `server/secrets/erpnext.env`.

The MariaDB container and the ERPNext container both read this file, so the `MYSQL_PASSWORD` and `DB_PASSWORD` must exactly match so they can talk to each other.

```env
# ----------------------------------------
# MariaDB Database Initialization
# ----------------------------------------
# The root password for the entire MariaDB server
MYSQL_ROOT_PASSWORD=YourSuperSecureRootPassword123!

# The password for the specific 'frappe' database user
MYSQL_PASSWORD=YourSecureFrappeUserPassword123!

# ----------------------------------------
# ERPNext / Frappe App Configuration
# ----------------------------------------
# Must match MYSQL_PASSWORD above
DB_PASSWORD=YourSecureFrappeUserPassword123!

# The password for the ERPNext 'Administrator' web login
ADMIN_PASSWORD=YourSecureAdminPassword123!

```

### 2. Encrypt and Apply

1. **Encrypt the file:** Use `sops` to encrypt the file with your server's age/ssh key, just like you did for your Cloudflare secrets.
```bash
sops -e -i server/secrets/erpnext.env

```


2. **Track in Git:** NixOS Flakes cannot read files unless they are tracked by git.
```bash
git add server/secrets/erpnext.env
git add server/modules/erpnext.nix

```


3. **Rebuild the Server:**
```bash
sudo nixos-rebuild switch --flake .#server

```


*At this point, NixOS will download the Docker images, start the database, start Redis, and boot the ERPNext app container on port 8001.*

### 3. Initialize Your ERPNext Site (Crucial Step)

Frappe is a multi-tenant framework. It uses the URL you type in your browser (the "Host" header) to figure out which database to serve. Because your Cloudflare tunnel will route traffic to something like `erp.yourdomain.com`, **your Frappe site must be named exactly the same as your domain.**

Run this command directly on your server to tell the running ERPNext container to initialize your site and install the ERPNext application into it.

*(Replace `erp.yourdomain.com` with the actual public URL you plan to use in Cloudflare)*:

```bash
sudo docker exec -it erpnext-app bench new-site erp.yourdomain.com \
  --db-root-password 'YourSuperSecureRootPassword123!' \
  --admin-password 'YourSecureAdminPassword123!' \
  --install-app erpnext

```

*Note: This command will take a few minutes to run. It is building the database tables and compiling the web assets.*

Once it finishes, tell the container to use this site by default if it ever gets confused:

```bash
sudo docker exec -it erpnext-app bench use erp.yourdomain.com

```

### 4. Route via Cloudflare

Since your Cloudflared tunnel configuration (from the `cloudflared.nix` file you uploaded previously) is already running on the host network, you just need to update your Cloudflare Zero Trust dashboard.

Add a new Public Hostname route:

* **Public Hostname:** `erp.yourdomain.com` (Must match the site name you created above)
* **Service:** `http://localhost:8001`

Navigate to that URL, and you should be greeted by the ERPNext login screen. Use the username **Administrator** and the `ADMIN_PASSWORD` you set in your `.env` file to log in.

```

### 2. Encrypt and Apply

1. **Encrypt the file:** Use `sops` to encrypt the file with your server's age/ssh key, just like you did for your Cloudflare secrets.
```bash
sops -e -i server/secrets/erpnext.env

```


2. **Track in Git:** NixOS Flakes cannot read files unless they are tracked by git.
```bash
git add server/secrets/erpnext.env
git add server/modules/erpnext.nix

```


3. **Rebuild the Server:**
```bash
sudo nixos-rebuild switch --flake .#server

```


*At this point, NixOS will download the Docker images, start the database, start Redis, and boot the ERPNext app container on port 8001.*

### 3. Initialize Your ERPNext Site (Crucial Step)

Frappe is a multi-tenant framework. It uses the URL you type in your browser (the "Host" header) to figure out which database to serve. Because your Cloudflare tunnel will route traffic to something like `erp.yourdomain.com`, **your Frappe site must be named exactly the same as your domain.**

Run this command directly on your server to tell the running ERPNext container to initialize your site and install the ERPNext application into it.

*(Replace `erp.yourdomain.com` with the actual public URL you plan to use in Cloudflare)*:

```bash
sudo docker exec -it erpnext-app bench new-site erp.yourdomain.com \
  --db-root-password 'YourSuperSecureRootPassword123!' \
  --admin-password 'YourSecureAdminPassword123!' \
  --install-app erpnext

```

*Note: This command will take a few minutes to run. It is building the database tables and compiling the web assets.*

Once it finishes, tell the container to use this site by default if it ever gets confused:

```bash
sudo docker exec -it erpnext-app bench use erp.yourdomain.com

```

### 4. Route via Cloudflare

Since your Cloudflared tunnel configuration (from the `cloudflared.nix` file you uploaded previously) is already running on the host network, you just need to update your Cloudflare Zero Trust dashboard.

Add a new Public Hostname route:

* **Public Hostname:** `erp.yourdomain.com` (Must match the site name you created above)
* **Service:** `http://localhost:8001`

Navigate to that URL, and you should be greeted by the ERPNext login screen. Use the username **Administrator** and the `ADMIN_PASSWORD` you set in your `.env` file to log in.