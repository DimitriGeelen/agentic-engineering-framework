---
id: T-2269
name: "arc-010 Slice 4 — Watchtower frontend migration: one blueprint to MCP JSON
  shape"
description: >
  Migrate one Watchtower blueprint (candidate: /review or /approvals) to call framework
  MCP server via mcp__fw__* JSON shape instead of subprocess + shell-out to bin/fw.
  Closes arc-010 §11 IW-1 'both-as-siblings' commitment — demonstrates the MCP surface
  works for in-process consumers, not just headless agents.

status: captured
workflow_type: build
owner: claude-code
horizon: later
tags: [arc:capability-overlay, mcp, watchtower]
components: []
related_tasks: [T-2209, T-2265, T-2268]
arc_id: capability-overlay
unlocks_inception_decision: [T-2209:iw1-delivery-shape]
created: 2026-06-08T21:40:38Z
last_update: '2026-06-13T18:00:04Z'
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
  - ts: '2026-06-08T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-08T21:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2269: arc-010 Slice 4 — Watchtower frontend migration: one blueprint to MCP JSON shape

## Context

Closes arc-010's `iw1-delivery-shape` decision ("both-as-siblings") by demonstrating that the framework MCP server (shipped by T-2265) is usable by **in-process consumers** — not just headless `claude -p` agents. The Watchtower frontend today shells out to `bin/fw <verb>` via subprocess. This slice migrates ONE blueprint (candidate: `/review` or `/approvals`) to use the MCP server's JSON shape directly, demonstrating the parallel client surface.

**Sequencing:** strictly downstream of T-2268 (HM-A demo agent — Slice 3). Slice 3 proves the MCP surface works for the headless-agent case (the headline mechanic); Slice 4 proves it works for the in-process-Python case. Filing as `horizon: later` until Slice 3 closes and the demo evidence is captured.

**Dispatch contract:** follow `docs/dispatch-templates/iw-slice-worker.md`. Treat the migration as additive (introduce MCP client path alongside subprocess path with feature-flag) rather than replacement — see Decisions section when promoted.

**Candidate blueprint selection rationale** (decision point for the slice author):
- `/review/<id>` reads task file + computes review-state — primarily READ shape; lowest-blast-radius migration. Maps to `mcp__fw__task_show` + `mcp__fw__bvp_rank`. **Recommended starter.**
- `/approvals` queue page — primarily READ shape but renders multiple tasks; could surface MCP batching latency early.
- `/cockpit` system-health — broader read surface; lower-priority because it touches more state.

## Acceptance Criteria

### Agent
- [ ] T-2268 (HM-A demo) is in `.tasks/completed/` (or partial-complete with closed [REVIEW]) and arc-010 `demo_evidence:` is populated. Verified via `test -d .tasks/completed && ls .tasks/completed/T-2268*.md 2>/dev/null | head -1`.
- [ ] One Watchtower blueprint route migrated to MCP client path. Migrated route documented at `docs/reports/arc-010-slice-4-migration.md` with: chosen blueprint + route, before/after diff summary, feature-flag name (`FW_WATCHTOWER_MCP_CLIENT=1` or similar), rollback path.
- [ ] MCP client wrapper added at `web/clients/framework_mcp_client.py` (or `web/shared.py` extension) — minimal stdio JSONRPC client that opens framework-mcp via subprocess once per worker, caches the connection, exposes typed Python methods for the wired tool subset used by the migrated route.
- [ ] Integration test at `tests/integration/test_watchtower_mcp_client.py` (or .bats) asserts: (a) MCP client successfully calls `mcp__fw__task_show("T-2268")` and parses the returned payload, (b) the migrated blueprint route renders HTTP 200 with `FW_WATCHTOWER_MCP_CLIENT=1` env, (c) the same route still renders HTTP 200 with the env unset (backward-compat: subprocess path preserved). Green.
- [ ] Playwright test at `tests/playwright/test_watchtower_mcp_route.py` asserts the migrated route renders the same key elements with the MCP path engaged as without — i.e. no visual regression (P-013 render-surface gate).
- [ ] Feature flag `FW_WATCHTOWER_MCP_CLIENT` documented at CLAUDE.md §Configuration (or `fw config list`) with default 0 (off) and rollout note.
- [ ] `bin/fw reviewer T-2269` returns Overall: PASS or CONCERN-only-with-suppression.
- [ ] No regression in Watchtower load times for the migrated route — within ±20% of baseline (Playwright timing assertion or `curl -w "%{time_total}"`).

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
- [ ] [REVIEW] Migrated route renders correctly to the operator's eye — open `/<migrated-route>` in the browser with `FW_WATCHTOWER_MCP_CLIENT=1` and again without it. **Steps:** Compare side-by-side; check layout rhythm, content density, and any subtle text or formatting differences. **Expected:** Visually indistinguishable from the subprocess path; no surprise UI changes. **If not:** Note the divergence — Slice 4 should be a contract-level swap, not a UI re-flow.

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

## Updates

### 2026-06-08T21:40:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2269-arc-010-slice-4--watchtower-frontend-mig.md
- **Context:** Initial task creation
