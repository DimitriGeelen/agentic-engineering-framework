---
id: T-1776
name: "fallback-workflow contract gap — default.yaml declares worker_kind: TermLink
  which spawn driver does not route"
description: >
  fallback-workflow contract gap — default.yaml declares worker_kind: TermLink which
  spawn driver does not route

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [spawn, contract-gap]
components: [C-004, lib/spawn.py, lib/termlink_worker.py, 
      lib/workflow_coverage.py, tests/unit/test_spawn.py, 
      tests/unit/test_termlink_worker.py, tests/unit/test_workflow_coverage.py]
related_tasks: [T-1773, T-1775]
arc_id: orchestrator-rethink
created: 2026-05-09T21:18:59Z
last_update: '2026-08-16T22:23:59Z'
date_finished: 2026-05-31T09:26:42Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T23:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 5
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=5 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1776: fallback-workflow contract gap — default.yaml declares worker_kind: TermLink which spawn driver does not route

## Context

While shipping T-1775 (ollama-loop spawn route), discovered that
`.context/project/workflows/default.yaml:2` declares `worker_kind: TermLink`.
The Q12 fallback contract (`load_workflow`) routes any `task_type` without
its own workflow file to default.yaml. That means for any default-fallback
dispatch:

```
fw resolver run T-XXX <unknown_task_type>
  → load_workflow falls back to default.yaml
  → envelope has worker_kind=TermLink
  → spawn._DISPATCHERS["TermLink"] is missing
  → NotImplementedError raised at spawn time
```

This is a substrate gap, not a code bug — the resolver+spawn split was
designed when TermLink was the only dispatch surface. Now the spawn driver
exists but doesn't route TermLink, so the default fallback path is a trap.

This task is a **filing**, not a build. The architectural choice
(Python primitive vs shell adapter vs change default.yaml's worker_kind)
belongs to the human and is out of scope for autonomous agent work. ACs
below capture the discovery + recommendation matrix.

## Acceptance Criteria

### Agent

**1. Discovery captured**
- [x] Build report `docs/reports/T-1776-default-workflow-termlink-gap.md` documents:
      - The current contract (resolver→spawn for ollama-loop and pi works; default fallback breaks)
      - Three resolution options with trade-offs (Python primitive / shell adapter / change default)
      - Recommendation for human decision

**2. No code change**
- [x] No edits to lib/spawn.py, lib/resolver.py, or default.yaml in this task.
      The current NotImplementedError path is the safest state — it surfaces
      the gap loudly rather than silently producing garbage. Resolution lands
      in a follow-up task once the human picks a direction.
      Verified: `git log --all --oneline --grep "T-1776" -- lib/spawn.py lib/resolver.py .context/project/workflows/default.yaml`
      returns zero commits — the discipline held; lib/spawn.py was edited under T-1797
      (option A), not under T-1776.

### Human

- [ ] [REVIEW] **#H1: Choose resolution direction**
      **Steps:**
      1. Read `docs/reports/T-1776-default-workflow-termlink-gap.md`
      2. Pick one of three options: A) Build TermLink Python primitive (~150 LOC + tests, mirrors OllamaLoopWorker, wraps `fw termlink dispatch`); B) Add shell adapter that shells out to `fw termlink dispatch` and parses result; C) Change `default.yaml` to use `worker_kind: ollama-loop` (cheapest path, requires litellm) or `worker_kind: pi` (requires pi binary)
      3. File a follow-up build task for the chosen direction; close this one as DEFER if option C is picked at the workflow level (no spawn-side work needed)
      **Expected:** Decision recorded on this task or a follow-up.
      **If not:** Park as horizon=later; the NotImplementedError is loud, so latent risk is bounded.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
test -f docs/reports/T-1776-default-workflow-termlink-gap.md
grep -q "worker_kind: TermLink" .context/project/workflows/default.yaml

## Recommendation

**Recommendation:** GO (close as resolved) — option A was picked and shipped; the filing has served its purpose.

