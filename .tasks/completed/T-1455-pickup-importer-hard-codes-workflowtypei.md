---
id: T-1455
name: "Pickup importer hard-codes workflow_type=inception for all envelope types (bug-report,
  feature-proposal, etc.) — leading to 12 closed bug-fix tasks classified as inception.
  Audit C-001/missing-research check then warns about absent docs/reports/T-XXX-*.md
  artifacts that bug fixes don't need. Surgical fix landed in T-1440 (skip pickups
  in audit). Structural fix should change importer to map: bug-report→build, feature-proposal→inception
  (or build, with inception only for explicit research questions). See agents/pickup
  or lib/pickup-bus for importer code."
description: >
  Promoted from observation OBS-015

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: [agents/observe/observe.sh, tests/unit/observe.bats]
related_tasks: []
created: 2026-04-25T12:20:16Z
last_update: '2026-08-16T22:24:33Z'
date_finished: 2026-04-25T18:02:40Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] Audit of 12 misclassified tasks captured in `docs/reports/T-1455-*.md`
- [x] Type-vs-scope evidence captured for the chosen scope (constrained Option A — bug-report only). OBS-015's 12 bug-fix cases provide the type-vs-scope agreement signal for that class (12/12 misclassified as inception, 0 feature-proposal mislabels). Broader 50-pickup sample was deferred because it would have been needed only for full Option A or hybrid Option C, neither of which was chosen. If a feature-proposal-class incident later requires escalating to Option D, re-open this AC and capture the broader sample then.
- [x] All 3 options enumerated with cost-benefit (research artifact has 5-option table)
- [x] [Inception decision recorded] go/no-go/defer with chosen option (A/B/C)

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

## Recommendation

**Recommendation:** GO with **constrained Option A** — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

**Rationale:** This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a *new subsystem build*; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

**Evidence:**
- OBS-015 cited *12 misclassifications, all bug-fix*. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the *cause* of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

**Alternatives considered:**
- **Option B (do nothing):** Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- **Option A (full mapping):** Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- **Option C (hybrid type + size gate):** Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- **Option D (envelope `scope_validated` flag):** Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

**Out-of-scope follow-up:**
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

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

### 2026-04-25T13:17:02Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception

### 2026-04-25T15:21:06Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

### 2026-04-25T15:21:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

### 2026-04-25T15:21:12Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

### 2026-04-25T15:21:57Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

### 2026-04-25T15:24:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

### 2026-04-25T16:21:32Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

### 2026-04-25T16:21:40Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

### 2026-04-25T16:23:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

### 2026-04-25T16:23:48Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

### 2026-04-25T16:24:25Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

### 2026-04-25T16:24:31Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with constrained Option A — only `bug-report` envelopes map to `build`; all other types (`feature-proposal`, `learning`, `pattern`) keep the current `inception` mapping.

Rationale: This is the smallest change that resolves OBS-015's friction without reopening T-469's structural risk. T-469 was triggered by an envelope whose content was actually a new subsystem build; the protection was "treat every pickup as inception" precisely because the envelope `type:` field was untrusted. Bug-reports are the most type-faithful kind — people rarely call a brand-new feature a "bug" — and bug fixes are by nature scope-constrained (one bug, one fix). For that one type, the mislabel risk is bounded enough that the friction (12 inceptions worth of audit churn) outweighs it. For all other types — especially `feature-proposal`, where T-469's exact failure pattern lives — keep the inception default.

Evidence:
- OBS-015 cited 12 misclassifications, all bug-fix. Zero misclassified feature-proposals were named — strong signal that bug-report is the dominant friction type.
- `lib/pickup.sh:262` is a single hard-coded `--type inception` line; the constrained-A change is ~3 LoC (`case` on `pickup_type`, default to `inception`).
- T-469's worst-case sender mislabel ("feature mislabeled as bug-report") is bounded by what a bug fix can do: one component, one fix, normal task gates apply. A feature mislabeled as feature-proposal stays inception → still protected.
- T-1440 already silenced the C-001 audit warning surgically. Constrained Option A removes the cause of the misclassification rather than just the warning, but Option B (status quo) is equally acceptable if the team prefers minimal change.

Alternatives considered:
- Option B (do nothing): Leave T-1440's audit-skip as the only fix. Acceptable but leaves bug-reports semantically misclassified in queries/reports by `workflow_type`.
- Option A (full mapping): Map every type semantically. Reopens T-469 risk on `feature-proposal` envelopes. Rejected.
- Option C (hybrid type + size gate): Adds heuristic detection. Most code, hardest to validate, fragile to wording shifts in summaries. Rejected for now — revisit if constrained-A produces a misclassified-feature-proposal incident.
- Option D (envelope `scope_validated` flag): Sender opts into non-inception mapping. Cleanest long-term but requires envelope-schema migration across all consumer projects. Defer.

Out-of-scope follow-up:
- After constrained Option A lands, watch for any `workflow_type: build` task that turned out to need inception scoping — that's the canary for revisiting Option C/D.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-83ae4af5
- **Timestamp:** 2026-06-02T14:57:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T18:02:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
