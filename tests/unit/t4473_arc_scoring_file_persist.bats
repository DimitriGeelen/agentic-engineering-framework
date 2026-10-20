#!/usr/bin/env bats
# T-4473 (010-termlink proposal 341, their T-3472): approve-driver --scoring-file
# must STORE the spec inline. The estimator reads only an inline `scoring:` block
# (estimator.load_scoring_spec), so a spec handed to the reviewer and then dropped
# scored nothing. These tests pin the writer -> estimator round trip.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root "$PROJECT_ROOT"
    mkdir -p "$PROJECT_ROOT/.context/arcs" "$PROJECT_ROOT/policy" "$PROJECT_ROOT/.tasks/active"
    cp "$FRAMEWORK_ROOT/policy/value-drivers.yaml" "$PROJECT_ROOT/policy/value-drivers.yaml"
    export CLAUDECODE=1

    GOOD_RATIONALE='Distinguishes from D2 (Reliability): D2 is about no silent failures at run time, this driver is about refusing a collision before the work ever starts.'
    export GOOD_RATIONALE

    cat > "$PROJECT_ROOT/spec.yaml" <<'YAML'
scoring:
  kind: signals
  levels:
    3:
      keywords: ["write-set"]
YAML
    printf 'scoring:\n  kind: no-such-kind\n' > "$PROJECT_ROOT/bad-spec.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

write_arc() {  # <arc-id> — scoped_drivers entries from stdin (may be empty)
    { echo "id: $1"; echo "name: fixture"; echo "status: in-progress";
      echo "proposed_scoped_drivers: []"; echo "scoped_drivers:"; cat; } \
      > "$PROJECT_ROOT/.context/arcs/$1.yaml"
}

run_fw() {
    run bash -c "cd '$PROJECT_ROOT' && PROJECT_ROOT='$PROJECT_ROOT' FRAMEWORK_ROOT='$FRAMEWORK_ROOT' \
        source '$FRAMEWORK_ROOT/lib/arc.sh'; PROJECT_ROOT='$PROJECT_ROOT'; $*"
}

# Prints the spec the ESTIMATOR would load for <driver>, as "kind=<kind>", or "none".
estimator_spec() {  # <arc-id> <driver-name>
    python3 - "$FRAMEWORK_ROOT" "$PROJECT_ROOT/.context/arcs/$1.yaml" "$2" <<'PY'
import importlib.util, sys, yaml
root, fn, name = sys.argv[1:4]
spec = importlib.util.spec_from_file_location("est", root + "/agents/termlink/bvp-estimator/estimator.py")
est = importlib.util.module_from_spec(spec); spec.loader.exec_module(est)
d = yaml.safe_load(open(fn)) or {}
for sd in (d.get("scoped_drivers") or []):
    if sd.get("name") == name:
        s = est.load_scoring_spec(sd)
        print("none" if s is None else "kind=%s errors=%d" % (s.get("kind"), len(est.validate_scoring_spec(s))))
        break
else:
    print("absent")
PY
}

@test "T-4473: reviewer path stores the --scoring-file spec inline, estimator loads it" {
    write_arc arc-980 < /dev/null
    run_fw "arc_approve_driver arc-980 ad-hoc-driver --weight 4 --rationale \"\$GOOD_RATIONALE\" --scoring-file spec.yaml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Reviewer PASS"* ]]
    [ "$(estimator_spec arc-980 ad-hoc-driver)" = "kind=signals errors=0" ]
}

@test "T-4473: --i-am-human path stores the spec inline too" {
    write_arc arc-981 < /dev/null
    run_fw "arc_approve_driver arc-981 human-driver --weight 3 --i-am-human --scoring-file spec.yaml"
    [ "$status" -eq 0 ]
    [ "$(estimator_spec arc-981 human-driver)" = "kind=signals errors=0" ]
}

@test "T-4473: an invalid spec on the human path is refused before any entry is written" {
    write_arc arc-982 < /dev/null
    before=$(md5sum "$PROJECT_ROOT/.context/arcs/arc-982.yaml")
    run_fw "arc_approve_driver arc-982 bad-driver --weight 3 --i-am-human --scoring-file bad-spec.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not validate"* ]]
    [ "$(md5sum "$PROJECT_ROOT/.context/arcs/arc-982.yaml")" = "$before" ]
}

@test "T-4473: --scoring-file on an approved driver attaches in place on the operator path" {
    write_arc arc-983 <<'YAML'
  - name: old-driver
    weight: 4
    approved_at: '2026-01-01T00:00:00Z'
    approved_by: human
YAML
    run_fw "arc_approve_driver arc-983 old-driver --i-am-human --scoring-file spec.yaml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"attached scoring spec"* ]]
    [ "$(estimator_spec arc-983 old-driver)" = "kind=signals errors=0" ]
    grep -q "approved_at: '2026-01-01T00:00:00Z'" "$PROJECT_ROOT/.context/arcs/arc-983.yaml"
    grep -q "approved_by: human" "$PROJECT_ROOT/.context/arcs/arc-983.yaml"
}

@test "T-4473: attach without the operator path is refused and writes nothing" {
    write_arc arc-984 <<'YAML'
  - name: old-driver
    weight: 4
    approved_at: '2026-01-01T00:00:00Z'
    approved_by: human
YAML
    before=$(md5sum "$PROJECT_ROOT/.context/arcs/arc-984.yaml")
    run_fw "arc_approve_driver arc-984 old-driver --scoring-file spec.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs the operator path"* ]]
    [ "$(md5sum "$PROJECT_ROOT/.context/arcs/arc-984.yaml")" = "$before" ]
}

@test "T-4473: attach with a different --weight is refused" {
    write_arc arc-985 <<'YAML'
  - name: old-driver
    weight: 4
    approved_at: '2026-01-01T00:00:00Z'
    approved_by: human
YAML
    run_fw "arc_approve_driver arc-985 old-driver --weight 2 --i-am-human --scoring-file spec.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"differs from the approved weight"* ]]
    [ "$(estimator_spec arc-985 old-driver)" = "none" ]
}

@test "T-4473: approval without --scoring-file writes no scoring: key (path unchanged)" {
    write_arc arc-986 < /dev/null
    run_fw "arc_approve_driver arc-986 plain-driver --weight 3 --i-am-human"
    [ "$status" -eq 0 ]
    [ "$(estimator_spec arc-986 plain-driver)" = "none" ]
    run grep -c "scoring" "$PROJECT_ROOT/.context/arcs/arc-986.yaml"
    [ "$output" = "0" ]
}
