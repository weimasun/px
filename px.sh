# px - run ONE command through a proxy, then restore. POSIX sh / bash / zsh.
# Linux, macOS, WSL and Git Bash all use this file. Source it from your rc file:
#
#   . "/c/Users/<you>/px/px.sh"              (Git Bash)
#   . "/mnt/c/Users/<you>/px/px.sh"          (WSL)
#   . "$HOME/px/px.sh"                       (Linux / macOS)
#
# No restore logic is needed here: `VAR=x cmd` only affects that one child.
# Linux env vars ARE case sensitive, so both cases are exported.

PX_SELF="${BASH_SOURCE[0]:-$0}"
PX_DIR="${PX_DIR:-$(cd "$(dirname "$PX_SELF")" 2>/dev/null && pwd)}"

_px_norm() {
    case "$1" in
        *://*) printf '%s' "$1" ;;
        *)     printf 'http://%s' "$1" ;;
    esac
}

# Single source: px-proxy.txt, written by `px --set`. No env-var override and
# no hardcoded fallback - prints nothing and returns 1 when the file is unset.
_px_default() {
    if [ -r "$PX_DIR/px-proxy.txt" ]; then
        # strip CR and any leading junk such as a UTF-8 BOM
        _px_v=$(tr -d '\r' < "$PX_DIR/px-proxy.txt" | sed 's/^[^A-Za-z]*//')
        if [ -n "$_px_v" ]; then _px_norm "$_px_v"; return 0; fi
    fi
    return 1
}

# WSL2 runs in a VM: 127.0.0.1 is the VM itself, not the Windows host.
_px_wsl_fix() {
    case "$(uname -r 2>/dev/null)" in
        *[Mm]icrosoft*|*WSL*) ;;
        *) printf '%s' "$1"; return 0 ;;
    esac
    case "$1" in
        *127.0.0.1*|*localhost*) ;;
        *) printf '%s' "$1"; return 0 ;;
    esac
    _px_ip=${PX_WSL_HOST_IP:-$(ip route show default 2>/dev/null | awk '{print $3; exit}')}
    if [ -z "$_px_ip" ]; then printf '%s' "$1"; return 0; fi
    printf '%s' "$1" | sed "s/127\.0\.0\.1/$_px_ip/g; s/localhost/$_px_ip/g"
}

px() {
    local url cur

    case "${1-}" in
        --set)
            if [ -z "${2-}" ]; then echo "px: --set needs an address" >&2; return 1; fi
            url=$(_px_norm "$2")
            printf '%s\n' "$url" > "$PX_DIR/px-proxy.txt"
            echo "px: default proxy set to $url"
            return 0
            ;;
        "")
            echo "Usage: px <command> [args...]"
            echo "       px --set <addr>"
            if cur=$(_px_default); then echo "Default proxy: $cur"
            else echo "Default proxy: (not set)"; fi
            return 0
            ;;
        *)
            if ! url=$(_px_default); then
                echo "px: no proxy configured, run: px --set <addr>" >&2
                return 1
            fi
            ;;
    esac

    url=$(_px_wsl_fix "$url")

    HTTP_PROXY="$url" HTTPS_PROXY="$url" ALL_PROXY="$url" \
    http_proxy="$url" https_proxy="$url" all_proxy="$url" \
    NO_PROXY="localhost,127.0.0.1,::1" no_proxy="localhost,127.0.0.1,::1" \
    "$@"
}

px-status() {
    local url code
    if [ -n "${1-}" ]; then
        url=$(_px_norm "$1")
    else
        if ! url=$(_px_default); then
            echo "px: no proxy configured, run: px --set <addr>" >&2
            return 1
        fi
    fi
    url=$(_px_wsl_fix "$url")
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -x "$url" https://github.com 2>/dev/null)
    rc=$?
    if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
        echo "px: proxy OK (HTTP $code) -> $url"
    else
        echo "px: proxy NOT reachable -> $url (curl exit $rc, http=$code)"
    fi
}
