#!/bin/bash

set -e

VOLUME="$HOME/subes.hc"
MAPPER="vc"
MOUNTPOINT="$HOME/mnt/vera"

case "$1" in
    mount)
        mkdir -p "$MOUNTPOINT"

        sudo cryptsetup open \
            --type tcrypt \
            --veracrypt \
            "$VOLUME" \
            "$MAPPER"

        sudo mount -o uid=$(id -u),gid=$(id -g) \
            /dev/mapper/"$MAPPER" \
            "$MOUNTPOINT"

        echo "Mounted at $MOUNTPOINT"
        ;;
        
    umount)
        sudo umount "$MOUNTPOINT" || true
        sudo cryptsetup close "$MAPPER"
        echo "Unmounted"
        ;;

    status)
        if mountpoint -q "$MOUNTPOINT"; then
            echo "Mounted"
            df -h "$MOUNTPOINT"
        else
            echo "Not mounted"
        fi
        ;;

    *)
        echo "Usage: $0 {mount|umount|status}"
        exit 1
        ;;
esac
