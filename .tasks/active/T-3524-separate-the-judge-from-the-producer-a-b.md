---
id: T-3524
name: "separate the judge from the producer: a BVP scoring reviewer agent and an arc-driver
  reviewer agent"
description: >
  Operator proposal 2026-09-27, responding to the producer-not-judge waiver recorded
  in D-661/T-3523: 'we should use the external reviewer for that, right? We should
  then have a BVP agent for that. A BVP and an ArcScopeDriver agent or two agents.'
  THE PROBLEM IT SOLVES: D-661 legs 1+2 let an agent confirm its own task's value
  scores and tune its arc's driver weights. Taking the human out of the path removed
  the only party that was not the producer. An independent reviewer AGENT restores
  the separation without putting the operator back in the loop — the human keeps the
  sticky override (T-3523) rather than the approval step. WHAT ALREADY EXISTS, so
  this is not built from nothing: (a) agents/termlink/bvp-estimator/ PROPOSES task
  scores by heuristic; (b) lib/arc-driver-review.sh is an external value-driver reviewer
  but a STATIC check, answering scorable/distinct/distinguishes — it never judges
  whether a score is RIGHT; (c) T-1951 established the isolated-reviewer-as-TermLink-worker
  pattern (fw reviewer --dispatch). So the missing party is a JUDGE, and the pattern
  for running one already ships. THE SHARP QUESTION, and the reason this is an inception
  and not a build: if ONE agent both approves the drivers (the yardstick) and scores
  tasks against them (the measurement), it is judging with a yardstick it made — the
  same defect one level up. Two agents preserve that separation; one agent is cheaper
  to maintain and shares the rubric. Scope is >3 new files and a new subsystem, so
  G-020 requires inception.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [bvp, arc, agents, producer-not-judge]
components: []
related_tasks: [T-3523, T-3429, T-1951, T-3410]
created: 2026-09-27T19:20:38Z
last_update: 2026-09-27T19:22:35Z
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
  - ts: '2026-09-27T19:22:36Z'
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

# T-3524: separate the judge from the producer: a BVP scoring reviewer agent and an arc-driver reviewer agent

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## The four parties, and which one is missing

| party | exists? | what it does |
|---|---|---|
| **producer** | yes | the agent doing the work, which under D-661 also confirms its own scores |
| **proposer** | yes — `agents/termlink/bvp-estimator/` | heuristic, writes `bvp_scores_proposed:` / `cost_estimate_proposed:` |
| **driver quality checker** | yes — `lib/arc-driver-review.sh` (T-3429) | STATIC: scorable / distinct / distinguishes. Never asks whether a score is *right* |
| **judge** | **NO** | nothing independently reviews a proposed score and confirms it |

The operator keeps a fifth role that is not a party to the judgement: the **sticky
override** (T-3523). That is deliberate — it is a veto after the fact, not an approval
step in the path.

## The argument for TWO agents rather than one

A scoped driver is the **yardstick**. A task score is the **measurement**. One agent
holding both is judging with a yardstick it made — producer-not-judge reproduced one
level up, which is the exact defect this proposal exists to close.

Cost of two: two AGENT.md prompts, two dispatch paths, some duplicated rubric
knowledge. Cost of one: the separation this is being built for.

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

- **IW-1: One agent or two?**
  confidence: 2
  disposition: deferred
  rationale: Leaning two. A scoped driver is the yardstick, a task score is the
  measurement, and one agent holding both judges with a yardstick it made. Deferred to
  the operator: it changes the file layout materially, and two prompts is a real
  maintenance cost he is entitled to weigh against the separation it buys.

- **IW-2: Does the judge get to REFUSE a score, or only flag it?**
  confidence: 1
  disposition: deferred
  rationale: A refusal makes the reviewer a gate and puts a second agent in the
  critical path of every close — the T-3297 contention class, hit live twice today. A
  flag makes it advisory and therefore ignorable, which is how `[REVIEWER]` adoption
  reached 7 against 412 for `[REVIEW]` (T-1878). Neither is obviously right.

- **IW-3: What does the judge judge AGAINST?**
  confidence: 1
  disposition: deferred
  rationale: The static driver reviewer answers scorable / distinct / distinguishes —
  structural questions. "Is D2=4 right for this task" is not structural, and the
  measured D2 no-signal rate of 83% over 3,350 tasks (T-3408) says the rubric's own
  detectors cannot answer it either. A judge with no readable yardstick is a judge in
  name only. This question may dissolve T-3410 into it, or be blocked by it.

- **IW-4: New scores only, or the 3,350 already scored?**
  confidence: 2
  disposition: deferred
  rationale: Reviewing at confirm time and retro-reviewing the corpus are
  different-sized projects. Scoping must say which, because "it applies to everything"
  is how a reviewer becomes a 3,350-item backlog nobody runs.

- **IW-5: May the judge be the same MODEL as the producer?**
  confidence: 1
  disposition: deferred
  rationale: Independence of PARTY is not independence of JUDGEMENT. Two instances of
  one model sharing a rubric can agree for the same wrong reason — and T-3408 measured
  exactly that shape across two independent corpora (D2 83% vs 84%, different authors
  and domains, same blind spot). Worth deciding deliberately rather than by default.

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

**Rationale:** GO on the exploration, with a stated leaning: TWO agents, because a single agent that both defines the yardstick (arc-scoped drivers) and applies it (task scores) reproduces producer-not-judge one level up, which is precisely the defect the operator is trying to close. Evidence this is tractable rather than speculative: three of the four parties already exist — the estimator proposes (agents/termlink/bvp-estimator/), the static driver reviewer checks driver quality (lib/arc-driver-review.sh, T-3429), and T-1951 already runs a reviewer as an isolated TermLink worker with results on the fw bus. What is missing is the judging half and the handoff. Not a build task: >3 new files and a new subsystem, so G-020 requires scoping first, and the one-agent-or-two question changes the file layout materially.

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

### 2026-09-27T19:22:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
