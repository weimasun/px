#!/usr/bin/env bash
# install-remote.sh - one-shot installer, meant to be piped straight into bash:
#
#   curl -fsSL https://raw.githubusercontent.com/weimasun/px/main/src/install-remote.sh | bash
#
# Git Bash / WSL / Linux / macOS. It downloads the px files into ~/px and then
# sources px.sh from your rc file. Re-running it upgrades the scripts in place.
# px-proxy.txt is never touched, so your proxy address survives.
# Idempotent: the loader block is replaced, not appended.
#
# NOTE: piping a URL into bash runs whatever that URL serves. Read the file
# first (it is short) if you do not trust the source.

set -eu

# Scripts live in src/ in the repo, but they are installed flat into ~/px so
# that px.sh, px-proxy.txt and the uninstaller all sit in one directory.
repo='https://raw.githubusercontent.com/weimasun/px/main/src'
dir="$HOME/px"

mkdir -p "$dir"

for f in px.sh uninstall-px.sh px.ps1 uninstall-px.ps1 verify-px.ps1; do
    curl -fsSL "$repo/$f" -o "$dir/$f"
    echo "downloaded $f"
done

chmod +x "$dir"/*.sh

# --- source px.sh from the shell rc files ----------------------------------

px_sh="$dir/px.sh"
if [ ! -f "$px_sh" ]; then
    echo "FAIL: px.sh not found next to this script: $px_sh" >&2
    exit 1
fi

marker='# px - single-command proxy prefix'

install_to() {
    rc="$1"
    [ -e "$rc" ] || : > "$rc"
    tmp="${rc}.px.tmp"
    grep -v -F -e "$marker" -e "px.sh" "$rc" > "$tmp" 2>/dev/null || true
    cat "$tmp" > "$rc"
    rm -f "$tmp"
    printf '\n%s\n. "%s"\n' "$marker" "$px_sh" >> "$rc"
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
echo "px.sh = $px_sh"
echo "Open a new shell, or run:  . \"$px_sh\""
