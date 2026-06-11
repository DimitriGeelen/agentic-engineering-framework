---
id: T-1735
name: "fw doctor: assert VALID_WORKER_KINDS parity between bin/fw and lib/resolver.py"
description: >
  T-1734 promised follow-up. Doctor check loads both VALID_WORKER_KINDS constants
  and warns if they differ. Cheap structural prevention against silent drift.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, lib/resolver.py]
related_tasks: []
created: 2026-05-05T07:33:16Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-05-05T08:33:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 2
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=2 
      (components:substrate-edit); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1735: fw doctor: assert VALID_WORKER_KINDS parity between bin/fw and lib/resolver.py

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw doctor` emits a "worker-kinds parity" check that compares the `VALID_WORKER_KINDS` set in `bin/fw:1804` against `lib/resolver.py:VALID_WORKER_KINDS` (single source) and reports OK / WARN with concrete diff
- [x] When the two tables match: green `OK Worker-kinds parity` line in doctor output
- [x] When the two tables differ (test scenario): yellow `WARN` line listing the symmetric difference (members in fw-only / resolver-only)
- [x] bats test in `tests/unit/worker_kinds_parity.bats` covering both states (parity → exit 0 OK; drift → exit non-zero or WARN line present) — 6 tests, all green
- [x] `T-1734` learning cross-ref: comment in both `bin/fw:1804` and `lib/resolver.py:56` already exists; nothing new there — but the doctor check is the runtime witness that closes the structural gap

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

# L-351: wrap LHS with `|| true` so doctor's exit 2 (unrelated failures) doesn't
# break our parity-line assertion under pipefail; SIGPIPE on grep -q closure
# similarly handled.
{ bin/fw doctor 2>&1 || true; } | grep -qiE "worker-kinds parity"
test -f tests/unit/worker_kinds_parity.bats
{ bats tests/unit/worker_kinds_parity.bats 2>&1 || true; } | grep -q "^ok 1 "

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

### 2026-05-05T07:33:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1735-fw-doctor-assert-validworkerkinds-parity.md
- **Context:** Initial task creation

### 2026-05-05T08:26:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bdff46c4
- **Timestamp:** 2026-06-02T14:59:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 13
     - evidence: `{ bin/fw doctor 2>&1 || true; } | grep -qiE "worker-kinds parity"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 15
     - evidence: `{ bats tests/unit/worker_kinds_parity.bats 2>&1 || true; } | grep -q "^ok 1 "`
### 2026-05-05T08:33:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
