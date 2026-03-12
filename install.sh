#!/bin/bash
# Elezaio Installer - Entry Point
set -euo pipefail

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$INSTALLER_DIR/ui/branding.sh"
source "$INSTALLER_DIR/ui/screens.sh"
source "$INSTALLER_DIR/core/disk.sh"
source "$INSTALLER_DIR/core/system.sh"
source "$INSTALLER_DIR/config.conf"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "Elezaio Installer must be run as root."
    exit 1
fi

# Check dependencies
for dep in whiptail parted mkfs.ext4 grub-install; do
    if ! command -v "$dep" &>/dev/null; then
        echo "Missing dependency: $dep"
        exit 1
    fi
done

# Run installer
ui_welcome
ui_language
ui_keyboard
ui_disk
ui_users
ui_summary
core_install
ui_done
