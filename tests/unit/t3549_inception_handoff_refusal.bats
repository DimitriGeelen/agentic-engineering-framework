#!/usr/bin/env bats
# T-3549 — an inception handoff is REFUSED when the decision it invites would be
# refused.
#
# `emit_review` detected the under-disposed state from T-3279 onward and WARNED,
# then handed over anyway. T-3540 added a footer so the blocker travelled with
# the handoff. Both kept emission unblocked, on two reasons this file's fixture
# set now pins as false:
#
#   1. "Refusing would strand a task whose only problem is that nobody has
#      answered its questions yet." `deferred` is always an available
#      disposition, so no question is undisposable and nothing can be stranded.
#   2. "The blocker travels WITH the handoff, so an agent cannot hand it over
#      unaware." True and irrelevant — on T-3548 the agent read the warning and
#      relayed it to the operator with a justification attached. Awareness was
#      never the failure mode.
#
# Third operator-facing instance (T-3532, T-3535, T-3548), the second after an
# explicit escalation. The decide-time gate (T-2190) is NOT touched here: it
# worked correctly every time. The defect was that it fired after the handoff,
# so the operator was the one who discovered it.
#
# THE CONTROL IS LOAD-BEARING. Without "a ready inception still emits", every
# assertion below is satisfied by a build that refuses everything.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/lib/review.sh" ] || { echo "missing lib/review.sh" >&2; return 1; }
    P="$(mktemp -d)"
    mkdir -p "$P/.tasks/active" "$P/.context/working"
}

teardown() {
    if [ -n "${P:-}" ]; then rm -rf "$P"; fi
    return 0
}

# _inception DISPOSITIONS — a filed inception with two IW questions.
#   disposed   : both carry a disposition value
#   undisposed : both have the line but no value (T-3548's exact shape)
#   mixed      : one disposed, one not
_inception() {
    local kind="$1"
    { printf -- '---\nid: T-9999\nname: "fixture inception"\nstatus: started-work\n'
      printf 'workflow_type: inception\nowner: human\nhorizon: now\n'
      printf 'created: 2026-09-01T00:00:00Z\nlast_update: 2026-09-01T00:00:00Z\n---\n\n'
      printf '# T-9999: fixture inception\n\n## Problem Statement\n\nx\n\n'
      printf '## Open Questions\n\n'
      case "$kind" in
        disposed)
          printf -- '- **IW-1: first question**\n  confidence: 2\n  disposition: answered\n  rationale: because evidence\n\n'
          printf -- '- **IW-2: second question**\n  confidence: 1\n  disposition: deferred\n  rationale: to its own ruling\n\n' ;;
        undisposed)
          printf -- '- **IW-1: first question**\n  confidence: 2\n  disposition:\n  rationale: because evidence\n\n'
          printf -- '- **IW-2: second question**\n  confidence: 1\n  disposition:\n  rationale: to its own ruling\n\n' ;;
        mixed)
          printf -- '- **IW-1: first question**\n  confidence: 2\n  disposition: answered\n  rationale: because evidence\n\n'
          printf -- '- **IW-2: second question**\n  confidence: 1\n  disposition:\n  rationale: to its own ruling\n\n' ;;
      esac
      printf '## Recommendation\n\n**Recommendation:** GO\n\n**Rationale:** because.\n\n'
      printf '## Acceptance Criteria\n\n### Agent\n- [x] done\n\n'; } \
      > "$P/.tasks/active/T-9999-fixture.md"
}

_review() {
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        timeout 120 bash -c "source '$FRAMEWORK_ROOT/lib/review.sh'; emit_review T-9999" 2>&1
}

# ── the control: the ready path is untouched ─────────────────────────────────

@test "CONTROL: a fully disposed inception still emits its handoff" {
    _inception disposed
    run _review
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c 'BLOCKED')" -eq 0 ]
    echo "$output" | grep -qi 'inception'
}

# ── the refusal ──────────────────────────────────────────────────────────────

