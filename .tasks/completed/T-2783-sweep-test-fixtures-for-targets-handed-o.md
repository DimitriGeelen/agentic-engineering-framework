---
id: T-2783
name: "Sweep test fixtures for targets handed out without being pinned"
description: >
  T-2782 found that `base_url` returned a URL without depending on the fixture that
  starts a server behind it, so test_all_routes_size.py never started one and measured
  whatever held the port — the operator's live Watchtower, for every run to date.

  The shape generalises: a fixture that hands out a *reference to a target* (URL,
  port,
  path, project root, session id) without also depending on whatever establishes that
  target. The test then asserts confidently about whatever happens to be there. This
  is
  the same wrong-object class as the :3000 false-greens (CLAUDE.md §Watchtower Port)
  and
  the T-2762 foreign-source read.

  Sweep the test corpus for other instances and close or explicitly clear each one.
  OBS-140.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/playwright/conftest.py, web/app.py]
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
created: 2026-08-04T10:02:14Z
last_update: '2026-08-16T22:25:17Z'
date_finished: 2026-08-04T10:08:32Z
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
  - ts: '2026-08-16T22:25:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2783: Sweep test fixtures for targets handed out without being pinned

## Context

Sweep born from T-2782 / OBS-140. See `## Findings` below for the result.

## Findings

**Corpus examined:** 3 in-repo `conftest.py` files (`tests/playwright/`, `tests/web/`, `web/`),
150 `tests/playwright/test_*.py`, plus all `tests/web/` and `web/test_*.py`. Nine further
`conftest.py` copies exist under `.claude/worktrees/` — stale checkouts, not part of this
branch's corpus and not run; they still carry the pre-T-2782 `base_url()` and will inherit the
fix when those worktrees are reconciled or pruned.

**Fixtures handing out a target reference:**

| Fixture | Target | Depends on what establishes it? |
|---|---|---|
| `tests/playwright/conftest.py:base_url` | URL | **now yes** (fixed in T-2782; was the origin instance) |
| `tests/playwright/conftest.py:page` | browser page | yes — takes `watchtower_server` |
| `tests/playwright/conftest.py:watchtower_server` | the server itself | n/a — it *is* the establishing fixture |
| `tests/web/conftest.py:_restore_web_shared_root` | `PROJECT_ROOT` / `web.shared` | n/a — restores state, hands out nothing |
| `web/conftest.py` | — | no fixtures; markers and consumer-mode skip only |

No further instance of the exact `base_url` shape — a fixture returning a reference with no
dependency on what establishes it — exists in the corpus.

**Cleared on evidence, not on reading.** `tests/web/` and `web/` never construct a URL or a
port: zero matches for `localhost:<port>` / `127.0.0.1:<port>` across both. They drive Flask's
in-process test client, where the app object *is* the target and cannot be absent or foreign —
there is no port for another project's server to answer on. `page` is cleared because removing
`watchtower_server` from its signature makes `pg.goto` fail on connection refused, which is
observable, not inferred.

**One adjacent instance found, different shape, filed as T-2784.** 81 of the 150 playwright
test files define their own module-level `TEST_URL = "http://localhost:3099"`; none of the 81
reads `FW_TEST_PORT`; 3 files use the correct shape (importing `TEST_URL` from conftest). All
81 *do* take `page`, so a server is established — this is not the missing-dependency bug. It is
the other half of the same wrong-object class: conftest starts, verifies and age-bounds a server
on `FW_TEST_PORT`, while these files address a literal 3099. When those differ, T-2782's
identity check guards a server the tests are not talking to. Not fixed here because it is an
81-file mechanical change, not the one-line dependency shape this task scoped.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every `conftest.py` in the repo is enumerated, and for each fixture that returns a
      reference to a target (URL, port, filesystem path, project root, session/task id) the
      sweep states whether it depends on whatever establishes that target, or why it does not
      need to. Enumeration is by discovery, not by memory — the count of conftest files and
      fixtures examined is recorded, so a later reader can tell coverage from sampling.
      3 in-repo conftests / 5 fixtures / 150 playwright test files, tabulated in `## Findings`.
      The 9 `.claude/worktrees/` copies are named and excluded with a reason rather than
      silently dropped.
- [x] Each instance found is either fixed in this task (if it is the same one-line dependency
      shape as `base_url`) or filed as its own task with the wrong-object failure named. No
      instance is left described-but-unowned.
      One adjacent instance (81 files hard-coding port 3099) → **T-2784**, with the failure
      named: T-2782's identity check guards a server the tests are not addressing.
- [x] A cleared fixture is cleared on evidence, not on reading: for each one claimed safe, the
      sweep names what would break if the target were absent or foreign — an assertion that
      fails, a connection that refuses. "Looks fine" is not a clearance.
      `tests/web/` + `web/`: zero `localhost:<port>` matches, in-process Flask client, no port
      for a foreign server to answer on. `page`: drop `watchtower_server` and `pg.goto` fails
      on connection refused.
- [x] Result recorded even if the sweep is empty. A zero-finding sweep is a real outcome and
      must be distinguishable from a sweep that was never run — state the corpus size examined
      and that no further instances were found.
      Recorded: zero further instances of the `base_url` shape, against the corpus sizes above.

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

# The origin instance stays fixed: base_url must keep its dependency.
grep -q "def base_url(watchtower_server)" tests/playwright/conftest.py
# No NEW fixture may return a bare URL/port without depending on what establishes it.
# (tests/web + web/ drive the in-process Flask client and construct no URLs at all.)
! grep -rn "localhost:[0-9]\|127.0.0.1:[0-9]" tests/web/*.py web/test_*.py
# The adjacent 81-file instance is owned, not just described.
test -f .tasks/active/T-2784-playwright-tests-hard-code-port-3099-byp.md -o -f .tasks/completed/T-2784-playwright-tests-hard-code-port-3099-byp.md

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

### 2026-08-04T10:02:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2783-sweep-test-fixtures-for-targets-handed-o.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-932a205c
- **Timestamp:** 2026-08-04T10:08:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-04T10:08:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
