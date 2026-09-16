#!/usr/bin/env bats
# T-3371 (OBS-417): the hook telemetry counter must not lose increments under
# concurrency.
#
# Origin: `_fw_telemetry_increment` was a lock-free read-modify-write. Two hooks
# firing at once both read, both write, last writer wins with its stale view.
# Measured before the fix with this repo's own function: 8 procs x 200 fires =
# 1600 expected, 17 recorded, 5 of 8 keys gone, one duplicate key.
#
# The control leg (test 2) is load-bearing: it runs the SAME assertions against a
# deliberately lock-free implementation and requires them to FAIL. Without it, a
# green suite is equally consistent with "the lock works" and "the test never
# had teeth" — which is the exact false-green class this test was born from.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/hook-telemetry.sh"
    TDIR="$(mktemp -d)"
    COUNTER="$TDIR/.hook-counter"
    PROCS=8
    ITERS=200
}

teardown() {
    [ -n "${TDIR:-}" ] && rm -rf "$TDIR"
}

# Fire PROCS x ITERS concurrent increments, one distinct key per process.
_hammer() {
    local fn="$1" file="$2" p
    for p in $(seq 1 "$PROCS"); do
        ( local i; for i in $(seq 1 "$ITERS"); do "$fn" "$file" "k$p"; done ) &
    done
    wait
}

_sum()        { awk -F= '{s+=$2} END {print s+0}' "$1"; }
_keycount()   { grep -c . "$1"; }
_dupecount()  { cut -d= -f1 "$1" | sort | uniq -d | grep -c . || true; }

@test "T-3371: concurrent increments are not lost" {
    _hammer _fw_telemetry_increment "$COUNTER"

    local expected=$(( PROCS * ITERS ))
    [ "$(_sum "$COUNTER")" -eq "$expected" ]
    [ "$(_keycount "$COUNTER")" -eq "$PROCS" ]
    [ "$(_dupecount "$COUNTER")" -eq 0 ]
}

# ---- CONTROL LEG --------------------------------------------------------
# A lock-free implementation, byte-equivalent to the pre-T-3371 code. If this
# passes the same assertions, the test above proves nothing.

_lockfree_increment() {
    local file="$1" key="$2"
    local -a lines
    local i k v
    local found=0
    if [ -f "$file" ]; then
        mapfile -t lines < "$file"
        for i in "${!lines[@]}"; do
            k="${lines[i]%%=*}"
            if [ "$k" = "$key" ]; then
                v="${lines[i]#*=}"
                lines[i]="$key=$((v + 1))"
                found=1
                break
            fi
        done
        [ "$found" = "0" ] && lines+=("$key=1")
        printf '%s\n' "${lines[@]}" > "$file"
    else
        printf '%s=1\n' "$key" > "$file"
    fi
}

@test "T-3371 CONTROL: the lock-free implementation DOES lose increments" {
    local ctl="$TDIR/.lockfree-counter"
    _hammer _lockfree_increment "$ctl"

    local expected=$(( PROCS * ITERS ))
    local got; got="$(_sum "$ctl")"

    # The defect must reproduce. If it does not, this test has no teeth and the
    # passing result above is not evidence of anything.
    [ "$got" -lt "$expected" ]
}

# ---- Degrade-to-allow (L-331) -------------------------------------------

@test "T-3371: a held lock degrades to an unlocked write, never a hang or a failure" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"

    # Hold the lock from a live foreign process for longer than our wait.
    ( exec 9>>"$COUNTER.lock"; flock 9; sleep 5 ) &
    local holder=$!
    sleep 0.3

    FW_TELEMETRY_LOCK_WAIT=1 run _fw_telemetry_increment "$COUNTER" "degraded"
    [ "$status" -eq 0 ]
    grep -q '^degraded=1$' "$COUNTER"

    kill "$holder" 2>/dev/null || true
    wait "$holder" 2>/dev/null || true
}

@test "T-3371: fw_record_hook_fire never returns non-zero even on an unwritable dir" {
    PROJECT_ROOT="$TDIR/does-not-exist" run fw_record_hook_fire "some-hook" 0
    [ "$status" -eq 0 ]
}

# ---- Self-healing the corruption the race already left behind -----------

@test "T-3371: a seeded duplicate key and blank line are collapsed, not inherited" {
    printf 'budget-gate=39\n\nbudget-gate=31\ncheck-arc-id=7\n' > "$COUNTER"

    _fw_telemetry_increment "$COUNTER" "budget-gate"

    # One line per key, the live value incremented, the corpse dropped.
    [ "$(grep -c '^budget-gate=' "$COUNTER")" -eq 1 ]
    grep -q '^budget-gate=40$' "$COUNTER"
    grep -q '^check-arc-id=7$' "$COUNTER"
    # No blank line survived.
    [ "$(grep -c '^$' "$COUNTER" || true)" -eq 0 ]
}

@test "T-3371: a malformed line without '=' is dropped rather than corrupting the file" {
    printf 'good=3\ngarbage-no-equals\n' > "$COUNTER"
    _fw_telemetry_increment "$COUNTER" "good"
    grep -q '^good=4$' "$COUNTER"
    ! grep -q 'garbage-no-equals' "$COUNTER"
}

# ---- Performance budget (lib/hook-telemetry.sh:15 says <5ms per fire) ---

# The timing loop runs in a PLAIN bash subprocess, deliberately not inside bats.
# bats installs a DEBUG trap and instruments every command in a @test body, which
# costs far more than the function under test: measured in-harness at ~88ms/fire
# versus ~2.3ms for the same code outside it. Timing it in-place would measure the
# harness and report it as the subject's cost — so the benchmark is shelled out and
# only its verdict is asserted here.
@test "T-3371: per-fire cost stays under the documented 5ms budget" {
    local us
    us="$(bash -c '
        source "'"$FRAMEWORK_ROOT"'/lib/hook-telemetry.sh"
        f="'"$TDIR"'/.bench-counter"
        for i in $(seq 1 20); do _fw_telemetry_increment "$f" "seed$i"; done
        n=200
        t0=$(date +%s%N)
        for i in $(seq 1 $n); do _fw_telemetry_increment "$f" "seed7"; done
        t1=$(date +%s%N)
        echo $(( (t1 - t0) / n / 1000 ))
    ')"

    echo "measured: ${us}us/fire (budget 5000us, pre-fix lock-free baseline ~632us)"
    [ "$us" -lt 5000 ]
}
