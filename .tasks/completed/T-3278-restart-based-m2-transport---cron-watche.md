---
id: T-3278
name: "Restart-based M2 transport - cron-watched flag launches claude-fw, directive
  injected at SessionStart instead of live PTY injection"
description: >
  Inception: Restart-based M2 transport - cron-watched flag launches claude-fw, directive
  injected at SessionStart instead of live PTY injection

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-09-05T10:40:56Z
last_update: 2026-09-05T10:51:26Z
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
  - ts: '2026-09-05T10:42:36Z'
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
  - ts: '2026-09-05T10:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=151,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3278: Restart-based M2 transport - cron-watched flag launches claude-fw, directive injected at SessionStart instead of live PTY injection

## Problem Statement

The M2 continuous loop's cross-session continuation currently depends on live keystroke injection into a running TUI (`continuous-driver.sh`, channel 3 of arc-012) — the arc's most defect-dense subsystem (G-097 silent no-op, T-3275 delivery confirmation, spinner-fold busy detection, a second tmux wire in T-3277). The operator proposes an alternative: a cron-type watcher sees a flag and launches `claude-fw`, which injects the next directive through the first-party SessionStart context-injection path (`inject-next-directive.py` → `FW_NEXT_DIRECTIVE`). That channel already exists for restart-after-exit; the question is whether to make it cron-drivable and prefer it for unattended loops. For: arc-012 / anyone running unattended continuous mode. Why now: T-3277 just shipped the second live-injection wire, and further investment in keystroke emulation should be weighed against a channel with none of its failure classes. Full analysis: `docs/reports/T-3278-restart-based-m2-transport.md`.

## Assumptions

- A1: SessionStart `additionalContext` injection delivers the directive reliably with none of the G-097/T-3275 failure classes (it is a harness contract, not keystroke emulation). Evidence base: the restart leg already uses it (T-2364/T-2365, T-3166).
- A2: A cron leg can determine "no session currently running for this project" from the process table (pidfile/pgrep) — cheaper and more reliable than pane-diff busy detection.
- A3: >=60s hop latency is acceptable for M2 (the continuous-driver cron already runs on minute ticks).
- A4: The existing brake set (halt file, enabled flag, iteration/task caps, tier ceiling) can gate the cron leg at launch time — the L-652 AUTO_RESTART gating asymmetry is avoidable, not inherent.

## Open Questions

- **IW-1: Who ends the session in a restart-based loop — agent-initiated exit on directive completion, budget-critical exit, or does the cron leg treat any running session as busy and skip?**
  confidence: 1
  disposition: deferred
  rationale: Session-exit contract is a build-slice design decision; exploration plan names skip-while-running as the safe default (docs/reports/T-3278-restart-based-m2-transport.md IW-1); GO recorded 2026-09-05 with this deferral explicit.
- **IW-2: Is cron-tick latency (>=60s per hop) acceptable for the M2 loop?**
  confidence: 2
  disposition: answered
  rationale: Yes - the continuous-driver cron already runs on minute ticks (arc-012 practice since T-3239); operator raised no latency concern at GO.
- **IW-3: Should the cron leg launch claude-fw headless or inside an observable tmux/TermLink pane (Session Launch Policy 2026-09-03 mandates TermLink for observable framework work)?**
  confidence: 1
  disposition: deferred
  rationale: Launch shape is a build-slice decision bounded by Session Launch Policy 2026-09-03 (TermLink observability mandated); headless-vs-pane resolved at build.
- **IW-4: Does .next-directive.yaml suffice as the cron flag, or does launch-arming need a separate file so 'directive present' and 'cron may launch' are independently controllable?**
  confidence: 1
  disposition: deferred
  rationale: Default is reuse of .next-directive.yaml + existing halt file; separate arm-file is a build-slice schema decision, does not affect go/no-go.
- **IW-5: If restart-based hops become the primary loop, does the T-3240 Stop-hook one-continuation cap stop mattering (each session takes few turns then exits; the LOOP is the restart chain)?**
  confidence: 1
  disposition: answered
  rationale: The Stop-hook cap bounds turns-per-session only; loop bounding moves to the iteration counter in a restart chain. T-3240 stays its own inception, unaffected by this GO.

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

1. **Look-back (done, 0.5h):** map the three existing continuation channels and what the proposal reuses — captured in `docs/reports/T-3278-restart-based-m2-transport.md`.
2. **Spike: cold-start injection (1h, on GO or as pre-decision evidence if the operator wants it):** launch `claude-fw` from a non-interactive parent with a directive filed in `.next-directive.yaml` and continuous-mode enabled; confirm the directive reaches the session's context at SessionStart and the iteration counter advances. This is the one leg of A1 not yet measured (the restart leg fires after an exit, not from a cold start).
3. **Decide IW-1 (dialogue):** session-exit contract — recommend option (c) skip-while-running as the safe default, with (a) agent-initiated exit as the throughput improvement.
4. **Decide IW-3/IW-4 (dialogue):** launch shape (tmux+termlink per Session Launch Policy) and flag schema (reuse `.next-directive.yaml` + existing halt file, or add a separate arm-file).

## Technical Constraints

