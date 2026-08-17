#!/usr/bin/env bats
# T-3056 — memory recall must see the OPEN task corpus, not only knowledge
# harvested from closed work.
#
# The three failure directions, all of which look like success from outside:
#   - not firing at all       -> the original bug, unchanged
#   - firing on itself        -> `fw context focus T-X` recalls T-X (A2)
#   - firing on everything    -> open tasks take every slot, learnings vanish (A3)
#
# Fixtures use nonsense vocabulary so a hit cannot come from the real corpus.

load ../test_helper

RECALL="agents/context/lib/memory-recall.py"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    P="$TEST_TEMP_DIR/proj"
    mkdir -p "$P/.tasks/active" "$P/.context/project"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR:?}"
}

_task() {  # _task <id> <name>
    printf -- '---\nid: %s\nname: "%s"\nstatus: started-work\ndescription: >\n  irrelevant prose\n---\n' \
        "$1" "$2" > "$P/.tasks/active/$1-fixture.md"
}

_learning() {  # _learning <id> <text>
    printf 'learnings:\n  - id: %s\n    learning: "%s"\n    task: T-0001\n' \
        "$1" "$2" > "$P/.context/project/learnings.yaml"
}

_run_recall() {  # _run_recall <script> <args...>
    local script="$1"; shift
    PROJECT_ROOT="$P" python3 "$script" --no-hybrid "$@" 2>&1
}

# A copy of memory-recall.py with the self-exclusion removed — the A2 mutation.
_mutant_no_exclude() {
    local m="$TEST_TEMP_DIR/mr-noexclude.py"
    sed 's/exclude_task=args\.task/exclude_task=None/' \
        "$FRAMEWORK_ROOT/$RECALL" > "$m"
    ! cmp -s "$m" "$FRAMEWORK_ROOT/$RECALL"    # the substitution must have landed
    printf '%s' "$m"
}

@test "A1 — a query matching an open task's name recalls it" {
    _task T-9001 "widget carburetor telemetry harmonics plimsoll"
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --query "widget carburetor telemetry harmonics"
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" == *"(open task)"* ]]
}

@test "A1 — positive control: the harness can tell a hit from a miss" {
    # Required by L-616. Same fixture, a query that shares nothing.
    _task T-9001 "widget carburetor telemetry harmonics plimsoll"
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --query "quantum teleportation banana"
    [[ "$output" != *"T-9001"* ]]
}

@test "A2 — a task is not recalled by a query built from itself" {
    _task T-9001 "widget carburetor telemetry harmonics plimsoll"
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --task T-9001
    [[ "$output" != *"T-9001"* ]]
}

@test "A2 — without the exclusion it DOES recall itself (mutation)" {
    _task T-9001 "widget carburetor telemetry harmonics plimsoll"
    run _run_recall "$(_mutant_no_exclude)" --task T-9001
    [[ "$output" == *"T-9001"* ]]
}

@test "A2 — excluding one task does not hide a genuine sibling" {
    # The over-broad version of the fix: dropping every task, or the wrong one.
    _task T-9001 "widget carburetor telemetry harmonics plimsoll"
    _task T-9002 "widget carburetor telemetry harmonics resonance"
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --task T-9001
    [[ "$output" != *"T-9001"* ]]
    [[ "$output" == *"T-9002"* ]]
}

@test "A3 — open tasks are capped, they cannot take every slot" {
    for n in 1 2 3 4 5; do
        _task "T-900$n" "widget carburetor telemetry harmonics variant$n"
    done
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --query "widget carburetor telemetry harmonics"
    [ "$(echo "$output" | grep -c '(open task)')" -eq 2 ]
}

@test "A3 — knowledge results are unchanged by the new source" {
    _learning L-9001 "widget carburetor telemetry is the documented approach"
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --query "widget carburetor telemetry harmonics"
    [[ "$output" == *"L-9001"* ]]
    knowledge_only="$output"

    for n in 1 2 3 4 5; do
        _task "T-900$n" "widget carburetor telemetry harmonics variant$n"
    done
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --query "widget carburetor telemetry harmonics"
    # the learning still there, and still the same number of non-task lines
    [[ "$output" == *"L-9001"* ]]
    [ "$(echo "$output" | grep -vc '(open task)')" \
      -eq "$(echo "$knowledge_only" | grep -vc '(open task)')" ]
}

@test "A3 — a weak overlap stays below the floor" {
    # Three of four shared — one short of the floor, so right on the boundary.
    # On the real corpus this is where the junk lives: pairs scoring exactly 3
    # were "systemd template" against "PreToolUse hook".
    _task T-9001 "widget carburetor telemetry plimsoll"
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --query "widget carburetor telemetry harmonics"
    [[ "$output" != *"T-9001"* ]]
}

@test "A1 — a small corpus is not silenced by the frequency cut" {
    # int(2 * 0.10) == 0, so an unguarded ceiling of 1 would discard every word
    # shared by both fixtures and return nothing, forever, on any small project.
    _task T-9001 "widget carburetor telemetry harmonics plimsoll"
    _task T-9002 "widget carburetor telemetry harmonics resonance"
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --query "widget carburetor telemetry harmonics"
    [ "$(echo "$output" | grep -c '(open task)')" -eq 2 ]
}

@test "A3 — on the LIVE corpus the feature fires, but not for everybody" {
    # Fixtures prove the mechanism; only the real corpus proves the thresholds.
    # Both bounds matter and they fail in opposite directions: 0 means the floor
    # is too high and this shipped as a silent no-op, near-100% means it is too
    # low and every focus call gets noise.
    run python3 - "$FRAMEWORK_ROOT" <<'PY'
import importlib.util, sys
root = sys.argv[1]
spec = importlib.util.spec_from_file_location(
    "mr", root + "/agents/context/lib/memory-recall.py")
mr = importlib.util.module_from_spec(spec); spec.loader.exec_module(mr)
tasks = mr.load_open_tasks()
if len(tasks) < 50:
    print("SKIP small corpus", len(tasks)); sys.exit(0)
hits = 0
for t in tasks:
    others = [o for o in tasks if o["id"] != t["id"]]
    if mr.search_open_tasks(mr.get_task_context(t["id"]), others,
                            mr.OPEN_TASK_SLOTS):
        hits += 1
frac = hits / len(tasks)
print(f"{hits}/{len(tasks)} tasks have an open-task hit ({frac:.0%})")
sys.exit(0 if 0 < frac < 0.35 else 1)
PY
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "A1 — no .tasks/active/ at all is survivable" {
    rm -rf "$P/.tasks"
    _learning L-9001 "widget carburetor telemetry is the documented approach"
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --query "widget carburetor telemetry harmonics"
    [ "$status" -eq 0 ]
    [[ "$output" == *"L-9001"* ]]
}
