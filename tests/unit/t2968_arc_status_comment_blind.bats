#!/usr/bin/env bats
# T-2968 — `status:` in an arc YAML had five readers, and they disagreed.
#
# The gate's reader was:
#
#   awk -F': ' '/^status:/ {sub(/^status:[[:space:]]*/, ""); print; exit}' "$f" \
#       | tr -d ' "' | head -c 32
#
# An inline YAML comment is valid YAML and invisible to yaml.safe_load. This
# reader kept it, and — having deleted every space first — welded it onto the
# value. Measured on arc-013 (`status: in-progress  # T-2428 GO recorded ...`):
#
#   yaml.safe_load    in-progress
#   _arc_get_status   in-progress#T-2428GOrecorded2026     <- truncated by head -c 32
#   fw arc list       in-progress  # T-2428 GO recorded 2026-06-18 - build arc authorized
#   L1026 site        in-progress                          <- correct BY ACCIDENT (default FS)
#   L1286/L1769       in-progress#T-2428GOrecorded2026-06-18-buildarcauthorized
#
# Every _arc_require_status caller therefore refused for that arc, naming a
# status that appears nowhere in the file, while every YAML-reading surface
# (audit, Watchtower) showed it in-progress. The arc was structurally
# unclosable and only the refusal text said so.
#
# These legs drive the REAL parser and compare against yaml.safe_load rather
# than against a hard-coded expectation — the defect was precisely that a
# hand-rolled reader diverged from YAML, so YAML is the oracle.
#
# COUNTERFACTUAL (measured, by substituting the pre-fix parser body under the
# same name so the parse change is what is isolated):
#   legs 1 and 2 go red — the commented value and the commented draft.
#   Legs 3, 4 and 5 stay GREEN, for two different reasons, and the difference
#   matters:
#     - Legs 3 and 4 are genuinely green under both. Leg 4 is the uncommented
#       control; leg 3 is the `a#b` case, which the old reader also got right
#       because it never looked for `#` at all and so could not over-strip. A
#       suite of 3+4 alone would have reported the reader healthy while arc-013
#       could not be closed — the same always-answers shape as the reader itself.
#     - Leg 5 is green for a REASON THE COUNTERFACTUAL CANNOT SEE: it shells out
#       to the real `bin/fw`, which the setup substitution does not reach. Its
#       pre-fix behaviour is NOT measured by this method. It was measured
#       directly instead, before the fix landed, and printed:
#         arc-013   in-progress  # T-2428 GO recorded 2026-06-18 — build arc authorized
#       Recorded here rather than left as an unmarked green, because "green under
#       both" and "not actually exercised" are indistinguishable from the result
#       column alone — which is the defect this whole file is about.
#
# (First attempt at this counterfactual ran the copy from /tmp, where
# BATS_TEST_FILENAME/../.. resolves to `/` and `bin/fw` does not exist. Leg 5
# went red and looked like signal. It was the probe failing.)

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    ARC="$BATS_TEST_TMPDIR/a.yaml"
    # Source only the parser, not the whole arc CLI.
    eval "$(sed -n '/^_arc_status_from_file()/,/^}/p' "$FRAMEWORK_ROOT/lib/arc.sh")"
}

# The oracle: what a real YAML parser makes of the same file.
_yaml_status() {
    python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['status'])" "$1"
}

@test "an inline comment on status: does not become part of the value" {
    printf 'id: arc-013\nstatus: in-progress  # T-2428 GO recorded 2026-06-18 — build arc authorized\n' > "$ARC"
    got="$(_arc_status_from_file "$ARC")"
    [ "$got" = "$(_yaml_status "$ARC")" ]
    [ "$got" = "in-progress" ]
}

@test "a commented draft arc still reads as draft (the auto-promote check)" {
    # lib/arc.sh's approve-driver path promotes draft -> in-progress on `= draft`.
    # Pre-fix this comparison silently failed and the arc never promoted.
    printf 'status: draft   # awaiting first driver decision\n' > "$ARC"
    got="$(_arc_status_from_file "$ARC")"
    [ "$got" = "$(_yaml_status "$ARC")" ]
    [ "$got" = "draft" ]
}

@test "a # not preceded by whitespace is part of the scalar, as YAML says" {
    # YAML opens a comment only after whitespace. Over-stripping here would be a
    # new divergence in the opposite direction, so the oracle is the assertion.
    printf 'status: a#b\n' > "$ARC"
    got="$(_arc_status_from_file "$ARC")"
    [ "$got" = "$(_yaml_status "$ARC")" ]
    [ "$got" = "a#b" ]
}

@test "an uncommented status is unchanged (control)" {
    printf 'id: arc-015\nstatus: in-progress\n' > "$ARC"
    got="$(_arc_status_from_file "$ARC")"
    [ "$got" = "$(_yaml_status "$ARC")" ]
    [ "$got" = "in-progress" ]
}

@test "fw arc list renders a commented arc's status without the comment" {
    # The display reader was a sixth copy; this pins that it now agrees too.
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw arc list 2>&1 | grep '^ *arc-013'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"#"* ]]
    [[ "$output" == *"in-progress"* ]]
}
