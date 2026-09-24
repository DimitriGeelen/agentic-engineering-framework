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

# fw_audit_timing_read_section_measurement <project_root> <section>
#
#   stdout : "SECONDS<TAB>TIMESTAMP<TAB>TIMED_OUT" on success (exit 0) —
#            TIMED_OUT is the literal string "true" or "false".
#   exit 1 : nothing usable for <section> anywhere in the ledger.
#
# T-3451: the ledger the two derivations below read
# (.context/audits/full-audit-timing.yaml) used to carry exactly one
# measurement per section — last_run.sections, written ONLY by a full,
# unscoped `fw audit`. The pre-push gate never runs a full audit; it runs
# `fw audit --section structure` on every push, and that scoped run never
# updated the ledger, so both derivations tracked a number that could be
# days stale relative to the cost they actually bound (measured: ledger said
# 268s, a clean scoped run right next to it took 325s — see T-3451 task).
#
# agents/audit/audit.sh now writes a second, continuously-updated block,
# `section_runs:`, from EVERY invocation (full or `--section`-scoped) that
# completes a section — see `_audit_record_section_run` there. Resolution
# order:
#   1. section_runs: entry named <section> — canonical from T-3451 onward.
#   2. last_run.sections: entry named <section>, timestamped with
#      last_run.timestamp and flagged with last_run.timed_out — the
#      pre-T-3451 shape, read only when (1) has nothing for <section>, so a
#      ledger written by an older audit.sh (or a section section_runs has
#      simply never recorded yet) still parses exactly as before.
fw_audit_timing_read_section_measurement() {
    local root="${1:-}" section="${2:-}"
    local ledger="$root/.context/audits/full-audit-timing.yaml"
    [ -n "$root" ] && [ -n "$section" ] && [ -f "$ledger" ] || return 1

    local hit
    hit=$(awk -v want="$section" '
        /^section_runs:/ { in_sr = 1; next }
        in_sr && /^[^[:space:]]/ { in_sr = 0 }
        in_sr && /^[[:space:]]*-[[:space:]]*name:/ {
            n = $0
            sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*"?/, "", n); sub(/"?[[:space:]]*$/, "", n)
            in_item = (n == want)
            if (in_item) { secs = ""; ts = ""; tout = "" }
            next
        }
        in_sr && in_item && /^[[:space:]]*seconds:[[:space:]]*[0-9]+[[:space:]]*$/ {
            s = $0; sub(/^[[:space:]]*seconds:[[:space:]]*/, "", s); sub(/[[:space:]]*$/, "", s); secs = s; next
        }
        in_sr && in_item && /^[[:space:]]*timestamp:/ {
            t = $0; sub(/^[[:space:]]*timestamp:[[:space:]]*"?/, "", t); sub(/"?[[:space:]]*$/, "", t); ts = t; next
        }
        in_sr && in_item && /^[[:space:]]*timed_out:[[:space:]]*(true|false)[[:space:]]*$/ {
            t = $0; sub(/^[[:space:]]*timed_out:[[:space:]]*/, "", t); sub(/[[:space:]]*$/, "", t); tout = t; next
        }
        END { if (secs != "") print secs "\t" ts "\t" (tout == "" ? "false" : tout) }
    ' "$ledger" 2>/dev/null)

    if [ -z "$hit" ]; then
        # Fallback: last_run.sections (pre-T-3451 shape) — same scan
        # fw_prepush_lock_wait_default always ran inline, extracted here
        # (T-3450) and now generalised to any <section> (T-3451).
        hit=$(awk -v want="$section" '
            /^last_run:/ { in_lr = 1; next }
            in_lr && /^[^[:space:]]/ { in_lr = 0 }
            in_lr && /^[[:space:]]*timestamp:/ {
                t = $0; sub(/^[[:space:]]*timestamp:[[:space:]]*"?/, "", t); sub(/"?[[:space:]]*$/, "", t); ts = t; next
            }
            in_lr && /^[[:space:]]*timed_out:[[:space:]]*(true|false)[[:space:]]*$/ {
                t = $0; sub(/^[[:space:]]*timed_out:[[:space:]]*/, "", t); sub(/[[:space:]]*$/, "", t); tout = t; next
            }
            in_lr && /^[[:space:]]*-[[:space:]]*name:/ {
                n = $0; sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*"?/, "", n); sub(/"?[[:space:]]*$/, "", n)
                in_item = (n == want); next
            }
            in_lr && in_item && /^[[:space:]]*seconds:[[:space:]]*[0-9]+[[:space:]]*$/ {
                s = $0; sub(/^[[:space:]]*seconds:[[:space:]]*/, "", s); sub(/[[:space:]]*$/, "", s); secs = s; next
            }
            END { if (secs != "") print secs "\t" ts "\t" (tout == "" ? "false" : tout) }
        ' "$ledger" 2>/dev/null)
    fi

    [ -n "$hit" ] || return 1
    printf '%s\n' "$hit"
}

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
# carrying its own awk script. T-3451: now backed by
# fw_audit_timing_read_section_measurement, so it also picks up a scoped
# `--section structure` run's own record — behaviour on an old-shape ledger
# is unchanged.
fw_audit_timing_read_structure_seconds() {
    local root="${1:-}"
    local hit measured
    hit=$(fw_audit_timing_read_section_measurement "$root" "structure") || return 1
    measured="${hit%%$'\t'*}"
    case "$measured" in
        ''|*[!0-9]*) return 1 ;;
    esac
    echo "$measured"
}

