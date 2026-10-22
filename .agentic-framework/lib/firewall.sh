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

# ensure_firewall_open PORT [COMMENT] [BIND_HOST] [STATE_FILE]
# T-4297: changing the host firewall is the operator's decision, not a side effect.
#   - BIND_HOST is loopback: nothing to open, return without touching UFW.
#   - otherwise: open the port only when the operator opted in
#     (FW_WATCHTOWER_OPEN_FIREWALL=1, config WATCHTOWER_OPEN_FIREWALL); without it,
#     print the exact ufw command and change nothing.
# No-op if UFW is inactive or the port is already allowed; if UFW is not installed,
# print one line saying no change was made (T-4330).
# T-4323: when STATE_FILE is given, a rule this call actually ADDED is recorded
# there (one PORT per line), so close_recorded_firewall_rules can later remove
# exactly that rule and nothing else. A rule that already existed is not recorded.
ensure_firewall_open() {
    local port="$1"
    local comment="${2:-Agentic Framework}"
    local bind_host="${3:-}"
    local state_file="${4:-}"

    if [ -n "$bind_host" ] && _fw_host_is_loopback "$bind_host"; then
        return 0
    fi

    # ufw not installed: change nothing, but say so (T-4330) — silence left the
    # operator not knowing whether the port is reachable.
    if ! command -v ufw >/dev/null 2>&1; then
        _fw_log_warn "ufw not installed: no firewall change made; make sure port $port is reachable from your LAN if you need it."
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
        if [ -n "$state_file" ] && ! grep -qx "$port" "$state_file" 2>/dev/null; then
            echo "$port" >> "$state_file" 2>/dev/null || true
        fi
    else
        _fw_log_warn "Failed to open port $port — LAN access may be blocked."
    fi
}

# close_recorded_firewall_rules STATE_FILE (T-4323)
# Delete the UFW rules ensure_firewall_open recorded in STATE_FILE — only those:
# a rule that is merely labelled like ours but was not recorded is never touched
# (fw doctor reports those instead). A delete that fails keeps its record and
# prints the exact command, so the next stop (or the operator) can retry.
close_recorded_firewall_rules() {
    local state_file="$1"
    [ -s "$state_file" ] || { rm -f "$state_file" 2>/dev/null; return 0; }
    command -v ufw >/dev/null 2>&1 || return 0
    local port keep=""
    while IFS= read -r port; do
        case "$port" in ''|*[!0-9]*) continue ;; esac
        if ufw delete allow "$port/tcp" >/dev/null 2>&1; then
            _fw_log_info "Removed the UFW rule Watchtower added for port $port/tcp."
        else
            _fw_log_warn "Could not remove the UFW rule Watchtower added for port $port/tcp. Remove it yourself:"
            _fw_log_warn "    sudo ufw delete allow $port/tcp"
            keep="${keep}${port}"$'\n'
        fi
    done < "$state_file"
    if [ -n "$keep" ]; then
        printf '%s' "$keep" > "$state_file"
    else
        rm -f "$state_file"
    fi
}

# firewall_orphan_rules (T-4323)
# Print, one per line, each port that has a framework-labelled UFW ALLOW rule
# (comment Agentic Framework / Watchtower / fw serve) but no TCP listener.
# Prints nothing when ufw or ss is missing, ufw is inactive or unreadable.
firewall_orphan_rules() {
    command -v ufw >/dev/null 2>&1 || return 0
    command -v ss >/dev/null 2>&1 || return 0
    local status
    status=$(ufw status 2>/dev/null) || return 0
    printf '%s\n' "$status" | grep -q "Status: active" || return 0
    local port
    printf '%s\n' "$status" \
        | grep -E '^[0-9]+/tcp( \(v6\))?[[:space:]]+ALLOW.*#.*(Agentic Framework|Watchtower|fw serve)' \
        | sed -E 's|^([0-9]+)/tcp.*|\1|' | sort -un \
        | while IFS= read -r port; do
            if [ -z "$(ss -Htln "sport = :$port" 2>/dev/null)" ]; then
                echo "$port"
            fi
        done
}
