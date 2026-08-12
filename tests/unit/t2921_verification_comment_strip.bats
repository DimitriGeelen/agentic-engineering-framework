#!/usr/bin/env bats
# T-2921 — the P-011 verification extractor must strip comments STRUCTURALLY.
#
# The block this extractor produces is handed to `eval`. So `<!--` opening a
# line is prose to discard, and the same delimiter inside a line is argument
# text belonging to a command. The pre-fix whole-block
# `re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)` could not tell them apart:
#
#   * mangled  — `sed '/<!--/,/-->/d' f` became `sed '/d' f` (errors; loud)
#   * deleted  — `.*?` spans newlines under DOTALL, so a mid-line `<!--` pairs
#                with the NEXT `-->` below, deleting every command between them
#                BEFORE `wc -l` counts them. The gate then prints "N/N passed"
#                over a population it silently shrank. Quiet, and worse.
#
# Legs 1-5 drive the real `extract_verification_block` from lib/verification-port.sh
# — the same expression the gate calls, not a re-typed copy (L-533). Legs 6-7
# drive the real `update-task.sh --status work-completed` end-to-end, because
# the extractor being right and the gate CALLING it are two different claims and
# the bug lives at the join (L-399).
#
# FALSIFICATION (must be re-run if this file is edited): restoring the one-line
# DOTALL strip in lib/verification-port.sh turns legs 1, 3, 6 and 7 red, and
# leaves 2, 4 and 5 green — 2 and 5 are no-regression legs that must survive
# both implementations, and 4 drives the old expression inline on purpose.
# Verified at author time; the pre-fix gate on leg 7's fixture printed
# "Running 2 verification command(s)" / "Verification: 2/2 passed" for a block
# of three commands whose middle member fails. A green suite over an unrestored
# fix proves nothing, so this run is part of the deliverable, not a courtesy.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working"
    source "$FRAMEWORK_ROOT/lib/verification-port.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Write a task file whose ## Verification block is exactly $2.
_write_task() {
    local task_id="$1" body="$2"
    local file="$PROJECT_ROOT/.tasks/active/${task_id}-test.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "Test task"
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# ${task_id}: Test

## Verification

${body}

## Decisions

None.
EOF
    echo "$file"
}

@test "T-2921 leg 1: a command carrying <!-- and --> as argument text survives byte-identical" {
    # The T-2862 origin shape. Pre-fix this came back as `sed '/d' f`.
    local file
    file=$(_write_task "T-2921a" "sed '/<!--/,/-->/d' somefile.txt")
    run extract_verification_block "$file"
    [ "$status" -eq 0 ]
    [ "$output" = "sed '/<!--/,/-->/d' somefile.txt" ]
}

