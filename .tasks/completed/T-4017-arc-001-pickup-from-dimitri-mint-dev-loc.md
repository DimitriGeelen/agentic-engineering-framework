---
id: T-4017
name: "arc-001 pickup from dimitri-mint-dev: local retrieval stack refresh (telemetry,
  benchmark, model manifest, reranker health, per-project keyword index)"
description: >
  Inception: arc-001 pickup from dimitri-mint-dev: local retrieval stack refresh (telemetry,
  benchmark, model manifest, reranker health, per-project keyword index)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-10-09T21:41:29Z
last_update: 2026-10-12T09:03:57Z
date_finished: 2026-10-12T09:03:57Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-10-09T21:42:43Z'
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
  - ts: '2026-10-09T21:45:38Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=136,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4017: arc-001 pickup from dimitri-mint-dev: local retrieval stack refresh (telemetry, benchmark, model manifest, reranker health, per-project keyword index)

## Problem Statement

dimitri-mint-dev (the operator's workstation project on .107) runs arc-001 "Local retrieval stack refresh" and sent AEF a pickup on 2026-10-09 (conversation arc-001-pickup; docs in OneDev project dimitri-mint-dev-workstation: `docs/designs/arc-001-01-requirements.md` v1.3, `arc-001-02-design.md` v0.4, `arc-001-03-pickup-proposal.md`). Phases asked of AEF: P1a signed deciding records + GPU baseline/stop rule; P1 telemetry, reranker/search health, benchmark harness; P2 model manifest, item tags, per-project multilingual keyword index; P3 night runner for model switches; P6 AEF's own default model. Findings against AEF: query text stored against the operator's data rule; `fw recall` never reranked; silent embed failover; hourly reindex is daytime bulk and model-unaware; Ollama open on the LAN; Watchtower on 0.0.0.0 with an empty secret key; cloud fallback in `fw ask`.

**Coordination (2026-10-11).** The pickup was filed here but never acknowledged for ~30 h (ring20 relayed the gap). The same migration snapshotted and deleted seven Qdrant collections on 192.168.10.201:6333 on 2026-10-10 12:54 UTC; ring20-dashboard asked who did it. The operator confirmed it was dimitri-mint-dev's planned Qdrant migration and asked AEF to coordinate. Sent: acknowledgement + request for the whole plan to dimitri-mint-dev (arc-001-pickup, msg a780d1f9), correction to ring20-dashboard (vectordb-kms-1011), task id to ring20. Next: read the three docs when dimitri-mint-dev shares them, answer each finding with a task id, agree the phase order.

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

- **IW-1: Which of the nine components (C1-C7, C12, C13) does AEF want at all, and in what order?**
  confidence: 2
  disposition: answered
  rationale: P1a (C5 core, C7 baseline + stop rule) then P1 (C1, C4, C2, C5 rest, C7 collector) — the order dimitri-mint-dev and the operator set (no model change before benchmark + health); C3/C12/C13/C6 (P2-P3) deferred to a re-inception after P1's benchmark exists (docs/reports/T-4017-arc-001-retrieval-refresh.md §Recommendation).
- **IW-2: How much of C1/C4 already exists (web/recall_telemetry.py, lib/vector_index_health.py, T-3953 reranker fix, T-3967 query-text switch)?**
  confidence: 3
  disposition: answered
  rationale: checked against source 2026-10-11 (design §1.2 confirmed): telemetry rows exist (query_hash, n_hits, top_score, latency; miss rows carry query text, web/recall_telemetry.py:278 → T-3967), index health exists (lib/vector_index_health.py), reranker fixed in 1.8.8 but silent when unavailable and absent from fw recall (T-4063); C1/C4 extend these, they do not replace them.
- **IW-3: Does C5 (signed deciding records, operator key off-host) fit AEF's existing provenance model or is it a new trust root (operator/Tier 0 call)?**
  confidence: 2
  disposition: answered
  rationale: it is a new trust root: AEF's existing provenance (human_ac_ticks ledger, review-dispatch HMAC) is same-user and forgeable by a root agent (T-3581's stated residual), which R-34 forbids; three consults (docs/reports/T-4017-O5-consult-*.md) agree on an off-host asymmetric key with the trust list kept off .107 — operator chose the phone (2026-10-11); enrolment of the trust anchor is an operator action.

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
- The proposal's findings hold against AEF's own code (each checked, not taken on trust)
- The first phases (P1a, P1) split into build tasks that each ship, test and upgrade on their own, without a model change
- The signing question (O-5) has a viable answer that meets R-34 against a root agent on .107

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

