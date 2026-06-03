#!/usr/bin/env bats
# T-2191 (T-2186 slice 5): detect_disposition_completeness — per-question
# disposition discipline for inception ## Open Questions.
#
# Sibling shape to T-2145 defer-as-hedge: same decision-without-evidence
# family applied to per-question dispositions. CONCERN-level, partial,
# heuristic. Fires verdict-level (ac_index=None).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    SCAN_RUNNER="$TEST_TEMP_DIR/run_scan.py"
    cat > "$SCAN_RUNNER" <<'PY'
import sys, json
from pathlib import Path
sys.path.insert(0, "${FRAMEWORK_ROOT}")
from lib.reviewer.static_scan import detect_disposition_completeness

task_file = Path(sys.argv[1])
text = task_file.read_text()
# Split frontmatter
parts = text.split("---", 2)
meta = {}
if len(parts) >= 3:
    for line in parts[1].splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            meta[k.strip()] = v.strip()
    body = parts[2]
else:
    body = text
findings = detect_disposition_completeness(meta or None, body, task_file)
out = [{"pattern_id": f.pattern_id, "evidence": f.evidence, "location": f.location} for f in findings]
print(json.dumps(out))
PY
    # Substitute FRAMEWORK_ROOT into the runner (heredoc was unquoted only for ${VAR}? No — using EOF-quoted, manual subst)
    sed -i "s|\${FRAMEWORK_ROOT}|$FRAMEWORK_ROOT|g" "$SCAN_RUNNER"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_task() {
    local wtype="$1" oq_body="$2"
    local path="$TEST_TEMP_DIR/task.md"
    {
        echo "---"
        echo "id: T-9999"
        echo "workflow_type: $wtype"
        echo "---"
        echo "# T-9999"
        if [ -n "$oq_body" ]; then
            echo "## Open Questions"
            echo ""
            echo "$oq_body"
            echo ""
        fi
    } > "$path"
    echo "$path"
}

@test "well-filed inception passes (zero findings)" {
    file=$(_make_task inception "- **IW-1: First question**
  confidence: 2
  disposition: answered
  rationale: see docs/reports/T-9999-test.md L42

- **IW-2: Second**
  confidence: 1
  disposition: dissolved
  rationale: refuted by F-0.3")
    run python3 "$SCAN_RUNNER" "$file"
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

@test "missing disposition line fires" {
    file=$(_make_task inception "- **IW-1: question one**
  confidence: 2
  rationale: see T-9998")
    run python3 "$SCAN_RUNNER" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no \`disposition:\` line"* ]]
}

@test "missing rationale line fires" {
    file=$(_make_task inception "- **IW-1: question one**
  disposition: answered")
    run python3 "$SCAN_RUNNER" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no/empty \`rationale:\` line"* ]]
}

@test "invalid disposition value fires" {
    file=$(_make_task inception "- **IW-1: question one**
  disposition: maybe
  rationale: idk T-9998")
    run python3 "$SCAN_RUNNER" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"disposition='maybe'"* ]]
    [[ "$output" == *"must be one of"* ]]
}

@test "answered-without-citation fires" {
    file=$(_make_task inception "- **IW-1: question one**
  disposition: answered
  rationale: yeah ok agreed")
    run python3 "$SCAN_RUNNER" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"answered"* ]]
    [[ "$output" == *"no evidence citation"* ]]
}

@test "non-inception (build) is exempt" {
    file=$(_make_task build "- **IW-1: question one**
  disposition: maybe")
    run python3 "$SCAN_RUNNER" "$file"
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

@test "no Open Questions section: grandfathered (zero findings)" {
    file=$(_make_task inception "")
    run python3 "$SCAN_RUNNER" "$file"
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

@test "deferred with valid rationale passes (no citation required)" {
    file=$(_make_task inception "- **IW-1: question one**
  disposition: deferred
  rationale: spike scheduled later")
    run python3 "$SCAN_RUNNER" "$file"
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

@test "multiple IW-N with mixed health: one finding per malformed entry" {
    file=$(_make_task inception "- **IW-1: ok one**
  disposition: answered
  rationale: see T-9998

- **IW-2: bad one**
  disposition: answered
  rationale: trust me

- **IW-3: also ok**
  disposition: deferred
  rationale: see T-9997")
    run python3 "$SCAN_RUNNER" "$file"
    [ "$status" -eq 0 ]
    # IW-2 fires, IW-1 and IW-3 do not
    [[ "$output" == *"IW-2"* ]]
    [[ "$output" != *"IW-1\""* ]] || true
    [[ "$output" != *"IW-3\""* ]] || true
}
