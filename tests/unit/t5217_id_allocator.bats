#!/usr/bin/env bats
# T-5217 (slice 1 of T-5212): one authoritative task-id allocator, lib/idalloc.sh.
#
# Every test runs in a temporary git repository with several worktrees; nothing here
# reads or writes this repository's .tasks/, counter or ledger. The cases are 1409's
# prototype checks (their T-6848) plus reconcile, the single-path byte-compare,
# objectives-seed (T-5213) and the doctor check.

load ../git_fence

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
IDALLOC="$FRAMEWORK_ROOT/lib/idalloc.sh"
RECONCILE="$FRAMEWORK_ROOT/lib/idalloc_reconcile.py"
CREATE_TASK="$FRAMEWORK_ROOT/agents/task-create/create-task.sh"

setup() {
    T="$(mktemp -d "${BATS_RUN_TMPDIR:-/tmp}/t5217.XXXXXX")"
    MAIN="$T/main"
    mkdir -p "$MAIN/.tasks/active" "$MAIN/.tasks/completed" "$MAIN/.context/locks"
    : > "$MAIN/.tasks/active/.gitkeep"
    : > "$MAIN/.tasks/completed/.gitkeep"
    git -C "$MAIN" init -q
    git -C "$MAIN" add -A
    git -C "$MAIN" -c user.email=t@t -c user.name=t commit -qm seed
    export PROJECT_ROOT="$MAIN"
    unset CLAUDECODE FW_ID_CHECK FW_ID_BLOCK_MAX FW_ID_QUARANTINE_GAP _FW_PATHS_DERIVED_BY
    unset FW_ALLOW_EMPTY_RECOMMENDATION FW_INCEPTION_PRE_GATED
}

teardown() {
    git -C "$MAIN" worktree prune 2>/dev/null || true
    rm -rf "$T"
}

_wt() {  # add worktree N
    git -C "$MAIN" worktree add -q "$T/wt$1" HEAD 2>/dev/null
}

_seed() {  # _seed <view-dir> <id> [slug]
    : > "$1/active/T-$2-${3:-seed}.md"
}

# alloc <tasks-dir> <n> [purpose] — runs the allocator in its own process.
alloc() {
    TASKS_DIR="$1" bash -c 'source "$0"; fw_id_allocate "$1" "$2"' "$IDALLOC" "$2" "${3:-test}"
}

reconcile() {
    local views=() d
    for d in "$MAIN/.tasks" "$T"/wt*/.tasks; do [ -d "$d" ] && views+=(--view "$d"); done
    python3 "$RECONCILE" --main-view "$MAIN/.tasks" "${views[@]}" "$@"
}

counter() { cat "$MAIN/.tasks/.id-highwater"; }
ledger() { cat "$MAIN/.tasks/.id-ledger.jsonl"; }

# ── fw_id_allocate ────────────────────────────────────────────────────────────

@test "allocates a contiguous block, ledger before counter, under the main-worktree lock" {
    _seed "$MAIN/.tasks" 10
    run alloc "$MAIN/.tasks" 13 "arc:demo"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "T-011" ]
    [ "${lines[12]}" = "T-023" ]
    [ "${#lines[@]}" -eq 13 ]
    [ "$(counter)" = "23" ]
    # first row adopts the pre-ledger history, second is the reservation
    sed -n 1p "$MAIN/.tasks/.id-ledger.jsonl" | grep -q '"event":"adopt","last":10'
    sed -n 2p "$MAIN/.tasks/.id-ledger.jsonl" | grep -q '"event":"reserve","first":11,"last":23,"n":13,"purpose":"arc:demo"'
    [ -f "$MAIN/.context/locks/task-id-allocation.lock" ]
    # source order: the reserve row is appended before the counter is written
    awk '/Ledger before counter/{getline; print}' "$IDALLOC" | grep -q '_fw_idalloc_append "\$ledger" "\$row" && _fw_idalloc_write_counter'
}

