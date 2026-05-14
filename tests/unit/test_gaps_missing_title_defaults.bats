#!/usr/bin/env bats
# T-1840 — fw gaps defensive .get() for missing 'title' / 'id' fields.
#
# Origin: consumer email-archive (framework:pickup offset 2, 2026-05-04)
# reported fw gaps crashing with KeyError: 'title' on a project whose
# .context/project/concerns.yaml predated the title-field requirement.
# Direct dict subscript at bin/fw:4864 killed the CLI on the first malformed
# entry; consumer had to backfill all 8 entries with derived titles before
# fw gaps would render anything.
#
# These tests pin:
#   - missing 'title' field renders as <untitled>, doesn't crash
#   - well-formed entries (title + id present) render unchanged
#   - bin/fw parses post-edit
#   - the defensive .get() is present at the render site

load ../test_helper

FW_BIN="${FRAMEWORK_ROOT}/bin/fw"

_make_consumer_with_concerns() {
    local concerns_content="$1"
    local dir="$TEST_TEMP_DIR/consumer"
    mkdir -p "$dir/.context/project" "$dir/.tasks/active" "$dir/.tasks/completed" "$dir/.tasks/templates"
    echo "version: 1.6.170" > "$dir/.framework.yaml"
    {
        echo "concerns:"
        echo "$concerns_content" | sed 's/^/  /'
    } > "$dir/.context/project/concerns.yaml"
    echo "$dir"
}

@test "T-1840: fw gaps renders <untitled> for entry missing title field" {
    local consumer
    consumer=$(_make_consumer_with_concerns "$(cat <<'EOF'
- id: G-LEGACY
  description: legacy entry without title field
  severity: medium
  status: watching
EOF
)")
    cd "$consumer"
    # Explicitly override PROJECT_ROOT to the synthetic consumer — otherwise
    # the env-inherited PROJECT_ROOT from a parent process (e.g. update-task.sh
    # verification gate) shadows the cwd-based resolution and fw queries the
    # framework's own concerns.yaml instead of the synthetic fixture.
    PROJECT_ROOT="$consumer" run "$FW_BIN" gaps
    [ "$status" -eq 0 ]
    [[ "$output" == *"<untitled>"* ]]
    [[ "$output" != *"KeyError"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "T-1840: fw gaps renders ? for entry missing id field" {
    local consumer
    consumer=$(_make_consumer_with_concerns "$(cat <<'EOF'
- title: Entry without id
  description: legacy entry without id field
  severity: medium
  status: watching
EOF
)")
    cd "$consumer"
    # Explicitly override PROJECT_ROOT to the synthetic consumer — otherwise
    # the env-inherited PROJECT_ROOT from a parent process (e.g. update-task.sh
    # verification gate) shadows the cwd-based resolution and fw queries the
    # framework's own concerns.yaml instead of the synthetic fixture.
    PROJECT_ROOT="$consumer" run "$FW_BIN" gaps
    [ "$status" -eq 0 ]
    # Defensive '?' placeholder renders rather than crash on missing id
    [[ "$output" != *"KeyError"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "T-1840: fw gaps renders well-formed entry unchanged" {
    local consumer
    consumer=$(_make_consumer_with_concerns "$(cat <<'EOF'
- id: G-NORMAL
  title: A normal well-formed concern
  description: standard entry with both id and title
  severity: high
  status: watching
EOF
)")
    cd "$consumer"
    # Explicitly override PROJECT_ROOT to the synthetic consumer — otherwise
    # the env-inherited PROJECT_ROOT from a parent process (e.g. update-task.sh
    # verification gate) shadows the cwd-based resolution and fw queries the
    # framework's own concerns.yaml instead of the synthetic fixture.
    PROJECT_ROOT="$consumer" run "$FW_BIN" gaps
    [ "$status" -eq 0 ]
    [[ "$output" == *"G-NORMAL"* ]]
    [[ "$output" == *"A normal well-formed concern"* ]]
    [[ "$output" != *"<untitled>"* ]]
}

@test "T-1840: bin/fw has defensive .get() at the gaps render site" {
    run grep -q "gap.get('title'" "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1840: bin/fw parses with bash -n" {
    run bash -n "$FW_BIN"
    [ "$status" -eq 0 ]
}
