---
id: T-2293
name: "fw mcp check — exit-code drift check verb for CI/pre-commit (arc-010 sibling
  to doctor)"
description: >
  fw mcp check — exit-code drift check verb for CI/pre-commit (arc-010 sibling to
  doctor)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc-010, mcp, governance]
components: [bin/fw, agents/mcp/manifest.py]
arc_id: arc-010
related_tasks: [T-2265, T-2290, T-2291]
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
created: 2026-06-09T19:04:18Z
last_update: 2026-06-09T19:17:58Z
date_finished: 2026-06-09T19:17:58Z
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
  - ts: '2026-06-09T19:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T19:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2293: fw mcp check — exit-code drift check verb for CI/pre-commit (arc-010 sibling to doctor)

## Context

After T-2290 (doctor MCP manifest content-compare) and T-2291 (CLAUDE.md
tool-set.yaml-touching Verification rule), the agent-facing drift signal for
`policy/capability-overlay/tool-set.yaml` → `agents/mcp/framework-mcp-manifest.json`
exists at `fw doctor` (one of many checks) and as a Verification one-liner pinned
in task close. What's missing is a **focused exit-code verb** that scripts /
pre-commit hooks / CI can call to get a single drift signal without parsing
doctor's mixed output.

`fw mcp check` (and `agents/mcp/manifest.py check`) emit the manifest in memory,
md5-compare to the on-disk file, and exit with a script-friendly code:

| Exit | Meaning                                       | stderr/stdout                                   |
|------|-----------------------------------------------|-------------------------------------------------|
| 0    | manifest matches tool-set.yaml                | "OK: manifest in sync (N tools)"                |
| 1    | drift — manifest differs from tool-set.yaml   | "DRIFT: regenerate via `fw mcp emit-manifest`"  |
| 2    | manifest absent — never been emitted          | "ABSENT: run `fw mcp emit-manifest`"            |

This is the structural sibling of `fw vendor self --dry-run` (T-2240) and `fw
cron --check` (the cron-registry drift verb). It composes with the pre-push
gate, CI workflows, and any tool-set-aware automation that needs to assert sync
before mutating state. Doctor keeps its mixed-output role; this verb adds the
focused-exit-code surface for callers that need it.

## Acceptance Criteria

### Agent
- [x] `agents/mcp/manifest.py` exposes a `check` subcommand that emits the manifest in memory, compares its md5 to the on-disk file, and exits 0 (sync), 1 (drift), or 2 (absent or read error).
- [x] `fw mcp check` dispatches to `python3 agents/mcp/manifest.py check` (sibling to `emit`/`show`) and the `fw mcp help` lists the new verb.
- [x] `tests/unit/t2293_mcp_check.bats` pins all three exit codes — sync→0, drift→1, absent→2 — using setup/teardown that backs up/restores the live `tool-set.yaml` + `framework-mcp-manifest.json`.
- [x] [REVIEWER] Reviewer PASS — verified via `bin/fw reviewer T-2293`.

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

# 1. Sync state: check exits 0 with OK message. L-387 capture-first.
bin/fw mcp emit-manifest
out=$(bin/fw mcp check 2>&1); echo "$out" | grep -qE "^OK:"

# 2. New bats covers all three exit codes.
bats tests/unit/t2293_mcp_check.bats 2>&1 | tail -3

# 3. Reviewer PASS or CONCERN (no FAIL). L-387 capture-first single pipe.
rev=$(bin/fw reviewer T-2293 2>&1); echo "$rev" | grep -qE "Overall:.*(PASS|CONCERN)"
rev=$(bin/fw reviewer T-2293 2>&1); ! echo "$rev" | grep -qE "Overall:.*FAIL"

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

### 2026-06-09 — verification-block hint comments are not under `## Verification` by default

- **What changed:** During filing, the template-block delete operation that removed the empty `### Human` AC section also accidentally consumed the `## Verification` heading on the next line — leaving the multi-line P-011 hint comments orphaned at the top of the body. The verification gate kept running them as comments (they all start with `#`), so the close gate did not fire on this. Caught at reviewer time when the heading was missing from the rendered task body.
- **Plan impact:** none — verification commands themselves were unaffected; only the heading was missing.
- **Triggered:** In-line fix during this task. Worth noting for future `iw-slice-worker.md` edits: when deleting the empty `### Human` block, the safe range is `### Human` heading through the line BEFORE `## Verification`, exclusive.

### 2026-06-09 — L-387 detector flags both negation form and `>/dev/null` shape

- **What changed:** The reviewer's `l387-sigpipe-risk` detector flagged the canonical negation form `! echo "$rev" | grep -q FAIL` (needed override OV-16c93834, same FP class as OV-3a659191 on T-2292). A sibling `empty-output-success` detector flagged `bin/fw mcp emit-manifest > /dev/null` — reasoned away by removing the redirect (emit-manifest's "Wrote /path" output is harmless in Verification).
- **Plan impact:** none — both findings resolved without code change.
- **Triggered:** This is the 2nd time the negation FP fired (after T-2292) — pattern is now well-established for arc-010 close gates.

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

### 2026-06-09T19:04:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2293-fw-mcp-check--exit-code-drift-check-verb.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c1c54c88
- **Timestamp:** 2026-06-09T19:18:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - l387-sigpipe-risk @ Verification:line 41

### 2026-06-09T19:17:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
