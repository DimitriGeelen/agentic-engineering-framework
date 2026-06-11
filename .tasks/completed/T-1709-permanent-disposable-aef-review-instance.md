---
id: T-1709
name: "Permanent disposable AEF review instance at /opt/ttt-AEF-Review-instance —
  TermLink-driven test bench for human-AC reviews + install/upgrade flow testing"
description: >
  Permanent disposable AEF review instance at /opt/ttt-AEF-Review-instance — TermLink-driven
  test bench for human-AC reviews + install/upgrade flow testing

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-04T05:21:06Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-04T07:12:24Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
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
---

# T-1709: Permanent disposable AEF review instance at /opt/ttt-AEF-Review-instance — TermLink-driven test bench for human-AC reviews + install/upgrade flow testing

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
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
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

Two convergent reasons:

1. **It closes a real recurring blind spot.** Three tasks shipped this session (T-1700, T-1702, T-1707) all carry Human ACs the agent here structurally cannot verify (path isolation + sovereignty). Without a review instance, every one of those is "hand off and wait" with no way for the agent to do the legwork while the human stays the decider. The pattern repeats on every framework-internal change touching paths/hooks/install flow. T-1635 (fresh-machine install simulation) hand-waves on "should test in clean container" because there is no permanent rig. T-1709 makes the rig.

2. **It closes the T-1442/T-1443 wiring gap.** Those inceptions reached GO with explicit confirmed-yes for *"Reviewer agent may auto-tick Agent ACs"* and *"TermLink-dispatched, evidence-gated reviewer."* What shipped: in-process verdict-writer with hard-coded "NEVER modifies AC checkboxes" guard. The auto-tick + TermLink-dispatch halves never wired. T-1709 is precisely that wiring — same authority, same policy files (`policy/escalation-patterns.yaml`, `policy/anti-patterns.yaml`), TermLink runs in the review instance which is the structurally clean place for it to live.

**Evidence:**

- Inception artifact: `docs/reports/T-1709-aef-review-instance.md` — full grill log (10 questions across 2 rounds, all answered or verified-as-prior-decided), steelman/strawman vs 4 directives for Q9, locked design synthesis (5 sections).
- Prior-work verification: T-1442 + T-1443 both `work-completed`; `lib/reviewer/static_scan.py` ships with explicit "NEVER modifies AC checkboxes" comment; `agents/reviewer/` does not exist; auto-tick + TermLink-dispatch halves of GO never wired. User claim verified.
- 7 build tasks decomposed in `## Locked design — D. Implementation sequence` of the artifact. Bounded; first 3 (instance init/shred/dispatch CLI) are foundational, next 3 (reviewer extension + auto-tick + log) extend existing code, final 1 is the T-1710 spinoff.
- Q1 (b) two instances; Q2 (c with carve-outs); Q3-5 agent-judgment; Q6 spun out as T-1710; Q7 already-decided (3-layer classifier shipped); Q8 already-decided (extension, not replacement); Q9 review→clone+SHA, test→GitHub mirror; Q10 ladder maps onto Error Escalation Ladder doctrine.
- Spinoff already filed: T-1710 (failure-mode discrimination — canary vs broken instance).

**Risk acknowledged:**

- Auto-tick is a one-way door if Q10 ladder isn't built before tick is enabled. Mitigation: build sequence puts log + cron + ladder in steps 5-6 BEFORE tick is allowed in step 4. Auto-tick flag stays off until cron + log are in place.
- Drift between policy files and reviewer behaviour. Mitigation: existing `fw reviewer audit` Pass A/B daily already covers this surface.
- Two more `/opt/ttt-*` directories to maintain. Acceptable cost — neither is git-tracked, both are shred-and-reinit, drift is bounded.

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

**Rationale**: Recommendation: GO

Rationale:

Two convergent reasons:

1. It closes a real recurring blind spot. Three tasks shipped this session (T-1700, T-1702, T-1707) all carry Human ACs the agent here structurally cannot verify (path isolation + sovereignty). Without a review instance, every one of those is "hand off and wait" with no way for the agent to do the legwork while the human stays the decider. The pattern repeats on every framework-internal change touching paths/hooks/install flow. T-1635 (fresh-machine install simulation) hand-waves on "should test in clean container" because there is no permanent rig. T-1709 makes the rig.

2. It closes the T-1442/T-1443 wiring gap. Those inceptions reached GO with explicit confirmed-yes for "Reviewer agent may auto-tick Agent ACs" and "TermLink-dispatched, evidence-gated reviewer." What shipped: in-process verdict-writer with hard-coded "NEVER modifies AC checkboxes" guard. The auto-tick + TermLink-dispatch halves never wired. T-1709 is precisely that wiring — same authority, same policy files (`policy/escalation-patterns.yaml`, `policy/anti-patterns.yaml`), TermLink runs in the review instance which is the structurally clean place for it to live.

Evidence:

