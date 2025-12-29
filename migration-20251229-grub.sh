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
echo "[*] Migrating from /efi/grub -> /boot/grub"
if [[ ! -d /boot/grub ]]; then
    echo "[?] Currently using /efi/grub. Continuing..."
    echo "[*] Removing old GRUB config..."
    mkdir -p /boot/grub
    rm -rf /efi/grub
    [[ $? == 0 ]] && echo "[+] Removed." || (echo "[!!!] Failed to remove GRUB config" && exit 1)
    mkdir -p /boot/grub
    "$grub_exe_mkconfig" -o /boot/grub/grub.cfg
    [[ $? == 0 ]] && echo "[+] Migration Done!!!" || (echo "[!!!] Failed to generate GRUB config!" && exit 1)
    echo "[?] Here's your new status:"
    $CTLPATH status
    echo "[+] Migration completed. Reboot recommended."
    exit
else
    echo "[!] Already using the new /boot/grub config path. No need to migrate."
    exit 1
fi
