---
id: T-3558
name: "circuit address everywhere - D-660 wording dropped the 5-level model a peer
  then abandoned; TermLink keys are per machine"
description: >
  Amend D-660 so the circuit id is the addressing rule and dm: is transport only;
  correct the record with 832 and 010-termlink; decide whether to propose per-project
  identity to TermLink.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-3518, T-3433, T-3287, T-3543]
created: 2026-09-29T14:35:01Z
last_update: '2026-09-29T14:45:27Z'
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
  - ts: '2026-09-29T14:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=143,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-29T14:45:27Z'
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

# T-3558: circuit address everywhere - D-660 wording dropped the 5-level model a peer then abandoned; TermLink keys are per machine

## Problem Statement

The operator's intent (2026-09-29): **the 5-level circuit model applies everywhere**,
with the fallback ladder agent → session → project → hub → machine. Three things
currently disagree with that, and a peer has already acted on the disagreement:

1. **D-660's wording** says `inbox:<agent-id>` where D-599 said `inbox:<circuit-id>`.
2. **`dm:<fp>:<fp>`** keys on TermLink's machine-wide identity (`d1993c2c3ec44c94`),
   so it bypasses the circuit model and collapses co-resident projects into one
   shared mailbox (OBS-567, verified OBS-574).
3. **832-Workflow-designer read D-660's text and withdrew the five-level framing**,
   while our own code kept it (`inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework`).

Full findings and verbatim dialogue: `docs/reports/T-3558-circuit-address-everywhere.md`.

## Assumptions

- **A-1:** `inbox:` carries every TermLink mail semantic the circuit model needs (wake,
  receipts, `--await-ack`), so routing by circuit id needs no TermLink change.
  Source: `lib/sidecar/circuit.py` docstring (T-3433); 010-termlink's fix to their
  notify rail (they now enumerate `inbox:` as well as `dm:`).
- **A-2:** trust, unlike routing, cannot be solved on our side alone: a circuit id is a
  name, and TermLink's identity only proves the machine.

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

- **IW-1: Is the circuit id (with ladder fallback) the addressing rule for all agent-to-agent traffic, with `dm:` demoted to transport?**
  confidence: 3
  disposition: answered
  rationale: Operator 2026-09-29, segment 2 ("you want to use the circuit model. With the ladder of the fallback. From agent, session, project, hub, machine") and "proceed as you see fit and as suggested" (segment 4). Two rounds of external review (3 vendors, amber x2) agree on inbox:<circuit-id> and on demoting dm: (2 of 3; the third's objection answered by one machine-checked spec). The D-660 amendment itself is recorded by this task's GO.

- **IW-2: Do we propose per-project/per-circuit identity to TermLink, for trust rather than routing?**
  confidence: 3
  disposition: answered
  rationale: Operator "proceed as suggested", 2026-09-29. Proposal sent to 010-termlink on inbox:cacc73ea32b121dd/010-termlink (client_msg_id e248f235-d075-407a-85bf-cae3ed4b2afe): named identities, a whoami that errors on ambiguity, optional topic ACLs or encryption, with the external reviewers' caveat that key files under one OS user are attribution, not isolation. Theirs to decide per gap-homing (T-1333).

- **IW-3: May the agent send the correction to 832 and 010-termlink now?**
  confidence: 3
  disposition: answered
  rationale: Operator "proceed as suggested", 2026-09-29. Sent: to 832 on circuit-id-adoption (client_msg_id c8ec7241-ecf6-4282-887b-9a123b12514b) stating the five-level model stands and from_circuit is routing-only and untrusted; to 010-termlink on e2e-ab947312 (e248f235-…). Both reported INJECTED_NOW, which means hub-accepted only, not read.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** the addressing rule (circuit id after `inbox:`, `dm:` as transport); amending
D-660's wording; correcting the record with the two peers; proposing per-project
identity to TermLink.

**OUT:** building consumption (D-645 is ratified on its own; slice 1 is its own task);
the trust layer (signer verification, replay, key lifecycle); any TermLink change.

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
- The addressing rule can be stated as one machine-checked definition that D-660, the
  code and peers all read, so a ruling's wording cannot drift from its code again (F-2)
- External review does not find the direction unsound

**NO-GO if:**
- Review finds that circuit addressing on `inbox:` cannot carry agent-to-agent traffic
  without a TermLink change

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

**Rationale:** Amend D-660 so the rule it states is the rule the code already follows: the circuit id, with the fallback ladder (agent, session, project, hub, host), is the address after `inbox:` for all agent-to-agent traffic, and `dm:<fp>:<fp>` is TermLink transport only, never a private circuit. D-660 was worded `inbox:<agent-id>` where D-599 said `inbox:<circuit-id>`, and a peer (832) acted on the wording and withdrew the model. `dm:` keys on TermLink's machine-wide identity, so between co-resident projects it collapses into one shared topic (OBS-567, verified OBS-574). Two rounds of three-vendor external review returned amber, not red: they endorse the direction and put consumption first. That is scoped to D-645's own build, not to this addressing ruling.

**Evidence:**
- F-1..F-6 and the verbatim dialogue: `docs/reports/T-3558-circuit-address-everywhere.md`.
- Six external reviews, verbatim: `docs/reports/T-3558-review-{openai,zai,anthropic}.md` and `T-3558-review2-*.md`.
- Our own inbox address has used the circuit id throughout: `inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework` (`lib/sidecar/circuit.py`).
- 832 and 010-termlink were told on 2026-09-29 that the model stands (IW-3).

**What a GO authorises, and what it does not:**
1. Amending D-660's text to the rule above, and publishing the address rule as one machine-checked definition (reviewer consensus, F-2 prevention).
2. Not the trust layer: signer verification, replay protection and key lifecycle belong to D-645's build and to TermLink (IW-2 proposal sent).
3. Not the consumption build: D-645 is already ratified; its slice 1 is a separate task.

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
