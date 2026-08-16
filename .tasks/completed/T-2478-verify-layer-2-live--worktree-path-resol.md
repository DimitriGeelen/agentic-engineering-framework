---
id: T-2478
name: "verify Layer 2 live — worktree path-resolution arc (T-2464/2465 + OBS-080)
  actual status"
description: >
  Operator asked to verify live (not from memory) whether the worktree path-resolution
  systemic fix actually landed. Check: T-2464 inception decision, T-2465 shared resolver
  (fw_reanchor_from_cwd in lib/paths.sh) presence + tests, slices T-2466/2467/2468
  status, and whether the OBS-080 gate bug (PROJECT_ROOT resolves to MAIN inside a
  worktree) still reproduces. Report DONE/ISSUE/OUTSTANDING per item with evidence.

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-06-24T07:43:23Z
last_update: '2026-08-16T22:25:07Z'
date_finished: 2026-06-24T07:45:45Z
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
  - ts: '2026-08-16T22:25:07Z'
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

# T-2478: verify Layer 2 live — worktree path-resolution arc (T-2464/2465 + OBS-080) actual status

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Live status of T-2464/2465/2466/2467/2468 recorded (active vs completed, with status field) — not from memory.
- [x] Presence + shape of the shared resolver (`fw_reanchor_from_cwd` / equivalent in `lib/paths.sh`) confirmed, with its tests located and their pass/fail recorded.
- [x] OBS-080 reproduction attempted live (does the active-task gate resolve PROJECT_ROOT to MAIN inside this worktree?) — result recorded as STILL-REPRODUCES / FIXED / INCONCLUSIVE with evidence.
- [x] Per-item DONE / ISSUE / OUTSTANDING verdict written to this task, replacing the remembered status in the chat report.

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

## Findings (2026-06-24, live)

**Verdict: Layer 2 is DONE and OBS-080 is FIXED. Live-confirmed, not from memory.**

| Item | Live status | Evidence |
|------|-------------|----------|
| T-2464 (inception: make worktrees reliable) | COMPLETED | `.tasks/completed/` |
| T-2465 (slice 1 — shared resolver) | COMPLETED | `.tasks/completed/` |
| T-2466 (slice 2 — fw worktree …) | COMPLETED | `.tasks/completed/` |
| T-2467 (slice 3 — vendored …) | COMPLETED | `.tasks/completed/` |
| T-2468 (slice 1b — python side) | COMPLETED | `.tasks/completed/` |
| Shared resolver | PRESENT | `lib/paths.sh:95 fw_reanchor_from_cwd` + `:118 fw_reanchor_from_hook_stdin` |
| Gate wiring | WIRED | `agents/context/check-active-task.sh:56` calls `fw_reanchor_from_hook_stdin "$INPUT"` |
| Tests | GREEN | `t2465_reanchor_from_cwd.bats` 10/10; `test_hook_paths.py` 8/8 |
| OBS-080 reproduction | FIXED | Direct: seeding `PROJECT_ROOT=<MAIN>` (the OBS-080 condition) then `fw_reanchor_from_cwd <worktree>` re-resolves PROJECT_ROOT to the worktree path. Behavioral: this entire session's active-task gate tracked T-2473→T-2476→T-2478 in *this* worktree's focus.yaml — if OBS-080 were live it would have read MAIN's focus and blocked regardless. |

**Caveat (honest):** the fix is correct in the framework repo's code and on this host. It depends on whichever `bin/fw` the hook executes carrying T-2465 — confirmed live here because the gate reanchored correctly all session. A consumer/host running a pre-T-2465 deployed copy would still see OBS-080 until upgraded (normal forward-deploy lag, not a defect in the fix).

**Net:** Layer 2 (worktree path-resolution) is systemically fixed — one root cause (PROJECT_ROOT resolved from wrong cwd), one shared resolver, wired into the gate, tested, and the original symptom no longer reproduces. The earlier chat report's "from memory / needs verification" is now resolved to DONE.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-24T07:43:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2478-verify-layer-2-live--worktree-path-resol.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0ec125fc
- **Timestamp:** 2026-06-24T07:45:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — Presence + shape of the shared resolver (`fw_reanchor_from_cwd` / equivalent in `lib/paths.sh`) confirmed, with its tests located and their pass/fail recorded.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/paths.sh in: Presence + shape of the shared resolver (`fw_reanchor_from_cwd` / equivalent in `lib/paths.sh`) confirmed, with its tests located and their pass/fail `

### 2026-06-24T07:45:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
