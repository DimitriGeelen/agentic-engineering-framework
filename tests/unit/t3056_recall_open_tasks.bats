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

# T-4137: the thresholds used to be proven against the LIVE corpus (hit fraction
# strictly between 0 and 0.5). That anchor rots as the corpus moves (T-3326) and,
# worse, a fraction says nothing about whether the hits are right. It went red at
# 51% because precision had fallen to 12/30 — paragraph-length names absorbing
# generic words. Pinned now against a committed fixture of real task names with
# labeled related/unrelated pairs; the live fraction is printed, not asserted.
FIXTURE="tests/fixtures/t4137_recall_precision.yaml"

_fixture_check() {  # _fixture_check <memory-recall.py>
    python3 - "$1" "$FRAMEWORK_ROOT/$FIXTURE" "$P" <<'PY'
import importlib.util, os, sys, yaml
mod, fixture, proj = sys.argv[1:4]
fx = yaml.safe_load(open(fixture))
active = os.path.join(proj, ".tasks", "active")
os.makedirs(active, exist_ok=True)
for t in fx["tasks"]:
    lines = ["---", "id: " + t["id"],
             "name: " + yaml.safe_dump(t["name"], width=10**6).splitlines()[0],
             "status: started-work"]
    if t.get("description"):
        lines += ["description: >", "  " + t["description"]]
    if t.get("tags"):
        lines += ["tags: [%s]" % t["tags"]]
    with open(os.path.join(active, t["id"] + "-fixture.md"), "w") as fh:
        fh.write("\n".join(lines + ["---", ""]))
os.environ["PROJECT_ROOT"] = proj
spec = importlib.util.spec_from_file_location("mr", mod)
mr = importlib.util.module_from_spec(spec); spec.loader.exec_module(mr)
tasks = mr.load_open_tasks()
# Below DF_MIN_CORPUS the weighted path is off and this would prove nothing.
assert len(tasks) == len(fx["tasks"]) >= mr.DF_MIN_CORPUS, len(tasks)

def hits(q):
    others = [t for t in tasks if t["id"] != q]
    return [i["id"] for _s, i in mr.search_open_tasks(
        mr.get_task_context(q), others, mr.OPEN_TASK_SLOTS)]

fails, tp, fp = [], 0, 0
for r in fx["related"]:
    ok = r["expect"] in hits(r["query"]); tp += ok
    if not ok:
        fails.append(f"MISS  {r['query']} -> {r['expect']}")
for kind in ("unrelated", "marginal"):
    for u in fx[kind]:
        bad = u["never"] in hits(u["query"]); fp += bad
        if bad and kind == "unrelated":
            fails.append(f"NOISE {u['query']} -> {u['never']}")
for q in fx["no_hit"]:
    if hits(q):
        fails.append(f"NOISE {q} -> {hits(q)}")
prec = tp / (tp + fp) if tp + fp else 0.0
print(f"labeled precision {tp}/{tp + fp} = {prec:.2f}")
if prec < 0.8:
    fails.append(f"precision {prec:.2f} < 0.80")
print("\n".join(fails) or "all fixture assertions hold")
sys.exit(1 if fails else 0)
PY
}

@test "A3 — fixture: related tasks are offered, unrelated ones are not (precision)" {
    run _fixture_check "$FRAMEWORK_ROOT/$RECALL"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"all fixture assertions hold"* ]]
}

@test "A3 — fixture bites: the unweighted word-count floor alone fails it (mutation)" {
    # OPEN_TASK_MIN_SCORE = 0 is the pre-T-4137 filter: four shared words, any
    # words, any name length. If this passes, the fixture no longer encodes the
    # failure it was built from.
    local m="$TEST_TEMP_DIR/mr-noscore.py"
    sed 's/^OPEN_TASK_MIN_SCORE = .*/OPEN_TASK_MIN_SCORE = 0.0/' \
        "$FRAMEWORK_ROOT/$RECALL" > "$m"
    run cmp -s "$m" "$FRAMEWORK_ROOT/$RECALL"
    [ "$status" -ne 0 ]                     # the substitution must have landed
    run _fixture_check "$m"
    echo "$output"
    [ "$status" -ne 0 ]
    [[ "$output" == *"NOISE"* ]]
}

@test "A3 — live corpus hit fraction (informational, never asserted — T-3326)" {
    run python3 - "$FRAMEWORK_ROOT" <<'PY'
import importlib.util, sys
root = sys.argv[1]
spec = importlib.util.spec_from_file_location(
    "mr", root + "/agents/context/lib/memory-recall.py")
mr = importlib.util.module_from_spec(spec); spec.loader.exec_module(mr)
tasks = mr.load_open_tasks()
hits = sum(1 for t in tasks if mr.search_open_tasks(
    mr.get_task_context(t["id"]), [o for o in tasks if o["id"] != t["id"]],
    mr.OPEN_TASK_SLOTS))
print(f"live: {hits}/{len(tasks)} open tasks have an open-task hit")
PY
    echo "# $output" >&3
    [ "$status" -eq 0 ]
}

@test "A1 — no .tasks/active/ at all is survivable" {
    rm -rf "$P/.tasks"
    _learning L-9001 "widget carburetor telemetry is the documented approach"
    run _run_recall "$FRAMEWORK_ROOT/$RECALL" --query "widget carburetor telemetry harmonics"
    [ "$status" -eq 0 ]
    [[ "$output" == *"L-9001"* ]]
}
