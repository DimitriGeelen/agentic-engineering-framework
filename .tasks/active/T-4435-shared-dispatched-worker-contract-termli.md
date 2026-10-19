---
id: T-4435
name: "Shared dispatched-worker contract (TermLink + AEF + ring20): should AEF own
  the run.sh record writer, dispatcher recording and worker instruction?"
description: >
  Formal question from 010-termlink (msg 0673a051, conversation shared-worker-contract-3way,
  after their operator ruled termlink T-3483 option C): one shared contract for dispatched
  agent workers, based on ring20's arc-009 S-1 model, with TermLink building the hub
  ledger primitive, AEF owning run.sh as the supervisor-writer, the dispatcher recording
  and the worker instruction, ring20 moving its supervisor onto the shared primitive.
  Operator asked for three reviews before deciding. Prior AEF context: T-3977 (GO:
  take arc-009 orchestration in piece by piece), T-3960 (S-1 contract stakeholder
  check). Artefact: docs/reports/T-4435-shared-worker-contract.md.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-19T21:56:28Z
last_update: '2026-10-19T22:00:42Z'
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
  - ts: '2026-10-19T21:58:30Z'
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
  - ts: '2026-10-19T22:00:42Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=128,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4435: Shared dispatched-worker contract (TermLink + AEF + ring20): should AEF own the run.sh record writer, dispatcher recording and worker instruction?

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

- **IW-1: Is the shared contract sound (single-writer done, (dispatch id, attempt, nonce) fencing, lost only on confirmed session end), with no race, split-brain or stuck state left open?**
  confidence: 3
  disposition: answered
  rationale: No — sound in shape, not as specified. All 3 seats independently: done/lost race with no precedence (needs CAS + fenced done > lost), stuck running without a bounded unknown state, hub-allocated attempts/nonce + no overlapping attempts. Artefact §6.2 items 1-3
- **IW-2: Should AEF own the run.sh supervisor-writer, the dispatcher recording and the worker instruction, and are AEF's four conditions right?**
  confidence: 3
  disposition: answered
  rationale: Yes, all 3 seats; add the local-evidence reconciler and the session<->dispatch binding at spawn. Conditions 1-3 kept but sharpened; condition 4 narrowed to the completion authority (evaluation ledger separate, shadow mode first). Artefact §6.2-6.5
- **IW-3: How does an answer reach a running worker given no worker receiver (T-4423), circuit addressing / the orphan-inbox class (T-3855, T-4418) and a retry ladder that outlives any worker (D-600)?**
  confidence: 2
  disposition: answered
  rationale: Per-attempt answer entries in the fenced record, acked by a fenced read-marker; TTL <= attempt life then bounce to the dispatcher; never the retry ladder, never a worker inbox (excludes the T-4418 class by construction, keeps T-4423). Default pause-and-redispatch until in-run consumption is demonstrated (codex). Artefact §6.2 item 4, §6.4

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

**Recommendation:** GO, for the ownership plus a spec-first first slice, not for code.

**Rationale:** All three independent seats (codex, claude, and opencode re-run isolated) answer AEF's question "yes, with conditions". They agree just as clearly that the contract is not build-ready: the transition semantics decide correctness and are unspecified. So AEF says yes to owning:

- the run.sh supervisor-writer;
- the dispatcher recording;
- the worker instruction;
- plus the local-evidence reconciler and the session ↔ dispatch binding at spawn.

These conditions go to termlink and ring20:

1. **First deliverable is a jointly agreed transition table** plus a shared conformance suite run against the hub backend and AEF's local backend. The table covers:
   - CAS on every transition;
   - fenced `done` outranks `lost`, with a `lost → done` upgrade;
   - a bounded `unknown` state with a resolution verb;
   - hub-allocated attempts and nonces;
   - no overlapping attempts;
   - an outcome field on `done`.

   No implementation before that.
2. **Answers are per-attempt record entries** with a fenced read-marker ack, TTL at most the attempt's life, then bounce to the dispatcher. Never the retry ladder, never a worker inbox. Default to pause-and-redispatch.
3. **Local backend:** same CAS semantics, chosen at dispatch time, same conformance suite.
4. **The record replaces the completion authority only.** The evaluation ledger stays separate. Shadow mode before switch-over.
5. **Named durable dispatcher session id**, bound at spawn.
6. **ring20 maps its T-2281 against the contract** before it is declared absorbed.

This fits T-3977's GO (take arc-009 in piece by piece).

**Evidence:**
- docs/reports/T-4435-shared-worker-contract.md §6: verdicts, convergence, the condition-4 disagreement and how it resolves.
- Verbatim reviews: docs/reports/T-4435-reviews/{codex,claude,opencode}.md.
- The first opencode seat was not independent: it is kept as opencode-contaminated.md and not counted. No host data was exposed (checked); follow-up T-4437.

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

### 2026-10-19T21:58:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
