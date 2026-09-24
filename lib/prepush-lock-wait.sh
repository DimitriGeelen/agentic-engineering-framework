#!/usr/bin/env bash
# lib/prepush-lock-wait.sh — T-3421: derive the pre-push audit-lock wait from
# the measured audit, instead of asserting it.
#
# T-3297 gave the pre-push gate a bounded wait for the audit lock, default 90s,
# on the premise that the contended audit "finishes within a minute or two".
# The framework's own timing ledger (.context/audits/full-audit-timing.yaml,
# T-3127) measures `--section structure` — the very section the gate runs —
# at ~292s. A 90s wait therefore expires before the audit it waits for can
# finish, so every contended push fails, and its retry re-runs a fresh 292s
# audit that holds the lock against everyone else. Measured 2026-09-22 with
# five concurrent writers: 10 + 8 + 25 lock hits across three pushers in one
# morning.
#
#   fw_prepush_lock_wait_default <project_root>
#
#     stdout : an integer number of seconds
#     rule   : ceil(1.25 x last measured `structure` seconds), clamped to
#              [90, 600]; 360 when the ledger is absent, unreadable, or has
#              no numeric `structure` entry.
#
# The floor keeps T-3297's original default as the minimum; the cap keeps a
# runaway measurement (a timed-out audit records total >= ceiling) from
# turning the gate into an indefinite hang. 1.25 covers the run-to-run spread
# in the ledger. An explicit FW_PREPUSH_LOCK_WAIT still overrides this in
# hooks.sh — this function only supplies the default.

FW_PREPUSH_LOCK_WAIT_FLOOR=90
FW_PREPUSH_LOCK_WAIT_CAP=600
FW_PREPUSH_LOCK_WAIT_FALLBACK=360

# fw_audit_timing_read_structure_seconds <project_root>
#
#   stdout : the last measured "structure" section seconds as a bare
#            integer, on success (exit 0).
#   exit 1 : ledger missing, unreadable, or has no numeric structure entry —
#            nothing is printed. Callers decide their own fallback.
#
# T-3450: extracted from fw_prepush_lock_wait_default (below) so it and
# fw_handover_push_timeout_default (lib/prepush-lock-wait.sh, same file)
# parse the ledger's on-disk shape in exactly one place rather than each
# carrying its own awk script. Behaviour is unchanged — this is the same
# scan fw_prepush_lock_wait_default always ran inline.
fw_audit_timing_read_structure_seconds() {
    local root="${1:-}"
    local ledger="$root/.context/audits/full-audit-timing.yaml"
    local measured=""

    if [ -n "$root" ] && [ -f "$ledger" ]; then
        # The ledger lists sections as
        #     - name: "structure"
        #       seconds: 292
        # Take the `seconds:` line that follows the structure entry.
        measured=$(awk '
            /^[[:space:]]*-[[:space:]]*name:[[:space:]]*"?structure"?[[:space:]]*$/ { want = 1; next }
            want && /^[[:space:]]*seconds:[[:space:]]*[0-9]+[[:space:]]*$/ {
                sub(/^[[:space:]]*seconds:[[:space:]]*/, ""); sub(/[[:space:]]*$/, "");
                print; exit
            }
            want && /^[[:space:]]*-[[:space:]]*name:/ { want = 0 }
        ' "$ledger" 2>/dev/null)
    fi

    case "$measured" in
        ''|*[!0-9]*) return 1 ;;
    esac
    echo "$measured"
}

# fw_audit_timing_last_run_timed_out <project_root>
#
# Exit 0 when the ledger's last_run.timed_out is literally `true`; exit 1
# otherwise (false, missing, or unreadable). fw_prepush_lock_wait_default
# does NOT consult this — its own pinned tests (t3421) assert it trusts the
# measured value even when timed_out: true. fw_handover_push_timeout_default
# does consult it; see that function's header for why the two differ.
fw_audit_timing_last_run_timed_out() {
    local root="${1:-}"
    local ledger="$root/.context/audits/full-audit-timing.yaml"
    [ -n "$root" ] && [ -f "$ledger" ] || return 1
    grep -qE '^[[:space:]]*timed_out:[[:space:]]*true[[:space:]]*$' "$ledger" 2>/dev/null
}

