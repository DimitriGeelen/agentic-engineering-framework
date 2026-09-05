---
id: T-3241
name: "budget gauge encodes 'could not measure' as level=ok, silently disarming the
  restart loop"
description: >
  REPRODUCED (T-3239 E3, docs/reports/T-3239-continuous-loop-demo/evidence/E3-budget-selftrigger.txt).
  Two transcripts carrying an IDENTICAL 400000-token volume against a 100000-token
  window: the scopeable one reports level=critical, exits 2 and writes .restart-requested;
  the one context_tokens.py cannot scope reports {"level":"ok","tokens":0}, exits
  0, and writes no signal. lib/context_tokens.py returns 0 by design below two in-scope
  entries ('return 0 rather than guess'), budget-gate maps 0 to ok, and nothing anywhere
  emits 'I could not measure'. A third path exits 0 even earlier when no transcript
  is found at all. Link 1 of arc-012's headline mechanic therefore fails OPEN, and
  its failure is byte-identical to a healthy fresh session — the L-555 class inside
  the arc built to remove it. This confirms and upgrades review finding W1-F5 (previously
  downgraded to plausible), and locates it one level deeper than the review did: the
  scoping rule, not budget-gate's regex fallback. Fix needs a third state (unknown)
  distinct from 0, surfaced at every gauge that consumes it; blast radius is why this
  is its own task rather than an inline change.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:continuous-run, bug, budget, false-green]
components: [C-007, C-008, agents/context/post-compact-resume.sh, lib/context_tokens.py, lib/continuous-mode.sh]
related_tasks: [T-3239, T-2885, T-2403]
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
created: 2026-09-01T07:31:04Z
last_update: 2026-09-05T08:50:43Z
date_finished: 2026-09-05T08:50:43Z
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
  - ts: '2026-09-01T07:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=258,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-01T07:45:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-09-02T08:00:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3241: budget gauge encodes 'could not measure' as level=ok, silently disarming the restart loop

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

### The ambiguous encoding is not an edge case — it is the first reading of every session

Observed live, S-2026-0901 (arc-012 E9 session), no instrumentation needed:

| moment | `.context/working/.budget-status` |
|---|---|
| at `/resume`, tool-counter 1 | `{"level":"ok","tokens":0,"timestamp":1788293872}` |
| ~6 min later, tool-counter 5 | `{"level":"ok","tokens":112183,"timestamp":1788294234}` |

The first reading is the documented `return 0 rather than guess` path: at session
start the transcript has fewer than two in-scope entries, `context_tokens.py`
returns 0, and `budget-gate` maps 0 to `level=ok`. Nothing says "unmeasured".

**Why that widens the gap as filed.** The original evidence (E3) framed this as a
scoping failure on unusual transcripts. It is more ordinary than that: *every*
session begins in the unmeasurable state, so the very first budget reading an
agent takes is always the ambiguous one. And the `/resume` skill instructs the
agent to treat this file as **canonical** and explicitly not to infer budget from
anywhere else (T-2155 / T-2156) — so the one reading the protocol most trusts is
the one that cannot distinguish "fresh" from "blind".

Here it was harmless: the session genuinely was near zero, so the false green and
the true green coincided. That coincidence is the hazard. A session resuming into
a *loaded* context that the scoper cannot read gets the identical line and reports
it, in prose, to the operator as a budget fact. I reported it as one in this
session's resume summary before checking.

The fix direction is unchanged and unaffected by this note: emit an explicit
`level=unknown` (or a `measured: false` field) rather than encoding failure as the
safe value. This observation only argues the blast radius is every session start,
not a rare transcript shape.

### Third trigger path — external field report (001-CashWeb T-222/G-087, folded in via T-3264)

001-CashWeb (a consumer project) hit the same fabricated-`ok`/0 shape independently
in production, from a different code path than either of the two above, and sent a
tested patch. Verified independently against this repo's own `lib/context_tokens.py`
before trusting it:

`context_tokens.py:111` (`main()`) passes `sys.stdin` directly into the line
iterator inside `compute_context_tokens_detail`. The `try/except` at
`context_tokens.py:60-63` only guards `json.loads(line)` — it does not guard the
`next()` call the `for line in lines:` loop performs to *produce* each line. A
transcript containing invalid UTF-8 bytes raises `UnicodeDecodeError` during that
iteration, outside any guard, so the whole Python process crashes: empty stdout,
exit 1, traceback on stderr. `budget-gate.sh`'s slow-path regex fallback
(`[[ "$TOKENS" =~ ^[0-9]+$ ]] || TOKENS=0`) cannot distinguish "scan legitimately
measured zero" from "scan crashed and produced nothing" — both collapse to
`TOKENS=0` → `LEVEL=ok` → `{"level":"ok","tokens":0}` written to `.budget-status`,
byte-identical to a healthy fresh session. In 001-CashWeb's production incident this
fired once at ~297,923 real tokens (~99% of window) and once at ~70,549 (~23%) — in
both cases the gate later blocked mid-task on the real number, after the false
"you have budget" reading had already let a full task get picked up.

