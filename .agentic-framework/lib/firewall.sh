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

# ensure_firewall_open PORT [COMMENT]
# Opens a UFW port for TCP traffic if UFW is active and the port isn't already allowed.
# No-op if UFW is not installed or inactive.
ensure_firewall_open() {
    local port="$1"
    local comment="${2:-Agentic Framework}"

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
    # Open the port
    _fw_log_info "Opening port $port/tcp (UFW policy is DROP)..."
    if ufw allow "$port/tcp" comment "$comment" >/dev/null 2>&1; then
        _fw_log_info "Port $port opened for LAN access."
    else
        _fw_log_warn "Failed to open port $port — LAN access may be blocked."
    fi
}
