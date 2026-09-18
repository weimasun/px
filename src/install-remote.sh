#!/usr/bin/env bash
# install-remote.sh - one-shot installer, meant to be piped straight into bash:
#
#   curl -fsSL https://raw.githubusercontent.com/weimasun/px/main/src/install-remote.sh | bash
#
# Git Bash / WSL / Linux / macOS. It downloads the px files into ~/px and then
# runs install-px.sh from there, which sources px.sh from your rc file.
# Re-running it upgrades the scripts in place. px-proxy.txt is never touched,
# so your proxy address survives a reinstall.
#
# NOTE: piping a URL into bash runs whatever that URL serves. Read the file
# first (it is short) if you do not trust the source.

set -eu

# Scripts live in src/ in the repo, but they are installed flat into ~/px so
# that px.sh, px-proxy.txt and the installers all sit in one directory.
repo='https://raw.githubusercontent.com/weimasun/px/main/src'
dir="$HOME/px"

mkdir -p "$dir"

for f in px.sh install-px.sh uninstall-px.sh px.ps1 install-px.ps1 uninstall-px.ps1 verify-px.ps1; do
    curl -fsSL "$repo/$f" -o "$dir/$f"
    echo "downloaded $f"
done

chmod +x "$dir"/*.sh

bash "$dir/install-px.sh"
