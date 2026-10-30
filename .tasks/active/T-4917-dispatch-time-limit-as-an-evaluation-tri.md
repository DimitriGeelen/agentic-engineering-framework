---
id: T-4917
name: "Dispatch time limit as an evaluation trigger, not a kill (1409: 19 of 279 workers killed, 13 with finished code)"
description: >
  1409-sprind proposal (msg d9271ba5, their T-3405, operator-approved): run.sh's blind watchdog kills at --timeout (600 s default); make the timeout a review span, kill only on evaluated standstill, plus a high hard ceiling.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: [termlink, dispatch]
components: []
related_tasks: [T-577]
origin: {kind: "peer", source: "1409-sprind", ref: "d9271ba5"}
created: 2026-10-30T00:31:25Z
last_update: 2026-10-30T00:31:25Z
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

# T-4917: Dispatch time limit as an evaluation trigger, not a kill (1409: 19 of 279 workers killed, 13 with finished code)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

`fw termlink dispatch` ends a worker at `--timeout` with a blind watchdog in `agents/termlink run.sh`: `(sleep "$TIMEOUT" && kill "$CLAUDE_PID")`, plus the LOOP_PID and HARNESS_PID variants. The default is 600 s when `--timeout` is omitted. The watchdog does not look at whether the worker is progressing.

**Evidence (1409-sprind, msg d9271ba5, 2026-10-30, their T-3405, operator-approved):**
- Since 2026-10-27, 279 TermLink workers ended in their project; 19 were killed by the watchdog.
- 13 of the 19 were build workers at 3–4 h whose code was done and who were waiting for a long verification run.
- 3 were reviewers killed by the 600 s default.
- Detached children (a 50-min full test tier) died with them, so each restart cost about 1 h.

**Their operator, verbatim:** "we are really losing valuable work because of timegrenzen … It can be an indicator to kill it if you think there's no value, nothing is progressing … it should be a trigger, but it should not be called kill because timegrenzen."

**Their suggested direction (a proposal, not a spec):**
1. `--timeout` becomes a review span. When it elapses, record an evaluation (result.jsonl growth, commits in the worker's project dir, CPU of the worker's process tree, live child processes) and notify the orchestrator.
2. Kill only on an evaluated standstill, by the orchestrator, with the reason logged and state preserved first.
3. A separate high hard ceiling (e.g. `--hard-timeout`, default 48 h) for hung workers.
4. No blind 600 s default.

**Their project-side mitigation (live, no framework edit):** all dispatches pass `--timeout 172800`; the watchdog sleeps were removed by PID; and they run an evaluator every 3 h that wakes the orchestrator on standstill and never kills. Its path is `/opt/1409-sprind/.context/working/orchestrator/zeitgrenze_bewertung.py` (msg a0aa3b15). Signals: result.jsonl age, last commit in the worker's project dir, CPU of the run.sh process tree, live or queued child verification runs. **Not read:** standing rule, no reading other projects' files. Ask the operator, or ask 1409 to send the content in a message, if it is needed.

**Constraint to keep:** T-577 (orphaned or hung workers must be ended). The hard ceiling is what keeps that protection.

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

**Rationale:** Measured loss in one consumer: 19 of 279 workers since 2026-10-27 killed by the blind watchdog in agents/termlink run.sh, 13 of them build workers at 3-4 h with code done waiting on verification, 3 reviewers killed by the 600 s default; detached children died too, ~1 h rework each. Their operator ruled the limit should be a trigger, not a kill. The hard-ceiling leg keeps T-577's protection against hung or orphaned workers, so the change does not reopen that class. Exploration should settle the evaluation signals and who may kill.

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
