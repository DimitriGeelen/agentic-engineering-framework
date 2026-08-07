---
id: T-2863
name: "rework the inception workflow: five failure modes, and a gate that manufactures
  the decision it then records"
description: >
  Map the inception workflow in the designer corpus (arc-014 pair-draft ritual: agent
  seeds skeleton, operator edits in the UI, agent re-reads and normalises, iterate
  to promotion), then rework it with the operator. Scope IN: the filing-to-decision
  path — recommendation-completeness gate, @auto-tick-on-decide, the decide preflight's
  AC requirement, C-001 artifact timing, agent-vs-human decide authority, and the
  seed tasks that instantiate all of it. Scope OUT: BVP scoring, arc lifecycle, and
  the T-2857 CLI-suite gate (its own task chain).

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-07T17:25:59Z
last_update: 2026-08-07T17:34:49Z
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
  - ts: '2026-08-07T17:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-07T17:30:13Z'
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

# T-2863: rework the inception workflow: five failure modes, and a gate that manufactures the decision it then records

## Problem Statement

The inception workflow asks for the conclusion before the evidence exists, then
records that answer as the finding.

Five instances, four hit live in one session:

| # | Instance | Failure |
|---|----------|---------|
| 1 | **T-2862** | Greenfield seed ships `- [ ] Go/no-go decision recorded: fw inception decide T-002 go` as an Agent AC with no `@auto-tick-on-decide`. The decide preflight refuses while any agent AC is unchecked — but that AC *is* the decision. Every new project's first inception is un-completable. |
| 2 | **T-2442** | Prior sibling: inception schema deadlock. Same shape, already once fixed. |
| 3 | **T-2857** | Decision recorded *mid-exploration* with `--skip-sovereignty`; `@auto-tick-on-decide` ticked the `### Human [REVIEW]` AC; the recorded rationale was the filing-time prior verbatim with an empty `Evidence:` block — and the spike refuted its central claim 40 minutes later. |
| 4 | **T-2861** | C-001 makes creating `docs/reports/T-XXX-*.md` the **first** act of an inception, which is exactly when a background session's write guard refuses. The advice it gives (enter a worktree) is wrong here, because governance state is tracked and a worktree forks it (T-2821/T-2822). |
| 5 | **Root** | The T-2204 recommendation-completeness gate *requires* GO/NO-GO/DEFER at filing time, before any exploration. `@auto-tick-on-decide` then promotes that untested prior into the recorded decision. |

Instance 5 is the root and the other four are its surface. The gate was built for
a real problem — agents filing inceptions with empty recommendations and handing
the operator a blank form (T-679). But the fix put the recommendation at the
wrong point in time. A recommendation written before the research is a *prior*,
and the workflow currently has no way to distinguish a prior from a finding: same
field, same rendering, and auto-tick converts one into the other silently.

For whom: every consumer project (instance 1 blocks all of them at first run) and
every agent running an inception. Why now: the operator hit three of these in a
single fresh-install session.

## Assumptions

- **A1** — Separating "prior at filing" from "recommendation at review" is
  sufficient; the gate does not need to be removed, only re-timed.
- **A2** — `@auto-tick-on-decide` ticking a `### Human` AC is always wrong, and
  no current workflow depends on it.
- **A3** — The decide preflight's agent-AC requirement is load-bearing for
  *content* ACs (problem statement, assumptions) and never for *process* ACs
  that name the decision itself.
- **A4** — Mapping the workflow in the designer will surface transitions that no
  prose reading has, because the corpus forces every state and edge to be named
  (the T-2624 `aef-task-lifecycle` precedent).

## Open Questions

- **IW-1: Should the recommendation be required at filing time, at review time, or both with different names?**
  confidence: 2
  disposition: deferred
  rationale: Leaning "both, named differently" — a `prior:` at filing (explicitly falsifiable, rendered as such) and a `recommendation:` at review. This preserves what T-679/T-2204 bought without letting a prior masquerade as a finding. Needs the operator's call.

