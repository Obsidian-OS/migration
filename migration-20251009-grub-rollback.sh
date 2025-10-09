# rollback GRUB -> systemd-boot migration (20251009-grub)
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

echo "[*] Rolling back GRUB -> systemd-boot"
if ! command -v bootctl &>/dev/null; then
    echo "[!!!] bootctl not found! Cannot rollback systemd-boot."
    exit 1
fi

echo "[*] Installing systemd-boot..."
bootctl install
[[ $? == 0 ]] && echo "[+] systemd-boot installed" || { echo "[!] Failed to install systemd-boot!"; exit 1; }
grub_efi_name="ObsidianOSslot$(get_current_slot | tr '[:lower:]' '[:upper:]')"
echo "[*] Removing GRUB EFI entry: $grub_efi_name (if exists)"
efibootmgr -b $(efibootmgr | grep -i "$grub_efi_name" | awk '{print $1}' | tr -d '*') -B 2>/dev/null || echo "[!] No GRUB EFI entry found, skipping..."
echo "[+] Rollback complete. Reboot recommended."
bootctl status
