---
id: T-2347
name: "Arc closure UX RCA — Watchtower arc-action handoff defaults to CLI"
description: >
  RCA on why arc-006 closure flow surfaced CLI commands in agent handoff instead of
  Watchtower URLs. Three defects found: (A) arc_detail.html:430-447 prints fw arc
  close CLI block instead of linking to existing /arcs/<slug>/close form. (B) /approvals
  'Arc Closure' filter undercounts constituents (35/51 = 68% < 80% threshold) excluding
  arc-006 from auto-surface despite CLI showing 49/53 = 92%. (C) Agent reflexively
  gives CLI commands for arc actions (approve-driver, close) despite Watchtower buttons
  existing — memory entries (use_fw_task_review, etc.) only cover task review handoffs,
  not arc actions.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [watchtower, arc-mechanics, ux, arc:arc-grooming]
components: []
related_tasks: [T-1671, T-1911, T-1961, T-2125, T-2182]
created: 2026-06-12T10:25:35Z
last_update: '2026-08-16T22:25:02Z'
date_finished: 2026-06-12T10:32:32Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-12T10:30:03Z'
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
  - ts: '2026-08-16T22:25:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-12T10:30:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2347: Arc closure UX RCA — Watchtower arc-action handoff defaults to CLI

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Is the constituent-count gap (35/51 Watchtower vs 49+/53 CLI) caused by `arc_id:` vs `tags:[arc:*]` heterogeneity, or by a different resolver path?**
  confidence: 2
  disposition: deferred
  rationale: Defect B identified at `web/blueprints/approvals.py:405`; root cause in `_resolve_constituents` (`web/blueprints/arcs.py:422`) — Slice B1 build task will isolate via parity test against `bin/fw arc show` task lookup.

- **IW-2: Should arc_detail.html keep a CLI fallback at all, or only the Watchtower button?**
  confidence: 2
  disposition: answered
  rationale: Keep collapsible CLI fallback (`<details>`) — headless/no-Watchtower environments exist (cron, remote SSH), and the CLI command is the underlying source-of-truth verb anyway. Primary affordance becomes the button; CLI is the backup.

- **IW-3: Should the `--from-watchtower` block of the agent-refusal message at `lib/arc.sh:670-705` be reworded to lead with the resolved Watchtower URL?**
  confidence: 1
  disposition: deferred
  rationale: Slice C2 candidate — defense in depth. Currently mid-block; promoting the URL to the top of the refusal would have caught this in-session. Decide after A1+B1+C1 ship; may be obviated by A1.

- **IW-4: Are there other arc verbs (`fw arc abandon`, `fw arc create`, `fw arc focus`) with the same CLI-handoff default?**
  confidence: 1
  disposition: deferred
  rationale: Out of scope for T-2347 (one bug = one task). Spike after Slice C1 lands the memory rule; if the rule covers them automatically, file no follow-up.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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

**Recommendation:** GO

**Rationale:** Three structural defects with concrete file:line evidence. (A) arc_detail.html:430-447 renders <pre><code> CLI block when /arcs/<slug>/close form exists (arcs.py:1253). (B) approvals.py:_load_close_ready_arcs filter at line 405 uses _completion_stats=35/51 vs CLI fw arc show value-prioritisation=49+/53 — constituent resolver parity gap (likely arc_id vs tags:arc:* mismatch). (C) agent gave CLI for both arc-011 approve-driver and arc-006 close in this session despite Watchtower endpoints existing — needs CLAUDE.md rule sibling to T-679 (task review URLs). Each defect has a bounded build slice; all reversible; high value (every arc closure today routes through this UX). Recommendation GO with rationale walked.

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

**Rationale**: Three structural defects with concrete file:line evidence. (A) arc_detail.html:430-447 renders <pre><code> CLI block when /arcs/<slug>/close form exists (arcs.py:1253). (B) approvals.py:_load_close_ready_arcs filter at line 405 uses _completion_stats=35/51 vs CLI fw arc show value-prioritisation=49+/53 — constituent resolver parity gap (likely arc_id vs tags:arc:* mismatch). (C) agent gave CLI for both arc-011 approve-driver and arc-006 close in this session despite Watchtower endpoints existing — needs CLAUDE.md rule sibling to T-679 (task review URLs). Each defect has a bounded build slice; all reversible; high value (every arc closure today routes through this UX). Recommendation GO with rationale walked.

**Date**: 2026-06-12T10:32:31Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-12T10:32:31Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Three structural defects with concrete file:line evidence. (A) arc_detail.html:430-447 renders <pre><code> CLI block when /arcs/<slug>/close form exists (arcs.py:1253). (B) approvals.py:_load_close_ready_arcs filter at line 405 uses _completion_stats=35/51 vs CLI fw arc show value-prioritisation=49+/53 — constituent resolver parity gap (likely arc_id vs tags:arc:* mismatch). (C) agent gave CLI for both arc-011 approve-driver and arc-006 close in this session despite Watchtower endpoints existing — needs CLAUDE.md rule sibling to T-679 (task review URLs). Each defect has a bounded build slice; all reversible; high value (every arc closure today routes through this UX). Recommendation GO with rationale walked.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8e101cc3
- **Timestamp:** 2026-06-12T10:32:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

### 2026-06-12T10:32:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
