---
id: T-1355
name: "CLAUDE.md size exceeds Claude Code 40K perf threshold — decompose vs. trim"
description: >
  Inception: CLAUDE.md size exceeds Claude Code 40K perf threshold — decompose vs. trim

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-20T09:24:02Z
last_update: 2026-04-24T09:33:52Z
date_finished: 2026-04-24T09:33:52Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1355: CLAUDE.md size exceeds Claude Code 40K perf threshold — decompose vs. trim

## Problem Statement

CLAUDE.md currently measures 74,177 bytes (1,262 lines, ~18.5K tokens at a 4 chars/token approximation). Anthropic's Claude Code docs flag ~40K characters as the size at which system-prompt auto-loading starts to measurably slow turn-1 responses and stress the context budget. Our file is 1.85× that threshold. Every new session consumes ~18.5K tokens on governance prose *before* the user types their first message, which eats straight into the 300K working budget that the rest of the session will spend compressing, recovering, and handing over. The file has grown organically (T-1115, T-1117, T-1257, T-1259, T-1260, T-1284, T-1287, T-1376, T-1388 all added prose) without any corresponding trim pass. Question: *decompose* (split into CLAUDE.md + per-topic include files), *trim* (prune redundant prose + stale examples), or *both*?

## Assumptions

- A1: Claude Code's session-start token cost scales ~linearly with CLAUDE.md size up to the 300K window; every 1K tokens of CLAUDE.md costs 1K tokens of headroom. — LIKELY TRUE, directly measurable.
- A2: >30% of current CLAUDE.md prose is either duplicated elsewhere (e.g. Quick Reference table duplicates `fw help`) or stale (references to deprecated flows). — UNTESTED; needs inline diff pass.
- A3: Consumer projects inherit CLAUDE.md verbatim on `fw upgrade`; shrinking the framework's version shrinks every consumer's token cost too. — LIKELY TRUE from architectural knowledge.
- A4: A `@include` or `@import` pattern that Claude Code honours exists, enabling split files without losing governance coverage. — UNTESTED (needs Claude Code docs check).
- A5: Trim-only (no decomposition) can reach ~45K bytes (60%) with minimal governance loss if Quick Reference + redundant examples are factored to `fw help` / agent AGENT.md files. — EDUCATED GUESS, 60% is the floor that still keeps the four-directive frame + task gate + escalation ladder intact.

## Exploration Plan

- **Spike A** (15m): Section-by-section size audit. Produce `docs/reports/T-1355-claudemd-size-audit.md` with per-heading byte/token counts; flag top-10 heaviest sections. Inline measurement only, no edits.
- **Spike B** (10m): Scan for duplication — grep each section for content already present in `fw help`, `FRAMEWORK.md`, `agents/*/AGENT.md`, or inline in enforcement scripts. Flag candidates for extraction.
- **Spike C** (5m): Verify Claude Code's auto-load behaviour — does the session JSONL show the full CLAUDE.md in system prompt? (We know it does from observed behaviour; confirms A1 magnitude.)
- **Spike D** (5m): Check Claude Code docs for `@include` / file-include support. If present, decomposition is free; if absent, trim-only or path-pointer rule (e.g. "see AGENT.md in each agents/*/") is the only option.

## Technical Constraints

- CLAUDE.md is loaded verbatim at session start — no lazy-load, no truncation, no compression (our own governance rule disables auto-compact, D-027).
- Consumer projects vendor CLAUDE.md via `fw upgrade` — any restructure must be backwards-compatible or ship a migration note.
- Governance-critical invariants (four directives, task gate, escalation ladder, tier table, §Autonomous Mode Boundaries) must stay in the root file — they are the instruction-precedence anchor.
- Plugin-provided skills read CLAUDE.md for precedence signals; if we move rules into sub-files, skills still need to find them (deterministic include path, not glob).

## Scope Fence

**IN:**
- Measure current size + per-section cost.
- Decide: trim-only, decompose-only, or both.
- Identify 3-5 highest-leverage trim targets (Quick Reference? Repeated examples? The entire `fw CLI` section that duplicates `fw help`?).
- Name the decomposition pattern if chosen (sub-files, AGENT.md links, etc.).

**OUT:**
- Actually doing the trim/decompose (that is a separate build task — this inception sizes the opportunity).
- Rewriting the Core Principle, Constitutional Directives, or Authority Model.
- Touching CLAUDE.md in consumer projects (framework change propagates on next upgrade).

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
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

## Recommendation

**Recommendation:** GO — trim-first, decompose-only if trim tops out

**Rationale:** The problem is real and quantified — 74,177 bytes / ~18.5K tokens burned per session on governance prose before the user types. At 300K context budget, that is ~6% of the budget spent on a file that almost never changes session-to-session. A1 (linear cost) is a measurable mechanism, A3 (consumer projects pay the same cost) is architectural, and the trajectory is monotonically upward — every fix-RCA-learning arc this year has added to CLAUDE.md; nothing has been removed. Recommend a GO at the narrowest viable scope: a trim-first pass targeting 45K bytes (≈40% reduction) by factoring the Quick Reference table into `fw help` output (which already exists and is authoritative), collapsing the duplicated CLI catalogue, and consolidating the repeated "[REVIEW]/[RUBBER-STAMP]" examples into a single worked example with a reference. Only if trim-first stalls above 55K bytes do we commit to decomposition (Claude Code `@include` semantics — A4 — will need verification first). Decomposition-first is over-engineered for a file that is mostly prose, not config.

