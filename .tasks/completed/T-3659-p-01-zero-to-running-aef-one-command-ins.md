---
id: T-3659
name: "P-01 Zero-to-running AEF: one-command install (Claude Code + framework + deps),
  onboarding skipped, desktop icon starting Watchtower and a governed claude-fw session;
  Windows via WSL"
description: >
  Inception: P-01 Zero-to-running AEF: one-command install (Claude Code + framework
  + deps), onboarding skipped, desktop icon starting Watchtower and a governed claude-fw
  session; Windows via WSL

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [agents/task-create/create-task.sh, lib/inception.sh, lib/task_origin.py, tests/unit/t3897_create_task_origin.bats, tests/web/test_t3897_task_origin.py, web/blueprints/approvals.py, web/templates/_approvals_content.html, web/templates/_origin_badge.html]
related_tasks: []
origin: {kind: "proposal", source: "P-01 (external, unratified, 2026-09-29)", ref: "pasted by the operator 2026-10-01"}
created: 2026-10-01T15:01:12Z
last_update: 2026-10-05T22:30:48Z
date_finished: 2026-10-05T22:30:48Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-10-01T15:08:13Z'
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
cost_estimate_proposed:
  - ts: '2026-10-01T15:15:19Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=143,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-05T19:45:17Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=158,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3659: P-01 Zero-to-running AEF: one-command install (Claude Code + framework + deps), onboarding skipped, desktop icon starting Watchtower and a governed claude-fw session; Windows via WSL

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Skip onboarding for everyone, or offer "guided vs quickstart" at install?** Recommendation: both, with quickstart as the default, but only together with IW-3, so the governance gates are met rather than skipped.
  confidence: 2
  disposition: answered
  rationale: Offer both; quickstart is the default, and it ships only with IW-3's goal+first-task step, so the onboarding gates are satisfied rather than skipped. The operator's GO on this inception adopts it.

- **IW-2: WSL distros often default to root: accept it, or have install.ps1 create a normal user?** Recommendation: create a normal user (root amplified the T-2787/T-3610 leaks and hides permission bugs).
  confidence: 2
  disposition: answered
  rationale: install.ps1 creates a normal user, because running as root amplified the T-2787/T-3610 leaks and hides permission bugs (P-01 report, WSL findings). The operator's GO adopts it.

- **IW-3: Should the installer ask for the project goal and create the first task with ACs?** Recommendation: yes. Write objectives.yaml (T-3535/T-3636) and the first task via `fw work-on --ac` (T-3664).
  confidence: 2
  disposition: answered
  rationale: Yes. The installer asks for the goal, writes objectives.yaml (T-3535/T-3636) and creates the first task with ACs via fw work-on --ac (T-3664), so a quickstart project starts governed. The operator's GO adopts it.

