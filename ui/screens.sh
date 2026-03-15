#!/bin/bash
# Elezaio Installer - UI Screens (gum)

ui_welcome() {
    print_header
    gum style \
        --align center \
        --width 60 \
        --padding "1 4" \
        --margin "0 0 1 0" \
        "Welcome to Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"\n\nMake sure you have:\n  • A disk with at least 20 GB free\n  • UEFI boot mode enabled\n  • Internet connection"

    gum confirm \
        --affirmative "Continue" \
        --negative "Exit" \
        --selected.background "$GUM_ACCENT" \
        "Ready to install?" || exit 0
}

ui_language() {
    print_header
    gum style --margin "0 0 0 2" --foreground "$GUM_ACCENT" "Select your language:"

    SYSTEM_LANG=$(gum choose \
        --selected.foreground "$GUM_ACCENT" \
        --cursor.foreground "$GUM_ACCENT" \
        --height 10 \
        "en_US.UTF-8" \
        "en_GB.UTF-8" \
        "de_DE.UTF-8" \
        "fr_FR.UTF-8" \
        "es_ES.UTF-8" \
        "it_IT.UTF-8" \
        "pt_BR.UTF-8" \
        "ar_SA.UTF-8") || exit 0

    export SYSTEM_LANG
}

ui_keyboard() {
    print_header
    gum style --margin "0 0 0 2" --foreground "$GUM_ACCENT" "Select your keyboard layout:"

    SYSTEM_KB=$(gum choose \
        --selected.foreground "$GUM_ACCENT" \
        --cursor.foreground "$GUM_ACCENT" \
        --height 10 \
        "us" \
        "uk" \
        "de" \
        "fr" \
        "es" \
        "it" \
        "br" \
        "ara") || exit 0

    export SYSTEM_KB
}

ui_disk() {
    print_header
    gum style --margin "0 0 0 2" --foreground "$GUM_ACCENT" "Select installation disk:"

    local disk_list=()
    while IFS= read -r line; do
        local dev size model
        dev=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        model=$(echo "$line" | awk '{$1=$2=""; print $0}' | xargs)
        disk_list+=("/dev/$dev  $size  $model")
    done < <(lsblk -dn -o NAME,SIZE,MODEL -e 7,11 2>/dev/null)

    [[ ${#disk_list[@]} -gt 0 ]] || die "No disks found!"

    local selected
    selected=$(gum choose \
        --selected.foreground "$GUM_ACCENT" \
        --cursor.foreground "$GUM_ACCENT" \
        --height 10 \
        "${disk_list[@]}") || exit 0

    INSTALL_DISK=$(echo "$selected" | awk '{print $1}')

    gum style \
        --foreground "$GUM_DANGER" \
        --margin "1 2" \
        "WARNING: All data on $INSTALL_DISK will be erased!"

    gum confirm \
        --affirmative "Yes, erase it" \
        --negative "Go back" \
        --selected.background "$GUM_DANGER" \
        "Are you sure?" || ui_disk

    export INSTALL_DISK
    if echo "$INSTALL_DISK" | grep -q "nvme\|mmcblk"; then
        export EFI_PART="${INSTALL_DISK}p1"
        export ROOT_PART="${INSTALL_DISK}p2"
    else
        export EFI_PART="${INSTALL_DISK}1"
        export ROOT_PART="${INSTALL_DISK}2"
    fi
}

ui_users() {
    print_header

    gum style --margin "0 0 0 2" --foreground "$GUM_ACCENT" "Computer name:"
    SYSTEM_HOSTNAME=$(gum input \
        --placeholder "elezaio" \
        --value "${DEFAULT_HOSTNAME:-elezaio}" \
        --width 40) || exit 0

    gum style --margin "1 0 0 2" --foreground "$GUM_ACCENT" "Username:"
    SYSTEM_USER=$(gum input \
        --placeholder "user" \
        --value "${DEFAULT_USER:-user}" \
        --width 40) || exit 0

    if ! echo "$SYSTEM_USER" | grep -qE '^[a-z][a-z0-9_-]{0,30}$'; then
        gum style --foreground "$GUM_DANGER" "Invalid username! Use lowercase letters only."
        sleep 2
        ui_users
        return
    fi

    gum style --margin "1 0 0 2" --foreground "$GUM_ACCENT" "Password:"
    local pass1
    pass1=$(gum input --password --placeholder "Enter password" --width 40) || exit 0

    gum style --margin "1 0 0 2" --foreground "$GUM_ACCENT" "Confirm password:"
    local pass2
    pass2=$(gum input --password --placeholder "Confirm password" --width 40) || exit 0

    if [[ "$pass1" != "$pass2" ]]; then
        gum style --foreground "$GUM_DANGER" "Passwords do not match!"
        sleep 2
        ui_users
        return
    fi

    if [[ ${#pass1} -lt 4 ]]; then
        gum style --foreground "$GUM_DANGER" "Password must be at least 4 characters!"
        sleep 2
        ui_users
        return
    fi

    SYSTEM_PASS="$pass1"
    export SYSTEM_HOSTNAME SYSTEM_USER SYSTEM_PASS
}

ui_summary() {
    print_header
    gum style \
        --align center \
        --width 60 \
        --padding "1 4" \
        --border rounded \
        --border-foreground "$GUM_SUBTLE" \
        "Installation Summary\n\n  Disk:      $INSTALL_DISK\n  Hostname:  $SYSTEM_HOSTNAME\n  Username:  $SYSTEM_USER\n  Language:  $SYSTEM_LANG\n  Keyboard:  $SYSTEM_KB"

    gum confirm \
        --affirmative "Install" \
        --negative "Cancel" \
        --selected.background "$GUM_ACCENT" \
        "Proceed with installation?" || exit 0
}

ui_done() {
    clear
    gum style \
        --align center \
        --width 60 \
        --padding "2 4" \
        --border rounded \
        --border-foreground "$GUM_ACCENT" \
        --foreground "$GUM_ACCENT" \
        "Installation Complete!\n\nElezaio Linux has been installed.\n\nUsername:  $SYSTEM_USER\nHostname:  $SYSTEM_HOSTNAME\n\nRemove the USB drive and reboot."

    gum confirm --affirmative "Reboot now" --negative "Stay" "Reboot?" && reboot
}
