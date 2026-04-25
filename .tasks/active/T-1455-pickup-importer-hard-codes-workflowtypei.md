---
id: T-1455
name: "Pickup importer hard-codes workflow_type=inception for all envelope types (bug-report, feature-proposal, etc.) — leading to 12 closed bug-fix tasks classified as inception. Audit C-001/missing-research check then warns about absent docs/reports/T-XXX-*.md artifacts that bug fixes don't need. Surgical fix landed in T-1440 (skip pickups in audit). Structural fix should change importer to map: bug-report→build, feature-proposal→inception (or build, with inception only for explicit research questions). See agents/pickup or lib/pickup-bus for importer code."
description: >
  Promoted from observation OBS-015

status: captured
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-25T12:20:16Z
last_update: 2026-04-25T12:20:16Z
date_finished: null
---

# T-1455: Pickup importer hard-codes workflow_type=inception for all envelope types (bug-report, feature-proposal, etc.) — leading to 12 closed bug-fix tasks classified as inception. Audit C-001/missing-research check then warns about absent docs/reports/T-XXX-*.md artifacts that bug fixes don't need. Surgical fix landed in T-1440 (skip pickups in audit). Structural fix should change importer to map: bug-report→build, feature-proposal→inception (or build, with inception only for explicit research questions). See agents/pickup or lib/pickup-bus for importer code.

## Problem Statement

**For whom:** Agents importing pickup envelopes from other projects (TermLink dispatch, fw pickup process). **What problem:** the importer at `lib/pickup.sh:262` hard-codes `--type inception` for every envelope kind. **Why now:** OBS-015 reports 12 bug-fix tasks misclassified as inception, triggering C-001 missing-research warnings (T-1440 silenced the warning surgically; structural fix still missing).

## Tension with T-469 (the reason for the hard-code)

T-469 (closed 2026-03-12) established force-inception precisely BECAUSE an agent treated a pickup message as a build instruction and shipped 4 framework-source files without scoping. The hard-code is a deliberate guard: "any pickup MUST go through inception before becoming work." Reverting that guard by mapping `bug-report→build` brings back the same risk class — a pickup labeled "bug-report" might actually request building a new subsystem (mislabel by sender), and the guard is the only structural backstop.

So the question is NOT "should we map types?" but "what's the safe shape of the mapping rule, given T-469's lesson?"

## Hypotheses to test

1. **Type-trust hypothesis:** Sender-declared `type:` is reliable enough that we can map directly (bug-report→build, feature-proposal→inception). Test: review last 50 pickups — how often did `type` match the actual scope of work?
2. **Size-gate hypothesis:** Type alone is insufficient; we should gate on envelope size/scope signals (file count, "build a new subsystem" keywords). Test: compare type vs realized scope on the 12 misclassified tasks.
3. **Hybrid hypothesis:** bug-report→build is safe because bug-fixes are by nature constrained (one bug = one fix); feature-proposal stays inception. Test: any historical bug-report pickup that grew beyond bug-fix scope?

## Exploration Plan

1. Audit the 12 closed bug-fix tasks misclassified as inception (referenced in OBS-015) — were they correctly bug-shaped, or did any morph into bigger work?
2. Sample last 50 pickup envelopes — agreement between declared `type` and actual realized work.
3. Map the design space:
   - Option A: per-type mapping (bug-report→build, feature-proposal→inception, learning→learning, pattern→pattern)
   - Option B: keep force-inception, fix C-001 audit instead (already done in T-1440 — leaves importer untouched)
   - Option C: Hybrid — per-type default + size override (small bugfix → build, big feature → inception)
4. Decision criterion: which option preserves T-469's protection while removing OBS-015's friction?

## Expected outcome

A go/no-go decision recorded on `/inception/T-1455` selecting one of A/B/C, with a build task spawned for the chosen option.

## Acceptance Criteria

### Agent
- [ ] Audit of 12 misclassified tasks captured in `docs/reports/T-1455-*.md`
- [ ] Sample of last 50 pickups + type-vs-scope agreement table captured
- [ ] All 3 options enumerated with cost-benefit
- [ ] [Inception decision recorded] go/no-go/defer with chosen option (A/B/C)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-25T12:20:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1455-pickup-importer-hard-codes-workflowtypei.md
- **Context:** Initial task creation
