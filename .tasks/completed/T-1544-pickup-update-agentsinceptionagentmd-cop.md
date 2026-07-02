---
id: T-1544
name: "Pickup: Update agents/inception/AGENT.md copy-paste guidance for review-first
  Watchtower decide flow + project-port awareness (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-202. Type:
  feature-proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: [bin/fw, lib/review.sh, tests/unit/cron_flock_parity.bats]
related_tasks: []
created: 2026-04-27T15:06:01Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-28T11:56:22Z
source_task_id_in_origin: T-202
source_project_in_origin: "003-NTB-ATC-Plugin"
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1544: Pickup: Update agents/inception/AGENT.md copy-paste guidance for review-first Watchtower decide flow + project-port awareness (from 003-NTB-ATC-Plugin)

## Problem Statement

NTB-ATC pickup P-042 (origin T-202) reports the framework's inception-decide
copy-paste guidance still leads with the legacy CLI form (`fw inception decide
T-XXX go --rationale "..."`) even though structural enforcement (T-1259/T-1260)
already refuses that path when CLAUDECODE=1 and points agents at Watchtower.
Concrete repro: NTB-ATC's Watchtower runs on :3039 (its :3000 is taken by
termlink); agent-side guidance hard-coding :3000 produces wrong copy-paste.
The framework already has the resolution infrastructure (`bin/fw watchtower url`
reads the triple-file) — what's missing is documentation that leads with the
Watchtower path so a fresh agent sees it before reaching the CLI examples.

## Assumptions

- **A1:** The pickup's proposed target (`agents/inception/AGENT.md`) does not
  exist; the actual guidance lives in CLAUDE.md + two task templates.
- **A2:** CLAUDE.md still emits `fw inception decide ... --rationale ...`
  examples that read as guidance even though §Presenting Work for Human Review
  forbids it for human approvals.
- **A3:** `--rationale` is REQUIRED at the CLI surface (lib/inception.sh:292-293).
  Removing it from copy-paste blocks (per pickup AC1 verbatim) would emit
  broken commands for the human.
- **A4:** `bin/fw watchtower url` already resolves the project URL via the
  triple-file → fw config get PORT → :3000 fallback. No new helper needed.

## Exploration Plan

- Validate A1 by checking the framework directory tree.
- Validate A2 by grepping CLAUDE.md for `inception decide.*--rationale`.
- Validate A3 by reading lib/inception.sh argument parsing.
- Validate A4 by reading CLAUDE.md §Watchtower Port + bin/fw watchtower url.
- If all four hold, the realistic delta is: CLAUDE.md doc edits (2 sections,
  ~6 lines) + template footer rewrites (2 templates).

## Technical Constraints

- CLAUDE.md is auto-loaded into every Claude Code session — edits affect next
  invocation, no consumer sync required.
- Template edits affect new inception tasks created after the change; existing
  active tasks (T-1538/T-1544/T-1546) keep their old footers (non-functional
  HTML comments).
- The CLI surface (lib/inception.sh do_inception_decide) is OUT of scope for
  this inception — touching argument parsing is a separate inception.

## Scope Fence

**IN scope:**
- CLAUDE.md §Copy-Pasteable Commands examples (lines 528, 533, 545): rework to
  lead with `fw task review T-XXX`, label CLI as fallback.
- CLAUDE.md §Inception Discipline: one line referencing `bin/fw watchtower url`.
- `.tasks/templates/inception.md` and `.tasks/templates/path-c-deep-dive.md`
  Decision-section footer comment: rewrite Watchtower-first with CLI fallback.

**OUT of scope:**
- Changes to lib/inception.sh do_inception_decide argument parsing (separate
  inception — pickup AC1 verbatim requires this but is deferred).
- Changes to bin/fw watchtower url (already correct).
- Backfill of historical task footers (HTML comments, non-functional).


## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO (with reduced scope)

**Rationale:** Spike (`docs/reports/T-1544-inception-doc-update-spike.md`) validated
all four assumptions. The achievable delta is bounded and reversible: CLAUDE.md doc
edits in two sections (~6 lines) and footer rewrites in two task templates. No code
changes; no CLI semantics change. The pickup's AC1 verbatim ("no `--rationale` in
any decide-step copy-paste block") cannot be satisfied because `--rationale` is
required at the CLI surface (lib/inception.sh:292) and dropping it would emit
broken commands for the human. The right interpretation is Watchtower-first lead
with CLI as labeled fallback (CLI retains `--rationale`); a separate inception
should track loosening the CLI requirement if desired.

