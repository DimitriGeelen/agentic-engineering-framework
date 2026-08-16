---
id: T-2338
name: "arc-011 M1 §2 — harness yield-point spike (orchestrator-graph hook)"
description: >
  arc-011 M1 §2 — harness yield-point spike (orchestrator-graph hook)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/dispatch/preamble.md, agents/dispatch/yield-point.sh]
related_tasks: []
arc_id: parallel-execution-aef
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
created: 2026-06-11T17:47:29Z
last_update: '2026-08-16T22:25:02Z'
date_finished: 2026-06-11T17:54:14Z
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
  - ts: '2026-06-11T22:24:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=2 (components:substrate-edit); 
      F3=1 (body/components:prompt-incidental); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2338: arc-011 M1 §2 — harness yield-point spike (orchestrator-graph hook)

## Context

Second arc-011 M1 build slice. Implements the **single-host** form of the §5
cooperative-poll mechanism from the AEF ADR — a file-flag yield point the
orchestrator writes to inject a "stop writing there" signal mid-flight.

Per T-2326 §dependencies: independent of §3 disjoint validator (T-2337, shipped),
can ship in parallel. Together §2 + §3 form the gating surface — §3 prevents
overlap at pre-flight (static), §2 prevents overlap mid-flight (dynamic).

Direct support for arc-011 headline_mechanic: "two agents on disjoint write-set
tasks run concurrently … operator observes no .tasks/ merge conflicts". When
§3 says "disjoint" but real-world drift introduces an unexpected write, §2 is
the safety net — orchestrator drops the flag, worker yields, conflict averted.

Spec: `docs/reports/arc-011-m1-single-host-sketch.md:112-152` (§2).

## Acceptance Criteria

### Agent
- [x] `agents/dispatch/yield-point.sh` exists with a `check_yield <target_path>` function: reads `.context/working/.dispatch-flag` if present; if flag content matches `refuse-write:<target_path>`, prints reason on stderr and exits non-zero
- [x] `tests/unit/test_yield_point.bats` covers: no-flag → exit 0 (write allowed); matching-flag → non-zero + stderr reason; non-matching-flag → exit 0; stale-flag (>5min old) → ignored with WARN; malformed-flag → ignored with WARN — all 5 PASS (9/9 total including multi-line/comment/help/usage siblings)
- [x] `agents/dispatch/preamble.md` documents the yield-point convention (one paragraph: when worker invokes it, what the flag format is, expected exit-code semantics)
- [x] Worked-example smoke: from this session shell, write the flag to `refuse-write:/tmp/.t2338-target`, run `agents/dispatch/yield-point.sh check /tmp/.t2338-target` — observe non-zero exit + stderr "refusing write to /tmp/.t2338-target"; then clear flag, re-run — observe exit 0

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

# AC verifications:
test -x agents/dispatch/yield-point.sh
bats tests/unit/test_yield_point.bats > /tmp/.t2338-bats.out 2>&1 && [ "$(grep -c '^ok ' /tmp/.t2338-bats.out)" -eq 9 ]
grep -q "Yield Point" agents/dispatch/preamble.md
grep -q "refuse-write:" agents/dispatch/preamble.md

## Evolution

### 2026-06-11 — slice ship: §2 harness yield-point
- **What changed:** Spec called for "ignored with WARN" on stale flag and "fail-open" on malformed. Implemented both literally — stale-flag check is `now - mtime > FW_YIELD_STALE_SECS` (default 300s); malformed flag fall-through is the unknown-directive default branch. Discovered that BSD `stat` and GNU `stat` use different flags (`-c %Y` vs `-f %m`); used the OR-fallback pattern. Discovered bats' `touch -d "10 minutes ago"` is GNU-only; added BSD `touch -t` fallback in the stale-flag test.
- **Plan impact:** None — design held.
- **Triggered:** §1 orchestrator-graph (next slice) consumes `yield-point.sh` as the runtime-collision response handler.

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

**Recommendation:** GO

**Rationale:** Second arc-011 M1 build slice landed clean. 4/4 Agent ACs verified, reviewer pending below, 9/9 bats PASS, worked-example smoke test confirms refusal+allow paths on live shell. The yield-point is the dynamic counterpart to T-2337's static disjoint validator — together they form pre-flight + mid-flight safety for the headline_mechanic. Pure shell, no IPC dependency, fails open on every error path (stale flag, malformed content, parse errors) so a broken orchestrator signal never deadlocks workers. Preamble.md updated with worker contract + orchestrator contract + exit-code semantics so the next slice (§1 orchestrator-graph) has a wire-level contract to consume.

**Evidence:**
- `agents/dispatch/yield-point.sh` — 124 lines pure shell, `check <target_path>` subcommand + `--help`
- `tests/unit/test_yield_point.bats` — 9/9 PASS (no-flag, matching-rule, non-matching, stale, malformed, multi-line, usage, --help, comment-only)
- `agents/dispatch/preamble.md` — new "Yield Point — Cooperative Poll" section documents worker invocation + orchestrator contract + fail-open guarantees
- Live smoke: `FW_YIELD_FLAG=/tmp/.t2338-flag echo "refuse-write:/tmp/.t2338-target" > $FW_YIELD_FLAG && agents/dispatch/yield-point.sh check /tmp/.t2338-target` → exit 1 + stderr; cleared flag → exit 0

**Next M1 slices unlocked:**
- §1 orchestrator-graph (consumes both §3 disjoint validator + §2 yield-point)
- §6 disjointness gate pre-flight (extends §1)
- §4 single-host parallel demo (depends on §1+§2)
- §5 /orchestrator/parallel Watchtower view (depends on §4)

## Updates

### 2026-06-11T17:47:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2338-arc-011-m1-2--harness-yield-point-spike-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7d520db4
- **Timestamp:** 2026-06-11T17:54:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-11T17:54:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
