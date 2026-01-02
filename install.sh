#!/usr/bin/env bash

# ==============================================================================
# SYSTEM RECOVERY & PROVISIONING SCRIPT
# ==============================================================================
# Targets: Debian system
# Logic: Repos -> Packages -> LVM Setup -> .bashrc Restore -> NVIDIA
# ==============================================================================

set -e          # Exit on error
set -u          # Error on unset variables
set -o pipefail # Catch errors in pipes

GITHUB_USERNAME="jake5253"
GITHUB_REPO="dotfiles"

LOG_FILE="/var/log/os_reinstall.log"
GITHUB_BASHRC_URL="https://raw.githubusercontent.com/${GITHUB_USERNAME}/${GITHUB_REPO}/main/.bashrc"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] This script must be run as root."
   exit 1
fi

# --- 1. Repository Setup ---
setup_repos() {
    log "Configuring Repositories..."
    
    # Enable contrib and non-free
    sed -i "s/^\(deb.*main\).*$/\1 contrib non-free non-free-firmware/" /etc/apt/sources.list

    # Google Chrome
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

    # VS Code
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list

    dpkg --add-architecture i386
    apt-get update -qq
}

# --- 2. Package Installation ---
install_packages() {
    log "Installing System Packages..."
    local pkgs=(
        linux-headers-$(uname -r)
        libglvnd-dev
        libglvnd-dev:i386
        build-essential
        gcc
        make
        cmake
        pkg-config 
        curl
        wget
        git
        git-lfs
        binwalk
        jq
        rsync
        ncdu
        silversearcher-ag
        libssl-dev
        libffi-dev
        liblzma-dev
        libbz2-dev
        libreadline-dev
        libsqlite3-dev
        bash-completion
        command-not-found
        htop
        net-tools
        screen
        byobu
        strace
        vlc
        gimp
        inkscape
        ffmpeg
        hplip
        baobab
        snapd
        flatpak
        apt-file
        google-chrome-stable
        code
    )
    apt-get install -y "${pkgs[@]}"
}

# --- 3. Storage & LVM Setup ---
configure_storage() {
    log "Initializing LVM and mounting volumes..."
    
    vgscan && vgchange -ay

    # Map LVs to /srv, excluding lvol0
    for vol in /dev/VG0/*; do
        if [ -e "$vol" ]; then
            local name=$(basename "$vol")
            
            if [[ "$name" == "lvol0" ]]; then
                log "Skipping $vol (administrative exclusion)"
                continue
            fi

            mkdir -p "/srv/$name"
            if ! grep -q "$vol" /etc/fstab; then
                echo "$vol /srv/$name auto defaults 0 2" >> /etc/fstab
                log "Added $name to fstab"
            fi
        fi
    done

    # Map /home to dream_volcano
    if ! grep -q "/home" /etc/fstab; then
        log "Mapping /home to dream_volcano..."
        echo "/dev/lvm0/dream_volcano /home auto defaults 0 2" >> /etc/fstab
    fi

    # CRITICAL MOUNT ENFORCEMENT
    log "Attempting to mount all filesystems..."
    mount -a || { 
        log "[FATAL ERROR] Filesystem mounting failed! Aborting to prevent filesystem fucketry"; 
        exit 1; 
    }

    # Verify /home is actually the LVM mount point
    if ! mountpoint -q /home; then
        log "[FATAL ERROR] /home is NOT a mountpoint. Protection triggered, exiting.";
        exit 1;
    fi

    # Sync User environment
    local user_name=$(id -nu 1000)
    local user_home="/home/$user_name"

    if [ ! -d "$user_home" ]; then
        log "Creating user home directory on new volume..."
        mkdir -p "$user_home"
        cp -r /etc/skel/. "$user_home/"
    fi

    # Restore .bashrc from GitHub
    log "Restoring .bashrc from GitHub..."
    if ! curl -fsSL "$GITHUB_BASHRC_URL" -o "$user_home/.bashrc"; then
        log "[ERROR] Failed to download .bashrc."
    fi
    
    # Fix ownership
    chown -R "$user_name:$user_name" "$user_home"
    
    # Add user to groups
    for grp in sudo dialout docker; do
        groupadd -f "$grp"
        usermod -aG "$grp" "$user_name"
    done
}

# --- 4. NVIDIA Driver ---
nvidia_install() {
    if [[ ! "$(tty)" == /dev/tty* ]]; then
        log "[SKIP] Not in a TTY. Skipping NVIDIA driver install."
        return 0
    fi

    local lib32_path="/usr/lib/i386-linux-gnu"
    if [ ! -d "$lib32_path" ]; then
        log "[INFO] Creating 32-bit lib directory..."
        mkdir -p "$lib32_path"
    fi

    log "Starting NVIDIA Driver Installation..."
    local download_dir="/tmp/nvidia_update"
    mkdir -p "$download_dir"

    # Blacklist Nouveau
    echo -e "blacklist nouveau\noptions nouveau modeset=0" > /etc/modprobe.d/blacklist-nouveau.conf
    update-initramfs -u

    local latest=$(curl -s https://www.nvidia.com/en-us/drivers/unix/ | grep -A 1 "Latest Production Branch Version" | grep -oE "[0-9]+\.[0-9]+(\.[0-9]+)?" | head -n1)
    local installer="${download_dir}/NVIDIA-Linux-x86_64-${latest}.run"

    curl -L -o "$installer" "https://us.download.nvidia.com/XFree86/Linux-x86_64/${latest}/NVIDIA-Linux-x86_64-${latest}.run"
    chmod +x "$installer"
    
    sh "$installer" -s --dkms -a --no-questions --no-cc-version-check
}

# --- 5. Third Party Tools ---
install_tools() {
    log "Installing Docker..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
    fi
}

# --- Main ---
main() {
    log "STARTING PROVISIONING"
    setup_repos
    install_packages
    configure_storage
    install_tools
    nvidia_install || log "NVIDIA install failed or skipped."

    log "PROVISIONING COMPLETE. Please reboot."
}

main "$@"
