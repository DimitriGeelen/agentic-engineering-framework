# T-372: Blind Task Completion Anti-Pattern Investigation

## Problem

An agent suggested batch-closing 12 human-owned tasks using `--force` without reviewing their Human acceptance criteria. The sovereignty gate (R-033) blocked execution, but nothing prevented the suggestion.

## Root Cause

**Asymmetric gates.** Four execution gates exist and work:
1. R-033 Sovereignty Gate (update-task.sh:201-217) — blocks `work-completed` for `owner: human`
2. P-010 AC Gate (update-task.sh:219-318) — blocks on unchecked Agent ACs; reports Human ACs
3. T-193 Partial-Complete (update-task.sh:552-559) — keeps partial tasks in active/
4. CLAUDE.md Autonomous Mode Boundaries — documents the prohibition

All fire on **execution** (tool invocation). None fire on **proposal** (reasoning/suggestion).

## Harm Assessment

| Task | Human AC Type | Harm if Skipped |
|------|--------------|-----------------|
| T-289 | RUBBER-STAMP (SSH key + pipeline test) | HIGH — prod pipeline untested |
| T-331 | RUBBER-STAMP (test in CI) | HIGH — untested public action |
| T-336/337/338 | Tone [x] + Publish [ ] | MEDIUM — tone passed, publish pending |
| T-339/362 | None (inception) | NONE — decisions recorded |
| T-361/365 | RUBBER-STAMP (visual QA) | LOW-MEDIUM — UX unchecked |
| T-364 | RUBBER-STAMP (spot-check 3 docs) | HIGH — 127 docs quality unchecked |
| T-366 | REVIEW (AI tone/accuracy) | HIGH — public-facing content |
| T-371 | RUBBER-STAMP (register hook) | LOW — advisory loop disabled |

4 blocking, 3 medium, 3 low, 2 none.

## Mitigations

### Sprint 1 (Immediate — closes the loop)
- **A1+A2:** CLAUDE.md blind-completion anti-pattern rule + autonomous boundary expansion
- **B1:** Handover surfaces unchecked Human ACs
- **C1:** `fw task verify T-XXX` query command

### Sprint 2 (Short-term — adds friction + visibility)
- **B2:** PostToolUse advisory hook on `--force` proposals
- **C2:** Audit discovery for partial-complete aging

### Sprint 3 (Long-term — architectural, if incidents recur)
- **D1:** Explicit `partial-complete` state
- **D2:** File-based approval artifact protocol

## T-373 Refinement

T-372 overcorrected: "never suggest closing human tasks." The correct rule (per human feedback):
- Suggesting closure is fine **IF you provide evidence** that Human ACs are satisfied
- Suggesting the human prioritize verification is fine **IF there's a reason** (blocking other work, aging)
- What's prohibited: suggesting closure **without evidence** — that's asking the human to skip validation

Root cause was not "suggesting closure" but "suggesting closure without evidence of validation."

## Gap Registration

New gap: G-017 — "Execution gates do not cover proposal/suggestion layer"

## Evidence Base

- Agent 1 report: `/tmp/fw-agent-human-ac-audit.md`
- Agent 2 report: `/tmp/fw-agent-gate-analysis.md`
- Agent 3 report: `/tmp/fw-agent-mitigation-design.md`
