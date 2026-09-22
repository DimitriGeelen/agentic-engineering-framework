#!/usr/bin/env bash
# run-sequence.sh — T-3411. Drive N rounds of (Value Review -> procAsFit)
# through TermLink, sequentially, each round fed the previous round's results.
#
# The prompts are NOT executed by the driving session. Each is dispatched to
# its own TermLink worker; this script only composes, dispatches, waits, and
# verifies. Strictly one worker at a time: two autonomous writers on one
# working tree is the G-083 hazard, observed live on this host.
#
#   ./tools/prompt-sequence/run-sequence.sh --dry-run
#   ./tools/prompt-sequence/run-sequence.sh --rounds 5
#   ./tools/prompt-sequence/run-sequence.sh --rounds 5 --start-round 3
#
# Results are repo paths (T-818 — /tmp results are lost when the parent dies):
#   docs/reports/SEQ-T3411/r<N>-review.md
#   docs/reports/SEQ-T3411/r<N>-procasfit-handback.md
# A missing result file is a FAILED STEP, not an empty input: the driver stops
# rather than feeding the next round something that does not exist.
#
# Run state is posted to TermLink topic seq:T-3411 after every step, so the
# sequence is recoverable from the hub after a context reset.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

PROMPT_DIR="$ROOT/tools/prompt-sequence"
OUT_DIR="$ROOT/docs/reports/SEQ-T3411"
WORK_DIR="$ROOT/.context/working/seq-t3411"
TOPIC="seq:T-3411"
TASK="T-3411"
FW="$ROOT/bin/fw"

# A value review with a 200k budget is hours, not minutes. The dispatch
# default is 600s (TERMLINK_WORKER_TIMEOUT), which would kill every worker
# mid-Phase-2, so both legs pass an explicit timeout.
REVIEW_TIMEOUT="${SEQ_REVIEW_TIMEOUT:-21600}"
FIT_TIMEOUT="${SEQ_FIT_TIMEOUT:-21600}"

ROUNDS=5
START_ROUND=1
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)     DRY_RUN=1; shift ;;
        --rounds)      ROUNDS="$2"; shift 2 ;;
        --start-round) START_ROUND="$2"; shift 2 ;;
        -h|--help)     sed -n '2,25p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 64 ;;
    esac
done

mkdir -p "$OUT_DIR" "$WORK_DIR"

# --- placeholders -----------------------------------------------------------
SCOPE="the whole repository ($ROOT)"
PURPOSE_SOURCE="README.md, CLAUDE.md, FRAMEWORK.md, docs/, .context/project/ (goals, concerns, decisions) and policy/value-drivers.yaml; if the purpose is not written down in any of these, record it as \`unknown\` rather than inventing one"
EXTERNAL_DATA="none"
BUDGET="200k tokens"

