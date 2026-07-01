#!/bin/bash
# T-2420: test helper for check-task-ac-structure.bats
# Provides JSON payload builder for hook testing.

# Build Write tool payload
build_write_payload() {
    local file="$1"
    local content="$2"
    python3 -c "import json; print(json.dumps({
        'tool_name': 'Write',
        'tool_input': {
            'file_path': '$file',
            'content': $(printf '%s' "$content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
        }
    }))"
}

# Build Edit tool payload
build_edit_payload() {
    local file="$1"
    local old_string="$2"
    local new_string="$3"
    python3 -c "import json; print(json.dumps({
        'tool_name': 'Edit',
        'tool_input': {
            'file_path': '$file',
            'old_string': $(printf '%s' "$old_string" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'),
            'new_string': $(printf '%s' "$new_string" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
        }
    }))"
}

# Build MultiEdit tool payload
build_multiedit_payload() {
    local file="$1"
    shift
    # Args come in pairs: old_string new_string old_string new_string...
    local edits="["
    while [ $# -ge 2 ]; do
        local old="$1"
        local new="$2"
        shift 2
        edits+=$(python3 -c "import json; print(json.dumps({
            'old_string': $(printf '%s' "$old" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'),
            'new_string': $(printf '%s' "$new" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
        }))")
        [ $# -ge 2 ] && edits+=","
    done
    edits+="]"
    
    python3 -c "import json; print(json.dumps({
        'tool_name': 'MultiEdit',
        'tool_input': {
            'file_path': '$file',
            'edits': $edits
        }
    }))"
}
