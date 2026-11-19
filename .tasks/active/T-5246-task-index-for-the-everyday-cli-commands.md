---
id: T-5246
name: "Task index for the everyday CLI commands: work-on, context focus, task update
  and the per-command hook under 5 s at about 290,000 task files (widens T-3934/T-5107
  beyond Watchtower pages)"
description: >
  Inception: Task index for the everyday CLI commands: work-on, context focus, task
  update and the per-command hook under 5 s at about 290,000 task files (widens T-3934/T-5107
  beyond Watchtower pages)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
step_entered_at: '2026-11-19T08:10:38Z'
waiting_on: agent
revisit_at: 2026-11-26
created: 2026-11-19T08:10:09Z
last_update: '2026-11-19T08:10:53Z'
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
  - ts: '2026-11-19T08:10:53Z'
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

# T-5246: Task index for the everyday CLI commands: work-on, context focus, task update and the per-command hook under 5 s at about 290,000 task files (widens T-3934/T-5107 beyond Watchtower pages)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

The `fw` commands an agent runs in the rhythm of its work read the task files directly, and their cost grows with the number of files. 1409 measured this in a throwaway project (msg bb07ad3f, 2026-11-19): `fw work-on` 3-4 s at 2,900 task files, 31-105 s at 10,000, 201-596 s at 50,000, over 600 s at 142,000; `fw task list` 439 s and `fw audit` over 1,800 s at 50,000. Their operator ruled that a new version of a step is a task, which means about 290,000 task files for one project (msg bbf3f214). Their targets: the rhythm commands (`fw work-on`, `fw context focus`, `fw task update`, the per-command hook) under 5 s; the rare ones (`fw task list`, `fw audit`, `fw metrics`) under 60 s.

The operator already gave GO on a derived SQLite index in front of the task files (T-3934, 2026-10-08), scoped to the slowest Watchtower pages; build task T-5107 has not started. On 2026-11-19 the operator approved widening that scope to the everyday CLI commands, planned as this inception ("2 yes"). 1409 adds one requirement (msg 95af5a15): the index must be verifiably rebuildable, with one command that rebuilds it from the files and reports every difference, cheap enough for a test tier.

Already separated out: about 15 s of every `fw context focus` and `fw work-on` was a task briefing that always timed out, fixed in T-5245. What remains is the file-count effect.

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

- **IW-1: Where does each rhythm command spend its time at 10,000 and 50,000 task files? Profile `fw work-on`, `fw context focus`, `fw task update` and the per-command hook against 1409's generator, and name the code paths that scan the corpus.**
- **IW-2: What must the index hold for those paths (id → path and status, frontmatter fields, arc membership, the id allocator's view), and can the hook and the gates read it without trusting a stale copy?**
- **IW-3: The verifiable rebuild: one command that rebuilds from the files and reports every difference from the live index. How cheap can it be at 290,000 files, and which test tier runs it?**
- **IW-4: How does it plug in: opt-in per project with a recommended switch-on point (1409's operator proposed a trigger), file fallback when missing or stale, and the same index serving the Watchtower pages T-5107 targets?**

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

**Recommendation:** EXPLORING

**Rationale:**

Operator ruling 2026-11-19 ('2 yes'): widen the T-3934 index scope to the run-rhythm CLI verbs, planned as its own inception. Evidence: 1409 timings (work-on 31-105 s at 10,000 files, 201-596 s at 50,000; task list 439 s at 50,000; audit over 1,800 s at 50,000) and their target of under 5 s for rhythm verbs, under 60 s for rare verbs. Questions to explore before a verdict: which verbs scan the corpus and where, what the index must hold, how the verifiable rebuild check works.

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

### 2026-11-19T08:10:38Z — inception-wait [inception-lifecycle]
- **Change:** waiting_on: agent → agent
- **Revisit:** 2026-11-26

### 2026-11-19T08:10:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
