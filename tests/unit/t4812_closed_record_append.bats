#!/usr/bin/env bats
# T-4812: the close path appended its final status-update entry at END OF FILE,
# after the '## Reviewer Verdict (v1.5)' block the close writes behind ## Updates.
# The visually-last Updates entry then sat outside ## Updates, and the T-4285
# closed-record gate refused its own documented append route (old_string = the
# file's last lines, new_string = the same + an entry). Writers now insert the
# entry at the end of the ## Updates section.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    PROJECT="$(create_test_project)"
    TASK="$(create_test_task "$PROJECT" T-998 closed-append)"
    # Shape of a real task: ## Updates with the created entry, then a Reviewer
    # Verdict block below it (as the close writes it).
    cat >> "$TASK" <<'EOF'

## Updates

### 2026-01-01T00:00:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent

## Reviewer Verdict (v1.5)

**Overall:** PASS
EOF
    sed -i 's/- \[ \] Test criterion/- [x] Test criterion/' "$TASK"
    sed -i 's/^echo "ok"$/test -f .framework.yaml/' "$TASK"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_close() {
    (cd /tmp && unset CLAUDECODE AI_AGENT && PROJECT_ROOT="$PROJECT" \
        "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed) >/dev/null 2>&1
}

_closed_file() {
    ls "$PROJECT"/.tasks/completed/T-998-*.md
}

_gate() {
    # $1 file, $2 old, $3 new — runs the PreToolUse gate under agent control
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Edit','tool_input':{'file_path':sys.argv[1],'old_string':sys.argv[2],'new_string':sys.argv[3]}}))" "$1" "$2" "$3")
    printf 'current_task: T-001\n' > "$PROJECT/.context/working/focus.yaml"
    echo "$json" | CLAUDECODE=1 PROJECT_ROOT="$PROJECT" bash "$HOOK"
}

@test "close writes its status-update entry inside ## Updates, before ## Reviewer Verdict" {
    _close
    f=$(_closed_file)
    python3 - "$f" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
u = re.search(r'^## Updates[ \t]*$', t, re.M).end()
v = re.search(r'^## Reviewer Verdict', t, re.M).start()
i = t.index('status: started-work → work-completed')
assert u < i < v, (u, i, v)
# nothing Updates-shaped is left below the verdict
assert '— status-update' not in t[v:], t[v:]
PY
}

@test "documented append Edit (last lines of ## Updates) on a freshly closed task passes the gate" {
    _close
    f=$(_closed_file)
    old=$(python3 - "$f" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
v = re.search(r'^## Reviewer Verdict', t, re.M).start()
print('\n'.join(t[:v].rstrip('\n').split('\n')[-2:]))
PY
)
    [[ "$old" == *"work-completed"* ]]
    run _gate "$f" "$old" "$old
- **Note:** appended after close"
    [ "$status" -eq 0 ]
}

@test "non-append Edit (rewriting an AC) on the closed task is still refused" {
    _close
    f=$(_closed_file)
    run _gate "$f" "- [x] Test criterion" "- [x] Test criterion rewritten"
    [ "$status" -eq 2 ]
}

@test "append that adds a '## ' section inside ## Updates is still refused" {
    _close
    f=$(_closed_file)
    run _gate "$f" "- **Change:** status: started-work → work-completed" "- **Change:** status: started-work → work-completed

## Sneaky"
    [ "$status" -eq 2 ]
}

@test "task with no ## Updates section still gets its entry (appended at end)" {
    python3 - "$TASK" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
t = t[:t.index('\n## Updates')] + '\n'
open(p, 'w').write(t)
PY
    _close
    f=$(_closed_file)
    grep -q 'status: started-work → work-completed' "$f"
}