- **IW-4: Where does the kit live: the framework repo under install/, or a separate quickstart repo?** Recommendation: the framework repo under install/, versioned and released with the framework (a separate repo drifts, as 055's stale vendored copy shows).
  confidence: 3
  disposition: answered
  rationale: The framework repo under install/, versioned and released with the framework. A separate repo drifts, as 055's stale vendored copy (1.7.825 while AEF shipped 1.8.x) shows.

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

Instrumented evidence on one Windows 10 machine (framework 1.7.0 @29f3b02): documented native Git Bash route 15m51s and blocked (Watchtower cannot start, doctor exit 1); WSL by hand 1m49s with ~10 manual fixes; P-01 Install-AEF.ps1 127s with 0 manual fixes, two projects side by side on :3000/:3001. 57 findings, each mapped to a P-01 workaround. GO on the landing shape (installer quickstart mode + install.ps1 + framework fixes that retire workarounds); the four open questions are design choices with recommendations in the artifact, not evidence gaps.

**What your GO adopts:**
- IW-1: the installer offers guided and quickstart, with quickstart as the default, and only together with IW-3.
- IW-2: install.ps1 creates a normal (non-root) user.
- IW-3: the installer asks for the project goal and creates the first task with acceptance criteria.
- IW-4: the kit lives in the framework repo under `install/`, released with the framework.

Each is recorded as an answered disposition above. A NO-GO rejects the installer route, and the seven defect tasks below stand on their own either way.

**Evidence:**
- Research artifact: `docs/reports/T-3659-p01-zero-to-running.md`. The source is the external proposal "P-01 — Zero-to-running AEF" (2026-09-29, unratified), pasted by the operator on 2026-10-01.
- Measured on Windows 10, framework 1.7.0:
  - native Git Bash: 15m51s, blocked;
  - WSL by hand: 1m49s with ~10 fixes;
  - P-01 Install-AEF.ps1: 127s with 0 fixes.
- 57 findings. The defects are filed independently of this decision: T-3660, T-3661, T-3662, T-3663, T-3664, T-3665 (CRLF silently disables the secret scan) and T-3666.
- State on 2026-10-05:
  - shipped: T-3660 (watchtower detach), T-3661 (status exit codes) and T-3665 (CRLF secret scan);
  - T-3662 (per-project port) is done and awaiting review;
  - T-3663, T-3664 and T-3666 are still open.
- Today's T-3876/T-3877 (one port rule, Watchtower ensured at session start) also narrow the gap P-01 works around.

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

Instrumented evidence on one Windows 10 machine (framework 1.7.0 @29f3b02): documented native Git Bash route 15m51s and blocked (Watchtower cannot start, doctor exit 1); WSL by hand 1m49s with ~10 manual fixes; P-01 Install-AEF.ps1 127s with 0 manual fixes, two projects side by side on :3000/:3001. 57 findings, each mapped to a P-01 workaround. GO on the landing shape (installer quickstart mode + install.ps1 + framework fixes that retire workarounds); the four open questions are design choices with recommendations in the artifact, not evidence gaps.

What your GO adopts:
- IW-1: the installer offers guided and quickstart, with quickstart as the default, and only together with IW-3.
- IW-2: install.ps1 creates a normal (non-root) user.
- IW-3: the installer asks for the project goal and creates the first task with acceptance criteria.
- IW-4: the kit lives in the framework repo under `install/`, released with the framework.

Each is recorded as an answered disposition above. A NO-GO rejects the installer route, and the seven defect tasks below stand on their own either way.

Evidence:
- Research artifact: `docs/reports/T-3659-p01-zero-to-running.md`. The source is the external proposal "P-01 — Zero-to-running AEF" (2026-09-29, unratified), pasted by the operator on 2026-10-01.
- Measured on Windows 10, framework 1.7.0:
  - native Git Bash: 15m51s, blocked;
  - WSL by hand: 1m49s with ~10 fixes;
  - P-01 Install-AEF.ps1: 127s with 0 fixes.
- 57 findings. The defects are filed independently of this decision: T-3660, T-3661, T-3662, T-3663, T-3664, T-3665 (CRLF silently disables the secret scan) and T-3666.
- State on 2026-10-05:
  - shipped: T-3660 (watchtower detach), T-3661 (status exit codes) and T-3665 (CRLF secret scan);
  - T-3662 (per-project port) is done and awaiting review;
  - T-3663, T-3664 and T-3666 are still open.
- Today's T-3876/T-3877 (one port rule, Watchtower ensured at session start) also narrow the gap P-01 works around.

**Date**: 2026-10-05T22:30:47Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-01T15:08:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-05T22:30:47Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

Instrumented evidence on one Windows 10 machine (framework 1.7.0 @29f3b02): documented native Git Bash route 15m51s and blocked (Watchtower cannot start, doctor exit 1); WSL by hand 1m49s with ~10 manual fixes; P-01 Install-AEF.ps1 127s with 0 manual fixes, two projects side by side on :3000/:3001. 57 findings, each mapped to a P-01 workaround. GO on the landing shape (installer quickstart mode + install.ps1 + framework fixes that retire workarounds); the four open questions are design choices with recommendations in the artifact, not evidence gaps.

What your GO adopts:
- IW-1: the installer offers guided and quickstart, with quickstart as the default, and only together with IW-3.
- IW-2: install.ps1 creates a normal (non-root) user.
- IW-3: the installer asks for the project goal and creates the first task with acceptance criteria.
- IW-4: the kit lives in the framework repo under `install/`, released with the framework.

Each is recorded as an answered disposition above. A NO-GO rejects the installer route, and the seven defect tasks below stand on their own either way.

Evidence:
- Research artifact: `docs/reports/T-3659-p01-zero-to-running.md`. The source is the external proposal "P-01 — Zero-to-running AEF" (2026-09-29, unratified), pasted by the operator on 2026-10-01.
- Measured on Windows 10, framework 1.7.0:
  - native Git Bash: 15m51s, blocked;
  - WSL by hand: 1m49s with ~10 fixes;
  - P-01 Install-AEF.ps1: 127s with 0 fixes.
- 57 findings. The defects are filed independently of this decision: T-3660, T-3661, T-3662, T-3663, T-3664, T-3665 (CRLF silently disables the secret scan) and T-3666.
- State on 2026-10-05:
  - shipped: T-3660 (watchtower detach), T-3661 (status exit codes) and T-3665 (CRLF secret scan);
  - T-3662 (per-project port) is done and awaiting review;
  - T-3663, T-3664 and T-3666 are still open.
- Today's T-3876/T-3877 (one port rule, Watchtower ensured at session start) also narrow the gap P-01 works around.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1843e056
- **Timestamp:** 2026-10-05T22:30:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-e8913f2b
- **Timestamp:** 2026-10-05T22:30:51Z
- **Overall:** CONFIRMED
- **Claims:** 10

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-3659-p01-zero-to-running.md` | file | ✓ pass |
| `T-3660` | task | ✓ pass |
| `T-3661` | task | ✓ pass |
| `T-3662` | task | ✓ pass |
| `T-3663` | task | ✓ pass |
| `T-3664` | task | ✓ pass |
| `T-3665` | task | ✓ pass |
| `T-3666` | task | ✓ pass |
| `T-3876` | task | ✓ pass |
| `T-3877` | task | ✓ pass |

### 2026-10-05T22:30:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
