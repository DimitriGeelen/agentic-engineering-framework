---
id: T-3396
name: "Peer-consult sidecar: real always-on listener per agent session, cooperative
  yield-point delivery"
description: >
  Inception: Peer-consult sidecar: real always-on listener per agent session, cooperative
  yield-point delivery

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [termlink, peer-consult, sidecar, cross-repo, architecture]
components: []
related_tasks: [T-2918, T-1820, T-1135, T-1140, T-2323, T-1804, T-1818, T-1819, 
      T-2409]
created: 2026-09-20T21:54:20Z
last_update: 2026-09-20T22:19:04Z
date_finished: 2026-09-20T22:19:04Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 5            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
                                  # M: new sidecar process + lib/peer.py integration + possible cross-repo TermLink change.
voi_score: 0.7                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
                                  # High: unblocks T-1820/arc-003's headline mechanic; resolves a design that has
                                  # been agreed-but-unbuilt twice (T-1135 April GO, arc-011 ADR) across 5+ months.
bvp_scores_proposed:
  - ts: '2026-09-20T21:56:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 4
      D4: 4
      F-RECALL: 4
      F-AUTONOMY: 4
      F3: 4
      F1: 4
      F2: 4
    rationale: D1=4 (no-signal); D2=4 (no-signal); D3=4 (no-signal); D4=4 
      (no-signal); F-RECALL=4 (no-signal); F-AUTONOMY=4 (no-signal); F3=4 
      (no-signal); F1=4 (no-signal); F2=4 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-20T22:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 4
      effort: 8
    rationale: blast_radius=5 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=8 (lines=285,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3396: Peer-consult sidecar: real always-on listener per agent session, cooperative yield-point delivery

## Problem Statement

`fw peer subscribe` (the mechanism that should let this framework react live to
cross-agent peer-consult messages arriving via TermLink) has never actually been
able to observe them — confirmed by direct reproduction against TermLink source
(T-2918 Investigation, 2026-09-20). The root cause is structural, not a bug: the
subscriber is a cron-driven 30s poll-once, and TermLink's hub-level event
broadcast has no cursor/replay — there is no way to ask "what did I miss."

This is the second time this exact class of gap has been named. T-1135
(2026-04-12) designed and got cross-repo agreement on an "always-listening
receptionist" — a persistent per-project agent session, exempted from
TermLink's cleanup cron, that never goes deaf. It reached a clean **GO**
decision the same day. It was never built — the only follow-up (T-1140) was a
duplicate self-pickup, correctly DEFERRED as noise five months ago, and nothing
replaced it. The design aged in place.

Separately, arc-011 (`parallel-execution-aef`) independently designed and
adversarially reviewed ("Grill Me") the *delivery* half of the same problem for
a different use case (write-collision prevention between parallel dispatch
workers): `docs/architecture/parallel-execution-aef.md` §5. It explicitly
considered and rejected PTY-injection-on-apparent-idle (an agent mid-turn is
uninterruptible; no external watcher can prove a true safe point), and chose
instead: a cheap, deterministic (non-LLM) sidecar that holds the connection and
writes a flag + heartbeat, with the *agent's own harness* cooperatively polling
that flag at a yield point it controls. Only a stripped single-host sliver of
this (`agents/dispatch/yield-point.sh`) was ever built, scoped narrowly to
file-write collision refusal — no sidecar process, no heartbeat, no priority
byte exist anywhere in the codebase today.

**Why now:** the operator, re-describing this "sidekick" idea from memory in a
2026-09-20 dialogue (see T-2918 Decisions and this task's Dialogue Log below),
independently reconstructed T-1135 + arc-011 §5's design and explicitly chose
to build the real thing rather than accept any of T-2918's four narrower
band-aids. This inception exists to turn "we agreed on this twice and never
built it" into a scoped, buildable spec — and to resolve the parts that were
never decided (only guessed) in either prior pass.

## Assumptions

<!-- Registered via `fw assumption add`, see Updates below for A-XXX ids -->

## Open Questions

- **IW-1: What yield-point granularity is right for peer-consult delivery?**
  confidence: 0
  disposition: deferred
  rationale: arc-011 §5's leading candidate ("check before every file-write
    tool call") was chosen for write-collision prevention, where the yield
    point IS the danger point. Peer-consult messages (design questions,
    escalations, triage) have no obvious equivalent trigger — checking only
    before writes could mean a read-only or dialogue-only stretch of work
    never notices an urgent message at all. No evidence gathered yet on what
    granularity peer-consult actually needs; this is the first thing to work
    through with the operator, not something to default from the sibling
    use case.

- **IW-2: What heartbeat tick/threshold values are safe?**
  confidence: 0
  disposition: deferred
  rationale: arc-011 §6 left "5s tick / 30s threshold (six missed beats)" as
    an explicit, unvalidated placeholder ("Unresolved number"). No load or
    responsiveness testing has ever been done against real TermLink hub
    behaviour. Needs at minimum a spike against a live hub before being
    treated as more than a guess.

- **IW-3: What should the flag shape actually carry?**
  confidence: 1
  disposition: deferred
  rationale: arc-011 §6 leaned "dirty-bit + single highest-priority byte,
    details fetched on yield" but never built it, and never needed to carry
    routing information (its use case is single-topic: "don't write here").
    Peer-consult messages route to different workflows (design-consult /
    escalation-triage / triage / fallback per `.context/peer-consult-prompts.yaml`)
    — worth checking whether a bare priority byte is enough to decide
    *whether* to yield, with the workflow routing fetched separately on
    yield (matching arc-011's own "details fetched on yield" principle), or
    whether that's insufficient for this use case specifically.

- **IW-4: Was T-1135's cross-repo persistence contract (tags:
  persistent,receptionist; cleanup exemption; session.needs_restart event)
  ever implemented on TermLink's side, five months on?**
  confidence: 0
  disposition: deferred
  rationale: Not checked this session — T-1135's Investigation captured
    TermLink's April response (`/opt/termlink/docs/reports/T-967-persistent-sessions-response.md`,
    cross-repo, not directly readable from here) describing a 3-change,
    small-effort fix. TermLink has shipped multiple releases since
    (T-1636/T-1637/T-2363 all landed post-April per T-1820's provenance
    trail). Needs a read-only cross-repo TermLink dispatch to check current
    state before assuming the April agreement is still accurate — do not
    re-litigate or re-negotiate it inline; confirm or re-open with evidence.

- **IW-5: Does the sidecar need its own registered TermLink identity, and
  what does "per agent session" mean operationally (one sidecar per
  `claude-fw` session, or one per project shared across sessions)?**
  confidence: 1
  disposition: deferred
  rationale: T-1135's naming convention (`fw-agent`, `termlink-agent`,
    `{project}-agent`) reads as one persistent identity *per project*, not
    per ephemeral session — which would make it a shared resource multiple
    concurrent `claude-fw` sessions on the same project poll against, not a
    1:1 spawn-per-session. This changes the supervision story (one thing to
    keep alive per project, not N) but needs confirming against how
    `fw peer subscribe`'s cron actually runs (per-session cron, or
    project-level cron already, per T-1804/T-1818).

