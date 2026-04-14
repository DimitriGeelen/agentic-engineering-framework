# T-1252 — Audit detection quality: bugfix-learning denominator

**Task:** T-1252
**Type:** Inception (research artifact per C-001)
**Created:** 2026-04-14

## Problem

The audit at `agents/audit/audit.sh:952-990` counts any completed task whose name
matches `fix|bugfix|hotfix|RCA|G-[0-9]` as a "bugfix" and expects each to have a
learning. Denominator is 242. But per CLAUDE.md "Bug-Fix Learning Checkpoint",
the rule only applies to **field-discovered** bugs — not dev-discovered ones.

Result: a mismatched denominator inflates the FAIL; the metric loses signal.

## Spikes

### Spike A — 20-task classification

<!-- Sample 20 completed "fix" tasks. Classify as field-discovered vs. dev-discovered. -->

### Spike B — Mechanical detection signals

<!-- What file/metadata signals correlate with field-discovery?
     - Created via `fw pickup`?
     - References a concerns register entry?
     - Linked to RCA task?
     - Task name contains "reported by" / specific phrasing?
-->

### Spike C — Revised denominator impact

<!-- Run the proposed narrower filter; compute corrected coverage ratio. -->

## Findings

<!-- Populated as spikes complete. -->

## Recommendation

<!-- GO/NO-GO/DEFER with rationale. -->

## Dialogue Log

<!-- Conversational reasoning trail. -->
