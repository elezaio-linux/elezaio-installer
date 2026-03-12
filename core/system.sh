#!/bin/bash
# Elezaio Installer - System Configuration

core_configure() {
    _log "Configuring system"

    # fstab
    local root_uuid efi_uuid
    root_uuid=$(blkid -s UUID -o value "$ROOT_PART")
    efi_uuid=$(blkid -s UUID -o value "$EFI_PART")

    cat > "$MOUNT/etc/fstab" << EOF
UUID=$root_uuid  /         ext4  errors=remount-ro  0  1
UUID=$efi_uuid   /boot/efi vfat  umask=0077         0  2
tmpfs            /tmp      tmpfs defaults,nosuid,nodev 0 0
EOF

    # Hostname
    echo "$SYSTEM_HOSTNAME" > "$MOUNT/etc/hostname"
    cat > "$MOUNT/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   $SYSTEM_HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF

    # Locale
    echo "LANG=$SYSTEM_LANG" > "$MOUNT/etc/locale.conf"
    echo "$SYSTEM_LANG UTF-8" >> "$MOUNT/etc/locale.gen"

    # Keyboard
    cat > "$MOUNT/etc/vconsole.conf" << EOF
KEYMAP=$SYSTEM_KB
EOF

    _log "System configured"
}

core_users() {
    _log "Creating user $SYSTEM_USER"

    # Remove live user
    chroot "$MOUNT" userdel -rf user 2>/dev/null || true
    chroot "$MOUNT" userdel -rf live 2>/dev/null || true

    # Create new user
    chroot "$MOUNT" useradd -m -s /usr/bin/zsh \
        -G sudo,video,input,audio,seat \
        "$SYSTEM_USER"

    # Set password
    echo "$SYSTEM_USER:$SYSTEM_PASS" | chroot "$MOUNT" chpasswd

    # Set root password same
    echo "root:$SYSTEM_PASS" | chroot "$MOUNT" chpasswd

    # Setup getty autologin for new user
    mkdir -p "$MOUNT/etc/systemd/system/getty@tty1.service.d"
    cat > "$MOUNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $SYSTEM_USER --noclear %I \$TERM
EOF

    # Setup mango autostart
    cat > "$MOUNT/home/$SYSTEM_USER/.bash_profile" << EOF
if [ -z "\$WAYLAND_DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    exec mango
fi
EOF

    chroot "$MOUNT" chown "$SYSTEM_USER:$SYSTEM_USER" \
        "/home/$SYSTEM_USER/.bash_profile"

    _log "User $SYSTEM_USER created"
}

core_bootloader() {
    _log "Installing bootloader"

    # Bind mounts for chroot
    mount --bind /dev  "$MOUNT/dev"
    mount --bind /proc "$MOUNT/proc"
    mount --bind /sys  "$MOUNT/sys"

    # Install grub
    chroot "$MOUNT" grub-install --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=Elezaio \
        --recheck >> "$LOG" 2>&1

    # Generate grub config
    cat > "$MOUNT/etc/default/grub" << EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR="Elezaio Linux"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
EOF

    chroot "$MOUNT" update-grub >> "$LOG" 2>&1

    # Unmount binds
    umount "$MOUNT/dev"  2>/dev/null || true
    umount "$MOUNT/proc" 2>/dev/null || true
    umount "$MOUNT/sys"  2>/dev/null || true

    _log "Bootloader installed"
}

core_cleanup() {
    _log "Cleaning up"

    # Remove live-specific packages
    chroot "$MOUNT" apt remove -y \
        live-boot live-boot-initramfs-tools \
        live-config live-config-systemd \
        live-tools 2>/dev/null || true
    chroot "$MOUNT" apt autoremove -y >> "$LOG" 2>&1
    chroot "$MOUNT" apt clean >> "$LOG" 2>&1

    # Remove installer from installed system
    rm -rf "$MOUNT/usr/share/elezaio-installer" 2>/dev/null || true

    # Generate locale
    chroot "$MOUNT" locale-gen >> "$LOG" 2>&1

    _log "Cleanup complete"
}

core_install() {
    # Progress wrapper
    (
        echo 5;  sleep 0.5
        core_partition
        echo 15; sleep 0.5
        core_mount
        echo 20; sleep 0.5
        core_copy &
        # Fake progress during copy
        for i in 25 30 35 40 45 50 55 60 65 70; do
            sleep 3
            echo $i
        done
        wait
        echo 75
        core_configure
        echo 80
        core_users
        echo 85
        core_bootloader
        echo 95
        core_cleanup
        echo 100
    ) | whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --gauge "Installing Elezaio Linux..." 8 70 0
}