A second, independent gap the same report surfaces: `.budget-status` carries no
`session_id`. One cache file per project (not per session) means a fresh cache from
session A is indistinguishable from a stale-but-still-fresh-enough cache, or a
foreign session's cache, when read by session B.

**Fix shape adopted here (adapted from the external diff, re-verified against this
repo's code rather than applied verbatim):**
1. `budget-gate.sh` slow path: distinguish "scan produced a valid integer" from
   "scan failed/produced nothing" (`SCAN_OK`). Only a successful scan computes and
   writes a real `ok/warn/urgent/critical` level; a failed scan writes
   `{"level":"unknown","tokens":null,...}`. This is the same `unknown`-state
   architecture T-3241 already commits to for the other two trigger paths — one
   fix, three triggers. Gate enforcement is unchanged: no case arm matches
   `unknown`, so a failed scan still fails open exactly like the existing
   no-transcript path; only the on-disk claim changes.
2. Both the real-measurement branch and the `unknown` branch, plus
   `post-compact-resume.sh`'s deliberate `{ok,0}` reset seed, stamp `session_id`
   (read from `session.yaml`, same pattern `_write_restart_signal` already uses at
   `budget-gate.sh:58-60`).
3. `checkpoint.sh` gains a `budget` subcommand: a safe reader that reports
   `level: unknown` (with a `reason:`) when the cache is writer-marked unknown,
   older than `BUDGET_STATUS_MAX_AGE`, or was written by a different `session_id` —
   rather than trusting a plausible-looking but wrong cached level. Verified not to
   false-positive on a fresh, valid, own-session cache.
4. `budget-gate.sh`'s own fast-path cache-trust logic (the code gating every tool
   call) is deliberately left untouched — it already re-validates stale `critical`
   against the live transcript, and adding session-identity checking to the hottest
   path in the framework is a larger, separately-justified change. The
   `unknown`-vs-fabricated-`ok` guarantee is scoped to the cache *writer* (both
   trigger paths) and to the new dedicated *reader* (`checkpoint.sh budget`), not
   to the fast-path gate itself.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `budget-gate.sh` slow path writes `{"level":"unknown","tokens":null,...}` (not a fabricated `ok`/0) when `context_tokens.py` crashes or produces no parseable output (SCAN_OK=false), and a negative test proves it using a transcript with invalid UTF-8 bytes.