@test "a single id is N=1; N > 100 and N < 1 are refused and write nothing" {
    run alloc "$MAIN/.tasks" 1
    [ "$status" -eq 0 ] && [ "$output" = "T-001" ]
    run alloc "$MAIN/.tasks" 101
    [ "$status" -eq 2 ]
    [[ "$output" == *"exceeds the block maximum of 100"* ]]
    run alloc "$MAIN/.tasks" 0
    [ "$status" -eq 2 ]
    [ "$(counter)" = "1" ]
    [ "$(grep -c '"event":"reserve"' "$MAIN/.tasks/.id-ledger.jsonl")" -eq 1 ]
    run alloc "$MAIN/.tasks" 100
    [ "$status" -eq 0 ] && [ "${#lines[@]}" -eq 100 ]
    # FW_ID_BLOCK_MAX can lower the cap, never raise it past 100
    run env FW_ID_BLOCK_MAX=500 TASKS_DIR="$MAIN/.tasks" bash -c 'source "$0"; fw_id_allocate 101' "$IDALLOC"
    [ "$status" -eq 2 ]
    run env FW_ID_BLOCK_MAX=5 TASKS_DIR="$MAIN/.tasks" bash -c 'source "$0"; fw_id_allocate 6' "$IDALLOC"
    [ "$status" -eq 2 ]
}

