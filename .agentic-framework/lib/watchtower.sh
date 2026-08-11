#!/bin/bash
# lib/watchtower.sh — Shared Watchtower URL detection and browser-open helper (T-974, T-1154)
#
# Centralizes port detection, host detection, and browser opening so that
# ALL scripts use the same logic. Eliminates hardcoded ports and duplicated
# browser-open code.
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/watchtower.sh"
#   url=$(_watchtower_url T-XXX)                    # get base URL with correct port
#   _watchtower_open "http://host:port/path"         # open in browser (desktop-user aware)
#
# Requires: PROJECT_ROOT (from paths.sh chain), config.sh for fw_config

# Source config for PORT setting (guard protects double-source)
source "${FRAMEWORK_ROOT:-.}/lib/config.sh"

[[ -n "${_FW_WATCHTOWER_LOADED:-}" ]] && return 0
_FW_WATCHTOWER_LOADED=1

# _watchtower_identity_matches URL
#
# Returns 0 iff the service at URL identifies (via /api/_identity) as THIS
# project's Watchtower: service=="watchtower" AND project_root==our root
# (PROJECT_ROOT, else FRAMEWORK_ROOT). Single source of truth for the identity
# handshake used by both the reader (_watchtower_url) and the writer
# (bin/watchtower.sh's port-kill guard + triple-write gate). T-1803.
_watchtower_identity_matches() {
    local _u="$1"
    local _our_root="${PROJECT_ROOT:-${FRAMEWORK_ROOT:-}}"
    local _json _svc _proot
    _json=$(curl -sf --max-time 2 "${_u}/api/_identity" 2>/dev/null) || return 1
    _svc=$(printf '%s' "$_json" | grep -oE '"service"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')
    _proot=$(printf '%s' "$_json" | grep -oE '"project_root"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')
    [ "$_svc" = "watchtower" ] && [ -n "$_our_root" ] && [ "$_proot" = "$_our_root" ]
}

# _watchtower_port_holder_is_ours PORT
#
# Returns 0 iff the service listening on localhost:PORT identifies as THIS
# project's Watchtower. The launcher uses this to tell its own stale instance
# (safe to recycle) from a FOREIGN service that happens to hold the port (must
# NOT be killed — the T-1802 wrong-dashboard / neighbor-kill hazard). A holder
# that does not answer /api/_identity as ours is treated as foreign. T-1803.
_watchtower_port_holder_is_ours() {
    local _port="$1"
    [ -n "$_port" ] || return 1
    _watchtower_identity_matches "http://localhost:${_port}"
}

