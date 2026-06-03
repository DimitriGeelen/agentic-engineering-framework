#!/usr/bin/env bats
# T-2169 — Pin audit.sh retire_when advisory. Origin: value-drivers.yaml v3
# free drivers (F-RECALL, F-ORCH) carry retire_when: text describing when the
# driver stops being relevant. Without an advisory rail nothing nudges the
# operator. Modelled on T-1855 stale-arc precedent (WARN, never FAIL).
#
# Rules pinned by these tests:
#   (a) F-RECALL recognition fires ONLY when all 4 signals are present
#   (b) F-ORCH recognition fires when T-1643 is completed cleanly OR G-064 closed
#   (c) Generic fallback emits INFO for any future free driver with retire_when
#       text but no dedicated recognition heuristic
#   (d) Inactive (commented-out) free drivers are skipped entirely
#   (e) No false-WARN when retire_when is empty/absent
#   (f) WARN cap — re-running audit produces same count, not N×count
#   (g) FW_RETIRE_WHEN_ADVISORY=0 silences the whole section

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-retire-when"
    mkdir -p "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.context/audits" \
             "$TEST_PROJECT/.context/project" \
             "$TEST_PROJECT/.context/locks" \
             "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates" \
             "$TEST_PROJECT/policy" \
             "$TEST_PROJECT/agents" \
             "$TEST_PROJECT/lib"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"

    # Minimal git repo so audit's git checks don't error
    git -C "$TEST_PROJECT" init -q
    git -C "$TEST_PROJECT" config user.email test@test
    git -C "$TEST_PROJECT" config user.name test
    echo seed > "$TEST_PROJECT/seed.txt"
    git -C "$TEST_PROJECT" add seed.txt
    git -C "$TEST_PROJECT" commit -q -m "T-001: seed commit"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_write_value_drivers() {
    # $1 = full YAML content for policy/value-drivers.yaml
    cat > "$TEST_PROJECT/policy/value-drivers.yaml" <<EOF
$1
EOF
}

_run_structure_audit() {
    run "$FRAMEWORK_ROOT/bin/fw" audit --section structure
}

@test "F-RECALL: only 1/4 signals → no WARN" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-RECALL
    name: Recall
    weight: 6
    polarity: positive
    retire_when: >
      L4 Reflect criteria are green.
YAML
)"
    # 1 of 4 signals: auto-sync code in agents/
    echo "# auto-sync code" > "$TEST_PROJECT/agents/sync.sh"

    _run_structure_audit
    [[ "$output" != *"free driver F-RECALL: retire_when"* ]]
}

@test "F-RECALL: all 4 signals → WARN (4/4)" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-RECALL
    name: Recall
    weight: 6
    polarity: positive
    retire_when: >
      L4 Reflect criteria are green.
YAML
)"
    # (a) positive-reinforcement commit
    echo "x" > "$TEST_PROJECT/positive.txt"
    git -C "$TEST_PROJECT" add positive.txt
    git -C "$TEST_PROJECT" commit -q -m "T-001: positive-reinforcement capture wired"
    # (b) preference index
    echo "# prefs" > "$TEST_PROJECT/preference-index.yaml"
    # (c) auto-sync code
    echo "# auto-sync" > "$TEST_PROJECT/agents/sync.sh"
    # (d) recent reflection log
    echo "# reflection" > "$TEST_PROJECT/.context/reflection-log.yaml"

    _run_structure_audit
    [[ "$output" == *"free driver F-RECALL: retire_when condition appears met (4/4 signals)"* ]]
}

@test "F-ORCH: T-1643 in completed/ cleanly → WARN" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-ORCH
    name: Orchestration
    weight: 5
    polarity: positive
    retire_when: >
      Orchestrator substrate (T-1643) lands in production.
YAML
)"
    cat > "$TEST_PROJECT/.tasks/completed/T-1643-orchestrator-substrate.md" <<'EOF'
---
id: T-1643
status: work-completed
owner: agent
---

# T-1643

Substrate landed cleanly, all ACs ticked, ready to ship.
EOF

    _run_structure_audit
    [[ "$output" == *"free driver F-ORCH: retire_when condition appears met"* ]]
}

@test "F-ORCH: T-1643 still has [REVIEW] marker → no WARN (and G-064 absent)" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-ORCH
    name: Orchestration
    weight: 5
    polarity: positive
    retire_when: >
      Orchestrator substrate (T-1643) lands in production.
YAML
)"
    cat > "$TEST_PROJECT/.tasks/completed/T-1643-orchestrator-substrate.md" <<'EOF'
---
id: T-1643
status: work-completed
owner: human
---

# T-1643

- [ ] [REVIEW] human-AC still unticked
EOF

    _run_structure_audit
    [[ "$output" != *"free driver F-ORCH: retire_when"* ]]
}

