---
id: T-3818
name: "Ring20 Manager committed directly to AEF master (eb49ff9, 2026-10-04 07:25Z,
  removing the OneDev LXC prod-deploy job): agree with ring20 how AEF master is protected
  — OneDev branch protection, who may write, and the route for cross-project change
  requests"
description: >
  Operator 2026-10-04: 'the fact that Ring20 Manager could commit to our master is
  not good; talk to Ring20 Manager how we can change that'. ring20-manager pushed
  eb49ff9 straight to AEF master (operator-requested change, via ring20 T-2216). master
  is the consumer install surface and receives only release fast-forwards from bleeding-edge
  (Release-Train model); PROTECT_MASTER is a local hook and cannot stop a remote push.
  It blocked the v1.8.0 release until merged into bleeding-edge. Questions: OneDev
  branch protection on master (release-only writer), ring20's write access to the
  AEF repo, and the sanctioned path for a change ring20 needs in AEF (sidecar request/pickup
  to 999, or a PR into bleeding-edge).

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [security, release-train, ring20]
components: [tests/web/test_t3896_inception_readiness.py, web/blueprints/approvals.py, web/blueprints/inception.py, web/shared.py, web/templates/_approvals_content.html, web/templates/inception_detail.html]
related_tasks: [T-3785, T-3185]
origin: {kind: "operator", source: "", ref: "operator 2026-10-04"}
bvp_scores: {D1: 4, D2: 5, D3: 3, D4: 3}
confirmed_by: operator
confirmed_at: 2026-10-04T13:34:11Z
confirmed_via: human   # operator ruling 2026-10-04: "give the very high value", "on horizon now, picked up soon after this"
created: 2026-10-04T13:34:11Z
last_update: 2026-10-05T22:39:42Z
date_finished: 2026-10-05T22:39:42Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-10-04T13:45:21Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-04T22:34:34Z'
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

# T-3818: Ring20 Manager committed directly to AEF master (eb49ff9, 2026-10-04 07:25Z, removing the OneDev LXC prod-deploy job): agree with ring20 how AEF master is protected — OneDev branch protection, who may write, and the route for cross-project change requests

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

- **IW-1: Which identity and credential did ring20-manager push to AEF master with, and what other write access to the AEF repo does ring20 rely on?**
  confidence: 3
  disposition: answered
  rationale: ring20-manager 2026-10-05 (raw post, conversation aef-master-protection): pushed from .122 CT 200 via its git credential helper with OneDev access token 7 'ring20-git-codewrite' (non-owner, role Code Writer, authorised on ALL 41 OneDev projects, expires 2026-11-14); author = the operator's configured identity; no other write access to AEF is relied on — filings go over TermLink, never git
- **IW-2: Does ring20 object to OneDev branch protection on master (release fast-forwards only, no direct pushes)?**
  confidence: 3
  disposition: answered
  rationale: ring20-manager 2026-10-05: no objection, supports it; suggests removing the AEF project from token 7 (or read-only), which only a OneDev admin can change — ring20 has no admin token
- **IW-3: Which path should ring20 use for future AEF changes — sidecar request to 999, patch bundle (832 style), or a branch/PR into bleeding-edge?**
  confidence: 3
  disposition: answered
  rationale: ring20-manager 2026-10-05: default a sidecar request to 999; if ring20 already wrote the patch, a branch ring20/<task> off bleeding-edge for 999 to review and merge; never master
- **IW-4: Does any ring20 automation (CI, mirror, timers) write AEF master or tags that protection would break?**
  confidence: 3
  disposition: answered
  rationale: ring20-manager 2026-10-05: none — checked cron jobs, systemd timers and scripts; nothing pushes AEF master or creates tags. (Our own release pushes master + tags from .107 as the release identity; protection must allow that path.)

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

**Rationale:** A peer agent wrote the consumer install surface directly, bypassing the release train and every client-side gate; server-side protection plus an agreed request path is the only control that holds, and ring20 must be party to it because it currently relies on that access. ring20-manager answered all four questions (2026-10-05) and agrees: it relies on no git write access to AEF, has no automation touching master or tags, and supports protection.

