# /etc -> /run/etc_ab migration
set -euo pipefail
get_current_mountpoint() {
    echo "$(findmnt -n -o SOURCE / 2>/dev/null)"
}
echo "[*] Migrating from /etc -> /run/etc_ab"
if [[ ! -d /run/etc_ab || -z "$(ls -A /run/etc_ab 2>/dev/null)" ]]; then
    echo "[?] Currently using old /etc. Continuing..."
    echo "[*] Copying the shared /etc files to the per-slot /etc..."
    mount $(get_current_mountpoint) /tmp/root_mount --mkdir || (echo "[!!!] Failed to mount / to /tmp/root_mount" && exit 1) 
    cp -r /etc/* /tmp/root_mount/etc/
    [[ $? == 0 ]] && echo "[+] Copied." || (echo "[!!!] Failed to move /etc/* to /tmp/root_mount/etc/" && exit 1) 
    echo "[*] Unmounting etc_ab partition..."
    umount /etc -l
    [[ $? == 0 ]] && echo "[+] Unmounted /etc." || (echo "[!!!] Failed to unmount /etc." && exit 1)
    echo "[*] Editing mountpoint in /etc/fstab"
    sed -i.bak '/[[:space:]]\/etc[[:space:]]/s/\/etc/\/run\/etc_ab\//' /etc/fstab
    [[ $? == 0 ]] && echo "[+] Edited mountpoint." || (echo "[!!!] Failed to edit mountpoint! Aborting." && exit 1)
    echo "[*] Mounting all entries..."
    systemctl daemon-reload || true
    mount -a
    [[ $? == 0 ]] && echo "[+] Mounted." || (echo "[!!!] Failed to mount entries (CRITICAL!!!)" && exit 1)
    echo "[*] Removing shared files..."
    rm -rf /run/etc_ab/*
    [[ $? == 0 ]] && echo "[+] Removed." || (echo "[!!!] Failed to remove." && exit 1)
    echo "[*] Cleaning up..."
    umount /tmp/root_mount
    rmdir /tmp/root_mount
    [[ $? == 0 ]] && echo "[+] Cleanup done." || (echo "[!!!] Failed to cleanup." && exit 1)
    echo "[?] Here's your new status:"
    $CTLPATH status
    echo "[+] Migration completed. Reboot not required."
    exit
else
    echo "[!] Already using the new /run/etc_ab. No need to migrate."
    exit 1
fi
