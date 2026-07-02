---
id: T-1724
name: "fix: handover Suggested First Action ignores DEFER-decided inception tasks"
description: >
  fix: handover Suggested First Action ignores DEFER-decided inception tasks

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/handover/handover.sh]
related_tasks: [T-1611, T-1068]
created: 2026-05-04T19:22:36Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-04T19:26:11Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); 
      F3=1 (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1724: fix: handover Suggested First Action ignores DEFER-decided inception tasks

## Context

The handover script's "Suggested First Action" recommends `started-work` +
`horizon: now` agent-owned tasks, but does NOT exclude inception tasks
that have already received a DEFER decision.

Result: T-1611 ("Werkzeug → gunicorn") was DEFERRED on 2026-04-30 with a
recorded **Decision: DEFER** rationale, but every handover since has
recommended it as the suggested first action — it was the suggestion in
LATEST.md (S-2026-0504-1833) that the user just read this session.

The state is intentional per `lib/inception.sh:712-714`:
> "DEFER on a started-work task is the legitimate 'keep exploring' state and
> is left untouched — only closing decisions (GO/NO-GO) trigger promotion."

That's correct for inception lifecycle, but wrong for handover suggestions —
DEFER means "parked until criteria re-met", not "actionable now". The
handover should treat DEFERed inceptions as out-of-scope for first-action
recommendation, the same way they're listed under "Deferred Inceptions —
Watching for Recurrence" in the handover body.

## Acceptance Criteria

### Agent
- [x] `agents/handover/handover.sh` — Suggested First Action python block excludes tasks that have a `**Decision**: DEFER` line in the body (in addition to current filters).
- [x] Verification: T-1611 (DEFER inception, started-work, horizon:now) is NOT recommended; instead some other started-work non-inception task is.
- [x] Existing logic preserved: agent-owned + horizon:now still preferred over horizon:next + human-owned.
- [x] Bash parse OK: `bash -n agents/handover/handover.sh`.
- [x] Run the inline python block in isolation against current task state — picked task is NOT T-1611. (--checkpoint uses a different template, so we test the python directly.)

## Verification

bash -n agents/handover/handover.sh
# Mirror the inline python from handover.sh:851-876 (one-line so the
# verification gate reads it as one command). Asserts the picked task is
# not T-1611 (the DEFER-decided inception this fix excludes).
python3 tests/unit/check_handover_suggestion.py

## Recommendation

**Recommendation:** GO

**Rationale:**

Three-line fix in `agents/handover/handover.sh:864-866`. Adds a single
filter to the existing python block: skip tasks that contain a literal
`**Decision**: DEFER` line (the inception-decide canonical marker).

The DEFER state was deliberately preserved as `started-work` per
`lib/inception.sh:712` — that's correct for inception lifecycle (DEFER
means "keep watching for re-promotion criteria"), but the handover script
treated it as actionable and recommended T-1611 every session for 5 days.

Same task-ID was the suggestion in the LATEST.md the user just read this
session.

**Evidence:**

- Pre-fix simulation: picks `T-1611` (DEFER inception, parked).
- Post-fix simulation: picks `T-1687` (legit started-work non-inception agent task).
- Bash parse OK.
- `bin/fw handover --checkpoint` uses a different template (lists all
  active tasks, no "Suggested First Action") so the verification runs
  the python block directly.
- Lifecycle invariant respected: `lib/inception.sh:712-714`'s "DEFER stays
  started-work" intent is untouched — only the handover *suggestion* logic
  changes.

## RCA

**Symptom:** Handover's "Suggested First Action" recommended T-1611 (DEFERed
inception, parked since 2026-04-30) every session for 5 days, despite a
recorded **Decision: DEFER**.

**Root cause:** `agents/handover/handover.sh` python filter checked status
+ horizon + owner but not decision-state. It treated `started-work` as
"actively being worked on" — which is true for build tasks but false for
DEFERed inceptions, where `started-work` means "still watching".

**Why structurally allowed:** The semantic mismatch between
`status: started-work + decision: DEFER` (inception lifecycle) and the
handover's mental model ("started-work = actionable") was unwritten. The
filter passed code review because it matched intuition, but inception's
decision-driven lifecycle is the exception.

**Prevention:** Filter explicitly checks for `**Decision**: DEFER`. A
future scenario where DEFER is recorded differently (e.g. only in
frontmatter) would need to update this filter — that's a known limitation,
covered by the human-AC instruction to spot-check the suggestion.

## RCA-deprecated

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-04T19:22:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1724-fix-handover-suggested-first-action-igno.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f638784e
- **Timestamp:** 2026-06-02T14:59:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-04T19:26:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