**Recommendation:** GO — accept arc-001 for AEF, starting with P1a then P1; re-incept P2/P3/P6 after P1's benchmark exists.

**Rationale:**

The earlier DEFER was an evidence gap that is now closed: the documents were received intact (sha256 checked), all ten findings were checked against AEF source (nine confirmed, F-8 corrected), and six of them already have tasks — two fixed and shipped today (T-4061 query text, T-4062 key-file mode). The first phases need no model change, so they are safe to build: measurement and signed approvals first, exactly the order dimitri-mint-dev and the operator asked for. The signing question O-5 is answered by three independent consults: phone as signer (shows the record on its own screen — the only option that closes "signing the wrong thing"), one FIDO2 key stored away as backup, and the trusted-key list kept off .107 (at ring20); TOTP is unsuitable. The central estate store (T-090, Qdrant on ring20) is designed in from the start via C3/C12, and its push interface gets its own inception.

**Proposed build tasks after GO** (one per component, P1a first): C5 signing core (sign/verify/hash binding, AC-34.1–34.3, test key first, phone enrolment once the app is chosen); C7 GPU baseline + stop rule; then P1: C1 telemetry extension, C4 reranker/search health (incl. T-4063 `fw recall` rerank), C2 benchmark harness, C5 rest, C7 collector. Plus a separate inception for the T-090 push interface.

**Evidence:**
- Research artifact: `docs/reports/T-4017-arc-001-retrieval-refresh.md` (asks, phases, ten findings with file:line, operator decisions, dialogue log)
- Inputs: `docs/reports/T-4017-arc-001-inputs/` (proposal 5992c032, design faf925a4, requirements a7b463ed — hashes verified)
- Signing consults: `docs/reports/T-4017-O5-consult-{codex,opencode,gemini}.md` (2 of 3 recommend phone + hardware backup; all three: two keys, trust list off .107; TOTP rejected)
- Findings filed: T-4061 (done), T-4062 (done), T-4063, T-4064, T-4065, T-4066, T-3967; F-2/F-6 folded into C2/C3/C6; F-3 estate (not AEF)
- Operator decisions recorded: keep `.context/qa/` tracked; Watchtower login optional (T-4071); phone for signing

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

**Rationale**: The earlier DEFER was an evidence gap that is now closed: the documents were received intact (sha256 checked), all ten findings were checked against AEF source (nine confirmed, F-8 corrected), and six of them already have tasks — two fixed and shipped today (T-4061 query text, T-4062 key-file mode). The first phases need no model change, so they are safe to build: measurement and signed approvals first, exactly the order dimitri-mint-dev and the operator asked for. The signing question O-5 is answered by three independent consults: phone as signer (shows the record on its own screen — the only option that closes "signing the wrong thing"), one FIDO2 key stored away as backup, and the trusted-key list kept off .107 (at ring20); TOTP is unsuitable. The central estate store (T-090, Qdrant on ring20) is designed in from the start via C3/C12, and its push interface gets its own inception.

**Date**: 2026-10-12T09:03:56Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-09T21:42:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-12T09:03:56Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The earlier DEFER was an evidence gap that is now closed: the documents were received intact (sha256 checked), all ten findings were checked against AEF source (nine confirmed, F-8 corrected), and six of them already have tasks — two fixed and shipped today (T-4061 query text, T-4062 key-file mode). The first phases need no model change, so they are safe to build: measurement and signed approvals first, exactly the order dimitri-mint-dev and the operator asked for. The signing question O-5 is answered by three independent consults: phone as signer (shows the record on its own screen — the only option that closes "signing the wrong thing"), one FIDO2 key stored away as backup, and the trusted-key list kept off .107 (at ring20); TOTP is unsuitable. The central estate store (T-090, Qdrant on ring20) is designed in from the start via C3/C12, and its push interface gets its own inception.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8bae368d
- **Timestamp:** 2026-10-12T09:04:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-0f1521f4
- **Timestamp:** 2026-10-12T09:04:01Z
- **Overall:** CONFIRMED
- **Claims:** 10

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-4017-arc-001-retrieval-refresh.md` | file | ✓ pass |
| `T-4061` | task | ✓ pass |
| `T-4062` | task | ✓ pass |
| `T-090` | task | ✓ pass |
| `T-4063` | task | ✓ pass |
| `T-4064` | task | ✓ pass |
| `T-4065` | task | ✓ pass |
| `T-4066` | task | ✓ pass |
| `T-3967` | task | ✓ pass |
| `T-4071` | task | ✓ pass |

### 2026-10-12T09:03:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
