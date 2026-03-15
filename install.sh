#!/bin/bash
# Elezaio Linux Installer
# https://github.com/elezaio-linux

touch /tmp/elezaio-install-error.log
exec 2>/tmp/elezaio-install-error.log

set -uo pipefail

export TERM=xterm-256color
eval "$(resize 2>/dev/null)" || true

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for module in \
    "$INSTALLER_DIR/config.conf" \
    "$INSTALLER_DIR/ui/branding.sh" \
    "$INSTALLER_DIR/ui/screens.sh" \
    "$INSTALLER_DIR/core/disk.sh" \
    "$INSTALLER_DIR/core/system.sh"; do
    [[ -f "$module" ]] || { echo "ERROR: Missing: $module"; exit 1; }
    source "$module"
done

# ── Dry run mode ──────────────────────────────────────────────
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if $DRY_RUN; then
    export INSTALL_DISK="/dev/sda"
    export EFI_PART="/dev/sda1"
    export ROOT_PART="/dev/sda2"
    export SYSTEM_HOSTNAME="elezaio-test"
    export SYSTEM_USER="testuser"
    export SYSTEM_PASS="testpass"
    export SYSTEM_LANG="en_US.UTF-8"
    export SYSTEM_KB="us"
    export MOUNT="/tmp/elezaio-dry-run"
    mkdir -p "$MOUNT"

    core_partition() { gum spin --spinner dot --title "[DRY] Partitioning disk..." -- sleep 1; }
    core_mount()     { gum spin --spinner dot --title "[DRY] Mounting partitions..." -- sleep 1; }
    core_copy()      { gum spin --spinner dot --title "[DRY] Copying squashfs..." -- sleep 2; }
    core_bind_mount(){ gum spin --spinner dot --title "[DRY] Binding filesystems..." -- sleep 0.5; }
    core_unbind()    { true; }
    core_configure() { gum spin --spinner dot --title "[DRY] Configuring system..." -- sleep 1; }
    core_packages()  { gum spin --spinner dot --title "[DRY] Installing packages..." -- sleep 2; }
    core_users()     { gum spin --spinner dot --title "[DRY] Creating user..." -- sleep 1; }
    core_bootloader(){ gum spin --spinner dot --title "[DRY] Installing bootloader..." -- sleep 1; }
    core_cleanup()   { gum spin --spinner dot --title "[DRY] Cleaning up..." -- sleep 1; }

    ui_welcome
    ui_language
    ui_keyboard
    ui_disk
    ui_users
    ui_summary
    core_install
    ui_done
    exit 0
fi

# ── Production mode ───────────────────────────────────────────
[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash install.sh"; exit 1; }

if ! command -v gum &>/dev/null; then
    echo "Installing gum..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
        > /etc/apt/sources.list.d/charm.list
    apt-get update -qq
    apt-get install -y gum
fi

missing=()
for dep in parted sgdisk mkfs.ext4 grub-install unsquashfs curl awk; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing: ${missing[*]}"
    exit 1
fi

ui_welcome
ui_language
ui_keyboard
ui_disk
ui_users
ui_summary
core_install
ui_done
