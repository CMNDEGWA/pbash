#!/usr/bin/env bash
# ----------------------------------------------------------------------
# pbashGUI.sh
# GUI privacy toolbox (PII redaction, permission tightening, key hardening,
# trace cleaning, MAC randomisation, VPN toggle, “run‑all”).
# First‑run splash now uses hwinfo.
#
# Tested on: Fedora 44 + KDE Plasma (works on any modern Linux distro).
# ----------------------------------------------------------------------
# Prerequisites (install once):
#   sudo dnf install -y zenity hwinfo inxi
#   # optional – neofetch‑gtk, cpu-x, baobab, etc.
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# 0️⃣  First‑run system‑information splash (hwinfo)
# ----------------------------------------------------------------------
FIRST_RUN_FLAG="$HOME/.config/privacy-suite/first-run-done"

if [[ ! -f "$FIRST_RUN_FLAG" ]]; then
    mkdir -p "$(dirname "$FIRST_RUN_FLAG")"

    # -------- Choose which GUI you prefer for the splash ----------
    # Uncomment ONE (or more) of the lines below.
    hwinfo --short --gui &          # Full hardware report (default)

    # Optional alternatives – comment out if not installed
    # lshw-gtk &                     # Hierarchical hardware view
    # cpu-x -g &                     # CPU‑centric view
    # kinfocenter5 &                 # KDE native system info
    # baobab &                       # Disk‑usage visualiser
    # neofetch --gtk &               # Pretty logo + brief summary
    # inxi -Fz | zenity --info --width=600 --height=400 \
    #          --title="System Overview" &

    # Give the user ~12 seconds to glance at the window, then close it
    (sleep 12; pkill -f hwinfo) &
    touch "$FIRST_RUN_FLAG"
fi


# ----------------------------------------------------------------------
# 1️⃣  Helper: Redact PII in a file (email, IPv4, phone)
# ----------------------------------------------------------------------
redact_file() {
    local infile="$1"
    local outfile="${2:-/dev/stdout}"
    sed -E \
        -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[REDACTED_EMAIL]/g' \
        -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[REDACTED_IP]/g' \
        -e 's/(\+?[0-9]{1,3}[-. ]?)?(\(?[0-9]{3}\)?[-. ]?)[0-9]{3}[-. ]?[0-9]{4}/[REDACTED_PHONE]/g' \
        "$infile" > "$outfile"
}


# ----------------------------------------------------------------------
# 2️⃣  Helper: Find files with permissive mode (777) and lock them down
# ----------------------------------------------------------------------
tighten_perms() {
    local target="$1"
    find "$target" -type f -perm /777 -print0 |
        while IFS= read -r -d '' f; do
            chmod 600 "$f"
        done
}


# ----------------------------------------------------------------------
# 3️⃣  Helper: Harden .ssh and .gnupg directories
# ----------------------------------------------------------------------
secure_keys() {
    for d in "$HOME/.ssh" "$HOME/.gnupg"; do
        if [[ -d "$d" ]]; then
            chmod 700 "$d"
            find "$d" -type f -exec chmod 600 {} +
        fi
    done
}


