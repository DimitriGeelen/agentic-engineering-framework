---
id: T-1804
name: "cross-agent conversation arc — joint AEF + TermLink design (consult substrate)"
description: >
  Joint AEF + TermLink design for cross-agent conversation substrate. Required to unlock peer-consultation (b3) as an alternative to operator pause for Worker uncertainty resolution. Surfaced during T-1687 grilling (Q15, CONTEXT.md). TermLink owns transport (channels, events, delivery, inbox, wakeup signal); AEF owns semantics (when to consult, task-context anchoring, conversation audit, spawn-on-event bridge). Must agree the seam before either repo ships code.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [inception, cross-repo]
components: []
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-13T14:38:27Z
last_update: 2026-05-13T17:39:25Z
date_finished: 2026-05-13T17:39:25Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1804: cross-agent conversation arc — joint AEF + TermLink design (consult substrate)

## Problem Statement

Workers in the v1 dispatch substrate have no way to consult peers (reviewer / specialist / orchestrator agents) when hit by mid-dispatch uncertainty. The only resolution paths today are: (a) guess and rely on post-hoc outcome eval, or (b1) pause and wait for the operator. Both are valid, but (b3) peer-consult would be cheaper than (b1) in operator-latency terms — *if* cross-agent conversation worked reliably.

Surfaced during T-1687 grilling (CONTEXT.md Q15, 2026-05-13). The user named the substrate gap precisely: *"one agent fires a request, when in luck the other agent polls and picks up the message but just as easily never sees the message; current operator solves that by instigating a very costly regular loop."*

The mechanisms that exist are fragmented:
- `fw bus post --remote` — audit trail, but sync read-only, no subscriber wakeup
- TermLink `event emit/wait/poll` / `channel_*` — substrate exists, adoption uneven
- Pickup — async, may silently drop if receiver never polls
- Operator cron poll — reliable, costly, latency-bound

The gap that needs solving for (b3) to be viable: **persistent topic + bounded round-trip + wakeup-of-non-running-agent + audit trail + multi-party**.

## Assumptions

<!-- Register with: fw assumption add "Statement" --task T-1804 -->

- TermLink already owns the transport primitives (channels, events, inbox, delivery, remote relay). AEF should not reinvent them.
- The "wakeup of a non-running agent" gap is the load-bearing missing piece. Adoption alone (using existing primitives consistently) does not close it.
- The seam between TermLink (transport) and AEF (semantics + spawn-on-event bridge) is real and stable — both repos can ship independently once the seam is agreed.
- "Long-lived AEF daemon per host" is a design smell; the framework prefers cron + on-demand spawn. A bridge that spawns the responder process on-demand is preferable to a daemon that holds state.

## Exploration Plan

Time-box: 1 session for the seam decision; 1-2 sessions for cross-repo coordination round-trip.

1. **Spike A** — Inventory TermLink primitives by reading `termlink help`, `mcp__termlink__*` schemas, and `/opt/termlink/CONTEXT.md` (if present). Map which primitives already satisfy each requirement (persistent topic, wakeup, multi-party, audit). Identify the actual gaps. Cost: 30 min.
2. **Spike B** — Sketch the three wakeup options in concrete terms:
   - (i) TermLink-side hook (TermLink fires `$WAKEUP_CMD` on undeliverable message)
   - (ii) AEF-side daemon (long-lived TermLink subscriber per host, spawns responders)
   - (iii) Hybrid (TermLink emits `message-arrived-no-consumer` event; AEF subscriber spawns responder)
   For each, name the file/function in the right repo, the failure modes, the API surface. Cost: 1h.
3. **Spike C** — Draft the cross-repo proposal artifact: one document, both repos read it, agreement landed before either ships. Format: `docs/proposals/cross-agent-conversation-substrate.md`. Cost: 1h.
4. **Cross-repo handoff** — Dispatch the proposal to the TermLink-project agent via `fw termlink dispatch --project /opt/termlink`. Await acknowledgment. **Do not edit TermLink files directly.** Cost: depends on TermLink-side latency.
5. **Decision** — Joint go/no-go on the recommended option (currently (iii) per grilling). Update CONTEXT.md and ADR-0004.

## Technical Constraints

- TermLink hub is per-machine; cross-machine routing goes through `termlink remote`. Cross-machine peer-consult must work or (b3) is single-host-only.
- Workers spawn `--bare` — no CLAUDE.md, no hooks. Pause/consult instruction must travel in the dispatch envelope (Resolver-injected preamble).
- Inception tasks must NOT write build artifacts before `fw inception decide T-1804 go`. This task ships a research artifact + cross-repo proposal + decision. Code lands in follow-up build tasks under the orchestrator-rethink arc.

## Scope Fence

**IN scope:**
- Joint design of the transport-vs-semantics seam
- Cross-repo coordination protocol (one proposal artifact, two-repo agreement)
- Decision on wakeup option (i / ii / iii)
- ADR-0004 capturing the seam and decision

**OUT of scope:**
- Implementation (build tasks come after GO decision, separate task IDs)
- (b3) peer-consult prompt-template surface in workflows (depends on this substrate; separate downstream build task)
- Generalizing to non-consult conversations (multi-step debates, design dialogues across agents) — surface needed, but v1 should ship the simplest case first

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