@test "20 concurrent processes over 4 views mixing singles and 13-blocks: 0 duplicates, 0 overlaps" {
    local i
    for i in 1 2 3; do _wt "$i"; done
    _seed "$MAIN/.tasks" 100
    for i in $(seq 1 20); do
        local view="$MAIN/.tasks"
        [ $((i % 4)) -ne 0 ] && view="$T/wt$((i % 4))/.tasks"
        (
            for k in 1 2 3; do alloc "$view" 1 "single-$i"; done
            alloc "$view" 13 "block-$i"
            alloc "$view" 1 "single-$i"
        ) > "$T/out.$i" &
    done
    wait
    cat "$T"/out.* > "$T/all"
    [ "$(wc -l < "$T/all")" -eq $((20 * 17)) ]
    [ -z "$(sort "$T/all" | uniq -d)" ]
    # dense: exactly T-101..T-440, nothing skipped, nothing reused
    [ "$(sort -t- -k2 -n "$T/all" | head -1)" = "T-101" ]
    [ "$(sort -t- -k2 -n "$T/all" | tail -1)" = "T-440" ]
    [ "$(counter)" = "440" ]
    # each 13-block came back contiguous
    for i in $(seq 1 20); do
        local first last
        first=$(sed -n 4p "$T/out.$i" | sed 's/T-//'); last=$(sed -n 16p "$T/out.$i" | sed 's/T-//')
        [ $((10#$last - 10#$first)) -eq 12 ]
    done
    run reconcile --json
    [ "$status" -eq 0 ]
    ! grep -q '"overlapping-reservations"' <<<"$output"
}

@test "kill -9 after a reservation: no reuse, reconcile reports the incomplete reservation" {
    _seed "$MAIN/.tasks" 10
    TASKS_DIR="$MAIN/.tasks" bash -c 'source "$0"; fw_id_allocate 13 arc:crash >/dev/null; kill -9 $$' "$IDALLOC" || true
    run alloc "$MAIN/.tasks" 1
    [ "$output" = "T-024" ]
    run reconcile
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  incomplete-reservation"* ]]
    [[ "$output" == *"T-11..T-23 (arc:crash"* ]]
}

@test "kill -9 mid-block (5 of 13 files written): no reuse, reconcile names the 8 missing ids" {
    _seed "$MAIN/.tasks" 10
    TASKS_DIR="$MAIN/.tasks" bash -c '
        source "$0"
        ids=$(fw_id_allocate 13 arc:mid)
        for id in $(echo "$ids" | head -5); do : > "$TASKS_DIR/active/$id-x.md"; fw_id_ledger_created "$id"; done
        kill -9 $$' "$IDALLOC" || true
    [ -f "$MAIN/.tasks/active/T-015-x.md" ] && [ ! -f "$MAIN/.tasks/active/T-016-x.md" ]
    run alloc "$MAIN/.tasks" 1
    [ "$output" = "T-024" ]
    run reconcile --json
    python3 -c '
import json,sys
d=json.loads(sys.argv[1])
f=[x for x in d["findings"] if x["code"]=="incomplete-reservation"][0]
r=[x for x in f["reservations"] if x["purpose"]=="arc:mid"][0]
assert r["missing"]==["T-16..T-23"], r' "$output"
}

@test "crash between ledger and counter: the ledger tail raises the counter even with FW_ID_CHECK=0" {
    _seed "$MAIN/.tasks" 10
    alloc "$MAIN/.tasks" 1 >/dev/null                          # adopt + reserve 11, counter 11
    printf '{"event":"reserve","first":12,"last":30,"n":19,"purpose":"crashed","ts":"x","pid":1,"view":"v"}\n' \
        >> "$MAIN/.tasks/.id-ledger.jsonl"                     # counter never written
    run env FW_ID_CHECK=0 TASKS_DIR="$MAIN/.tasks" bash -c 'source "$0"; fw_id_allocate 1' "$IDALLOC"
    [ "$output" = "T-031" ]
    ledger | grep -q '"reason":"ledger-above-counter"'
}

@test "stale view: a worktree behind main and with an old mark does not mint a duplicate" {
    _wt 1
    _seed "$MAIN/.tasks" 50 main-only          # the worktree never sees this file
    printf '12\n' > "$T/wt1/.tasks/.id-highwater"
    run alloc "$T/wt1/.tasks" 1
    [ "$output" = "T-051" ]
    # the counter lives in the main worktree, not in the view that asked
    [ "$(counter)" = "51" ]
    [ "$(cat "$T/wt1/.tasks/.id-highwater")" = "12" ]
}

@test "counter missing: the check rebuilds it from files, marks and ledger" {
    _seed "$MAIN/.tasks" 10
    alloc "$MAIN/.tasks" 5 >/dev/null                     # 11..15, no files
    rm "$MAIN/.tasks/.id-highwater"
    run env FW_ID_CHECK=0 TASKS_DIR="$MAIN/.tasks" bash -c 'source "$0"; fw_id_allocate 1' "$IDALLOC"
    [ "$output" = "T-016" ]
    ledger | grep -q '"from":null,"to":15,"reason":"counter-missing"'
}

@test "counter too low: the check raises it and records why" {
    _seed "$MAIN/.tasks" 40
    printf '7\n' > "$MAIN/.tasks/.id-highwater"
    printf '{"event":"adopt","last":7,"ts":"x"}\n' > "$MAIN/.tasks/.id-ledger.jsonl"
    run alloc "$MAIN/.tasks" 1
    [ "$output" = "T-041" ]
    ledger | grep -q '"from":7,"to":40,"reason":"check-raised"'
}

@test "counter too high (within the gap): ids continue above it, it is never lowered" {
    _seed "$MAIN/.tasks" 10
    printf '300\n' > "$MAIN/.tasks/.id-highwater"
    run alloc "$MAIN/.tasks" 1
    [ "$output" = "T-301" ]
    run reconcile
    [[ "$output" != *"counter-above-ledger"* ]]   # the reservation now explains it
}

@test "deleted top file with the counter deleted: the ledger keeps its id from being reissued" {
    _seed "$MAIN/.tasks" 10
    id=$(alloc "$MAIN/.tasks" 1)
    : > "$MAIN/.tasks/active/$id-top.md"
    rm "$MAIN/.tasks/active/$id-top.md" "$MAIN/.tasks/.id-highwater"
    run alloc "$MAIN/.tasks" 1
    [ "$output" = "T-012" ]
}

@test "outlier band (T-99971 / T-100202 shape): ids stay in the main range, counter present or not" {
    _seed "$MAIN/.tasks" 2524
    _seed "$MAIN/.tasks" 99971 inflated
    _seed "$MAIN/.tasks" 100202 inflated
    run alloc "$MAIN/.tasks" 1
    [ "$output" = "T-2525" ]
    rm "$MAIN/.tasks/.id-highwater"
    run alloc "$MAIN/.tasks" 13
    [ "${lines[0]}" = "T-2526" ]
    # a counter that points into the band is ignored like the band (T-4189 rule)
    printf '99971\n' > "$MAIN/.tasks/.id-highwater"
    run alloc "$MAIN/.tasks" 1
    [ "$output" = "T-2539" ]
    ledger | grep -q '"from":99971,"to":2538,"reason":"counter-in-quarantine"'
}

@test "12 aborted 100-blocks against the quarantine gap: the next id follows the ledger" {
    _seed "$MAIN/.tasks" 10
    local i
    for i in $(seq 1 12); do alloc "$MAIN/.tasks" 100 "aborted-$i" >/dev/null; done
    # 1,200 reserved and unused ids are more than the 1,000 gap; ledger ids count as used
    run alloc "$MAIN/.tasks" 1
    [ "$output" = "T-1211" ]
    rm "$MAIN/.tasks/.id-highwater"
    run alloc "$MAIN/.tasks" 1
    [ "$output" = "T-1212" ]
}

# ── create-task and objectives-seed go through it ─────────────────────────────

@test "create-task allocates through fw_id_allocate and records the created row" {
    run timeout 30 env TASKS_DIR="$MAIN/.tasks" "$CREATE_TASK" --name "Probe" --description d --type build --owner agent < /dev/null
    [ "$status" -eq 0 ]
    ls "$MAIN/.tasks/active/" | grep -q '^T-001-probe.md$'
    ledger | grep -q '"event":"reserve","first":1,"last":1,"n":1,"purpose":"create-task"'
    ledger | grep -q '"event":"created","id":1,'
    # generate_id is a thin wrapper — no scan of its own left in create-task
    ! grep -q 'printf "T-%03d"' "$CREATE_TASK" || false
    grep -q 'fw_id_allocate 1 "create-task"' "$CREATE_TASK"
}

@test "single-task creation writes the same file as before T-5217, apart from id and timestamps" {
    # The pre-change script: the parent of the first T-5217 commit to touch it, or HEAD while
    # the change is still uncommitted.
    local base oldrev
    base=$(git -C "$FRAMEWORK_ROOT" log --format=%H --grep='^T-5217' -- agents/task-create/create-task.sh | tail -1)
    if [ -n "$base" ]; then
        oldrev="$base^"
    elif ! git -C "$FRAMEWORK_ROOT" diff --quiet HEAD -- agents/task-create/create-task.sh; then
        oldrev=HEAD
    fi
    [ -n "${oldrev:-}" ] || { echo "cannot find the pre-T-5217 create-task.sh in this checkout" >&2; return 1; }
    local old="$T/oldfw"
    mkdir -p "$old/agents/task-create" "$old/.tasks"
    git -C "$FRAMEWORK_ROOT" show "$oldrev:agents/task-create/create-task.sh" > "$old/agents/task-create/create-task.sh"
    chmod +x "$old/agents/task-create/create-task.sh"
    ln -s "$FRAMEWORK_ROOT/lib" "$old/lib"
    ln -s "$FRAMEWORK_ROOT/agents/context" "$old/agents/context"
    ln -s "$FRAMEWORK_ROOT/.tasks/templates" "$old/.tasks/templates"
    mkdir -p "$T/a/.tasks/active" "$T/a/.tasks/completed" "$T/b/.tasks/active" "$T/b/.tasks/completed"
    local args=(--name "Golden probe" --description "A description" --type build --owner agent --tags "alpha,beta" --related "T-084")
    local iargs=(--name "Golden inception" --description "Why" --type inception --owner human --i-am-human
                 --recommendation GO --rationale "Because evidence" --horizon next)
    for v in a b; do
        local script="$CREATE_TASK"; [ "$v" = a ] && script="$old/agents/task-create/create-task.sh"
        (cd "$T/$v" && PROJECT_ROOT="$T/$v" TASKS_DIR="$T/$v/.tasks" timeout 30 "$script" "${args[@]}" < /dev/null > /dev/null)
        (cd "$T/$v" && PROJECT_ROOT="$T/$v" TASKS_DIR="$T/$v/.tasks" timeout 30 "$script" "${iargs[@]}" < /dev/null > /dev/null)
    done
    norm() { sed -E 's/T-00[12]\b/T-ID/g; s/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/TS/g; s/[0-9]{4}-[0-9]{2}-[0-9]{2}/DATE/g' "$1" | sed "s#$2#ROOT#g"; }
    diff <(norm "$T/a/.tasks/active/T-001-golden-probe.md" "$T/a") <(norm "$T/b/.tasks/active/T-001-golden-probe.md" "$T/b")
    diff <(norm "$T/a/.tasks/active/T-002-golden-inception.md" "$T/a") <(norm "$T/b/.tasks/active/T-002-golden-inception.md" "$T/b")
    # both paths really produced files (an empty diff of two missing files proves nothing)
    [ "$(wc -l < "$T/b/.tasks/active/T-001-golden-probe.md")" -gt 50 ]
    [ "$(wc -l < "$T/b/.tasks/active/T-002-golden-inception.md")" -gt 50 ]
}

@test "objectives-seed allocates through fw_id_allocate (T-5213): counter honoured, ledger written" {
    source "$FRAMEWORK_ROOT/lib/objectives-seed.sh"
    _seed "$MAIN/.tasks" 8
    printf '40\n' > "$MAIN/.tasks/.id-highwater"   # a deleted T-040 — the old seeder reissued it
    run fw_objectives_seed_task "$MAIN" "$FRAMEWORK_ROOT" demo
    [ "$status" -eq 0 ]
    [ "$output" = "$MAIN/.tasks/active/T-041-define-project-objectives.md" ]
    grep -q '^id: T-041$' "$output"
    ledger | grep -q '"purpose":"objectives-seed"'
    ledger | grep -q '"event":"created","id":41,'
    ! grep -q 'printf "T-%03d"' "$FRAMEWORK_ROOT/lib/objectives-seed.sh"
}

@test "objectives-seed from a worktree sees main's tasks (no lock, no views before)" {
    _wt 1
    _seed "$MAIN/.tasks" 30 main-only
    source "$FRAMEWORK_ROOT/lib/objectives-seed.sh"
    run fw_objectives_seed_task "$T/wt1" "$FRAMEWORK_ROOT" demo
    [ "$status" -eq 0 ]
    [[ "$output" == *"/T-031-define-project-objectives.md" ]]
}

# ── fw task id reconcile ──────────────────────────────────────────────────────

@test "reconcile ERROR: duplicate, file above counter, counter below ledger, overlap, missing counter" {
    _wt 1
    _seed "$MAIN/.tasks" 10
    alloc "$MAIN/.tasks" 3 >/dev/null                         # 11..13, counter 13
    _seed "$MAIN/.tasks" 5 one
    _seed "$T/wt1/.tasks" 5 other                             # duplicate across views
    _seed "$MAIN/.tasks" 20 above                             # above the counter
    printf '{"event":"reserve","first":12,"last":30,"n":19,"purpose":"o","ts":"x","pid":1,"view":"v"}\n' \
        >> "$MAIN/.tasks/.id-ledger.jsonl"                    # overlaps 12..13, above counter
    run reconcile
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR duplicate"*"T-5"* ]]
    [[ "$output" == *"ERROR file-above-counter"*"T-20"* ]]
    [[ "$output" == *"ERROR counter-below-ledger"* ]]
    [[ "$output" == *"ERROR overlapping-reservations"*"T-12..T-13"* ]]
    rm "$MAIN/.tasks/.id-highwater"
    run reconcile
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR counter-missing"* ]]
}

@test "reconcile WARN and INFO: incomplete, file without reservation, deleted after creation, quarantine band" {
    _seed "$MAIN/.tasks" 10
    alloc "$MAIN/.tasks" 4 >/dev/null                         # 11..14 never created
    id=$(alloc "$MAIN/.tasks" 1)                              # 15 created, then deleted
    TASKS_DIR="$MAIN/.tasks" bash -c 'source "$0"; fw_id_ledger_created "$1"' "$IDALLOC" "$id"
    printf '20\n' > "$MAIN/.tasks/.id-highwater"
    _seed "$MAIN/.tasks" 17 hand-made                         # no reservation covers 17
    _seed "$MAIN/.tasks" 99971 band
    run reconcile
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  incomplete-reservation"*"T-11..T-14"* ]]
    [[ "$output" == *"WARN  file-without-reservation"*"T-17"* ]]
    [[ "$output" == *"WARN  counter-above-ledger"* ]]
    [[ "$output" == *"INFO  deleted-after-creation"*"T-15"* ]]
    [[ "$output" == *"INFO  quarantine-band"*"T-99971"* ]]
    run reconcile --json
    python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["counter"]==20 and d["main_max"]==17' "$output"
}

@test "reconcile --heal only raises the counter, and records a heal row" {
    _seed "$MAIN/.tasks" 10
    alloc "$MAIN/.tasks" 5 >/dev/null
    printf '3\n' > "$MAIN/.tasks/.id-highwater"
    run reconcile --heal
    [ "$status" -eq 0 ]
    [[ "$output" == *"HEALED  counter 3 -> 15"* ]]
    [ "$(counter)" = "15" ]
    ledger | grep -q '"event":"heal","from":3,"to":15,"reason":"reconcile"'
    # too high is reported, never lowered
    printf '900\n' > "$MAIN/.tasks/.id-highwater"
    run reconcile --heal
    [ "$(counter)" = "900" ]
    [[ "$output" == *"counter-above-ledger"* ]]
    # missing is recreated
    rm "$MAIN/.tasks/.id-highwater"
    run reconcile --heal
    [ "$status" -eq 0 ]
    [ "$(counter)" = "15" ]
}

@test "fw task id reconcile routes to the reconciler for this project's views" {
    _seed "$MAIN/.tasks" 10
    alloc "$MAIN/.tasks" 1 >/dev/null
    run bash -c 'cd "$1" && PROJECT_ROOT="$1" TASKS_DIR="$1/.tasks" "$2/bin/fw" task id reconcile --json' _ "$MAIN" "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
    python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["counter"]==11, d' "$output"
    run bash -c 'cd "$1" && PROJECT_ROOT="$1" "$2/bin/fw" task id reconcile --bogus' _ "$MAIN" "$FRAMEWORK_ROOT"
    [ "$status" -eq 2 ]
}

# ── doctor: one allocator ─────────────────────────────────────────────────────

@test "doctor line: OK for this framework copy, WARN on a planted second allocator in a worktree copy" {
    source "$IDALLOC"
    run fw_id_doctor_line "$FRAMEWORK_ROOT" "$MAIN"
    [[ "$output" == "OK one task-id allocator"* ]]
    _wt 1
    mkdir -p "$T/wt1/agents/task-create"
    printf '#!/bin/bash\ngenerate_id() { printf "T-%%03d" $((max + 1)); }\n' > "$T/wt1/agents/task-create/create-task.sh"
    run fw_id_doctor_line "$FRAMEWORK_ROOT" "$MAIN"
    [[ "$output" == "WARN another task-id allocator"*"wt1/agents/task-create/create-task.sh"* ]]
    # python spelling is caught too
    mkdir -p "$T/wt1/lib"
    printf 'new = f"T-{max_id + 1:03d}"\n' > "$T/wt1/lib/mint.py"
    run fw_id_other_allocators "$T/wt1"
    [[ "$output" == *"wt1/lib/mint.py"* ]]
}

@test "fw doctor prints the one-allocator line" {
    grep -q 'fw_id_doctor_line "\$FRAMEWORK_ROOT" "\$PROJECT_ROOT"' "$FRAMEWORK_ROOT/bin/fw"
    source "$IDALLOC"
    # the framework repo itself: the real allocator is the only one
    [ -z "$(fw_id_other_allocators "$FRAMEWORK_ROOT")" ]
}
