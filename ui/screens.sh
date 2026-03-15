#!/bin/bash
# Elezaio Installer - UI Screens

ui_welcome() {
    branded_dialog --msgbox "\n\
  Welcome to Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"\n\n\
  This installer will guide you through installing\n\
  Elezaio Linux to your computer.\n\n\
  Make sure you have:\n\
    • A disk with at least 20 GB free\n\
    • An internet connection (for packages)\n\
    • UEFI boot mode enabled\n\n\
  Press OK to continue." 18 58
}

ui_language() {
    SYSTEM_LANG=$(branded_dialog --menu \
        "\nSelect your language:" 18 50 8 \
        "en_US.UTF-8"  "English (United States)" \
        "en_GB.UTF-8"  "English (United Kingdom)" \
        "de_DE.UTF-8"  "Deutsch (Germany)" \
        "fr_FR.UTF-8"  "Français (France)" \
        "es_ES.UTF-8"  "Español (Spain)" \
        "it_IT.UTF-8"  "Italiano (Italy)" \
        "pt_BR.UTF-8"  "Português (Brazil)" \
        "ar_SA.UTF-8"  "العربية (Arabic)" \
        3>&1 1>&2 2>&3) || exit 0
    export SYSTEM_LANG
}

ui_keyboard() {
    SYSTEM_KB=$(branded_dialog --menu \
        "\nSelect your keyboard layout:" 18 50 8 \
        "us"     "English (US)" \
        "uk"     "English (UK)" \
        "de"     "German" \
        "fr"     "French" \
        "es"     "Spanish" \
        "it"     "Italian" \
        "br"     "Portuguese (Brazil)" \
        "ara"    "Arabic" \
        3>&1 1>&2 2>&3) || exit 0
    export SYSTEM_KB
}

ui_disk() {
    local disks=()
    while IFS= read -r line; do
        local dev size
        dev=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        disks+=("/dev/$dev" "$size")
    done < <(lsblk -dn -o NAME,SIZE -e 7,11 2>/dev/null)

    [[ ${#disks[@]} -gt 0 ]] || {
        branded_dialog --msgbox "No disks found. Cannot continue." 8 40
        exit 1
    }

    INSTALL_DISK=$(branded_dialog --menu \
        "\nSelect installation disk:\n\n  WARNING: All data will be erased!" \
        18 56 6 "${disks[@]}" \
        3>&1 1>&2 2>&3) || exit 0

    branded_dialog --yesno \
        "\n  Are you sure you want to erase:\n\n    $INSTALL_DISK\n\n  This cannot be undone!" \
        12 46 || exit 0

    export INSTALL_DISK
    export EFI_PART="${INSTALL_DISK}1"
    export ROOT_PART="${INSTALL_DISK}2"
}

ui_users() {
    SYSTEM_HOSTNAME=$(branded_dialog --inputbox \
        "\nEnter a hostname for your computer:" \
        10 50 "elezaio" \
        3>&1 1>&2 2>&3) || exit 0

    SYSTEM_USER=$(branded_dialog --inputbox \
        "\nEnter your username (lowercase, no spaces):" \
        10 50 "user" \
        3>&1 1>&2 2>&3) || exit 0

    if ! echo "$SYSTEM_USER" | grep -qE '^[a-z][a-z0-9_-]{0,30}$'; then
        branded_dialog --msgbox "Invalid username. Use lowercase letters, numbers, _ or - only." 8 56
        ui_users
        return
    fi

    local pass1 pass2
    pass1=$(branded_dialog --passwordbox \
        "\nEnter password for $SYSTEM_USER:" \
        10 50 \
        3>&1 1>&2 2>&3) || exit 0

    pass2=$(branded_dialog --passwordbox \
        "\nConfirm password:" \
        10 50 \
        3>&1 1>&2 2>&3) || exit 0

    if [[ "$pass1" != "$pass2" ]]; then
        branded_dialog --msgbox "Passwords do not match. Try again." 8 40
        ui_users
        return
    fi

    if [[ ${#pass1} -lt 4 ]]; then
        branded_dialog --msgbox "Password must be at least 4 characters." 8 44
        ui_users
        return
    fi

    SYSTEM_PASS="$pass1"
    export SYSTEM_HOSTNAME SYSTEM_USER SYSTEM_PASS
}

ui_summary() {
    branded_dialog --yesno \
        "\n  Installation Summary\n\
  ─────────────────────────────────\n\
  Disk:      $INSTALL_DISK\n\
  Hostname:  $SYSTEM_HOSTNAME\n\
  Username:  $SYSTEM_USER\n\
  Language:  $SYSTEM_LANG\n\
  Keyboard:  $SYSTEM_KB\n\
  ─────────────────────────────────\n\n\
  Proceed with installation?" \
        18 50 || exit 0
}

ui_done() {
    branded_dialog --msgbox \
        "\n  Installation Complete!\n\n\
  Elezaio Linux has been installed successfully.\n\n\
  Username:  $SYSTEM_USER\n\
  Hostname:  $SYSTEM_HOSTNAME\n\n\
  Remove the USB drive and press OK to reboot." \
        16 54

    reboot
}