**Evidence:**
- Spike artifact `docs/reports/T-1544-inception-doc-update-spike.md` — full
  assumption-by-assumption findings, line-level CLAUDE.md citations, achievable-
  delta plan, risk surface.
- A1 confirmed: `agents/inception/` does not exist (`ls agents/`).
- A2 confirmed: 3 sites in CLAUDE.md (lines 528, 533, 545) emit the legacy form.
- A3 confirmed: lib/inception.sh:266,292-293 mandates `--rationale`.
- A4 confirmed: CLAUDE.md §Watchtower Port + `bin/fw watchtower url` already
  resolve project URLs via triple-file.

**Open question for human (non-blocker):** Should the framework also propose a
follow-up inception for loosening the CLI `--rationale` requirement (interactive
prompt or Watchtower-form-only path)? That would let pickup AC1 land verbatim.
Recommendation: capture as a separate inception, not bundled here.


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

**Decision**: GO

**Rationale**: Recommendation: GO (with reduced scope)

Rationale: Spike (`docs/reports/T-1544-inception-doc-update-spike.md`) validated
all four assumptions. The achievable delta is bounded and reversible: CLAUDE.md doc
edits in two sections (~6 lines) and footer rewrites in two task templates. No code
changes; no CLI semantics change. The pickup's AC1 verbatim ("no `--rationale` in
any decide-step copy-paste block") cannot be satisfied because `--rationale` is
required at the CLI surface (lib/inception.sh:292) and dropping it would emit
broken commands for the human. The right interpretation is Watchtower-first lead
with CLI as labeled fallback (CLI retains `--rationale`); a separate inception
should track loosening the CLI requirement if desired.

Evidence:
- Spike artifact `docs/reports/T-1544-inception-doc-update-spike.md` — full
  assumption-by-assumption findings, line-level CLAUDE.md citations, achievable-
  delta plan, risk surface.
- A1 confirmed: `agents/inception/` does not exist (`ls agents/`).
- A2 confirmed: 3 sites in CLAUDE.md (lines 528, 533, 545) emit the legacy form.
- A3 confirmed: lib/inception.sh:266,292-293 mandates `--rationale`.
- A4 confirmed: CLAUDE.md §Watchtower Port + `bin/fw watchtower url` already
  resolve project URLs via triple-file.

Open question for human (non-blocker): Should the framework also propose a
follow-up inception for loosening the CLI `--rationale` requirement (interactive
prompt or Watchtower-form-only path)? That would let pickup AC1 land verbatim.
Recommendation: capture as a separate inception, not bundled here.

**Date**: 2026-04-28T11:56:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-27T18:33:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

### 2026-04-28T11:56:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO (with reduced scope)

Rationale: Spike (`docs/reports/T-1544-inception-doc-update-spike.md`) validated
all four assumptions. The achievable delta is bounded and reversible: CLAUDE.md doc
edits in two sections (~6 lines) and footer rewrites in two task templates. No code
changes; no CLI semantics change. The pickup's AC1 verbatim ("no `--rationale` in
any decide-step copy-paste block") cannot be satisfied because `--rationale` is
required at the CLI surface (lib/inception.sh:292) and dropping it would emit
broken commands for the human. The right interpretation is Watchtower-first lead
with CLI as labeled fallback (CLI retains `--rationale`); a separate inception
should track loosening the CLI requirement if desired.

Evidence:
- Spike artifact `docs/reports/T-1544-inception-doc-update-spike.md` — full
  assumption-by-assumption findings, line-level CLAUDE.md citations, achievable-
  delta plan, risk surface.
- A1 confirmed: `agents/inception/` does not exist (`ls agents/`).
- A2 confirmed: 3 sites in CLAUDE.md (lines 528, 533, 545) emit the legacy form.
- A3 confirmed: lib/inception.sh:266,292-293 mandates `--rationale`.
- A4 confirmed: CLAUDE.md §Watchtower Port + `bin/fw watchtower url` already
  resolve project URLs via triple-file.

Open question for human (non-blocker): Should the framework also propose a
follow-up inception for loosening the CLI `--rationale` requirement (interactive
prompt or Watchtower-form-only path)? That would let pickup AC1 land verbatim.
Recommendation: capture as a separate inception, not bundled here.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2cef7667
- **Timestamp:** 2026-06-02T14:58:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-28T11:56:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
