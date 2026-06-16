---
id: T-2425
name: "fix lib/costs.sh union-leg — fw costs blind in worktree (T-2392/T-2400 finish)"
description: >
  fix lib/costs.sh union-leg — fw costs blind in worktree (T-2392/T-2400 finish)

status: started-work
workflow_type: build
owner: agent
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
created: 2026-06-16T15:24:13Z
last_update: 2026-06-16T15:24:13Z
date_finished: null
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
---

# T-2425: fix lib/costs.sh union-leg — fw costs blind in worktree (T-2392/T-2400 finish)

## Context

T-2392 fixed the gauge sites (checkpoint.sh:86, budget-gate.sh:255, session-metrics.sh:44) to walk BOTH the worktree and main-repo Claude Code projects dirs and pick the globally-newest transcript, because Claude Code keys the projects dir on launch cwd (main repo for `claude -c`) not PROJECT_ROOT (worktree). T-2400 corpus-swept the transcript-dir encoding to other consumers but flagged `lib/costs.sh` as the remaining union-leg gap (it migrated to `fw_claude_project_dir_name` in T-2380 but kept the single-dir lookup).

Today `lib/costs.sh:_costs_jsonl_dir` (line 47-49) builds ONE candidate dir from `PROJECT_ROOT`. In a worktree session where Claude Code's actual JSONLs live in the main-repo projects-dir, `fw costs` returns "No JSONL directory found" (when worktree projects-dir doesn't exist) or an empty/incomplete listing. The shared helper `fw_claude_project_dirs` in `lib/paths.sh` already emits the union; costs.sh just needs to consume it the same way checkpoint/budget-gate/session-metrics do.

## Acceptance Criteria

### Agent
- [x] `lib/costs.sh` enumerates JSONLs across ALL dirs emitted by `fw_claude_project_dirs` (worktree-aware union, matching the T-2392 pattern at checkpoint.sh:86 / budget-gate.sh:255 / session-metrics.sh:44)
- [x] Live: `fw costs sessions` in this worktree shows 46 sessions / total turns from BOTH worktree + main-repo projects-dirs (was potentially blind pre-fix)
- [x] `fw costs` summary continues to work (live smoke at HEAD: shows 63.5B total, 46 sessions, 359K turns — no regression)
- [x] bats coverage pins the union pattern: `tests/unit/costs_union_leg.bats` 5/5 PASS (union, single-dir backward compat, no-dirs error, dedup-by-basename, _costs_jsonl_dir delegation)

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

bash -n lib/costs.sh
bats tests/unit/costs_union_leg.bats
out=$(bin/fw costs 2>&1); echo "$out" | grep -q "Token Usage Summary"

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

**Symptom:** `fw costs` could be blind in a worktree session where the actual session JSONLs live under the main-repo Claude Code projects-dir (because CC keys the projects dir on launch cwd, not PROJECT_ROOT). T-2400 corpus-swept the transcript-dir encoding fix to other consumers but flagged costs.sh as the remaining union-leg gap.

**Root cause:** `lib/costs.sh:_costs_jsonl_dir` returned a single dir built from PROJECT_ROOT alone. The shared helper `fw_claude_project_dirs` in `lib/paths.sh` (T-2392) emits BOTH the PROJECT_ROOT-keyed dir AND the main-repo-keyed dir (resolved via git-common-dir parent). costs.sh skipped the union — sibling consumers (checkpoint.sh:86, budget-gate.sh:255, session-metrics.sh:44) had already migrated.

**Why structurally allowed:** the T-2380 encoding fix (slash-only → full non-alnum tr) landed in costs.sh same shape as the gauge sites; T-2392 then introduced the union but only gauge sites were migrated. costs.sh inherited a partial fix.

**Prevention:** `tests/unit/costs_union_leg.bats` (5/5) pins the union pattern with fixtures across two candidate projects-dirs. Future corpus-sweep regressions caught at test time.

## Recommendation

**Recommendation:** GO
**Rationale:** Scoped fix to `lib/costs.sh` mirroring the shared `fw_claude_project_dirs` pattern from sibling consumers (checkpoint/budget-gate/session-metrics). Live smoke pass: 63.5B tokens / 46 sessions / 359K turns surface from a worktree. bats 5/5 PASS. Single-dir backward compat preserved (t2). Dedup by basename for the same-session-in-two-dirs case (t4).
**Evidence:**
- `lib/costs.sh:43-58` — `_costs_jsonl_dir` now delegates to `fw_claude_project_dirs` (newline-separated union)
- `lib/costs.sh:51-72` — `_costs_parse_all` Python loop splits newline-separated dir list, filters by `os.path.isdir`, globs all, dedupes by basename keeping newer mtime
- `tests/unit/costs_union_leg.bats` — 5/5 PASS (union, backward compat, no-dirs error, dedup, delegation)
- Live: `bin/fw costs` returns full summary (post-fix, this worktree)

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

### 2026-06-16T15:24:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2425-fix-libcostssh-union-leg--fw-costs-blind.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9fe3d059
- **Timestamp:** 2026-06-16T15:29:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
