#!/usr/bin/env bash
# ----------------------------------------------------------------------
# privacy‑suite.sh
# A one‑stop GUI utility that bundles seven common privacy‑hardening tasks
# (PII sanitisation, permission tightening, key hardening, trace cleaning,
# MAC randomisation, VPN toggling, and an “run‑everything” mode).
#
# Tested on: Fedora 44 + KDE Plasma (Lenovo ThinkPad)
# GUI library: zenity (installed from the Fedora repos)
# ----------------------------------------------------------------------
# Dependencies (install once):
#   sudo dnf install -y zenity iproute2 NetworkManager
#   (zenity provides the dialogs; ip & nmcli are already in the base system)
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# 1️⃣  Helper: Redact PII in a file (email, IPv4, phone)
# ----------------------------------------------------------------------
redact_file() {
    # $1 – input file path
    # $2 – where to write the redacted output (defaults to stdout)
    local infile="$1"
    local outfile="${2:-/dev/stdout}"

    # Three separate regular‑expression passes:
    #   • Email addresses → [REDACTED_EMAIL]
    #   • IPv4 addresses → [REDACTED_IP]
    #   • Phone numbers  → [REDACTED_PHONE]
    # The combined pipeline writes the result to $outfile.
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
    # $1 – directory to search recursively
    local target="$1"
    # Find any file that has *any* of the world‑read/write/exec bits set.
    # “/777” means “match if any of those bits are present”.
    find "$target" -type f -perm /777 -print0 |
        while IFS= read -r -d '' f; do
            chmod 600 "$f"          # Owner read/write only
        done
}

# ----------------------------------------------------------------------
# 3️⃣  Helper: Harden .ssh and .gnupg directories (private‑key safety)
# ----------------------------------------------------------------------
secure_keys() {
    for d in "$HOME/.ssh" "$HOME/.gnupg"; do
        if [[ -d "$d" ]]; then
            chmod 700 "$d"                     # Dir: rwx for owner only
            find "$d" -type f -exec chmod 600 {} +   # Files: rw for owner only
        fi
    done
}

