#!/bin/bash
# ╔═══════════════════════════════════════╗
# ║     Elezaio Linux Installer           ║
# ║     https://github.com/elezaio-linux  ║
# ╚═══════════════════════════════════════╝

touch /tmp/elezaio-install-error.log
exec 2>/tmp/elezaio-install-error.log

set -uo pipefail

export TERM=xterm-256color
export NEWT_COLORS_FILE=""
eval "$(resize 2>/dev/null)" || true

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for module in \
    source "$INSTALLER_DIR/config.conf"
    source "$INSTALLER_DIR/ui/branding.sh"
    source "$INSTALLER_DIR/ui/screens.sh"
    source "$INSTALLER_DIR/core/disk.sh"
    source "$INSTALLER_DIR/core/system.sh" do
    [[ -f "$module" ]] || { echo "ERROR: Missing: $module"; exit 1; }
    source "$module"
done

[[ $EUID -eq 0 ]] || {
    whiptail --title "Permission Error" \
        --msgbox "This installer must be run as root.\n\nRun: sudo bash install.sh" 10 50
    exit 1
}

missing=()
for dep in whiptail parted mkfs.ext4 grub-install unsquashfs curl awk; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
done
[[ ${#missing[@]} -eq 0 ]] || {
    whiptail --title "Missing Dependencies" \
        --msgbox "Missing required tools:\n\n  ${missing[*]}\n\nInstall them and try again." 14 52
    exit 1
}

ui_welcome
ui_language
ui_keyboard
ui_disk
ui_users
ui_summary
core_install
ui_done
