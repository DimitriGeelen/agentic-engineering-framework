---
id: T-1550
name: "Layer A: ## RCA template + completion gate for bug-class tasks (T-1548 GO)"
description: >
  Layer A: ## RCA template + completion gate for bug-class tasks (T-1548 GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-27T15:58:34Z
last_update: '2026-08-16T22:24:36Z'
date_finished: 2026-04-27T16:03:36Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=1 (body/components:prompt-incidental); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1550: Layer A: ## RCA template + completion gate for bug-class tasks (T-1548 GO)

## Context

T-1548 inception (GO 2026-04-27) → T-1549 spike showed 99% of bug-class tasks (315/317 in corpus) lack a `## RCA` section. Re-framing: not agent disobedience, framework template + completion gate never asked. T-1550 ships Layer A: add `## RCA` to default template, enforce non-empty for bug-class tasks at `--status work-completed`, mirror existing `check_recommendation_for_review` pattern at `agents/task-create/update-task.sh:172-221`.

## Acceptance Criteria

### Agent
- [x] `.tasks/templates/default.md` contains `## RCA` section with prompt explaining required content (symptom / root cause / why structurally allowed / prevention)
- [x] `agents/task-create/update-task.sh` defines `check_rca_for_bugfix` function: classifies task as bug-class via workflow_type + tags + title heuristic; if bug-class, requires non-empty `## RCA` body content for completion
- [x] Gate fires only on `--status work-completed` and only for bug-class tasks (workflow_type≠inception/specification/design AND (tag matches `bug|bugfix|hotfix|rca|incident` OR title matches `fix|bug|rca|broken|crash|error|regression|fail|hotfix`))
- [x] `--skip-rca` flag bypasses with mandatory `log_gate_bypass` entry; `--skip-rca` documented in `--help` output alongside other skip flags
- [x] bats test `tests/unit/rca_gate.bats` covers 6 cases: bug-class no-RCA → blocks; bug-class empty-RCA (comments only) → blocks; bug-class substantive-RCA → passes; inception no-RCA → passes; non-bug-class build no-RCA → passes; `--skip-rca` bypass → passes + logs
- [x] All bats tests pass (`bats tests/unit/rca_gate.bats`)
- [x] CLAUDE.md §"Post-Fix Root Cause Escalation" updated to point at the new gate (one-line addition, not rewrite)

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
grep -q "^## RCA" .tasks/templates/default.md
grep -q "check_rca_for_bugfix" agents/task-create/update-task.sh
grep -q "skip-rca" agents/task-create/update-task.sh
test -f tests/unit/rca_gate.bats
bats tests/unit/rca_gate.bats

## RCA

**Symptom:** 99% of bug-class tasks (315/317 across 1462 completed tasks) shipped without an `## RCA` section. The framework's gap-register entry G-019 named the pattern as `[high]` severity for months without remediation. Sustained blindness despite registration.

**Root cause:** The framework's bug-task template never contained an `## RCA` section. The completion gate at `agents/task-create/update-task.sh` ran AC + verification + recommendation checks but had no RCA check. CLAUDE.md §"Post-Fix Root Cause Escalation" was advisory text only — text-as-control with no structural enforcement.

**Why structurally allowed:** The framework's enforcement strategy was layered (template + gate + log) for AC, verification, and recommendation, but RCA was treated as a behavioral guideline. Behavioral rules read at session start compete with task pressure during in-flight work; structural gates don't. G-019's existence in the gaps register made the pattern observable but not enforceable, and observability without enforcement decayed into "we're tracking it" without remediation. T-1549 spike (run via this inception arc) confirmed the data: 99% baseline = template gap, not behavior.

**Prevention:** Three layers shipped here. (1) Template adds `## RCA` section to `.tasks/templates/default.md` — agents fill what the template asks for. (2) Completion gate `check_rca_for_bugfix` in `update-task.sh` blocks `--status work-completed` for bug-class tasks lacking substantive RCA content; mirrors `check_recommendation_for_review` pattern. (3) `--skip-rca` permitted with mandatory `log_gate_bypass` Tier-2 entry — legitimate trivial fixes still possible, but every bypass leaves an audit trail. Layer B v1 (T-1551, deferred) will sweep historical 262 H3-flagged tasks against this baseline. Self-test: T-1550's own title triggers the bug-class heuristic, and this very RCA section is what unblocks the gate — dogfooding proves the loop closes.

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

### 2026-04-27T15:58:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1550-layer-a--rca-template--completion-gate-f.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1881dca4
- **Timestamp:** 2026-06-02T14:58:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T16:03:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