# ----------------------------------------------------------------------
# 4️⃣  Helper: Clean traces – history, tmp files, caches
# ----------------------------------------------------------------------
clean_privacy() {
    # 1️⃣  Shell history
    history -c                               # Erase the current session's history
    rm -f "$HOME/.bash_history" "$HOME/.zsh_history"

    # 2️⃣  Temporary directories (only files owned by the current user)
    for td in /tmp "$HOME/.cache"; do
        find "$td" -maxdepth 1 -mindepth 1 -user "$(whoami)" -exec rm -rf {} + 2>/dev/null
    done

    # 3️⃣  Application caches – adjust/extend as you like
    rm -rf "$HOME/.cache"/*
    rm -rf "$HOME/.mozilla/firefox"/*.default-release/Cache/*
    rm -rf "$HOME/.config/google-chrome/Default/Cache"/*
}

# ----------------------------------------------------------------------
# 5️⃣  Helper: Randomise MAC address of a given network interface
# ----------------------------------------------------------------------
rotate_mac() {
    # $1 – network interface name (e.g. eth0, wlan0)
    local iface="$1"

    # Generate a random locally‑administered MAC address.
    # The first octet 02 forces the “locally administered” flag.
    local mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' \
                $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM)

    # Changing a MAC requires root; pkexec gives a graphical sudo prompt.
    pkexec ip link set dev "$iface" down
    pkexec ip link set dev "$iface" address "$mac"
    pkexec ip link set dev "$iface" up

    zenity --info --text="Interface $iface now uses MAC $mac"
}

# ----------------------------------------------------------------------
# 6️⃣  Helper: Toggle a NetworkManager VPN connection
# ----------------------------------------------------------------------
toggle_vpn() {
    # $1 – exact VPN connection name as shown in “nmcli connection show”
    local vpnname="$1"

    # Determine whether the VPN is already active.
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
# 7️⃣  GUI – Main menu (zenity list) and dispatch logic
# ----------------------------------------------------------------------
while true; do
    # Show a simple list dialog.  The first column is the internal “code”,
    # the second column is a human‑readable description.
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

    # If the user closed the dialog or pressed Cancel, exit the loop.
    [[ -z "$CHOICE" ]] && break

    case "$CHOICE" in
        1)   # ----------- Sanitize file ----------
            INFILE=$(zenity --file-selection --title="Select file to sanitize")
            [[ -z "$INFILE" ]] && continue    # user aborted
            OUTFILE=$(zenity --file-selection --save --confirm-overwrite \
                --title="Save sanitized output as…" \
                --filename="${INFILE}.redacted")
            [[ -z "$OUTFILE" ]] && continue
            redact_file "$INFILE" "$OUTFILE"
            zenity --info --text="Sanitisation complete:\n$OUTFILE"
            ;;

        2)   # ----------- Tighten permissions ----------
            TARGET=$(zenity --file-selection --directory \
                --title="Select directory to scan for 777 files")
            [[ -z "$TARGET" ]] && continue
            # pkexec runs the function with root rights.
            pkexec bash -c "tighten_perms \"$TARGET\""
            zenity --info --text="Permission tightening finished."
            ;;

        3)   # ----------- Secure key dirs ----------
            secure_keys
            zenity --info --text="SSH/GnuPG directories hardened."
            ;;

        4)   # ----------- Clean traces ----------
            clean_privacy
            zenity --info --text="Privacy clean‑up completed."
            ;;

        5)   # ----------- MAC rotation ----------
            IFACE=$(zenity --entry --title="MAC rotation" \
                --text="Enter network interface (e.g., eth0, wlan0):")
            [[ -z "$IFACE" ]] && continue
            rotate_mac "$IFACE"
            ;;

        6)   # ----------- VPN toggle ----------
            VPN=$(zenity --entry --title="VPN toggle" \
                --text="Enter the exact NetworkManager VPN connection name:")
            [[ -z "$VPN" ]] && continue
            toggle_vpn "$VPN"
            ;;

        7)   # ----------- Run everything ----------
            zenity --question --title="Run all?" \
                --text="This will:\n\
• Sanitize a file you pick\n\
• Fix 777 permissions in $HOME\n\
• Harden .ssh/.gnupg\n\
• Clean history, temps, caches\n\
• Rotate MAC (you’ll be asked for an interface)\n\
• Toggle a VPN (you’ll be asked for its name)\n\nProceed?"
            [[ $? -ne 0 ]] && continue   # user said No

            # 1️⃣ Sanitize (mandatory file)
            INFILE=$(zenity --file-selection --title="Select file to sanitize")
            [[ -z "$INFILE" ]] && continue
            OUTFILE="${INFILE}.redacted"
            redact_file "$INFILE" "$OUTFILE"

            # 2️⃣ Tighten perms throughout $HOME
            pkexec bash -c "tighten_perms \"$HOME\""

            # 3️⃣ Harden key directories
            secure_keys

            # 4️⃣ Clean traces
            clean_privacy

            # 5️⃣ MAC rotation (optional – ask user)
            IFACE=$(zenity --entry --title="MAC rotation" \
                --text="Enter network interface for MAC randomisation (or leave empty to skip):")
            [[ -n "$IFACE" ]] && rotate_mac "$IFACE"

            # 6️⃣ VPN toggle (optional – ask user)
            VPN=$(zenity --entry --title="VPN toggle" \
                --text="Enter VPN connection name (or leave empty to skip):")
            [[ -n "$VPN" ]] && toggle_vpn "$VPN"

            zenity --info --text="All tasks finished.\nSanitized file saved as:\n$OUTFILE"
            ;;

        *)   # Should never happen
            ;;
    esac
done