fw_prepush_lock_wait_default() {
    local root="${1:-}"
    local measured

    measured=$(fw_audit_timing_read_structure_seconds "$root") || {
        echo "$FW_PREPUSH_LOCK_WAIT_FALLBACK"
        return 0
    }

    # ceil(measured * 1.25) in integer arithmetic: (5m + 3) / 4
    local wait=$(( (measured * 5 + 3) / 4 ))
    [ "$wait" -lt "$FW_PREPUSH_LOCK_WAIT_FLOOR" ] && wait=$FW_PREPUSH_LOCK_WAIT_FLOOR
    [ "$wait" -gt "$FW_PREPUSH_LOCK_WAIT_CAP" ] && wait=$FW_PREPUSH_LOCK_WAIT_CAP
    echo "$wait"
}

# fw_handover_push_timeout_default <project_root>
#
# T-3450: derive agents/handover/handover.sh's push timeout
# (FW_HANDOVER_PUSH_TIMEOUT) from the same ledger fw_prepush_lock_wait_default
# reads, instead of a static 300 — the number that was ~241s of headroom
# above the gate at T-3062 and is 32s of headroom today (gate now 268s).
#
# The push timeout bounds `gate + network`, and it has to sit ABOVE the lock
# wait (`gate` alone, via fw_prepush_lock_wait_default) or a push can die
# waiting for a lock it was about to win. This derivation uses knobs that are
# each strictly larger than fw_prepush_lock_wait_default's, applied to the
# SAME measured seconds: multiplier 1.5 (vs 1.25), floor 180s (vs 90s), cap
# 900s (vs 600s). Because every knob is larger, the clamped result here
# dominates fw_prepush_lock_wait_default's clamped result at every measured
# value on the normal path — proved by construction, pinned by
# tests/unit/handover_push_timeout.bats.
#
# The one place that isn't true by construction is the fallback: unlike
# fw_prepush_lock_wait_default, this function treats a timed_out: true
# ledger as untrustworthy and falls back rather than computing from it — the
# lock-wait number only bounds a wait for a lock someone else holds, but
# this number is what stands between a real push and an indefinite hang, so
# an unreliable measurement should not shape it (this is also why the
# fallback constant below is 650, not a value scaled from 360 the way the
# multiplier/floor/cap are scaled from lock-wait's: 650 exceeds
# FW_PREPUSH_LOCK_WAIT_CAP (600), so even when this function falls back
# while fw_prepush_lock_wait_default does not (a timed-out ledger with a
# large measured value), the dominance property still holds).
#
#   stdout : an integer number of seconds
FW_PUSH_TIMEOUT_FLOOR=180
FW_PUSH_TIMEOUT_CAP=900
FW_PUSH_TIMEOUT_FALLBACK=650

fw_handover_push_timeout_default() {
    local root="${1:-}"
    local measured budget

    if fw_audit_timing_last_run_timed_out "$root"; then
        echo "$FW_PUSH_TIMEOUT_FALLBACK"
        return 0
    fi

    measured=$(fw_audit_timing_read_structure_seconds "$root") || {
        echo "$FW_PUSH_TIMEOUT_FALLBACK"
        return 0
    }

    # ceil(measured * 1.5) in integer arithmetic: (3m + 1) / 2
    budget=$(( (measured * 3 + 1) / 2 ))
    [ "$budget" -lt "$FW_PUSH_TIMEOUT_FLOOR" ] && budget=$FW_PUSH_TIMEOUT_FLOOR
    [ "$budget" -gt "$FW_PUSH_TIMEOUT_CAP" ] && budget=$FW_PUSH_TIMEOUT_CAP
    echo "$budget"
}
