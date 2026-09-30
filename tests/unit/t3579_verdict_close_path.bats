#!/usr/bin/env bats
# T-3579 — closing on an independent reviewer's green verdict is the NORMAL path.
#
# Every step is the shipped code: `fw reviewer verdict record`, then update-task.sh
# --status work-completed. No --skip-* flag, no FW_ALLOW_* variable anywhere in this
# file — that absence is the assertion. A render-surface task with a human-owned taste
# [REVIEW] criterion is the exact shape that took --skip-render-review +
# FW_ALLOW_PARTIAL_COMPLETE_EDIT=1 seven times on 2026-09-29/30.

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"
UPDATE_TASK="$BATS_TEST_DIRNAME/../../agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic" "$PROJECT_ROOT/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    ln -sf "$FRAMEWORK_ROOT/bin/fw" "$PROJECT_ROOT/bin/fw"
    echo "screenshot notes" > "$PROJECT_ROOT/evidence.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR" "$TEST_TEMP_DIR.tl"
}

_make_render_task() {
    local f="$PROJECT_ROOT/.tasks/active/T-9200-render-fixture.md"
    cat > "$f" <<'TASK'
---
id: T-9200
name: "render fixture"
description: "render-surface task with one taste criterion"
status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/templates/fixture.html]
created: 2026-09-30T00:00:00Z
last_update: 2026-09-30T00:00:00Z
date_finished: null
---

# T-9200: render fixture

## Acceptance Criteria

### Agent
- [x] Fixture body is in place

### Human
- [ ] [REVIEW] The rendered page reads clearly
  **Steps:**
  1. Open the page
  **Expected:** it reads as a peer briefing
  **If not:** note the section that stalls

## Verification

## Recommendation

**Recommendation:** GO

**Rationale:** Fixture.

## Updates
TASK
    echo "$f"
}

_dispatch() {
    # Register a review dispatch the way the dispatcher does (T-3581): with the runtime's worker
    # directory, and the revision under review (HEAD now, before the worker runs — T-3580 round 3).
    mkdir -p "$TEST_TEMP_DIR.tl/${1:-rv-1}"
    PROJECT_ROOT="$PROJECT_ROOT" python3 "$BATS_TEST_DIRNAME/../../lib/verdict_ledger.py" \
        register-dispatch --dispatch-id "${1:-rv-1}" --task T-9200 --task-type review \
        --wdir "$TEST_TEMP_DIR.tl/${1:-rv-1}" --worker-kind claude "${@:2}" >/dev/null
}

_finish() {
    # The worker exited: the dispatch runtime (run.sh) writes its exit state and signs the
    # completion. The real CLI, outside the worker's environment.
    local w="$TEST_TEMP_DIR.tl/${1:-rv-1}"
    echo '{"type":"result"}' > "$w/result.jsonl"
    echo 0 > "$w/exit_code"
    # T-3580 round 6: the runtime's START issues the completion secret, and `start`/`complete`
    # authenticate their caller as the canonical `<wdir>/run.sh` (which would launch a real
    # worker). This close-path suite tests the CLOSE, so the runtime is played by the shared test
    # double (tests/unit/_review_runtime.as_runtime); the real run.sh is exercised by
    # t3580_round3/5/6 `_run_worker`.
    W="$w" DID="${1:-rv-1}" PROJECT_ROOT="$PROJECT_ROOT" \
        PYTHONPATH="$BATS_TEST_DIRNAME/../..:$BATS_TEST_DIRNAME" python3 - <<'PY'
import os
from pathlib import Path
from lib import verdict_ledger as vl
import _review_runtime as rt
root, w, did = Path(os.environ["PROJECT_ROOT"]), os.environ["W"], os.environ["DID"]
with rt.as_runtime():
    _st, secret = vl.start(did, wdir=w, root=root)
    vl.complete(did, wdir=w, exit_code=0, session=did, secret=secret, root=root)
PY
}

