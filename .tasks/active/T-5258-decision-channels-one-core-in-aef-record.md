---
id: T-5258
name: "Decision channels: one core in AEF (record-a-decision function, one-time signed
  decision keys, per-decision channel rules) with optional channel modules (Watchtower
  page default; ntfy tap-to-approve, email, chat as plug-ins), so other AEF users
  can plug in their own routes"
description: >
  Inception: Decision channels: one core in AEF (record-a-decision function, one-time
  signed decision keys, per-decision channel rules) with optional channel modules
  (Watchtower page default; ntfy tap-to-approve, email, chat as plug-ins), so other
  AEF users can plug in their own routes

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
step_entered_at: '2026-11-19T14:57:37Z'
waiting_on: agent
revisit_at: 2026-11-26
created: 2026-11-19T14:57:07Z
last_update: 2026-11-19T14:57:37Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-11-19T14:57:16Z'
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

# T-5258: Decision channels: one core in AEF (record-a-decision function, one-time signed decision keys, per-decision channel rules) with optional channel modules (Watchtower page default; ntfy tap-to-approve, email, chat as plug-ins), so other AEF users can plug in their own routes

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

Operator decisions in AEF are recorded in one place only: the Watchtower page (`/api/approvals/decide`). Notifications (lib/notify.sh, ntfy) can carry only a link that opens that page. ring20 built tap-to-approve on top: ntfy action buttons carry a one-time HMAC-signed key, and a `tap_decide` route records the decision (their T-2765 answer to T-4649, msg b1961c86). It lives as a local change in their vendored copy and is tied to ntfy.

The operator, 2026-11-19 (T-4649 walkthrough): AEF has other users, who may have no ntfy, so this must be optional, with different routes that can be plugged in: "we need to have a module system there". Proposed shape (agent, agreed in principle by the operator): a core in AEF (one record-a-decision function used by every route, the same ledger row and Tier 0 handling as the page; one-time signed decision keys bound to request, decision and expiry; a per-decision rule naming which channels may decide it) and channel modules that only deliver and hand a key back, never record a decision themselves. The Watchtower page stays the default; a project with no modules works as today; one-way alerts are kept separate from two-way deciding channels. ring20's ntfy version becomes the first module.

Under the operator's T-4649 principle, a project's operator chooses its modules and rules, recorded and shown by `fw audit`, and upgrades must not break them.

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

- **IW-1: The core: what does one record-a-decision function need so every route (page, tap, email, chat) produces the same ledger row and Tier 0 handling, and refuses unknown, expired or reused requests?**
- **IW-2: The module contract: what does a channel module implement (send a request with its decision options; return a tap or click as a key), how is it registered per project, and how are one-way alert modules kept apart from two-way deciding ones?**
- **IW-3: Keys and rules: how are one-time decision keys signed, bound and expired, and how does a project's operator set which decision kinds a channel may decide (for example Tier 0 and irreversible actions only on the page)?**
- **IW-4: First module and reach: does ring20's ntfy tap-to-approve fit the contract unchanged, how does a phone reach Watchtower (LAN, VPN), and which form-safety exemption does a tap address need?**

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

Operator 2026-11-19 (T-4649 walkthrough): other AEF users may have no ntfy, so it must be optional with pluggable routes, 'we need to have a module system there'. ring20's tap-to-approve (tap_decide route, HMAC single-use bearer, ntfy Actions header, approval_channel.py) is the first module and their evidence. Today AEF notifications carry only a click link (lib/notify.sh), and decisions are recorded only through /api/approvals/decide. Split from T-4649 as its own design.

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

### 2026-11-19T14:57:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-19T14:57:37Z — inception-wait [inception-lifecycle]
- **Change:** waiting_on: agent → agent
- **Revisit:** 2026-11-26
