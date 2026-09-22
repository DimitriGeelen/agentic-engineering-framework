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

fw_prepush_lock_wait_default() {
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
        ''|*[!0-9]*)
            echo "$FW_PREPUSH_LOCK_WAIT_FALLBACK"
            return 0
            ;;
    esac

    # ceil(measured * 1.25) in integer arithmetic: (5m + 3) / 4
    local wait=$(( (measured * 5 + 3) / 4 ))
    [ "$wait" -lt "$FW_PREPUSH_LOCK_WAIT_FLOOR" ] && wait=$FW_PREPUSH_LOCK_WAIT_FLOOR
    [ "$wait" -gt "$FW_PREPUSH_LOCK_WAIT_CAP" ] && wait=$FW_PREPUSH_LOCK_WAIT_CAP
    echo "$wait"
}
