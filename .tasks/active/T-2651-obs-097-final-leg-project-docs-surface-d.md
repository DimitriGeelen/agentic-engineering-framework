---
id: T-2651
name: "OBS-097 final leg: /project docs surface dual-root — list and serve framework-owned
  AGENT.md docs in split-root"
description: >
  OBS-097 final leg: /project docs surface dual-root — list and serve framework-owned
  AGENT.md docs in split-root

status: work-completed
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
created: 2026-07-28T08:55:49Z
last_update: 2026-07-28T09:02:26Z
date_finished: 2026-07-28T09:02:26Z
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
  - ts: '2026-07-28T09:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T09:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2651: OBS-097 final leg: /project docs surface dual-root — list and serve framework-owned AGENT.md docs in split-root

## Context

Final OBS-097 leg. T-2648 dispositioned core.py's /project agents listing as
allowlist-with-annotation because the surface is PROJECT_ROOT-relative
end-to-end (a lone resolution flip 500s in split-root). This task does the
paired listing+serving change: framework-owned docs (agents/*/AGENT.md) get a
`fw--` doc_id prefix routed to FRAMEWORK_ROOT in project_doc with its own
containment check. The prefix is emitted ONLY when roots differ — coincident
(framework repo) behavior stays byte-identical. Closes the last open
structural item in OBS-097's prevention scope.

## Acceptance Criteria

### Agent
- [x] Under split roots, /project lists framework AGENT.md docs and /project/fw--agents--<name>--AGENT serves 200 with content (subprocess test, same isolation as T-2650)
- [x] Coincident-root behavior unchanged: no fw-- prefix emitted, existing doc_ids identical, tests/web suite green
- [x] Containment holds for the fw-- namespace: a traversal-shaped doc_id 404s
- [x] T-2648's OBS-097-allow annotation on core.py removed (site now properly dual-root); grep-lint + shell ratchet still green
- [x] OBS-097 concern updated: all four prevention legs built; concern moves to watching

### Human
- [ ] [REVIEW] /project page renders correctly after the change
  **Steps:**
  1. Open http://192.168.10.107:3001/project
  2. Confirm the Agents category lists AGENT.md docs and one opens with rendered content
  **Expected:** listing and doc pages look unchanged from before (coincident roots — the change only activates in split-root consumers)
  **If not:** note the broken category/doc — the doc_id scheme change is the suspect

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

python3 -m pytest tests/web/test_project_dual_root.py tests/web/test_split_root_smoke.py -q
bats tests/unit/audit_split_root_asset_lint.bats
rc=0; out=$(grep -c "OBS-097-allow" web/blueprints/core.py) || rc=$?; test "$out" = "0"
curl -sf "$(bin/fw watchtower url)/project" > /dev/null
curl -sf "$(bin/fw watchtower url)/project/agents--git--AGENT" > /dev/null

## Recommendation

**Recommendation:** GO — approve the /project dual-root change (tick the [REVIEW] AC and complete).

**Rationale:** The change is inert where you'll review it (coincident roots — framework repo behavior is byte-identical, verified live: /project 200, agent docs listed, doc page 200) and only activates in split-root consumers, where it turns silently-vanishing vendored AGENT.md docs into listed, served pages. All four automated guards are green.

**Evidence:**
- tests/web 132/132 green including the two new files (test_project_dual_root.py: split-root probes, coincident byte-identity, traversal 404; test_split_root_smoke.py unaffected)
- audit_split_root_asset_lint.bats 11/11 (grep-lint clean after removing the core.py OBS-097-allow annotation — the site is now properly dual-root)
- Live-verified on :3001 after restart: /project → 200, `agents--git--AGENT` listed with NO fw-- prefix, /project/agents--git--AGENT → 200

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

## Updates

### 2026-07-28T08:55:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2651-obs-097-final-leg-project-docs-surface-d.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ff07ae94
- **Timestamp:** 2026-07-28T09:02:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 35
     - evidence: `curl -sf "$(bin/fw watchtower url)/project" > /dev/null`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 36
     - evidence: `curl -sf "$(bin/fw watchtower url)/project/agents--git--AGENT" > /dev/null`

### 2026-07-28T09:02:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
