#!/bin/bash
# Elezaio Installer - Disk Operations
# Based on Debian live installation best practices

_log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

_chroot() {
    DEBIAN_FRONTEND=noninteractive \
    LANG=C \
    chroot "$MOUNT" /bin/bash -c "$*"
}

core_partition() {
    _log "Partitioning $INSTALL_DISK"

    # Wipe everything
    wipefs -af "$INSTALL_DISK" >> "$LOG" 2>&1
    sgdisk --zap-all "$INSTALL_DISK" >> "$LOG" 2>&1
    dd if=/dev/zero of="$INSTALL_DISK" bs=1M count=10 >> "$LOG" 2>&1

    # Create GPT with EFI + root
    sgdisk \
        --new=1:0:+512M \
        --typecode=1:ef00 \
        --change-name=1:"EFI System" \
        --new=2:0:0 \
        --typecode=2:8300 \
        --change-name=2:"Elezaio Root" \
        "$INSTALL_DISK" >> "$LOG" 2>&1

    partprobe "$INSTALL_DISK" >> "$LOG" 2>&1
    udevadm settle >> "$LOG" 2>&1
    sleep 2

    # Handle nvme partition naming (nvme0n1p1 vs sda1)
    if echo "$INSTALL_DISK" | grep -q "nvme\|mmcblk"; then
        EFI_PART="${INSTALL_DISK}p1"
        ROOT_PART="${INSTALL_DISK}p2"
    else
        EFI_PART="${INSTALL_DISK}1"
        ROOT_PART="${INSTALL_DISK}2"
    fi
    export EFI_PART ROOT_PART

    mkfs.fat -F32 -n "EFI" "$EFI_PART" >> "$LOG" 2>&1
    mkfs.ext4 -L "elezaio" -F "$ROOT_PART" >> "$LOG" 2>&1

    _log "Partitioning done: EFI=$EFI_PART ROOT=$ROOT_PART"
}

core_mount() {
    _log "Mounting partitions"

    mkdir -p "$MOUNT"
    mount "$ROOT_PART" "$MOUNT" >> "$LOG" 2>&1
    mkdir -p "$MOUNT/boot/efi"
    mount "$EFI_PART" "$MOUNT/boot/efi" >> "$LOG" 2>&1

    _log "Mounted ROOT=$ROOT_PART EFI=$EFI_PART at $MOUNT"
}

core_bind_mount() {
    _log "Binding virtual filesystems"

    for fs in dev dev/pts proc sys run; do
        mkdir -p "$MOUNT/$fs"
        mount --bind "/$fs" "$MOUNT/$fs" >> "$LOG" 2>&1
    done

    # EFI vars needed for grub-install
    if [ -d /sys/firmware/efi/efivars ]; then
        mkdir -p "$MOUNT/sys/firmware/efi/efivars"
        mount --bind /sys/firmware/efi/efivars \
            "$MOUNT/sys/firmware/efi/efivars" >> "$LOG" 2>&1
    fi

    # DNS resolution inside chroot
    cp /etc/resolv.conf "$MOUNT/etc/resolv.conf" 2>/dev/null || true

    _log "Virtual filesystems bound"
}

core_unbind() {
    _log "Unbinding virtual filesystems"

    # Unmount in reverse order
    for fs in sys/firmware/efi/efivars run sys/fs/cgroup sys proc dev/pts dev; do
        umount -lf "$MOUNT/$fs" 2>/dev/null || true
    done

    _log "Unbind complete"
}

core_copy() {
    _log "Finding squashfs"

    local squashfs=""
    for path in \
        /lib/live/mount/medium/live/filesystem.squashfs \
        /run/live/medium/live/filesystem.squashfs \
        /lib/live/mount/medium/live/filesystem.squashfs \
        /cdrom/live/filesystem.squashfs \
        /media/cdrom/live/filesystem.squashfs; do
        if [ -f "$path" ]; then
            squashfs="$path"
            break
        fi
    done

    # Fallback: find it anywhere
    if [ -z "$squashfs" ]; then
        squashfs=$(find /run /lib/live /mnt /media \
            -name "filesystem.squashfs" 2>/dev/null | head -1)
    fi

    if [ -z "$squashfs" ]; then
        _log "ERROR: Cannot find filesystem.squashfs!"
        exit 1
    fi

    _log "Found squashfs: $squashfs"
    _log "Extracting to $MOUNT (this takes a while)..."

    # unsquashfs -f = force overwrite, -d = destination
    unsquashfs -f -d "$MOUNT" "$squashfs" >> "$LOG" 2>&1

    _log "Extraction complete"
}
