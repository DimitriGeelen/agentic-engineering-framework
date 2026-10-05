#!/usr/bin/env bash
# T-3779: TERMLINK_RUNTIME_DIR split-brain.
#
# TermLink keeps its hub socket and session registry in a runtime dir:
# $TERMLINK_RUNTIME_DIR, or /tmp/termlink-$UID when unset. The canonical hub
# on a host can live elsewhere (here: /var/lib/termlink). A launcher that
# starts an agent under `env -i` drops the variable, so the agent's
# `termlink register` lands in /tmp/termlink-$UID where no hub listens — peers
# cannot discover it and peer mail is never typed into it. Seen live after the
# 2026-10-05 reboot: 27 fleet sessions, AEF's included.
#
# fw_termlink_runtime_resolve
#   Prints ONE line "<verdict> <dir> <reason>" and returns 0; changes nothing
#   (callers act on the verdict — claude-fw exports, doctor WARNs). Verdicts:
#     set        TERMLINK_RUNTIME_DIR already set — left alone
#     default    unset, and the default dir has a live hub — nothing to do
#     supplied   unset, default dir has no hub, exactly one known hub dir is
#                live: <dir> is the dir to use
#     none       unset, and no live hub anywhere we know — nothing to choose
#     ambiguous  unset, several live hub dirs — refuse to guess
# Known hub dirs: $TERMLINK_RUNTIME_DIR_FALLBACK (space-separated), else
# /var/lib/termlink. Tests override the default dir via
# FW_TERMLINK_DEFAULT_RUNTIME_DIR.

fw_termlink_hub_live() {   # fw_termlink_hub_live <dir>  → 0 when a hub answers there
    local d="$1" pid
    [ -S "$d/hub.sock" ] || return 1
    pid=$(cat "$d/hub.pid" 2>/dev/null) || return 1
    case "$pid" in ''|*[!0-9]*) return 1 ;; esac
    kill -0 "$pid" 2>/dev/null
}

# fw_termlink_doctor_line
#   Prints a doctor finding ("WARN <text>") when this process — or the
#   TermLink session it runs in ($TERMLINK_SESSION_ID) — is on a runtime dir
#   with no live hub while a live hub exists in a known dir; prints nothing
#   when consistent. The session check matters: an agent's own environment can
#   carry the variable while the `termlink register` that owns its session was
#   started without it (AEF, 2026-10-05).
fw_termlink_doctor_line() {
    local v dir rest
    v=$(fw_termlink_runtime_resolve)
    case "$v" in
        supplied\ *)
            rest=${v#supplied }; dir=${rest%% *}
            echo "WARN TermLink split-brain: TERMLINK_RUNTIME_DIR is unset and the default dir has no hub; the live hub is in $dir — export TERMLINK_RUNTIME_DIR=$dir and restart the session (T-3779)"
            return 0 ;;
    esac
    local sid="${TERMLINK_SESSION_ID:-}"
    [ -n "$sid" ] || return 0
    local here="${TERMLINK_RUNTIME_DIR:-${FW_TERMLINK_DEFAULT_RUNTIME_DIR:-/tmp/termlink-$(id -u)}}"
    [ -e "$here/sessions/$sid.json" ] && return 0
    local def="${FW_TERMLINK_DEFAULT_RUNTIME_DIR:-/tmp/termlink-$(id -u)}" c
    for c in $def ${TERMLINK_RUNTIME_DIR_FALLBACK:-/var/lib/termlink}; do
        [ "$c" = "$here" ] && continue
        if [ -e "$c/sessions/$sid.json" ] && ! fw_termlink_hub_live "$c" && fw_termlink_hub_live "$here"; then
            echo "WARN TermLink split-brain: this session ($sid) is registered in $c, where no hub listens; the hub is in $here — peers cannot discover it. Restart the session with TERMLINK_RUNTIME_DIR=$here (T-3779)"
            return 0
        fi
    done
    return 0
}

fw_termlink_runtime_resolve() {
    if [ -n "${TERMLINK_RUNTIME_DIR:-}" ]; then
        echo "set $TERMLINK_RUNTIME_DIR TERMLINK_RUNTIME_DIR is set"
        return 0
    fi
    local def="${FW_TERMLINK_DEFAULT_RUNTIME_DIR:-/tmp/termlink-$(id -u)}"
    if fw_termlink_hub_live "$def"; then
        echo "default $def hub is live in the default runtime dir"
        return 0
    fi
    local cands="${TERMLINK_RUNTIME_DIR_FALLBACK:-/var/lib/termlink}" c live=()
    for c in $cands; do
        [ "$c" = "$def" ] && continue
        fw_termlink_hub_live "$c" && live+=("$c")
    done
    case "${#live[@]}" in
        0) echo "none $def no live hub in the default dir or in: $cands" ;;
        1) echo "supplied ${live[0]} TERMLINK_RUNTIME_DIR was unset and $def has no hub" ;;
        *) echo "ambiguous $def live hubs in several dirs: ${live[*]} — set TERMLINK_RUNTIME_DIR" ;;
    esac
    return 0
}
