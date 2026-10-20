#!/usr/bin/env bats
# T-4476 (termlink proposal 346, their T-2882/T-3370): an unfilled handover must
# say it is unfilled. The frontmatter carries `enrichment_status: pending`, the
# Gotchas section no longer deflects to "See gaps register above.", and the
# Suggested First Action line discloses that it is a mechanical ranking.
#
# End-to-end against the real generator on a synthetic git-backed corpus.

setup_file() {
    export TMPROOT="$(mktemp -d)"
    export FW_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    mkdir -p "$TMPROOT/.tasks/active" "$TMPROOT/.context/handovers" \
             "$TMPROOT/.context/working" "$TMPROOT/.context/project" \
             "$TMPROOT/out-full" "$TMPROOT/out-focus" "$TMPROOT/out-cp"
    for n in 9001 9002; do
        cat > "$TMPROOT/.tasks/active/T-$n-fixture.md" <<EOF
---
id: T-$n
name: fixture task $n
status: started-work
workflow_type: build
horizon: now
last_update: '2026-08-0${n: -1}T00:00:00Z'
---

## Acceptance Criteria
EOF
    done
    echo "observations: []" > "$TMPROOT/.context/inbox.yaml"
    git -C "$TMPROOT" init -q
    git -C "$TMPROOT" -c user.name=t -c user.email=t@t commit -q --allow-empty \
        -m "T-9001: wire the fixture widget"

    _gen() {  # $1 = out dir, $2 = session id, rest = extra args
        local out="$1" sid="$2"; shift 2
        env PROJECT_ROOT="$TMPROOT" NTFY_ENABLED=0 \
            TASKS_DIR="$TMPROOT/.tasks" CONTEXT_DIR="$TMPROOT/.context" \
            HANDOVER_DIR="$TMPROOT/$out" \
            bash "$FW_ROOT/agents/handover/handover.sh" --session "$sid" --no-commit "$@" \
            >/dev/null 2>&1 || true
    }
    # No focus: the heuristic branch (most recent last_update wins → T-9002).
    _gen out-full S-T4476-FULL
    # Focus on the older task: the focus branch.
    printf 'current_task: T-9001\n' > "$TMPROOT/.context/working/focus.yaml"
    _gen out-focus S-T4476-FOCUS
    _gen out-cp S-T4476-CP --checkpoint
    export FULL="$TMPROOT/out-full/S-T4476-FULL.md"
    export FOCUS="$TMPROOT/out-focus/S-T4476-FOCUS.md"
    export CP="$(ls "$TMPROOT"/out-cp/*.md 2>/dev/null | grep -v LATEST | head -1)"
}

teardown_file() {
    rm -rf "$TMPROOT"
}

_section() {  # $1 = file, $2 = heading text
    awk -v h="## $2" '$0==h {on=1; next} on && /^## / {exit} on' "$1"
}

_frontmatter() {
    awk 'NR==1 && /^---$/ {on=1; next} on && /^---$/ {exit} on' "$1"
}

@test "handovers were generated" {
    [ -s "$FULL" ]
    [ -s "$FOCUS" ]
    [ -n "$CP" ] && [ -s "$CP" ]
}

@test "full handover frontmatter carries enrichment_status: pending" {
    _frontmatter "$FULL" | grep -qx 'enrichment_status: pending'
}

@test "checkpoint frontmatter carries enrichment_status: pending" {
    _frontmatter "$CP" | grep -qx 'enrichment_status: pending'
}

@test "Gotchas no longer deflects to the gaps register" {
    run _section "$FULL" "Gotchas / Warnings for Next Session"
    [[ "$output" != *"See gaps register above."* ]]
    [[ "$output" == *"not an answer"* ]]
}

@test "Gotchas placeholder adds no [TODO token (D8 grading unchanged)" {
    run _section "$FULL" "Gotchas / Warnings for Next Session"
    [[ "$output" != *"[TODO"* ]]
}

@test "heuristic suggestion discloses it is a mechanical ranking" {
    run _section "$FULL" "Suggested First Action"
    [[ "$output" == *"Continue T-9002: fixture task 9002"* ]]
    [[ "$output" == *"Mechanical fallback, ranked by owner, horizon and last update"* ]]
    [[ "$output" == *"not a reasoned recommendation"* ]]
}

@test "focused suggestion discloses it is the current focus, not advice" {
    run _section "$FOCUS" "Suggested First Action"
    [[ "$output" == *"Continue T-9001: fixture task 9001"* ]]
    [[ "$output" == *"Mechanical fallback, ranked by current focus"* ]]
}

@test "focus lookup defaults CONTEXT_DIR to PROJECT_ROOT/.context" {
    grep -qF "\${CONTEXT_DIR:-\$PROJECT_ROOT/.context}', 'working', 'focus.yaml'" \
        "$FW_ROOT/agents/handover/handover.sh"
}

@test "commit-pending hook from proposal 346 was not applied" {
    run grep -c 'commit-pending' "$FW_ROOT/agents/handover/handover.sh"
    [ "$output" = "0" ]
}
