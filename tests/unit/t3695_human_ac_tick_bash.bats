#!/usr/bin/env bats
# T-3695: check-human-ac-tick extended to Bash, plus the post-hoc audit detector.
#
# Two claims per write path, so no test can pass by testing nothing:
#   1. VECTOR — run for real against a fixture, the command DOES tick the `### Human` box
#      (the path is a genuine bypass, not a no-op the guard trivially "refuses").
#   2. GUARD  — handed to the hook as a Bash tool call under CLAUDECODE=1, it exits 2.
# Controls show reads and unrelated writes still exit 0. Fixtures live in mktemp dirs.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TICKS="$FRAMEWORK_ROOT/lib/human_ac_ticks.py"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/reviews"
    TASK_REL=".tasks/active/T-9999-test.md"
    TASK_FILE="$TEST_ROOT/$TASK_REL"
    cat > "$TASK_FILE" <<'MD'
---
id: T-9999
name: "test"
status: started-work
workflow_type: build
---
# T-9999: test

## Acceptance Criteria

### Agent
- [ ] Agent AC one

### Human
- [ ] [REVIEW] Human AC one

## Verification

true
MD
    cp "$TASK_FILE" "$TEST_ROOT/pristine.md"
    printf '%s\n' "$(sed 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/' "$TASK_FILE")" > "$TEST_ROOT/ticked.md"
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK AI_AGENT
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

human_ticked() {
    sed -n '/^### Human/,/^## /p' "$TASK_FILE" | grep -q '^- \[x\]'
}

# Run the command for real in the fixture and require that it ticked the Human box.
assert_vector_ticks() {
    cp "$TEST_ROOT/pristine.md" "$TASK_FILE"
    run human_ticked
    [ "$status" -ne 0 ]
    run bash -c "cd '$TEST_ROOT' && $1"
    [ "$status" -eq 0 ]
    run human_ticked
    [ "$status" -eq 0 ]
    cp "$TEST_ROOT/pristine.md" "$TASK_FILE"
}

# The SAME command string: proven to tick for real, then refused by the hook.
assert_vector_refused() {
    assert_vector_ticks "$1"
    assert_refused "$1"
}

S="'s/- \[ \] \[REVIEW\]/- [x] [REVIEW]/'"

run_hook_bash() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "$1" "$TEST_ROOT")
    run bash "$HOOK_SH" <<< "$input"
}

assert_refused() {
    run_hook_bash "$1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SHELL WRITE TO A TASK FILE BLOCKED"* ]]
}

assert_allowed() {
    run_hook_bash "$1"
    [ "$status" -eq 0 ]
}

# ── write paths: vector is real AND the guard refuses ─────────────────────────

@test "sed -i: ticks for real, and is refused" {
    c="sed -i 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/' $TASK_REL"
    assert_vector_ticks "$c"
    assert_refused "$c"
}

@test "tee: ticks for real, and is refused" {
    c="sed 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/' $TASK_REL > /tmp/t3695-\$\$ && tee $TASK_REL < /tmp/t3695-\$\$ >/dev/null"
    assert_vector_ticks "$c"
    assert_refused "$c"
}

@test "redirect (>): ticks for real, and is refused" {
    c="cat ticked.md > $TASK_REL"
    assert_vector_ticks "$c"
    assert_refused "$c"
}

@test "cp over the task file: ticks for real, and is refused" {
    c="cp ticked.md $TASK_REL"
    assert_vector_ticks "$c"
    assert_refused "$c"
}

@test "python3 -c: ticks for real, and is refused" {
    c="python3 -c \"import pathlib; p = pathlib.Path('$TASK_REL'); p.write_text(p.read_text().replace('- [ ] [REVIEW]', '- [x] [REVIEW]'))\""
    assert_vector_ticks "$c"
    assert_refused "$c"
}

@test "perl -pi: ticks for real, and is refused" {
    c="perl -pi -e 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/' $TASK_REL"
    assert_vector_ticks "$c"
    assert_refused "$c"
}

@test "mv over / dd of=: tick for real, and are refused" {
    assert_vector_refused "cp ticked.md mv-src.md && mv mv-src.md $TASK_REL"
    assert_vector_refused "dd if=ticked.md of=$TASK_REL status=none"
}

@test "append (>>) of a ticked Human line is refused" {
    assert_refused "echo '- [x] [REVIEW] forged' >> $TASK_REL"
}

