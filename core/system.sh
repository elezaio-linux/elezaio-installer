#!/bin/bash
# Elezaio Installer - System Configuration

LOG="/var/log/elezaio-install.log"
MOUNT="/mnt/elezaio"

_log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

# ───────── CONFIGURE ─────────
core_configure() {
    _log "Configuring system"

    local root_uuid efi_uuid
    root_uuid=$(blkid -s UUID -o value "$ROOT_PART")
    efi_uuid=$(blkid -s UUID -o value "$EFI_PART")

    cat > "$MOUNT/etc/fstab" << EOF
UUID=$root_uuid  /         ext4  errors=remount-ro  0  1
UUID=$efi_uuid   /boot/efi vfat  umask=0077         0  2
tmpfs            /tmp      tmpfs defaults,nosuid,nodev 0 0
EOF

    echo "$SYSTEM_HOSTNAME" > "$MOUNT/etc/hostname"
    cat > "$MOUNT/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   $SYSTEM_HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF

    echo "LANG=$SYSTEM_LANG" > "$MOUNT/etc/locale.conf"
    echo "$SYSTEM_LANG UTF-8" >> "$MOUNT/etc/locale.gen"

    cat > "$MOUNT/etc/vconsole.conf" << EOF
KEYMAP=$SYSTEM_KB
EOF

    cat > "$MOUNT/etc/apt/sources.list" << EOF
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

    cat >> "$MOUNT/etc/sysctl.conf" << EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF

    _log "System configured"
}

# ───────── PACKAGES ─────────
core_packages() {
    _log "Installing packages"

    chroot "$MOUNT" apt update >> "$LOG" 2>&1

    chroot "$MOUNT" apt install -y \
        swaybg waybar wofi dunst grim slurp \
        wl-clipboard brightnessctl playerctl \
        >> "$LOG" 2>&1

    chroot "$MOUNT" apt install -y \
        pipewire pipewire-pulseaudio wireplumber \
        >> "$LOG" 2>&1

    chroot "$MOUNT" apt install -y \
        network-manager network-manager-gnome \
        >> "$LOG" 2>&1

    chroot "$MOUNT" apt install -y sddm >> "$LOG" 2>&1

    chroot "$MOUNT" apt install -y \
        tlp tlp-rdw zram-tools irqbalance systemd-resolved \
        >> "$LOG" 2>&1

    chroot "$MOUNT" apt install -y \
        zsh kitty fastfetch curl jq \
        >> "$LOG" 2>&1

    chroot "$MOUNT" apt install -y \
        fonts-jetbrains-mono fonts-noto-core \
        >> "$LOG" 2>&1

    chroot "$MOUNT" apt install -y \
        firefox-esr thunar mousepad \
        >> "$LOG" 2>&1

    chroot "$MOUNT" apt install -y \
        arc-theme papirus-icon-theme \
        >> "$LOG" 2>&1

    chroot "$MOUNT" systemctl enable NetworkManager >> "$LOG" 2>&1
    chroot "$MOUNT" systemctl enable tlp >> "$LOG" 2>&1
    chroot "$MOUNT" systemctl enable irqbalance >> "$LOG" 2>&1
    chroot "$MOUNT" systemctl enable zramswap >> "$LOG" 2>&1
    chroot "$MOUNT" systemctl enable systemd-resolved >> "$LOG" 2>&1

    _log "Packages installed"
}

# ───────── USERS ─────────
core_users() {
    _log "Creating user $SYSTEM_USER"

    chroot "$MOUNT" userdel -rf user 2>/dev/null || true
    chroot "$MOUNT" userdel -rf live 2>/dev/null || true

    chroot "$MOUNT" useradd -m -s /usr/bin/zsh \
        -G sudo,video,input,audio,seat,render,netdev \
        "$SYSTEM_USER" >> "$LOG" 2>&1

    echo "$SYSTEM_USER:$SYSTEM_PASS" | chroot "$MOUNT" chpasswd
    echo "root:$SYSTEM_PASS" | chroot "$MOUNT" chpasswd

    chroot "$MOUNT" su -c \
        'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' \
        "$SYSTEM_USER" >> "$LOG" 2>&1 || true

    echo 'fastfetch' >> "$MOUNT/home/$SYSTEM_USER/.zshrc"

    mkdir -p "$MOUNT/etc/sddm.conf.d"
    cat > "$MOUNT/etc/sddm.conf.d/elezaio.conf" << EOF
[Autologin]
User=$SYSTEM_USER
Session=mango

[General]
DisplayServer=wayland

[Theme]
Current=
EOF

    chroot "$MOUNT" systemctl enable sddm >> "$LOG" 2>&1
    chroot "$MOUNT" systemctl set-default graphical.target >> "$LOG" 2>&1
    chroot "$MOUNT" chsh -s /usr/bin/zsh "$SYSTEM_USER" >> "$LOG" 2>&1
    chroot "$MOUNT" chown -R "$SYSTEM_USER:$SYSTEM_USER" \
        "/home/$SYSTEM_USER" >> "$LOG" 2>&1

    _log "User $SYSTEM_USER created"
}