_as() {
    # Run git as a named identity. Env, not `-c user.name`: dispatch sessions export GIT_AUTHOR_*.
    local who="$1"; shift
    GIT_AUTHOR_NAME="$who" GIT_AUTHOR_EMAIL="${who// /.}@x.y" \
        GIT_COMMITTER_NAME="$who" GIT_COMMITTER_EMAIL="${who// /.}@x.y" \
        git -C "$PROJECT_ROOT" -c core.hooksPath=/dev/null "$@"
}

_produce() {
    [ -d "$PROJECT_ROOT/.git" ] || git -C "$PROJECT_ROOT" init -q
    # The producer's commit touches a render surface — that is what makes P-013 apply.
    mkdir -p "$PROJECT_ROOT/web/templates" && echo "<p>fixture</p>" > "$PROJECT_ROOT/web/templates/fixture.html"
    git -C "$PROJECT_ROOT" add -A
    _as "Builder Bot" commit -q -m "T-9200: build it"
}

_record() {
    # The shipped path: the producer has committed, the reviewer submits the digest it read,
    # names a registered review dispatch, and commits its own row as its own worker identity.
    # A render criterion also needs a signed review run that recorded the pages required and a
    # verified screenshot of each (T-3580 round 2): the judge's part, played here in python.
    git -C "$PROJECT_ROOT" rev-parse -q --verify HEAD >/dev/null 2>&1 || _produce
    local dg extra=() rung=cross-vendor
    dg=$("$FW" reviewer verdict digest T-9200 --ac 1)
    if [ "$1" = green ]; then
        # T-3580 round 6: the run is registered first, at the rung IW-7 requires (the shared
        # policy), and the dispatch is bound to it AT REGISTRATION — before the worker runs.
        printf 'png' > "$PROJECT_ROOT/shot-rv-1.png"
        rung=$(PYTHONPATH="$BATS_TEST_DIRNAME/../.." PROJECT_ROOT="$PROJECT_ROOT" python3 - <<'PY'
import os
from pathlib import Path
from lib import review_policy, verdict_ledger as vl
root = Path(os.environ["PROJECT_ROOT"])
ctx = vl._task_ctx(root, "T-9200")
crit = next(c for c in vl.human_criteria(ctx.text) if c.index == 1)
label = review_policy.rung_label(vl.required_strength(ctx, crit)[0])
vl.register_run("run-rv-1", "T-9200", acs=[1], rung=label,
                seats=[{"seat": "claude", "vendor": "claude"}], required_vendors=1,
                pages={"1": ["/review"]},
                captures=[{"page": "/review", "ok": True, "sha256": vl._hash_path(root / "shot-rv-1.png"), "error": ""}],
                root=root)
print(label)
PY
)
        _dispatch rv-1 --run-id run-rv-1 --seat claude
        extra=(--run-id run-rv-1 --evidence shot-rv-1.png)
    else
        _dispatch rv-1
    fi
    "$FW" reviewer verdict record T-9200 --ac 1 --outcome "$1" --reviewer "reviewer-rv-1:openai/gpt-5" \
        --rung "$rung" --dispatch-id rv-1 --digest "$dg" "${extra[@]}" "${@:2}" || return $?
    git -C "$PROJECT_ROOT" add .context/reviews
    _as "reviewer-rv-1" commit -q -m "T-9200: reviewer verdict"
    _finish rv-1
}

@test "without a verdict the render task is refused by the sovereignty gate" {
    _make_render_task >/dev/null
    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "Sovereignty gate"
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 1 ]
}