@test "indirect spellings each tick for real and are refused (same command string)" {
    assert_vector_refused "cd .tasks/active && sed -i $S T-9999-test.md"
    assert_vector_refused "sed -i $S .t*/act*/T-9999*"
    assert_vector_refused "F=$TASK_REL; sed -i $S \"\$F\""
    assert_vector_refused "ls .tasks/active/T-9999* | xargs sed -i $S"
    assert_vector_refused "find .tasks -name 'T-9999*' -exec sed -i $S {} \\;"
    assert_vector_refused "bash -c \"sed -i $S $TASK_REL\""
    assert_vector_refused "sed -i $S \$'\\x2etasks'/active/T-9999-test.md"
    assert_vector_refused "echo \$(sed -i $S $TASK_REL)"
    assert_vector_refused "python3 - <<'EOF'
import pathlib
p = pathlib.Path('$TASK_REL')
p.write_text(p.read_text().replace('- [ ] [REVIEW]', '- [x] [REVIEW]'))
EOF"
    assert_vector_refused "cat ticked.md | sudo -n tee $TASK_REL >/dev/null 2>&1 || cat ticked.md | env tee $TASK_REL >/dev/null"
}

@test "review round 1: attached sed -e, sed w-command, sed -f are refused" {
    assert_vector_refused "sed -i -e's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/' $TASK_REL"
    assert_vector_refused "sed -i -e 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/' -- $TASK_REL"
    assert_vector_refused "cp $TASK_REL src.md && sed -n 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/;w $TASK_REL' src.md"
    # s///w writes only the matched lines (it clobbers rather than ticks) — refusal only
    assert_refused "cp $TASK_REL src.md && sed 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/w $TASK_REL' src.md >/dev/null"
    assert_refused "sed -f /tmp/script.sed $TASK_REL"
}

@test "Watchtower tick endpoint and the provenance ledger are refused from Bash" {
    assert_refused "curl -s -X POST http://localhost:3000/api/task/T-9999/toggle-ac -d line=12"
    assert_refused "echo '{}' >> .context/reviews/human-ac-ticks.jsonl"
    assert_refused "python3 lib/human_ac_ticks.py ack T-9999 --ac 1 --i-am-human"
    assert_refused "git checkout HEAD~1 -- $TASK_REL"
}

@test "verb must be in command position: a quoted mention is not a write" {
    assert_allowed "echo 'sed -i x .tasks/active/T-9999-test.md'"
    assert_allowed "git commit -m 'T-3695: refuse sed -i on .tasks files' --dry-run"
    assert_allowed "grep -n 'tee' $TASK_REL"
}

# ── controls: reads and unrelated writes pass ─────────────────────────────────

@test "controls: reads of task files pass" {
    assert_allowed "cat $TASK_REL"
    assert_allowed "grep -n Human $TASK_REL"
    assert_allowed "sed -n 1,20p $TASK_REL"
    assert_allowed "awk '/^### /' $TASK_REL"
    assert_allowed "git diff -- $TASK_REL"
    assert_allowed "grep x $TASK_REL 2>&1 | head -3"
    assert_allowed "head -5 $TASK_REL > /tmp/t3695-read-copy"
    assert_allowed "cp $TASK_REL /tmp/t3695-copy.md"
    # review round 1 false positives
    assert_allowed "grep '>' $TASK_REL"
    assert_allowed "git show HEAD:$TASK_REL"
    assert_allowed "git cat-file -p HEAD:$TASK_REL"
    assert_allowed "awk 'NF > 0' $TASK_REL"
    assert_allowed "tar -cf /tmp/t3695-tasks.tar .tasks"
    assert_allowed "sed -n '/^### Human/,/^## /p' $TASK_REL"
}

@test "controls: unrelated writes and framework verbs pass" {
    assert_allowed "echo hi > /tmp/t3695-out.txt"
    assert_allowed "sed -i s/a/b/ /tmp/t3695-other.txt"
    assert_allowed "python3 -c 'print(1)' > /tmp/t3695-py.txt"
    assert_allowed "bin/fw task update T-9999 --status started-work"
    assert_allowed "bats tests/unit/t3695_human_ac_tick_bash.bats"
    # quoted prose naming the endpoint / ledger CLI is not a call (hit live filing T-3722)
    assert_allowed "bin/fw task create --name 'Watchtower toggle-ac writes a row via human_ac_ticks ack' --type build"
    assert_allowed "python3 lib/human_ac_ticks.py audit"
}

@test "no agent-control signal: Bash leg is advisory (exit 0, NOTE)" {
    unset CLAUDECODE
    run_hook_bash "sed -i s/a/b/ $TASK_REL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"advisory only"* ]]
}

