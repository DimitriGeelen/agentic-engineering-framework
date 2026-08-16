---
id: T-2915
name: "resolver in-flight latch never expires — 9 tasks locked out of the loop since
  2026-07-05"
description: >
  resolver in-flight latch never expires — 9 tasks locked out of the loop since 2026-07-05

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/resolver.py, tests/unit/t2915_resolver_inflight_expiry.bats, 
      tests/unit/test_resolver.py]
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
created: 2026-08-11T11:08:56Z
last_update: '2026-08-16T22:25:22Z'
date_finished: 2026-08-11T13:19:50Z
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
  - ts: '2026-08-11T11:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-11T11:15:13Z'
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
  - ts: '2026-08-16T22:25:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=3 (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2915: resolver in-flight latch never expires — 9 tasks locked out of the loop since 2026-07-05

## Context

`fw resolver loop` has dispatched **nothing since 2026-08-11T00:27:13Z** — 24 consecutive
systemd ticks each reporting `nothing to do — no eligible tasks; dispatched 0`. That reads
as T-2914's stall guard working. It is not. Measured 2026-08-11T11:00Z:

`_select_eligible(stall_after=5)` returns **zero** eligible tasks out of ~330 active. Nine
agent-owned candidates — the only ones that survive the owner/horizon/workflow_type/AC
filters — are excluded with reason `in-flight dispatch`:

| task | last dispatch | total dispatches |
|---|---|---|
| T-2171 | 2026-06-26T10:52Z | 33 |
| T-1820 | 2026-07-05T18:40Z | 25 |
| T-2389 | 2026-07-05T20:42Z | 47 |
| T-2395 | 2026-07-05T21:43Z | 1 |
| T-100196 | 2026-07-05T22:44Z | 1 |
| T-1687 | 2026-07-06T00:16Z | 2 |
| T-1719 | 2026-07-06T02:18Z | 1 |
| T-2448 | 2026-07-06T02:49Z | 1 |
| T-2385 | 2026-07-06T03:50Z | 1 |

Every one is **five weeks stale**. `_inflight_task_ids()` (`lib/resolver.py:1236`) treats a
dispatch row without a `terminal_event` as in-flight, and nothing ever writes that event for
an abandoned worker. So the latch is permanent: a dispatch that dies silently removes its
task from the loop forever, with no expiry, no surfacing, and no distinction from a worker
that is genuinely still running.

The loop is not idle because the work is done. It is idle because every door is latched shut
from July.

Found while re-verifying T-2914 against a live tick (the deep-investigation follow-up to
OBS-212). Sibling defect T-2916 covers the stall guard being inert; the two mask each other,
which is why neither is visible from the outside.

## Acceptance Criteria

### Agent
- [x] `_inflight_task_ids()` treats a dispatch older than a bounded age (config, default
      documented) as NOT in-flight — a worker cannot be in flight indefinitely
- [x] The nine tasks above become re-eligible (or are excluded for a DIFFERENT, stated
      reason) after the fix — verified by re-running `_select_eligible` and diffing reasons
- [x] `fw resolver loop --json` distinguishes "no eligible tasks because everything is done"
      from "no eligible tasks because N are latched" — the silence must name its cause
- [x] Unit test pins the expiry: a synthetic dispatch row beyond the threshold is not
      in-flight, one within it still is (both directions, so the test cannot pass vacuously)
- [x] A stale-latch count is surfaced where an operator sees it without asking
      (`fw orchestrator status` or `fw doctor`)

**Measured extent — the Context above undercounts by 28×.** It says nine; that was the count
*after* every other eligibility filter had already removed most candidates. The true figure
from `fw resolver latched --json` is **254 tasks**, deaths clustered on 2026-05-05 (76),
2026-05-23 (47), 2026-05-14 (27), continuing through 2026-08-10. The eligible pool has been
shrinking monotonically for three months: every worker death permanently removed a task and
nothing ever added one back. The nine were simply the last ones still visible.

**Evidence the fix works, live rather than simulated:** at 13:58:43 the loop picked
**T-2171** — latched since 2026-06-26 — and dispatched `27e29813`, ending 14 hours of
starvation. The age bound was in effect at that moment as uncommitted working-tree state,
because `resolver-loop.service` execs `bin/fw` directly from the tree.

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

