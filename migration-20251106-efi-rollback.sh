# rollback /efi -> /boot migration
set -euo pipefail
grub_exe=$(command -v grub2-install || command -v grub-install) || { echo "No GRUB found"; exit 1; }
grub_exe_mkconfig=$(command -v grub2-mkconfig || command -v grub-mkconfig) || { echo "No grub(2)-mkconfig found"; exit 1; }
get_current_slot() {
    if findmnt_output=$(findmnt -n -o SOURCE,UUID,PARTUUID,LABEL,PARTLABEL / 2>/dev/null); then
        for item in $findmnt_output; do
            case $item in
                *_a*) echo a; return 0 ;;
                *_b*) echo b; return 0 ;;
            esac
        done
    fi
    echo unknown
}

echo "[*] Rolling back /efi -> /boot migration"
if mountpoint -q /efi; then
    echo "[*] Backing up current /boot contents..."
    mkdir -p /boot_new
    mv /boot/* /boot_new/ || { echo "[!!!] Failed to move /boot/* to /boot_new"; exit 1; }
    echo "[*] Unmounting /efi..."
    umount /efi || { echo "[!!!] Failed to unmount /efi"; exit 1; }
    echo "[*] Reverting /etc/fstab mountpoint..."
    sed -i.bak '/[[:space:]]\/efi[[:space:]]/s/\/efi/\/boot/' /etc/fstab || { echo "[!!!] Failed to edit fstab"; exit 1; }
    echo "[*] Mounting all entries..."
    mount -A || { echo "[!!!] Failed to mount entries"; exit 1; }
    echo "[*] Restoring old kernel files..."
    mv /boot_new/* /boot/ || { echo "[!!!] Failed to move files back to /boot"; exit 1; }
    rmdir /boot_new
    echo "[*] Cleaning up leftover EFI bootloader files..."
    rm -rf /efi/EFI /efi/grub /efi/loader || echo "[!] Skipped cleaning /efi (might not exist)"
    echo "[*] Reinstalling GRUB (legacy /boot setup)..."
    "$grub_exe" --target=x86_64-efi --efi-directory=/boot --bootloader-id=ObsidianOSslot$(get_current_slot | tr '[:lower:]' '[:upper:]') || { echo "[!!!] Failed to reinstall GRUB"; exit 1; }
    sed -i 's|^#*GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|' /etc/default/grub
    "$grub_exe_mkconfig" -o /boot/grub/grub.cfg || { echo "[!!!] Failed to generate GRUB config"; exit 1; }
    echo "[+] Rollback complete. Reboot recommended."
    $CTLPATH status
else
    echo "[!] Already using old /boot layout. Nothing to rollback."
    exit 1
fi
