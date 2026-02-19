# T-194: Research Persistence Failure Analysis

**Date:** 2026-02-19
**Participants:** Human + Claude (dialogue)
**Phase:** 0b (Control failure diagnosis)
**Trigger:** T-194 genesis discussion almost lost — human caught it with "is our discovery/analysis documented?"

## The Incident

During T-194 inception, a rich dialogue produced:
- T-151 timeline analysis (spec completed in 2 min without human)
- Three-layer assurance model (hooks → OE → discovery)
- ISO 27001 four-level mapping to AEF
- Complete control inventory (11 controls, 9 without OE)
- OE test design examples for 5 controls
- Discovery capability gap analysis with 12 examples

**None of this was being captured.** The agent was generating analysis, presenting it in conversation, and moving on. If the human hadn't asked "is our discovery/analysis documented?", all of it would have been lost at compaction or session end.

## Seven Controls That Failed

| # | Control | Type | Why it failed HERE |
|---|---------|------|-------------------|
| 1 | Audit Section 10 (T-185) | Detective | Only checks **completed** inception tasks. T-194 is active — won't fire for weeks. |
| 2 | Resume integration (T-185) | Recovery | Shows existing files. Can't detect research **never written**. |
| 3 | CLAUDE.md dispatch rules | Advisory | Only apply to **sub-agent** dispatch. Main-thread conversation uncovered. |
| 4 | Session capture checklist | Advisory | Agent must remember to follow it. Same unreliability as manual `fw audit`. |
| 5 | G-009 gap (registered) | Awareness | Status: "decided-build." Implementation was partial — audit + resume only. |
| 6 | T-190 task | Intended | Started-work but barely explored. No enforcement built. |
| 7 | fw bus | Unused | Designed, built, documented, **never used once** across 190+ tasks. Dead code. |

## Root Cause Analysis

**Every control is either post-hoc, advisory, scope-limited, or unused:**

- **Post-hoc:** Checks at task completion — conversation gone by then
- **Advisory:** CLAUDE.md rules agent must remember — same failure as "agent remembers to audit"
- **Scope-limited:** Covers sub-agent outputs, not main-thread conversation (where most research happens)
- **Unused:** fw bus adopted by nobody

**The conversation between human and agent — where decisions, discoveries, and insights actually occur — has ZERO structural enforcement for capture.**

## Pattern: Control Design ≠ Operational Effectiveness

This is a textbook ISO 27001 control failure:
- **Control Design:** 7 mechanisms exist. Looks comprehensive on paper.
- **Operational Effectiveness:** None prevent the most common scenario (main-thread research loss).

The controls were designed for a narrower problem (sub-agent output persistence) than the actual risk (all research persistence). The risk was mis-scoped.

## Evidence From Project History

From `gaps.yaml` G-009:
> "Sub-agent dispatch protocol says content generators 'MUST write to disk' and use fw bus. Reality: fw bus has NEVER been used. 5+ agents dispatched returned full content — would have been lost without human intervention."

From `patterns.yaml` FP-004:
> "72 tool calls consumed context. Handover was skeleton with [TODO] placeholders — useless for recovery."

The pattern repeats: research generated → not persisted → context lost → recovery impossible.

## Candidate Remediation Options

| Option | Type | Description | Pros | Cons |
|--------|------|-------------|------|------|
| **A** | Preventive gate | After N tool calls on inception task, block further work until docs/reports/ commit exists | Structural, can't bypass | May be annoying if N is wrong |
| **B** | Periodic prompt | Conversation checkpoint — like budget warnings but for research capture | Low friction, natural cadence | Still advisory (agent can ignore) |
| **C** | Phase transition gate | Can't proceed to next phase until current phase artifact committed | Precise, phase-aligned | Requires phases to be machine-readable |
| **D** | Live document pattern | Create research file FIRST (even empty), fill as conversation progresses | Proven (T-191 used this successfully) | Requires discipline, not enforced |
| **E** | PostToolUse hook | After each conversation turn, check if research-generating activity occurred without a matching file write | Structural, real-time | Complex to detect "research-generating activity" |
| **F** | Commit cadence + artifact check | Existing commit cadence rule extended: inception commits require docs/reports/ in the diff | Piggybacks on existing enforcement | Only catches at commit time |

### T-191 as positive evidence for Option D

T-191 (Component Fabric) successfully persisted all Phase 1 research:
- `docs/reports/T-191-cf-genesis-discussion.md` — Phase 0
- `docs/reports/T-191-cf-research-landscape.md` — Phase 1a
- `docs/reports/T-191-cf-aef-topology-sample.md` — Phase 1b
- `docs/reports/T-191-cf-research-ui-patterns.md` — Phase 1c

Why did T-191 succeed? The human established the pattern early: "the thinking trail IS the artifact." The agent internalized this and created files per phase. But this was **human discipline**, not structural enforcement. It worked because the human was actively engaged.

## Open Questions

1. Which option(s) to prototype?
2. Can options be combined (e.g., D + F: live document + commit gate)?
3. What's "research-generating activity" for option E? (How would a hook know?)
4. Should the remediation be inception-specific or apply to all task types?
5. What about non-inception research? (Build tasks can generate discoveries too)

## Decision Needed

This analysis feeds into T-194 Phase 1 (risk landscape) and directly addresses T-190's scope. The remediation choice should be validated experimentally before becoming a build task.
