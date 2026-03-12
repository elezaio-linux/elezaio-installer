#!/bin/bash
# Elezaio Installer - Disk & Partitioning

LOG="/var/log/elezaio-install.log"
MOUNT="/mnt/elezaio"

_log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

core_partition() {
    _log "Partitioning $TARGET_DISK"

    # Wipe disk
    wipefs -af "$TARGET_DISK" >> "$LOG" 2>&1
    sgdisk -Z "$TARGET_DISK" >> "$LOG" 2>&1

    # Create GPT partition table
    parted -s "$TARGET_DISK" mklabel gpt >> "$LOG" 2>&1

    # EFI partition (512MB)
    parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 513MiB >> "$LOG" 2>&1
    parted -s "$TARGET_DISK" set 1 esp on >> "$LOG" 2>&1

    # Root partition (rest of disk)
    parted -s "$TARGET_DISK" mkpart ROOT ext4 513MiB 100% >> "$LOG" 2>&1

    # Format
    if [[ "$TARGET_DISK" == *nvme* ]]; then
        EFI_PART="${TARGET_DISK}p1"
        ROOT_PART="${TARGET_DISK}p2"
    else
        EFI_PART="${TARGET_DISK}1"
        ROOT_PART="${TARGET_DISK}2"
    fi

    mkfs.fat -F32 "$EFI_PART" >> "$LOG" 2>&1
    mkfs.ext4 -F "$ROOT_PART" >> "$LOG" 2>&1

    export EFI_PART ROOT_PART
    _log "Partitioning complete: EFI=$EFI_PART ROOT=$ROOT_PART"
}

core_mount() {
    _log "Mounting partitions"
    mkdir -p "$MOUNT"
    mount "$ROOT_PART" "$MOUNT" >> "$LOG" 2>&1
    mkdir -p "$MOUNT/boot/efi"
    mount "$EFI_PART" "$MOUNT/boot/efi" >> "$LOG" 2>&1
    export MOUNT
}

core_copy() {
    _log "Copying system files"
    # Copy squashfs contents to target
    local squashfs
    squashfs=$(find /run/live -name "*.squashfs" 2>/dev/null | head -1)
    squashfs="${squashfs:-/run/live/medium/live/filesystem.squashfs}"

    if [[ ! -f "$squashfs" ]]; then
        _log "ERROR: squashfs not found at $squashfs"
        exit 1
    fi

    unsquashfs -f -d "$MOUNT" "$squashfs" >> "$LOG" 2>&1
    _log "Files copied successfully"
}