- [x] Control: a transcript with ≥2 dominant-model usage entries whose token totals are genuinely all zero (a confident measurement, not an under-fill) still writes a real `{"level":"ok","tokens":0}` — the fix does not turn every honest zero into a false alarm.
- [x] `budget-gate.sh` slow path writes `{"level":"unknown",...}` (not `ok`) for T-3241's original two trigger paths: fewer than 2 dominant-model usage entries since the last compact boundary, and zero usage entries found in the transcript at all.
- [x] Every branch that writes `.budget-status` (budget-gate.sh real-measurement branch, budget-gate.sh unknown branch, post-compact-resume.sh's `{ok,0}` reset seed) stamps `session_id` read from `session.yaml`.
- [x] `checkpoint.sh budget` reports `level: unknown` plus a `reason:` line when the cache is writer-marked unknown, older than `BUDGET_STATUS_MAX_AGE`, or written by a different `session_id` than the caller's own.
- [x] Control: `checkpoint.sh budget` reports the real cached level cleanly (no false "unknown") for a fresh, valid, own-session cache.
- [x] `budget-gate.sh`'s existing fast-path enforcement behavior is unchanged: no case arm added for `unknown`, so an `unknown`-level cache still falls through to the slow path / fails open exactly as the pre-existing no-transcript path does today. Existing `tests/e2e/tier-a/test-budget-gate.sh` still passes.
- [x] The four files this task touched (`lib/context_tokens.py`, `agents/context/budget-gate.sh`, `agents/context/checkpoint.sh`, `agents/context/post-compact-resume.sh`) are resynced to the vendored `.agentic-framework/` copy (`FW_VENDOR_ONLY="<paths>" bin/fw vendor self`), per CLAUDE.md §Vendored-path-touching tasks. (Whole-repo `bin/fw vendor self --check` may still report DRIFT from other in-flight, unrelated uncommitted files — not this task's scope.)

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
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

out=$(bats tests/unit/t3241_budget_status_unknown_state.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t2885_context_tokens_model_scope.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t3204_budget_cap_legibility.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash tests/e2e/tier-a/test-budget-gate.sh > /tmp/.t3241-e2e.out 2>&1; echo $? | grep -q '^0$'
bash -n agents/context/budget-gate.sh
bash -n agents/context/checkpoint.sh
bash -n agents/context/post-compact-resume.sh
python3 -c "import ast; ast.parse(open('lib/context_tokens.py').read())"
# fw vendor self --check reports whole-repo drift, including any OTHER task's
# unrelated in-flight changes (e.g. lib/paths.sh at time of writing) — this
# task's own AC is scoped to the four files it actually touched.
diff -q lib/context_tokens.py .agentic-framework/lib/context_tokens.py && diff -q agents/context/budget-gate.sh .agentic-framework/agents/context/budget-gate.sh && diff -q agents/context/checkpoint.sh .agentic-framework/agents/context/checkpoint.sh && diff -q agents/context/post-compact-resume.sh .agentic-framework/agents/context/post-compact-resume.sh

## RCA

**Symptom:** `.context/working/.budget-status` writes `{"level":"ok","tokens":0}`
(or, before the token count is added at all, silently reports a healthy level) in at
least three distinct situations that are NOT a healthy fresh session: (1) fewer than
2 dominant-model usage entries since the last compact boundary — `context_tokens.py`'s
documented "return 0 rather than guess" path; (2) no transcript file can be located
at all; (3) the transcript scan crashes (e.g. `UnicodeDecodeError` on invalid UTF-8
bytes during line iteration) and produces empty stdout. All three collapse, via
`budget-gate.sh`'s `[[ "$TOKENS" =~ ^[0-9]+$ ]] || TOKENS=0` fallback, into the exact
same on-disk shape as a genuinely healthy zero-usage session — the reading the
`/resume` protocol treats as canonical (T-2155/T-2156).

**Root cause:** the cache schema has no way to represent "I could not measure this"
as distinct from "I measured zero". Three independent code paths (a designed
under-fill guard, a missing-file guard, and an unguarded exception) all fail into
the same value space (`level=ok, tokens=0`) because that value space was never
designed to carry a failure signal — it was designed to carry a measurement.

**Why structurally allowed:** the gate's own safety property (fail open rather than
block a session on a measurement it cannot trust) was implemented by defaulting the
*ambiguous* state to the *safe* state, rather than by adding a third state and
routing both "ok" and "unknown" to the same enforcement outcome (allow) while
keeping the on-disk claim honest. Nothing downstream (the `/resume` skill, prose
budget statements, `checkpoint.sh`'s own reads) had a way to ask "was this actually
measured?" — the schema had no field to ask it of. Reproduced live in S-2026-0901
(T-3239 E3: two transcripts carrying an identical 400k-token volume, one scopeable
→ correctly reports critical, one not → reports ok/0) and independently in
production by a consumer project (001-CashWeb, their T-222/G-087) via the third
(crash) path.

**Prevention:** `.budget-status` gains a genuine third state (`level: "unknown"`,
`tokens: null`) that every writer (`budget-gate.sh`, `post-compact-resume.sh`) uses
for all three trigger paths, plus a `session_id` field so a reader can also tell a
cache apart from a stale or foreign-session one. `checkpoint.sh budget` is the
dedicated safe reader that surfaces `unknown` (with a reason) rather than ever
echoing a plausible-looking but untrustworthy cached level. The negative-test bats
file (six cases: crash→unknown, honest-zero control→ok, session-id present,
stale-cache→unknown, foreign-session→unknown, fresh-valid-own-session control→passes
through) pins the distinction so a future edit that re-collapses the states fails a
test rather than shipping silently, the way this one did for the life of the file.

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

### 2026-09-03 — third trigger path folded in from field report

- **What changed:** filing-time scope was two trigger paths (scoping <2 entries,
  no transcript). A field report from consumer project 001-CashWeb (their T-222,
  origin G-087) surfaced a third — `context_tokens.py` crashing on invalid UTF-8
  during transcript scan — that collapses into the identical fabricated-`ok`/0
  shape. Verified independently against this repo's own code before trusting it.
- **Plan impact:** none to the fix architecture (the `unknown`-state design already
  chosen here covers all three paths without modification) — only widened the ACs
  and negative-test matrix to assert all three, plus adopted the report's
  `session_id` addition and `checkpoint.sh budget` safe-reader, which weren't part
  of the original filing.
- **Triggered:** a separate task T-3264 was opened first (before the overlap with
  this task was noticed), then demoted to `captured`/`later` and its evidence
  folded in here rather than shipping two patches to the same file. See T-3264 for
  the demotion record.

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-09-01T07:31:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3241-budget-gauge-encodes-could-not-measure-a.md
- **Context:** Initial task creation

### 2026-09-03T18:52:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d2a787df
- **Timestamp:** 2026-09-05T08:50:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-05T08:50:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
