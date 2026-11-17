#!/usr/bin/env bats
# T-5215 (G-133) — `fw task review-batch` applies the SAME inception
# handoff-readiness decision as `fw task review` (T-3549).
#
# Before this, emit_review_batch checked only an empty Recommendation (T-2206),
# so the multi-task handoff CLAUDE.md prescribes handed the operator decide
# links for inceptions with undisposed questions (T-5211, T-5212). The parity
# test at the bottom is the one that stops a third handoff path from starting
# out without the gate.
#
# All fixtures live in a tmp project root; the real .tasks/ is never touched.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    [ -f "$FRAMEWORK_ROOT/lib/review.sh" ] || { echo "missing lib/review.sh" >&2; return 1; }
    P="$(mktemp -d)"
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.context/working"
}

teardown() {
    if [ -n "${P:-}" ]; then rm -rf "$P"; fi
    return 0
}

# _inception ID KIND — KIND: disposed | undisposed
_inception() {
    local id="$1" kind="$2"
    { printf -- '---\nid: %s\nname: "fixture inception"\nstatus: started-work\n' "$id"
      printf 'workflow_type: inception\nowner: human\nhorizon: now\n'
      printf 'created: 2026-09-01T00:00:00Z\nlast_update: 2026-09-01T00:00:00Z\n---\n\n'
      printf '# %s: fixture inception\n\n## Problem Statement\n\nx\n\n## Open Questions\n\n' "$id"
      case "$kind" in
        disposed)
          printf -- '- **IW-1: first question**\n  disposition: answered\n  rationale: because evidence\n\n'
          printf -- '- **IW-2: second question**\n  disposition: deferred\n  rationale: to its own ruling\n\n' ;;
        undisposed)
          printf -- '- **IW-1: first question**\n  disposition:\n  rationale: because evidence\n\n'
          printf -- '- **IW-2: second question**\n  disposition:\n  rationale: to its own ruling\n\n' ;;
      esac
      printf '## Recommendation\n\n**Recommendation:** GO\n\n**Rationale:** because.\n\n'
      printf '## Acceptance Criteria\n\n### Agent\n- [x] done\n\n'; } \
      > "$P/.tasks/active/${id}-fixture.md"
}

_build() {
    local id="$1"
    printf -- '---\nid: %s\nname: "fixture build"\nstatus: started-work\nworkflow_type: build\nowner: agent\n---\n\n# %s: fixture build\n' \
        "$id" "$id" > "$P/.tasks/active/${id}-build.md"
}

_batch() {
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" WATCHTOWER_URL="http://test-host:7777" NO_COLOR=1 \
        timeout 120 bash -c "set -euo pipefail; source '$FRAMEWORK_ROOT/lib/colors.sh'; source '$FRAMEWORK_ROOT/lib/review.sh'; emit_review_batch $*" 2>&1
}

_single() {
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" WATCHTOWER_URL="http://test-host:7777" NO_COLOR=1 \
        timeout 120 bash -c "set -euo pipefail; source '$FRAMEWORK_ROOT/lib/colors.sh'; source '$FRAMEWORK_ROOT/lib/review.sh'; emit_review $1" 2>&1
}

@test "shared function exists and both paths call it (no copy)" {
    grep -q '^_inception_handoff_readiness()' "$FRAMEWORK_ROOT/lib/review.sh"
    [ "$(grep -c '_inception_handoff_readiness "\$task_id" "\$task_file" "emit_review"' "$FRAMEWORK_ROOT/lib/review.sh")" -eq 1 ]
    [ "$(grep -c '_inception_handoff_readiness "\$tid_r" "\$tf_r" "emit_review_batch"' "$FRAMEWORK_ROOT/lib/review.sh")" -eq 1 ]
    # The predicate calls live in the shared function only.
    [ "$(grep -c '_underdisposed=\$(inception_underdisposed_questions' "$FRAMEWORK_ROOT/lib/review.sh")" -eq 1 ]
    [ "$(grep -c '_blockers=\$(inception_handoff_blockers' "$FRAMEWORK_ROOT/lib/review.sh")" -eq 1 ]
}

