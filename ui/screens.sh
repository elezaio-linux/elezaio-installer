#!/bin/bash
# Elezaio Installer - UI Screens

# ── Welcome ──
ui_welcome() {
    branded_dialog msgbox "Welcome" \
"Welcome to Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"

This installer will guide you through installing
Elezaio Linux on your computer.

WARNING: This will erase data on the selected disk.
Make sure you have backups before continuing.

Press OK to begin."
}

# ── Language ──
ui_language() {
    LANG_CHOICE=$(whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --menu "Select your language:" 20 70 8 \
        "en_US.UTF-8" "English (United States)" \
        "en_GB.UTF-8" "English (United Kingdom)" \
        "de_DE.UTF-8" "German (Germany)" \
        "fr_FR.UTF-8" "French (France)" \
        "es_ES.UTF-8" "Spanish (Spain)" \
        "it_IT.UTF-8" "Italian (Italy)" \
        "pt_BR.UTF-8" "Portuguese (Brazil)" \
        "ar_SA.UTF-8" "Arabic (Saudi Arabia)" \
        3>&1 1>&2 2>&3) || exit 0

    export SYSTEM_LANG="$LANG_CHOICE"
}

# ── Keyboard ──
ui_keyboard() {
    KB_CHOICE=$(whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --menu "Select your keyboard layout:" 20 70 8 \
        "us"      "English (US)" \
        "uk"      "English (UK)" \
        "de"      "German" \
        "fr"      "French" \
        "es"      "Spanish" \
        "it"      "Italian" \
        "pt"      "Portuguese" \
        "arabic"  "Arabic" \
        3>&1 1>&2 2>&3) || exit 0

    export SYSTEM_KB="$KB_CHOICE"
}

# ── Disk Selection ──
ui_disk() {
    # Build disk list
    local disks=()
    while IFS= read -r line; do
        local dev size
        dev=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        disks+=("/dev/$dev" "$size")
    done < <(lsblk -dno NAME,SIZE | grep -v loop)

    DISK_CHOICE=$(whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --menu "Select installation disk:\n\nWARNING: All data will be erased!" \
        20 70 6 "${disks[@]}" \
        3>&1 1>&2 2>&3) || exit 0

    export TARGET_DISK="$DISK_CHOICE"

    # Confirm
    branded_dialog yesno "Confirm" \
"Are you sure you want to install to:

  $TARGET_DISK

ALL DATA ON THIS DISK WILL BE ERASED!

This cannot be undone." || exit 0
}

# ── Users ──
ui_users() {
    # Hostname
    HOSTNAME=$(whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --inputbox "Enter hostname for this computer:" \
        10 70 "elezaio" \
        3>&1 1>&2 2>&3) || exit 0

    # Username
    USERNAME=$(whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --inputbox "Enter your username:" \
        10 70 "" \
        3>&1 1>&2 2>&3) || exit 0

    # Validate username
    if [[ ! "$USERNAME" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        branded_dialog msgbox "Error" "Invalid username. Use only lowercase letters, numbers, - and _"
        ui_users
        return
    fi

    # Password
    PASSWORD=$(whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --passwordbox "Enter password for $USERNAME:" \
        10 70 "" \
        3>&1 1>&2 2>&3) || exit 0

    # Confirm password
    PASSWORD2=$(whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --passwordbox "Confirm password:" \
        10 70 "" \
        3>&1 1>&2 2>&3) || exit 0

    if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
        branded_dialog msgbox "Error" "Passwords do not match. Please try again."
        ui_users
        return
    fi

    export SYSTEM_HOSTNAME="$HOSTNAME"
    export SYSTEM_USER="$USERNAME"
    export SYSTEM_PASS="$PASSWORD"
}

# ── Summary ──
ui_summary() {
    branded_dialog yesno "Installation Summary" \
"Please review your selections:

  Language:   $SYSTEM_LANG
  Keyboard:   $SYSTEM_KB
  Disk:       $TARGET_DISK
  Hostname:   $SYSTEM_HOSTNAME
  Username:   $SYSTEM_USER

Click Yes to begin installation.
Click No to go back and change settings." || {
        ui_welcome
        ui_language
        ui_keyboard
        ui_disk
        ui_users
        ui_summary
    }
}

# ── Progress ──
ui_progress() {
    local msg="$1"
    local pct="$2"
    echo "$pct" | whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --gauge "$msg" 8 70 0
}

# ── Done ──
ui_done() {
    branded_dialog msgbox "Installation Complete" \
"Elezaio Linux has been installed successfully!

Remove the installation media and press OK to reboot."

    reboot
}
