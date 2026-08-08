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
- **A2** — ~~`@auto-tick-on-decide` ticking a `### Human` AC is always wrong, and
  no current workflow depends on it.~~ **FALSIFIED (F-6).** Ticking the approval
  AC is the function's stated purpose (T-1324) and it prevents a real
  partial-complete leak (G-008). What is wrong is the *inference*: the tick reads
  "a command ran" and writes "a human approved", while `decide` has three
  non-human entry paths. Revised: the tick must be conditioned on the authority
  channel, not removed.
- **A3** — The decide preflight's agent-AC requirement is load-bearing for
  *content* ACs (problem statement, assumptions) and never for *process* ACs
  that name the decision itself.
- **A4** — Mapping the workflow in the designer will surface transitions that no
  prose reading has, because the corpus forces every state and edge to be named
  (the T-2624 `aef-task-lifecycle` precedent).

## Open Questions

- **IW-1: Should the recommendation be required at filing time, at review time, or both with different names?**
  confidence: 3
  disposition: deferred
  rationale: Sharpened by F-8 — the prior/finding distinction is ALREADY in the template, as prose inside the Evidence placeholder ("the filing-time recommendation can be revised before fw inception decide"), with zero enforcement. So the cheap answer is not a schema split but a predicate: require Evidence to be non-placeholder at decide time (F-7 shows only the `**Recommendation:**` line is checked today). Recommend: keep filing-time required, rename it `prior:` in rendering, and gate decide on evidence. Operator's call.

- **IW-2: May `@auto-tick-on-decide` ever tick a `### Human` AC?**
  confidence: 3
  disposition: deferred
  rationale: **Reframed by F-6 — my prior answer here was wrong.** Ticking the approval AC is the function's stated purpose (T-1324) and removing it re-opens the G-008 partial-complete leak. The defect is that the tick infers "a human approved" from "decide ran", while decide admits `--i-am-human` / `--from-watchtower` / `--skip-sovereignty`, and a third caller (`do_inception_sweep:866`) ticks in batch with no decide at all. Recommend: tick only on human-authenticated channels; on `--skip-sovereignty` leave it unticked. Operator's call because it changes what a decide does.

- **IW-3: Should the decide preflight require agent ACs at all?**
  confidence: 2
  disposition: deferred
  rationale: T-2862 shows it deadlocks on process ACs — the AC names the decision the gate is blocking. The gate itself is load-bearing (T-1503: without it, decide poisoned the body then failed P-010, and retries appended duplicate Updates). So: keep the gate, kill the self-referential AC class. Recommend exempting ACs whose text names the decide command, and fixing the seed (T-2862) so the class stops being generated. Operator's call on whether to exempt or to forbid at author time.

- **IW-4: What is the correct C-001 artifact timing under a write guard?**
  confidence: 2
  disposition: deferred
  rationale: The artifact-first rule is right (T-194: conversations are ephemeral). The collision is with background-session isolation, and the guard's own advice (enter a worktree) is wrong for AEF because governance state is tracked and a worktree forks it (T-2821/T-2822). Recommend: fix in config, not workflow — `fw init` emits `worktree.bgIsolation=none` (T-2861) — but the workflow must stop assuming an unguarded write, so C-001 should state the artifact is written to the main checkout. Operator's call.

- **IW-5: Where does the designer map draw the human/agent authority boundary?**
  confidence: 3
  disposition: answered
  rationale: It does not draw it at all — `aef-inception-flow` has two lanes (Agent, Human) where the authority model has three, and all five failure instances are Framework-Authority actions. Artifact F-2.

- **IW-6: Does the map codify the process, and can it be made deterministic for the code to follow?**
  confidence: 3
  disposition: answered
  rationale: No and yes. 1 of 6 maps carries authority (`aef-task-lifecycle`, transition-table, detail-authority); inception is `vocabulary-set` — green means GO/NO-GO/DEFER appear on both sides, nothing more. Determinism is proven once and is generative: `status-transitions.yaml` is READ at runtime by `lib/enums.sh:4,14`, `create-task.sh:205,416`, `web/blueprints/tasks.py:151-163`, and the rail compares the map to it. Artifact F-4/F-5.

