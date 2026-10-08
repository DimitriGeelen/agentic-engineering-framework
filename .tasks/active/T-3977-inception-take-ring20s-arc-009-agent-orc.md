---
id: T-3977
name: "Inception: take ring20's arc-009 agent orchestration into AEF (portable core
  + optional systemd isolation adapter)?"
description: >
  ring20 T-2281 proposal, operator-requested on their side: docs/reports/T-2281-arc009-upstream-proposal.md
  in http://192.168.10.201:6610/proxmox-ring20-management (commit f2c968bda, code
  pinned at 49708487a); contracts at http://192.168.10.122:3000/design/orchestration-s1-contract
  and /design/orchestration-s3-contract. One agent commissions work to other agents/vendors
  over approved routes, gets it back verified, reviewed by a different vendor, counted
  once; operator interrupted only at real decisions. Built on AEF primitives (resolver,
  spawn, outcome, keylock, worker_identity, secret-scan, Tier-0/paid hooks, P-011).
  ~5,900 lines incl. 1,800 tests. Proposed shape: portable core + optional linux-systemd
  isolation adapter + consumer config. Six open questions in their §9. Security: G-112
  (git in worker trees) must be settled before any uid split. Related: T-3930, T-3960,
  T-3961.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-07T09:29:48Z
last_update: 2026-10-07T11:31:48Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-10-07T09:45:22Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-07T09:45:50Z'
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

# T-3977: Inception: take ring20's arc-009 agent orchestration into AEF (portable core + optional systemd isolation adapter)?

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

- **IW-1: Which parts of arc-009 are portable framework core and which are ring20-estate specific (addresses, uid ranges, systemd)?**
  confidence: 2
  disposition: answered
  rationale: map review IW-1 — registry, route side-file, data classes, ledger/fold, view, candidates are portable; supervisor is MIXED (systemd-run default launcher, /var/lib/orch, ring20 path layout); isolation adapter is linux-systemd specific.
- **IW-2: Does arc-009 duplicate or contradict AEF primitives it builds on (resolver, spawn, outcome, keylock, worker_identity, verdict ledger, review-backends)?**
  confidence: 2
  disposition: answered
  rationale: map review IW-2 — uses resolver/keylock/outcome/spawn/review_cost as-is; duplicates worker launch, review verdict, approvals, P-011 extraction, OS sandbox; contradicts T-3910 (cap) and T-3583 (cost rows).
- **IW-3: Can it land in PR-sized pieces that each stand alone, and in what order?**
  confidence: 2
  disposition: answered
  rationale: map review IW-3 — yes: 0a-0c AEF-side first, then 1 route schema, 2 registry, 3 ledger, 4 fw facade, 5 engine (after D-a/D-b/D-c), 6 view, 7 Watchtower, 8 isolation adapter.
- **IW-4: Do its security lessons (their §6, incl. G-232) expose gaps AEF already has today?**
  confidence: 2
  disposition: answered
  rationale: yes — T-2271 was live in AEF (fixed: T-3983); G-232 → G-112/T-3980; T-2272/T-2274 latent in govd_sandbox (map review IW-4); G-228/G-231 already avoided.

## Exploration Plan

1. Dispatched static review of the map (`docs/reports/T-2281-arc009-upstream-proposal.md` at ring20 commit f2c968bda, code pinned at 49708487a) against AEF's primitives; output `docs/reports/T-3977-arc009-map-review.md` answering IW-1..IW-4 with file references. Time-box: one worker run.
2. Dialogue with the operator on the review; GO/NO-GO per piece.

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

**Recommendation:** GO — piece by piece, not as one merge

**Rationale:** The evidence gap behind the earlier DEFER is closed by the dispatched map review (`docs/reports/T-3977-arc009-map-review.md`). The map is accurate where checkable, the portable core is genuinely portable, and the work is built on AEF primitives. What blocks a wholesale merge is five duplicated AEF mechanisms (worker launch, review verdict, approvals, P-011 extraction, OS sandbox) and two contradictions of standing rulings (workers launched outside `fw termlink dispatch` escape the T-3910 cap; no cost rows per T-3583). So: take the AEF-side pieces first (0a done as T-3983; 0b P-011 extractor as a library; 0c a `safe_git` helper feeding T-3980), then the schemas (route side-file, registry, ledger), and land the supervisor engine only after three operator decisions:
- **D-a** may `systemd-run` launch workers next to TermLink, and does the worker cap apply to it?
- **D-b** does orchestration review write `verdict_ledger` rows at a policy rung, or is it a separately named class that never ticks ACs?
- **D-c** one sandbox in AEF (`govd_sandbox`) or two?

**Evidence:**
- Map review, IW-1..IW-4 with ring20 file:line references at the pinned commit.
- Piece 0a already found and fixed a live AEF fail-open (T-3983: scan-tree clean on an empty index).
- IW-4: T-2272 and T-2274 are latent in `lib/govd_sandbox.py` (nested InaccessiblePaths not validated; `/run/systemd/transient` readable). Worth their own tasks before any sandbox use.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-08 — operator walkthrough (chat): GO piece by piece, and the three engine rulings
- **Chose:** GO, piece by piece (A). D-a YES: systemd-run may launch workers alongside TermLink, with the T-3910 worker cap applying to both. D-b YES: orchestration review records through `verdict_ledger` at a policy rung, under the T-3986 ruling (a seat that could not evaluate says NOT-EVALUATED, never a verdict). D-c YES: one sandbox in AEF — ring20's isolation adapter is rebuilt on `lib/govd_sandbox.py`.
- **Why:** the map review (`docs/reports/T-3977-arc009-map-review.md`) found solid, tested work whose blockers are duplicated AEF mechanisms and two bypassed rulings; ring20 has agreed to build toward this shape.
- **Rejected:** NO-GO (loses tested work AEF needs) and DEFER (the evidence gap is closed).

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-07T11:06:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
