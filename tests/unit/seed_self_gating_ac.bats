#!/usr/bin/env bats
# T-2862 — no seeded Agent AC may name the command that closes its own task.
#
# Origin: lib/seeds/tasks/greenfield/T-002-define-project-goals.md shipped
#
#   - [ ] Go/no-go decision recorded: `fw inception decide T-002 go --rationale "..."`
#
# as an Agent AC. The decide preflight refuses while any Agent AC is unchecked,
# and that AC *was* the decision — so every greenfield project's first inception
# was un-completable by construction. `fw init` seeds these files into every new
# project, which makes a seed defect a defect in every consumer at once.
#
# The property pinned here is deliberately narrower than "no AC mentions a
# command": an AC may legitimately name `fw task update ... --status
# work-completed` when it refers to a DIFFERENT task the learner creates (the
# T-004 lifecycle exercise does exactly this, and is correct). The defect is
# self-reference — an AC in task T-NNN naming a closing command aimed at T-NNN
# itself, or at the task file's own id placeholder.
#
# ANTI-VACUITY: `test_detects_the_original_defect` reconstructs the shipped
# pre-fix line in a fixture and asserts the scanner flags it. Without that, a
# green run over an already-clean corpus proves only that the corpus is clean
# today — not that the scanner can see anything at all.

load ../test_helper

SEEDS_DIR="$FRAMEWORK_ROOT/lib/seeds/tasks"

# Emit one line per offending "<file>:<ac text>" found under $1.
# An Agent AC is self-gating when it names a closing verb AND the task id it
# targets is this file's own id (or the file's own id placeholder).
_scan_self_gating() {
    local root="$1"
    local f own_id agent_acs
    while IFS= read -r f; do
        own_id=$(grep -m1 '^id:' "$f" | sed 's/^id:[[:space:]]*//' | tr -d '"' | tr -d "'")
        [ -n "$own_id" ] || continue
        agent_acs=$(awk '/^### Agent/{a=1;next} /^### |^## /{a=0} a' "$f" \
                    | grep -E '^\s*-\s*\[[ x]\]' || true)
        [ -n "$agent_acs" ] || continue
        while IFS= read -r ac; do
            [ -n "$ac" ] || continue
            # Closing verbs: the two commands that refuse while ACs are unchecked.
            echo "$ac" | grep -qE 'inception decide|--status work-completed' || continue
            # Self-reference: the AC names this file's own task id.
            if echo "$ac" | grep -qE "(^|[^A-Za-z0-9-])${own_id}([^0-9]|$)"; then
                echo "$f: $ac"
            fi
        done <<< "$agent_acs"
    done < <(find "$root" -name '*.md' -type f | sort)
}

@test "T-2862: the shipped seed corpus has no self-gating Agent AC" {
    run _scan_self_gating "$SEEDS_DIR"
    [ "$status" -eq 0 ]
    if [ -n "$output" ]; then
        echo "Self-gating Agent AC(s) found — these deadlock task closure:" >&2
        echo "$output" >&2
    fi
    [ -z "$output" ]
}

@test "T-2862: anti-vacuity — the scanner detects the original defect" {
    local fixture="$BATS_TEST_TMPDIR/seeds"
    mkdir -p "$fixture"
    cat > "$fixture/T-002-repro.md" <<'EOF'
---
id: T-002
name: "repro"
workflow_type: inception
---

## Acceptance Criteria

### Agent
- [ ] Research artifact exists: `docs/reports/T-002-*.md`
- [ ] Go/no-go decision recorded: `fw inception decide T-002 go --rationale "..."`
EOF
    run _scan_self_gating "$fixture"
    [ "$status" -eq 0 ]
    [[ "$output" == *"inception decide T-002"* ]]
}

@test "T-2862: an AC targeting a DIFFERENT task is not flagged (T-004 lifecycle)" {
    local fixture="$BATS_TEST_TMPDIR/seeds-ok"
    mkdir -p "$fixture"
    cat > "$fixture/T-004-lifecycle.md" <<'EOF'
---
id: T-004
name: "lifecycle"
workflow_type: build
---

## Acceptance Criteria

### Agent
- [ ] Create a new task: `fw work-on "description" --type build`
- [ ] Set status to work-completed: `fw task update T-XXX --status work-completed`
EOF
    run _scan_self_gating "$fixture"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-2862: greenfield T-002 no longer instructs the agent to run decide" {
    local seed="$SEEDS_DIR/greenfield/T-002-define-project-goals.md"
    [ -f "$seed" ]
    local agent_acs
    agent_acs=$(awk '/^### Agent/{a=1;next} /^### |^## /{a=0} a' "$seed" \
                | grep -E '^\s*-\s*\[[ x]\]' || true)
    # `fw inception decide` is agent-blocked under $CLAUDECODE=1 (T-1259) — an
    # Agent AC must never instruct the agent to run it.
    run bash -c "echo '$agent_acs' | grep -c 'inception decide' || true"
    [ "$output" = "0" ]
    # …and the handoff that replaced it is present.
    [[ "$agent_acs" == *"fw task review T-002"* ]]
}
