---
id: T-2307
name: "T-2304 follow-on: extend _self_vendor_libs to recursive + .md filter (parity
  with _self_vendor_agents)"
description: >
  T-2304 follow-on: extend _self_vendor_libs to recursive + .md filter (parity with
  _self_vendor_agents)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-004, lib/upgrade.sh, 
      tests/unit/test_self_vendor_libs_md_filter.bats]
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
created: 2026-06-10T10:34:49Z
last_update: '2026-08-16T22:25:01Z'
date_finished: 2026-06-10T10:44:34Z
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
  - ts: '2026-06-10T10:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-10T10:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2307: T-2304 follow-on: extend _self_vendor_libs to recursive + .md filter (parity with _self_vendor_agents)

## Context

T-2304 (OBS-068) extended `_self_vendor_agents` to recursive + `.md` filter (parity with audit's libs-class drift scanner). T-2304 also extended audit's `check_self_vendor_drift` libs-class filter to include `*.md`. The asymmetry that remains: `_self_vendor_libs` in `lib/upgrade.sh:141` iterates `$FRAMEWORK_ROOT/lib/*.sh` non-recursively — so 33 tracked `.md` siblings under `lib/templates/` and `lib/templates/skills/` drift silently, and audit's own comment at `agents/audit/audit.sh:1640-1643` explicitly calls this out as the follow-on. This closes the leg by mirroring T-2304's `_self_vendor_agents` shape: while-read-find loop, `*.sh + *.md` filter, recursive subdir traversal with parent-dir `mkdir -p` at real-run, dry-run/real-run wording-split preserved (`would sync` / `synced` — caught by T-2240 pre-push gate regex).

## Acceptance Criteria

### Agent
- [x] `_self_vendor_libs()` in `lib/upgrade.sh` iterates via `while read … find` with filter `*.sh + *.md` (parity with `_self_vendor_agents`)
- [x] Recursive traversal — files under `lib/templates/` and `lib/templates/skills/` sync to corresponding paths under `.agentic-framework/lib/`
- [x] Real-run creates missing parent dirs via `mkdir -p` (matches T-2266 shape)
- [x] Dry-run wording: `Self-vendor: would sync N file(s) to .agentic-framework/lib/` (preserves T-2240 pre-push gate regex match)
- [x] Real-run wording: `Self-vendor: synced N file(s) to .agentic-framework/lib/`
- [x] Bats test `tests/unit/test_self_vendor_libs_md_filter.bats` pins the four classes (drift in dry-run, real-run syncs, .sh regression, clean-state) — 4/4 PASS
- [x] Audit's libs-class comment at `agents/audit/audit.sh:1636-1643` updated to remove the "until lib/upgrade.sh extends" advisory (now extended)
- [x] Bats t2266 (`tests/unit/t2266_self_vendor_agents.bats`) still PASS — no regression (7/7 + t2304 4/4)
- [x] `bin/fw doctor` reports no "vendored .agentic-framework/ may diverge" WARN after `bin/fw vendor self` runs to clean state

<!-- No Human AC: pure helper-extension parity work, deterministic verifiable outcome, no rendering surface, no subjective quality call. All ACs Agent-verifiable. -->

## Verification

# Helper extracted + recursive + .md filter
grep -qE '^_self_vendor_libs\(\) \{' lib/upgrade.sh
grep -qE 'while IFS= read -r _sv_src' lib/upgrade.sh
grep -qE 'find "\$FRAMEWORK_ROOT/lib".*\(.*-name "\*\.sh".*-name "\*\.md".*\)' lib/upgrade.sh
# Dry-run + real-run wording-split preserved (T-2240 gate regex)
grep -qE 'would sync.*file\(s\) to \.agentic-framework/lib/' lib/upgrade.sh
grep -qE 'synced.*file\(s\) to \.agentic-framework/lib/' lib/upgrade.sh
# Bats sibling test exists + PASSes
test -f tests/unit/test_self_vendor_libs_md_filter.bats
bats tests/unit/test_self_vendor_libs_md_filter.bats >/tmp/.t2307-bats.out 2>&1 && grep -q "ok 4" /tmp/.t2307-bats.out
# T-2266 regression net green
bats tests/unit/t2266_self_vendor_agents.bats >/tmp/.t2266-regression.out 2>&1 && ! grep -q "not ok" /tmp/.t2266-regression.out
# Live: doctor clean after sync. File-then-grep (no pipe between capture and
# grep) — clears L-387 SIGPIPE-risk and empty-output-success heuristics.
bin/fw vendor self > /tmp/.t2307-vendor.out 2>&1
bin/fw doctor > /tmp/.t2307-doctor.out 2>&1
if grep -q "vendored .agentic-framework/ may diverge" /tmp/.t2307-doctor.out; then cat /tmp/.t2307-doctor.out; exit 1; fi

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

### 2026-06-10T10:34:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2307-t-2304-follow-on-extend-selfvendorlibs-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-918575c6
- **Timestamp:** 2026-06-10T10:46:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-10T10:44:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
