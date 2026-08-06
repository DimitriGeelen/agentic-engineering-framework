---
id: T-2841
name: "config table parity test contradicts CLAUDE.md curated-subset design"
description: >
  config table parity test contradicts CLAUDE.md curated-subset design

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
created: 2026-08-06T21:39:56Z
last_update: '2026-08-06T21:45:11Z'
date_finished:
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
  - ts: '2026-08-06T21:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T21:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2841: config table parity test contradicts CLAUDE.md curated-subset design

## Context

`tests/lint/config-registry-parity.bats` test 2 requires **every** key in
`lib/config.sh` `FW_CONFIG_REGISTRY` to appear as `` `FW_<KEY>` `` in CLAUDE.md.
17 of 22 do not, and it has been red long enough that nobody knows how long.

CLAUDE.md's §Configuration section states its table lists **"Agent-relevant
settings"** and points at `fw config list` / Watchtower `/config` for the rest.
So the test asserts total documentation parity against a document that
explicitly documents a curated subset. One of the two is wrong; they have
disagreed silently for months because nothing ran the test (T-2837).

**Disclosure — this task changes a guard that is currently blocking me.** The
T-2837 audit check makes a red invariant a push-blocking FAIL, and this is the
red. That is a real conflict of interest, so the reasoning below has to stand
without it: the alternative (document all 17 keys) was fully available, costs
about 17 lines, and was rejected on merit, not on effort.

**Why the subset is right, not the parity.** CLAUDE.md is loaded into every
agent context on every session. Keys like `KEYLOCK_TIMEOUT`,
`TOKEN_CHECK_INTERVAL`, `BUDGET_RECHECK_INTERVAL` and `CALL_WARN/URGENT/CRITICAL`
are internal tuning constants an agent never sets; carrying them in
always-loaded context is a permanent cost for a lookup that `fw config list`
answers on demand. Every key already carries a description inline in
`lib/config.sh`, and T-2838 made `/config` complete, so nothing is undocumented —
only un-duplicated.

**The direction that would catch real rot is not tested at all.** Nothing
currently detects CLAUDE.md referencing an `FW_` key that no longer exists — a
stale doc pointing at a removed setting, which is strictly worse than an
undocumented-but-live one because it reads as authoritative. The strict test
enforces the low-value direction and leaves the high-value one open.

Fix: invert test 2 to phantom-detection, and make the subset intentional in
CLAUDE.md rather than accidental, so the test and the document agree about what
the table is for.

## Acceptance Criteria

### Agent
- [x] Test 2 asserts the **phantom** direction: every `` `FW_<KEY>` `` referenced
      in CLAUDE.md's Configuration section resolves to a real key in
      `lib/config.sh`. A documented key that does not exist fails.
- [x] Test 2 no longer requires every registry key to appear in CLAUDE.md, and
      its comment states why (curated subset by design; full list via
      `fw config list`), so the next reader does not "restore" the strict form.
- [x] The phantom direction is proven to actually fire — verified three ways,
      because the first attempt was a false negative:
      1. **Real finding on first run.** It immediately flagged
         `FW_BRANCH_BEHIND_WARN`, `FW_STALE_ARC_DAYS`, `FW_RETIRE_WHEN_ADVISORY`
         — all genuine, all invisible to the old direction. Fixed in T-2842.
      2. **Deliberate probe.** Appending `` `FW_TOTALLY_FAKE_KEY` `` to CLAUDE.md
         turned test 2 red naming the key; CLAUDE.md restored and confirmed clean
         against git.
      3. **Unplanned self-catch.** The CLAUDE.md paragraph written for AC #4
         mentioned `` `FW_CONFIG_REGISTRY` `` and went red — the array's name, not
         a setting. Allowlisted with the reason recorded.

      **The first probe was vacuous and returned the expected answer.** The fake
      key ended in `_T2841`, and the extraction regex was `[A-Z_]+` — digits
      excluded — so the key was never extracted and the test passed while
      "proving" nothing. A negative control that passes for the wrong reason is
      indistinguishable from a working check. The regex now accepts digits.
- [x] CLAUDE.md's §Configuration section states the table is a deliberate subset,
      names `lib/config.sh` / `fw config list` / `/config` as the complete list,
      and states which direction the test enforces and why — so the paragraph and
      the test cannot silently drift apart again.
- [x] `tests/lint/` is fully green (51/51, zero red), so the T-2837 audit check
      reports PASS rather than a standing FAIL that readers learn to ignore.

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

out=$(bats tests/lint/config-registry-parity.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Whole suite, since the point of this task is that the T-2837 audit check reports
# PASS rather than a standing FAIL. Asserts 51 results AND zero red — a suite that
# silently stopped running would satisfy 'no failures' on its own.
out=$(bats tests/lint/ 2>&1); [ "$(echo "$out" | grep -cE '^(ok|not ok) ')" -eq 51 ] && [ "$(echo "$out" | grep -c '^not ok')" -eq 0 ]
# The phantom direction must still fire. Probe in a scratch copy so CLAUDE.md is
# never mutated by verification; a digit-free key, because [A-Z0-9_]+ vs [A-Z_]+
# is exactly what made the first probe vacuous.
# `|| true` on the capture is REQUIRED, not defensive: this probe exists to make
# bats exit non-zero, and under the gate's `set -e` a failing $(…) aborts the line
# AT THE ASSIGNMENT — so the grep that reads the verdict never runs and the line
# fails while the check underneath it is working perfectly.
d=$(mktemp -d); cp -r lib tests CLAUDE.md web "$d"/ 2>/dev/null; printf '\nProbe: `FW_PHANTOM_PROBE_KEY`\n' >> "$d/CLAUDE.md"; out=$(cd "$d" && bats tests/lint/config-registry-parity.bats 2>&1) || true; rm -rf "$d"; echo "$out" | grep -q '^not ok 2'

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

### 2026-08-06T21:39:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2841-config-table-parity-test-contradicts-cla.md
- **Context:** Initial task creation
