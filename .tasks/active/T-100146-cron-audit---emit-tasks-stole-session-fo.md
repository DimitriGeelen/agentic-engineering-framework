---
id: T-100146
name: "Cron audit --emit-tasks must not steal focus or create started-work tasks"
description: >
  Promoted from observation OBS-082. Hourly cron audit created T-100141 as
  started-work and rewrote focus.yaml current_task while an interactive session
  held focus on T-100140. Emitted backlog tasks should be captured + horizon:later
  and must never touch focus.yaml.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-04T12:28:33Z
last_update: '2026-07-04T12:30:02Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
bvp_scores_proposed:
  - ts: '2026-07-04T12:29:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-04T12:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100146: Cron audit --emit-tasks must not steal focus or create started-work tasks

## Context

On 2026-07-04 ~12:00 the hourly cron audit (`fw audit --emit-tasks`) created T-100141
with `status: started-work` and rewrote `.context/working/focus.yaml` `current_task`
while an interactive session held focus on T-100140. The next interactive Bash call
was blocked by G-020 (T-100141 had placeholder ACs and now owned focus). Backlog tasks
emitted by an unattended cron are proposals, not active work — they must be created
`captured` + `horizon: later` and must not touch session focus. Origin: OBS-082,
found during T-100140.

## Acceptance Criteria

### Agent
- [x] Tasks created via `fw audit --emit-tasks` land with `status: captured` and `horizon: later` (audit.sh emit call: `--horizon later`, no `--start`)
- [x] `fw audit --emit-tasks` leaves `.context/working/focus.yaml` untouched (the only focus call in create-task.sh sits under the `START_WORK` guard, which emission no longer sets)
- [x] Regression test pins both behaviours (`tests/unit/test_audit_emit_tasks.bats` — 2 new T-100146 tests, both green)
- [x] T-100141 (the incident artifact) is demoted to `captured` + `horizon: later` so it no longer trips G-020 (plus T-100147–T-100155 from the recurrence burst during this fix)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
bash -n agents/audit/audit.sh
out=$(bats tests/unit/test_audit_emit_tasks.bats --filter "T-100146" 2>&1); echo "$out" | grep -q "ok 2" && ! echo "$out" | grep -q "not ok"
# Emission call shape: no --start, horizon later
block=$(sed -n '/bin\/fw" task create/,/2>&1)/p' agents/audit/audit.sh); echo "$block" | grep -q -- "--horizon later" && ! echo "$block" | grep -q -- "--start"

## RCA

**Symptom:** Interactive session's Bash calls repeatedly blocked by G-020 pointing at
tasks the session never created (T-100141, then T-100147…T-100155 during this very fix).
`.context/working/focus.yaml` `current_task` kept flipping to freshly-created audit tasks.

**Root cause:** `_emit_findings_as_tasks` (agents/audit/audit.sh) invoked
`fw task create … --horizon now --start`. `--start` does two things in create-task.sh:
sets `status: started-work` AND calls `context.sh focus <new-id>` (T-297 behaviour built
for interactive use). An unattended cron inheriting that path reassigns the live session's
focus once per finding — during the recurrence burst, 9 findings = 9 focus thefts in
minutes, each landing on a placeholder-AC task that then G-020-blocked all session Bash.

**Why structurally allowed:** focus.yaml is a single global slot with no writer identity —
nothing distinguishes "interactive session sets its own focus" from "background cron
side-effects it". The emit feature (T-2353) reused the interactive create path wholesale;
no gate or review question asks "does this unattended path mutate session-scoped state?"

**Prevention:** two static pins in `tests/unit/test_audit_emit_tasks.bats`: (1) the
emission create call must not contain `--start` and must use `--horizon later`; (2) the
only `context.sh focus` call in create-task.sh must remain inside the `START_WORK` guard,
so a captured create can never touch focus. Deeper fix (out of scope, candidate follow-up):
per-session focus or writer-identity check in context.sh so background processes cannot
mutate an interactive session's focus at all.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

**Recommendation:** GO — close as work-completed.

**Rationale:** The defect is fixed at its root (emission no longer passes `--start`,
uses `--horizon later`), the incident artifacts are cleaned up, and the fix is pinned
by two regression tests. The bug reproduced live *during* the fix (cron burst emitted
T-100147–T-100155, stealing focus 9 more times), which both confirmed the RCA and
exercised the cleanup path. Owner is `human` only because `fw note promote` defaults
there — all ACs are agent-verifiable and ticked with evidence.

**Evidence:**
- `agents/audit/audit.sh` emit call: `--horizon later`, no `--start` (with origin comment)
- `tests/unit/test_audit_emit_tasks.bats`: 2 new T-100146 tests green (`ok 1`, `ok 2`)
- T-100141 + T-100147…T-100155 all demoted to `captured` + `horizon: later` (verified by grep)
- `bash -n agents/audit/audit.sh` clean

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-04T12:28:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100146-cron-audit---emit-tasks-stole-session-fo.md
- **Context:** Initial task creation

### 2026-07-04T12:29:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
