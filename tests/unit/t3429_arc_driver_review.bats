#!/usr/bin/env bats
# T-3429 (arc-006, D-586): the external value-driver reviewer.
#
# Pins the three static checks against crafted fixture arcs — each check failing
# on a fixture built to fail exactly it, and passing on a valid one. The point of
# a STATIC reviewer is that its verdict is re-runnable; these tests are what make
# that claim falsifiable.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root "$PROJECT_ROOT"
    mkdir -p "$PROJECT_ROOT/.context/arcs" "$PROJECT_ROOT/policy"
    cp "$FRAMEWORK_ROOT/policy/value-drivers.yaml" "$PROJECT_ROOT/policy/value-drivers.yaml"
    export CLAUDECODE=1   # the path the ruling changed: agent session, no override

    # A scoring: spec that passes the T-3428 validator. Indented for a
    # proposed_scoped_drivers[] list item (keys at column 4).
    VALID_SCORING='    scoring:
      kind: signals
      levels:
        3:
          keywords: ["write-set", "collision"]
        5:
          keywords: ["disjoint"]'
    # A rationale that satisfies check (c): >= 60 chars and names a directive.
    GOOD_RATIONALE='    rationale: >-
      Distinguishes from D2 (Reliability): D2 is about no silent failures at run
      time, this driver is about refusing a collision before the work starts.'
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

write_arc() {
    cat > "$PROJECT_ROOT/.context/arcs/$1.yaml"
}

run_review() {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' FRAMEWORK_ROOT='$FRAMEWORK_ROOT' \
        source '$FRAMEWORK_ROOT/lib/arc.sh'; PROJECT_ROOT='$PROJECT_ROOT'; arc_review_driver $*"
}

@test "T-3429: all three checks PASS on a well-formed proposed driver" {
    write_arc arc-900 <<YAML
id: arc-900
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers:
  - name: write-set-discipline
    weight: 5
$GOOD_RATIONALE
$VALID_SCORING
YAML
    run_review arc-900 write-set-discipline --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS  write-set-discipline"* ]]
    [[ "$output" == *"(a) scorable       PASS"* ]]
    [[ "$output" == *"(b) distinct       PASS"* ]]
    [[ "$output" == *"(c) distinguishes  PASS"* ]]
}

@test "T-3429: check (a) FAILs when the driver has no handler and no scoring spec" {
    write_arc arc-901 <<YAML
id: arc-901
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers:
  - name: no-mechanism-driver
    weight: 4
$GOOD_RATIONALE
YAML
    run_review arc-901 no-mechanism-driver --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"(a) scorable       FAIL"* ]]
    [[ "$output" == *"no handler, no inline scoring: block, no scoring_file:"* ]]
    [[ "$output" == *"(c) distinguishes  PASS"* ]]
}

@test "T-3429: check (a) FAILs when the scoring spec is present but invalid" {
    write_arc arc-902 <<YAML
id: arc-902
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers:
  - name: broken-spec-driver
    weight: 4
$GOOD_RATIONALE
    scoring:
      kind: not-a-real-kind
      levels:
        3:
          keywords: ["x"]
YAML
    run_review arc-902 broken-spec-driver --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"(a) scorable       FAIL"* ]]
    [[ "$output" == *"does not validate"* ]]
}

@test "T-3429: check (a) accepts a scoring_file: path relative to the project root" {
    cat > "$PROJECT_ROOT/policy/my-driver-scoring.yaml" <<'YAML'
kind: signals
levels:
  3:
    keywords: ["write-set"]
  5:
    keywords: ["disjoint"]
YAML
    write_arc arc-903 <<YAML
id: arc-903
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers:
  - name: file-spec-driver
    weight: 4
$GOOD_RATIONALE
    scoring_file: policy/my-driver-scoring.yaml
YAML
    run_review arc-903 file-spec-driver --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"(a) scorable       PASS"* ]]
    [[ "$output" == *"scoring_file: policy/my-driver-scoring.yaml validates"* ]]
}

@test "T-3429: check (b) FAILs on a name that duplicates a constitutional directive" {
    write_arc arc-904 <<YAML
id: arc-904
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers:
  - name: Reliability
    weight: 4
$GOOD_RATIONALE
$VALID_SCORING
YAML
    run_review arc-904 Reliability --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"(b) distinct       FAIL"* ]]
    [[ "$output" == *"constitutional directive D2"* ]]
}

