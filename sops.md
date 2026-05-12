This is it—the transition from "Hobbyist" to **"Systems Architect."** By the end of this guide, you will have a setup where your Cloudflare Tunnel Token is safely stored in your **public GitHub repo**, yet only your **physical server** can read it. We will use the **SSH-to-Age** method because it leverages your existing "Hardware Identity" (your SSH host key).

---

## The "Why" Behind the Architecture

In a standard NixOS setup, everything in `/etc/nixos` is world-readable in the Nix store. If you put a secret there, any process on the machine can see it.

**`sops-nix` solves this using a Three-Layer Defense:**

1. **Encryption at Rest:** Your secret is encrypted with a public key before it ever hits Git.
2. **Hardware-Bound Decryption:** Only the specific private key on your server can decrypt it.
3. **In-Memory Injection:** The secret is decrypted into a temporary file system (`/run/secrets/`) at boot, keeping it off the permanent disk.

---

## Step 1: Generating the "Public Identities"

**The Why:** To encrypt a file, you need the **Public Keys** of the people/machines allowed to read it. We will use your Laptop (to edit) and your Server (to run).

1. **On your Laptop:** Convert your SSH key to an Age key.
```bash
nix-shell -p ssh-to-age --run "cat ~/.ssh/id_ed25519.pub | ssh-to-age"
# Result: age1... (This is your ADMIN key)

```


2. **On your Server:** Get its Host Key identity.
```bash
nix-shell -p ssh-to-age --run "cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age"
# Result: age1... (This is your SERVER key)

```



---

## Step 2: Defining the "Access Policy" (`.sops.yaml`)

**The Why:** `sops` needs to know which keys belong to which files. This file lives in your root directory but is **not** encrypted. It's the "Instruction Manual" for the encryption tool.

Create a file named `.sops.yaml` in your config folder:

```yaml
keys:
  - &admin_laptop age1_your_laptop_key_here
  - &cosmos_server age1_your_server_key_here
creation_rules:
  - path_regex: secrets.yaml$
    key_groups:
      - age:
        - *admin_laptop
        - *cosmos_server

```

> **Logic:** This says: "Any file ending in `secrets.yaml` must be encrypted so that both my laptop and my server can read it."

---

## Step 3: Creating the "Vault" (`secrets.yaml`)

**The Why:** This is the actual file that goes on GitHub.

1. **Open the editor:**
```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt # Or point to your SSH key
sops secrets.yaml

```


2. **Add your Cloudflare Token:**
```yaml
cloudflare_token: "your-long-tunnel-token-here"

```


3. **Save and Close.** If you `cat secrets.yaml`, you’ll see a wall of encrypted text. This is now safe for GitHub.

---

## Step 4: Importing the `sops-nix` Logic

**The Why:** NixOS doesn't know how to handle `.yaml` secrets by default. You need to add the `sops-nix` module to your system.

In your `flake.nix`:

```nix
inputs.sops-nix.url = "github:Mic92/sops-nix";
# ... in your outputs:
modules = [
  ./configuration.nix
  sops-nix.nixosModules.sops
];

```

---

## Step 5: The "Wiring" (`configuration.nix`)

**The Why:** We need to tell the server to look for its decryption key in the SSH folder and then map the secret to the Cloudflare service.

```nix
{ config, ... }: {
  # 1. Point to the encrypted file
  sops.defaultSopsFile = ./secrets.yaml;
  sops.validateSopsFiles = false; # Handy for ADHD-speed builds

  # 2. Use the host SSH key for decryption (The "Identity")
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # 3. Define the secret and give Cloudflare permission to read it
  sops.secrets.cloudflare_token = {
    owner = config.services.cloudflared.user;
  };

  # 4. Inject the secret into the Headless Tunnel
  services.cloudflared = {
    enable = true;
    tunnels = {
      "your-uuid-here" = {
        # This points to the DECRYPTED path in /run/secrets/
        token = config.sops.secrets.cloudflare_token.path;
      };
    };
  };
}

```

---

## Step 6: The "Switch" and Verification

**The Why:** To ensure the "Pipe" is working.

1. **Rebuild:** `sudo nixos-rebuild switch --flake .`
2. **Verify the Secret:** `sudo ls -l /run/secrets/cloudflare_token`
* It should exist.
* It should be owned by the `cloudflared` user.


3. **Verify the Tunnel:** Check your Cloudflare Dashboard. The status should turn from "Inactive" to **"Healthy"**.

---

## Final Review: Why This is "Master Level"

* **Security:** If a hacker clones your GitHub repo, they have **zero** access to your tunnel.
* **Reproducibility:** If your server dies, you just flash NixOS, put your SSH host key back, and the whole system (including the tunnel) comes back to life instantly.
* **Headless:** You never have to manually log in to Cloudflare on the server again. The token is the only "Handshake" needed.

## **Horizontal Rule**

**You have officially "hardened" your infrastructure. Now that your secrets are secure, are you ready to close the browser and solve one "Array Manipulation" problem in Python before the day ends?**