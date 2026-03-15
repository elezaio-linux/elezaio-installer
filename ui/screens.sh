#!/bin/bash
# Elezaio Installer - UI Screens (gum)

ui_welcome() {
    print_header
    gum style \
        --align center \
        --width 60 \
        --padding "1 4" \
        --margin "0 0 1 0" \
        "$(printf 'Welcome to Elezaio Linux %s "%s"\n\nMake sure you have:\n  • A disk with at least 20 GB free\n  • UEFI boot mode enabled\n  • Internet connection' "$INSTALLER_VERSION" "$INSTALLER_CODENAME")"

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
    gum style --margin "0 0 0 2" --foreground "$GUM_ACCENT" "Select a disk or partition to install to:"
    echo ""

    local display_list=()
    local choice_list=()

    while IFS= read -r disk_line; do
        local dname dsize dmodel
        dname=$(echo "$disk_line" | awk '{print $1}')
        dsize=$(echo "$disk_line" | awk '{print $2}')
        dmodel=$(echo "$disk_line" | awk '{$1=$2=""; print $0}' | xargs)

        display_list+=("$(printf "disk  /dev/%s  [%s]  %s" "$dname" "$dsize" "$dmodel")")
        choice_list+=("/dev/$dname")

        while IFS= read -r part_line; do
            local pname psize ptype
            pname=$(echo "$part_line" | awk '{print $1}')
            psize=$(echo "$part_line" | awk '{print $2}')
            ptype=$(echo "$part_line" | awk '{$1=$2=""; print $0}' | xargs)
            display_list+=("$(printf "  └─  /dev/%s  [%s]  %s" "$pname" "$psize" "$ptype")")
            choice_list+=("/dev/$pname")
        done < <(lsblk -ln -o NAME,SIZE,PARTTYPENAME "/dev/$dname" 2>/dev/null | tail -n +2)

    done < <(lsblk -dn -o NAME,SIZE,MODEL -e 7,11 2>/dev/null)

    [[ ${#display_list[@]} -gt 0 ]] || die "No disks found!"

    local selected_display
    selected_display=$(gum choose \
        --selected.foreground "$GUM_ACCENT" \
        --cursor.foreground "$GUM_ACCENT" \
        --height 15 \
        "${display_list[@]}") || exit 0

    local idx=0
    local selected_dev=""
    for item in "${display_list[@]}"; do
        if [[ "$item" == "$selected_display" ]]; then
            selected_dev="${choice_list[$idx]}"
            break
        fi
        (( idx++ )) || true
    done

    # Full disk or partition?
    if echo "$selected_dev" | grep -qE '[0-9]$'; then
        # Partition selected - use parent disk for grub
        INSTALL_DISK=$(echo "$selected_dev" | sed 's/p\?[0-9]*$//')
        export EFI_PART="$selected_dev"
        gum style --margin "1 0 0 2" --foreground "$GUM_ACCENT" "Now select the root partition:"
        ROOT_PART=$(gum choose \
            --selected.foreground "$GUM_ACCENT" \
            --cursor.foreground "$GUM_ACCENT" \
            --height 10 \
            "${display_list[@]}" ) || exit 0
        ROOT_PART=$(echo "$ROOT_PART" | awk '{print $2}')
        export ROOT_PART
    else
        # Full disk - auto partition
        INSTALL_DISK="$selected_dev"
        if echo "$INSTALL_DISK" | grep -q "nvme\|mmcblk"; then
            export EFI_PART="${INSTALL_DISK}p1"
            export ROOT_PART="${INSTALL_DISK}p2"
        else
            export EFI_PART="${INSTALL_DISK}1"
            export ROOT_PART="${INSTALL_DISK}2"
        fi
    fi

    export INSTALL_DISK

    gum style \
        --foreground "$GUM_DANGER" \
        --margin "1 2" \
        "$(printf 'WARNING: All data on %s will be erased!' "$INSTALL_DISK")"

    gum confirm \
        --affirmative "Yes, erase it" \
        --negative "Go back" \
        --selected.background "$GUM_DANGER" \
        "Are you sure?" || ui_disk
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
        "$(printf 'Installation Summary\n\n  Disk:      %s\n  Hostname:  %s\n  Username:  %s\n  Language:  %s\n  Keyboard:  %s' "$INSTALL_DISK" "$SYSTEM_HOSTNAME" "$SYSTEM_USER" "$SYSTEM_LANG" "$SYSTEM_KB")"

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
        "$(printf 'Installation Complete!\n\nElezaio Linux has been installed.\n\nUsername:  %s\nHostname:  %s\n\nRemove the USB drive and reboot.' "$SYSTEM_USER" "$SYSTEM_HOSTNAME")"

    gum confirm --affirmative "Reboot now" --negative "Stay" "Reboot?" && reboot
}