@test "a green verdict closes the render task with no bypass flag, and the gate names the verdict" {
    local f; f="$(_make_render_task)"
    run _record green --evidence evidence.md
    [ "$status" -eq 0 ]

    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Render-surface gate: satisfied by green verdict V-"
    echo "$output" | grep -q "openai/gpt-5"

    [ "$(ls "$PROJECT_ROOT/.tasks/completed" | grep -c '^T-9200-')" -eq 1 ]
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 0 ]
    grep -q "Reviewer verdict:\*\* green V-" "$PROJECT_ROOT/.tasks/completed/"T-9200-*.md
    grep -q '"kind":"verdict-apply"' "$PROJECT_ROOT/.context/reviews/applied.jsonl"

    # No bypass was used, so none was logged.
    ! grep -qs "skip-render-review\|skip-sovereignty\|skip-human-ownership" \
        "$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "an amber verdict does not close it and lands on the refusal ledger" {
    _make_render_task >/dev/null
    run _record amber --guidance "tighten the second section"
    [ "$status" -eq 0 ]

    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 1 ]
    grep -q '"class":"verdict-amber"' "$PROJECT_ROOT/.context/reviews/refusals-interim.jsonl"
}

@test "a verdict recorded before the criterion was edited no longer closes it" {
    local f; f="$(_make_render_task)"
    run _record green --evidence evidence.md
    [ "$status" -eq 0 ]
    sed -i 's/reads clearly/reads very clearly/' "$f"

    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 1 ]
}

@test "the CLI refuses a green record from the producer" {
    _make_render_task >/dev/null
    _produce
    _dispatch rv-1
    run "$FW" reviewer verdict record T-9200 --ac 1 --outcome green --reviewer "reviewer-rv-1:Builder Bot" \
        --rung same-agent --dispatch-id rv-1 --digest "$("$FW" reviewer verdict digest T-9200 --ac 1)" \
        --evidence evidence.md
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "never the producer"
    [ ! -f "$PROJECT_ROOT/.context/reviews/verdicts.jsonl" ]
}

@test "T-3581 containment: a hand-appended green row does not close the render task" {
    local f; f="$(_make_render_task)"
    mkdir -p "$PROJECT_ROOT/.context/reviews"
    local dg
    dg=$(PROJECT_ROOT="$PROJECT_ROOT" python3 -c "
import sys; sys.path.insert(0,'$BATS_TEST_DIRNAME/../..')
from lib import verdict_ledger as v; from lib.delegation import human_criteria
t=open('$f').read(); print(v.criterion_digest(human_criteria(t)[0]))")
    printf '{"id":"V-FORGED","task":"T-9200","ac":1,"ac_digest":"%s","outcome":"green","verdict":"green","reviewer":"independent-reviewer-session-7","rung":"x","evidence":["evidence.md"]}\n' "$dg" \
        > "$PROJECT_ROOT/.context/reviews/verdicts.jsonl"

    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 1 ]
    ! echo "$output" | grep -q "Render-surface gate: satisfied"
}

@test "T-3581: a close attempt that fails a later gate does not leave a permanent tick — a later red withdraws it" {
    local f; f="$(_make_render_task)"
    run _record green --evidence evidence.md
    [ "$status" -eq 0 ]
    # Give the task a verification line that fails, so apply runs and a LATER gate refuses.
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(t.replace("## Verification\n", "## Verification\n\nfalse\n", 1))
PY
    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    grep -q "^owner: agent" "$f"                       # apply ticked and handed ownership over
    grep -q "\[x\] \[REVIEW\]" "$f"

    # An independent reviewer now returns red. The tick must not survive it.
    _dispatch rv-2
    run "$FW" reviewer verdict record T-9200 --ac 1 --outcome red --reviewer "reviewer-rv-2:zai/glm-5" \
        --rung cross-vendor --dispatch-id rv-2 --guidance "contradicts itself" \
        --digest "$("$FW" reviewer verdict digest T-9200 --ac 1)"
    [ "$status" -eq 0 ]
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(t.replace("\nfalse\n", "\ntrue\n", 1))     # every other gate now passes
PY
    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "WITHDRAWN"
    grep -q "^owner: human" "$f"
    grep -q "\[ \] \[REVIEW\]" "$f"
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 1 ]
}

