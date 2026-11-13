#!/usr/bin/env bats
# T-5120 (010 T-3777) — `fw termlink prune`: unattended retention for FINISHED worker dirs.
# Removes only this project's dirs that are finished (review: finalised), collected and older
# than the age cut; keeps everything else; signals nothing. `fw termlink dispatch` kicks it in
# the background at most hourly (_retention_kick), off when TERMLINK_DISPATCH_RETENTION_DAYS=0.
# Sandbox only: FW_DISPATCH_DIR / FW_DISPATCH_LEGACY_DIR under BATS_TEST_TMPDIR, termlink stubbed.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TL="$ROOT/agents/termlink/termlink.sh"
    T="$BATS_TEST_TMPDIR"
    D="$T/dispatch"; P="$T/proj-here"; Q="$T/proj-other"; L="$T/legacy"
    mkdir -p "$D" "$P" "$Q" "$L"
    STUB="$T/stub"; mkdir -p "$STUB"
    printf '#!/bin/sh\necho "$*" >> "%s/termlink.log"\nexit 0\n' "$T" > "$STUB/termlink"
    chmod +x "$STUB/termlink"
    PIDS_FILE="$T/pids"; : > "$PIDS_FILE"
}

teardown() {
    local pid
    while read -r pid; do
        [ -n "$pid" ] || continue
        pkill -KILL -P "$pid" 2>/dev/null || true
        kill -KILL "$pid" 2>/dev/null || true
    done < "$PIDS_FILE"
}

mk() {  # dir project age_days [flags...]   flags: nometa unfinished uncollected unfinalised finalised
    local w="$1" proj="$2" age="$3"; shift 3
    mkdir -p "$w"
    local f nometa=0 finished=1 collected=1
    for f in "$@"; do
        case "$f" in
            nometa) nometa=1 ;;
            unfinished) finished=0 ;;
            uncollected) collected=0 ;;
            unfinalised) : > "$w/finalise_required" ;;
            finalised) : > "$w/finalise_required"; echo "unsigned:x" > "$w/finalised" ;;
        esac
    done
    [ "$nometa" = 1 ] || printf '{\n  "name": "%s",\n  "project": "%s",\n  "timeout": 60\n}\n' "${w##*/}" "$proj" > "$w/meta.json"
    echo "result text" > "$w/result.md"
    [ "$collected" = 1 ] && date > "$w/collected"
    if [ "$finished" = 1 ]; then
        echo 0 > "$w/exit_code"
        touch -d "$age days ago" "$w/exit_code"
    fi
}

prune() {  # args...
    run env PATH="$STUB:$PATH" FW_DISPATCH_DIR="$D" PROJECT_ROOT="$P" bash "$TL" prune "$@" < /dev/null
}

@test "an old, finished, collected dir of this project is removed and the removal is logged" {
    mk "$D/w-old" "$P" 10
    prune --older-than 7
    [ "$status" -eq 0 ]
    [ ! -e "$D/w-old" ]
    grep -q "Removed 1 finished worker dir" <<<"$output"
    python3 -c 'import json,sys; r=json.loads(open(sys.argv[1]).read().splitlines()[-1]); assert r["removed"]==["w-old"] and r["older_than_days"]==7 and "kept" in r' "$D/retention.jsonl"
}

@test "a finished dir younger than the cut is kept" {
    mk "$D/w-young" "$P" 2
    prune --older-than 7
    [ "$status" -eq 0 ]; [ -d "$D/w-young" ]
    grep -q "kept: 1 younger" <<<"$output"
}

@test "an uncollected result older than the collected cut but younger than its own cut is kept" {
    mk "$D/w-unread" "$P" 20 uncollected
    prune --older-than 7
    [ -d "$D/w-unread" ]; grep -q "1 uncollected" <<<"$output"
}

@test "an uncollected result older than TERMLINK_DISPATCH_UNCOLLECTED_DAYS (30) is removed and logged as such" {
    mk "$D/w-stale" "$P" 40 uncollected
    mk "$D/w-read" "$P" 40
    prune --older-than 7
    [ "$status" -eq 0 ]; [ ! -e "$D/w-stale" ]; [ ! -e "$D/w-read" ]
    python3 -c 'import json,sys; r=json.loads(open(sys.argv[1]).read().splitlines()[-1]); assert r["removed"]==["w-read"], r; assert r["removed_uncollected"]==["w-stale"], r; assert r["uncollected_older_than_days"]==30' "$D/retention.jsonl"
}

@test "TERMLINK_DISPATCH_UNCOLLECTED_DAYS=0 never removes an uncollected result" {
    mk "$D/w-stale" "$P" 400 uncollected
    run env PATH="$STUB:$PATH" FW_DISPATCH_DIR="$D" PROJECT_ROOT="$P" FW_TERMLINK_DISPATCH_UNCOLLECTED_DAYS=0 bash "$TL" prune --older-than 7 < /dev/null
    [ "$status" -eq 0 ]; [ -d "$D/w-stale" ]
}

@test "an uncollected cut below the collected cut is raised to it" {
    mk "$D/w-unread" "$P" 10 uncollected
    prune --older-than 14 --uncollected-older-than 3
    [ -d "$D/w-unread" ]
}

