---
id: T-5248
name: "Upgrade feedback loop: every fw upgrade writes a report (what changed, local edits found, health before and after, failures) that comes back to AEF — full over the sidecar for our own projects, an opt-in cleaned-up summary on GitHub for outside users"
description: >
  Inception: Upgrade feedback loop: every fw upgrade writes a report (what changed, local edits found, health before and after, failures) that comes back to AEF — full over the sidecar for our own projects, an opt-in cleaned-up summary on GitHub for outside users

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
step_entered_at: '2026-11-19T10:58:35Z'
waiting_on: agent
revisit_at: 2026-11-26
created: 2026-11-19T10:57:59Z
last_update: 2026-11-19T10:58:35Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
---

# T-5248: Upgrade feedback loop: every fw upgrade writes a report (what changed, local edits found, health before and after, failures) that comes back to AEF — full over the sidecar for our own projects, an opt-in cleaned-up summary on GitHub for outside users

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

AEF learns how an upgrade went in a consumer project only when that project happens to tell us (ring20's list of 27 in-file patches reached us by message; 055's outage from a locally edited gate likewise). `fw upgrade` prints what it did and keeps nothing: no report is written, and the `aef-upgrade-report` message type in lib/message_router.py is deferred. So we cannot see, across projects, which upgrades failed, which health checks got worse, or which framework files projects keep changing locally, which is the demand signal for T-4649's extension points.

Operator, 2026-11-19 (T-4649 walkthrough): build in a feedback loop for every project that upgrades and get the reports back, perhaps by sending them to GitHub and collecting them from there, "and that's then really your feedback also for other things ... but maybe that's increasing our scope too much". Filed separately from T-4649 for that reason; operator: "yes, send the consultation and file the inception".

Constraint: GitHub is public. No paths, host details, project names or secrets go there.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: What does an upgrade report hold: versions before and after, files changed, local edits found or preserved (T-4870), `fw doctor` before and after, failures and their messages?**
- **IW-2: How does it come back: full report over the sidecar for our own projects; for outside users an opt-in, cleaned-up summary to GitHub (or email), collected with `fw issues`? What exactly is removed before anything leaves the project?**
- **IW-3: What does AEF do with the reports: a per-release view of upgrade outcomes, a list of framework files that projects keep changing locally (input to T-4649), and follow-up tasks for failures?**
- **IW-4: Consent and control: is sending on by default for our own projects and off by default for outside users, and how does a project see exactly what would be sent before it goes?**

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
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** EXPLORING

**Rationale:**

Operator idea 2026-11-19 during the T-4649 walkthrough: get feedback back from every project that upgrades, possibly via GitHub, flagged by the operator as possibly too much scope for T-4649, so filed separately. Today fw upgrade writes no report (screen output only; an aef-upgrade-report message type in lib/message_router.py is deferred). The most useful content for T-4649 is which vendored files a project had changed locally. Constraint: GitHub is public, so no paths, host details or project names go there.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-19T10:58:35Z — inception-wait [inception-lifecycle]
- **Change:** waiting_on: agent → agent
- **Revisit:** 2026-11-26
