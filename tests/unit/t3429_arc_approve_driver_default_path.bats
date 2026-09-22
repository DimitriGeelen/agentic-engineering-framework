#!/usr/bin/env bats
# T-3429 (arc-006, D-586): approve-driver's default path is the reviewer.
#
# The operator ruling moved WHO certifies an arc-scoped driver, not WHAT the
# structural limits are — so these tests pin both halves: the new reviewer gate
# AND that cap-3 / weight<=6 / T-1979 dedup / the §ACD gate on --none all still
# bite on the path that no longer asks a human.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root "$PROJECT_ROOT"
    mkdir -p "$PROJECT_ROOT/.context/arcs" "$PROJECT_ROOT/policy" "$PROJECT_ROOT/.tasks/active"
    cp "$FRAMEWORK_ROOT/policy/value-drivers.yaml" "$PROJECT_ROOT/policy/value-drivers.yaml"
    export CLAUDECODE=1   # agent session — the exact context the ruling changed

    GOOD_RATIONALE='Distinguishes from D2 (Reliability): D2 is about no silent failures at run time, this driver is about refusing a collision before the work ever starts.'
    export GOOD_RATIONALE
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# write_arc <arc-id> — proposed entries read from stdin (may be empty).
write_arc() {
    local aid="$1"
    { echo "id: $aid"; echo "name: fixture"; echo "status: in-progress";
      echo "scoped_drivers: []"; echo "proposed_scoped_drivers:"; cat; } \
      > "$PROJECT_ROOT/.context/arcs/$aid.yaml"
}

# A proposal that passes all three checks.
good_proposal() {
    cat <<YAML
  - name: $1
    weight: ${2:-4}
    rationale: >-
      $GOOD_RATIONALE
    scoring:
      kind: signals
      levels:
        3:
          keywords: ["write-set"]
YAML
}

run_fw() {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' FRAMEWORK_ROOT='$FRAMEWORK_ROOT' \
        source '$FRAMEWORK_ROOT/lib/arc.sh'; PROJECT_ROOT='$PROJECT_ROOT'; $*"
}

scoped_field() {  # <arc-id> <driver-name> <field>
    python3 -c "
import yaml, sys
d = yaml.safe_load(open('$PROJECT_ROOT/.context/arcs/$1.yaml')) or {}
for s in (d.get('scoped_drivers') or []):
    if s.get('name') == '$2':
        print(s.get('$3') or '')
        break
"
}

@test "T-3429: an unflagged approve no longer refuses — it approves on reviewer PASS" {
    write_arc arc-970 < <(good_proposal certified-driver 5)
    run_fw "arc_approve_driver arc-970 certified-driver --weight 5 --rationale \"\$GOOD_RATIONALE\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"Reviewer PASS (reviewer:static-v1)"* ]]
    [[ "$output" == *"OK: approved scoped driver 'certified-driver'"* ]]
    # The old §ACD refusal must NOT appear on this path.
    [ "$(printf '%s' "$output" | grep -c 'agents must not invoke')" -eq 0 ]
    [ "$(scoped_field arc-970 certified-driver approved_by)" = "reviewer:static-v1" ]
}

@test "T-3429: the approved entry carries the reviewer verdict, not just the claim" {
    write_arc arc-971 < <(good_proposal verdict-driver)
    run_fw "arc_approve_driver arc-971 verdict-driver --rationale \"\$GOOD_RATIONALE\""
    [ "$status" -eq 0 ]
    run python3 -c "
import yaml
d = yaml.safe_load(open('$PROJECT_ROOT/.context/arcs/arc-971.yaml'))
r = d['scoped_drivers'][0]['reviewer']
assert r['verdict'] == 'pass', r
assert set(r['checks']) == {'a','b','c'}, r
assert r['reviewer_id'] == 'static-v1', r
print('ok')"
    [ "$status" -eq 0 ]
}

