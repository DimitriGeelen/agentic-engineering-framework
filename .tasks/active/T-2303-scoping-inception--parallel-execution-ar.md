---
id: T-2303
name: "Scoping inception — parallel-execution architecture (AEF + TermLink coordination)"
description: >
  Inception: Scoping inception — parallel-execution architecture (AEF + TermLink coordination)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-1641, T-1643, T-2302]
arc_id: orchestrator-rethink
created: 2026-06-10T07:57:45Z
last_update: 2026-06-10T08:01:47Z
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
  - ts: '2026-06-10T08:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-10T08:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2303: Scoping inception — parallel-execution architecture (AEF + TermLink coordination)

## Problem Statement

Two architecture decision records (companion AEF + TermLink-substrate ADRs, landed by T-2302 at `docs/architecture/parallel-execution-aef.md` and `docs/architecture/parallel-execution-substrate.md`) describe a large multi-layer, cross-repo change: move AEF from single-agent / shared-tree / single-writer execution to multiple agents executing concurrently across ring20, coordinated through TermLink. The design is dense, has multiple independent go/no-go calls, and depends on TermLink substrate primitives that do not yet exist (claim/exclusive delivery, idle/busy registry, pull/assign verb, reconnect/outbound queue, filesystem-write observation).

Before any of that work begins, **scoping coherence** is at risk: the design factors into 3-5 independent decision points (§2-3 disjoint write-sets, §4 active dispatcher, §5 sidecar+harness, §6 open questions, §8 substrate contracts), bundled into one filing they collapse into an all-or-nothing decision (CLAUDE.md "umbrella inceptions" anti-pattern). The operator's standing concern, voiced explicitly at this inception's origination: *"we lose focus and do not get proper scoping and coherence established."*

**This inception's job is to decide HOW the design work gets decomposed, sequenced, and arc-placed — not to decide whether the design itself is right.** The design's *correctness* is a downstream design-of-record inception (or set of inceptions) that this scoping inception schedules.

**Stakeholder:** the operator (sole decision-maker for AEF + TermLink across the ring20 homelab). **Why now:** the design has crystallised across multiple prior sessions; the operator has authorised significant cost ("allowed to bear significant costs"); the next move is choosing the shape of the next moves.

## Assumptions

Key assumptions to validate during exploration. Register each with `fw assumption add` as the spike that addresses it begins. The bare list is captured here so the assumptions are visible at filing time.

- A1: The two ADRs (AEF + substrate) are stable enough that scoping them is well-defined work — i.e. we are not racing a design that is still flowing.
- A2: The TermLink-side has an authoritative party (an agent, an operator role) we can engage about the §8 substrate-contracts question via a known mechanism (pickup, `fw pending`, `termlink remote inject`, or a session attach).
- A3: arc-003 (orchestrator-rethink) is the right arc home for this work; an alternative is a sibling arc.
- A4: The recommendation "before every file-write tool call" yield-point granularity (AEF §6 first open question) is the leading candidate but not yet pinned; downstream §5 inception must resolve it.
- A5: The operator's "significant cost" authorisation extends to multiple downstream inceptions and a multi-month build, not just to this scoping inception.

## Open Questions

These are the load-bearing scoping questions. Each maps to an exploration spike. All start `deferred` at filing time; the disposition gate fires only at `--status work-completed`. Each disposition rationale will cite the dialogue segment or evidence that resolved it.

- **IW-1: What is the testable headline mechanic / success criterion for the whole parallel-execution effort?**
  confidence: 0
  disposition: deferred
  rationale: To be resolved by Spike 1 (goals/headline-mechanic dialogue). Candidate framing: *"two agents on disjoint-write-set tasks complete concurrently, integrate via the hub, with zero governance-plane corruption and zero un-decomposed coordination overhead, observable from wire evidence X."* Without this, every downstream inception has fuzzy success criteria.

- **IW-2: Single arc (extend arc-003 orchestrator-rethink) or multi-arc (sibling AEF + TermLink-side arc + possibly more)?**
  confidence: 0
  disposition: deferred
  rationale: To be resolved by Spike 2 (arc-shape). Substrate ADR §9 makes the cross-repo split first-class — arc placement must reflect that. Tradeoff: arc-003 is already in-progress (3 active constituents) and aligned with this trajectory; opening a new arc fragments closure evidence. Default-to-OPEN per §ACD/G-062 applies to whichever arcs host this work.

