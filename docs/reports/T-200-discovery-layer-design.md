# T-200: Discovery Layer Design — Research Artifact

**Date:** 2026-02-22
**Participants:** Human + Claude (dialogue)
**Phase:** T-194 Phase 4 (follow-up inception)
**Prerequisite:** T-194 Phases 1-3 (risk landscape, control register, OE tests)

## Problem Statement

The framework has three assurance layers designed in T-194:
1. **Layer 1 (Hooks):** Real-time enforcement during sessions (11 blocking controls)
2. **Layer 2 (OE Tests):** Periodic verification that controls are working (20/23 automatable)
3. **Layer 3 (Discovery):** Pattern detection, omission finding, insight surfacing — **NOT YET DESIGNED**

Layer 3 is where the framework moves from "are controls working?" to "what are we missing?" This is the antifragility layer — it finds things no single check can see by analyzing patterns across time.

## Prior Art (from T-194 genesis discussion)

### Omission Detection Examples
| Discovery | Example |
|-----------|---------|
| Tasks stuck too long | T-190 "started-work" for 10h with 0 updates |
| Decisions made without dialogue | T-151 captured→completed in 2 min with owner: human |
| Specs completed without human review | Specification tasks completed by agent without human interaction |
| Stale handovers with unfilled TODOs | LATEST.md has `[TODO]` sections |
| Growing gaps register without action | G-004 "watching" for days with no trigger |
| Commits bunching (budget pressure) | 5 commits in 10 minutes = agent rushing |

### Insight Generation Examples
| Insight | Example |
|---------|---------|
| Pattern emerging across tasks | Same error type hit 3+ times → candidate for practice |
| Velocity change | Tasks taking 2x longer than average |
| Task quality degrading | Descriptions getting shorter, ACs vaguer over time |
| Agent bypassing governance | Bypass log growing, `--force` usage increasing |

## Data Sources Available

| Source | Volume | What it reveals |
|--------|--------|-----------------|
| Cron audits | 234 YAML files | Compliance trends over time |
| Episodic memory | 235 files | Task outcomes, patterns, decisions |
| Completed tasks | 230 files | Work patterns, lifecycle metrics |
| Active tasks | 6 files | Current state, stuck detection |
| Git history | 550+ commits | Velocity, commit patterns, bypasses |
| Risks register | 38 risks | Open risk tracking |
| Controls register | 23 controls | Control effectiveness |
| Issues register | 8 incidents | Resolution patterns |
| Learnings | 58+ entries | Knowledge accumulation |
| Patterns | 14+ entries | Failure/success patterns |
| Gaps register | 2 watching | Spec-reality drift |
| Bypass log | Variable | Governance circumvention |

## Research Questions

1. What discovery capabilities provide the highest value-to-effort ratio?
2. How should discoveries surface to the human? (cron reports? session-start? web UI? all three?)
3. What temporal analysis requires looking across audit history vs point-in-time?
4. Should discoveries be prescriptive ("fix this") or observational ("look at this")?
5. What's the right frequency for each discovery type?
6. How do we avoid false positives that erode trust?

## Dialogue Log

<!-- Record questions, answers, course corrections during human dialogue -->

</content>
</invoke>