**Proposed decision (three parts, all operator/OneDev-admin actions):**
1. OneDev branch protection on `master` of agentic-engineering-framework: no direct pushes and no force-pushes; only the release identity (the account `fw release tag-and-release` pushes with from .107) may update it, by fast-forward. Also protect `v*` tags from deletion and moving.
2. Token 7 'ring20-git-codewrite' (Code Writer on all 41 projects, expires 2026-11-14): remove the AEF project from its authorised projects, or make it read-only there. ring20 suggested this itself.
3. The ring20 → AEF change path is agreed: by default a sidecar request to 999; if ring20 has already written the patch, a branch `ring20/<task>` off `bleeding-edge` for 999 to review and land; never `master`.

**Evidence:** IW-1..IW-4 above (dispositions answered from ring20-manager's reply); eb49ff9 on master 2026-10-04 07:25Z; the v1.8.0 release was blocked until it was merged into bleeding-edge (docs/reports/T-3785-v1.8.0-release-rca.md).

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

Rationale: A peer agent wrote the consumer install surface directly, bypassing the release train and every client-side gate; server-side protection plus an agreed request path is the only control that holds, and ring20 must be party to it because it currently relies on that access. ring20-manager answered all four questions (2026-10-05) and agrees: it relies on no git write access to AEF, has no automation touching master or tags, and supports protection.

Proposed decision (three parts, all operator/OneDev-admin actions):
1. OneDev branch protection on `master` of agentic-engineering-framework: no direct pushes and no force-pushes; only the release identity (the account `fw release tag-and-release` pushes with from .107) may update it, by fast-forward. Also protect `v` tags from deletion and moving.
2. Token 7 'ring20-git-codewrite' (Code Writer on all 41 projects, expires 2026-11-14): remove the AEF project from its authorised projects, or make it read-only there. ring20 suggested this itself.
3. The ring20 → AEF change path is agreed: by default a sidecar request to 999; if ring20 has already written the patch, a branch `ring20/<task>` off `bleeding-edge` for 999 to review and land; never `master`.

Evidence: IW-1..IW-4 above (dispositions answered from ring20-manager's reply); eb49ff9 on master 2026-10-04 07:25Z; the v1.8.0 release was blocked until it was merged into bleeding-edge (docs/reports/T-3785-v1.8.0-release-rca.md).

**Date**: 2026-10-05T22:39:41Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-04T22:34:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-05T22:39:41Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: A peer agent wrote the consumer install surface directly, bypassing the release train and every client-side gate; server-side protection plus an agreed request path is the only control that holds, and ring20 must be party to it because it currently relies on that access. ring20-manager answered all four questions (2026-10-05) and agrees: it relies on no git write access to AEF, has no automation touching master or tags, and supports protection.

Proposed decision (three parts, all operator/OneDev-admin actions):
1. OneDev branch protection on `master` of agentic-engineering-framework: no direct pushes and no force-pushes; only the release identity (the account `fw release tag-and-release` pushes with from .107) may update it, by fast-forward. Also protect `v` tags from deletion and moving.
2. Token 7 'ring20-git-codewrite' (Code Writer on all 41 projects, expires 2026-11-14): remove the AEF project from its authorised projects, or make it read-only there. ring20 suggested this itself.
3. The ring20 → AEF change path is agreed: by default a sidecar request to 999; if ring20 has already written the patch, a branch `ring20/<task>` off `bleeding-edge` for 999 to review and land; never `master`.

Evidence: IW-1..IW-4 above (dispositions answered from ring20-manager's reply); eb49ff9 on master 2026-10-04 07:25Z; the v1.8.0 release was blocked until it was merged into bleeding-edge (docs/reports/T-3785-v1.8.0-release-rca.md).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f06792c6
- **Timestamp:** 2026-10-05T22:39:44Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  4. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-5ae6148e
- **Timestamp:** 2026-10-05T22:39:44Z
- **Overall:** CONFIRMED
- **Claims:** 1

| Claim | Type | Status |
|-------|------|--------|
| `T-3785` | task | ✓ pass |

### 2026-10-05T22:39:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
