---
id: T-325
name: "Actionable human AC handoffs — enforce quality, surface pending reviews"
description: >
  Human ACs have 50% completion rate when vague vs 95% when specific. Two gaps: (1) ACs lack
  executable steps, (2) no proactive notification when human action is needed. Explore enforcement
  and surfacing mechanisms.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [governance, ux, handoff]
components: [agents/task-create/update-task.sh, agents/handover/handover.sh, agents/task-create/create-task.sh]
related_tasks: [T-193, T-285, T-289]
created: 2026-03-04T23:51:59Z
last_update: 2026-03-04T23:55:00Z
date_finished: null
---

# T-325: Actionable human AC handoffs — enforce quality, surface pending reviews

## Problem Statement

Human acceptance criteria are written as outcome statements ("verify X works") not executable instructions. Evidence from 46 tasks: vague ACs complete at 50%, specific ACs at 95%. Tasks pile up for 72h+ triggering D2 audit failures. The agent-to-human handoff assumes context the human no longer has.

Two gaps:
1. **Actionability** — ACs lack commands, URLs, expected output, failure steps
2. **Discoverability** — No proactive notification; human must visit Watchtower to find pending work

## Assumptions

- A-1: Enforcing a `Steps:` block in human ACs will improve completion rates
- A-2: Surfacing pending human ACs at session start will reduce D2 staleness
- A-3: Confidence signaling (rubber-stamp vs genuine review) will help humans prioritize
- A-4: Watchtower UI is sufficient — CLI/handover/resume are the real gaps

## Exploration Plan

1. **Spike 1: Template + CLAUDE.md rule change** (30 min)
   - Draft new human AC format with required `Steps:` block
   - Draft CLAUDE.md rule for writing actionable human ACs
   - Validate against 5 existing tasks: would it have helped?

2. **Spike 2: Enforcement gate prototype** (30 min)
   - Prototype P-010 extension: regex check for commands/URLs in human ACs
   - Test: does it catch vague ACs without false positives on good ones?

3. **Spike 3: Surfacing mechanisms** (30 min)
   - Add `fw task list --needs-human-verification` CLI
   - Add pending human ACs to resume output
   - Add "Human Actions Required" section to handover generation

4. **Spike 4: Confidence signal** (15 min)
   - Define rubber-stamp vs genuine-review markers
   - Draft syntax for task files

## Technical Constraints

- Must not break existing tasks (backward compatible)
- P-010 gate changes must fail open (warn, not block) for existing tasks without Steps blocks
- Handover changes must not bloat the document significantly

## Scope Fence

**IN scope:**
- Human AC format requirements (template, CLAUDE.md)
- P-010 gate extension (quality check)
- CLI/handover/resume surfacing
- Confidence signaling design

**OUT of scope:**
- Email/webhook/external notifications (separate task if needed)
- Watchtower UI changes (already has "Awaiting Verification")
- Retroactive fixing of all existing human ACs

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Template change demonstrably improves AC actionability on 3+ real examples
- Enforcement gate has <10% false positive rate on existing good ACs
- Surfacing mechanisms can be built in <2h total

**NO-GO if:**
- Format enforcement creates friction without measurable improvement
- Existing human AC patterns are too diverse to standardize
- The real problem is notification (out of scope), not quality

## Verification

# Research artifact exists (C-001)
test -f docs/reports/T-325-human-ac-handoff-quality.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives. -->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

### 2026-03-05T00:00:00Z — inception-start
- **Action:** Created inception with 4-agent research phase
- **Findings:** 46 tasks analyzed, clear correlation between AC specificity and completion rate
- **Research artifact:** docs/reports/T-325-human-ac-handoff-quality.md