- **IW-7: Can the inception map be promoted to detail-authority before the Framework lane exists?**
  confidence: 3
  disposition: answered
  rationale: No — and this is a forced ordering, not a preference. A transition-table rail can only check transitions that exist as nodes; with the gates still encoded as notes on Agent nodes, promotion would make the map outrank CLAUDE.md prose while staying blind to all five failures. False green, strictly worse than descriptive-only. Artifact F-5.

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
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

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

**Recommendation:** GO — and the shape changed materially from the prior below.

**What changed from the filing-time prior.** The prior (kept verbatim further down,
because this task is its own worked example) said *"GO on the rework; the design is
the open question."* That was a placeholder standing in for evidence the gate
demanded before any existed. The design is no longer open, and the root moved
twice under evidence:

- **From field to transition.** I framed the root as a *field* problem — the
  recommendation is requested too early. The operator reframed it as a
  *transition* problem — the inception is put forward for approval before the
  requirements for putting it forward are met. Tested mechanically and it holds:
  the put-forward verb (`lib/review.sh` `emit_review`) validates one grep for a
  `**Recommendation:**` line and nothing else, while the readiness predicate that
  *would* catch an unfinished record (`check_disposition_gate`) is wired to
  `work-completed` — one transition downstream of the approval it should guard.
- **From timing to representation.** Timing is the mechanism; the reason it went
  unseen is that all five instances are **Framework-Authority** actions and the
  inception map had no Framework-Authority lane, so every gate was drawn as a
  parenthetical on an Agent node. Same words, two readings, only one actionable.
- **A2 falsified.** I asserted that `@auto-tick-on-decide` ticking a `### Human`
  AC was a leak. Reading `lib/inception.sh:292` shows ticking is the function's
  documented purpose (T-1324) and removing it reopens G-008. The defect is the
  *inference* — it reads "decide ran" and writes "a human approved", while decide
  admits `--i-am-human` and `--from-watchtower`, and `do_inception_sweep` ticks the
  same box in batch with no decide at all.

**Rationale:** Five concrete instances inside two weeks, four of them hit live this session. (1) T-2862: the greenfield seed ships a self-referential AC that deadlocks fw inception decide in every new project. (2) T-2442: prior sibling, inception schema deadlock. (3) T-2857: the decision was recorded mid-exploration with --skip-sovereignty, auto-ticking the ### Human [REVIEW] AC, and the recorded rationale was the filing-time prior verbatim with an empty Evidence block — which the spike then refuted 40 minutes later. (4) T-2861: C-001 demands the research artifact as the FIRST act of an inception, which is exactly when Claude Code's background-session guard refuses Write. (5) The T-2204 recommendation-completeness gate REQUIRES a GO/NO-GO/DEFER at filing time, before any exploration exists, and @auto-tick-on-decide then promotes that untested prior into the recorded decision. The last one is the root: the framework asks for the conclusion before the evidence, then treats the answer as the finding. GO on the rework; the design is the open question, which is what this inception is for. Filed with a GO at creation time because the gate requires one — this task is its own worked example.

**Evidence:**

- **The put-forward verb checks one third of its own printed contract.**
  `lib/task-audit.sh:117` `audit_inception_recommendation` greps for a
  `**Recommendation:**` line; `lib/inception.sh:493-496` prints a three-part
  contract naming Rationale *and* Evidence. Rationale and Evidence are never read.
  (F-7)
- **The readiness predicate exists and fires one transition too late.**
  `agents/task-create/update-task.sh:768` and `:1583` — `check_disposition_gate`
  is called only when `NEW_STATUS = work-completed`, i.e. downstream of the
  approval it should guard. `disposition: deferred` also satisfies it, so an
  unanswered question passes a gate that asks only whether a disposition string is
  present. (F-11)
- **The template knows the recommendation is a prior and nothing enforces it.**
  `lib/inception.sh:178-210` `_inject_recommendation_block` writes the Evidence
  placeholder *"The filing-time recommendation can be revised before fw inception
  decide."* — documented intent, zero enforcement. (F-8)
