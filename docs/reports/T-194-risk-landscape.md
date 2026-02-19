# T-194: Risk Landscape — Phase 1

**Date:** 2026-02-19
**Participants:** Human + Claude (dialogue)
**Phase:** 1a (Risk identification from incidents)
**Method:** Mined patterns.yaml (14 patterns), learnings.yaml (58 learnings), gaps.yaml (10 gaps), 190 episodic files, CLAUDE.md origins

## Summary

**38 distinct risks identified** across 9 categories, all traced to actual incidents.

| Category | Count | Closed | Open |
|----------|-------|--------|------|
| Governance Bypass | 3 | 1 | 2 |
| Context/Session Loss | 7 | 6 | 1 |
| Knowledge Loss | 6 | 4 | 2 |
| Quality Decay | 4 | 2 | 2 |
| Tooling Fragility | 5 | 4 | 1 |
| Operational Loops | 2 | 2 | 0 |
| Session/Memory | 5 | 4 | 1 |
| Architecture | 3 | 2 | 1 |
| Human Oversight | 2 | 2 | 0 |
| **TOTAL** | **38** | **27** | **11** |

## Risk Categories

### Category 1: Governance Bypass

Risks where framework rules are circumvented, intentionally or through design gaps.

| ID | Incident | Risk Statement | Control | Status |
|----|----------|---------------|---------|--------|
| R-001 | T-061: 0/20 plugin skills were task-aware; plugins claimed authority over CLAUDE.md | External code overrides governance rules | PreToolUse hook (check-active-task.sh), fw work-on, instruction precedence in CLAUDE.md | Closed |
| R-002 | T-057: Agent checked behavior ACs without observation (7/8 falsely completed) | Human-verifiable criteria completed without human verification | T-192 GO → T-193 (AC tagging with ### Agent / ### Human) | Decided-build |
| R-003 | T-138: Agent skipped inception despite knowing the rule | Architectural decisions made without exploration | L-042 recorded; no structural enforcement | Acknowledged |

### Category 2: Context/Session Loss

Risks where session context (tokens, working memory) is exhausted or corrupted.

| ID | Incident | Risk Statement | Control | Status |
|----|----------|---------------|---------|--------|
| R-004 | T-059: Session hit 0% context, no handover generated | Work context destroyed with no recovery | P-009 budget management, tool counter, checkpoint.sh | Closed |
| R-005 | T-078: Session at 177K tokens (88%) with ZERO warnings | Context monitoring fails silently | T-078: cache removal, synthetic filtering, 2MB window | Closed |
| R-006 | T-145: Budget gate deadlock after compaction | Fresh sessions locked by stale budget state | T-145: allowlist fw context init, pre-compact reset | Closed |
| R-007 | Sprechloop: 14 cascading compactions in 13 minutes (L-050) | Budget protection creates runaway loops | T-136 cooldown, T-148 dedup, T-149 project isolation | Closed |
| R-008 | T-136: 25 handover commits in 10 minutes | Safety mechanisms create cascading triggers | T-136: 10-minute cooldown file | Closed |
| R-009 | G-007: Budget gate non-functional in shared-tooling mode | Budget protection silently fails in multi-project setup | T-149: 4 bugs fixed (transcript discovery, reset, stale handling) | Closed |
| R-028 | L-031/L-032: Research + implementation burns ~100K context | Architectural insights lost before session ends | L-031/L-032: synthesize immediately, split sessions | Closed |

### Category 3: Knowledge Loss

Risks where decisions, research, learnings, or work history is lost.

| ID | Incident | Risk Statement | Control | Status |
|----|----------|---------------|---------|--------|
| R-010 | G-009: Sub-agent research returned to context, lost at session end | Agent-generated knowledge not persisted | fw bus (never adopted), T-178 GO, T-185 partial, **T-194 C-001/C-002/C-003** | Decided-build → Experiment |
| R-011 | G-008: TaskOutput raw JSONL (30-50K chars × 4) | Uncontrolled tool output exhausts context | L-053/L-054: write-to-file instructions | Decided-build |
| R-012 | T-112: Task marked complete, 6 commits followed (173 min, bug fix, 2 new tasks) | Significant work after closure becomes invisible | T-113 AC gate, T-114 closed task warning, T-122 verification gate | Closed |
| R-013 | FP-006: Post-closure commits reference closed task | Knowledge accumulates in wrong location | T-114 warning, episodic refresh | Closed |
| R-014 | T-141: init.sh created `patterns: []` but pattern.sh expected `failure_patterns:` | Framework knowledge silently lost by format mismatch | T-141: YAML format fix, L-047: round-trip verification | Closed |
| R-015 | T-140/T-141: create-task.sh used hardcoded heredoc, not template | Controls bypassed via alternative code paths | T-141: wire template, L-044/L-045 | Closed |

### Category 4: Quality Decay

Risks where work quality degrades without detection.

| ID | Incident | Risk Statement | Control | Status |
|----|----------|---------------|---------|--------|
| R-016 | T-112: No gate preventing work-completed without AC verification | Incomplete work declared complete | T-113 P-010 gate, T-122 P-011 verification gate | Closed |
| R-017 | T-140/T-141: P-011 treated HTML comments as executable commands | Template text executed as shell code | T-141: fixed extraction regex | Closed |
| R-018 | T-143: YAML with colons breaks silently, Watchtower skips task | Invalid data disappears without error | L-048 recorded; needs schema validation | Acknowledged |
| R-019 | T-118: Agent defaults to workaround not investigation (3 instances) | Root causes hidden by premature workarounds | CLAUDE.md hypothesis-driven debugging, error-watchdog hook | Closed |

### Category 5: Tooling Fragility

Risks where framework tooling breaks silently or unpredictably.

| ID | Incident | Risk Statement | Control | Status |
|----|----------|---------------|---------|--------|
| R-020 | T-061: Plugins claim authority over CLAUDE.md rules | Third-party code overrides governance | T-062 precedence rules, T-063 hook, T-067 audit | Closed |
| R-021 | FP-003: PyYAML validator dependency conflicts | External dependencies create instability | T-026: use built-in validation | Closed |
| R-022 | FP-002: sed/grep/((x++)) bash parsing bugs | Shell utilities hide edge cases | L-007/L-008: patterns documented | Closed |
| R-023 | T-092+: Claude Code hooks require nested structure, flat fails silently | Enforcement disappears without error | T-063/T-092/T-118, MEMORY.md | Closed (fragile) |
| R-024 | T-143: YAML errors cause Watchtower to skip task silently | UI silently drops data | L-048; needs validation | Acknowledged |

### Category 6: Operational Loops

Risks where automation creates self-reinforcing failure cycles.

| ID | Incident | Risk Statement | Control | Status |
|----|----------|---------------|---------|--------|
| R-025 | FP-001: Task timestamp updates every commit → endless changes | Automation creates infinite loops | FP-001: only update active tasks | Closed |
| R-026 | L-016/E-004: Removing hook caused 97%→88% traceability drop in 5 commits | Single enforcement layer removal breaks system | L-016: defense-in-depth, proved experimentally | Closed |

### Category 7: Session/Memory Management

Risks specific to session boundaries and cross-session memory.

| ID | Incident | Risk Statement | Control | Status |
|----|----------|---------------|---------|--------|
| R-029 | L-043: Agent at 80% context never checked budget despite knowing rule | Procedural knowledge fails under pressure | L-043: check at every decision point; budget-gate blocks structurally | Closed |
| R-030 | L-025: 8 sub-agent dispatches across 96 tasks, result management ad-hoc | Sub-agent outputs uncontrolled | L-025: protocol + templates, fw bus (unused) | Closed |
| R-031 | L-014: Transcript cache across sessions, wrong session read at 177K | Session boundary state corruption | L-014: removed cache entirely | Closed |
| R-032 | T-191 inception: 5-10 sessions, 2-commit gate forces premature decisions | Deep exploration blocked by gate designed for short tasks | L-002 logged; bypass used; needs configurable threshold | Acknowledged |
| R-033 | T-151: Spec completed by agent in 2 min without human dialogue | Human-owned tasks auto-completed without human | T-194 inception, human-dialogue-mandatory decision | New |

### Category 8: Architecture

Risks from structural design choices.

| ID | Incident | Risk Statement | Control | Status |
|----|----------|---------------|---------|--------|
| R-034 | G-002: 6 statuses designed, refined/blocked had 0 uses after 50 tasks | Spec complexity unmatched by reality | T-051: simplified to 4, validated | Closed |
| R-035 | G-003: 11 template fields, priority/tags/agents.supporting unused | Unused complexity creates maintenance burden | T-052: removed unused fields | Closed |
| R-036 | G-004: Multi-agent spec, 188 tasks all single-owner | Coordination capability untested | Trigger: first multi-agent task | Watching |

### Category 9: Human Oversight

Risks where human review/approval is bypassed or absent.

| ID | Incident | Risk Statement | Control | Status |
|----|----------|---------------|---------|--------|
| R-037 | L-058: T-182 edited 4 core files without impact assessment | Framework changes made without blast radius analysis | L-058: show files/changes/risks, get approval | Closed |
| R-038 | L-026: Success patterns ad-hoc across 3+ tasks, never codified | Effective practices lost | L-026: operational reflection protocol | Closed |

## Key Patterns Across Risks

1. **Silent failures dominate** (R-005, R-014, R-018, R-019, R-023, R-024): 6 of 38 risks involve errors that produce no visible indication
2. **Structural enforcement > procedural rules** (R-003, R-029, R-033): When a rule exists only in CLAUDE.md without a hook/gate, it fails
3. **Defense-in-depth proven essential** (R-026): Removing one enforcement layer caused immediate measurable degradation
4. **Safety mechanisms create new risks** (R-007, R-008, R-025): Budget protection, auto-handover, and timestamp updates all created cascading loops
5. **Session boundaries are danger zones** (R-004, R-005, R-006, R-031): Cross-session state (caches, counters, transcripts) frequently corrupts
6. **Spec-reality gaps close through simplification** (R-034, R-035): Evidence-driven removal beats speculative complexity

## Open Risks (Not Fully Controlled)

| ID | Risk | Severity | What's needed |
|----|------|----------|--------------|
| R-002 | Behavior ACs falsely completed | High | T-193 implementation |
| R-003 | Inception gate bypass | Medium | Structural enforcement (not just rule) |
| R-010 | Research artifact loss | High | T-194 experiment (C-001/C-002/C-003) running |
| R-011 | Sub-agent output explosion | High | Structural enforcement of write-to-file |
| R-018 | YAML errors silent | Medium | Schema validation |
| R-024 | UI silently drops data | Medium | Schema validation |
| R-032 | Long inception gate conflict | Low | Configurable commit threshold |
| R-033 | Human-owned tasks auto-completed | High | T-194 human-dialogue mandate |
| R-036 | Multi-agent untested | Low | First real test |

## Open Questions for Phase 1b

1. Are these 9 risk categories the right taxonomy? Should we consolidate or split?
2. Should we formalize this as a risk register (with likelihood × impact scoring)?
3. Which open risks should be prioritized for control design?
4. Does `gaps.yaml` evolve into the risk register, or do we keep them separate?
