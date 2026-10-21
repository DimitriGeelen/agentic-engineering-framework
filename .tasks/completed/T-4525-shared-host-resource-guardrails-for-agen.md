---
id: T-4525
name: "Shared-host resource guardrails for agents (dimitri-mint-dev T-162: Shared
  host section, fw run-heavy, FW_PROJECT/FW_TASK attribution, host PSI canary, cleanup
  on every path)"
description: >
  Inception: Shared-host resource guardrails for agents (dimitri-mint-dev T-162: Shared
  host section, fw run-heavy, FW_PROJECT/FW_TASK attribution, host PSI canary, cleanup
  on every path)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-10-21T08:59:47Z
last_update: 2026-10-21T09:10:53Z
date_finished: 2026-10-21T09:10:53Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-10-21T09:00:24Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=120,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-21T09:00:42Z'
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

# T-4525: Shared-host resource guardrails for agents (dimitri-mint-dev T-162: Shared host section, fw run-heavy, FW_PROJECT/FW_TASK attribution, host PSI canary, cleanup on every path)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

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

- **IW-1: Which of P1-P5 does AEF take, in what order?**
  confidence: 2
  disposition: answered
  rationale: P1 (Shared host section in the CLAUDE.md template) and P3 (FW_PROJECT/FW_TASK exported into agent-run commands) first: small, no new mechanism, field-testable at once by dimitri-mint-dev; then P2 (fw run-heavy, systemd-run scope with CPUQuota/MemoryMax/IOWeight/RuntimeMaxSec and an attributable unit name) and P5 (EXIT-trap cleanup generalised, doctor reports this project's old /tmp entries); P4 (host PSI canary naming the owning project) last, since attribution comes from P3. Source: docs/reports/T-4525-inputs/dimitri-mint-dev-T-162-message.txt.
- **IW-2: Is the nproc/4 default cap right for every host, or should it be a config key with that default?**
  confidence: 1
  disposition: deferred
  rationale: A config key (default nproc/4) keeps single-tenant hosts unrestricted by choice; to settle in the P1 build task.
- **IW-3: Does P2 work where systemd user scopes are unavailable (containers, macOS, root without a user session)?**
  confidence: 1
  disposition: deferred
  rationale: Needs a fallback (nice/ionice/timeout/prlimit) and an honest message when quotas cannot be applied; to settle in the P2 build task.

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

Six incidents of one class on the shared host (latest 2026-10-21: an 832 load test took all 24 cores for 39 minutes, found only by process cwd). Root causes are structural: each agent sees only its project, nothing caps CPU/IO/memory/time by default, processes are not attributable, detection is a human feeling lag. Recommend GO on P1 (Shared host section in the CLAUDE.md template) and P3 (FW_PROJECT/FW_TASK exported into agent-run commands) first: small, no new mechanism, field-testable on the host at once; then P2 (fw run-heavy as a systemd-run scope with quotas, deadline and an attributable unit name) and P5 (EXIT-trap cleanup generalised, doctor reports this project's old /tmp entries); P4 (host PSI canary naming the owning project) last, as it needs P3's attribution. Operator of the proposing project rates it high priority and high value.

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

**Decision**: GO

**Rationale**: Six incidents of one class on the shared host (latest 2026-10-21: an 832 load test took all 24 cores for 39 minutes, found only by process cwd). Root causes are structural: each agent sees only its project, nothing caps CPU/IO/memory/time by default, processes are not attributable, detection is a human feeling lag. Recommend GO on P1 (Shared host section in the CLAUDE.md template) and P3 (FW_PROJECT/FW_TASK exported into agent-run commands) first: small, no new mechanism, field-testable on the host at once; then P2 (fw run-heavy as a systemd-run scope with quotas, deadline and an attributable unit name) and P5 (EXIT-trap cleanup generalised, doctor reports this project's old /tmp entries); P4 (host PSI canary naming the owning project) last, as it needs P3's attribution. Operator of the proposing project rates it high priority and high value.

**Date**: 2026-10-21T09:10:53Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-21T09:07:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-21T09:10:53Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Six incidents of one class on the shared host (latest 2026-10-21: an 832 load test took all 24 cores for 39 minutes, found only by process cwd). Root causes are structural: each agent sees only its project, nothing caps CPU/IO/memory/time by default, processes are not attributable, detection is a human feeling lag. Recommend GO on P1 (Shared host section in the CLAUDE.md template) and P3 (FW_PROJECT/FW_TASK exported into agent-run commands) first: small, no new mechanism, field-testable on the host at once; then P2 (fw run-heavy as a systemd-run scope with quotas, deadline and an attributable unit name) and P5 (EXIT-trap cleanup generalised, doctor reports this project's old /tmp entries); P4 (host PSI canary naming the owning project) last, as it needs P3's attribution. Operator of the proposing project rates it high priority and high value.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a5e6193b
- **Timestamp:** 2026-10-21T09:10:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-34b50b1a
- **Timestamp:** 2026-10-21T09:10:55Z
- **Overall:** UNVERIFIED
- **Claims:** 0
- No verifiable claims found in ## Recommendation

### 2026-10-21T09:10:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