- **Three machines can write or ratify a recommendation and none requires
  evidence**, and a fourth (`lib/reviewer/recommendation_claims.py`) stamps an
  empty one **CONFIRMED**, because it checks referent *existence* (`T-XXX` resolves
  to a task file), not claim support. Its own docstring says "advisory only".
  (F-9, F-10)
- **`--skip-sovereignty` is not an operator bypass** — `fw inception decide` has
  exactly two (`--i-am-human`, `--from-watchtower`, `lib/inception.sh:429`);
  `--skip-sovereignty` is what decide passes *downstream* to `update-task.sh`
  (lines 684, 705, 716). Correction to my own earlier claim. (S-2)
- **DEFER skips the agent-AC preflight entirely.** `lib/inception.sh:521` guards it
  with `if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]`. So T-2862's
  deadlock is escapable by hedging, and there is a mechanical gradient toward the
  exact hedge CLAUDE.md forbids in prose (T-2144) and T-2145 ships a detector for.
  (F-17)
- **Every one of the five instances is a Framework-Authority action** and the
  inception map has no Framework-Authority lane — 5/5, tabulated against the
  corpus, where `aef-tier0-escalation` and `draft-trigger-handling` both have one.
  (F-2)
- **The fix needs no designer extension** — the Framework lane, the readiness
  gateway and the named return edges are all constructs the corpus already ships,
  verified before proposing any tool change. (F-14)
- **Draft seeded and iterated through a full pair-draft round**:
  `.context/designer/projects/draft-inception-readiness/` v1 → operator layout →
  agent re-read/normalise → v2 (17 nodes / 18 flows / 3 lanes). Served bytes
  verified byte-identical to disk (sha256 `fe3a520d…a846`).
- **The draft was then walked against its own purpose and mostly failed.** S-2:
  only **1 of 5** instances attaches to v2 — the decide-preflight has no node at
  all (instances 1, 2), the write guard is a note on an *Agent* node reproducing
  the very defect F-2 diagnosed (instance 4), and the bypass edges are undrawn
  (instance 3). This is evidence *for* GO, not against: the walk is what turned a
  plausible map into a specified one.
- **832 (peer designer agent) confirmed the notation is not moving** (rail 444) —
  `aef-bpmn-mapping-v1.md:42-45` untouched, Part I frozen — so the draft is
  authored against a stable clause. Their fidelity-probe offer for the
  cycle-through-subProcess shape is taken up (rail 445).

**Candidate build slices on GO** (one deliverable each, per Task Sizing — not to be
built under this ID):

1. **Readiness floor at the put-forward transition** — move/duplicate the
   disposition predicate to `emit_review`, checking the agent's proposal against
   the agent's own record: no `blocking: true` IW unanswered, Evidence placeholder
   no longer intact, Dialogue Log present. Content-blind and deterministic.
2. **`blocking:` field on Open Questions** — the mechanical half of slice 1.
3. **Not-ready as router** — the deficit class names the mode owed (research /
   testing / dialogue) so a block becomes a work item.
4. **F-17 DEFER asymmetry** — include `defer` in the preflight guard, or state the
   reason it is exempt.
5. **Tick on authenticated channel only** — `--from-watchtower` ticks the approval
   AC; bypasses leave it unticked, which is the honest state.
6. **Map v3 + conformance rail (S-3)** — blocked on the operator's
   as-operated-vs-proposed ruling (see Open Decisions).
7. **Vendor + pin the frozen standard** (F-18 / OBS-190) — precondition for
   ratifying anything on the 832 fence.

**Open decisions for the operator** (none block GO; all shape the slices):

- Does `decision?` belong in the Agent lane, or does the gateway move to Framework?
- Do research and testing want separate not-ready return edges, or one?
- Is `draft-inception-readiness` a map of **as-operated** or **proposed** behaviour?
  v2 currently mixes both, and S-3's rail cannot audit map-vs-code parity until we
  say which nodes claim parity.
- Ratify `doc`-as-`workflowMeta`-attribute into the frozen standard? 832 supports
  it and wants it classed semantic in §1 with a migration note for our four maps.
  Our fence, our version bump — and currently blocked by F-18.

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
