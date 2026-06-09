---
id: T-2289
name: "lib/paths.sh — re-derive TASKS_DIR/CONTEXT_DIR when PROJECT_ROOT is explicitly
  overridden (env-leak class)"
description: >
  3-incident class signal (T-2200 first-launch, T-2202 worker, workflow-designer T-015).
  Symptom: when caller's session has TASKS_DIR/CONTEXT_DIR exported via prior fw context
  init and then invokes vendored fw in a different project with PROJECT_ROOT override,
  writes go to calling project. Proposed fix per OBS-053: paths.sh re-derives TASKS_DIR/CONTEXT_DIR
  from PROJECT_ROOT when explicitly overridden. Origin: OBS-053.

status: work-completed
workflow_type: build
owner: claude-code
horizon: null
tags: [paths-sh, env-leak, framework-bug, class-signal, obs-053]
components: []
related_tasks: [T-2200, T-2202]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-09T14:15:57Z
last_update: 2026-06-09T15:06:16Z
date_finished: 2026-06-09T15:06:16Z
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
  - ts: '2026-06-09T15:04:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2289: lib/paths.sh — re-derive TASKS_DIR/CONTEXT_DIR when PROJECT_ROOT is explicitly overridden (env-leak class)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `lib/paths.sh` exports `_FW_PATHS_DERIVED_BY="$PROJECT_ROOT"` after derivation
- [x] `lib/paths.sh` unsets `TASKS_DIR`/`CONTEXT_DIR` when `_FW_PATHS_DERIVED_BY` is set AND differs from current `PROJECT_ROOT`
- [x] Env-leak reproducer: outer sources with `PROJECT_ROOT=/tmp/proj-A`; subshell with `PROJECT_ROOT=/tmp/proj-B` re-sources → `TASKS_DIR=/tmp/proj-B/.tasks`
- [x] Fixture invariant preserved: same-shell explicit `TASKS_DIR` override (no prior derivation, sentinel absent) survives intact
- [x] Fresh-invocation invariant: derives `TASKS_DIR=$PROJECT_ROOT/.tasks` + `CONTEXT_DIR=$PROJECT_ROOT/.context` exactly as before
- [x] New bats `tests/unit/t2289_paths_env_leak.bats` covers all 5 scenarios — 5/5 PASS
- [x] `fw reviewer T-2289` returns Overall PASS (3 AC-verify-mismatch FPs suppressed via OV-3fd9517e/OV-26f42554/OV-1d8cb020 — same class as T-2284/T-2285/T-2288)

Note: existing baseline failures in `tests/unit/create_task.bats` (4 inception template tests — t13, t18, t19, t20) are pre-existing on master (confirmed via stash-baseline check) and unrelated to this env-leak fix. Out of scope for this slice.

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

**Symptom:** When an outer shell ran `fw context init` in project A (exporting `TASKS_DIR=/project-A/.tasks` and `CONTEXT_DIR=/project-A/.context`) and then invoked vendored fw in project B with `PROJECT_ROOT=/project-B` (via SSH dispatch, TermLink remote, or any subprocess invocation), framework writes (task files, context updates, gate-bypass log entries) went to project A instead of project B. Hit 3 times: T-2200 (fan-dashboard first-launch), T-2202 (workflow-designer first-launch), workflow-designer T-015.

**Root cause:** `lib/paths.sh:49-50` used `TASKS_DIR="${TASKS_DIR:-$PROJECT_ROOT/.tasks}"`. The `:-` default expansion only fires when the variable is empty. With an inherited (non-empty) `TASKS_DIR`, the new `PROJECT_ROOT` had no effect on the derived path.

**Why structurally allowed:** No sentinel tracked which `PROJECT_ROOT` originally derived the path vars. The script's guard `_FW_PATHS_LOADED=1` (line 24) is non-exported, so subprocess re-sources correctly skip the double-source guard — but `TASKS_DIR`/`CONTEXT_DIR` ARE exported and inherited, opening the gap. The `:-` operator's "preserve existing" semantic was always wrong for path vars that derive from another vars; the path vars are computed values, not user-overridable defaults.

**Prevention:** `_FW_PATHS_DERIVED_BY="$PROJECT_ROOT"` exported sentinel makes the env-leak detectable. When the inherited sentinel differs from the current `PROJECT_ROOT`, the unset block clears `TASKS_DIR`/`CONTEXT_DIR` and the `:-` defaults re-derive correctly. Bats test `t2289_paths_env_leak.bats` (5 scenarios) pins all four behaviours: env-leak detection, sentinel export, fixture invariant, fresh-invocation derivation. The fixture invariant is the critical one — without it, the fix would have broken every existing test that sets `TASKS_DIR` independently in setup() (≥9 tests in tests/unit/).

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

### 2026-06-09T14:15:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2289-libpathssh--re-derive-tasksdircontextdir.md
- **Context:** Initial task creation

### 2026-06-09T15:04:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-23a8d444
- **Timestamp:** 2026-06-09T15:06:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 3 (by override)
  - AC-verify-mismatch @ AC#1 (Agent)
  - AC-verify-mismatch @ AC#2 (Agent)
  - AC-verify-mismatch @ AC#6 (Agent)

### 2026-06-09T15:06:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