# fw_audit_timing_last_run_timed_out <project_root>
#
# Exit 0 when the run backing the CURRENT "structure" measurement (see
# fw_audit_timing_read_section_measurement's resolution order) is flagged
# timed_out: true; exit 1 otherwise (false, missing, or unreadable).
# fw_prepush_lock_wait_default does NOT consult this — its own pinned tests
# (t3421) assert it trusts the measured value even when timed_out: true.
# fw_handover_push_timeout_default does consult it; see that function's
# header for why the two differ.
#
# T-3451: previously a bare `grep timed_out: true` anywhere in the file,
# which only ever meant "the last FULL run" because that was the only
# place the key appeared. Now that section_runs: entries carry their own
# timed_out flag too, the naive grep would trip on an unrelated section's
# timeout — this reads the SAME resolved entry the seconds reader used.
fw_audit_timing_last_run_timed_out() {
    local root="${1:-}"
    local hit rest tout
    hit=$(fw_audit_timing_read_section_measurement "$root" "structure") || return 1
    rest="${hit#*$'\t'}"
    tout="${rest#*$'\t'}"
    [ "$tout" = "true" ]
}

# fw_audit_timing_last_measured_at <project_root> [section]
#
#   stdout : the ISO-8601 timestamp of the measurement
#            fw_audit_timing_read_section_measurement would resolve for
#            <section> (default "structure"), on success (exit 0).
#   exit 1 : no usable measurement (see fw_audit_timing_read_section_measurement).
#
# T-3451 AC2: staleness needs a number to compare against "now" — this is
# that number. Used by `fw doctor`'s structure-timing-staleness WARN.
fw_audit_timing_last_measured_at() {
    local root="${1:-}" section="${2:-structure}"
    local hit rest ts
    hit=$(fw_audit_timing_read_section_measurement "$root" "$section") || return 1
    rest="${hit#*$'\t'}"
    ts="${rest%%$'\t'*}"
    [ -n "$ts" ] || return 1
    printf '%s\n' "$ts"
}

# fw_audit_timing_is_stale <project_root> [section] [days]
#
# Exit 0 (stale) when the resolved measurement for <section> (default
# "structure") is missing entirely, or its timestamp is unparseable, or its
# age in whole days is >= <days> (default 7, overridable via
# FW_STRUCTURE_TIMING_STALE_DAYS through the caller). Exit 1 (fresh)
# otherwise. "Missing" counts as stale rather than being a separate
# tri-state — a gate that has never been measured deserves the same WARN as
# one measured too long ago; `fw doctor` distinguishes "never measured" in
# its own message text by checking fw_audit_timing_last_measured_at
# directly when it wants that distinction.
fw_audit_timing_is_stale() {
    local root="${1:-}" section="${2:-structure}" days="${3:-7}"
    local ts ts_epoch now_epoch age_days
    ts=$(fw_audit_timing_last_measured_at "$root" "$section") || return 0
    ts_epoch=$(date -d "$ts" +%s 2>/dev/null) || return 0
    now_epoch=$(date +%s)
    age_days=$(( (now_epoch - ts_epoch) / 86400 ))
    [ "$age_days" -ge "$days" ]
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
