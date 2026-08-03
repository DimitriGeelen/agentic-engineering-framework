---
id: T-2755
name: "fw upgrade header labels any version mismatch as behind — it never compares
  direction"
description: >
  fw upgrade header labels any version mismatch as behind — it never compares direction

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh]
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
created: 2026-08-03T00:16:00Z
last_update: 2026-08-03T10:23:15Z
date_finished: 2026-08-03T10:23:15Z
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
  - ts: '2026-08-03T00:22:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-03T00:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2755: fw upgrade header labels any version mismatch as behind — it never compares direction

## Context

The `fw upgrade` header line was an equality test wearing a directional label. The
comparator it needed already existed (T-2713's `fw_version_relation`, git-ancestry
based) and was wired into the guard below it — but not into the sentence above it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/upgrade.sh` header computes the actual direction (behind / ahead / current)
      instead of branching on string equality alone (`lib/upgrade.sh:840-844`), using the
      same comparator the T-1912 precheck already uses — one comparator, not two.
- [x] When the consumer is ahead, the header says so, and the header's wording cannot
      contradict the guard's verdict printed a few lines later in the same output.
- [x] Regression test pins all three directions (behind / ahead / equal) against the
      rendered header text, so a future refactor cannot silently reintroduce
      "any mismatch = behind".
- [x] `tests/unit/upgrade_fresh_machine_simulation.bats` stays green (CLAUDE.md
      §Consumer-Facing Command Hygiene — this is one of the three consumer-facing commands).

**How each was met.** The relation is computed once (`lib/upgrade.sh:850-857`) and read
by both the header and the T-1912 precheck. Rendering moved to a pure function
`fw_upgrade_render_pin_line` (`lib/upgrade.sh:511-551`) so the wording is reachable by a
test without standing up a consumer — the old line was only observable by running a real
upgrade against a real mismatched consumer, which is why nothing caught it. The suffix
("upgrade will refuse") is derived from `fw_version_relation_should_refuse`, the guard's
own predicate, so header and guard cannot disagree. Nine tests in
`tests/unit/t2755_upgrade_pin_line_direction.bats` pin five relations plus the
`--force-downgrade` variant, the delegation seam, and a check that the renderer never
compares versions itself.

**Live-verified** against the operator's exact numbers (dry-run, fixture consumer pinned
v1.6.354, no `version_sha`):

```
  Framework: /opt/999-Agentic-Engineering-Framework (v1.6.764)
  Pinned:    v1.6.354 (direction undecidable vs v1.6.764)

WARN    Version relation undetermined: no version_sha recorded and no tag v1.6.354 …
```

Header and WARN now agree. Before the fix that same line read `(behind v1.6.764)` while
the WARN two lines down said the direction could not be determined.

**Mutation-checked:** collapsing the `ahead` branch back to "behind" turns tests 1, 2 and
7 red. The suite bites; it does not merely co-exist with the fix.

**Origin (2026-08-03, operator report from `/opt/002-Claude-Partner-Network`):** a consumer
`fw upgrade` printed `Pinned: v1.6.354 (behind v1.6.8)` and then `REFUSED  Consumer
v1.6.354 is AHEAD of framework v1.6.8` in the same output. The header is not a
lexicographic comparison — it is `[ "$project_version" = "$fw_version" ]`, so **every**
mismatch renders as "behind". The operator-facing consequence is that the header tells you
to upgrade at the exact moment the guard is refusing to, which points a reader at
`--force-downgrade`. A downgrade did occur on that host (vendored 1.6.295 → 1.6.121,
working-tree only). This task fixes the false direction label; T-2756 investigates
whether the bootstrap auto-clone path also bypasses the T-1839 guard.

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
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

out=$(bats tests/unit/t2755_upgrade_pin_line_direction.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/version_relation.bats tests/unit/test_upgrade_runtime_downgrade_guard.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n lib/upgrade.sh
# the defect shape itself must be gone from the header
! grep -q 'behind v${fw_version}' lib/upgrade.sh

## RCA

**Symptom.** One `fw upgrade` run printed, two lines apart:
`Pinned: v1.6.354 (behind v1.6.8)` and
`REFUSED  Consumer v1.6.354 is AHEAD of framework v1.6.8`.
On the reporting host a downgrade did occur (vendored 1.6.295 → 1.6.121).

**Root cause.** The header was `[ "$project_version" = "$fw_version" ]` — an *equality*
test with a *directional* label bolted onto its else-branch. It never computed direction,
so every mismatch rendered "behind", including the ones the guard was about to refuse.

**Why structurally allowed.** T-2713 had already established that this comparison cannot
be done on version strings (VERSION is a counter that resets) and shipped
`fw_version_relation` to replace `sort -V` at *three decision sites*. The header was not
one of the three, because it was never classified as a decision site — it only prints.
That is the gap: a line that prints a direction is making the same claim as a line that
acts on one, and it reaches the operator first and louder. T-2713's own test
(`version_relation.bats:47` "no decision site still open-codes sort -V") scanned for the
old comparator; the header didn't have one to find, because it wasn't comparing at all.

A second, quieter contributor: `bin/fw:688` sources `lib/version-relation.sh` with
`2>/dev/null || true`. Any consumer of those functions that isn't reached through that
line degrades silently. Found while fixing this — `lib_upgrade.bats:95` went red because
the bats context sources `lib/upgrade.sh` alone. Now sourced defensively at
`lib/upgrade.sh:8-16`.

**Prevention.** Three layers, none of which is "remember to use the comparator":
1. `tests/unit/t2755_upgrade_pin_line_direction.bats` — nine tests over five relations;
   mutation-verified to fail when the `ahead` branch is collapsed back to "behind".
2. The delegation seam test in that file greps `lib/upgrade.sh` for the call site *and*
   for the old `behind v${fw_version}` shape, so re-inlining the defect inside
   `do_upgrade` cannot pass against an orphaned renderer.
3. The refusal suffix is derived from `fw_version_relation_should_refuse` rather than
   restated, so the header and the guard read the same predicate. Divergence would now
   require editing the predicate, not forgetting to mirror it.

**Not fixed here.** Whether the `fw upgrade` bootstrap auto-clone re-invokes from a clone
lacking the T-1839 guard — the operator's other claim — is T-2756. It is a different
mechanism and unverified; asserting on it here would be guessing.

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

### 2026-08-03T00:16:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2755-fw-upgrade-header-labels-any-version-mis.md
- **Context:** Initial task creation

### 2026-08-03T00:22:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-88e3ffe2
- **Timestamp:** 2026-08-03T10:24:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-03T10:23:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
