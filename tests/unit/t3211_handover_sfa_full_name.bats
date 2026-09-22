#!/usr/bin/env bats
# T-3211 — handover's "Suggested First Action" truncated the task name at the
# first physical line of a folded/quoted multi-line YAML `name:` scalar (the
# template's normal shape for long names), leaving an unclosed opening quote.
#
# Root cause (agents/handover/handover.sh, Suggested First Action block,
# formerly ~line 1341): `re.search(r'^name:\s*(.+)', content, re.M)` reads
# only the first physical line. Fixed by parsing the frontmatter as YAML
# (falling back to joining indented continuation lines when it doesn't
# parse) via a local `extract_frontmatter_name()` helper.
#
# Same _selector extraction technique as tests/unit/t3210_handover_suggested_action.bats
# (carves the shipped `$(python3 -c "...")` block out of handover.sh and runs
# it against a synthetic task tree) — a test that reimplements the selection
# logic instead of running the shipped block cannot detect regressions in it.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    T="$TEST_TEMP_DIR"
    mkdir -p "$T/tasks/active" "$T/context/working"
}
teardown() { rm -rf "$TEST_TEMP_DIR"; }

_selector() {
    local s b e
    s=$(grep -n '^candidates = \[\]$' "$HANDOVER" | cut -d: -f1)
    [ -n "$s" ] || return 91
    b=$(awk -v s="$s" 'NR<s && /^\$\(python3 -c "$/{l=NR} END{print l}' "$HANDOVER")
    e=$(awk -v s="$s" 'NR>s && /^" 2>\/dev\/null \|\| echo "See active tasks"\)$/{print NR; exit}' "$HANDOVER")
    [ -n "$b" ] && [ -n "$e" ] || return 91
    sed -n "${b},${e}p" "$HANDOVER" > "$T/block.txt"
    { printf 'SFA='; cat "$T/block.txt"; printf '\nprintf %%s "$SFA"\n'; } > "$T/run.sh"
    TASKS_DIR="$T/tasks" CONTEXT_DIR="$T/context" bash "$T/run.sh"
}

@test "t3211: a three-line folded name renders in full, no dangling quote" {
    cat > "$T/tasks/active/T-5000.md" <<'EOF'
---
id: T-5000
name: "handover Suggested First Action truncates the task name at the first
  line of a folded YAML scalar spanning three physical lines in the
  frontmatter block"
status: started-work
horizon: now
owner: agent
last_update: 2026-09-22T18:00:00Z
---
EOF
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-5000:"* ]]
    # Last words of the folded name must survive — the old one-line regex
    # cut the string mid-sentence at "at the first".
    [[ "$output" == *"frontmatter block"* ]]
    # No dangling opening quote: the rendered name must not contain a bare
    # unclosed double quote (a closed quote pair is fine; an odd count is not).
    quote_count=$(printf '%s' "$output" | tr -cd '"' | wc -c)
    [ "$((quote_count % 2))" -eq 0 ]
}

@test "t3211: a one-line name is unchanged (CONTROL)" {
    cat > "$T/tasks/active/T-5001.md" <<'EOF'
---
id: T-5001
name: "a plain one-line task name"
status: started-work
horizon: now
owner: agent
last_update: 2026-09-22T18:00:00Z
---
EOF
    run _selector
    [ "$status" -eq 0 ]
    [ "$output" = "Continue T-5001: a plain one-line task name" ]
}

@test "t3211: handover.sh no longer contains the truncating one-line name regex" {
    # grep -c exits 1 on zero matches (normal grep behaviour) — the count on
    # stdout is the assertion, not the exit status.
    run grep -cF "re.search(r'^name:" "$HANDOVER"
    [ "$output" -eq 0 ]
}

@test "t3211: handover.sh passes shell syntax check" {
    run bash -n "$HANDOVER"
    [ "$status" -eq 0 ]
}
