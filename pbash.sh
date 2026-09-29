#!/usr/bin/env bash
# privacy-toolkit.sh – All‑in‑one GUI privacy utility for Fedora 44 KDE Plasma
# --------------------------------------------------------------
# 1. Sanitize logs / text files (PII redaction)
# 2. Recursively tighten permissive file permissions (777 → 600)
# 3. Harden .ssh and .gnupg directories
# 4. Clear shell history, temp files and common caches
# 5. Rotate a network interface MAC address
# 6. Toggle a pre‑configured VPN (NetworkManager)
# --------------------------------------------------------------
# Requires: kdialog, sed, awk, find, chmod, ip, nmcli, sudo
# --------------------------------------------------------------

# -------------------- Helper Functions --------------------

redact_file() {
    local infile="$1"
    local outfile="${infile}.redacted"

    sed -E \
        -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[REDACTED_EMAIL]/g' \
        -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[REDACTED_IP]/g' \
        -e 's/(\+?[0-9]{1,3}[-. ]?)?(\(?[0-9]{3}\)?[-. ]?)[0-9]{3}[-. ]?[0-9]{4}/[REDACTED_PHONE]/g' \
        "$infile" > "$outfile"

    kdialog --msgbox "Redacted file created:\n$outfile" --title "Sanitize Logs"
}

tighten_perms() {
    local target="$1"
    find "$target" -type f -perm /777 -print0 |
        while IFS= read -r -d '' f; do
            chmod 600 "$f"
        done
    kdialog --msgbox "Over‑permissive files under $target have been set to 600." \
        --title "Permission Harden"
}

secure_keys() {
    local dirs=("$HOME/.ssh" "$HOME/.gnupg")
    for d in "${dirs[@]}"; do
        [[ -d "$d" ]] && {
            chmod 700 "$d"
            find "$d" -type f -exec chmod 600 {} +
        }
    done
    kdialog --msgbox "Permissions for .ssh and .gnupg hardened." \
        --title "Key Directory Security"
}

clean_privacy() {
    # 1. History
    history -c
    rm -f "$HOME/.bash_history" "$HOME/.zsh_history"

    # 2. Temp dirs (only files owned by the current user)
    for td in /tmp "$HOME/.cache"; do
        find "$td" -maxdepth 1 -mindepth 1 -user "$(whoami)" -exec rm -rf {} + 2>/dev/null
    done

    # 3. Common caches
    rm -rf "$HOME/.cache"/*
    rm -rf "$HOME/.mozilla/firefox"/*.default-release/Cache/*
    rm -rf "$HOME/.config/google-chrome/Default/Cache"/*

    kdialog --msgbox "History cleared, temporary files and caches removed." \
        --title "Privacy Clean‑up"
}

rotate_mac() {
    local iface iface_list iface_selected
    iface_list=$(ip -o link show | awk -F': ' '{print $2}')
    iface_selected=$(kdialog --combobox "Select interface to randomise MAC:" \
                              "$iface_list" --title "MAC Rotator")
    [[ -z "$iface_selected" ]] && return

    # Generate a random locally‑administered MAC (02:xx:xx:xx:xx:xx)
    local newmac
    newmac=$(printf '02:%02x:%02x:%02x:%02x:%02x' $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM)

    # Need root for the changes
    pkexec bash -c "ip link set dev $iface_selected down && \
                    ip link set dev $iface_selected address $newmac && \
                    ip link set dev $iface_selected up"

    kdialog --msgbox "Interface $iface_selected now uses MAC $newmac" \
        --title "MAC Rotator"
}

toggle_vpn() {
    # List only VPN connections (type vpn) via nmcli
    local vpn_list vpn_selected state
    vpn_list=$(nmcli -t -f NAME,TYPE connection show | grep ':vpn$' | cut -d: -f1)
    [[ -z "$vpn_list" ]] && {
        kdialog --error "No VPN connections found in NetworkManager." \
                 --title "VPN Toggle"
        return
    }

    vpn_selected=$(kdialog --combobox "Select VPN to toggle:" "$vpn_list" \
                            --title "VPN Toggle")
    [[ -z "$vpn_selected" ]] && return

    state=$(nmcli -t -f NAME,DEVICE connection show --active | grep "^$vpn_selected:" | cut -d: -f2)

    if [[ -n "$state" ]]; then
        nmcli connection down id "$vpn_selected"
        kdialog --msgbox "VPN \"$vpn_selected\" disconnected." \
                 --title "VPN Toggle"
    else
        nmcli connection up id "$vpn_selected"
        kdialog --msgbox "VPN \"$vpn_selected\" connected." \
                 --title "VPN Toggle"
    fi
}

# -------------------- Main GUI Menu --------------------

while true; do
    choice=$(kdialog --menu "Privacy Toolkit – Choose an action" \
        1 "Sanitize a log / text file (PII redaction)" \
        2 "Tighten overly permissive file permissions (777 → 600)" \
        3 "Secure .ssh and .gnupg directories" \
        4 "Clear shell history, temp files & caches" \
        5 "Rotate MAC address of an interface (requires root)" \
        6 "Toggle a NetworkManager VPN connection" \
        7 "Exit")

    case "$choice" in
        1)  # Sanitize file
            file=$(kdialog --title "Select file to sanitize" --getopenfilename "$HOME")
            [[ -n "$file" ]] && redact_file "$file"
            ;;
        2)  # Tighten perms
            dir=$(kdialog --title "Select directory to scan" --getexistingdirectory "$HOME")
            [[ -n "$dir" ]] && tighten_perms "$dir"
            ;;
        3)  secure_keys ;;
        4)  clean_privacy ;;
        5)  rotate_mac ;;
        6)  toggle_vpn ;;
        7|*) break ;;
    esac
done

exit 0
