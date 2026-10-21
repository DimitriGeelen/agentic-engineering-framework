#!/usr/bin/env bats
# T-4334 — the G-020 block message named one rule in its title and another in
# its Policy label ("Scope-Aware Task Gate" vs "Pickup message governance
# bypass prevention"), so a first-time agent could not tell which rule fired
# (dimitri-mint-dev T-133 F-09). Drives the REAL hook in a sandbox.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    SANDBOX="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$SANDBOX/.tasks/active" "$SANDBOX/.context/working" "$SANDBOX/src"
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s/src/app.py","content":"x"}}\n' \
        "$SANDBOX" > "$SANDBOX/in.json"
    cat > "$SANDBOX/.tasks/active/T-9001-t.md" <<'EOF'
---
id: T-9001
name: "t"
status: started-work
workflow_type: build
owner: agent
---

# T-9001

## Acceptance Criteria

### Agent
- [ ] [First criterion]
- [ ] [Second criterion]

## Verification
EOF
    printf 'current_task: T-9001\n' > "$SANDBOX/.context/working/focus.yaml"
}

_run_hook() {
    PROJECT_ROOT="$SANDBOX" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" CLAUDECODE=1 \
        bash "$HOOK" < "$SANDBOX/in.json"
}

@test "t4334: G-020 title and Policy label name the same rule" {
    run _run_hook
    [ "$status" -eq 2 ]
    title=$(printf '%s\n' "$output" | sed -n 's/.*(G-020: \([^)]*\)).*/\1/p' | head -1)
    label=$(printf '%s\n' "$output" | sed -n 's/^Policy: G-020 (\([^)]*\)).*/\1/p' | head -1)
    [ -n "$title" ] || { echo "no '(G-020: …)' title in block" >&2; echo "$output" >&2; return 1; }
    [ -n "$label" ] || { echo "no 'Policy: G-020 (…)' label in block" >&2; echo "$output" >&2; return 1; }
    [ "$title" = "$label" ] || { echo "title='$title' label='$label'" >&2; return 1; }
}

@test "t4334: the shared name is the build readiness gate" {
    run _run_hook
    [ "$status" -eq 2 ]
    printf '%s\n' "$output" | grep -q '^Policy: G-020 (Build readiness gate'
}
