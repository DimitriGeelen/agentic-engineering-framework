---
id: T-1902
name: "Watchtower /arcs/<slug>/close review surface for human arc closure"
description: >
  Inception: Watchtower /arcs/<slug>/close review surface for human arc closure

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: [T-1671, T-679, T-1626, T-1633, T-1641, T-1667, T-1670]
created: 2026-05-18T18:33:39Z
last_update: '2026-06-11T22:24:02Z'
date_finished: '2026-05-18T20:15:17Z'
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1902: Watchtower /arcs/<slug>/close review surface for human arc closure

## Problem Statement

**For whom:** the human, when an arc is structurally ready to close.

**What:** today's closure workflow is raw CLI — `cd /opt/999-Agentic-Engineering-Framework && bin/fw arc close arc-grooming --demo docs/reports/arc-005-headline-mechanic-demo.md --decision "..."`. The agent cannot run it ($CLAUDECODE=1 refusal, T-1671). The human must context-switch to a terminal, recall the exact arc slug, recall the demo path, remember the flag names, and type a decision string with no preview.

**Why now:** arc-grooming has 32 constituent tasks all work-completed, demo artefact captured at `docs/reports/arc-005-headline-mechanic-demo.md`, but closure has been pending across multiple sessions because the friction is real. `fw task review T-XXX` solved the equivalent friction for task approvals (T-679). The arc-level twin is missing.

**Why this is NOT about weakening the gate:** T-1671's §ACD axiom (closure is strategic judgment, not substrate verification) stays intact. The exemption mechanism (`--from-watchtower` flag in `lib/arc.sh:779`) already exists and is the documented path for human-via-UI decisions. This task proposes the UI, not the gate change.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

Three small spikes before committing to a build slice:

1. **Spike: confirm `--from-watchtower` reaches the close path end-to-end** — read `lib/arc.sh:779`, trace the flag through `do_arc_close`, confirm $CLAUDECODE refusal is bypassed when the flag is present. Time-box: 30 min.
2. **Spike: existing Watchtower task-review surface as template** — read `web/blueprints/tasks.py` and `web/templates/task_review*.html` (whatever the actual paths are) to confirm the pattern is reusable for arcs. Identify the minimal delta. Time-box: 45 min.
3. **Spike: prerequisite-check function design** — define the function signature in `lib/arc.sh` that returns the structured status (all-tasks-completed: bool, demo-present: bool, headline-mechanic-non-empty: bool, anchor-completed: bool) so both the CLI verb and the Watchtower backend can call it. Time-box: 30 min.

After spikes, file a small build slice (likely T-1903) for the implementation. The spikes prove the assumptions hold; the build slice ships the surface.

## Technical Constraints

- Watchtower already runs on per-project port (T-1376); the surface uses the existing port resolution, no new hard-codes.
- `fw arc close` is shell, not Python — the backend handler invokes it via subprocess. `--from-watchtower` is the only auth signal (sufficient because the Watchtower process itself runs locally and access is human-gated by virtue of the human opening the URL on their LAN/VPN).
- The agent (in this session or any future one) MUST NOT attempt to invoke the backend POST handler itself — that would route an agent-initiated request through the human exemption. The `--from-watchtower` flag is a structural pinky-swear; the backend should additionally check `$CLAUDECODE` is unset in the calling environment of the subprocess (Watchtower process is not running under $CLAUDECODE=1, so this is naturally enforced — but pin it with a test).

<!-- Technical Constraints moved to Exploration Plan section above to keep adjacent context together. -->

## Scope Fence

**IN scope:**
- New CLI verb `fw arc review <slug>` (parallel to `fw task review T-XXX`) — emits Watchtower URL + QR code, prints prerequisite checklist status to console
- New Watchtower page `/arcs/<slug>/close` rendering: arc metadata, `headline_mechanic` text, constituent task table with status, demo artefact preview/link, captured agent recommendation block, proposed decision text editor, prerequisite checklist (auto-evaluated), Approve / Reject buttons
- Backend POST handler at `/arcs/<slug>/close` invoking `bin/fw arc close <slug> --demo <path> --decision "<text>" --from-watchtower`
- Prerequisite checks (auto-evaluated, surfaced to UI): (a) all constituent tasks `work-completed`, (b) demo artefact file exists and is referenced from the arc YAML or recommendation, (c) `headline_mechanic` is non-empty, (d) anchor task exists and is work-completed
- Agent-side: extend `lib/arc.sh` with a new `do_arc_review` function the CLI verb calls

**OUT of scope:**
- Changing the §ACD axiom or T-1671's $CLAUDECODE refusal
- Auto-closing arcs (the human decision remains explicit)
- Bulk arc operations
- Editing the `--from-watchtower` exemption itself (already correct)

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

**Rationale:**

T-1671 §ACD gate correctly refuses agent-side arc closure ($CLAUDECODE=1 → fw arc close errors). This is structurally right (closure is strategic judgment, not substrate verification — origin: 4 incidents T-1626/T-1633/T-1641/T-1667/T-1670). But the human-side workflow today is raw CLI: cd into repo, recall the headline_mechanic, type the full fw arc close command with --demo and --decision args. fw task review T-XXX exists for task approvals; fw arc review <slug> + Watchtower /arcs/<slug>/close should be its arc-level twin. Agent presents prereqs check (all constituent tasks work-completed? demo artefact present? headline_mechanic referenced?) + the captured demo + the proposed decision text. Human reads, decides, one-clicks Approve → backend invokes fw arc close --from-watchtower exemption (already exists, lib/arc.sh:779). T-1671 §ACD gate stays intact. Only the friction goes away. GO because (a) friction is real (arc-grooming has been waiting on closure for days), (b) the exemption mechanism already exists and is tested, (c) no weakening of the gate — Watchtower IS the human surface, just like /tasks/T-XXX/review.

**Evidence:**

- `lib/arc.sh` `arc_close` function gates on `$CLAUDECODE=1` and accepts `--from-watchtower` (T-1671)
- `fw task review T-XXX` exists and proves the pattern works for task-level approvals (T-679)
- arc-grooming arc (id arc-005) has 32 work-completed constituent tasks and a demo artefact at `docs/reports/arc-005-headline-mechanic-demo.md` but `closed_at: null` because closure CLI friction has parked it
- T-1626 / T-1633 / T-1641 / T-1667 / T-1670 — five separate incidents where agent attempts to participate in arc closure had to be structurally blocked; the gate is load-bearing, this proposal preserves it
- §ACD axiom (CLAUDE.md "Arc Completion Discipline") explicitly separates substrate-verification (which agent CAN do) from closure-decision (which only human can do); this proposal uses the agent for the first and the human for the second

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

### 2026-05-18T18:35:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fba60cd6
- **Timestamp:** 2026-06-02T15:00:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
