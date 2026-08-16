---
id: T-1734
name: "VALID_WORKER_KINDS drift between bin/fw and lib/resolver.py — ollama-loop accepted
  by listing but rejected by dispatch"
description: >
  fw resolver workflows lists prompt-triage.yaml (ollama-loop) but fw resolver dispatch
  rejects it as invalid worker_kind. Two tables: bin/fw:1804 includes ollama-loop,
  lib/resolver.py:56 does not. Either consolidate to one table or sync both. Discovered
  during T-1733 first dispatch attempt.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, validation-drift, resolver]
components: [bin/fw, lib/resolver.py]
related_tasks: [T-1733, T-1706, T-1689]
arc_id: orchestrator-rethink
created: 2026-05-05T07:29:58Z
last_update: '2026-08-16T22:24:42Z'
date_finished: 2026-05-05T07:33:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 3
      F3: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=3 
      (body:typed-io-or-gate); F3=4 (body:prompt-material); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=4 (body:prompt-material); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1734: VALID_WORKER_KINDS drift between bin/fw and lib/resolver.py — ollama-loop accepted by listing but rejected by dispatch

## Context

`fw resolver workflows` (implemented in `bin/fw:1804`) and `fw resolver dispatch` (implemented
in `lib/resolver.py:56`) maintain two independent `VALID_WORKER_KINDS` constants. `bin/fw`
includes `ollama-loop` (added when T-1706 introduced the ollama-research workflow), but
`lib/resolver.py` was never synced. Result: a workflow can list cleanly but fail at dispatch.
Discovered when T-1733 (prompt-triage) attempted its first dry-run dispatch.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/resolver.py:56` `VALID_WORKER_KINDS` includes `"ollama-loop"`
- [x] `bin/fw resolver dispatch T-1733 prompt-triage --dry-run` builds an envelope without worker_kind error
- [x] Both validation tables exist in only one canonical location, OR a one-line comment on each cross-references the other so the next drift is caught (lightweight — no refactor required for this slice)
- [x] `bin/fw resolver workflows` continues listing all 6 workflows after the change
- [x] `bin/fw doctor` does not regress (no new warnings introduced)

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
grep -q "ollama-loop" lib/resolver.py
bin/fw resolver dispatch T-1733 prompt-triage --dry-run 2>&1 | grep -vq "invalid worker_kind"
bin/fw resolver workflows 2>&1 | grep -c "yaml" | grep -q "^6$"

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

**Symptom:** `bin/fw resolver dispatch T-1733 prompt-triage --dry-run` returned `error:
Workflow prompt-triage has invalid worker_kind 'ollama-loop'`, despite `bin/fw resolver
workflows` listing prompt-triage.yaml cleanly with worker=ollama-loop.

**Root cause:** Two `VALID_WORKER_KINDS` constants — `bin/fw:1804` (used by `resolver
workflows` and the lint path) and `lib/resolver.py:56` (used by `resolver dispatch`). T-1706
added `ollama-loop` to the first; the second was never updated. The lint-vs-dispatch
divergence stayed silent because no consumer of ollama-research ever invoked `fw resolver
dispatch` end-to-end — `tools/ollama-tool-loop.py` runs out-of-band against litellm directly.
T-1733 became the first dispatch-path consumer, which surfaced the drift.

**Why structurally allowed:** Two near-identical constants in two languages (Python in
lib/resolver.py, embedded Python heredoc in bin/fw). No test, lint, or doctor check that
cross-validates them. The lint path uses one table to validate workflow files; the dispatch
path uses the other to validate at envelope-build time. Same name, same purpose, no shared
source-of-truth.

**Prevention:**
- Cross-reference comments on both constants pointing at each other (this slice — caught by
  human reading code, not by tooling).
- Future improvement (separate task): add `bin/fw doctor` check that loads both constants and
  asserts equality (or refactors to a single shared table). Filed as T-1735.


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

### 2026-05-05 — drift discovery during T-1733
- **What changed:** Filed as a one-line fix; turned into "what catches the next drift" question. Decided cross-ref comments are the right slice (cheap, human-readable), and a doctor check is a separate concern that warrants its own task (filed as T-1735).
- **Plan impact:** None — original AC for "both tables exist in only one canonical location" was relaxed to "OR cross-ref comments" because the Python-in-Python-via-heredoc structure makes a single source-of-truth table non-trivial (would require refactoring the bin/fw lint heredoc).
- **Triggered:** T-1735 (doctor check for VALID_WORKER_KINDS parity).


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

### 2026-05-05T07:29:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1734-validworkerkinds-drift-between-binfw-and.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-eba6aeac
- **Timestamp:** 2026-06-02T14:59:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `bin/fw resolver dispatch T-1733 prompt-triage --dry-run 2>&1 | grep -vq "invalid worker_kind"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `bin/fw resolver workflows 2>&1 | grep -c "yaml" | grep -q "^6$"`
### 2026-05-05T07:33:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