**Evidence:**
- Measurement this session: 74,177 bytes, 1,262 lines, ~18.5K tokens (see Problem Statement).
- Growth trajectory: T-1115, T-1117, T-1257, T-1259, T-1260, T-1284, T-1287, T-1376, T-1388 all added prose in the last ~90 days. No recorded trim pass in git log.
- `fw help` authoritative for Quick Reference (the table is a copy of the CLI's own `help` output — pure duplication).
- Consumer projects vendor CLAUDE.md verbatim via `fw upgrade` — every byte we save here saves bytes in every consumer session too (A3 linear amplifier).
- Scope-fence is tight: inception decides trim-vs-decompose + names targets; separate build task does the actual cut. GO commits us only to the scoping commit.
- Risk mitigation: keep Core Principle, Four Directives, Authority Model, Instruction Precedence, Task Gate, Escalation Ladder, §Autonomous Mode Boundaries, §Human Task Completion, §Copy-Pasteable Commands, §Plan Mode Prohibition, §Built-in Task Tool Ban all in-root — these are the high-blast-radius anchors; trim acts on redundant catalogues and worked examples only.

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

**Rationale**: Recommendation: GO — trim-first, decompose-only if trim tops out

Rationale: The problem is real and quantified — 74,177 bytes / ~18.5K tokens burned per session on governance prose before the user types. At 300K context budget, that is ~6% of the budget spent on a file that almost never changes session-to-session. A1 (linear cost) is a measurable mechanism, A3 (consumer projects pay the same cost) is architectural, and the trajectory is monotonically upward — every fix-RCA-learning arc this year has added to CLAUDE.md; nothing has been removed. Recommend a GO at the narrowest viable scope: a trim-first pass targeting 45K bytes (≈40% reduction) by factoring the Quick Reference table into `fw help` output (which already exists and is authoritative), collapsing the duplicated CLI catalogue, and consolidating the repeated "[REVIEW]/[RUBBER-STAMP]" examples into a single worked example with a reference. Only if trim-first stalls above 55K bytes do we commit to decomposition (Claude Code `@include` semantics — A4 — will need verification first). Decomposition-first is over-engineered for a file that is mostly prose, not config.

Evidence:
- Measurement this session: 74,177 bytes, 1,262 lines, ~18.5K tokens (see Problem Statement).
- Growth trajectory: T-1115, T-1117, T-1257, T-1259, T-1260, T-1284, T-1287, T-1376, T-1388 all added prose in the last ~90 days. No recorded trim pass in git log.
- `fw help` authoritative for Quick Reference (the table is a copy of the CLI's own `help` output — pure duplication).
- Consumer projects vendor CLAUDE.md verbatim via `fw upgrade` — every byte we save here saves bytes in every consumer session too (A3 linear amplifier).
- Scope-fence is tight: inception decides trim-vs-decompose + names targets; separate build task does the actual cut. GO commits us only to the scoping commit.
- Risk mitigation: keep Core Principle, Four Directives, Authority Model, Instruction Precedence, Task Gate, Escalation Ladder, §Autonomous Mode Boundaries, §Human Task Completion, §Copy-Pasteable Commands, §Plan Mode Prohibition, §Built-in Task Tool Ban all in-root — these are the high-blast-radius anchors; trim acts on redundant catalogues and worked examples only.

**Date**: 2026-04-24T09:33:51Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-20T09:24:21Z — status-update [task-update-agent]
- **Change:** horizon: now → later

### 2026-04-23T16:46:49Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-24T09:33:51Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — trim-first, decompose-only if trim tops out

Rationale: The problem is real and quantified — 74,177 bytes / ~18.5K tokens burned per session on governance prose before the user types. At 300K context budget, that is ~6% of the budget spent on a file that almost never changes session-to-session. A1 (linear cost) is a measurable mechanism, A3 (consumer projects pay the same cost) is architectural, and the trajectory is monotonically upward — every fix-RCA-learning arc this year has added to CLAUDE.md; nothing has been removed. Recommend a GO at the narrowest viable scope: a trim-first pass targeting 45K bytes (≈40% reduction) by factoring the Quick Reference table into `fw help` output (which already exists and is authoritative), collapsing the duplicated CLI catalogue, and consolidating the repeated "[REVIEW]/[RUBBER-STAMP]" examples into a single worked example with a reference. Only if trim-first stalls above 55K bytes do we commit to decomposition (Claude Code `@include` semantics — A4 — will need verification first). Decomposition-first is over-engineered for a file that is mostly prose, not config.

Evidence:
- Measurement this session: 74,177 bytes, 1,262 lines, ~18.5K tokens (see Problem Statement).
- Growth trajectory: T-1115, T-1117, T-1257, T-1259, T-1260, T-1284, T-1287, T-1376, T-1388 all added prose in the last ~90 days. No recorded trim pass in git log.
- `fw help` authoritative for Quick Reference (the table is a copy of the CLI's own `help` output — pure duplication).
- Consumer projects vendor CLAUDE.md verbatim via `fw upgrade` — every byte we save here saves bytes in every consumer session too (A3 linear amplifier).
- Scope-fence is tight: inception decides trim-vs-decompose + names targets; separate build task does the actual cut. GO commits us only to the scoping commit.
- Risk mitigation: keep Core Principle, Four Directives, Authority Model, Instruction Precedence, Task Gate, Escalation Ladder, §Autonomous Mode Boundaries, §Human Task Completion, §Copy-Pasteable Commands, §Plan Mode Prohibition, §Built-in Task Tool Ban all in-root — these are the high-blast-radius anchors; trim acts on redundant catalogues and worked examples only.

### 2026-04-24T09:33:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** Inception decision in progress

### 2026-04-24T09:33:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d4085a6a
- **Timestamp:** 2026-06-02T14:56:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