- Inception artifact: `docs/reports/T-1709-aef-review-instance.md` — full grill log (10 questions across 2 rounds, all answered or verified-as-prior-decided), steelman/strawman vs 4 directives for Q9, locked design synthesis (5 sections).
- Prior-work verification: T-1442 + T-1443 both `work-completed`; `lib/reviewer/static_scan.py` ships with explicit "NEVER modifies AC checkboxes" comment; `agents/reviewer/` does not exist; auto-tick + TermLink-dispatch halves of GO never wired. User claim verified.
- 7 build tasks decomposed in `## Locked design — D. Implementation sequence` of the artifact. Bounded; first 3 (instance init/shred/dispatch CLI) are foundational, next 3 (reviewer extension + auto-tick + log) extend existing code, final 1 is the T-1710 spinoff.
- Q1 (b) two instances; Q2 (c with carve-outs); Q3-5 agent-judgment; Q6 spun out as T-1710; Q7 already-decided (3-layer classifier shipped); Q8 already-decided (extension, not replacement); Q9 review→clone+SHA, test→GitHub mirror; Q10 ladder maps onto Error Escalation Ladder doctrine.
- Spinoff already filed: T-1710 (failure-mode discrimination — canary vs broken instance).

Risk acknowledged:

- Auto-tick is a one-way door if Q10 ladder isn't built before tick is enabled. Mitigation: build sequence puts log + cron + ladder in steps 5-6 BEFORE tick is allowed in step 4. Auto-tick flag stays off until cron + log are in place.
- Drift between policy files and reviewer behaviour. Mitigation: existing `fw reviewer audit` Pass A/B daily already covers this surface.
- Two more `/opt/ttt-` directories to maintain. Acceptable cost — neither is git-tracked, both are shred-and-reinit, drift is bounded.

**Date**: 2026-05-04T07:12:24Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-04T05:21:45Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-04T07:12:24Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

Two convergent reasons:

1. It closes a real recurring blind spot. Three tasks shipped this session (T-1700, T-1702, T-1707) all carry Human ACs the agent here structurally cannot verify (path isolation + sovereignty). Without a review instance, every one of those is "hand off and wait" with no way for the agent to do the legwork while the human stays the decider. The pattern repeats on every framework-internal change touching paths/hooks/install flow. T-1635 (fresh-machine install simulation) hand-waves on "should test in clean container" because there is no permanent rig. T-1709 makes the rig.

2. It closes the T-1442/T-1443 wiring gap. Those inceptions reached GO with explicit confirmed-yes for "Reviewer agent may auto-tick Agent ACs" and "TermLink-dispatched, evidence-gated reviewer." What shipped: in-process verdict-writer with hard-coded "NEVER modifies AC checkboxes" guard. The auto-tick + TermLink-dispatch halves never wired. T-1709 is precisely that wiring — same authority, same policy files (`policy/escalation-patterns.yaml`, `policy/anti-patterns.yaml`), TermLink runs in the review instance which is the structurally clean place for it to live.

Evidence:

- Inception artifact: `docs/reports/T-1709-aef-review-instance.md` — full grill log (10 questions across 2 rounds, all answered or verified-as-prior-decided), steelman/strawman vs 4 directives for Q9, locked design synthesis (5 sections).
- Prior-work verification: T-1442 + T-1443 both `work-completed`; `lib/reviewer/static_scan.py` ships with explicit "NEVER modifies AC checkboxes" comment; `agents/reviewer/` does not exist; auto-tick + TermLink-dispatch halves of GO never wired. User claim verified.
- 7 build tasks decomposed in `## Locked design — D. Implementation sequence` of the artifact. Bounded; first 3 (instance init/shred/dispatch CLI) are foundational, next 3 (reviewer extension + auto-tick + log) extend existing code, final 1 is the T-1710 spinoff.
- Q1 (b) two instances; Q2 (c with carve-outs); Q3-5 agent-judgment; Q6 spun out as T-1710; Q7 already-decided (3-layer classifier shipped); Q8 already-decided (extension, not replacement); Q9 review→clone+SHA, test→GitHub mirror; Q10 ladder maps onto Error Escalation Ladder doctrine.
- Spinoff already filed: T-1710 (failure-mode discrimination — canary vs broken instance).

Risk acknowledged:

- Auto-tick is a one-way door if Q10 ladder isn't built before tick is enabled. Mitigation: build sequence puts log + cron + ladder in steps 5-6 BEFORE tick is allowed in step 4. Auto-tick flag stays off until cron + log are in place.
- Drift between policy files and reviewer behaviour. Mitigation: existing `fw reviewer audit` Pass A/B daily already covers this surface.
- Two more `/opt/ttt-` directories to maintain. Acceptable cost — neither is git-tracked, both are shred-and-reinit, drift is bounded.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e2d11214
- **Timestamp:** 2026-06-02T14:59:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-04T07:12:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
