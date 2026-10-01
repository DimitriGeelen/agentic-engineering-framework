#!/usr/bin/env bats
# T-3696: lib/inception.sh decide-preflight stripped real `### Agent` ACs that
# followed a one-line <!-- --> comment, because sed '/<!--/,/-->/d' opens a range
# on the one-line comment and runs to the NEXT -->. The unchecked-AC gate then
# saw no unchecked ACs and passed falsely.

setup() {
    ROOT="$BATS_TEST_DIRNAME/../.."
    FIX="$BATS_TEST_TMPDIR/task.md"
    cat > "$FIX" <<'TASK'
## Acceptance Criteria

### Agent
<!-- one-line comment -->
- [ ] real unchecked agent AC

### Human
<!--
     multi-line comment closes here
-->

## Verification
TASK
}

# Run the REAL extraction line from lib/inception.sh against the fixture.
run_extraction() {
    local line
    line=$(grep -m1 '_ac_section=\$(extract_ac_section' "$ROOT/lib/inception.sh")
    [ -n "$line" ]
    ( source "$ROOT/lib/section-extract.sh"
      export FRAMEWORK_ROOT="$ROOT" PROJECT_ROOT="$ROOT"
      task_file="$FIX"
      eval "$line"
      printf '%s\n' "$_ac_section" )
}

@test "real unchecked Agent AC after a one-line comment survives the strip" {
    run run_extraction
    [ "$status" -eq 0 ]
    [[ "$output" == *"real unchecked agent AC"* ]]
}
