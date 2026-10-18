#!/bin/bash
# lib/firewall.sh — Firewall port management utilities
#
# Provides ensure_firewall_open() for any script that starts network services.
# Extracted from bin/watchtower.sh for reuse by T-885 service registry.
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/firewall.sh"
#   ensure_firewall_open 3000

[[ -n "${_FW_FIREWALL_LOADED:-}" ]] && return 0
_FW_FIREWALL_LOADED=1

# Requires colors from paths.sh or standalone usage
: "${GREEN:=}" "${YELLOW:=}" "${NC:=}"

_fw_log_info()  { echo -e "${GREEN}[firewall]${NC} $*"; }
_fw_log_warn()  { echo -e "${YELLOW}[firewall]${NC} $*"; }

# _fw_host_is_loopback HOST — true for 127.x, localhost, ::1 (and their bracketed forms).
_fw_host_is_loopback() {
    case "${1:-}" in
        127.*|localhost|::1|"[::1]") return 0 ;;
        *) return 1 ;;
    esac
}

# ensure_firewall_open PORT [COMMENT] [BIND_HOST]
# T-4297: changing the host firewall is the operator's decision, not a side effect.
#   - BIND_HOST is loopback: nothing to open, return without touching UFW.
#   - otherwise: open the port only when the operator opted in
#     (FW_WATCHTOWER_OPEN_FIREWALL=1, config WATCHTOWER_OPEN_FIREWALL); without it,
#     print the exact ufw command and change nothing.
# No-op if UFW is not installed or inactive, or the port is already allowed.
ensure_firewall_open() {
    local port="$1"
    local comment="${2:-Agentic Framework}"
    local bind_host="${3:-}"

    if [ -n "$bind_host" ] && _fw_host_is_loopback "$bind_host"; then
        return 0
    fi

    # Skip if ufw is not installed
    if ! command -v ufw >/dev/null 2>&1; then
        return 0
    fi
    # Skip if ufw is inactive
    if ! ufw status 2>/dev/null | grep -q "Status: active"; then
        return 0
    fi
    # Check if port is already allowed
    if ufw status 2>/dev/null | grep -qE "^${port}/tcp\s+ALLOW"; then
        _fw_log_info "Port $port already open."
        return 0
    fi
    if [ "${FW_WATCHTOWER_OPEN_FIREWALL:-0}" != "1" ]; then
        _fw_log_warn "UFW is active and port $port/tcp is not allowed, so LAN clients may be blocked."
        _fw_log_warn "  Not changing the firewall without consent. To allow it yourself:"
        _fw_log_warn "    sudo ufw allow $port/tcp comment '$comment'"
        _fw_log_warn "  Or let fw do it on start: fw config set WATCHTOWER_OPEN_FIREWALL 1"
        return 0
    fi
    # Open the port (operator opted in)
    _fw_log_info "Opening port $port/tcp (UFW policy is DROP; WATCHTOWER_OPEN_FIREWALL=1)..."
    if ufw allow "$port/tcp" comment "$comment" >/dev/null 2>&1; then
        _fw_log_info "Port $port opened for LAN access."
    else
        _fw_log_warn "Failed to open port $port — LAN access may be blocked."
    fi
}