@test "block message states the text-gate residual (scripts not inspected, T-2742)" {
    run_hook_bash "sed -i s/a/b/ $TASK_REL"
    [ "$status" -eq 2 ]
    [[ "$output" == *"script file"* ]]
    [[ "$output" == *"T-2742"* ]]
    [[ "$output" == *"fw audit"* ]]
}

# ── Write/Edit leg: appended ticked boxes and the ledger ──────────────────────

@test "Edit that APPENDS an already-ticked Human box is refused (zip blind spot)" {
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1],
  "old_string": "- [ ] [REVIEW] Human AC one\n", "new_string": "- [ ] [REVIEW] Human AC one\n- [x] [REVIEW] forged\n"}}))
' "$TASK_FILE")
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 2 ]
}

@test "Edit ticking a box under a SECOND ### Human section is refused (review round 1)" {
    printf '\n## Other\n\n### Human\n- [ ] [REVIEW] Second-section AC\n' >> "$TASK_FILE"
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1],
  "old_string": "- [ ] [REVIEW] Second-section AC", "new_string": "- [x] [REVIEW] Second-section AC"}}))
' "$TASK_FILE")
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 2 ]
}

@test "Write to the Human-tick ledger is refused under agent control" {
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": sys.argv[1], "content": "{}\n"}}))
' "$TEST_ROOT/.context/reviews/human-ac-ticks.jsonl")
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 2 ]
}

# ── post-hoc detector (fw audit) ──────────────────────────────────────────────

git_fixture() {
    cd "$TEST_ROOT"
    git init -q .
    git config user.email op@example.com
    git config user.name Operator
    cp pristine.md "$TASK_REL"
    git add "$TASK_REL"
    git commit -qm "T-9999: create"
}

commit_tick_as() {  # name email [message]
    cp "$TEST_ROOT/ticked.md" "$TASK_FILE"
    git -C "$TEST_ROOT" add "$TASK_REL"
    GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2" \
        git -C "$TEST_ROOT" commit -qm "${3:-T-9999: tick}"
}

@test "audit: tick committed by an agent worker identity FAILs and says AGENT" {
    git_fixture
    commit_tick_as "fw worker (termlink-dispatch)" "dispatch+abcd1234@aef.local"
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL T-9999 ticked"* ]]
    [[ "$output" == *"AGENT"* ]]
}

@test "audit: tick in a commit with a Claude co-author trailer FAILs as AGENT" {
    git_fixture
    commit_tick_as "Operator" "op@example.com" "T-9999: tick

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"AGENT"* ]]
}

@test "audit: tick by a human identity with no provenance still FAILs (not via Watchtower)" {
    git_fixture
    commit_tick_as "Operator" "op@example.com"
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"no Watchtower/operator record"* ]]
}

@test "audit: operator ack row makes the same tick pass; ack is refused under agent control" {
    git_fixture
    commit_tick_as "Operator" "op@example.com"
    run python3 "$TICKS" ack T-9999 --ac 1
    [ "$status" -eq 2 ]
    [[ "$output" == *"REFUSED"* ]]
    CLAUDECODE= run python3 "$TICKS" ack T-9999 --ac 1
    [ "$status" -eq 0 ]
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 0 ]
}

@test "audit: an ADDED already-ticked Human box FAILs" {
    git_fixture
    printf '%s\n' "$(sed 's/^- \[ \] \[REVIEW\] Human AC one/- [ ] [REVIEW] Human AC one\n- [x] [REVIEW] forged extra/' pristine.md)" > "$TASK_FILE"
    git add "$TASK_REL" && git commit -qm "T-9999: add"
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"added-ticked"* ]]
}

annotate_tick() {
    python3 - "$TASK_FILE" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("- [ ] [REVIEW] Human AC one",
    "- [x] [REVIEW] Human AC one\n  **Reviewer verdict:** green V-0001 — r (rung 1), digest d; dispatch x; evidence: e; ledger l")
open(p, "w").write(s)
PY
    git add "$TASK_REL" && git commit -qm "T-9999: verdict"
}

@test "audit: a FABRICATED verdict annotation does not exempt the tick (review round 1)" {
    git_fixture
    annotate_tick
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL T-9999 ticked"* ]]
}

@test "audit: an annotation backed by a green verdict row AND an applied tick is left to verdict_ledger" {
    git_fixture
    printf '%s\n' '{"id": "V-0001", "task": "T-9999", "ac": 1, "outcome": "green"}' > .context/reviews/verdicts.jsonl
    printf '%s\n' '{"task": "T-9999", "kind": "verdict-apply", "ticked": [{"ac": 1, "verdict_id": "V-0001"}]}' > .context/reviews/applied.jsonl
    annotate_tick
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 0 ]
    # a green row alone (no applied tick) is not enough
    : > .context/reviews/applied.jsonl
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
}