out=$(bats tests/unit/t2915_resolver_inflight_expiry.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
python3 -m pytest tests/unit/test_resolver.py -q > /tmp/.t2915-pytest 2>&1 && grep -q passed /tmp/.t2915-pytest
bin/fw resolver latched --json > /tmp/.t2915-latched 2>&1 && python3 -c "import json;d=json.load(open('/tmp/.t2915-latched'));assert 'latched' in d and 'max_age_min' in d"
bin/fw resolver loop --json --max 1 > /tmp/.t2915-loop 2>&1 && python3 -c "import json;d=json.load(open('/tmp/.t2915-loop'));assert 'in_flight_count' in d, 'AC3 field missing'"
# File-redirect, not capture-and-pipe: doctor's output is far past the 65536-byte
# pipe buffer, so `echo "$out" | grep -q` exits 141 (SIGPIPE) under pipefail — L-387/T-2743.
bin/fw doctor > /tmp/.t2915-doctor 2>&1; grep -q "Autonomous Dispatch" /tmp/.t2915-doctor

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

python3 -c "import ast; ast.parse(open('lib/resolver.py').read())"
bash -n bin/fw
out=$(python3 -m pytest tests/unit/test_resolver.py -k inflight -q 2>&1); echo "$out" | grep -q "4 passed" && ! echo "$out" | grep -q failed
out=$(python3 -m pytest tests/unit/test_resolver.py -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
out=$(bats tests/unit/t2915_resolver_inflight_expiry.bats 2>&1); echo "$out" | grep -q '^ok 6 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t2914_resolver_stall_guard.bats 2>&1); echo "$out" | grep -q '^ok 10 ' && ! echo "$out" | grep -q '^not ok'
# AC2. Asserts the INVARIANT, not a snapshot: no task may be excluded as
# "in-flight dispatch" on the strength of a dispatch that has already aged out.
# The original line here asserted none of the nine was in-flight at all — true
# only until the fix took effect, then permanently red: the loop resumed, picked
# the un-latched backlog, and T-1820 went legitimately in-flight at 12:27:58Z.
# A verification that passes only while the fix has no effect is worse than none.
python3 lib/resolver.py pick --json --stall-after 0 2>/dev/null > /tmp/.t2915-pick && bin/fw resolver latched --json > /tmp/.t2915-stale 2>&1 && python3 -c "import json; pick=json.load(open('/tmp/.t2915-pick')); stale=set(json.load(open('/tmp/.t2915-stale'))['latched']); inflight={t for t,r in (pick.get('excluded') or {}).items() if r=='in-flight dispatch'}; overlap=sorted(inflight & stale); assert not overlap, f'excluded as in-flight despite having aged out: {overlap}'"
python3 -c "import yaml; yaml.safe_load(open('.context/concerns.yaml'))"

## RCA

**Symptom:** the autonomous dispatch loop reports `no eligible tasks; dispatched 0` on every
tick and has dispatched nothing for 12 hours, while ~330 tasks are active and 9 of them are
agent-owned, scoped, non-inception work.

**Root cause:** `_inflight_task_ids()` derives in-flight status from the *absence* of a
`terminal_event` on a dispatch row. Absence is produced by two entirely different situations —
a worker still running, and a worker that died without writing one — and the predicate cannot
tell them apart. There is no age bound, so the second situation is permanent.

**Why structurally allowed:** the latch fails *closed* (excludes work) and the loop's only
externally visible output is `dispatched 0`. A loop that dispatches nothing because everything
is latched is byte-identical, in every log line and every `--json` field, to a loop that
dispatches nothing because there is nothing to do. Nobody is ever prompted to look. This is the
same false-green shape CLAUDE.md documents for port-3000 verification lines: the failure mode is
a green that asserts nothing.

Compounding it: the silence arrived within hours of T-2914 shipping a stall guard whose *stated
purpose* was to stop the loop over-dispatching. The fix and the defect produce the same
observable, so the defect reads as the fix working.

**Prevention:** (a) age-bound the latch so an abandoned dispatch cannot exclude forever;
(b) make the loop's silence self-describing — `dispatched 0` must carry *why*, so "nothing to do"
and "everything latched" stop being the same sentence; (c) surface the latched count in an
operator-facing status so a growing latch set is visible without running a Python probe.
(a) is the fix; (b) and (c) are what catch the next instance.

**Addendum (OBS-185, found wiring (c) into `fw doctor`):** the sibling stalled-task WARN this
new WARN was modeled on (T-2914, same "Autonomous Dispatch" doctor section) used
`echo "${_json:-{}}" | python3 -c "... except Exception: d={} ..."` to default an empty
capture to `{}`. That idiom is itself broken — bash's brace-matching in parameter expansion
appends a stray `}` to the OUTPUT whenever the variable is set and ends in `}` (which valid
JSON always does), corrupting the JSON before it reaches `python3`, which then silently
falls back to `d={}` via the bare `except`. Net effect: the T-2914 stalled-task WARN had
never actually fired, on any input, since it shipped — measured directly (real stalled
count via `fw resolver stalled --json` vs the doctor-path count) rather than inferred. Same
class this task's RCA describes one paragraph up: a green that asserts nothing, this time at
one more remove (a shell quoting bug swallowed by a Python except-clause swallowed by a
doctor WARN nobody had reason to distrust). Fixed alongside (both the stalled and the new
latched blocks) rather than shipping this task's own new WARN right next to a sibling of the
exact same shape, silently broken. Registered as OBS-185 (resolved, same commit).

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

### 2026-08-11 — adopting an autonomous worker's uncommitted implementation

- **Chose:** adopt the implementation written by dispatch worker `593a2bcc` and commit it,
  rather than discard it and rewrite, or leave it uncommitted.
- **Why:** it satisfies all five ACs on their merits — age bound with a documented default and
  env override, four distinct `stop_reason` strings, a `fw resolver latched` verb, a `fw doctor`
  **Autonomous Dispatch** section, and a 6-leg bats suite whose legs 1 and 2 are the two
  required directions (all green, plus 31 pytest). Discarding working, tested code to rewrite
  it identically would be waste. Leaving it uncommitted was not an option: `resolver-loop.service`
  execs `bin/fw` from the working tree, so the fix was already governing production while
  existing only as unstaged state — one `git checkout` from being lost silently.
- **Rejected:** committing it silently as my own. The authorship is recorded here and in the
  commit body because T-2917 is open on exactly this — worker commits being indistinguishable
  from operator commits. Filing that defect and then obscuring an instance of it would be
  incoherent.
- **Note:** the worker did not close its own task. It died `aborted_streaming` after 168 turns
  and $10.54, having been refused three times by gates — twice on
  `fw task update T-2915 --status work-completed`. It did the work and could not record it.

### 2026-08-11 — in-flight age bound default (240min)
- **Chose:** `FW_RESOLVER_INFLIGHT_MAX_AGE_MIN` defaults to 240 (4 hours), env-only
  (no `FW_CONFIG_REGISTRY` entry yet).
- **Why:** measured worst-case legitimate dispatch duration is well under an hour —
  `TermLinkWorker` defaults to a 1800s (30min) internal timeout, and every
  pi/ollama-loop row sampled from `dispatches.jsonl` completed inside a single 30-min
  systemd tick. 240min is a wide safety margin above that ceiling (roughly 8x) while
  remaining far short of "weeks" — the failure mode this fixes. Env-only mirrors the
  existing precedent of `FW_RESOLVER_BVP_RANK` / `FW_DISPATCH_ORIGIN` (both read
  directly via `os.environ` in `lib/resolver.py` with no registry entry) rather than
  adding a new registry key for a single-consumer internal tuning constant.
- **Rejected:** (a) tying the bound to `TERMLINK_WORKER_TIMEOUT` (600s/10min,
  already in `FW_CONFIG_REGISTRY`) — rejected because that constant governs a
  different worker_kind's internal timeout, not a general dispatch-row age bound,
  and pi/ollama-loop dispatches have no such cap; conflating them would risk
  expiring a genuinely-running non-TermLink worker. (b) a much shorter bound
  (e.g. 60min) — rejected as leaving less margin for a slow but legitimate
  dispatch to be mistaken for abandoned, with no offsetting benefit (the defect
  this fixes was five *weeks*, not minutes).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-11T11:08:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2915-resolver-in-flight-latch-never-expires--.md
- **Context:** Initial task creation

### 2026-08-11T12:00Z — build [dispatched worker]
- **Action:** Age-bounded the in-flight latch (`lib/resolver.py`): `_inflight_dispatch_status()`
  now splits dispatch rows with no `terminal_event` into "in-flight" (within
  `FW_RESOLVER_INFLIGHT_MAX_AGE_MIN`, default 240min) and "stale" (beyond it, no longer
  excludes). `_inflight_task_ids()`/`_stale_inflight_ids()` are the two read sides.
  `fw resolver loop --json` now names its own cause (`in_flight_count` field + stop_reason
  text distinguishing "N in-flight" from "nothing to do" from "N excluded, none in-flight").
  New `fw resolver latched [--json]` CLI surfaces the stale set; wired into `fw doctor`'s
  Autonomous Dispatch section as a WARN/OK line alongside the existing stalled-task check.
- **Discovered + fixed alongside (OBS-185):** the sibling stalled-task WARN (T-2914) used a
  broken `${var:-{}}` bash idiom that silently corrupted its own JSON and always reported
  zero regardless of the real count — same false-green shape as this task's core defect, one
  layer down. Fixed both call sites (stalled + new latched) with an explicit empty-check +
  `printf` instead of the buggy parameter-expansion default.
- **Verified:** all nine originally-latched tasks (T-2171, T-1820, T-2389, T-2395, T-100196,
  T-1687, T-1719, T-2448, T-2385) are eligible again per `fw resolver pick --json` (measured
  directly, not inferred). New pytest unit tests (`test_resolver.py::test_inflight_*`, 4
  tests) pin both directions of the expiry so the test cannot pass vacuously. New bats file
  `t2915_resolver_inflight_expiry.bats` (6 tests) pins the CLI-level surfacing. Pre-existing
  `t2914_resolver_stall_guard.bats` (10 tests) still green — no regression to the stall guard
  it sits beside.
- **Output:** `lib/resolver.py`, `bin/fw` (Autonomous Dispatch doctor section),
  `tests/unit/test_resolver.py`, `tests/unit/t2915_resolver_inflight_expiry.bats`,
  `.context/concerns.yaml` (OBS-185)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b697c001
- **Timestamp:** 2026-08-11T13:23:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-11T13:19:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
