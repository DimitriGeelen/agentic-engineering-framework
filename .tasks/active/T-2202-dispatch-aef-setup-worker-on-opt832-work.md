---
id: T-2202
name: "dispatch AEF setup worker on /opt/832-Workflow-designer"
description: >
  Same shape as T-2200 — autonomous AEF install + audit-loop worker on /opt/832-Workflow-designer.
  Reuses operator-supplied 6-step brief with project-specific path substitution.

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
created: 2026-06-04T07:50:29Z
last_update: '2026-07-02T16:15:06Z'
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
cost_estimate_proposed:
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=1 
      (body:hand-wired-dispatch)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-08T23:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 4
      F-RECALL: 2
      F-ORCH: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 4
      F-RECALL: 2
      F-ORCH: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 4
      F-RECALL: 2
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 4
      F-RECALL: 2
      F-ORCH: 1
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F-AUTONOMY=0
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-02T16:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 4
      F-RECALL: 2
      F-ORCH: 1
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F-AUTONOMY=0
      (no-signal); audit_severity=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2202: dispatch AEF setup worker on /opt/832-Workflow-designer

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Prompt file written at `docs/reports/T-2202-workflow-designer-aef-setup-prompt.md` (187 lines, sed-substitution of T-2200 prompt: fan-dashboard → 832-Workflow-designer, T-2200 → T-2202).
- [x] TermLink session `workflow-designer-aef-setup` spawned via `fw termlink dispatch --task T-2202 --project /opt/832-Workflow-designer --timeout 3600`. Worker dir: `/tmp/tl-dispatch/workflow-designer-aef-setup/`.
- [x] Worker progressing past Step 1 (install) — 25KB result.jsonl growth at 15s; actively running Bash tool-uses diagnosing FRAMEWORK_ROOT mode detection (same env-leak pattern as fan-dashboard worker, evidence for T-2201 inception).
- [x] Operator surfaced session id + monitor command.

## Status: COMPLETED 2026-06-09

Prior worker exited; re-dispatched alongside T-2200 at 2026-06-09T00:43Z after `/root/.claude.json` verified valid. Completed exit 0 at 2026-06-09T01:50Z (~67 minutes runtime).

- [x] Verified `/root/.claude.json` parses as valid JSON.
- [x] Worker re-spawned: session `tl-zdqnjfal` / `workflow-designer-aef-setup`. Tagged: task:T-2202, task-type:build. Tmux backend, 3600s timeout.
- [x] Worker exited 0 (no timeout). Result captured at `/tmp/tl-dispatch/workflow-designer-aef-setup/result.md`. Event `worker.done` emitted.
- [x] Final audit verdict on `/opt/832-Workflow-designer`: **78 PASS, 2 WARN, 0 FAIL** (both WARNs documented residue).
- [x] 4 substantive fixes applied: (a) Orchestrator MCP baseline 252 → 263 (9 auto-classifiable TermLink tools + 2 manual `_status`-suffix tools as `readonly_exempt`); (b) `fw test-onboarding` env-isolation bug — added `env -u TASKS_DIR -u CONTEXT_DIR` to `fw work-on` + `handover.sh` test invocations so the test no longer leaks current-project tasks into temp dir, ID-agnostic assertions added; (c) cron audit backlog committed (290 files); (d) Watchtower started on port 3002 (3000 held by framework repo).
- [x] Cross-repo escalation: T-015 (`upstream-framework` tag) filed in workflow-designer's local task system — proposes `paths.sh` re-derive `TASKS_DIR`/`CONTEXT_DIR` from `PROJECT_ROOT` when `PROJECT_ROOT` is explicitly overridden and differs from inherited vars. Recommendation: GO. **HV signal — this is the same env-leak pattern observed in fan-dashboard worker's first launch (T-2201 inception).** May warrant framework-side task if reproducible.

Monitor archive: `termlink pty output workflow-designer-aef-setup --lines 100` (session may have been swept).

### Human
- [ ] [REVIEW] Verify workflow-designer audit verdict reproducible on the target host.
  **Steps:**
  1. `cd /opt/832-Workflow-designer && bin/fw audit 2>&1 | tail -10`
  2. Visually scan PASS/WARN/FAIL counts.
  3. Open `http://192.168.10.107:3002/` (the workflow-designer Watchtower) and confirm it loads.
  **Expected:** Audit summary line reports 0 FAIL. WARN count ≤ 3 (target was 2). Watchtower renders.
  **If not:** Re-run `cd /opt/832-Workflow-designer && bin/fw audit` and reply with the new WARN/FAIL list. The 2 documented WARNs at session end were: uncommitted audit-state file churn (normal periodic-commit residue), and orchestrator-arc cross-repo drift (T-1649, outside path isolation).

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

## Recommendation

**Recommendation:** GO — ship as partial-complete; operator runs the `[REVIEW]` Human AC to confirm reproducible verdict on the workflow-designer host.

**Rationale:** Worker delivered a clean exit-0 result with 78 PASS / 2 WARN / 0 FAIL on `/opt/832-Workflow-designer` and applied 4 substantive fixes. The most valuable signal is fix (b) — the env-isolation bug in `fw test-onboarding` reproduces the same env-leak pattern observed when T-2200's first worker launch failed (see T-2201 inception). Worker filed local T-015 in workflow-designer's task system with concrete proposal for `paths.sh` re-derivation; this is the kind of cross-project signal that should inform whether to file a framework-side observation/task.

**Evidence:**
- Worker exit-0 + `worker.done` event: `/tmp/tl-dispatch/workflow-designer-aef-setup/result.md`
- `fw test-onboarding` result: ONBOARDING BROKEN (1 FAIL) → ONBOARDING DEGRADED (0 FAIL, 1 WARN).
- Orchestrator MCP baseline tool-count 252 → 263 (worker scan exits 0).
- 290-file commit reduced cron audit backlog to zero on the workflow-designer side.
- Watchtower live on `http://192.168.10.107:3002`.

**Follow-on candidate (optional, agent will file iff operator confirms HV):** filing an observation on the framework side — *"env-var leakage causes `fw test-onboarding` + dispatched-worker first-launch failures when calling project differs from target. See workflow-designer's local T-015 for the paths.sh proposal."* Will not file unilaterally; cross-project framework changes belong to operator triage.

## Updates

### 2026-06-04T07:50:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2202-dispatch-aef-setup-worker-on-opt832-work.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1aca9623
- **Timestamp:** 2026-06-08T23:21:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
