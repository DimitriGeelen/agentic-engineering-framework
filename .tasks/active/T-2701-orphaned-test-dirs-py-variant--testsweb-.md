---
id: T-2701
name: "Orphaned test dirs: py variant + tests/web unwired + 832 fixture re-pin"
description: >
  Orphaned test dirs: py variant + tests/web unwired + 832 fixture re-pin

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
created: 2026-07-31T10:49:48Z
last_update: 2026-07-31T10:49:48Z
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

# T-2701: Orphaned test dirs: py variant + tests/web unwired + 832 fixture re-pin

## Context

T-2697 shipped `tests/lint/no-orphaned-test-dirs.bats` to catch test directories no
runner globs. 832 (rail 348) ran the same check their side and found the class one
level down: 9 of their 33 `tests/test_*.py` are named by no runner. Running their
check against our tree finds the same thing here — and finds it in a place my own
guard is blind to.

`tests/web/` holds 32 Python test files. `tests/scripts/` holds 1. Neither path
appears anywhere in `bin/fw`. `fw test web` runs `python3 -m pytest web/test_app.py`
(bin/fw:7556) — a single file in the *application* directory, not the test directory.

My T-2697 guard passed them because it globs `*.bats` only. Identical shape to the
trailing-comment miss in the same batch: I fixed the instance in front of me, not
the class. Third guard-was-wrong instance this week, and this one was found by a
peer running my own check rather than by a negative control.

Also carries the mechanical half of rail 348: 832 re-pinned two shared fixtures
(laneSet reorder, proven zero-semantic), so `CANONICAL_SHA256` in
`tests/unit/test_bpmn_to_tasks.py` must move to the new sha.

## Acceptance Criteria

### Agent
- [x] `no-orphaned-test-dirs.bats` detects orphaned dirs holding `*.py` as well as
      `*.bats` (the guard's own blind spot, closed at the class not the instance)
- [x] The extended guard is negative-controlled: proven RED against a synthetic
      orphan of each file type, not merely observed green
- [x] `tests/web/` reachable from a runner, with its pass/fail state established
      BEFORE wiring and any red filed separately rather than absorbed
- [x] `tests/scripts/` dispositioned explicitly (wired, moved, or removed) — not
      left as a third silent directory
- [x] Both pytest call sites (`fw test web` and `fw test all` stage 3) name the
      same targets, pinned by a test so they cannot drift apart again
- [x] `bin/fw test invariants` red count does not increase (T-2698/T-2699 remain
      the only reds)

**Moved out, not dropped:** the `CANONICAL_SHA256` re-pin to 832's new `bbfbc5ec…`
requires 832's repaired fixture BYTES, which we do not hold. The pin is a
tamper-detector on our copy (`"canonical fixture mutated — re-fetch from 832 rail"`),
so editing the constant alone would turn a passing check into a false red while the
old bytes sit on disk. Our state is *behind* 832's repair, not broken. Bytes
requested on the rail; re-pin filed as its own task.

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
out=$(bin/fw test invariants 2>&1); echo "$out" | grep -qE '^ok .* collectable test files is referenced'
out=$(bin/fw test invariants 2>&1); echo "$out" | grep -qE '^ok .* same pytest targets'
out=$(bin/fw test invariants 2>&1); [ "$(echo "$out" | grep -cE '^not ok')" -le 4 ]
python3 -m pytest web/test_app.py tests/web/ --collect-only -q 2>&1 | grep -q "277 tests collected"

## RCA

**Symptom:** `tests/web/` — 32 pytest files including the designer-seam API
contract tests (`test_api_overlay.py`, `test_api_version_latest.py`) — was
collected by no runner. `fw test web` and `fw test all` stage 3 both ran
`pytest web/test_app.py`, a single file in the *application* directory.
`tests/scripts/` was likewise unreferenced.

**Root cause:** two independent gaps that presented as one silence.
1. The runner named a FILE where the directory-shaped verb implied a DIRECTORY.
   `fw test web` reads as "run the web tests"; it ran one file whose path merely
   starts with the same word.
2. T-2697's `no-orphaned-test-dirs.bats`, written to catch exactly this, globbed
   `*.bats` only — so the directory it existed to find was invisible to it.

**Why structurally allowed:** the guard was written against the instance that
prompted it (a bats directory) rather than the class (a directory of tests no
runner collects). Same shape as the trailing-comment miss in the same batch:
both fixed the case in hand and left the general one open. It went undetected
because a guard's silence is indistinguishable from health — the T-2697 lesson,
recurring one level down inside T-2697's own fix.

Found by 832 running our check against their tree (rail 348, their T-316: 9 of 33
`tests/test_*.py` unreferenced) and reporting the class back. Neither of us would
have found our own instance; each found the other's.

**Prevention:**
- Guard predicate now matches what a runner would COLLECT (`*.bats`, `test_*.py`,
  `*_test.py`) rather than one hard-coded extension — so the next directory is
  covered whatever language it is written in.
- Non-collectable helpers stay unflagged (`tests/scripts/yaml_parse_all_tasks.py`
  is called from task Verification blocks). Per L-527 a false-positive guard is
  not a weaker guard, it is one that gets ignored.
- Second test pins the two pytest call sites to the same targets, closing the
  limit the fix exposed: the dir-level guard proves REACHABILITY (one mention
  anywhere turns it green), not COMPLETENESS across runner paths.
- All three behaviours negative-controlled: red on a synthetic `.py` orphan, red
  on call-site drift, green on a helper-only directory.

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

### 2026-07-31T10:49:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2701-orphaned-test-dirs-py-variant--testsweb-.md
- **Context:** Initial task creation