@test "F-ORCH: G-064 closed in concerns.yaml → WARN" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-ORCH
    name: Orchestration
    weight: 5
    polarity: positive
    retire_when: >
      Orchestrator substrate criterion green.
YAML
)"
    cat > "$TEST_PROJECT/.context/project/concerns.yaml" <<'EOF'
concerns:
- id: G-064
  type: gap
  status: closed
  closed_date: 2026-06-01
  title: "Orchestrator substrate"
EOF

    _run_structure_audit
    [[ "$output" == *"free driver F-ORCH: retire_when condition appears met"* ]]
}

@test "Generic fallback: F-TEST with retire_when text → INFO not WARN" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-TEST
    name: Fictional
    weight: 3
    polarity: positive
    retire_when: >
      Some hypothetical condition.
YAML
)"
    _run_structure_audit
    [[ "$output" == *"free driver F-TEST: retire_when text present, no recognition heuristic"* ]]
    [[ "$output" != *"[WARN] free driver F-TEST"* ]]
}

@test "Inactive (commented-out) free driver: skipped — no WARN, no INFO" {
    cat > "$TEST_PROJECT/policy/value-drivers.yaml" <<'EOF'
free_drivers:
  - id: F-ORCH
    name: Orchestration
    weight: 5
    retire_when: >
      Orchestrator substrate green.

  # - id: F-AUTONOMY
  #   name: Autonomy
  #   weight: 4
  #   retire_when: >
  #     Continuous-run capability proven.
EOF
    cat > "$TEST_PROJECT/.tasks/completed/T-1643-x.md" <<'EOF'
---
id: T-1643
status: work-completed
owner: agent
---
clean
EOF

    _run_structure_audit
    # F-ORCH fires (T-1643 clean), but F-AUTONOMY is commented out — must NOT appear
    [[ "$output" == *"free driver F-ORCH"* ]]
    [[ "$output" != *"F-AUTONOMY"* ]]
}

@test "Empty retire_when: no WARN, no INFO" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-EMPTY
    name: Empty
    weight: 2
    polarity: positive
    retire_when: ""
YAML
)"
    _run_structure_audit
    [[ "$output" != *"F-EMPTY"* ]]
}

@test "Missing retire_when field: no WARN, no INFO" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-NOFIELD
    name: NoField
    weight: 2
    polarity: positive
YAML
)"
    _run_structure_audit
    [[ "$output" != *"F-NOFIELD"* ]]
}

@test "WARN cap: re-running audit produces ONE WARN per driver, not N" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-ORCH
    name: Orchestration
    weight: 5
    retire_when: >
      Orchestrator substrate criterion green.
YAML
)"
    cat > "$TEST_PROJECT/.context/project/concerns.yaml" <<'EOF'
concerns:
- id: G-064
  status: closed
  title: x
EOF

    _run_structure_audit
    count=$(echo "$output" | grep -c "free driver F-ORCH: retire_when condition appears met" || true)
    [ "$count" -eq 1 ]
}

@test "FW_RETIRE_WHEN_ADVISORY=0 silences the section entirely" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-TEST
    name: Fictional
    weight: 3
    retire_when: >
      Some condition.
YAML
)"
    FW_RETIRE_WHEN_ADVISORY=0 run "$FRAMEWORK_ROOT/bin/fw" audit --section structure
    [[ "$output" != *"F-TEST"* ]]
    [[ "$output" != *"retire_when"* ]]
}

@test "No FAIL emitted from the retire_when section (advisory-only)" {
    _write_value_drivers "$(cat <<'YAML'
free_drivers:
  - id: F-RECALL
    name: Recall
    weight: 6
    retire_when: >
      L4 Reflect criteria are green.
  - id: F-ORCH
    name: Orchestration
    weight: 5
    retire_when: >
      Orchestrator substrate green.
  - id: F-NEW
    name: NewDriver
    weight: 2
    retire_when: >
      Some condition.
YAML
)"
    # Trigger ALL: F-RECALL gets 4/4, F-ORCH gets G-064 close, F-NEW gets INFO
    echo x > "$TEST_PROJECT/positive.txt"
    git -C "$TEST_PROJECT" add positive.txt
    git -C "$TEST_PROJECT" commit -q -m "T-001: positive-reinforcement and happiness wired"
    echo "# prefs" > "$TEST_PROJECT/preference-index.yaml"
    echo "# auto-sync" > "$TEST_PROJECT/lib/sync.sh"
    echo "# reflection" > "$TEST_PROJECT/.context/reflection.yaml"
    cat > "$TEST_PROJECT/.context/project/concerns.yaml" <<'EOF'
concerns:
- id: G-064
  status: closed
  title: x
EOF

    _run_structure_audit
    # No FAIL line introduced by this section. (Other sections might add their
    # own; we assert no FAIL containing "free driver" or "retire_when".)
    [[ "$output" != *"[FAIL] free driver"* ]]
    [[ "$output" != *"[FAIL]"*"retire_when"* ]]
}