@test "T-3429: a driver that fails review is refused, and the failed checks are named" {
    write_arc arc-972 <<'YAML'
  - name: no-spec-driver
    weight: 4
    rationale: "too short"
YAML
    run_fw "arc_approve_driver arc-972 no-spec-driver --rationale 'too short'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"did not pass review — not approved"* ]]
    [[ "$output" == *"FAILED (a) scorable"* ]]
    [[ "$output" == *"FAILED (c) distinguishes"* ]]
    [[ "$output" == *"--i-am-human"* ]]
    run python3 -c "
import yaml
d = yaml.safe_load(open('$PROJECT_ROOT/.context/arcs/arc-972.yaml'))
assert not (d.get('scoped_drivers') or []), d.get('scoped_drivers')
print('ok')"
    [ "$status" -eq 0 ]
}

@test "T-3429: --i-am-human still approves without the reviewer, recorded as human" {
    write_arc arc-973 <<'YAML'
  - name: override-driver
    weight: 4
    rationale: "too short"
YAML
    run_fw "arc_approve_driver arc-973 override-driver --rationale 'too short' --i-am-human"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | grep -c 'Reviewer PASS')" -eq 0 ]
    [ "$(scoped_field arc-973 override-driver approved_by)" = "human" ]
}

@test "T-3429: --none keeps its human gate — a negative ruling stays sovereign" {
    write_arc arc-974 <<'YAML'
YAML
    run_fw "arc_approve_driver arc-974 --none --justification 'global D1-D4 already cover every value dimension of this arc'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"agents must not invoke 'fw arc approve-driver --none' directly"* ]]
}

@test "T-3429: weight > 6 is still refused on the reviewer path (M2)" {
    write_arc arc-975 < <(good_proposal heavy-driver)
    run_fw "arc_approve_driver arc-975 heavy-driver --weight 9 --rationale \"\$GOOD_RATIONALE\""
    [ "$status" -eq 2 ]
    [[ "$output" == *"capped at 6 (M2)"* ]]
}

@test "T-3429: the T-1979 dedup still refuses a second approval of the same name" {
    write_arc arc-976 < <(good_proposal twice-driver)
    run_fw "arc_approve_driver arc-976 twice-driver --rationale \"\$GOOD_RATIONALE\""
    [ "$status" -eq 0 ]
    run_fw "arc_approve_driver arc-976 twice-driver --rationale \"\$GOOD_RATIONALE\""
    [ "$status" -eq 1 ]
    [[ "$output" == *"already in scoped_drivers"* ]]
}

@test "T-3429: --all-reviewed approves passing drivers and stops at the M2 cap of 3" {
    { write_arc arc-977 < <(for i in 1 2 3 4 5; do good_proposal "driver-$i"; done); }
    run_fw "arc_approve_driver arc-977 --all-reviewed"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 approved, 0 refused by review, 2 skipped"* ]]
    [[ "$output" == *"Skipped (scoped_drivers: at the M2 cap of 3): driver-4, driver-5"* ]]
    run python3 -c "
import yaml
d = yaml.safe_load(open('$PROJECT_ROOT/.context/arcs/arc-977.yaml'))
assert len(d['scoped_drivers']) == 3, d['scoped_drivers']
assert [s['name'] for s in d['scoped_drivers']] == ['driver-1','driver-2','driver-3']
print('ok')"
    [ "$status" -eq 0 ]
}

@test "T-3429: --all-reviewed skips what fails review and reports a non-zero exit" {
    { write_arc arc-978 < <(good_proposal ok-driver; printf '  - name: bad-driver\n    weight: 4\n    rationale: "nope"\n'); }
    run_fw "arc_approve_driver arc-978 --all-reviewed"
    [ "$status" -eq 1 ]
    [[ "$output" == *"1 approved, 1 refused by review, 0 skipped"* ]]
    run python3 -c "
import yaml
d = yaml.safe_load(open('$PROJECT_ROOT/.context/arcs/arc-978.yaml'))
assert [s['name'] for s in d['scoped_drivers']] == ['ok-driver'], d['scoped_drivers']
print('ok')"
    [ "$status" -eq 0 ]
}

@test "T-3429: --all-reviewed on an arc with no proposals says so and exits 0" {
    write_arc arc-979 <<'YAML'
YAML
    run_fw "arc_approve_driver arc-979 --all-reviewed"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to approve"* ]]
}
