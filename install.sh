#!/bin/bash
# Elezaio Linux Installer
# https://github.com/elezaio-linux

touch /tmp/elezaio-install-error.log
exec 2>/tmp/elezaio-install-error.log

set -uo pipefail

export TERM=xterm-256color
export NEWT_COLORS_FILE=""
eval $(resize 2>/dev/null) || true

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules
for module in \
    "$INSTALLER_DIR/config.conf" \
    "$INSTALLER_DIR/ui/branding.sh" \
    "$INSTALLER_DIR/ui/screens.sh" \
    "$INSTALLER_DIR/core/disk.sh" \
    "$INSTALLER_DIR/core/system.sh"; do
    if [ ! -f "$module" ]; then
        echo "ERROR: Missing module: $module"
        exit 1
    fi
    source "$module"
done

# Must be root
if [[ $EUID -ne 0 ]]; then
    whiptail --title "Error" \
        --msgbox "Elezaio Installer must be run as root.\n\nTry: sudo bash install.sh" 10 50
    exit 1
fi

# Check dependencies
missing=()
for dep in whiptail parted mkfs.ext4 grub-install unsquashfs curl; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
done

if [ ${#missing[@]} -gt 0 ]; then
    whiptail --title "Missing Dependencies" \
        --msgbox "The following tools are missing:\n\n${missing[*]}\n\nPlease install them and try again." 14 50
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
