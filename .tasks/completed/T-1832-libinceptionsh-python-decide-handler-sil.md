---
id: T-1832
name: "lib/inception.sh Python decide-handler silently no-ops when '## Decision' heading
  absent — Layer 2 of T-1831 RCA"
description: >
  Found in S-2026-0514 session via errors 4+5. lib/inception.sh:531-582 Python script
  searches for line.strip() == '## Decision' (singular). If absent (custom-body inception
  tasks, or template variants using '## Decisions' plural only), decision_written
  stays False, no Decision block is written, but inception.sh returns 0. Caller's
  tick + Updates-entry steps run normally. Then update-task.sh's check_inception_decision
  at line 366 (looking for '**Decision**:' line-start) fails with 'no decision recorded'
  — error appears AFTER decision was 'successfully recorded' per the CLI. Same class
  as T-1828: gate measures proxy that diverged from reality. Fix: Python should ERROR
  if heading absent (or auto-create the section before writing). Sibling to T-1831
  Layer 1 (AC checkbox).

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/inception.sh]
related_tasks: [T-1828, T-1829, T-1830, T-1831]
created: 2026-05-14T20:13:43Z
last_update: '2026-06-11T22:24:00Z'
date_finished: 2026-05-14T20:49:40Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1832: lib/inception.sh Python decide-handler silently no-ops when '## Decision' heading absent — Layer 2 of T-1831 RCA

## Context

Discovered while RCA-ing T-1831 (4 errors → 6 errors in user's S-2026-0514 session). Errors 4 and 5 (T-1829 and T-1830 `fw inception decide` returning "Cannot complete inception task - no decision recorded" AFTER agent ACs all ticked) traced to the Python decide-handler in `lib/inception.sh:531-582`.

The script iterates lines looking for `line.strip() == '## Decision'` (singular). When absent — which happens whenever a task has `## Decisions` (plural, the default template) but not the singular `## Decision` placeholder section — `decision_written` stays False and **no Decision block is written**. The function returns 0. Downstream `tick_inception_decide_acs` ticks the Human AC, the Updates entry gets appended (`### timestamp — inception-decision`), and `update-task.sh` is invoked with `--status work-completed`. That hits `check_inception_decision` at `update-task.sh:366` which grep-checks for `^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)` — finds nothing — and fails with "no decision recorded".

The user sees: agent says "decision recorded", framework says "no decision recorded". Same antifragility class as T-1828 (gate measures proxy that diverged from reality).

## Acceptance Criteria

### Agent
- [x] Patch `lib/inception.sh` Python script: when `## Decision` heading absent, EITHER (a) auto-create the section before writing OR (b) error with helpful message naming the missing heading
- [x] Bats test in `tests/unit/` exercising both code paths (heading present → writes; heading absent → errors-or-creates)
- [x] Update inception task template (default.md) to include the `## Decision` (singular) placeholder section — currently only inception.md has it
- [x] Sweep existing active inception tasks for the missing-heading state; add the section to any found (T-1829/T-1830/T-1831 already patched as part of this RCA)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

bats tests/unit/inception_decide_auto_create_decision_section.bats
grep -q "^## Decision$" .tasks/templates/default.md

## RCA

**Symptom:** `fw inception decide T-XXX go --rationale "..."` reports success (exit 0) at the inception-decide preflight but then the downstream `update-task.sh --status work-completed` fails with `Cannot complete inception task - no decision recorded`. User sees: agent says decision recorded, framework says it isn't. Reproduced in S-2026-0514 on T-1829 (after errors 4-5) and T-1830/T-1831 (errors 5-6).

**Root cause:** `lib/inception.sh:531-582` Python script iterates lines looking for `line.strip() == '## Decision'` (singular). When the heading is absent — which happens for tasks created with templates that have only `## Decisions` (plural, the default.md state pre-T-1832), or tasks where the heading was edited out — the `decision_written` flag stays `False`. The loop completes, the file is rewritten verbatim (no Decision block), the function returns 0. The caller then ticks the Human AC and invokes `update-task.sh --status work-completed`. `check_inception_decision` at `update-task.sh:366` grep-checks for `^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)\b`, finds nothing, and refuses the transition with the misleading "no decision recorded" error.

**Why structurally allowed:**
- Python decide-handler relied on heading-existence as both an anchor AND an invariant — no fallback for missing-anchor case.
- Template asymmetry: `inception.md` template had both `## Decisions` (plural) and `## Decision` (singular placeholder); `default.md` had only `## Decisions`. Inception tasks created via the default-template path inherited the broken structure.
- The two-gate split (inception-decide preflight at lib/inception.sh:506-524 measures AC checkbox state; update-task.sh:366 measures Decision-block presence) means the first gate succeeds even when the second gate is destined to fail. Same antifragility class as T-1828 (gate measures proxy that diverges from reality).
- Silent no-op pattern: the Python emits no warning when its sole purpose (write the decision) fails — the function trusts its caller's caller (update-task.sh:366) to surface the problem, which it does with a misleading message.

**Prevention:** (this task's fix)
- Python decide-handler now synthesizes the `## Decision` block when missing — inserts before `## Updates`, else `## Recommendation`, else EOF.
- stderr WARNING emitted with `[T-1832]` marker so auto-creation is visible (not silent).
- `default.md` template updated to include `## Decision` placeholder — new tasks get the anchor for free; auto-create is fallback for legacy tasks.
- Bats test pins both paths (heading-present normal path; heading-absent auto-create with warning) at `tests/unit/inception_decide_auto_create_decision_section.bats`.

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

### 2026-05-14T20:13:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1832-libinceptionsh-python-decide-handler-sil.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-62890cd4
- **Timestamp:** 2026-06-02T14:59:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-14T20:49:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
