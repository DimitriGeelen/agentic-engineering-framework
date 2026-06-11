---
id: T-1836
name: "Gate diagnostic upgrade — surface body-vs-checkbox drift in AC-unchecked error
  message (T-1831 C-3 build)"
description: >
  T-1831 C-3 build sibling. Enhance the error message in P-010 (update-task.sh:110)
  and inception-decide preflight (lib/inception.sh:517) when ACs are unchecked: append
  a hint pointing at CLAUDE.md §Progressive AC ticking, and (when a ## Recommendation
  block is filled) explicitly suggest 'AC content likely present — tick the boxes
  if work is complete'. Origin: S-2026-0514 errors 1-3 — agent wrote content, didn't
  tick, gate refused with no signal that the fix is 'tick the box', leading to repeated
  retries. Sibling to T-1835 (C-4 documentation half).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [fw-upgrade-incident-2026-05-14, gate-diagnostic, ac-discipline, bug]
components: [agents/task-create/update-task.sh, lib/inception.sh]
related_tasks: []
created: 2026-05-14T20:56:18Z
last_update: '2026-06-11T22:24:00Z'
date_finished: 2026-05-14T20:59:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1836: Gate diagnostic upgrade — surface body-vs-checkbox drift in AC-unchecked error message (T-1831 C-3 build)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] update-task.sh P-010 error message appends Progressive-AC-ticking hint when ACs unchecked
- [x] lib/inception.sh decide-preflight error message appends the same hint
- [x] Hint references CLAUDE.md §Progressive AC ticking explicitly
- [x] When `## Recommendation` block is filled (non-template), error message includes "AC content likely present — tick the boxes if work is complete"
- [x] Bats test exercising the augmented messages

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

bats tests/unit/p010_gate_diagnostic_body_drift_hint.bats

## RCA

**Symptom:** S-2026-0514 errors 1-3 — gate refused with `Cannot complete — N/N agent AC unchecked` followed by a list of unchecked AC text, but no signal indicating whether the fix is "tick the boxes" vs "do the work". Agent and user both treated each occurrence as a fresh problem, slowing recognition of the class.

**Root cause:** the gate error message reported state ("ACs unchecked") without diagnosing the *kind* of unchecked-state. Two kinds exist: (a) AC content not yet written → do the work; (b) AC content written but boxes not ticked → tick the boxes. Same error message for both; no help discriminating.

**Why structurally allowed:** the gate's job was to refuse the transition, which it did. Message hygiene was not part of T-1503/P-010's original scope. The pattern (write-content-without-ticking) was a discovered antipattern from this session — not foreseen.

**Prevention:** the gate now appends a body-vs-checkbox drift hint. When a `## Recommendation` block is filled (strong signal that substantive content was written), the message explicitly says "AC content likely present — tick the boxes if work is complete". When no Recommendation block, the message points at CLAUDE.md §Progressive AC ticking (T-1831 C-4). Bats test `tests/unit/p010_gate_diagnostic_body_drift_hint.bats` pins both branches. Cross-link: T-1835 lands the documentation half of T-1831's GO bundle.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-14T20:56:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1836-gate-diagnostic-upgrade--surface-body-vs.md
- **Context:** Initial task creation

### 2026-05-14T20:56:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5a9026fd
- **Timestamp:** 2026-06-02T14:59:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-14T20:59:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
