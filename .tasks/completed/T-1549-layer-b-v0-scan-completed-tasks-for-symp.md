---
id: T-1549
name: "Layer B v0: scan completed tasks for symptom-fix candidates (T-1548 spike 1)"
description: >
  Layer B v0: scan completed tasks for symptom-fix candidates (T-1548 spike 1)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-27T15:50:05Z
last_update: 2026-04-27T15:53:58Z
date_finished: 2026-04-27T15:53:58Z
---

# T-1549: Layer B v0: scan completed tasks for symptom-fix candidates (T-1548 spike 1)

## Context

T-1548 (inception, GO 2026-04-27) confirmed two-layer scope for G-019 structural remediation. This task delivers Spike 1: Layer B v0 — a one-shot Python scanner that surfaces symptom-fix candidates from the completed-tasks corpus by 3 simple heuristics (H1 bug-class without RCA, H2 repeat-learning across N tasks in M days, H3 bug-class with no RCA AND no learning). Read-only, writes report to docs/reports/T-1549-escalation-scan-v0.md. Outcome data drives Layer B v1 (cron promotion) GO/NO-GO.

## Acceptance Criteria

### Agent
- [x] `tools/escalation-scan-v0.py` exists and runs to completion against the live `.tasks/completed/` corpus without errors
- [x] Scanner implements all 3 heuristics (H1, H2, H3) with code matching the inception artifact spec
- [x] Scanner writes structured report to `docs/reports/T-1549-escalation-scan-v0.md` containing: corpus size, bug-class count, per-heuristic counts, last-30-days sample, self-application result for T-1548
- [x] Scanner is read-only (no writes outside `docs/reports/` and stdout)
- [x] Self-application (Spike 3): scanner reports T-1548's H1 status — pass criterion is that it produces a deterministic verdict (flagged or not), not that any specific outcome is required
- [x] Report's "Read-out" section names explicit GO/NO-GO thresholds for promoting Layer B from v0 to v1 (cron + register)

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
test -x tools/escalation-scan-v0.py || test -f tools/escalation-scan-v0.py
python3 tools/escalation-scan-v0.py
test -f docs/reports/T-1549-escalation-scan-v0.md
grep -q "Headline numbers" docs/reports/T-1549-escalation-scan-v0.md
grep -q "Self-application" docs/reports/T-1549-escalation-scan-v0.md

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

### 2026-04-27T15:50:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1549-layer-b-v0-scan-completed-tasks-for-symp.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-50c9b781
- **Timestamp:** 2026-06-02T14:58:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T15:53:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