# _watchtower_url [TASK_ID]
#
# Returns the base Watchtower URL (e.g., http://192.168.10.107:3000) on stdout.
#
# T-1284 / T-1290 3-layer discovery (replaces the port-probe fallback that
# accidentally matched any service returning 200, e.g. Open WebUI on :8080):
#
#   Fast path — WATCHTOWER_URL env override
#   Layer 1  — authoritative triple (.pid/.port/.url) written by watchtower.sh
#              at startup. Verify pid alive AND pid listens on that port, then
#              return .url verbatim. No probing.
#   Layer 2  — identity handshake. For the configured port, call
#              /api/_identity and match only when service=="watchtower" AND
#              project_root equals ours. No task-path heuristics.
#   Layer 3  — fail loud. Exit 1 with actionable stderr message. Never return
#              a URL to a service we didn't positively identify.
#
# TASK_ID is accepted for signature compatibility but no longer used for
# probing — identity replaces it.
_watchtower_url() {
    local task_id="${1:-}"  # kept for signature compat; not used for probing

    # Fast path: explicit env override
    if [ -n "${WATCHTOWER_URL:-}" ]; then
        echo "$WATCHTOWER_URL"
        return 0
    fi

    local _our_root="${PROJECT_ROOT:-${FRAMEWORK_ROOT:-}}"

    # Helper: verify a url is OUR Watchtower via /api/_identity. Returns 0 iff
    # match. Delegates to the top-level _watchtower_identity_matches (T-1803) so
    # reader and writer share one identity-handshake implementation.
    _wt_identity_matches() { _watchtower_identity_matches "$1"; }

    # -----------------------------------------------------------------
    # Layer 1 — authoritative triple (.pid/.port/.url), verified by identity
    # -----------------------------------------------------------------
    local triple_dirs=(
        "$PROJECT_ROOT/.context/working"
        "${FRAMEWORK_ROOT:-}/.context/working"
    )
    local _dir
    for _dir in "${triple_dirs[@]}"; do
        [ -z "$_dir" ] && continue
        local _pf="$_dir/watchtower.pid"
        local _uf="$_dir/watchtower.url"
        [ -f "$_pf" ] && [ -f "$_uf" ] || continue

        local _pid _url
        _pid=$(cat "$_pf" 2>/dev/null | tr -d '[:space:]')
        _url=$(cat "$_uf" 2>/dev/null | tr -d '[:space:]')
        [ -n "$_pid" ] && [ -n "$_url" ] || continue

        # Verify process is alive (cheap kernel check)
        kill -0 "$_pid" 2>/dev/null || continue

        # Verify identity (confirms the url actually IS our Watchtower,
        # not a masquerader that happened to bind the same port after restart)
        if _wt_identity_matches "$_url"; then
            echo "$_url"
            return 0
        fi
    done

    # -----------------------------------------------------------------
    # Layer 2 — identity handshake on configured port (triple absent/stale)
    # -----------------------------------------------------------------
    local _cfg_port
    _cfg_port=$(fw_config "PORT" 3000 2>/dev/null || echo 3000)

    local _host
    _host=$(hostname -I 2>/dev/null | awk '{print $1}')
    _host="${_host:-localhost}"

    local _probe_host
    for _probe_host in "localhost" "$_host" ; do
        [ -z "$_probe_host" ] && continue
        local _try_url="http://${_probe_host}:${_cfg_port}"
        if _wt_identity_matches "$_try_url"; then
            # Prefer LAN host in returned url for external callers
            if [ -n "$_host" ] && [ "$_host" != "localhost" ]; then
                echo "http://${_host}:${_cfg_port}"
            else
                echo "$_try_url"
            fi
            return 0
        fi
    done

    # -----------------------------------------------------------------
    # Layer 3 — fail loud (no silent wrong answer)
    # -----------------------------------------------------------------
    echo "No Watchtower reachable for project: ${_our_root:-(unknown)}" >&2
    echo "  Start one with: fw serve" >&2
    echo "  Or set WATCHTOWER_URL explicitly." >&2
    return 1
}

# _watchtower_base_or_placeholder [TASK_ID]
#
# T-2922. Same question as _watchtower_url — "what is this project's Watchtower
# base URL?" — for the callers that must keep going when the answer is "there
# isn't one running yet". _watchtower_url fails loud by design (Layer 3, exit 1,
# no stdout) so callers needing a LIVE server can detect it; under `set -e` a
# bare `x=$(_watchtower_url)` assignment aborts the caller outright. For
# emit_review that abort happened BEFORE the `.reviewed-<id>` marker write —
# the only unblock for `fw inception decide` — so on a fresh `fw init` project,
# where nothing has yet told the user to run `fw serve`, the first inception was
# uncompletable by any path.
#
# Answers on stdout in BOTH cases and distinguishes them by EXIT CODE, never by
# output shape:
#
#   0 — live and identity-verified (delegates to _watchtower_url verbatim)
#   2 — no Watchtower reachable. stdout is a WOULD-BE base URL built from the
#       configured port: correct the moment `fw serve` runs, wrong to treat as
#       reachable now.
#
# Two distinct non-empty answers rather than "empty means down", because an
# empty base silently concatenates into "/review/T-XXX" — a broken relative path
# that looks like a link. A caller that ignores the exit code gets a URL that is
# merely premature; a caller that reads it gets the truth. (L-578: a check that
# can only answer yes/no cannot say which question it answered — so the third
# state gets its own code, not a sentinel value the caller may not notice.)
#
# This lives here, not in the callers, because lib/watchtower.sh is the single
# source of port resolution (T-974, T-1154) and T-1155's invariant suite pins
# that: `fw_config "PORT" 3000` inline in lib/review.sh or lib/verify-acs.sh is
# structurally RED. The placeholder needs the configured port, so the
# placeholder belongs on this side of that line.
_watchtower_base_or_placeholder() {
    local _live
    if _live=$(_watchtower_url "${1:-}"); then
        printf '%s\n' "$_live"
        return 0
    fi

    # Not reachable. Build the would-be URL from the same configured port
    # Layer 2 probes, so the printed link matches where `fw serve` will bind.
    local _port
    _port=$(fw_config "PORT" 3000 2>/dev/null || echo 3000)
    printf 'http://localhost:%s\n' "${_port:-3000}"
    return 2
}

