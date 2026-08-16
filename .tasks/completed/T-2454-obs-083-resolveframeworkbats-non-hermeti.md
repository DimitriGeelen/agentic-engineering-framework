---
id: T-2454
name: "OBS-083: resolve_framework.bats non-hermetic — inherited FRAMEWORK_ROOT overrides
  fixtures (3 resolution-guard tests red)"
description: >
  OBS-083: resolve_framework.bats non-hermetic — inherited FRAMEWORK_ROOT overrides
  fixtures (3 resolution-guard tests red)

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
created: 2026-06-21T13:29:21Z
last_update: '2026-08-16T22:25:06Z'
date_finished: 2026-06-21T13:32:15Z
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
  - ts: '2026-08-16T22:25:06Z'
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

# T-2454: OBS-083: resolve_framework.bats non-hermetic — inherited FRAMEWORK_ROOT overrides fixtures (3 resolution-guard tests red)

## Context

Filed as OBS-083 during T-2450 (F3 version fix) when `resolve_framework.bats` showed 3 failures while
editing `bin/fw`; git-stash proved they were pre-existing (not the F3 regression). T-2454 triages: all 3
tests fail on **both** the worktree AND the main checkout — not a worktree artifact — yet `fw` resolution
works fine in practice. Root cause is non-hermetic tests (see `## RCA`). Test-only fix.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — `tests/unit/resolve_framework.bats` passes 3/3. **Done:** all 3 green (framework-repo self,
      direct vendored, global-shim leak fix) after the fix.
- [x] AC2 — the fix makes the tests hermetic: each fixture `fw` invocation runs under
      `env -u FRAMEWORK_ROOT -u PROJECT_ROOT -u CLAUDE_PROJECT_DIR` (the `FW_HERMETIC` prefix) so the
      resolver discovers the framework from the fixture's filesystem layout, not the ambient env. **Done:**
      prefix added to all 3 `run` lines; root cause documented in a file-level comment.

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

out=$(bats tests/unit/resolve_framework.bats 2>&1); echo "$out" | grep -qE "^ok 3 " && ! echo "$out" | grep -q "^not ok"
grep -q "FW_HERMETIC=\"env -u FRAMEWORK_ROOT -u PROJECT_ROOT -u CLAUDE_PROJECT_DIR\"" tests/unit/resolve_framework.bats
test "$(grep -c 'run \$FW_HERMETIC ' tests/unit/resolve_framework.bats)" -eq 3

## RCA

**Symptom:** `tests/unit/resolve_framework.bats` — all 3 resolution-guard tests (framework-repo self,
direct vendored, global-shim leak fix) FAIL on both the worktree and the main checkout, despite `fw`
resolution working correctly in real use. Each fails the same assertion: `grep "Framework: <fixture>"`.

**Root cause:** the tests are **non-hermetic**. `tests/test_helper.bash:15` does
`export FRAMEWORK_ROOT="$(_find_framework_root)"` (=/opt/999), and `bin/fw` honours an inherited
`FRAMEWORK_ROOT` (also `PROJECT_ROOT`, `CLAUDE_PROJECT_DIR`) as an explicit override. So the fixture `fw`
binaries — meant to exercise *filesystem* discovery (cwd + `.agentic-framework` layout) — instead read
the ambient `FRAMEWORK_ROOT` and resolve to /opt/999 (`Mode: global`), never the fixture. Proven by
bisection: stripping `FRAMEWORK_ROOT` on the invocation → correct fixture resolution; setting it →
override. The env-override resolver tiers (long-standing, hardened by T-2390/T-2391/T-2446) work *as
designed*; the tests simply never isolated the env.

**Why structurally allowed:** (1) no gate runs the unit suite at task close for *unrelated* tasks, so a
red guard-test file persists silently until someone edits a nearby file and notices (here: T-2450). (2)
no hermeticity lint for bats — a test that invokes the real `fw` while `test_helper` exports
`FRAMEWORK_ROOT` looks identical to a correct one until the resolver honours that env, which it always
did. (3) an outer `env -u … bats` does NOT fix it (test_helper re-derives + re-exports FRAMEWORK_ROOT),
masking the cause unless you strip on the inner `run`.

**Prevention:** the fix itself (the `FW_HERMETIC` env-strip prefix on every fixture `fw` invocation) makes
the suite deterministic regardless of ambient env — the green state is self-defending. Captured as
**L-490** (resolution-test hermeticity: any bats that exercises `bin/fw`'s *filesystem* resolution must
strip `FRAMEWORK_ROOT`/`PROJECT_ROOT`/`CLAUDE_PROJECT_DIR` on the inner `run`, because `test_helper`
exports `FRAMEWORK_ROOT` and the resolver honours it).

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

### 2026-06-21T13:29:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2454-obs-083-resolveframeworkbats-non-hermeti.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e82b861a
- **Timestamp:** 2026-06-21T13:32:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-21T13:32:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