@test "T-3581 round 4: stripping the annotation from a reviewer-derived tick refuses the close (control: intact annotation revalidates)" {
    local f; f="$(_make_render_task)"
    run _record green --evidence evidence.md
    [ "$status" -eq 0 ]
    run "$FW" reviewer verdict apply T-9200
    [ "$status" -eq 0 ]
    grep -q "Reviewer verdict:" "$f"
    run "$FW" reviewer verdict apply T-9200                       # control: intact annotation is fine
    [ "$status" -eq 0 ]
    grep -v "Reviewer verdict:" "$f" > "$f.new" && mv "$f.new" "$f"
    run "$FW" reviewer verdict apply T-9200
    [ "$status" -eq 1 ]
    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "revalidation failed"
    grep -q "\\[x\\] \\[REVIEW\\]" "$f"
}

@test "T-3581: a green recorded under a pseudonym with no review dispatch cannot be recorded, and a forged registry row does not help" {
    _make_render_task >/dev/null
    _produce
    run "$FW" reviewer verdict record T-9200 --ac 1 --outcome green \
        --reviewer "independent-reviewer-session-7" --rung x --evidence evidence.md \
        --dispatch-id "" --digest "$("$FW" reviewer verdict digest T-9200 --ac 1)"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "dispatch"
    mkdir -p "$PROJECT_ROOT/.context/reviews"
    echo '{"dispatch_id":"rv-fake","task":"T-9200","task_type":"review","issuer_session":"","issuer_identity":"","ts":"x","sig":"00"}' \
        > "$PROJECT_ROOT/.context/reviews/review-dispatches.jsonl"
    run "$FW" reviewer verdict record T-9200 --ac 1 --outcome green \
        --reviewer "independent-reviewer-session-7" --rung x --evidence evidence.md \
        --dispatch-id rv-fake --digest "$("$FW" reviewer verdict digest T-9200 --ac 1)"
    [ "$status" -eq 1 ]
    [ ! -f "$PROJECT_ROOT/.context/reviews/verdicts.jsonl" ]
}

@test "T-3581 round 3: a missing verdict module REFUSES the close instead of skipping revalidation" {
    _make_render_task >/dev/null
    run _record green --evidence evidence.md
    [ "$status" -eq 0 ]
    # A framework tree identical to this one except lib/verdict_ledger.py is absent.
    local fake="$TEST_TEMP_DIR/fake-fw" e
    mkdir -p "$fake/lib"
    for e in "$FRAMEWORK_ROOT"/* "$FRAMEWORK_ROOT"/.[!.]*; do
        [ "$(basename "$e")" = lib ] || [ "$(basename "$e")" = .git ] || ln -s "$e" "$fake/$(basename "$e")"
    done
    for e in "$FRAMEWORK_ROOT"/lib/* "$FRAMEWORK_ROOT"/lib/.[!.]*; do
        [ "$(basename "$e")" = verdict_ledger.py ] || ln -s "$e" "$fake/lib/$(basename "$e")"
    done
    [ ! -e "$fake/lib/verdict_ledger.py" ]
    FRAMEWORK_ROOT="$fake" run "$fake/agents/task-create/update-task.sh" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "verdict_ledger.py is missing"
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 1 ]
    # control: the real tree closes the same task
    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -eq 0 ]
}

@test "T-3581 round 3: fw audit reports a failure, not a skip, when the verdict module is missing" {
    # Pin: the audit block has an else-branch that calls fail, never a bare fi.
    awk '/verdict_ledger.py" \]; then/{f=1} f&&/^else/{e=1} f&&e&&/fail "Reviewer-verdict ledger: lib\/verdict_ledger.py is missing/{ok=1} END{exit !ok}' \
        "$BATS_TEST_DIRNAME/../../agents/audit/audit.sh"
}