@test "an under-disposed inception is REFUSED, not warned" {
    _inception undisposed
    run _review
    [ "$status" -ne 0 ]
    echo "$output" | grep -q 'BLOCKED'
    # The old behaviour is specifically what must not return.
    [ "$(echo "$output" | grep -c 'WARNING: this inception is NOT decision-ready')" -eq 0 ]
}

@test "the refusal emits NO handoff URL — the whole point" {
    # A handoff artefact that cannot become a decision is worse than none: it
    # looks like a decision request and is not one.
    _inception undisposed
    run _review
    [ "$(echo "$output" | grep -c 'http')" -eq 0 ]
}

@test "one undisposed question out of two is enough to refuse" {
    _inception mixed
    run _review
    [ "$status" -ne 0 ]
    echo "$output" | grep -q 'IW-2'
    [ "$(echo "$output" | grep -c 'http')" -eq 0 ]
}

@test "the refusal names each offending question, not just a count" {
    _inception undisposed
    run _review
    echo "$output" | grep -q 'IW-1'
    echo "$output" | grep -q 'IW-2'
}

@test "the refusal names deferred as always-available — the belief that killed the block" {
    # The WARN existed because someone believed a question might be undisposable
    # and refusing would strand the task. Saying so in the block message is what
    # stops that belief being re-derived by the next reader.
    _inception undisposed
    run _review
    echo "$output" | grep -q 'deferred'
    echo "$output" | grep -qi 'always'
}

@test "the refusal names the file to edit and the legal values" {
    _inception undisposed
    run _review
    echo "$output" | grep -q 'T-9999-fixture.md'
    echo "$output" | grep -q 'answered'
    echo "$output" | grep -q 'dissolved'
}

# ── the bypass ───────────────────────────────────────────────────────────────

@test "FW_ALLOW_UNREADY_HANDOFF=1 emits, and writes a Tier-2 entry" {
    _inception undisposed
    run env FW_ALLOW_UNREADY_HANDOFF=1 PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        timeout 120 bash -c "source '$FRAMEWORK_ROOT/lib/review.sh'; emit_review T-9999"
    [ "$status" -eq 0 ]
    [ -f "$P/.context/working/.gate-bypass-log.yaml" ]
    grep -q 'FW_ALLOW_UNREADY_HANDOFF' "$P/.context/working/.gate-bypass-log.yaml"
    grep -q 'T-9999' "$P/.context/working/.gate-bypass-log.yaml"
}

@test "the bypass log is written by THIS file, not by an out-of-scope helper" {
    # log_gate_bypass() is defined in agents/task-create/update-task.sh and is
    # NOT in lib/review.sh's scope. The first draft called it with `|| true`,
    # which would have skipped the Tier-2 record silently — the same
    # silent-failure class this task removes. Pinned so it cannot regress to
    # that form.
    # Comments are stripped first: the block's own comment EXPLAINS why
    # log_gate_bypass is not called, so an unstripped grep matches the
    # explanation and reddens on the correct code. Same text-vs-behaviour trap
    # as tests/unit/sidecar_audit_rail.bats hit on the word `termlink`.
    body=$(awk '/FW_ALLOW_UNREADY_HANDOFF/,/^                fi$/' "$FRAMEWORK_ROOT/lib/review.sh" \
           | grep -v '^[[:space:]]*#')
    [ -n "$body" ]
    [ "$(printf '%s\n' "$body" | grep -c 'log_gate_bypass')" -eq 0 ]
    printf '%s\n' "$body" | grep -q 'gate-bypass-log.yaml'
}

# ── the decide-time gate is untouched ────────────────────────────────────────

@test "T-2190's decide-time predicate is unchanged and still the last line" {
    # This task moved the EARLIEST check, not the last one. The shared predicate
    # must still exist and still be what emit_review consults.
    grep -q 'inception_underdisposed_questions' "$FRAMEWORK_ROOT/lib/review.sh"
    grep -q 'inception_underdisposed_questions()' "$FRAMEWORK_ROOT/lib/inception-readiness.sh"
}

