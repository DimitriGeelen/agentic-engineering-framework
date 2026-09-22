#!/usr/bin/env bats
# T-3430: `fw fabric register` derives purpose/subsystem instead of writing
# placeholders — and says so out loud when it cannot.
#
# The card is the artefact a human (and every index over .fabric/) reads, so
# the properties pinned here are: a described file gets a real sentence plus
# its provenance; an undescribed file keeps the TODO *and* prints the refusal;
# and the subsystem routes off .fabric/subsystems.yaml paths: patterns rather
# than the hard-coded case block register.sh used to carry.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.fabric/components" "$TMP_PROJECT/lib" \
             "$TMP_PROJECT/web/static/css" "$TMP_PROJECT/vendor/thirdparty" \
             "$TMP_PROJECT/.tasks/active"

    cat > "$TMP_PROJECT/.fabric/subsystems.yaml" <<'YAML'
subsystems:
  - id: framework-core
    name: Framework Core
    paths:
      - "lib/*"
  - id: watchtower
    name: Watchtower
    paths:
      - "web/*"
YAML

    cat > "$TMP_PROJECT/lib/rotate.sh" <<'SH'
#!/bin/bash
# Rotate the fleet certificates across every registered node.
set -euo pipefail
SH

    cat > "$TMP_PROJECT/lib/quoted.py" <<'PY'
#!/usr/bin/env python3
r"""Emit a "quoted" $PATH banner with a \backslash and `backticks` in it."""
PY

    printf 'body { margin: 0; }\n' > "$TMP_PROJECT/web/static/css/style.css"
    printf 'x = 1\n' > "$TMP_PROJECT/vendor/thirdparty/mystery.py"

    cat > "$TMP_PROJECT/.tasks/active/T-4242-restyle.md" <<'MD'
---
id: T-4242
name: "Restyle the task list so long titles wrap instead of clipping"
---
MD

    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR="$FABRIC_DIR/components"
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""

    ensure_fabric_dirs() { :; }
    export -f ensure_fabric_dirs 2>/dev/null || true

    # shellcheck source=agents/fabric/lib/register.sh
    source "$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

@test "T-3430: a described file gets a real purpose and purpose_source: header-comment" {
    run do_register "lib/rotate.sh"
    [ "$status" -eq 0 ]
    local card="$COMPONENTS_DIR/lib-rotate.yaml"
    [ -f "$card" ]
    grep -q 'purpose: "Rotate the fleet certificates across every registered node."' "$card"
    grep -q '^purpose_source: header-comment$' "$card"
    ! grep -q 'TODO: describe what this component does' "$card"
}

@test "T-3430: a python docstring is recorded as purpose_source: docstring" {
    run do_register "lib/quoted.py"
    [ "$status" -eq 0 ]
    grep -q '^purpose_source: docstring$' "$COMPONENTS_DIR/lib-quoted.yaml"
}

@test "T-3430: quotes, dollars and backslashes in a purpose survive as valid YAML" {
    run do_register "lib/quoted.py"
    [ "$status" -eq 0 ]
    # The whole point of the base64 bridge: the card still parses.
    run python3 -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); print(d['purpose'])" \
        "$COMPONENTS_DIR/lib-quoted.yaml"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"quoted"'* ]]
    [[ "$output" == *'$PATH'* ]]
}

@test "T-3430: an undescribed file keeps the TODO and the run PRINTS the refusal" {
    run do_register "web/static/css/style.css"
    [ "$status" -eq 0 ]
    [[ "$output" == *"describes itself nowhere"* ]]
    [[ "$output" == *"write a header comment"* ]]
    local card="$COMPONENTS_DIR/web-static-css-style.yaml"
    grep -q 'TODO: describe what this component does' "$card"
    grep -q '^purpose_source: none$' "$card"
}

@test "T-3430: the created_by task title is the fallback when the file has no header" {
    CURRENT_TASK=T-4242 run do_register "web/static/css/style.css"
    [ "$status" -eq 0 ]
    local card="$COMPONENTS_DIR/web-static-css-style.yaml"
    grep -q '^purpose_source: task-title$' "$card"
    grep -q 'Restyle the task list' "$card"
    [[ "$output" != *"describes itself nowhere"* ]]
}

@test "T-3430: subsystem routes off subsystems.yaml paths: patterns" {
    run do_register "web/static/css/style.css"
    [ "$status" -eq 0 ]
    grep -q '^subsystem: watchtower$' "$COMPONENTS_DIR/web-static-css-style.yaml"
}

@test "T-3430: an unroutable path stays unknown and PRINTS why" {
    run do_register "vendor/thirdparty/mystery.py"
    [ "$status" -eq 0 ]
    grep -q '^subsystem: unknown$' "$COMPONENTS_DIR/vendor-thirdparty-mystery.yaml"
    [[ "$output" == *"no subsystem rule matches"* ]]
    [[ "$output" == *"subsystems.yaml"* ]]
}

@test "T-3430: every card register writes is still parseable YAML" {
    do_register "lib/rotate.sh"
    do_register "lib/quoted.py"
    do_register "web/static/css/style.css"
    run python3 -c "
import glob, sys, yaml
n = 0
for p in glob.glob(sys.argv[1] + '/*.yaml'):
    d = yaml.safe_load(open(p))
    assert d and d.get('location'), p
    n += 1
print(n)
" "$COMPONENTS_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}
