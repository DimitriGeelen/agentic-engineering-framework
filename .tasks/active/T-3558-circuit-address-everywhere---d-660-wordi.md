---
id: T-3558
name: "circuit address everywhere - D-660 wording dropped the 5-level model a peer then abandoned; TermLink keys are per machine"
description: >
  Amend D-660 so the circuit id is the addressing rule and dm: is transport only; correct the record with 832 and 010-termlink; decide whether to propose per-project identity to TermLink.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-3518, T-3433, T-3287, T-3543]
created: 2026-09-29T14:35:01Z
last_update: 2026-09-29T14:35:01Z
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
  confidence: 2
  disposition:
  rationale: Operator 2026-09-29 segment 2 states the intent ("you want to use the circuit model. With the ladder of the fallback"). Needs the operator's explicit amendment of D-660, since D-660 is a sovereign ruling.

- **IW-2: Do we propose per-project/per-circuit identity to TermLink, for trust rather than routing?**
  confidence: 1
  disposition:
  rationale: Operator asked "maybe we should make a change in TermLink". Agent's view: not needed for routing; needed only if the circuit id is to be trusted, which is exactly 832's open question. Fix belongs to TermLink per gap-homing (T-1333); ours is to propose.

- **IW-3: May the agent send the correction to 832 and 010-termlink now?**
  confidence: 1
  disposition:
  rationale: Outward-facing, so it needs the operator's go. 832 withdrew the five-level model on the strength of D-660's wording and asked for a full readout; seven consults sat unread for 23.6h.

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

**Recommendation:** GO

**Rationale:** Operator intent 2026-09-29: the 5-level circuit model with ladder fallback (agent, session, project, hub, host) applies everywhere. D-660's text says inbox:<agent-id> where D-599 said inbox:<circuit-id>; our code kept circuit ids, but 832 read the text and withdrew the five-level framing (unread consult, 2026-09-28). dm:<fp>:<fp> keys on TermLink's machine-wide identity, so it bypasses the circuit model entirely and collapses co-resident projects (OBS-567, verified OBS-574). Addressing needs no TermLink change: inbox:<circuit-id> already has mail semantics. A TermLink identity change is worth proposing only for trust, not routing.

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
