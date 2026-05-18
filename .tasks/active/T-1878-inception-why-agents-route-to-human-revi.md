---
id: T-1878
name: "[INCEPTION] Why agents route to human review when reviewer/agent could close — structural routing-decision investigation"
description: >
  3rd recurrence of the same pattern: agents file Human ACs that fw reviewer would PASS + needs_human=no, then sit in review queue while only 6/33 are genuinely human-only. Prior remediations (T-954 matrix, T-1811 [REVIEWER] prefix) were vocabulary-level — the routing decision at AC-file time defaults to [REVIEW] regardless. Investigate root cause + structural enforcement.

status: started-work
workflow_type: inception
owner: claude
horizon: now
tags: [arc, arc-grooming, routing, reviewer-agent, governance, recurrence]
components: []
related_tasks: [T-954, T-1811, T-1687, T-1730, T-1731, T-1854, T-1855]
created: 2026-05-17T07:18:29Z
last_update: 2026-05-18T07:42:53Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1878: [INCEPTION] Why agents route to human review when reviewer/agent could close — structural routing-decision investigation

## Problem Statement

Agents authoring task files default to `[REVIEW]` Human ACs even when the "Expected" sub-claim is mechanical (grep / file-exists / structural). The reviewer agent (`fw reviewer`) confirms after-the-fact that many such ACs are agent-actionable (PASS + needs_human=no), but the routing decision was already made at file-time, sending the AC to the human queue and consuming attention that should go to genuine taste/judgment calls.

**Evidence (this week):** T-1851, T-1857, T-1890, T-1893 — 4 mis-classifications shipped in ~3 days. T-1894 (today) was the manual remediation. T-1878 names this as the 3rd recurrence after T-954 (vocabulary matrix) and T-1811 (`[REVIEWER]` prefix) — both vocabulary fixes that didn't change AC-author-time defaults.

**Why now:** Per Error Escalation Ladder, vocabulary-level fixes (B/C) twice over haven't held. Time to consider C (tooling) or D (ways of working) — structural intervention at AC-author time.

Full reasoning + dialogue in `docs/reports/T-1878-routing-default-bias.md`.

## Assumptions

- **A1** — Defensive bias is primary driver. Agents internalise CLAUDE.md's "when in doubt, make it Human" and over-apply.
- **A2** — `[REVIEWER]` prefix (T-1811, 4 days old) is unknown/unfamiliar at AC-author time.
- **A3** — Template anchoring matters: example `### Human` block primes `[REVIEW]`; no parallel `[REVIEWER]` example exists.
- **A4** — Reviewer-at-close is too late; needs to run at AC-edit time to influence the routing decision.
- **A5** — A static scanner could catch most mis-classifications via lexical signals (file paths, grep terms, references to specific task IDs, command outputs) in the Steps/Expected clauses.

## Exploration Plan

Time-boxed to ≤2 hours total. Four spikes:

1. **Corpus scan (30 min):** Across all `.tasks/{active,completed}/T-*.md`, count `[REVIEW]` Human ACs and run `fw reviewer T-XXX` on each. Compute the % that the reviewer would close without human input. Tests A1+A2.
2. **Author-time signal analysis (30 min):** For T-1851/T-1857/T-1890/T-1893, catalogue lexical patterns in the original `[REVIEW]` AC's "Expected" clauses that signal mechanical content. Validates A5.
3. **Template + tooling inspection (20 min):** Read `.tasks/templates/zzz-default.md`, `agents/reviewer/`, and PreToolUse hooks on `.tasks/active/T-*.md` to identify integration points for a routing-bias check. Tests A3+A4.
4. **Cost/benefit ranking (20 min):** For each candidate intervention, estimate implementation cost + false-positive rate + catch rate against the 4 just-fixed cases. Inputs to GO/NO-GO.

## Technical Constraints

- New PreToolUse hooks must run <50ms (matches existing `check-arc-id.py`).
- Author-time signal must come from the file content + corpus context — no network calls or upstream reads.
- Backward-compat: existing `[REVIEW]` ACs in the corpus stay until manually re-classed; intervention applies to *new* author actions only.
- Must work for both `Write` (full content) and `Edit/MultiEdit` (substitution) tool shapes — see T-1893's Prong 2 wire-evidence demo for the payload-shape gotcha.

## Scope Fence

**In scope:**
- AC-author-time routing decision (Agent vs Human + `[REVIEW]` vs `[REVIEWER]`)
- Structural interventions to shift the default toward `[REVIEWER]` when mechanical
- Audit-time detectors that surface mis-classification *before* the human sees it

**Out of scope:**
- Re-classifying historical mis-classified `[REVIEW]` ACs in the corpus (separate sweep task; T-1894 covered today's 4)
- Expanding `fw reviewer`'s pattern catalogue
- Watchtower UI changes
- Render-surface gate P-013 (T-1766) — different human-AC class
- Inception go/no-go authority — that's genuinely human

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Spike 1 shows ≥30% of `[REVIEW]` Human ACs in active+completed tasks are agent-closable per `fw reviewer` (confirms scale)
- At least one structural intervention designed with <200 LOC implementation, <10ms author-time overhead, and ≥75% catch rate against T-1851/T-1857/T-1890/T-1893 cases
- Intervention is bounded, testable, and reversible (PreToolUse hook fits this — already a proven pattern)

**NO-GO if:**
- Spike 1 shows <15% mis-classification rate — pattern is too rare to warrant structural enforcement; vocabulary discipline + occasional manual audit (T-1894-style) is cheaper
- No bounded intervention achieves both reasonable false-positive rate (<20%) and reasonable catch rate (>50%) — risks creating warning fatigue worse than the disease

**DEFER if:**
- Spike 1 shows 15-30% mis-class rate AND no intervention is clearly net-positive — wait for 4th recurrence (revisit_evidence_needed: "4th observed mis-class instance in audit")

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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-18T07:41:49Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-18T07:42:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-05-18T07:42:53Z — status-update [task-update-agent]
- **Change:** horizon: now → now