- **IW-2: May `@auto-tick-on-decide` ever tick a `### Human` AC?**
  confidence: 3
  disposition: deferred
  rationale: Almost certainly no — CLAUDE.md says "NEVER check a ### Human AC", and T-2857 shows the marker doing exactly that. Confidence is high but the change is the operator's, since it alters what a decide does.

- **IW-3: Should the decide preflight require agent ACs at all?**
  confidence: 1
  disposition: deferred
  rationale: T-2862 shows it deadlocks on process ACs. Options: exempt self-referential ACs, require only content ACs, or drop the requirement and let the recommendation carry the burden. Undecided.

- **IW-4: What is the correct C-001 artifact timing under a write guard?**
  confidence: 1
  disposition: deferred
  rationale: The artifact-first rule is right (T-194: conversations are ephemeral). The collision is with background-session isolation. Fix may be config (T-2861 `bgIsolation=none`) rather than workflow, but the workflow should not assume an unguarded write.

- **IW-5: Where does the designer map draw the human/agent authority boundary?**
  confidence: 1
  disposition: deferred
  rationale: T-2857's decision arrived via `--skip-sovereignty` from a path that is agent-blocked under `$CLAUDECODE=1`. The map must make explicit which lane each transition belongs to, and which bypasses are legitimate. This is what the designer is for.

## Exploration Plan

- **S-1 — seed the map.** Draft `aef-inception-lifecycle` in the designer corpus
  following the arc-014 pair-draft ritual: agent seeds the skeleton, operator
  edits in the UI, agent re-reads and normalises, iterate to promotion. Lanes at
  minimum: Agent, Framework-Authority, Human. Model the filing→exploration→
  recommendation→decide→build-slices path with every gate as an explicit node.
- **S-2 — walk the five instances across the map.** Each should land on a
  specific node or edge. Any instance that has no place on the map means the map
  is wrong, not the instance.
- **S-3 — conformance.** Reuse the T-2621 rail: audit map-vs-code transition
  parity, so the map cannot drift from `lib/inception.sh` / `update-task.sh`.

## Technical Constraints

- The corpus is authoritative for the map; edits round-trip through the served
  designer, so the skeleton must be valid on first write (lint baseline is
  checked).
- `fw corpus prove` is **destructive on the live store** — do not run it against
  the working corpus.
- Any change to the decide path touches `lib/inception.sh` and
  `agents/task-create/update-task.sh`, both of which have hook consumers; per
  L-399 / T-1890, a bypass contract must ship on every gated path at once.

## Scope Fence

**IN:** the filing→decision path — recommendation-completeness gate,
`@auto-tick-on-decide`, decide preflight AC requirement, C-001 timing,
agent-vs-human decide authority, and the seed tasks that instantiate all of it.

**OUT:** BVP scoring, arc lifecycle, and the T-2857 CLI-suite gate (own chain).

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

**Rationale:** Five concrete instances inside two weeks, four of them hit live this session. (1) T-2862: the greenfield seed ships a self-referential AC that deadlocks fw inception decide in every new project. (2) T-2442: prior sibling, inception schema deadlock. (3) T-2857: the decision was recorded mid-exploration with --skip-sovereignty, auto-ticking the ### Human [REVIEW] AC, and the recorded rationale was the filing-time prior verbatim with an empty Evidence block — which the spike then refuted 40 minutes later. (4) T-2861: C-001 demands the research artifact as the FIRST act of an inception, which is exactly when Claude Code's background-session guard refuses Write. (5) The T-2204 recommendation-completeness gate REQUIRES a GO/NO-GO/DEFER at filing time, before any exploration exists, and @auto-tick-on-decide then promotes that untested prior into the recorded decision. The last one is the root: the framework asks for the conclusion before the evidence, then treats the answer as the finding. GO on the rework; the design is the open question, which is what this inception is for. Filed with a GO at creation time because the gate requires one — this task is its own worked example.

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

### 2026-08-07T17:34:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