- Session Launch Policy (2026-09-03): observable framework sessions run through TermLink (`claude-fw --termlink`), never the Claude Code background-job daemon — the cron leg must honour this at launch.
- cron minimum granularity is 60s; hop latency floor follows from it (A3).
- The Stop hook yields to the prompt without exiting the process — a restart-based loop cannot assume sessions end on their own (IW-1).
- `claude -c` vs fresh session: T-3166 already decided fresh (continue restores the transcript but does not free context); the cron leg inherits that decision.
- L-652: the wrapper's AUTO_RESTART is gated on its own flag, not on continuous-mode `enabled:` — the cron leg must gate on the full brake set at launch time.

## Scope Fence

**IN:** the decision (this inception); the channel-map look-back; optionally the one cold-start spike; the IW-1..IW-5 contracts.
**OUT:** building the cron leg (separate build task on GO); removing or reworking the live-injection leg (T-3277 stays as built — it serves attended sessions); any TermLink upstream work (G-097 fix stays homed at TermLink, T-3256); changes to the Stop hook cap (T-3240 is its own inception).

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
- The SessionStart injection path is confirmed reachable from a cron-launched cold start (A1's unmeasured leg), or the operator accepts the restart-leg evidence as sufficient
- The build delta stays bounded: one cron leg + launch-time brake gate + a decided session-exit contract, with no changes required to the injector or wrapper contracts
- IW-1 has a decided answer (skip-while-running is an acceptable default)

**NO-GO if:**
- Cold-start injection turns out to need harness behaviour that doesn't exist (e.g. SessionStart context injection not firing for the launch mode chosen)
- The session-exit contract can't be made safe without rewriting the Stop hook (that would make this depend on T-3240 and unbounded)
- Hop cost (session cold-start tokens per hop) is measured to be prohibitive for the loop cadence M2 needs

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

Three continuation channels exist in arc-012 today; the proposed one is 80% built. The live-injection leg (continuous-driver.sh) fights an inherently hostile problem: G-097 (termlink inject silently no-ops into ink TUIs), busy-detection false positives (spinner frames read as work, fixed by animation-folding), and delivery confirmation (T-3275) - all defensive machinery against a wire that pushes keystrokes into a raw-mode TUI. The restart leg (claude-fw wrapper + .restart-requested + inject-next-directive.py + FW_NEXT_DIRECTIVE at SessionStart) already delivers a directive into a fresh session with NONE of those failure classes, because context injection is a first-party Claude Code channel, not keystroke emulation. The delta to build is small: a cron leg that watches the existing .next-directive.yaml flag and launches claude-fw when no session is running. Open questions are real but scoped: session-exit semantics (Stop hook yields to prompt, does not exit), coexistence with the live-injection leg for operator-attended sessions, and cron-granularity latency.

**Evidence:**

- G-097 + T-3275 + T-3277: three tasks of defensive machinery, all specific to keystroke emulation; none applies to SessionStart injection (analysis: `docs/reports/T-3278-restart-based-m2-transport.md`).
- Delivery path shipped and tested: `agents/context/inject-next-directive.py` + `FW_NEXT_DIRECTIVE` + `.context/working/.next-directive.yaml` (T-2364/T-2365); brake proof E10/T-3250.
- L-652: the wrapper's AUTO_RESTART gating asymmetry — a named, avoidable defect the cron leg must not copy (gate on full brake set at launch).
- T-3255 control measurement: tmux send-keys 2/2 vs termlink inject 0/2 into the same TUI — the origin of the whole second-wire investment this proposal makes unnecessary for unattended loops.

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

**Rationale**: Three continuation channels exist in arc-012 today; the proposed one is 80% built. The live-injection leg (continuous-driver.sh) fights an inherently hostile problem: G-097 (termlink inject silently no-ops into ink TUIs), busy-detection false positives (spinner frames read as work, fixed by animation-folding), and delivery confirmation (T-3275) - all defensive machinery against a wire that pushes keystrokes into a raw-mode TUI. The restart leg (claude-fw wrapper + .restart-requested + inject-next-directive.py + FW_NEXT_DIRECTIVE at SessionStart) already delivers a directive into a fresh session with NONE of those failure classes, because context injection is a first-party Claude Code channel, not keystroke emulation. The delta to build is small: a cron leg that watches the existing .next-directive.yaml flag and launches claude-fw when no session is running. Open questions are real but scoped: session-exit semantics (Stop hook yields to prompt, does not exit), coexistence with the live-injection leg for operator-attended sessions, and cron-granularity latency.

**Date**: 2026-09-05T10:47:43Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-05T10:42:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-05T10:47:43Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Three continuation channels exist in arc-012 today; the proposed one is 80% built. The live-injection leg (continuous-driver.sh) fights an inherently hostile problem: G-097 (termlink inject silently no-ops into ink TUIs), busy-detection false positives (spinner frames read as work, fixed by animation-folding), and delivery confirmation (T-3275) - all defensive machinery against a wire that pushes keystrokes into a raw-mode TUI. The restart leg (claude-fw wrapper + .restart-requested + inject-next-directive.py + FW_NEXT_DIRECTIVE at SessionStart) already delivers a directive into a fresh session with NONE of those failure classes, because context injection is a first-party Claude Code channel, not keystroke emulation. The delta to build is small: a cron leg that watches the existing .next-directive.yaml flag and launches claude-fw when no session is running. Open questions are real but scoped: session-exit semantics (Stop hook yields to prompt, does not exit), coexistence with the live-injection leg for operator-attended sessions, and cron-granularity latency.
