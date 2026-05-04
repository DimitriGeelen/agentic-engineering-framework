---
id: T-1727
name: "v0.5 build — escalation-scan with LLM augmentation (T-1726 GO conditional)"
description: >
  v0.5 build — escalation-scan with LLM augmentation (T-1726 GO conditional)

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [blocked-on-t-1726-go, arc:orchestrator-rethink, T-1726-implementation, G-064-closure-pilot]
components: []
related_tasks: []
created: 2026-05-04T21:39:23Z
last_update: 2026-05-04T21:39:58Z
date_finished: null
---

# T-1727: v0.5 build — escalation-scan with LLM augmentation (T-1726 GO conditional)

## Context

**🔒 BLOCKED on T-1726 GO recording.** Task pre-filed per CLAUDE.md
"Post-Grill Governance Closure (L-349)" pattern: after writing
Recommendation, the build sibling is filed at captured/horizon-next so
it surfaces immediately on GO without a separate filing step.

Implements T-1726 Recommendation if and when it reaches GO. Headline
mechanic locked from T-1726 filing:
> *"Daily oe-daily cron triggers v0.5 → for each v0 candidate, dispatch
> via fw resolver dispatch with task_type=escalation-triage → ollama-local
> grades each candidate (real symptom-fix vs false positive) → outcome
> row written to dispatch-outcomes.jsonl → /orchestrator page shows
> dispatches accumulating + per-task-type model preferences shifting as
> route_cache learns."*

## Acceptance Criteria

### Agent (locked at T-1726 filing — do not modify without ## Evolution entry)

- [ ] **A1** New workflow file `prompts/escalation-triage.yaml` (or
  inline in default workflow) with `worker_kind` accepted by validator,
  `task_type: escalation-triage`, ollama-local default + cloud fallback,
  cost cap configured.
- [ ] **A2** New tool `tools/escalation-scan-v0.5.py` (sibling of v0)
  reads `.context/working/escalation-drift-LATEST.yaml`, dispatches one
  triage call per candidate via `fw resolver dispatch`, writes
  `.context/working/escalation-drift-LATEST-v0.5.yaml` with `verdict`
  + `reasoning` per candidate, captures outcomes via existing T-1697
  back-prop hook.
- [ ] **A3** Idempotency: re-running v0.5 on the same candidate within
  N days (configurable, default 7) skips dispatch (mtime/checksum guard).
- [ ] **A4** `oe-daily` cron wires v0.5 after v0 (additive, never
  replaces). Failure of v0.5 must not impair v0's report emission.
- [ ] **A5** Watchtower surface: either augment existing v0 panel with
  a `triage` column or add `/embeddings`-style v0.5 panel (decision
  during build). Playwright test pins visibility (per T-1575 — element-
  presence grep is forbidden).
- [ ] **A6** Spike 2 ground truth recorded in `docs/reports/T-1727-v0-5-disagreement-rate.md`:
  LLM verdict vs heuristic verdict on the 30-day backlog, ≥10%
  disagreement to confirm A1 of T-1726.
- [ ] **A7** ## Evolution log populated at completion (Evolution-gate
  from T-1718 fires on this arc-tagged build task).
- [ ] **A8** Bats coverage: ≥1 test per AC; new components fabric-
  registered; `fw audit` clean.
- [ ] **A9** Two pre-existing minor items from T-1726 Spike 1 either
  fixed or filed as separate tasks: (a) `worker_kind: ollama-loop`
  validator rejection in `lib/resolver.py`, (b) `<!-- resolver:
  unresolved $VARs: ['VAR'] -->` template leak in `prompts/default.md`.

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

### 2026-05-04T21:39:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1727-v05-build--escalation-scan-with-llm-augm.md
- **Context:** Initial task creation

### 2026-05-04T21:39:48Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** tags: +blocked-on-t-1726-go

### 2026-05-04T21:39:58Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-04T21:39:58Z — status-update [task-update-agent]
- **Change:** tags: +T-1726-implementation

### 2026-05-04T21:39:58Z — status-update [task-update-agent]
- **Change:** tags: +G-064-closure-pilot