@test "audit: one ack licenses ONE tick — untick then re-tick FAILs again (review round 1)" {
    git_fixture
    commit_tick_as "Operator" "op@example.com"
    CLAUDECODE= run python3 "$TICKS" ack T-9999 --ac 1
    [ "$status" -eq 0 ]
    cp pristine.md "$TASK_FILE" && git add "$TASK_REL" && git commit -qm "T-9999: untick"
    commit_tick_as "Operator" "op@example.com" "T-9999: retick"
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"1 unprovenanced"* ]]
}

@test "audit: a tick under a SECOND ### Human section FAILs (review round 1)" {
    git_fixture
    printf '\n## Other\n\n### Human\n- [ ] [REVIEW] Second-section AC\n' >> "$TASK_FILE"
    git add "$TASK_REL" && git commit -qm "T-9999: second section"
    sed -i 's/- \[ \] \[REVIEW\] Second-section AC/- [x] [REVIEW] Second-section AC/' "$TASK_FILE"
    git add "$TASK_REL" && git commit -qm "T-9999: tick second"
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"Second-section AC"* ]]
}

@test "audit: a tick introduced only in a MERGE commit FAILs; one inherited from a branch is not double-counted" {
    git_fixture
    base=$(git rev-parse --abbrev-ref HEAD)
    git checkout -qb topic
    echo "other" > other.txt && git add other.txt && git commit -qm "T-9999: topic"
    git checkout -q "$base"
    echo "main" > main.txt && git add main.txt && git commit -qm "T-9999: main"
    git merge --no-ff --no-commit -q topic
    cp ticked.md "$TASK_FILE" && git add "$TASK_REL"
    git commit -qm "T-9999: merge"
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"in merge "* ]]
    [[ "$output" == *"1 unprovenanced"* ]]
}

@test "audit: a branch tick merged later is reported once (on the branch commit), not again on the merge" {
    git_fixture
    base=$(git rev-parse --abbrev-ref HEAD)
    git checkout -qb topic
    commit_tick_as "fw worker (x)" "dispatch+3@aef.local"
    git checkout -q "$base"
    echo "main" > main.txt && git add main.txt && git commit -qm "T-9999: main"
    git merge --no-ff -q -m "T-9999: merge topic" topic
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"1 unprovenanced"* ]]
}

@test "audit: inception decide's own tick records provenance (passes)" {
    git_fixture
    printf '%s\n' "$(sed 's/\[REVIEW\] Human AC one/[REVIEW] Review exploration findings and approve go\/no-go decision/' pristine.md)" > "$TASK_FILE"
    git add "$TASK_REL" && git commit -qm "T-9999: inception shape"
    FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$TEST_ROOT" bash -c \
        'source "$FRAMEWORK_ROOT/lib/inception.sh" >/dev/null 2>&1; tick_inception_decide_acs "$1"' _ "$TASK_FILE"
    run human_ticked
    [ "$status" -eq 0 ]
    git add "$TASK_REL" && git commit -qm "T-9999: decide"
    run python3 "$TICKS" audit --since 2000-01-01
    [ "$status" -eq 0 ]
    run grep -c inception-decide "$TEST_ROOT/.context/reviews/human-ac-ticks.jsonl"
    [ "$output" = "1" ]
}

@test "audit: range is ancestry from the detector commit — earlier ticks not re-judged, backdating does not escape" {
    git_fixture
    commit_tick_as "fw worker (x)" "dispatch+1@aef.local"
    mkdir -p lib && echo "# detector" > lib/human_ac_ticks.py
    git add lib/human_ac_ticks.py && git commit -qm "T-9999: detector lands"
    run python3 "$TICKS" audit
    [ "$status" -eq 0 ]
    # a later tick, committed with a committer date years in the past, is still judged
    cp pristine.md "$TASK_FILE" && git add "$TASK_REL" && git commit -qm "T-9999: untick"
    cp ticked.md "$TASK_FILE" && git add "$TASK_REL"
    GIT_COMMITTER_DATE="2001-01-01T00:00:00Z" GIT_AUTHOR_DATE="2001-01-01T00:00:00Z" \
        git -c user.email=dispatch+2@aef.local commit -qm "T-9999: backdated tick"
    run python3 "$TICKS" audit
    [ "$status" -eq 2 ]
    [[ "$output" == *"AGENT"* ]]
}
