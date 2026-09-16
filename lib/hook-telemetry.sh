#!/usr/bin/env bash
# lib/hook-telemetry.sh — per-hook fire / failure counters (T-1628, B-2 of T-1626).
#
# Records every Claude Code hook invocation to flat `name=count` files so the
# threshold-escalation work in B-3 (T-1629) and `fw doctor` have observable
# signal that "non-blocking" hook failures are happening. Without this, hook
# breakage is invisible — see T-1626 inception (witness: ring20-dashboard
# 2026-04-30, dozens of `PostToolUse:Edit hook error / .agentic-framework/bin/fw:
# not found` flowed past while every framework health surface reported clean).
#
# Files (in $PROJECT_ROOT/.context/working/):
#   .hook-counter            — per-hook fire count, one `<hookname>=<count>` line
#   .hook-failure-counter    — per-hook non-zero-exit count, same format
#
# Performance budget: <5ms per fire (per T-1626 constraint). Achieved by a
# single awk subprocess per file with a small (typically <20-line) input.
# All errors are swallowed — telemetry must NEVER block a hook from running.

# fw_record_hook_fire <hookname> <exit_code>
#   Increment the per-hook fire counter. If exit_code != 0, also increment the
#   per-hook failure counter. Silent on all errors (telemetry never blocks).
fw_record_hook_fire() {
    local hookname="${1:-unknown}"
    local exit_code="${2:-0}"
    local working_dir="${PROJECT_ROOT:-.}/.context/working"
    [ -d "$working_dir" ] || return 0
    _fw_telemetry_increment "$working_dir/.hook-counter" "$hookname" 2>/dev/null || true
    if [ "$exit_code" != "0" ]; then
        _fw_telemetry_increment "$working_dir/.hook-failure-counter" "$hookname" 2>/dev/null || true
    fi
    return 0
}

# _fw_telemetry_increment <file> <key>
#   Read-modify-write of a flat `key=count\n` file, serialized by flock.
#
#   T-3371 (OBS-417): this was lock-free until 2026-09-16. The read-modify-write
#   (mapfile → edit array → `printf > file`) is not atomic, so two hooks firing
#   concurrently both read, both write, and the LAST WRITER WINS WITH ITS OWN
#   STALE VIEW — silently discarding every key it had not read. Measured with
#   this repo's own function, 8 processes x 200 increments: 1600 expected,
#   **17 recorded** (98.9% lost), 5 of 8 keys gone from the file entirely, plus
#   a duplicate key. The live `.hook-counter` carried exactly that damage: two
#   `budget-gate` lines (one live, one shadowed corpse) and a blank line.
#
#   Why that mattered more than a wrong number: `fw doctor` and the T-1629
#   hook-threshold escalation both read this file. An instrument that loses ~99%
#   of its signal under load reads identically to a quiet, healthy system — so
#   hook-failure escalation silently under-reports precisely when concurrency
#   (i.e. dispatched workers) makes hook breakage most likely. It also produced
#   a false alarm of its own: a clobbered snapshot listing only `Bash`-matched
#   hooks was read as evidence that write-time gates were not firing at all.
#
#   Cost: flock adds ~1.7ms, measured 2.3ms/fire total against the 5ms budget
#   above (200 fires, 20-key file). The budget is why this was written lock-free;
#   it is not why it should stay wrong. flock needs no stale-lock handling — the
#   kernel releases on fd close or process death.
#
#   Degrade-to-allow (L-331): if flock is unavailable or the lock cannot be taken
#   within FW_TELEMETRY_LOCK_WAIT seconds, the increment proceeds UNLOCKED rather
#   than failing or hanging. Telemetry must never block a hook — a lossy counter
#   is bad, a wedged gate is worse.
_fw_telemetry_increment() {
    local file="$1"
    local key="$2"
    local lockfd=""

    # Probe flock once per shell, not per fire.
    if [ -z "${_FW_TELEMETRY_HAS_FLOCK:-}" ]; then
        if command -v flock >/dev/null 2>&1; then
            _FW_TELEMETRY_HAS_FLOCK=1
        else
            _FW_TELEMETRY_HAS_FLOCK=0
        fi
    fi

    if [ "$_FW_TELEMETRY_HAS_FLOCK" = "1" ]; then
        # `>>` never truncates, so the lock file is safe to share and safe to
        # leave behind. Auto-assigned fd avoids colliding with a caller's fds.
        if exec {lockfd}>>"${file}.lock" 2>/dev/null; then
            flock -w "${FW_TELEMETRY_LOCK_WAIT:-2}" "$lockfd" 2>/dev/null || true
        fi
    fi

    _fw_telemetry_rmw "$file" "$key"

    [ -n "$lockfd" ] && exec {lockfd}>&- 2>/dev/null
    return 0
}

# _fw_telemetry_rmw <file> <key>
#   The read-modify-write itself. Assumes the caller holds the lock (or has
#   decided to proceed without one). Also self-heals the two corruption shapes
#   the pre-T-3371 race left behind: a blank line, and a shadowed duplicate key
#   that the old first-match-wins loop would increment forever while orphaning
#   the rest. First occurrence of a key wins — deliberately NOT a sum, which
#   would inflate the live count by folding in a stale corpse.
_fw_telemetry_rmw() {
    local file="$1"
    local key="$2"
    local -a lines out
    local i k v
    local found=0

    if [ ! -f "$file" ]; then
        printf '%s=1\n' "$key" > "$file"
        return 0
    fi

    mapfile -t lines < "$file"
    local -A seen 2>/dev/null || true
    for i in "${!lines[@]}"; do
        [ -z "${lines[i]}" ] && continue                 # drop blank lines
        k="${lines[i]%%=*}"
        v="${lines[i]#*=}"
        [ "$k" = "${lines[i]}" ] && continue             # no '=' — malformed
        [ -z "$k" ] && continue                          # empty key
        [ -n "${seen[$k]:-}" ] && continue               # shadowed duplicate
        seen[$k]=1
        case "$v" in ''|*[!0-9]*) v=0 ;; esac            # non-numeric → 0
        if [ "$k" = "$key" ]; then
            v=$((v + 1))
            found=1
        fi
        out+=("$k=$v")
    done
    [ "$found" = "0" ] && out+=("$key=1")
    printf '%s\n' "${out[@]}" > "$file"
}

# fw_hook_counter_get <kind> <hookname>
#   kind: fires|failures
#   Prints the current count for one hook, or "0" if absent. Used by B-3
#   (threshold escalation) and `fw doctor`. Read-only; safe in hot paths.
fw_hook_counter_get() {
    local kind="$1"
    local hookname="$2"
    local working_dir="${PROJECT_ROOT:-.}/.context/working"
    local file
    case "$kind" in
        fires)    file="$working_dir/.hook-counter" ;;
        failures) file="$working_dir/.hook-failure-counter" ;;
        *)        echo 0; return 0 ;;
    esac
    [ -f "$file" ] || { echo 0; return 0; }
    awk -v k="$hookname" -F= '$1==k {print $2; found=1; exit} END {if (!found) print 0}' "$file"
}