@test "the caller contract on the shared predicate is still honoured" {
    # inception_underdisposed_questions returns 1 as a FINDING (OBS-566), and
    # emit_review runs under set -euo pipefail. The `|| true` guard is what keeps
    # the refusal from killing the command before it can print (T-3539).
    grep -q '_underdisposed=$(inception_underdisposed_questions "$task_file") || true' \
        "$FRAMEWORK_ROOT/lib/review.sh"
}

# ── the unified predicate + bounded auto-adjust (T-3549 legs 2 and 3) ────────

_no_rec() {
    { printf -- '---\nid: T-9999\nname: "no rec"\nstatus: started-work\n'
      printf 'workflow_type: inception\nowner: human\nhorizon: now\n'
      printf 'created: 2026-09-01T00:00:00Z\nlast_update: 2026-09-01T00:00:00Z\n---\n\n'
      printf '# T-9999\n\n## Problem Statement\n\nx\n\n'
      printf '## Acceptance Criteria\n\n### Agent\n- [x] done\n'; } \
      > "$P/.tasks/active/T-9999-fixture.md"
}

@test "auto-adjust scaffolds a MISSING Recommendation section" {
    _no_rec
    run _review
    echo "$output" | grep -q 'auto-adjusted'
    grep -q '^## Recommendation' "$P/.tasks/active/T-9999-fixture.md"
}

@test "auto-adjust supplies SHAPE but never a verdict — it must still be refused" {
    # The whole boundary of the feature: repairing structure must not create
    # readiness. An auto-written GO would pass every gate with nobody having
    # thought about it, which is worse than the omission being fixed.
    _no_rec
    run _review
    [ "$status" -ne 0 ]
    echo "$output" | grep -q 'empty-recommendation'
    [ "$(echo "$output" | grep -c 'http')" -eq 0 ]
    # the scaffold carries no verdict word
    [ "$(grep -cE '^\*\*Recommendation:\*\* *(GO|NO-GO|DEFER)' "$P/.tasks/active/T-9999-fixture.md")" -eq 0 ]
}

@test "the unified predicate ALWAYS returns 0 — findings ride stdout (OBS-566)" {
    # Its sibling returns 1 as a finding, which silently killed three commands
    # until T-3539. This one must never repeat that contract.
    _inception undisposed
    run bash -c "source '$FRAMEWORK_ROOT/lib/inception-readiness.sh'; source '$FRAMEWORK_ROOT/lib/task-audit.sh'; set -euo pipefail; out=\$(inception_handoff_blockers '$P/.tasks/active/T-9999-fixture.md'); echo \"rc=\$?\"; echo \"\$out\" | head -1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'rc=0'
    echo "$output" | grep -q 'undisposed-question'
}

@test "grandfathering holds: no Open Questions section is not a disposition blocker" {
    # T-2190 grandfathers an inception with no '## Open Questions'. Inventing
    # that requirement here would block legitimate inceptions.
    { printf -- '---\nid: T-9999\nname: "no oq"\nstatus: started-work\n'
      printf 'workflow_type: inception\nowner: human\nhorizon: now\n'
      printf 'created: 2026-09-01T00:00:00Z\nlast_update: 2026-09-01T00:00:00Z\n---\n\n'
      printf '# T-9999\n\n## Recommendation\n\n**Recommendation:** GO\n\n**Rationale:** because.\n\n'
      printf '## Acceptance Criteria\n\n### Agent\n- [x] done\n'; } \
      > "$P/.tasks/active/T-9999-fixture.md"
    run _review
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c 'BLOCKED')" -eq 0 ]
}

@test "auto-adjust does NOT invent an Open Questions section" {
    _no_rec
    run _review
    [ "$(grep -c '^## Open Questions' "$P/.tasks/active/T-9999-fixture.md")" -eq 0 ]
}