**GO if:**
- TermLink-side agrees the seam (transport-vs-semantics) is correct
- Wakeup option (i/ii/iii) chosen with TermLink concurrence
- The chosen option has a bounded TermLink-side change (≤1 new event class or hook) and a bounded AEF-side change (≤1 subscriber daemon or bridge)
- Proposal artifact ships agreed and committed to both repos before any code

**NO-GO if:**
- TermLink-side disagrees on seam location and wants to take semantic responsibility, OR doesn't want to add wakeup primitive — forces AEF into option (ii) (long-lived daemon, smell)
- No clean way to make non-running-agent wakeup work within cost/latency budget — peer-consult collapses back to pickup-with-cron
- Cross-repo coordination round-trip exceeds 2 sessions — defer rather than block the orchestrator-rethink arc

**DEFER if:**
- Operator-pause (b1) load turns out to be acceptable in practice (low pause rate from real workflows). (b3) becomes an optimization for later when pressure exists.

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

**Rationale:** The substrate gap is real and load-bearing for (b3) peer-consult, which is the cheaper-than-operator-pause path for Worker uncertainty resolution. Without it, (b1) operator-pause becomes the only relief valve and is likely to collapse under load (pause-storms → operators raise threshold → effectively turns pause off → original failure mode by another route). The seam between TermLink (transport) and AEF (semantics + spawn-bridge) is stable and lets both repos ship independently after agreement.

The user-chosen approach (β) from the T-1687 grilling is exactly this inception's purpose: file the inception in both repos, agree the seam in writing, then build. (α) — AEF ships unilaterally with a workaround — was rejected because it bakes in adoption of whatever workaround we built, even if the eventual TermLink primitive disagrees.

**Evidence:**
- T-1687 grilling Q15 (CONTEXT.md) — operator named the substrate gap precisely: *"one agent fires a request, when in luck the other agent polls and picks up the message but just as easily never sees the message; current operator solves that by instigating a very costly regular loop."*
- TermLink already owns the transport primitives (channels, events, inbox, delivery, remote relay) — duplicating them in AEF is reinvention.
- AEF already owns the spawn semantics (`claude-fw`, `fw termlink dispatch`) — TermLink learning spawn would bleed consumer-specifics into a domain-neutral transport.
- Three wakeup options identified; option (iii) hybrid is the cleanest seam: TermLink adds one generic event class; AEF adds one specific subscriber bridge.
- Cross-repo proposal artifact drafted: `docs/proposals/T-1804-cross-agent-conversation-substrate.md`

**Next steps if GO:**
1. Dispatch proposal to TermLink-project agent (cross-repo action — requires explicit user approval; agent does not edit TermLink files directly per `feedback_no_cross_repo_edits.md`).
2. Await TermLink-side acknowledgment with answers to the four decision points in the proposal.
3. Joint decision recorded as ADR-0004 (AEF side) — seam location and chosen wakeup option.
4. Spawn AEF-side build tasks under arc:orchestrator-rethink for `fw consult`, subscriber bridge, audit channel, Watchtower surface, workflow-side knobs.
5. TermLink-side ships the event class on their own roadmap (out of AEF's control; not a v1 dispatch-substrate blocker — (b1) remains the v1 relief valve until (b3) lands).

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

**Rationale**: The substrate gap is real and load-bearing for (b3) peer-consult, which is the cheaper-than-operator-pause path for Worker uncertainty resolution. Without it, (b1) operator-pause becomes the only relief valve and is likely to collapse under load (pause-storms → operators raise threshold → effectively turns pause off → original failure mode by another route). The seam between TermLink (transport) and AEF (semantics + spawn-bridge) is stable and lets both repos ship independently after agreement.

The user-chosen approach (β) from the T-1687 grilling is exactly this inception's purpose: file the inception in both repos, agree the seam in writing, then build. (α) — AEF ships unilaterally with a workaround — was rejected because it bakes in adoption of whatever workaround we built, even if the eventual TermLink primitive disagrees.

**Date**: 2026-05-13T17:39:24Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-13T14:39:02Z — status-update [task-update-agent]
- **Change:** tags: +inception

### 2026-05-13T14:39:11Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-13T14:39:11Z — status-update [task-update-agent]
- **Change:** tags: +cross-repo

### 2026-05-13T17:39:24Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The substrate gap is real and load-bearing for (b3) peer-consult, which is the cheaper-than-operator-pause path for Worker uncertainty resolution. Without it, (b1) operator-pause becomes the only relief valve and is likely to collapse under load (pause-storms → operators raise threshold → effectively turns pause off → original failure mode by another route). The seam between TermLink (transport) and AEF (semantics + spawn-bridge) is stable and lets both repos ship independently after agreement.

The user-chosen approach (β) from the T-1687 grilling is exactly this inception's purpose: file the inception in both repos, agree the seam in writing, then build. (α) — AEF ships unilaterally with a workaround — was rejected because it bakes in adoption of whatever workaround we built, even if the eventual TermLink primitive disagrees.

### 2026-05-13T17:39:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b6901927
- **Timestamp:** 2026-06-02T14:59:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T17:39:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