# fw_task_review_url TASK_ID [TASK_FILE]
#
# T-2438: single source of the class-correct Watchtower review URL. Mirrors the
# routing emit_review applies inline (lib/review.sh) so the two paths can't
# diverge (the t2247-class staleness lesson):
#   workflow_type == inception → <base>/inception/<id>
#   otherwise (build/refactor/test/…) → <base>/review/<id>
#
# Echoes the full URL on success. When the Watchtower base can't be resolved
# (down / unidentifiable), echoes nothing and returns 1 — callers then pass no
# click_url rather than a broken link. TASK_FILE is a hint; falls back to
# active/ then completed/ discovery (same as emit_review).
fw_task_review_url() {
    local task_id="${1:-}"
    local task_file="${2:-}"
    [ -n "$task_id" ] || return 1

    local base_url
    base_url=$(_watchtower_url "$task_id" 2>/dev/null) || return 1
    [ -n "$base_url" ] || return 1

    if [ -z "$task_file" ] || [ ! -f "$task_file" ]; then
        task_file=""
        local f
        for f in "$PROJECT_ROOT/.tasks/active/$task_id"*.md "$PROJECT_ROOT/.tasks/completed/$task_id"*.md; do
            [ -f "$f" ] && { task_file="$f"; break; }
        done
    fi

    local workflow_type=""
    if [ -n "$task_file" ] && [ -f "$task_file" ]; then
        workflow_type=$(grep -m1 'workflow_type:' "$task_file" 2>/dev/null | sed 's/.*workflow_type:[[:space:]]*//' | tr -d '[:space:]')
    fi

    if [ "$workflow_type" = "inception" ]; then
        echo "${base_url}/inception/${task_id}"
    else
        echo "${base_url}/review/${task_id}"
    fi
    return 0
}

# _watchtower_open URL
#
# Opens a URL in the default browser. When running as root (agent context),
# detects the desktop user and uses sudo to avoid Chromium's --no-sandbox error.
# Non-blocking, fail-silent — never blocks the calling script.
_watchtower_open() {
    local url="${1:-}"
    [ -z "$url" ] && return 1

    local _browser_opened=false

    # When running as root, open as the desktop user
    if [ "$(id -u)" = "0" ]; then
        local _desktop_user _desktop_uid
        _desktop_user=$(who 2>/dev/null | grep 'tty[0-9].*(:' | head -1 | awk '{print $1}')
        if [ -n "$_desktop_user" ]; then
            _desktop_uid=$(id -u "$_desktop_user" 2>/dev/null)
            if [ -n "$_desktop_uid" ]; then
                sudo -u "$_desktop_user" \
                    DISPLAY=:0 \
                    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${_desktop_uid}/bus" \
                    xdg-open "$url" >/dev/null 2>&1 &
                _browser_opened=true
            fi
        fi
    fi

    if ! $_browser_opened; then
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$url" >/dev/null 2>&1 &
        elif command -v open >/dev/null 2>&1; then
            open "$url" >/dev/null 2>&1 &
        fi
    fi
}