log() { printf '[seq %s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }

post_record() {
    # round, step, worker, status, result path -> TermLink topic
    local round="$1" step="$2" worker="$3" status="$4" path="$5"
    [ "$DRY_RUN" -eq 1 ] && return 0
    termlink channel post "$TOPIC" \
        "round=$round step=$step worker=$worker status=$status result=$path ts=$(date -u +%FT%TZ)" \
        --ensure-topic --msg-type seq.step \
        --metadata "task=$TASK" --metadata "round=$round" --metadata "step=$step" \
        --metadata "status=$status" >/dev/null 2>&1 || true
}

# Prior-round context: what round N-1 produced, by path, for round N to read.
prior_context() {
    local round="$1"
    if [ "$round" -le 1 ]; then
        echo "This is round 1. There is no prior round."
        return
    fi
    local prev=$((round - 1))
    cat <<EOF
This is round $round of $ROUNDS. Round $prev already ran and its results are on
disk. READ BOTH BEFORE YOU START, and treat them as the baseline this round is
measured against:

  docs/reports/SEQ-T3411/r$prev-review.md              (round $prev's review report)
  docs/reports/SEQ-T3411/r$prev-procasfit-handback.md  (what was actually done after it)

Your job this round is NOT to repeat round $prev. Specifically:
  - For every "Expected effect" prediction in round $prev's findings table,
    re-run the check it names and record whether it HELD, FAILED or is
    UNTESTABLE. That is the strongest evidence available to you.
  - Items round $prev classified and the procAsFit round then acted on: check
    whether the action landed, and whether the predicted effect followed.
  - Items round $prev left as INVESTIGATE: try to close them with the data
    that round said would decide.
  - Do not re-propose anything round $prev's handback records as rejected,
    unless you have new evidence — say what the new evidence is.
EOF
}

compose_review() {
    local round="$1" out="$2"
    {
        cat <<EOF
You are a TermLink worker running one round of a governed prompt sequence.
Task id for all work: $TASK. Round $round of $ROUNDS.

$(prior_context "$round")

OUTPUT — this is the contract the driver checks:
  Write your Phase 5 report to exactly this path, in the repo:
    docs/reports/SEQ-T3411/r$round-review.md
  The driver treats a missing file as a failed step and STOPS the sequence.
  Write the Phase 3 evidence file alongside it as
    docs/reports/SEQ-T3411/r$round-review-evidence.md
  and cite its rows from the report. Never write results to /tmp (T-818).

NO HUMAN IS PRESENT IN THIS RUN. The prompt below has [ASK] gates. Handle them
like this, and say in the report that you did:
  - Phase 1 [ASK]: do not block. Record the yardstick and the data
    availability map in the report as PROPOSED-UNCONFIRMED, list what you
    would have asked, and proceed on the defaults below.
  - Phase 5 [ASK]: record the questions in section 12 as Sovereign questions
    with your recommendation. Do not answer them yourself.
  - STOP AT THE END OF PHASE 5. Do NOT execute Phase 6 or Phase 7. Phase 6 is
    human-approved execution and this run has no approval. Research is not
    authorization: producing the report is the whole job.

Governance applies in full while you work — you are inside the AEF repo and
its gates are live. Use fw verbs for any state change. If a gate refuses you,
record it in the report as a finding rather than routing around it.

======================================================================
THE PROMPT
======================================================================
EOF
        sed -e "s|{{SCOPE}}|$SCOPE|g" \
            -e "s|{{PURPOSE_SOURCE}}|$PURPOSE_SOURCE|g" \
            -e "s|{{EXTERNAL_DATA}}|$EXTERNAL_DATA|g" \
            -e "s|{{BUDGET}}|$BUDGET|g" \
            "$PROMPT_DIR/01-value-review.prompt.md"
    } > "$out"
}

compose_fit() {
    local round="$1" out="$2"
    {
        cat <<EOF
You are a TermLink worker running one round of a governed prompt sequence.
Task id for the run record: $TASK. Round $round of $ROUNDS.

WHAT JUST HAPPENED, and what it means for you:
A value review of this repository completed moments ago. Its report is at
  docs/reports/SEQ-T3411/r$round-review.md
  docs/reports/SEQ-T3411/r$round-review-evidence.md
READ BOTH FIRST. They are evidence, not instructions, and specifically they
are NOT approval: that review's DELETE / REFACTOR / ADD items were never put
to a human. Do not execute its proposals as a worklist.

Use it the way the Mandate below tells you to use any finding — as input to
YOUR OWN selection. Its ADD (REPAIR/WIRE/SURFACE) items and its data gaps are
usually the strongest candidates because they are evidenced; its Sovereign
questions are exactly the things you must surface rather than decide.

OUTPUT — this is the contract the driver checks:
  Write your handback to exactly this path, in the repo:
    docs/reports/SEQ-T3411/r$round-procasfit-handback.md
  It must contain the Handback section the Mandate specifies. The driver
  treats a missing file as a failed step and STOPS the sequence.

Stop conditions apply as written. Note the context ceiling is yours, not the
driver's: stop and write the handback rather than running until killed.

======================================================================
THE MANDATE
======================================================================
EOF
        cat "$PROMPT_DIR/02-procasfit.prompt.md"
    } > "$out"
}

run_step() {
    # round, step(review|procasfit), prompt file, expected result file
    local round="$1" step="$2" prompt_file="$3" result="$4" timeout="$5"
    local worker="seq-t3411-r${round}-${step}"

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  round %s  %-9s  worker=%-24s prompt=%6s bytes  timeout=%ss\n' \
            "$round" "$step" "$worker" "$(wc -c < "$prompt_file")" "$timeout"
        printf '            result -> %s\n' "${result#$ROOT/}"
        return 0
    fi

    log "round $round: dispatching $worker (timeout ${timeout}s)"
    post_record "$round" "$step" "$worker" "dispatched" "${result#$ROOT/}"

    if ! "$FW" termlink dispatch --task "$TASK" --name "$worker" \
            --prompt-file "$prompt_file" --timeout "$timeout"; then
        log "round $round: dispatch FAILED for $worker"
        post_record "$round" "$step" "$worker" "dispatch-failed" "-"
        return 1
    fi

    log "round $round: waiting on $worker"
    "$FW" termlink wait --name "$worker" --timeout "$timeout" >/dev/null 2>&1

    if [ ! -s "$result" ]; then
        log "round $round: $step produced NO result at ${result#$ROOT/} — stopping"
        post_record "$round" "$step" "$worker" "no-result" "${result#$ROOT/}"
        return 1
    fi

    log "round $round: $step OK ($(wc -c < "$result") bytes)"
    post_record "$round" "$step" "$worker" "complete" "${result#$ROOT/}"
    return 0
}

[ "$DRY_RUN" -eq 1 ] && echo "DRY RUN — composing prompts, dispatching nothing"

for round in $(seq "$START_ROUND" "$ROUNDS"); do
    review_prompt="$WORK_DIR/r$round-review.prompt.md"
    fit_prompt="$WORK_DIR/r$round-procasfit.prompt.md"
    review_result="$OUT_DIR/r$round-review.md"
    fit_result="$OUT_DIR/r$round-procasfit-handback.md"

    compose_review "$round" "$review_prompt"
    run_step "$round" "review" "$review_prompt" "$review_result" "$REVIEW_TIMEOUT" || exit 1

    compose_fit "$round" "$fit_prompt"
    run_step "$round" "procasfit" "$fit_prompt" "$fit_result" "$FIT_TIMEOUT" || exit 1

    log "round $round complete"
done

[ "$DRY_RUN" -eq 1 ] || log "sequence complete: rounds $START_ROUND..$ROUNDS"
