---
id: T-1868
name: "fix revisit-due-scan.sh path-resolution to work in framework repo (script assumes
  vendored-only; framework-repo case resolves to /opt/.tasks/active)"
description: >
  fix revisit-due-scan.sh path-resolution to work in framework repo (script assumes
  vendored-only; framework-repo case resolves to /opt/.tasks/active)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/context/revisit-due-scan.sh]
related_tasks: []
created: 2026-05-15T20:44:05Z
last_update: '2026-06-11T22:24:01Z'
date_finished: 2026-05-15T20:47:29Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1868: fix revisit-due-scan.sh path-resolution to work in framework repo (script assumes vendored-only; framework-repo case resolves to /opt/.tasks/active)

## Context

`agents/context/revisit-due-scan.sh` (T-1452) has a fallback PROJECT_ROOT resolver
written for the vendored case (`$PROJECT_ROOT/.agentic-framework/agents/context/...`):
```bash
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
```
3 levels up from `agents/context/` lands at `/opt/` in the framework repo (not
`/opt/999-Agentic-Engineering-Framework`). Result: `revisit-due-scan: tasks dir
not found at /opt/.tasks/active` and silent exit-0. Discovered during T-1687
fabric-drift housekeeping (the script had just been registered).

Discovery class: a script that resolves PROJECT_ROOT by relative walk-up makes a
context assumption (vendored-vs-framework-repo) that G-063 specifically flags
("project-shape conflation"). The fix must work in both shapes.

## Acceptance Criteria

### Agent
- [x] `revisit-due-scan.sh` walks up looking for a `.framework.yaml` OR `FRAMEWORK.md` marker instead of fixed-depth `../../..`
- [x] Running from `/opt/999-Agentic-Engineering-Framework/` (framework repo) resolves PROJECT_ROOT correctly (verified manually + bats #1)
- [x] Running from a vendored consumer (simulated test fixture) still resolves correctly (bats #2)
- [x] New regression test in `tests/unit/test_revisit_due_scan_shape.bats` covers both shapes (4 tests, all pass; existing test `agents/context/tests/revisit-due-scan-test.sh` also still passes)

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
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.

out=$(./agents/context/revisit-due-scan.sh 2>&1); test -z "$out" || echo "$out" | grep -qv "tasks dir not found at /opt/.tasks"
bats tests/unit/test_revisit_due_scan_shape.bats

## RCA

**Symptom:** Running `agents/context/revisit-due-scan.sh` from inside the
framework repo (no `PROJECT_ROOT` env var) silently exits 0 with
`revisit-due-scan: tasks dir not found at /opt/.tasks/active`. The handover
banner never surfaces ripe revisits because the cron-written file is never
populated.

**Root cause:** The fallback PROJECT_ROOT resolver used a fixed-depth
`SCRIPT_DIR/../../..` walk-up that was correct only for the vendored consumer
layout (`.agentic-framework/agents/context/`). In the framework repo itself
(`agents/context/` at root), 3-up lands at the *parent* of the repo
(`/opt/`), not the repo. The script then looked for `.tasks/active/` at
`/opt/.tasks/active` which never exists.

**Why structurally allowed:** The script was written for one shape and there
was no test exercising the alternate shape. T-1452 shipped it without a
pin against the fallback resolver. G-063 ("project-shape conflation") exists
specifically for this class — framework code that assumes one shape and
silently fails in the other. The script had no cron registration either,
so cron runs never surfaced the broken state.

**Prevention:** `tests/unit/test_revisit_due_scan_shape.bats` — four
regression tests exercising both shapes with `env -u PROJECT_ROOT` to force
the fallback. Test #1 fails on the broken `../../..` form and passes on the
marker walk-up form (verified by reverting the fix locally). Future
shape-assumption regressions caught at test-time, not by handover-banner
silence.

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

### 2026-05-15T20:44:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1868-fix-revisit-due-scansh-path-resolution-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bc7596ec
- **Timestamp:** 2026-06-02T15:00:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-15T20:47:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
