# nixos-dendritic

## Overview
This project is a declarative, modular, and reproducible configuration for a NixOS system. It uses the Nix Flakes methodology to define the entire system state, ensuring that the entire environment—including the operating system, user settings, and installed applications—is pinned to a specific, repeatable version.

This configuration is designed for a system named `cosmoslaptop`.

## Architecture and Modules
The project follows a modular architecture, where distinct concerns are separated into specialized files located in the `modules/` directory. This promotes scalability and maintainability.

### 📁 Core Components
*   **`flake.nix`**: The central manifest file. It pulls together all inputs (like `nixpkgs`, `home-manager`, etc.) and orchestrates the final system derivation by consuming all modules defined in `./modules`.
*   **`modules/nixos.nix`**: Defines the high-level `nixosConfigurations` structure, allowing the system to be built across various hardware platforms.
*   **`modules/configuration.nix`**: Contains global settings for the NixOS system, such as time zones, network parameters, and fundamental packages (`environment.systemPackages`).
*   **`modules/home.nix`**: Manages the user's personal environment using Home Manager. This keeps user customizations (dotfiles, specific application setups) separate from the core OS configuration.

### 🛠 Key Functionality Modules
The `modules/` directory also contains specific modules for specialized configurations, such as:
*   `plasma.nix`: KDE Plasma Desktop environment settings.
*   `nvidia.nix`: Hardware-specific settings, particularly for NVIDIA graphics drivers.
*   `ollama.nix`: Integration and setup for local large language models via Ollama.
*   `helix.nix`: Configuration for the Helix text editor.
*   ... and others that define hardware-specific profiles (e.g., `LenovoIdeapadGaming3.nix`).

## Getting Started
### Prerequisites
You must have Nix and Nix Flakes installed on your system.

### Building and Deploying
The project uses the `nixos-dendritic` flake, which dictates the build process.

1.  **To build the system image (for cross-machine inspection):**
    ```bash
    nixos-rebuild build --flake .#nixosConfigurations."cosmoslaptop"
    ```

2.  **To activate the complete system configuration on a running NixOS machine:**
    ```bash
    nixos-rebuild switch --flake .#nixosConfigurations."cosmoslaptop"
    ```

3.  **To update the user's personal packages and settings (Home Manager):**
    ```bash
    home-manager switch --flake .#homeConfigurations."sudha"
    ```

## Development
To contribute or modify the system, simply update the relevant module file (e.g., `modules/configuration.nix`) and run the appropriate build command.


nixos-rebuild switch --flake .#cosmosserver --target-host sudha@192.168.29.105 --use-remote-sudo


nixos-rebuild switch --flake .#cosmosserver --target-host sudha@cosmosserver --build-host localhost --sudo --ask-sudo-password

sudo tailscale funnel --bg --https=443 localhost:8001# server



installation commands

sudo NIX_CONFIG="experimental-features = nix-command flakes pipe-operators" nix run github:nix-community/disko -- --mode disko --flake .#server

sudo NIX_CONFIG="experimental-features = nix-command flakes pipe-operators" nixos-install --flake .#server

sudo docker exec -it erpnext-app bench new-site erp.protoplast.in --db-host erpnext-db

sudo docker exec -it erpnext-app bench --site erp.protoplast.in install-app erpnext