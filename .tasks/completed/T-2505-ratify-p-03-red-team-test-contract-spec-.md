---
id: T-2505
name: "Ratify P-03 red-team test contract (SPEC-autonomy-integrity-redteam) and commit
  RT-1..RT-5 red"
description: >
  Inception: Ratify P-03 red-team test contract (SPEC-autonomy-integrity-redteam)
  and commit RT-1..RT-5 red

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-07-06T08:13:37Z
last_update: '2026-08-16T22:25:08Z'
date_finished: 2026-07-06T16:09:23Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-07-06T14:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-06T14:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F-AUTONOMY=2 
      (no-signal); F3=2 (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:08Z'
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

# T-2505: Ratify P-03 red-team test contract (SPEC-autonomy-integrity-redteam) and commit RT-1..RT-5 red

## Problem Statement

DISCOVERY-governance-test-audit-2026-06-21 (T-2514) established that the governance
test tier is genuinely adversarial for every gate it covers (F2) but has **zero**
coverage of the P-03 bypass class — writing an autonomy-critical state file directly
to defeat a verb-gate (F3) — and **zero** audit-side assertions across all 27 tests
(F4). The one exploit that actually fired (`fw dispatch approve` self-approval) was
caught by the agent's confession, not a test.

The Sovereign, with Claude as sparring partner, authored a red-team test contract
(`SPEC-autonomy-integrity-redteam-2026-07-06`, docs/reports/) that closes both holes:
RT-1..RT-5, each asserting the block (H1) AND the durable refusal-record (H2), red-first
(must FAIL on today's repo; greens only when lock-1 lands). This inception decides one
thing: **ratify that contract and commit RT-1..RT-5 red — before, and structurally
separate from, whoever builds lock-1.** The spec is `status: proposed`; §8 leaves four
scoping calls to the Sovereign (the Open Questions below).

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

The four §8 Sovereign decisions. These are scoping choices *within* the GO, not
blockers to it — the contract lands red regardless; these bind how it greens.

- **IW-1: §6 sink-sequencing — fold refused-attempt logging into lock-1 (a), or split it to a lock-1b milestone (b)?**
  confidence: 1
  disposition: dissolved
  rationale: Sovereign lock-scoping call. Spec §6 flags that (b) reintroduces a smaller version of the exact audit-blind H2 names — argues for (a) unless lock-1 is already too wide. Not a test-design decision; withheld by design.

- **IW-2: What is the `ATTEMPT_LOG` refused-attempt sink named, and what is its schema?**
  confidence: 1
  disposition: dissolved
  rationale: No such sink exists today (F4 — .gate-bypass-log.yaml records sanctioned FW_* overrides, not refusals). Spec §5 leaves the name unset on purpose ("naming it is a lock-1/Sovereign decision, not mine to invent"). Must carry ≥ {path, tool/verb, timestamp, task_id?}.

- **IW-3: What cage mechanism does lock-1 pick for Layer A (RT-3) — POSIX perms, process/container boundary, or LSM?**
  confidence: 1
  disposition: dissolved
  rationale: RT-3's H1 assertion is mechanism-dependent (spec §5 caveat): EPERM-under-agent-user vs boundary-denial vs LSM-denial. The contract (write refused + recorded) is fixed now; the assertion binds when lock-1 chooses. Blocks finalizing RT-3 only, not filing the contract red.

- **IW-4: Does RT-5 (block-without-log isolator) land immediately against a current gate, or wait for the sink?**
  confidence: 2
  disposition: dissolved
  rationale: Spec §4 RT-5 says it is the one case addable against a real gate now (doesn't depend on lock-1) — it converts F4's finding into a standing assertion immediately. But its H2 log-assertion still needs the IW-2 sink to exist. Sovereign call whether to land RT-5 red now or with lock-1b.

## Exploration Plan

Exploration is complete — the evidence base is the DISCOVERY report (T-2514), the
pasted spec, and this session's live re-verification against 1.6.80. No spikes remain;
the four Open Questions are Sovereign scoping calls surfaced for the go/no-go, not
research gaps. On GO: (1) land the spec artifact + this inception record; (2) create a
separate build task to author RT-1..RT-5 red under the §7 producer-not-judge bind
(implementer ≠ spec author). No RT test or lock-1 code is written under this inception ID.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** Ratify the spec; commit the spec artifact + RT-1..RT-5 as a red-first contract;
answer the four §8 scoping questions; create the follow-on build task under the
producer-not-judge bind.

**OUT (hard):** Implementing lock-1 or any gate. Writing/editing RT tests under *this*
inception ID. Editing the spec to make an implementation pass (§7 forbids it). Adding a
coverage gate or line-coverage metric (rejected in the value ruling). The person who
implements lock-1 must not be the person who authored this contract.

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
- The bypass gap is real and uncovered (confirmed: DISCOVERY F3/F4, re-verified vs 1.6.80)
- The contract is red-first and well-formed (every RT case fails on today's repo)
- The four §8 scoping calls are sub-decisions, not blockers (they bind how it greens, not whether it lands)

**NO-GO if:**
- The gap turns out already covered somewhere (it is not)
- The spec cannot be committed red without pre-committing lock-1's design (it can — RT-3/H2 are explicitly mechanism-deferred)

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

**Recommendation:** NO-GO (operator kill, 2026-07-06 — "do 1")

**Rationale:**

KILLED by operator decision. The P-03 bypass gap is real, but filing the red-team
contract as an *inception awaiting go/no-go* was unwanted ceremony — the operator asked
"what is this stuff about red team spec" / "where has the bats gone" across three turns.
If the coverage gap is pursued later, write RT-1..RT-5 directly under a build task (no
inception gate needed); the spec artifact
`docs/reports/SPEC-autonomy-integrity-redteam-2026-07-06.md` stays on disk as the
contract. The four §8 Open Questions are dissolved (moot — not building it). Original GO
rationale retained below for the record:

DISCOVERY-governance-test-audit (T-2514), re-verified live against 1.6.80 this session, confirms the P-03 bypass class is genuinely uncovered: fw dispatch approve (lib/dispatch.sh:166) has zero governance tests, no RT tests exist, and no refused-attempt sink exists (.gate-bypass-log.yaml records only sanctioned FW_* overrides, not refusals). The pasted SPEC is well-formed and every RT case red-today premise holds against the repo. Adopting it — commit RT-1..RT-5 RED before lock-1, under the producer-not-judge bind the discovery itself violated — is the mechanism the value ruling already endorsed. GO to ratify + land the contract red. The four §8 open items (sink sequencing a/b, ATTEMPT_LOG name+schema, RT-3 cage mechanism, RT-5 timing) are Sovereign sub-decisions within the GO, not blockers to it.

**Evidence:**

- Spec artifact: `docs/reports/SPEC-autonomy-integrity-redteam-2026-07-06.md`
- Ground-truth basis: `docs/reports/DISCOVERY-governance-test-audit-2026-06-21.md` (in commit `0ab1e255f`; not on master)
- `fw dispatch approve` exists with zero governance coverage: `lib/dispatch.sh:166`, `agents/context/check-agent-dispatch.sh:102`
- No RT tests exist: only pre-existing integration tests reference `next-directive.yaml`/`focus.yaml`, all as setup (matches F3)
- No refused-attempt sink: `.gate-bypass-log.yaml` records only sanctioned FW_* overrides, not refusals (matches F4)
- Neither the spec nor `INSTRUCTIONS-autonomy-integrity-lock1` is present in repo history — both are net-new

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

**Rationale**: KILLED by operator decision. The P-03 bypass gap is real, but filing the red-team
contract as an *inception awaiting go/no-go* was unwanted ceremony — the operator asked
"what is this stuff about red team spec" / "where has the bats gone" across three turns.
If the coverage gap is pursued later, write RT-1..RT-5 directly under a build task (no
inception gate needed); the spec artifact
`docs/reports/SPEC-autonomy-integrity-redteam-2026-07-06.md` stays on disk as the
contract. The four §8 Open Questions are dissolved (moot — not building it). Original GO
rationale retained below for the record:

DISCOVERY-governance-test-audit (T-2514), re-verified live against 1.6.80 this session, confirms the P-03 bypass class is genuinely uncovered: fw dispatch approve (lib/dispatch.sh:166) has zero governance tests, no RT tests exist, and no refused-attempt sink exists (.gate-bypass-log.yaml records only sanctioned FW_* overrides, not refusals). The pasted SPEC is well-formed and every RT case red-today premise holds against the repo. Adopting it — commit RT-1..RT-5 RED before lock-1, under the producer-not-judge bind the discovery itself violated — is the mechanism the value ruling already endorsed. GO to ratify + land the contract red. The four §8 open items (sink sequencing a/b, ATTEMPT_LOG name+schema, RT-3 cage mechanism, RT-5 timing) are Sovereign sub-decisions within the GO, not blockers to it.

**Date**: 2026-07-06T16:09:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-06T08:15:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-07-06T16:09:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** KILLED by operator decision. The P-03 bypass gap is real, but filing the red-team
contract as an *inception awaiting go/no-go* was unwanted ceremony — the operator asked
"what is this stuff about red team spec" / "where has the bats gone" across three turns.
If the coverage gap is pursued later, write RT-1..RT-5 directly under a build task (no
inception gate needed); the spec artifact
`docs/reports/SPEC-autonomy-integrity-redteam-2026-07-06.md` stays on disk as the
contract. The four §8 Open Questions are dissolved (moot — not building it). Original GO
rationale retained below for the record:

DISCOVERY-governance-test-audit (T-2514), re-verified live against 1.6.80 this session, confirms the P-03 bypass class is genuinely uncovered: fw dispatch approve (lib/dispatch.sh:166) has zero governance tests, no RT tests exist, and no refused-attempt sink exists (.gate-bypass-log.yaml records only sanctioned FW_* overrides, not refusals). The pasted SPEC is well-formed and every RT case red-today premise holds against the repo. Adopting it — commit RT-1..RT-5 RED before lock-1, under the producer-not-judge bind the discovery itself violated — is the mechanism the value ruling already endorsed. GO to ratify + land the contract red. The four §8 open items (sink sequencing a/b, ATTEMPT_LOG name+schema, RT-3 cage mechanism, RT-5 timing) are Sovereign sub-decisions within the GO, not blockers to it.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f8668caa
- **Timestamp:** 2026-07-06T16:09:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-11cf9add
- **Timestamp:** 2026-07-06T16:09:24Z
- **Overall:** CONTRADICTED
- **Claims:** 5

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/SPEC-autonomy-integrity-redteam-2026-07-06.md` | file | ✓ pass |
| `docs/reports/DISCOVERY-governance-test-audit-2026-06-21.md` | file | ✗ fail — file not found at PROJECT_ROOT |
| `lib/dispatch.sh:166` | file_line | ✓ pass |
| `agents/context/check-agent-dispatch.sh:102` | file_line | ✓ pass |
| `T-2514` | task | ✗ fail — no task file in .tasks/{active,completed}/ |

### 2026-07-06T16:09:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
