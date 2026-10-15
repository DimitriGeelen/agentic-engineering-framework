#!/usr/bin/env bats
# T-4213 (T-4202 leg B) — check-visual-verification gate, render-surface checklist.
# A temp consumer-shaped project: git repo, focus on T-9001, a task file, staged files.
# The hook is driven with the same stdin JSON Claude Code sends (tool_name, command, cwd).

HOOK="$BATS_TEST_DIRNAME/../../agents/context/check-visual-verification.sh"

setup() {
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/web/blueprints" "$PROJ/docs"
    git -C "$PROJ" init -q
    echo "current_task: T-9001" > "$PROJ/.context/working/focus.yaml"
    TASK="$PROJ/.tasks/active/T-9001-render-thing.md"
    printf -- '---\nid: T-9001\nname: render\n---\n\n# T-9001\n\n## Verification\n\ntrue\n' > "$TASK"
    echo "x = 1" > "$PROJ/web/blueprints/x.py"
    echo "# readme" > "$PROJ/docs/readme.md"
    echo "body{}" > "$PROJ/web/app.css"
}

# Run the hook as a `git commit` PreToolUse call from $PROJ.
run_hook() {
    local payload
    payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m \\"T-9001: x\\""},"cwd":"%s"}' "$PROJ")
    run env PROJECT_ROOT="$PROJ" FW_UX_SHOT_WIDTHS="${FW_UX_SHOT_WIDTHS:-}" bash "$HOOK" <<< "$payload"
}

shot() { # shot <state> <width>: create an (empty) screenshot file at the convention path
    mkdir -p "$PROJ/.context/visual/T-9001"
    : > "$PROJ/.context/visual/T-9001/$1@$2.png"
}

stage() { git -C "$PROJ" add "$@"; }

write_checklist() { # $1: table rows (after the header); replaces any earlier checklist
    printf -- '---\nid: T-9001\nname: render\n---\n\n# T-9001\n\n## Verification\n\ntrue\n' > "$TASK"
    cat >> "$TASK" <<EOF

## Visual Verification

Screenshots: see \`fw ux shots\`.

| state | control | 1024 | 1440 | 1920 | note |
|-------|---------|------|------|------|------|
$1
EOF
}

@test "T-4213: render-surface .py commit with no Visual Verification section is refused" {
    stage web/blueprints/x.py
    run_hook
    [ "$status" -eq 2 ]
    [[ "$output" == *"no \`## Visual Verification\` section"* ]]
}

@test "T-4213: complete checklist with three widths of shots is allowed" {
    write_checklist "| toolbar | Load | ok | ok | ok | |
| toolbar | Save | ok | ok | ok | |"
    shot toolbar 1024; shot toolbar 1440; shot toolbar 1920
    stage web/blueprints/x.py
    run_hook
    [ "$status" -eq 0 ]
}

@test "T-4213: a listed state with only two widths of screenshots is refused" {
    write_checklist "| toolbar | Load | ok | ok | ok | |"
    shot toolbar 1024; shot toolbar 1440
    stage web/blueprints/x.py
    run_hook
    [ "$status" -eq 2 ]
    [[ "$output" == *"state 'toolbar': 2 width(s)"* ]]
    [[ "$output" == *"missing [1920]"* ]]
}

@test "T-4213: a blank checklist cell is refused" {
    write_checklist "| toolbar | Load | ok |  | ok | |"
    shot toolbar 1024; shot toolbar 1440; shot toolbar 1920
    stage web/blueprints/x.py
    run_hook
    [ "$status" -eq 2 ]
    [[ "$output" == *"blank cell: toolbar / Load @ 1440"* ]]
}

@test "T-4213: a cell outside ok/clipped/hidden/overlap/unreachable is refused" {
    write_checklist "| toolbar | Load | ok | maybe | ok | |"
    shot toolbar 1024; shot toolbar 1440; shot toolbar 1920
    stage web/blueprints/x.py
    run_hook
    [ "$status" -eq 2 ]
    [[ "$output" == *"'maybe' is not one of"* ]]
}

@test "T-4213: a non-ok cell without a note is refused; with a note it passes" {
    write_checklist "| toolbar | Save | ok | clipped | ok | |"
    shot toolbar 1024; shot toolbar 1440; shot toolbar 1920
    stage web/blueprints/x.py
    run_hook
    [ "$status" -eq 2 ]
    [[ "$output" == *"non-ok cell 'clipped' without a note"* ]]

    write_checklist "| toolbar | Save | ok | clipped | ok | Save cut off below 1440 |"
    stage web/blueprints/x.py
    run_hook
    [ "$status" -eq 0 ]
}

@test "T-4213: checklist width columns must equal the configured UX_SHOT_WIDTHS" {
    FW_UX_SHOT_WIDTHS="800,1280,1600"
    write_checklist "| toolbar | Load | ok | ok | ok | |"
    shot toolbar 800; shot toolbar 1280; shot toolbar 1600
    stage web/blueprints/x.py
    run_hook
    [ "$status" -eq 2 ]
    [[ "$output" == *"must equal UX_SHOT_WIDTHS"* ]]
}

@test "T-4213: an inert example in an HTML comment does not satisfy the gate" {
    cat >> "$TASK" <<'EOF'

<!--
## Visual Verification
| state | control | 1024 | 1440 | 1920 | note |
| toolbar | Load | ok | ok | ok | |
-->
EOF
    stage web/blueprints/x.py
    run_hook
    [ "$status" -eq 2 ]
}

@test "T-4213: non-render commit (docs only) with no checklist is still allowed" {
    stage docs/readme.md
    run_hook
    [ "$status" -eq 0 ]
}

@test "T-4213: existing css commit behaviour is unchanged (missing section refused with the old message)" {
    stage web/app.css
    run_hook
    [ "$status" -eq 2 ]
    [[ "$output" == *"Missing: a '## Visual Verification' section"* ]]
}
