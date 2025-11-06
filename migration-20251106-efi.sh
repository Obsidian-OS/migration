# /boot -> /efi migration
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
echo "[*] Migrating from /boot -> /efi"
if [[ ! -d /efi || -z "$(ls -A /efi 2>/dev/null)" ]]; then
    echo "[?] Currently using old /boot. Continuing..."
    echo "[*] Moving the old /boot somewhere else..."
    mkdir -p /boot_old
    mv /boot/* /boot_old/
    [[ $? == 0 ]] && echo "[+] Moved." || (echo "[!!!] Failed to move /boot/* to /boot_old" && exit 1) 
    echo "[*] Unmounting boot partition..."
    umount /boot
    [[ $? == 0 ]] && echo "[+] Unmounted /boot." || (echo "[!!!] Failed to unmount /boot." && exit 1)
    echo "[*] Editing mountpoint in /etc/fstab"
    sed -i.bak '/[[:space:]]\/boot[[:space:]]/s/\/boot/\/efi/' /etc/fstab
    [[ $? == 0 ]] && echo "[+] Edited mountpoint." || (echo "[!!!] Failed to edit mountpoint! Aborting." && exit 1)
    echo "[*] Mounting all entries..."
    mount -a
    [[ $? == 0 ]] && echo "[+] Mounted." || (echo "[!!!] Failed to mount entries (CRITICAL!!!)" && exit 1)
    echo "[*] Moving old partition files back..."
    mkdir -p /boot
    mv /boot_old/* /boot/
    [[ $? == 0 ]] && echo "[+] Moved." || (echo "[!!!] Failed to move old boot partition back." && exit 1)
    echo "[*] Cleaning up..."
    rmdir /boot_old
    rm -rf /boot/EFI /boot/grub /boot/loader
    [[ $? == 0 ]] && echo "[+] Cleanup done." || (echo "[!!!] Failed to cleanup /boot_old and/or /boot." && exit 1)
    echo "[*] Reinstalling GRUB..."
    "$grub_exe" --efi-directory=/efi --target=x86_64-efi --bootloader-id=ObsidianOSslot$(get_current_slot | tr '[:lower:]' '[:upper:]')
    [[ $? == 0 ]] && echo "[+] GRUB reinstalled" || (echo "[!!!] Failed to reinstall GRUB! Aborting. (CRITICAL!!!)" && exit 1)
    sed -i 's|^#*GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|' /etc/default/grub
    "$grub_exe_mkconfig" -o /efi/grub/grub.cfg
    [[ $? == 0 ]] && echo "[+] Migration Done!!!" || (echo "[!!!] Failed to generate GRUB config!" && exit 1)
    echo "[?] Here's your new status:"
    $CTLPATH status
    echo "[+] Migration completed. Reboot recommended."
    exit
else
    echo "[!] Already using the new /efi. No need to migrate."
    exit 1
fi