- **IW-3: When and how does AEF first engage TermLink about the §8 substrate-contracts question?**
  confidence: 0
  disposition: deferred
  rationale: To be resolved by Spike 3 (TermLink coordination). Substrate ADR §9 says producer (TermLink) ≠ judge; AEF signs off consumer-validation. Open: timing (before/parallel/after AEF-side downstream inceptions), first-contact mechanism (`fw pending register` / TermLink pickup / `termlink remote inject` to their session / out-of-band), and contract artifact shape (extract from substrate ADR vs. dedicated contract doc). The load-bearing scoping question.

- **IW-4: What is the full downstream inception cluster, in what order, with what dependencies?**
  confidence: 0
  disposition: deferred
  rationale: To be resolved by Spike 4 (inception cluster). Candidate cluster: (a) design-of-record inception (ratify the ADRs as spec), (b) §2-3 disjoint-write-set policy inception, (c) §4 active-dispatcher architecture inception, (d) §5 sidecar+cooperative-poll harness inception, (e) §6 open-question resolution inception(s), (f) TermLink-side §8 substrate-contracts inception. Order and dependencies need to fall out of A2 + IW-3 resolution.

- **IW-5: Where does the design-of-record live and how is it kept in sync?**
  confidence: 1
  disposition: deferred
  rationale: To be resolved by Spike 5 (artifact placement). Partial answer: the ADRs landed at `docs/architecture/parallel-execution-aef.md` (this repo authoritative) and `docs/architecture/parallel-execution-substrate.md` (TermLink-authoritative reference copy) by T-2302. Open: re-sync mechanism for the substrate copy, governance of updates (TermLink-side owns substrate doc; what's the receipt/sync protocol?), and whether a separate "design-of-record" inception is needed to ratify the ADRs themselves or whether ratification is folded into the downstream §2-3/§4/§5 inceptions.

## Exploration Plan

Each spike is operator-facing dialogue work, not autonomous agent work. The inception's research artifact at `docs/reports/T-2303-scoping-parallel-execution-aef.md` accumulates findings as each spike resolves (C-001 research artifact + dialogue log per CLAUDE.md §Inception Discipline).

- **Spike 1 — Goals & headline mechanic** (IW-1).
  Time-box: 1 dialogue session.
  Method: operator + agent jointly draft 2-3 candidate headline-mechanic statements, pick one, write the wire-evidence test that would falsify "we shipped this." Output: a paragraph in the research artifact under `## Goals` with the chosen statement and an explicit `## Wire Evidence Test` block.

- **Spike 2 — Arc shape** (IW-2).
  Time-box: ~30 minutes dialogue after Spike 1.
  Method: list arc-shape options (extend arc-003 / new AEF-side sibling / multi-arc), score each against §ACD/G-062 (default-to-OPEN, headline-mechanic discipline), pick. If the pick is arc-003-extension, no `fw arc create` needed; if a new arc, the create command surfaces to operator (NOT Sovereign-gated per memory). Output: a decision block in research artifact under `## Arc Shape`.

- **Spike 3 — TermLink coordination** (IW-3, load-bearing).
  Time-box: 1 dialogue session + 1 contact round-trip.
  Method: (a) operator confirms TermLink-side has an authoritative party we can reach (A2 validates). (b) agent + operator draft the first-contact message naming the §8 contract list + asking for confirm-or-redraw. (c) message goes via the chosen mechanism (`fw pending register` is the framework-native default; TermLink pickup or `termlink remote inject` are alternatives). (d) await response; resolution of IW-3 captures *what we asked, how, and what they replied*. Output: a transcript block in research artifact under `## TermLink Coordination` + a decision on first-contact-timing relative to AEF-side downstream inceptions.

- **Spike 4 — Downstream inception cluster** (IW-4).
  Time-box: ~45 minutes dialogue after Spike 3.
  Method: enumerate the inceptions, draw the dependency DAG, choose an order. Validate against "one inception = one question." Outputs: a numbered list in research artifact under `## Inception Cluster` with each inception's name, scope-one-line, predecessor inception(s), and predecessor evidence.

- **Spike 5 — Artifact placement & sync** (IW-5).
  Time-box: ~20 minutes dialogue.
  Method: confirm the docs landed at `docs/architecture/` are the design-of-record (or pick an alternative); design the substrate-doc re-sync protocol (manual diff vs. cron sync vs. on-update pickup); decide whether a separate design-of-record inception is needed. Output: a paragraph in research artifact under `## Artifact Placement`.

Each spike's resolution updates the corresponding IW-N entry (confidence 0→3, disposition deferred→answered, rationale citing the dialogue segment + research-artifact section). The disposition gate fires at `--status work-completed`.

## Technical Constraints

- **Cross-repo dependency.** TermLink (Rust workspace, separate repo) owns the substrate ADR and the §9 collaboration seam. We cannot unilaterally commit to substrate primitives; sign-off (producer ≠ judge per substrate §9) is bilateral.
- **Sovereignty gates on inception decisions.** `fw inception decide` is `$CLAUDECODE=1`-blocked — operator-only. `fw arc create` is NOT gated; agent can run it. `fw arc close` IS Sovereign-gated. `fw pending register` is agent-runnable.
- **Recommendation-completeness gate (T-2204).** Any downstream inception must be filed with `--recommendation DEFER + --rationale` at minimum (the inception's job is to *gather* evidence; legitimate evidence-gap DEFER).
- **Render-surface gate (P-013).** Not triggered by this inception (no `web/templates/`, `web/static/`, `web/blueprints/`, `web/shared.py` edits).
- **Build-task scope gate (G-020).** Downstream build tasks (post-inception) require real ACs before source edits.
- **The agent's authority limit.** Per CLAUDE.md §Authority Model, agent has initiative not authority. Decisions in spikes 1-5 are operator-recorded; agent proposes and records.

## Scope Fence

**IN scope (this inception decides these):**
- IW-1 headline mechanic / success criterion for the parallel-execution effort
- IW-2 arc placement of this work and its progeny
- IW-3 TermLink coordination timing, mechanism, contract artifact
- IW-4 enumeration and ordering of downstream inceptions
- IW-5 design-artifact placement and re-sync protocol

**OUT of scope (deferred to downstream inceptions):**
- Ratifying the ADRs as design-of-record (separate inception, per IW-5 resolution)
- §2-3 disjoint write-set policy details
- §4 active-dispatcher implementation strategy
- §5 sidecar/cooperative-poll harness design specifics
- §6 open-question resolution (yield-point granularity, heartbeat tick/threshold, flag shape, scale ceiling, optimistic-flip criteria)
- §8 substrate-contracts shape (TermLink-side own work)
- Any source code changes anywhere in AEF or TermLink

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
- All five spikes resolved with operator-confirmed dispositions (IW-1..IW-5 disposition = answered)
- TermLink coordination outcome captured (Spike 3): either bilateral confirm-or-redraw response received, or a documented decision to sequence AEF-side downstream inceptions first with TermLink engagement explicitly deferred to a named later trigger
- Downstream inception cluster + order documented (Spike 4), with at least the first downstream inception named and ready to file post-decision
- Arc placement decision committed (Spike 2)
- Research artifact `docs/reports/T-2303-scoping-parallel-execution-aef.md` carries dialogue log + per-spike findings

**NO-GO if:**
- Spike 1 cannot pin a falsifiable headline mechanic — reverts to "no testable outcome" which signals the wider effort is mis-scoped at the design level (kicks back to ADR authors, not to a build)
- Spike 3 reveals TermLink-side is not yet ready to commit to substrate-primitive contracts AND no useful "engage later under condition X" pre-arrangement is achievable — separate sub-inception on "what does TermLink need before §8 contracts are possible" gets filed instead, and this scoping inception NO-GOes pending that resolution
- Operator decides during exploration that the design as captured in the ADRs is not the right design (kicks back to design dialogue, not to this scoping work)

**DEFER if:**
- Spike 3 surfaces a TermLink-side blocker (e.g. an in-flight TermLink design session that materially changes substrate assumptions) whose ETA is bounded but external. Concrete revisit trigger + date logged via `revisit_at:` / `revisit_evidence_needed:` frontmatter.

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

**Recommendation:** DEFER

**Rationale:**

Scoping inception; recommendation lands after exploration spikes (goals, arc shape, TermLink coordination, downstream inception cluster, artifact placement) resolve. Legitimate evidence-gap DEFER per T-2144 — this inception's job is to gather the evidence.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

### 2026-06-10T08:01:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
