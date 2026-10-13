#!/usr/bin/env bats
# T-4191 (832 OBS-452, their T-1150): a handover nobody filled in must LOOK
# unfilled. The generator wrote a bare "None" under Decisions / Failures / Open
# Questions and "See task file" / "None" per task, so an empty handover read as
# a complete one and /resume (which counts [TODO]) gave no warning. And the
# commit-derived "Where We Are" read as an authored narrative.
#
# End-to-end against the real generator on a synthetic git-backed corpus.

setup_file() {
    export TMPROOT="$(mktemp -d)"
    export FW_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    mkdir -p "$TMPROOT/.tasks/active" "$TMPROOT/.context/handovers" \
             "$TMPROOT/.context/working" "$TMPROOT/.context/project" \
             "$TMPROOT/out-0" "$TMPROOT/out-1"
    cat > "$TMPROOT/.tasks/active/T-9001-fixture.md" <<'EOF'
---
id: T-9001
name: fixture task
status: started-work
workflow_type: build
horizon: now
last_update: '2026-08-01T00:00:00Z'
---

## Acceptance Criteria
EOF
    echo "observations: []" > "$TMPROOT/.context/inbox.yaml"
    git -C "$TMPROOT" init -q
    git -C "$TMPROOT" -c user.name=t -c user.email=t@t commit -q --allow-empty \
        -m "T-9001: wire the fixture widget"

    _gen() {  # $1 = digest flag, $2 = session id
        env PROJECT_ROOT="$TMPROOT" NTFY_ENABLED=0 \
            TASKS_DIR="$TMPROOT/.tasks" CONTEXT_DIR="$TMPROOT/.context" \
            HANDOVER_DIR="$TMPROOT/out-$1" FW_HANDOVER_DIGEST="$1" \
            bash "$FW_ROOT/agents/handover/handover.sh" --session "$2" --no-commit \
            >/dev/null 2>&1 || true
    }
    _gen 0 S-T4191-FULL
    _gen 1 S-T4191-DIG
    export FULL="$TMPROOT/out-0/S-T4191-FULL.md"
    export DIG="$TMPROOT/out-1/S-T4191-DIG.md"
}

teardown_file() {
    rm -rf "$TMPROOT"
}

_section() {  # $1 = file, $2 = heading text
    awk -v h="## $2" '$0==h {on=1; next} on && /^## / {exit} on' "$1"
}

@test "handovers were generated" {
    [ -s "$FULL" ]
    [ -s "$DIG" ]
}

@test "narrative sections carry [TODO], not a bare None" {
    for sec in "Decisions Made This Session" "Things Tried That Failed" \
               "Open Questions / Blockers"; do
        body=$(_section "$DIG" "$sec")
        echo "$sec => $body"
        echo "$body" | grep -q '\[TODO'
        if echo "$body" | grep -qx 'None'; then false; fi
    done
}

@test "digest mode stays at 3 [TODO] so audit D8 warns rather than fails" {
    n=$(grep -c '\[TODO' "$DIG")
    [ "$n" -eq 3 ]
}

@test "full mode: per-task Next step / Blockers carry [TODO]" {
    grep -q '^- \*\*Next step:\*\* \[TODO' "$FULL"
    grep -q '^- \*\*Blockers:\*\* \[TODO' "$FULL"
    if grep -q '^- \*\*Next step:\*\* See task file' "$FULL"; then false; fi
    if grep -q '^- \*\*Blockers:\*\* None$' "$FULL"; then false; fi
}

@test "commit-derived Where We Are is marked AUTO-MINED / VERIFY" {
    body=$(_section "$DIG" "Where We Are")
    echo "$body"
    echo "$body" | grep -q 'T-9001'
    echo "$body" | grep -q 'AUTO-MINED from commit subjects — VERIFY'
}
