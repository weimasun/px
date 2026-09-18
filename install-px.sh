#!/usr/bin/env bash
# install-px.sh - source px.sh from the rc file. Git Bash / WSL / Linux / macOS.
# Run it from INSIDE the shell you want to install into, so the path is
# written in that shell's own form (/c/... for Git Bash, /mnt/c/... for WSL).
#
#   bash install-px.sh
#
# Idempotent: re-running replaces the old block instead of appending.

set -u

PX_DIR="$(cd "$(dirname "$0")" && pwd)"
PX_SH="$PX_DIR/px.sh"
MARKER='# px - single-command proxy prefix'

if [ ! -f "$PX_SH" ]; then
    echo "FAIL: px.sh not found next to this script: $PX_SH" >&2
    exit 1
fi

chmod +x "$PX_SH" 2>/dev/null || true

install_to() {
    rc="$1"
    [ -e "$rc" ] || : > "$rc"
    tmp="${rc}.px.tmp"
    grep -v -F -e "$MARKER" -e "px.sh" "$rc" > "$tmp" 2>/dev/null || true
    cat "$tmp" > "$rc"
    rm -f "$tmp"
    printf '\n%s\n. "%s"\n' "$MARKER" "$PX_SH" >> "$rc"
    echo "OK   wired into $rc"
}

install_to "$HOME/.bashrc"

if command -v zsh >/dev/null 2>&1; then
    install_to "$HOME/.zshrc"
fi

case "$(uname -r 2>/dev/null)" in
    *[Mm]icrosoft*|*WSL*)
        echo
        echo "WSL detected: 127.0.0.1 inside WSL2 is the VM, not the Windows host."
        echo "px auto-swaps it for the host IP from 'ip route show default'."
        echo "If that IP is wrong, set PX_WSL_HOST_IP=<windows-host-ip> in your rc file."
        ;;
esac

echo
echo "px.sh = $PX_SH"
echo "Open a new shell, or run:  . \"$PX_SH\""