**Rationale:** Recommendation evolved from DEFER (2026-05-09 filing) to GO-resolved (2026-05-31 verification). Between filing and now, the human picked **option A** (TermLink Python primitive) and the follow-up shipped via **T-1797** (`df468c2f`: "TermLink worker primitive — closes T-1776 default-fallback contract gap") with audit-time prevention via **T-1798** (`cf480359`: "workflow-dispatcher coverage check — audit-time T-1776 prevention"). The default-fallback NotImplementedError trap that motivated this filing no longer exists in the substrate; `lib/spawn.py` now routes `worker_kind: TermLink` via the new primitive. T-1776's filing job (surface options, recommend, defer to human, then close once direction chosen) is complete by event — the human's choice was expressed through shipping T-1797, not through ticking #H1 on this task. This task is a textbook CTL-029 (T-2055) case: completable-but-not-completed, sitting in `active/` ~22 days past the moment its purpose was served.

**Evidence:**
- `git log --all --oneline --grep "T-1776"` returns 4 commits:
  - `703f3d34 T-1776: file substrate gap` (the filing itself)
  - `e134578d T-1687: fabric scan/enrich` (incidental T-1776 mention in fabric metadata)
  - `df468c2f T-1797: TermLink worker primitive — closes T-1776 default-fallback contract gap`
  - `cf480359 T-1798: workflow-dispatcher coverage check — audit-time T-1776 prevention`
- T-1797 is `status: work-completed` (date_finished `2026-05-12T21:57:27Z`), partial-complete with 1 [REVIEW] Human AC pending — orthogonal to this task's closure
- T-1798 is `status: work-completed` and moved to `.tasks/completed/`
- `docs/reports/T-1776-default-workflow-termlink-gap.md` (103 lines) preserved as historical filing
- Verification commands still pass (the loud-failure description is now historical context, not a live trap)

**Headline mechanic:** None — discovery filing. The downstream mechanic landed under T-1797 (TermLinkWorker primitive wraps `fw termlink dispatch`); see `lib/termlink_worker.py` for the actual route.

**Human action required:** Tick #H1 (option A confirmed via T-1797 commits) and close. The agent surfaces this evidence at `fw task review T-1776`; no rework of the original filing is intended.

## Evolution

### 2026-05-09 — discovered while investigating remaining NotImplementedError stubs

- **What changed:** While picking the next on-arc move post-T-1775, planned to investigate whether TermLink should be a Python primitive, shell adapter, or removed from VALID_WORKER_KINDS. Grep of workflows revealed `default.yaml` already declares `worker_kind: TermLink` — meaning the gap isn't just "what about TermLink", it's "the most-default path through the substrate currently breaks at spawn time". This is more critical than the architectural curiosity it started as.
- **Plan impact:** Pivoted from "build TermLink route" to "file discovery for human decision". The build is well-scoped if/when the human picks direction A or B; direction C is a 1-line workflow edit.
- **Triggered:** This task, T-1776. No further sub-tasks pending direction.

### 2026-05-31 — close-by-event: option A shipped under T-1797, T-1776 left stale

- **What changed:** S-2026-0531 sweep of orchestrator-arc started-work tasks found T-1776 sitting completable-but-not-completed. The human picked option A within days of filing; T-1797 (`df468c2f`, 2026-05-12) shipped the TermLink Python primitive that closes the default-fallback NotImplementedError trap, and T-1798 (`cf480359`) added the workflow-dispatcher coverage audit check so this exact class can't reappear silently. T-1776's filing-only mandate is complete by event — the recommendation pivots from DEFER to GO-resolved.
- **Plan impact:** Recommendation rewritten; Agent AC #2 ticked (discipline held — no spawn.py/resolver.py/default.yaml edits under T-1776's own commits, confirmed via `git log --all --oneline --grep "T-1776" -- <files>`). Human #H1 remains the only outstanding criterion and is surfaced via `fw task review T-1776`.
- **Triggered:** CTL-029 instance — this is exactly the "completable-but-not-completed" pattern T-2055 was filed to detect. The detector should flag T-1776 too; if it doesn't, that's a follow-up scope worth noting separately (out of scope for this transition).

## RCA

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

### 2026-05-09T21:18:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1776-fallback-workflow-contract-gap--defaulty.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-815bef49
- **Timestamp:** 2026-06-11T11:49:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — No edits to lib/spawn.py, lib/resolver.py, or default.yaml in this task.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/spawn.py in: No edits to lib/spawn.py, lib/resolver.py, or default.yaml in this task.`
### 2026-05-31T09:26:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