- **IW-6: Is the DM-rail topic split (`dm.queued` vs `inbox.queued`, noted
  in T-2918's Context as a separate concern) in scope for this sidecar, or a
  sibling problem the sidecar should be agnostic to?**
  confidence: 2
  disposition: deferred
  rationale: Leaning "agnostic" — the sidecar's job is transport (hold
    connection, flag on any subscribed topic), so subscribing to both
    `inbox.queued` and `dm.queued` is a config-shape question, not an
    architecture question. Low-confidence lean only; not verified against
    TermLink's actual subscribe API surface for multi-topic hub subscription.

## Exploration Plan

1. **Cross-repo state check (IW-4)** — read-only TermLink dispatch: has
   T-967's persistence contract shipped since April? What does `termlink
   register --tags persistent` actually do today, and does the cleanup cron
   honor it? Time-box: 30 min.
2. **Yield-point granularity dialogue (IW-1)** — work through with the
   operator directly (not solo-decided): what moments in an agent's loop
   are appropriate to check for a peer-consult flag, given the messages this
   sidecar carries are advisory/consultative rather than danger-preventing.
   Time-box: one dialogue session.
3. **Heartbeat spike (IW-2)** — once a target hub is available, measure real
   round-trip and staleness behaviour under normal and loaded conditions
   before picking numbers. Time-box: 1-2 hours once IW-4 confirms a live
   target.
4. **Flag-shape + routing sketch (IW-3, IW-5, IW-6)** — a short written spec
   (not code) proposing the flag file/KV shape, the sidecar's registered
   identity model, and topic scope — reviewed with the operator before any
   build task is filed.
5. **Write the build task(s)** — once IW-1 through IW-6 are disposed
   `answered`, decompose into build-sized tasks per Task Sizing Rules (this
   spans at least: sidecar process, harness poll integration in
   `lib/peer.py`, possibly TermLink-side changes if IW-4 finds the April
   contract unshipped — likely 3+ tasks, not one).

## Technical Constraints

- **Cross-repo dependency risk (IW-4).** If TermLink's side of the April
  T-1135 agreement was never shipped, this inception's scope grows to
  include (or block on) a cross-repo ask — Gap Homing (T-1333) applies: if
  the fix must live in TermLink, it gets filed there, not built around here.
- **No LLM in the hot path.** Per arc-011 §5's cost/responsiveness
  reasoning (an LLM-backed listener is woken infrequently to save money,
  reintroducing the latency this design exists to remove) — the sidecar
  must be a deterministic process, not `claude -p`. This is a hard
  constraint carried over from the ADR, not open for re-litigation here.
- **Must not reverse T-1804's cron-preferred stance for the *agent* itself.**
  Only the lightweight sidecar runs continuously; the agent harness still
  polls (a flag + heartbeat check), it does not become a daemon itself.

## Scope Fence

**IN scope:**
- Resolving IW-1 through IW-6 above.
- A written spec for the sidecar (process shape, flag/heartbeat file
  contract, registered TermLink identity, cross-repo persistence
  requirements) sufficient to file real build task(s) from.
- Confirming or re-opening T-1135's April cross-repo agreement with current
  evidence (not re-negotiating it from scratch).

**OUT of scope (this inception does not build any of it):**
- Implementing the sidecar process itself.
- Changing `lib/peer.py` / `fw peer subscribe`.
- Any TermLink-side code changes (cross-repo — files on their side per Gap
  Homing if IW-4 finds work needed).
- Re-opening T-1820/arc-003's headline mechanic scope (T-2918's rejected
  option 4) — this inception's success criterion is making the existing
  scope deliverable, not changing what it delivers.
- T-2323 (AEF-IC-1, write-collision yield-point granularity) — sibling,
  not superseded; this inception's IW-1 is the peer-consult-specific
  question, and should cross-link T-2323 rather than duplicate or override
  its still-open write-collision scope.

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
- IW-1 through IW-6 can each be disposed `answered` with real evidence
  (not guessed defaults inherited from arc-011's sibling use case)
- The resulting spec decomposes into build task(s) that are individually
  reversible (a sidecar can be killed/disabled without breaking
  `fw peer subscribe`'s existing cron-poll fallback path)
- IW-4 (cross-repo persistence state) resolves without requiring net-new
  TermLink-side scope beyond what T-1135 already negotiated — if it does
  require more, that becomes a Gap Homing (T-1333) filing on TermLink, not
  a blocker to closing this inception with a partial spec

**NO-GO if:**
- IW-4 finds TermLink's side has diverged enough that the April contract
  needs full re-negotiation (materially larger cross-repo scope than
  estimated)
- Heartbeat/responsiveness spike (IW-2) shows the sidecar cannot poll the
  hub cheaply enough to be worth it over the existing lossy 30s cron-poll
- IW-1 dialogue concludes peer-consult genuinely needs interrupt-driven
  delivery after all (would mean revisiting arc-011's own rejection of PTY
  injection — a bigger reopening than this inception is scoped for)

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

**Rationale:**

Operator explicitly chose this direction in dialogue 2026-09-20 (see T-2918 Decisions), after confirming it is not new design but the unbuilt half of an already-reasoned ADR (docs/architecture/parallel-execution-aef.md §5, arc-011, adversarial-reviewed). Recommending GO on scoping/building it because: the alternative (T-2918's 4 narrower fixes) either accepts silent message loss or asks a sibling repo for scope on their timeline, while this ADR's design is already agreed in principle and partially negotiated cross-repo (T-1135, April 2026) but never implemented. Real open sub-questions remain (yield-point granularity for peer-consult specifically, heartbeat timing, priority-byte flag shape, cross-repo persistence wiring) -- those are the inception's job to resolve with the operator, not reasons to defer starting it.

**Evidence:**

- `docs/architecture/parallel-execution-aef.md:121-211` (§5, §6) — the
  sidecar/flag/heartbeat/priority-byte design, adversarially reviewed,
  never built beyond `agents/dispatch/yield-point.sh`'s narrow slice.
- `.tasks/completed/T-1135-*.md` — cross-repo persistence contract, GO
  2026-04-12, never followed by a build task.
- `.tasks/completed/T-1140-*.md` — the only follow-up, DEFERRED as a
  duplicate self-pickup 2026-04-20; nothing replaced it.
- `.tasks/active/T-2918-*.md` Investigation section — direct TermLink
  source confirmation that the hub aggregator has no cursor/replay
  (`crates/termlink-hub/src/aggregator.rs:192-224`,
  `crates/termlink-cli/src/commands/events.rs:845-847`).
- Full research trail and dialogue log:
  `docs/reports/T-3396-peer-consult-sidecar-inception.md`.

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

**Rationale**: Operator explicitly chose this direction in dialogue 2026-09-20 (see T-2918 Decisions), after confirming it is not new design but the unbuilt half of an already-reasoned ADR (docs/architecture/parallel-execution-aef.md §5, arc-011, adversarial-reviewed). Recommending GO on scoping/building it because: the alternative (T-2918's 4 narrower fixes) either accepts silent message loss or asks a sibling repo for scope on their timeline, while this ADR's design is already agreed in principle and partially negotiated cross-repo (T-1135, April 2026) but never implemented. Real open sub-questions remain (yield-point granularity for peer-consult specifically, heartbeat timing, priority-byte flag shape, cross-repo persistence wiring) -- those are the inception's job to resolve with the operator, not reasons to defer starting it.

**Date**: 2026-09-20T22:19:03Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-20T21:56:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-20T22:19:03Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Operator explicitly chose this direction in dialogue 2026-09-20 (see T-2918 Decisions), after confirming it is not new design but the unbuilt half of an already-reasoned ADR (docs/architecture/parallel-execution-aef.md §5, arc-011, adversarial-reviewed). Recommending GO on scoping/building it because: the alternative (T-2918's 4 narrower fixes) either accepts silent message loss or asks a sibling repo for scope on their timeline, while this ADR's design is already agreed in principle and partially negotiated cross-repo (T-1135, April 2026) but never implemented. Real open sub-questions remain (yield-point granularity for peer-consult specifically, heartbeat timing, priority-byte flag shape, cross-repo persistence wiring) -- those are the inception's job to resolve with the operator, not reasons to defer starting it.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f86523a6
- **Timestamp:** 2026-09-20T22:19:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-f7770925
- **Timestamp:** 2026-09-20T22:19:05Z
- **Overall:** CONTRADICTED
- **Claims:** 8

| Claim | Type | Status |
|-------|------|--------|
| `docs/architecture/parallel-execution-aef.md:121-211` | file | ✗ fail — file not found at PROJECT_ROOT |
| `agents/dispatch/yield-point.sh` | file | ✓ pass |
| `crates/termlink-hub/src/aggregator.rs:192-224` | file | ✗ fail — file not found at PROJECT_ROOT |
| `crates/termlink-cli/src/commands/events.rs:845-847` | file | ✗ fail — file not found at PROJECT_ROOT |
| `docs/reports/T-3396-peer-consult-sidecar-inception.md` | file | ✓ pass |
| `T-2918` | task | ✓ pass |
| `T-1135` | task | ✓ pass |
| `T-1140` | task | ✓ pass |

### 2026-09-20T22:19:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