@test "T-2921 leg 2: a structural comment block is still stripped in full" {
    # The behaviour T-2765 added and this fix must NOT regress: an opening
    # `<!--` as the first non-blank token is prose, including its closing line.
    local file
    file=$(_write_task "T-2921b" "echo one
<!-- guidance for the author
     spanning several lines
     and closing here -->
echo two
   <!-- indented single-line note -->
echo three")
    run extract_verification_block "$file"
    [ "$status" -eq 0 ]
    [ "$output" = "echo one
echo two
echo three" ]
}

@test "T-2921 leg 3: commands between a mid-line <!-- and a later --> are NOT swallowed" {
    # THE FALSE GREEN. Pre-fix, `.*?` under DOTALL paired the `<!--` inside the
    # first echo with the `-->` closing the real comment below it, deleting
    # `echo middle` and truncating the first line — so the gate ran fewer
    # commands than the author wrote and still reported all of them passing.
    local file
    file=$(_write_task "T-2921c" "echo 'open <!-- marker'
echo middle
<!-- a genuine comment
     that closes down here -->
echo tail")
    run extract_verification_block "$file"
    [ "$status" -eq 0 ]
    [ "$output" = "echo 'open <!-- marker'
echo middle
echo tail" ]
    # Count is the thing the gate reports N/N over — assert it directly.
    [ "$(printf '%s\n' "$output" | wc -l)" -eq 3 ]
}

@test "T-2921 leg 4: non-vacuity — the pre-fix strip really did corrupt these fixtures" {
    # Guards against the fixtures being trivially satisfiable. Runs the OLD
    # expression verbatim over leg 1's and leg 3's bodies and asserts it
    # produced something DIFFERENT from the file. If this leg ever goes green
    # by matching, the other legs are asserting nothing.
    local old_out
    old_out=$(printf '%s\n' "sed '/<!--/,/-->/d' somefile.txt" \
        | python3 -c "import re,sys;sys.stdout.write(re.sub(r'<!--.*?-->','',sys.stdin.read(),flags=re.DOTALL))")
    [ "$old_out" != "sed '/<!--/,/-->/d' somefile.txt" ]
    # And the swallow: old strip over leg 3's body loses `echo middle`.
    old_out=$(printf '%s\n' "echo 'open <!-- marker'
echo middle
<!-- a genuine comment
     that closes down here -->
echo tail" | python3 -c "import re,sys;sys.stdout.write(re.sub(r'<!--.*?-->','',sys.stdin.read(),flags=re.DOTALL))")
    ! printf '%s\n' "$old_out" | grep -q '^echo middle$'
}

@test "T-2921 leg 5: '#' comments, blanks and fences are still dropped" {
    # The other two filters in the pipeline are untouched by this change; if a
    # refactor ever drops them, template prose becomes executable again (T-2765).
    local file
    file=$(_write_task "T-2921d" "# a shell-style comment

\`\`\`
echo fenced
\`\`\`
echo real")
    run extract_verification_block "$file"
    [ "$status" -eq 0 ]
    [ "$output" = "echo fenced
echo real" ]
}

@test "T-2921 leg 6: the real P-011 gate executes a delimiter-carrying command and passes" {
    # End-to-end through update-task.sh. The extractor being correct and the
    # gate CALLING the extractor are separate claims (L-399: the bug lives at
    # the join). Pre-fix this fixture FAILED with sed's "no previous regular
    # expression"; the whole point is that it now passes.
    PROJECT="$(create_test_project)"
    TASK="$(create_test_task "$PROJECT" T-996 delimiter-cmd)"
    printf 'keep\n<!--\ndrop\n-->\nkeep2\n' > "$PROJECT/fixture.txt"
    python3 - "$TASK" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
t = p.read_text().replace(
    '## Verification\n\necho "ok"',
    "## Verification\n\n"
    "test \"$(sed '/<!--/,/-->/d' fixture.txt | tr -d '\\n')\" = 'keepkeep2'\n"
    "\n## Decisions\n\nNone.\n",
)
p.write_text(t)
PY
    sed -i 's/- \[ \] Test criterion/- [x] Test criterion/' "$TASK"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-996 --status work-completed
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [[ "$output" == *"Verification: 1/1 passed"* ]]
}

@test "T-2921 leg 7: a FAILING command is not silently deleted (the false green, end-to-end)" {
    # The harm, stated at its worst and asserted against the REAL gate.
    #
    # `echo one <!-- x` opens mid-line; the next `-->` is the close of the
    # genuine comment two lines below. Pre-fix, DOTALL `.*?` deleted everything
    # between them — including `test 1 -eq 2`, an assertion that FAILS. What
    # survived was `echo one ` and `echo two`, both valid, both passing. The
    # gate printed "Running 2 verification command(s)" and "2/2 passed" and let
    # the task close. Nothing was red. Nothing was logged. The author's failing
    # check had simply ceased to exist.
    #
    # That is why this fix matters more than the mangling that reported it: a
    # mangled command errors and gets noticed, a deleted one does not. Same
    # shape as the port-3000 class — a green line that asserts nothing is
    # indistinguishable from a green line that asserts everything.
    #
    # Post-fix the gate must SEE all three and REFUSE the close.
    PROJECT="$(create_test_project)"
    TASK="$(create_test_task "$PROJECT" T-995 swallow-failing-cmd)"
    python3 - "$TASK" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
t = p.read_text().replace(
    '## Verification\n\necho "ok"',
    "## Verification\n\n"
    "echo one <!-- x\n"
    "test 1 -eq 2\n"
    "<!-- a genuine comment\n"
    "     closing here -->\n"
    "echo two\n"
    "\n## Decisions\n\nNone.\n",
)
p.write_text(t)
PY
    sed -i 's/- \[ \] Test criterion/- [x] Test criterion/' "$TASK"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-995 --status work-completed
    # The whole population is visible...
    [[ "$output" == *"Running 3 verification command(s)"* ]]
    # ...the failing member is actually run and reported...
    [[ "$output" == *"FAIL: test 1 -eq 2"* ]]
    # ...and the close is REFUSED, which pre-fix it was not.
    [ "$status" -ne 0 ]
    [[ "$output" == *"Cannot complete"* ]]
}
