#!/usr/bin/env bats
# T-4983 (G-126): a write whose target is only known at run time (`p=/srv/x; echo x >> "$p"`)
# was not judged in boundary mode, so it wrote outside the project. It is now refused when the
# command names a path outside the boundary anywhere (the T-4487 mention gate); a variable that
# names nothing outside (`o=$(mktemp)`, an in-project file) stays allowed.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
}

run_hook() {
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$1")
    echo "$payload" | bash "$HOOK"
}

blocks() {
    run run_hook "$1"
    [ "$status" -eq 2 ]
}

allows() {
    run run_hook "$1"
    [ "$status" -eq 0 ]
}

# ── the reproduction (codex review of T-4965, finding 4) ──
@test "assignment then append through the variable" { blocks 'p=/srv/other/x.txt; echo x >> "$p"'; }
@test "export then braced variable" { blocks 'export p=/srv/other/x.txt && echo x > "${p}"'; }
@test "unquoted variable" { blocks 'p=/srv/other/x.txt; echo x > $p'; }
@test "tee to a variable" { blocks 'p=/srv/other/x.txt; echo x | tee "$p"'; }
@test "cp to a variable" { blocks 'd=/srv/other; cp /tmp/a "$d/x"'; }

# ── controls: nothing outside is named, so the run-time target stays allowed ──
@test "control: mktemp variable" { allows 'o=$(mktemp); echo x > "$o"'; }
@test "control: in-project relative variable" { allows 'f=out.txt; echo x > "$f"'; }
@test "control: /tmp variable" { allows 'p=/tmp/a; echo x >> "$p"'; }
@test "control: unset variable names nothing" { allows 'echo x > "$OUT"'; }
@test "control: literal outside write is still refused as before" { blocks 'echo x >> /srv/other/x.txt'; }
