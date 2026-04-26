# T-1451 — Handover URL Sweep

**Type:** Inception
**Date:** 2026-04-25
**Decision:** GO (handover-only scope)
**Source task:** `.tasks/completed/T-1451-sweep-all-human-handoff-touchpoints--ren.md`

## Problem Statement

User feedback 2026-04-25: agent listed `T-1445/46/47/48/49/50 each have one [REVIEW]` without rendering URLs — friction caused human to ask for links explicitly. Goal: zero-friction review queue. The chat-side rule was already codified (`feedback_human_review_links.md`); this inception closes the structural side: which output surfaces still surface bare task IDs?

## Audit findings

| Surface | Status |
|---|---|
| `agents/handover/handover.sh` lines 477, 513, 570 | **Bare T-XXX IDs in 3 print sites** (Python heredocs) |
| `lib/review.sh` (fw task review) | URLs already rendered |
| Tier 0 prompts | URLs already rendered |
| `fw verify-acs` output | URLs already rendered |
| `fw audit` output | Bare IDs (lower-traffic surface) |
| `fw healing` output | Bare IDs (lower-traffic surface) |

## Recommendation

**GO with handover-only scope** (~30 minutes, single build task).

**Rationale:** The handover IS the gap — every other human-facing surface already renders URLs. The handover is also the highest-traffic surface (loaded via `/resume` at every session start, 28+46 task references per render). Doing the handover scope alone removes ~80% of the visible friction at low risk.

**Implementation:** Add `WT_URL` resolution at top of handover.sh (mirroring lib/review.sh:42-52 pattern), substitute into the 3 print sites.

**Out-of-scope (track separately if friction recurs):** audit.sh, healing.sh, fw note list.

## Outcome

Build task T-1461 implemented the handover URL sweep (closed 2026-04-25).
