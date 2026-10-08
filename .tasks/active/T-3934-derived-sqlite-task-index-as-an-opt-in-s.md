---
id: T-3934
name: "Derived SQLite task index as an opt-in second state layer for large projects
  (files stay authoritative; tasks first)"
description: >
  Inception: Derived SQLite task index as an opt-in second state layer for large projects
  (files stay authoritative; tasks first)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-06T10:14:32Z
last_update: '2026-10-06T10:30:27Z'
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
  - ts: '2026-10-06T10:16:00Z'
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
  - ts: '2026-10-06T10:30:27Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=158,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3934: Derived SQLite task index as an opt-in second state layer for large projects (files stay authoritative; tasks first)

## Problem Statement

At ~3,900 task files every Watchtower page and many CLI verbs re-derive the task corpus from
files on each request: 62 Python glob sites, a full parse 24.9 s under load. Should AEF add an
opt-in derived index (files stay authoritative)? Research artifact: `docs/reports/T-3934-task-index.md`.

## Assumptions

- A1: The per-request re-derivation, not the file format, dominates page cost at this scale.
- A2: (path, mtime, size) is a sufficient freshness key for task files.
- A3: SQLite in WAL mode tolerates this project's concurrent readers/writers.

## Open Questions

- **IW-1: How does the index stay fresh when a task file is edited directly (Edit tool, no fw verb)?**
  confidence: 1
  disposition:
  rationale:
- **IW-2: Which consumers move first — /approvals and /tasks only, or the CLI listings too?**
  confidence: 1
  disposition:
  rationale:
- **IW-3: One shared query module that the 62 sites converge on, or only the hot paths?**
  confidence: 1
  disposition:
  rationale:
- **IW-4: Is WAL mode plus rebuild-on-corruption enough for multiple writers (sessions, cron, Watchtower)?**
  confidence: 1
  disposition:
  rationale:
- **IW-5: Do episodics, handovers and fabric follow later under the same module, or stay out of scope?**
  confidence: 1
  disposition:
  rationale:

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

1. Spike (done): count derivation sites and time a full parse — 62 sites, 24.9 s.
2. Spike (1 h): prototype a throwaway index over tasks; time build, an incremental refresh after one
   edit, and a stat-sweep freshness check over 3,918 files (answers IW-1, A2).
3. Spike (1 h): 4 concurrent writers + Watchtower readers on one WAL SQLite file (IW-4, A3).
4. Dialogue with the operator on IW-2/IW-3/IW-5, then a scoped build plan.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

IN: a derived, gitignored, rebuildable task index; its freshness rule; fallback to file scans;
opt-in switch; which consumers move first.
OUT: replacing files as the source of truth; a server database engine; multi-host sharing;
episodics/handovers/fabric (IW-5 decides whether they come later).

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
- An index query answers /approvals' and /tasks' task data in well under 1 s, with an incremental refresh after one edit
- Freshness on direct edits is solvable by a cheap stat sweep (IW-1) and concurrency by WAL (IW-4)
- Every consumer keeps a working file-scan fallback (small projects unchanged)

**NO-GO if:**
- Freshness needs a long-running watcher daemon (breaks the no-daemon portability property)
- The index cannot be kept consistent without making it authoritative

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

Measured 2026-10-06: every Watchtower request re-derives state from files (glob of 3,209 completed tasks + 3,211 episodics, ~15.8K-file link walk, YAML re-parse per request); each perf fix so far was a page-local cache (T-3920, T-3736, dir signatures). A derived, gitignored, rebuildable SQLite index over tasks, with file fallback, removes the class rather than the instance and keeps D4 portability (stdlib, no daemon). Operator agreed the direction 2026-10-06: gitignored, tasks first.

**Evidence:**

- 62 Python sites glob the task files independently (web 21, lib 28, agents 13)
- Full frontmatter parse of 3,918 task files: 24.9 s at host load ~18 (2026-10-06)
- Stalled-Watchtower stack dump: 38 threads in glob, 13 in dir signatures, 10 queued on the link-index lock
- Operator agreed the direction 2026-10-06 (gitignored, tasks first) — dialogue in docs/reports/T-3934-task-index.md
- Spikes 2-3 (prototype timing, WAL concurrency) still to run before decide

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-08 — operator walkthrough (chat): GO on A, tasks first
- **Chose:** A — build the derived, gitignored, rebuildable SQLite index for tasks only, with file fallback; switch the slowest Watchtower pages first; learnings/episodics only if measured worth it.
- **Rejected:** B (more spikes — the cost is already measured); C (page-local caches treat instances, not the class).

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-06T10:16:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
