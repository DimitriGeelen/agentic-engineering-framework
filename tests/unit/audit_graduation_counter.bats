#!/usr/bin/env bats
# T-2677 — audit graduation counter shape-agnostic (dead >=20 branch).
# The old '^  - id: L-' grep counted 0 against the real learnings.yaml
# (column-0 dash entries + no-dash legacy entries), so the >=20 threshold
# branch — the only programmatic caller of `fw promote suggest` — never
# fired. Same file-shape-blindness family as T-2676 (harvest greps) and
# T-2672 (resolve.sh emit-indent); different site and mechanism
# (count-then-threshold vs extract-values).
#
# The counter line lives inline in audit.sh section 9; these tests pin the
# REGEX ITSELF against fixture files plus the live-file floor, so a
# regression to a fixed-shape grep fails here before it dies in the field.

load ../test_helper

COUNTER_REGEX='^[[:space:]]*(- )?id: P?L-'

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "audit.sh uses the shape-agnostic counter regex (not the dead 2-space form)" {
    grep -qF "grep -cE '^[[:space:]]*(- )?id: P?L-'" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    ! grep -qF "grep -c '^  - id: L-'" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "counter regex counts column-0 dash, 2-space dash, and no-dash legacy entries" {
    cat > "$TEST_TEMP_DIR/learnings.yaml" <<'EOF'
learnings:
- id: L-001
  learning: "column-0 dash form"
  - id: L-002
    learning: "two-space dash form"
  id: L-003
  learning: "no-dash legacy form"
- id: PL-004
  learning: "consumer-prefix form"
EOF
    count=$(grep -cE "$COUNTER_REGEX" "$TEST_TEMP_DIR/learnings.yaml")
    [ "$count" -eq 4 ]
}

@test "counter regex crosses the >=20 threshold on the LIVE learnings file" {
    live="$FRAMEWORK_ROOT/.context/project/learnings.yaml"
    [ -f "$live" ] || skip "no live learnings file"
    count=$(grep -cE "$COUNTER_REGEX" "$live")
    [ "$count" -ge 20 ]
}
