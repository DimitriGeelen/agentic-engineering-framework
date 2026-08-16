---
id: T-2843
name: "doctor path-ambiguity WARN fires on every vendored consumer (category error)"
description: >
  doctor path-ambiguity WARN fires on every vendored consumer (category error)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, lib/doctor-upstream.sh]
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
created: 2026-08-06T22:28:49Z
last_update: '2026-08-16T22:25:20Z'
date_finished: 2026-08-06T22:35:56Z
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
  - ts: '2026-08-06T22:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T22:30:12Z'
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
  - ts: '2026-08-16T22:25:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2843: doctor path-ambiguity WARN fires on every vendored consumer (category error)

## Context

`fw doctor` check 2 (`bin/fw:1148-1161`, T-1097/G-028) compares `upstream_repo`
from `.framework.yaml` against the running `FRAMEWORK_ROOT` and WARNs when they
differ. But `upstream_repo` is a **pull source** and `FRAMEWORK_ROOT` is **the
copy you are running**. In vendored mode — the D-377 default — the running fw is
by design the project's own `.agentic-framework/`, so the two can never be equal.
The WARN therefore fires on every vendored consumer, unconditionally, from the
moment `fw init` finishes.

Two independent live instances:
1. Operator's by-hand onboarding of `/opt/001-test-install` (`upstream_repo` = a
   local path) — WARN present in their pasted `fw doctor` output.
2. Scratch `fw init` reproduction on current bytes (`upstream_repo` = a URL) —
   WARN present, one of 5 on a brand-new project.

Note case 1 also shows `realpath -m` being applied to something that may be a
URL; `realpath -m "https://host/x"` yields `$PWD/https:/host/x`, which is
meaningless to compare against anything.

This is the same epistemic shape as T-2839 (`fw upgrade` gluing `https://github.com/`
onto a local path): two values of different kinds compared as if they were the
same kind, with inequality read as a defect.

## Acceptance Criteria

### Agent
- [x] Vendored project whose `upstream_repo` is a **URL** produces no "Framework path ambiguity" WARN from `fw doctor`
- [x] Vendored project whose `upstream_repo` is a **local path** produces no such WARN either (the operator's case)
- [x] Non-vendored (global/shared-tooling) mode with a local-path `upstream_repo` that differs from the running framework **still WARNs** — the check keeps the purpose T-1097 gave it
- [x] `realpath` is never applied to a value carrying a URL scheme
- [x] Regression test committed covering all three cases above, green

**Live evidence** (real `fw doctor`, not the predicate in isolation):

| Scenario | `Active mode` | Verdict |
|---|---|---|
| vendored, `upstream_repo: https://example.com/…` | vendored | quiet |
| vendored, `upstream_repo: /opt/agentic-engineering-framework` | vendored | quiet |
| global, `upstream_repo: /opt/some-other-framework` | global | **WARN, as intended** |

Greenfield: `fw init` into an empty directory then `fw doctor` — WARN count 5 → 4,
with the path-ambiguity line gone. Of the remaining four, two are `[host]`-scoped
(git identity, global install size), one is session-environmental (unsupervised
session). The one genuine project-scope day-zero WARN left is "Cron registry
present but not generated", which is a distinct defect and filed separately.

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

out=$(bats tests/unit/t2843_doctor_upstream_ambiguity.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Live end-to-end: a real vendored project running the real doctor must not emit the WARN.
r=$PWD; d=$(mktemp -d); mkdir -p "$d/.tasks/active" "$d/.context/working"; ln -s "$r" "$d/.agentic-framework"; printf 'project_name: t2843-probe\nversion: 0.0.0\nupstream_repo: https://example.com/agentic-engineering-framework\n' > "$d/.framework.yaml"; out=$(cd "$d" && PROJECT_ROOT="$d" "$r/bin/fw" doctor 2>&1) || true; rm -rf "$d"; ! echo "$out" | grep -q 'Framework path ambiguity'
# Same, with a LOCAL PATH upstream — the operator's /opt/001-test-install shape.
r=$PWD; d=$(mktemp -d); mkdir -p "$d/.tasks/active" "$d/.context/working"; ln -s "$r" "$d/.agentic-framework"; printf 'project_name: t2843-probe\nversion: 0.0.0\nupstream_repo: /opt/agentic-engineering-framework\n' > "$d/.framework.yaml"; out=$(cd "$d" && PROJECT_ROOT="$d" "$r/bin/fw" doctor 2>&1) || true; rm -rf "$d"; ! echo "$out" | grep -q 'Framework path ambiguity'

## RCA

**Symptom:** Every vendored consumer — including one three seconds old — greets
its owner with `WARN Framework path ambiguity`, listing an `upstream_repo` and a
`running fw` that are supposed to differ.

**Root cause:** The check compares a *pull source* to *the copy being run* and
treats inequality as a defect. In vendored mode those are different kinds of
thing by construction, so the comparison has no true branch. Secondary: `realpath -m`
was applied to `upstream_repo` without first establishing it was path-shaped, so
a URL was silently rewritten to `$PWD/https:/host/path` before comparison.

**Why structurally allowed:** The check was written under T-1097/G-028 when
running fw *from* a shared framework checkout was normal, and equality was
achievable. D-377 then made vendoring the default — inverting the check's premise
without revisiting it. Nothing failed: a WARN that is always on is
indistinguishable from a WARN that is correctly on, and `fw doctor` still exits 0
with warnings. The greenfield suites assert `fw init` succeeds and `fw audit`
passes (T-2740); no suite asserts a *newly initialised project's doctor is quiet*.
So the signal degraded to noise and stayed there.

**Prevention:** The predicate moves to `lib/doctor-upstream.sh` as a pure function
with a bats suite pinning all three modes, including the negative control that
global mode still WARNs — so a future change that re-broadens the check goes red
instead of going quiet. The live verification lines run the real `fw doctor`
against a real vendored project for both upstream shapes, which is the assertion
that was missing.

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

### 2026-08-06T22:28:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2843-doctor-path-ambiguity-warn-fires-on-ever.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6a064dd8
- **Timestamp:** 2026-08-06T22:35:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 68
     - evidence: `r=$PWD; d=$(mktemp -d); mkdir -p "$d/.tasks/active" "$d/.context/working"; ln -s "$r" "$d/.agentic-framework"; printf 'project_name: t2843-probe\nversion: 0.0.0\nupstream_repo: https://example.com/age`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 70
     - evidence: `r=$PWD; d=$(mktemp -d); mkdir -p "$d/.tasks/active" "$d/.context/working"; ln -s "$r" "$d/.agentic-framework"; printf 'project_name: t2843-probe\nversion: 0.0.0\nupstream_repo: /opt/agentic-engineerin`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-08-06T22:35:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