@test "T-3429: check (b) normalises case and punctuation before comparing" {
    write_arc arc-905 <<YAML
id: arc-905
name: fixture
status: in-progress
scoped_drivers:
  - name: Loop closure (conditional)
    weight: 3
    approved_at: '2026-09-01T00:00:00Z'
proposed_scoped_drivers:
  - name: loop-closure-conditional
    weight: 4
$GOOD_RATIONALE
$VALID_SCORING
YAML
    run_review arc-905 loop-closure-conditional --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"(b) distinct       FAIL"* ]]
    [[ "$output" == *"existing scoped driver 'Loop closure (conditional)'"* ]]
}

@test "T-3429: check (c) FAILs on a rationale under 60 characters" {
    write_arc arc-906 <<YAML
id: arc-906
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers:
  - name: terse-driver
    weight: 4
    rationale: "Distinguishes from D2."
$VALID_SCORING
YAML
    run_review arc-906 terse-driver --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"(c) distinguishes  FAIL"* ]]
    [[ "$output" == *"needs >= 60"* ]]
}

@test "T-3429: check (c) FAILs when the rationale names no directive to differ from" {
    write_arc arc-907 <<YAML
id: arc-907
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers:
  - name: vague-driver
    weight: 4
    rationale: >-
      This arc cares a great deal about making the pipeline feel smooth and the
      results legible to whoever is reading them later on in the week.
$VALID_SCORING
YAML
    run_review arc-907 vague-driver --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"(c) distinguishes  FAIL"* ]]
    [[ "$output" == *"names no directive"* ]]
}

@test "T-3429: --dry-run writes no reviewer: block; a real run writes one" {
    write_arc arc-908 <<YAML
id: arc-908
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers:
  - name: persisted-driver
    weight: 4
$GOOD_RATIONALE
$VALID_SCORING
YAML
    run_review arc-908 persisted-driver --dry-run
    [ "$status" -eq 0 ]
    [ "$(grep -c 'reviewer:' "$PROJECT_ROOT/.context/arcs/arc-908.yaml")" -eq 0 ]

    run_review arc-908 persisted-driver
    [ "$status" -eq 0 ]
    [ "$(grep -c 'reviewer_id: static-v1' "$PROJECT_ROOT/.context/arcs/arc-908.yaml")" -eq 1 ]
    run python3 -c "
import yaml
d=yaml.safe_load(open('$PROJECT_ROOT/.context/arcs/arc-908.yaml'))
r=d['proposed_scoped_drivers'][0]['reviewer']
assert r['verdict']=='pass', r
assert set(r['checks'])=={'a','b','c'}, r
print('ok')"
    [ "$status" -eq 0 ]
}

@test "T-3429: --all reviews every proposed entry and fails if any one fails" {
    write_arc arc-909 <<YAML
id: arc-909
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers:
  - name: good-driver
    weight: 4
$GOOD_RATIONALE
$VALID_SCORING
  - name: bad-driver
    weight: 4
    rationale: "too short"
YAML
    run_review arc-909 --all --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"PASS  good-driver"* ]]
    [[ "$output" == *"FAIL  bad-driver"* ]]
}

@test "T-3429: an already-approved driver is reviewed read-only, not as its own duplicate" {
    write_arc arc-910 <<YAML
id: arc-910
name: fixture
status: in-progress
proposed_scoped_drivers: []
scoped_drivers:
  - name: approved-driver
    weight: 4
    approved_at: '2026-09-01T00:00:00Z'
$GOOD_RATIONALE
YAML
    run_review arc-910 approved-driver --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"[scoped_drivers]"* ]]
    [[ "$output" == *"(b) distinct       PASS"* ]]
    [[ "$output" == *"(a) scorable       FAIL"* ]]
}

@test "T-3429: an unknown driver name exits 1 and says where it looked" {
    write_arc arc-911 <<YAML
id: arc-911
name: fixture
status: in-progress
scoped_drivers: []
proposed_scoped_drivers: []
YAML
    run_review arc-911 nope --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"no driver matching 'nope'"* ]]
}