# ───────── BOOTLOADER ─────────
core_bootloader() {
    _log "Installing bootloader"

    mount --bind /dev  "$MOUNT/dev"
    mount --bind /proc "$MOUNT/proc"
    mount --bind /sys  "$MOUNT/sys"
    mount --bind /run  "$MOUNT/run"

    chroot "$MOUNT" apt install -y grub-efi-amd64 >> "$LOG" 2>&1

    chroot "$MOUNT" grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=Elezaio \
        --recheck >> "$LOG" 2>&1

    cat > "$MOUNT/etc/default/grub" << EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR="Elezaio Linux"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
EOF

    chroot "$MOUNT" update-grub >> "$LOG" 2>&1

    umount "$MOUNT/run"  2>/dev/null || true
    umount "$MOUNT/dev"  2>/dev/null || true
    umount "$MOUNT/proc" 2>/dev/null || true
    umount "$MOUNT/sys"  2>/dev/null || true

    _log "Bootloader installed"
}

# ───────── CLEANUP ─────────
core_cleanup() {
    _log "Cleaning up"

    chroot "$MOUNT" apt remove -y \
        live-boot live-boot-initramfs-tools \
        live-config live-config-systemd \
        live-tools 2>/dev/null || true

    chroot "$MOUNT" apt autoremove -y >> "$LOG" 2>&1
    chroot "$MOUNT" apt clean >> "$LOG" 2>&1
    chroot "$MOUNT" locale-gen >> "$LOG" 2>&1

    rm -rf "$MOUNT/usr/share/elezaio-installer" 2>/dev/null || true
    rm -rf "$MOUNT/tmp/*" 2>/dev/null || true

    _log "Cleanup complete"
}

# ───────── INSTALL ORCHESTRATOR ─────────
core_install() {
    local start_time
    start_time=$(date +%s)

    _smooth() {
        local from="$1" to="$2" msg="$3" duration="${4:-2}"
        local steps=$(( to - from ))
        [ "$steps" -le 0 ] && steps=1
        local delay
        delay=$(awk "BEGIN {printf \"%.3f\", $duration / $steps}")
        local i=$from
        while [ "$i" -le "$to" ]; do
            local elapsed=$(( $(date +%s) - start_time ))
            local eta="calculating..."
            if [ "$i" -gt 2 ] && [ "$elapsed" -gt 0 ]; then
                local total_est=$(( elapsed * 100 / (i + 1) ))
                local secs_left=$(( total_est - elapsed ))
                if [ "$secs_left" -gt 60 ]; then
                    eta="~$((secs_left/60))m $((secs_left%60))s"
                elif [ "$secs_left" -gt 0 ]; then
                    eta="${secs_left}s"
                else
                    eta="almost done"
                fi
            fi
            echo "XXX"
            echo "$i"
            printf "%s\n\nElapsed: %ds  |  ETA: %s" "$msg" "$elapsed" "$eta"
            echo "XXX"
            sleep "$delay"
            i=$(( i + 1 ))
        done
    }

    {
        _smooth 0 4 "Preparing disk partitions..." 1
        core_partition >> "$LOG" 2>&1

        _smooth 4 10 "Mounting partitions..." 1
        core_mount >> "$LOG" 2>&1

        core_copy >> "$LOG" 2>&1 &
        local copy_pid=$!
        local squashfs
        squashfs=$(find /run/live -name "*.squashfs" 2>/dev/null | head -1)
        local total_size=0
        [ -f "$squashfs" ] && total_size=$(stat -c%s "$squashfs")
        local last_pct=10

        while kill -0 $copy_pid 2>/dev/null; do
            local elapsed=$(( $(date +%s) - start_time ))
            local written
            written=$(du -sb "$MOUNT" 2>/dev/null | awk '{print $1}' || echo 0)
            local pct=10
            if [ "$total_size" -gt 0 ]; then
                pct=$(( 10 + (written * 45 / total_size) ))
                [ "$pct" -gt 55 ] && pct=55
            fi
            if [ "$pct" -gt "$last_pct" ]; then
                local j=$last_pct
                while [ "$j" -le "$pct" ]; do
                    local elapsed2=$(( $(date +%s) - start_time ))
                    local eta="calculating..."
                    if [ "$elapsed2" -gt 0 ] && [ "$j" -gt 2 ]; then
                        local total_est=$(( elapsed2 * 100 / (j + 1) ))
                        local sl=$(( total_est - elapsed2 ))
                        [ "$sl" -gt 60 ] && eta="~$((sl/60))m $((sl%60))s" || eta="${sl}s"
                    fi
                    echo "XXX"
                    echo "$j"
                    printf "Copying system files...\n\nElapsed: %ds  |  ETA: %s" "$elapsed2" "$eta"
                    echo "XXX"
                    sleep 0.04
                    j=$(( j + 1 ))
                done
                last_pct=$pct
            fi
            sleep 1
        done
        wait $copy_pid

        _smooth $last_pct 60 "Configuring system..." 2
        core_configure

        _smooth 60 80 "Installing packages (this may take a while)..." 60
        core_packages

        _smooth 80 85 "Creating user $SYSTEM_USER..." 3
        core_users

        _smooth 85 93 "Installing bootloader..." 4
        core_bootloader

        _smooth 93 99 "Cleaning up..." 3
        core_cleanup

        _smooth 99 100 "Installation complete!" 1
        sleep 1

    } | whiptail \
        --title "  $INSTALLER_TITLE  " \
        --backtitle "Elezaio Linux $INSTALLER_VERSION \"$INSTALLER_CODENAME\"" \
        --gauge "Installing Elezaio Linux..." 10 70 0
}