# ----------------------------------------------------------------------
# 4️⃣  Helper: Clean traces – history, tmp files, caches
# ----------------------------------------------------------------------
clean_privacy() {
    # 1️⃣  Shell history
    history -c
    rm -f "$HOME/.bash_history" "$HOME/.zsh_history"

    # 2️⃣  Temp directories (only files owned by the current user)
    for td in /tmp "$HOME/.cache"; do
        find "$td" -maxdepth 1 -mindepth 1 -user "$(whoami)" -exec rm -rf {} + 2>/dev/null
    done

    # 3️⃣  Common browser caches – extend/remove as you need
    rm -rf "$HOME/.cache"/*
    rm -rf "$HOME/.mozilla/firefox"/*.default-release/Cache/*
    rm -rf "$HOME/.config/google-chrome/Default/Cache"/*
}


# ----------------------------------------------------------------------
# 5️⃣  Helper: Randomise MAC address of a given interface
# ----------------------------------------------------------------------
rotate_mac() {
    local iface="$1"
    # Random locally‑administered MAC (02:xx:xx:xx:xx:xx)
    local mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM)

    pkexec ip link set dev "$iface" down
    pkexec ip link set dev "$iface" address "$mac"
    pkexec ip link set dev "$iface" up

    zenity --info --text="Interface $iface now uses MAC $mac"
}


# ----------------------------------------------------------------------
# 6️⃣  Helper: Toggle a NetworkManager VPN connection
# ----------------------------------------------------------------------
toggle_vpn() {
    local vpnname="$1"
    local active=$(nmcli -t -f NAME,TYPE,DEVICE con show --active |
                   grep "^$vpnname:" | cut -d: -f3)

    if [[ -n "$active" ]]; then
        nmcli con down id "$vpnname"
        zenity --info --text="VPN \"$vpnname\" disconnected."
    else
        nmcli con up id "$vpnname"
        zenity --info --text="VPN \"$vpnname\" connected."
    fi
}


# ----------------------------------------------------------------------
# 7️⃣  Main GUI menu (Zenity) and dispatcher
# ----------------------------------------------------------------------
while true; do
    CHOICE=$(zenity --list \
        --title="Privacy Suite" \
        --column="Option" --column="Description" \
        1 "Sanitize a log / text file (PII redaction)" \
        2 "Find & fix files with 777 permissions" \
        3 "Harden .ssh and .gnupg directories" \
        4 "Clear shell history, temp files and caches" \
        5 "Randomise MAC address of an interface (needs sudo)" \
        6 "Toggle a pre‑configured VPN (NetworkManager)" \
        7 "Run **all** of the above sequentially" \
        --height=350 --width=600)

    [[ -z "$CHOICE" ]] && break   # user closed the dialog

    case "$CHOICE" in
        1)  # ---------- Sanitize file ----------
            INFILE=$(zenity --file-selection --title="Select file to sanitize")
            [[ -z "$INFILE" ]] && continue
            OUTFILE=$(zenity --file-selection --save --confirm-overwrite \
                --title="Save sanitized output as…" \
                --filename="${INFILE}.redacted")
            [[ -z "$OUTFILE" ]] && continue
            redact_file "$INFILE" "$OUTFILE"
            zenity --info --text="Sanitisation complete:\n$OUTFILE"
            ;;

        2)  # ---------- Tighten permissions ----------
            TARGET=$(zenity --file-selection --directory \
                --title="Select directory to scan for 777 files")
            [[ -z "$TARGET" ]] && continue
            pkexec bash -c "tighten_perms \"$TARGET\""
            zenity --info --text="Permission tightening finished."
            ;;

        3)  # ---------- Secure key dirs ----------
            secure_keys
            zenity --info --text="SSH/GnuPG directories hardened."
            ;;

        4)  # ---------- Clean traces ----------
            clean_privacy
            zenity --info --text="Privacy clean‑up completed."
            ;;

        5)  # ---------- MAC rotation ----------
            IFACE=$(zenity --entry --title="MAC rotation" \
                --text="Enter network interface (e.g., eth0, wlan0):")
            [[ -z "$IFACE" ]] && continue
            rotate_mac "$IFACE"
            ;;

        6)  # ---------- VPN toggle ----------
            VPN=$(zenity --entry --title="VPN toggle" \
                --text="Enter the exact NetworkManager VPN connection name:")
            [[ -z "$VPN" ]] && continue
            toggle_vpn "$VPN"
            ;;

        7)  # ---------- Run everything ----------
            zenity --question --title="Run all?" \
                --text="This will:\n\
• Sanitize a file you pick\n\
• Fix 777 permissions in $HOME\n\
• Harden .ssh/.gnupg\n\
• Clean history, temps, caches\n\
• Rotate MAC (you’ll be asked for an interface)\n\
• Toggle a VPN (you’ll be asked for its name)\n\nProceed?"
            [[ $? -ne 0 ]] && continue

            # 1️⃣  Sanitize
            INFILE=$(zenity --file-selection --title="Select file to sanitize")
            [[ -z "$INFILE" ]] && continue
            OUTFILE="${INFILE}.redacted"
            redact_file "$INFILE" "$OUTFILE"

            # 2️⃣  Permissions
            pkexec bash -c "tighten_perms \"$HOME\""

            # 3️⃣  Keys
            secure_keys

            # 4️⃣  Clean traces
            clean_privacy

            # 5️⃣  MAC rotation (optional)
            IFACE=$(zenity --entry --title="MAC rotation" \
                --text="Enter network interface for MAC randomisation (or leave empty to skip):")
            [[ -n "$IFACE" ]] && rotate_mac "$IFACE"

            # 6️⃣  VPN toggle (optional)
            VPN=$(zenity --entry --title="VPN toggle" \
                --text="Enter VPN connection name (or leave empty to skip):")
            [[ -n "$VPN" ]] && toggle_vpn "$VPN"

            zenity --info --text="All tasks finished.\nSanitized file saved as:\n$OUTFILE"
            ;;

        *)  # should never happen
            ;;
    esac
done
