# systemd-boot -> GRUB migration
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
echo "[*] Migrating from systemd-boot -> GRUB"
if bootctl status &>/dev/null; then
    echo "[?] Bootloader is systemd-boot. Continuing..."
    echo "[*] Removing systemd-boot"
    bootctl remove
    [[ $? == 0 ]] && echo "[+] Removed systemd-boot" || (echo "[!] Failed to remove systemd-boot! Aborting." && exit 1)
    echo "[*] Installing GRUB..."
    "$grub_exe" --efi-directory=/boot --bootloader-id=ObsidianOSslot$(get_current_slot | tr '[:lower:]' '[:upper:]')
    [[ $? == 0 ]] && echo "[+] GRUB installed" || (echo "[!] Failed to install GRUB! Aborting. (YOU DONT HAVE SYSTEMD-BOOT EITHER NOW!)" && exit 1)
    "$grub_exe_mkconfig" -o /boot/grub/grub.cfg
    [[ $? == 0 ]] && echo "[+] Migration Done!!!" || (echo "[!] Failed to generate GRUB config!" && exit 1)
    echo "[?] Here's your new status:"
    $CTLPATH status
    echo "[+] Migration completed."
    exit
else
    echo "[!] Bootloader is not systemd-boot. No need to migrate."
    exit
fi
