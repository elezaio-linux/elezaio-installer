#!/bin/bash
# Elezaio Linux Installer
# https://github.com/elezaio-linux

touch /tmp/elezaio-install-error.log
exec 2>/tmp/elezaio-install-error.log

set -uo pipefail

export TERM=xterm-256color
eval "$(resize 2>/dev/null)" || true

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config first
for module in \
    "$INSTALLER_DIR/config.conf" \
    "$INSTALLER_DIR/ui/branding.sh" \
    "$INSTALLER_DIR/ui/screens.sh" \
    "$INSTALLER_DIR/core/disk.sh" \
    "$INSTALLER_DIR/core/system.sh"; do
    [[ -f "$module" ]] || { echo "ERROR: Missing: $module"; exit 1; }
    source "$module"
done

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash install.sh"; exit 1; }

# Install gum if missing
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

# Check other dependencies
missing=()
for dep in parted sgdisk mkfs.ext4 grub-install unsquashfs curl awk; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
done

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing: ${missing[*]}"
    exit 1
fi

# Run installer
ui_welcome
ui_language
ui_keyboard
ui_disk
ui_users
ui_summary
core_install
ui_done