@test "an old dir with no exit_code is kept" {
    mk "$D/w-noexit" "$P" 30 unfinished
    touch -d "30 days ago" "$D/w-noexit"
    prune --older-than 7
    [ -d "$D/w-noexit" ]; grep -q "1 unfinished" <<<"$output"
}

@test "an old review dir that is not finalised is kept; a finalised one is removed" {
    mk "$D/w-unfin" "$P" 30 unfinalised
    mk "$D/w-fin" "$P" 30 finalised
    prune --older-than 7
    [ -d "$D/w-unfin" ]; [ ! -e "$D/w-fin" ]
}

@test "an old dir whose run.sh is still in the process table is kept" {
    mk "$D/w-live" "$P" 30
    # the `; :` stops bash exec'ing sleep, so its argv keeps the path; fds closed so bats does not wait
    bash -c 'sleep 300; :' "$D/w-live/run.sh" </dev/null >/dev/null 2>&1 3>&- &
    echo $! >> "$PIDS_FILE"
    sleep 0.3
    prune --older-than 7
    [ -d "$D/w-live" ]; grep -q "1 running" <<<"$output"
}

@test "another project's old dir is never touched" {
    mk "$D/w-theirs" "$Q" 30
    prune --older-than 7
    [ -d "$D/w-theirs" ]; grep -q "1 other project" <<<"$output"
}

@test "legacy /tmp root: a dir without meta.json is kept, this project's dir with meta.json is removed" {
    mk "$L/w-anon" "$P" 30 nometa
    mk "$L/w-ours" "$P" 30
    mk "$P/.context/dispatch/w-own-nometa" "$P" 30 nometa
    run env PATH="$STUB:$PATH" FW_DISPATCH_LEGACY_DIR="$L" PROJECT_ROOT="$P" bash -c 'cd "$PROJECT_ROOT" && bash "$0" prune --older-than 7' "$TL" < /dev/null
    [ "$status" -eq 0 ]
    [ -d "$L/w-anon" ]; [ ! -e "$L/w-ours" ]
    [ ! -e "$P/.context/dispatch/w-own-nometa" ]   # own root: dispatched from here, meta not needed
}

@test "--dry-run removes nothing and logs nothing" {
    mk "$D/w-old" "$P" 10
    prune --older-than 7 --dry-run
    [ "$status" -eq 0 ]; [ -d "$D/w-old" ]; [ ! -e "$D/retention.jsonl" ]
    grep -q "Would remove 1" <<<"$output"
}

@test "prune never calls termlink (no signal, no endpoint stop, no clean)" {
    mk "$D/w-old" "$P" 10
    prune --older-than 7
    [ ! -e "$T/termlink.log" ]
}

@test "bad --older-than is refused with exit 2 and changes nothing" {
    mk "$D/w-old" "$P" 10
    prune --older-than 0;   [ "$status" -eq 2 ]
    prune --older-than abc; [ "$status" -eq 2 ]
    [ -d "$D/w-old" ]
}

kick() {  # extra env assignments...
    run env PATH="$STUB:$PATH" FW_DISPATCH_DIR="$D" PROJECT_ROOT="$P" "$@" \
        bash -c 'source "$0"; _retention_kick; echo rc=$?' "$TL" < /dev/null
}

@test "dispatch kick: prunes in the background once, then is throttled for an hour" {
    mk "$D/w-old" "$P" 10
    kick
    [ "$status" -eq 0 ]; grep -q "rc=0" <<<"$output"
    [ -f "$D/.retention-stamp" ]
    local i; for i in $(seq 1 50); do [ -e "$D/w-old" ] || break; sleep 0.1; done
    [ ! -e "$D/w-old" ]
    mk "$D/w-old2" "$P" 10
    kick
    sleep 1
    [ -d "$D/w-old2" ]                       # stamp is fresh: no second prune
    touch -d "2 hours ago" "$D/.retention-stamp"
    kick
    for i in $(seq 1 50); do [ -e "$D/w-old2" ] || break; sleep 0.1; done
    [ ! -e "$D/w-old2" ]
}

@test "dispatch kick: TERMLINK_DISPATCH_RETENTION_DAYS=0 turns it off" {
    mk "$D/w-old" "$P" 10
    kick FW_TERMLINK_DISPATCH_RETENTION_DAYS=0
    grep -q "rc=0" <<<"$output"
    sleep 1
    [ -d "$D/w-old" ]; [ ! -e "$D/.retention-stamp" ]
}

@test "dispatch kick: an invalid retention value falls back to 7 days" {
    mk "$D/w-5d" "$P" 5
    mk "$D/w-9d" "$P" 9
    kick FW_TERMLINK_DISPATCH_RETENTION_DAYS=banana
    local i; for i in $(seq 1 50); do [ -e "$D/w-9d" ] || break; sleep 0.1; done
    [ ! -e "$D/w-9d" ]; [ -d "$D/w-5d" ]
}

@test "dispatch calls the kick right after the worker cap check" {
    grep -A1 '_enforce_worker_cap "$project_dir" "$name"' "$TL" | grep -q '_retention_kick'
}
