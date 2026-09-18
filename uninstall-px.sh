#!/usr/bin/env bash
# uninstall-px.sh - remove the px block from shell rc files.
# Git Bash / WSL / Linux / macOS. Run from INSIDE the shell you installed into.
#
#   bash ~/px/uninstall-px.sh
#
# Idempotent: safe to run when nothing is installed.
# Does NOT delete px.sh or this folder - remove them manually if you are done.

set -u

MARKER='# px - single-command proxy prefix'

strip_file() {
    rc="$1"

    [ -f "$rc" ] || return 0

    # nothing of ours here, leave the file untouched
    if ! grep -q -F "$MARKER" "$rc" 2>/dev/null; then
        return 0
    fi

    tmp="${rc}.px.tmp"
    awk -v m="$MARKER" '
        # the line right after the marker is the source line: drop it too
        {
            if (drop == 1) {
                drop = 0
                if (index($0, "px.sh") > 0) { next }
            }
            if (index($0, m) > 0) { drop = 1; next }
            print
        }
    ' "$rc" > "$tmp" || { rm -f "$tmp"; echo "FAIL: could not rewrite $rc" >&2; return 1; }

    # cat into place instead of mv: keeps owner/mode of the original file
    cat "$tmp" > "$rc"
    rm -f "$tmp"

    # if only blank lines are left, the file was ours - delete it
    if ! grep -q '[^[:space:]]' "$rc" 2>/dev/null; then
        rm -f "$rc"
        echo "OK   removed (was empty): $rc"
    else
        echo "OK   cleaned px block from: $rc"
    fi
}

strip_file "$HOME/.bashrc"
strip_file "$HOME/.zshrc"
strip_file "$HOME/.bash_profile"
strip_file "$HOME/.profile"

echo
echo "px.sh itself is kept. To remove everything:"
echo "  rm -rf \"$(cd "$(dirname "$0")" && pwd)\""