@test "batch: unready inception -> no link for any task, blockers named, non-zero exit" {
    _inception T-9001 undisposed
    _build T-9002
    run _batch T-9001 T-9002
    [ "$status" -ne 0 ]
    [ "$(grep -c '/inception/' <<<"$output")" -eq 0 ]
    [ "$(grep -c '/review/' <<<"$output")" -eq 0 ]
    grep -q 'IW-1' <<<"$output"
    grep -q 'IW-2' <<<"$output"
    grep -q 'not handoff-ready: T-9001' <<<"$output"
    grep -q 'FW_ALLOW_UNREADY_HANDOFF' <<<"$output"
}

@test "batch CONTROL: disposed inception with Recommendation gets its link; build unaffected" {
    _inception T-9001 disposed
    _build T-9002
    run _batch T-9001 T-9002
    [ "$status" -eq 0 ]
    grep -q '| T-9001 | inception | http://test-host:7777/inception/T-9001 |' <<<"$output"
    grep -q '| T-9002 | build | http://test-host:7777/review/T-9002 |' <<<"$output"
    [ "$(grep -c 'BLOCKED' <<<"$output")" -eq 0 ]
}

@test "batch: build-only batch is unaffected" {
    _build T-9002
    run _batch T-9002
    [ "$status" -eq 0 ]
    grep -q '/review/T-9002' <<<"$output"
}

@test "batch: FW_ALLOW_UNREADY_HANDOFF=1 emits and logs Tier-2 with caller emit_review_batch" {
    _inception T-9001 undisposed
    export FW_ALLOW_UNREADY_HANDOFF=1
    run _batch T-9001
    unset FW_ALLOW_UNREADY_HANDOFF
    [ "$status" -eq 0 ]
    grep -q '/inception/T-9001' <<<"$output"
    grep -q "flag: 'FW_ALLOW_UNREADY_HANDOFF'" "$P/.context/working/.gate-bypass-log.yaml"
    grep -q "caller: 'emit_review_batch'" "$P/.context/working/.gate-bypass-log.yaml"
}

@test "batch: a decided inception keeps its 'already decided' row and is not gated" {
    _inception T-9001 undisposed
    printf '\n## Decision\n\n**Decision**: GO\n\n**Rationale**: decided\n\n**Date**: 2026-09-02T00:00:00Z\n' \
        >> "$P/.tasks/active/T-9001-fixture.md"
    PROJECT_ROOT="$P" python3 "$FRAMEWORK_ROOT/lib/operator_pending.py" decided "$P/.tasks/active/T-9001-fixture.md" \
        || skip "fixture Decision shape not recognised by operator_pending.py"
    run _batch T-9001
    [ "$status" -eq 0 ]
    grep -q 'already decided' <<<"$output"
    [ "$(grep -c 'BLOCKED' <<<"$output")" -eq 0 ]
}

@test "single path unchanged: bypass log caller stays emit_review" {
    _inception T-9001 undisposed
    export FW_ALLOW_UNREADY_HANDOFF=1
    run _single T-9001
    unset FW_ALLOW_UNREADY_HANDOFF
    [ "$status" -eq 0 ]
    grep -q "caller: 'emit_review'$" "$P/.context/working/.gate-bypass-log.yaml"
}

@test "PARITY: single and batch agree on ready/not-ready for the same task file" {
    local kind single_rc batch_rc
    for kind in disposed undisposed; do
        rm -f "$P/.tasks/active/"*
        _inception T-9001 "$kind"
        single_rc=0; _single T-9001 >/dev/null || single_rc=$?
        _inception T-9001 "$kind"
        batch_rc=0; _batch T-9001 >/dev/null || batch_rc=$?
        if [ "$kind" = disposed ]; then
            [ "$single_rc" -eq 0 ]; [ "$batch_rc" -eq 0 ]
        else
            [ "$single_rc" -ne 0 ]; [ "$batch_rc" -ne 0 ]
        fi
    done
}
