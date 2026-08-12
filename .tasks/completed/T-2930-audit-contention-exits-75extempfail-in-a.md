---
id: T-2930
name: "audit contention exits 75/EX_TEMPFAIL in all modes; cron maps 75→0; pre-push
  blocks on could-not-evaluate"
description: >
  audit contention exits 75/EX_TEMPFAIL in all modes; cron maps 75→0; pre-push blocks
  on could-not-evaluate

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-08-12T06:09:12Z
last_update: 2026-08-12T06:18:35Z
date_finished: 2026-08-12T06:18:35Z
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
  - ts: '2026-08-12T06:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-12T06:15:13Z'
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

# T-2930: audit contention exits 75/EX_TEMPFAIL in all modes; cron maps 75→0; pre-push blocks on could-not-evaluate

## Context

The pre-push audit gate failed **open** under lock contention. `audit.sh` exited
`0` when another audit held the flock, and the generated pre-push hook read `0` as
"audited, no failures". Observed live 2026-08-11 (OBS-221): a push printed
`=== Pre-Push Audit Check ===`, then `Another audit is already running — exiting`,
and was allowed through while an invariant was RED moments earlier. Nothing in the
output distinguished *audited and clean* from *not audited at all*.

The defect was **not** "contention exits 0" — that was deliberate and documented
for cron's zero-zombie contract, so a blanket non-zero would have fixed the push
gate by breaking cron. The defect was that **one code carried two meanings** and
the two callers need opposite things from it. Remedy shape accepted from 832 on
the DM rail (539/541), filed as OBS-224; `75`/`EX_TEMPFAIL` rather than a private
code because it already means transient/retry to any reader.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Audit lock contention exits `75` (`EX_TEMPFAIL`) in **every** mode — both the `flock` arm and the no-flock fallback — never `0` and never a verdict code
- [x] Cron never surfaces `75` as a failure — **verified, not changed**: every generated audit line ends `2>&1 | logger`, so the pipeline status is `logger`'s and no audit code reaches cron. Immunity pinned by test rather than left accidental
- [x] The generated pre-push hook treats `75` as **could-not-evaluate and BLOCKS**, distinct from both its pass path and its `-eq 2` failure path
- [x] The block message names contention as the reason and states what to do (retry), so the operator is not left reading a generic audit failure
- [x] The four outcomes (`0`/`1`/`2`/`75`) are mutually distinguishable at the consumer — status *and* message
- [x] A test proves the contended arm is reachable in **both** lock modes, so neither arm can be vacuously green
- [x] Anti-vacuity: a test drives the reconstructed pre-fix consumer and shows it waved a contended push through, so the repair is demonstrably repairing something
- [x] Every other consumer of the audit exit code is swept and handled (L-533 N+1 rule), not just the two named in the observation
- [x] The spec implemented here matches OBS-221/224 as filed (read the observation; do not implement from memory of it)

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

# The suite: 16 legs. Both producer arms, all four consumer outcomes, the
# reconstructed pre-fix consumer (anti-vacuity), the cron logger-pipe immunity,
# and two L-533 enumerating guards. Judged on the marker AND the absence of a
# failure marker, per the T-2738 rule — a bats run that prints "not ok" still
# prints "ok" lines for the legs that passed.
out=$(bats tests/unit/t2930_audit_contention_exit_code.bats 2>&1); echo "$out" | grep -q '^ok 16 ' && ! echo "$out" | grep -q '^not ok'
# The producer really returns 75 under contention — asserted against the shipped
# script, not against the test's model of it.
bash -c 'T=$(mktemp -d); mkdir -p "$T/.context/locks"; exec 201>"$T/.context/locks/audit.lock"; flock -n 201; PROJECT_ROOT="$T" FRAMEWORK_ROOT="$PWD" bash agents/audit/audit.sh --section structure >/dev/null 2>&1; rc=$?; rm -rf "$T"; test "$rc" = 75'
# No contention path anywhere in audit.sh still exits 0 (comments stripped first,
# since this task's own block comment quotes the old behaviour).
test -z "$(sed 's/[[:space:]]*#.*$//' agents/audit/audit.sh | grep 'already running' -A6 | grep -E '^\s*[0-9]+[-:]?\s*exit 0\s*$')"
# Every consumer that reads the audit exit code handles 75 explicitly. Counted,
# not spot-checked: pre-push hook + onboarding test = 2.
test "$(grep -lE '(audit_exit|AUDIT_EXIT)' agents/git/lib/hooks.sh agents/onboarding-test/test-onboarding.sh | wc -l)" = "2"
test "$(grep -cE '(audit_exit|AUDIT_EXIT) -eq 75' agents/git/lib/hooks.sh agents/onboarding-test/test-onboarding.sh | grep -c ':1')" = "2"
# The generated pre-push hook on disk actually carries the branch — source having
# it is not the same as the installed hook having it.
grep -q 'audit_exit -eq 75' .git/hooks/pre-push
# Hooks generator is still syntactically valid after the heredoc edit.
bash -n agents/git/lib/hooks.sh
bash -n agents/audit/audit.sh
bash -n agents/onboarding-test/test-onboarding.sh

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

**Symptom:** a push during the daily audit cron was allowed through with the
pre-push audit gate never having evaluated anything. Output read
`=== Pre-Push Audit Check ===` / `Another audit is already running — exiting`, and
the push proceeded — with an invariant RED at the time (observed 2026-08-11).

**Root cause:** `audit.sh` exited `0` on lock contention, and the generated
pre-push hook branched only on `-eq 2` (fail) and `-eq 1` (warn). Everything else
fell through to `exit 0` = allow. So *did not run* and *ran and found nothing*
were the same value, and the consumer had no way to tell them apart.

**Why structurally allowed:** the exit code was correct for the caller it was
written for. `0`-on-contention is documented at the flock arm and exists to keep
cron from accumulating zombies or emailing on every collision. The pre-push gate
was added later and inherited a code whose meaning was defined by a different
consumer's needs. Nobody changed anything wrong; a second caller arrived and the
vocabulary was never widened for it. That is why it survived: there is no moment
in the history where someone made a mistake, so there was nothing for review to
catch.

It stayed invisible because the failure is a **false green**, the same class as
T-1376's port-3000 literal: a push that asserts nothing looks exactly like a push
that asserts everything. A red gate gets noticed immediately; a gate that
silently doesn't run is indistinguishable from one that ran and was happy. The
pre-fix consumer, reconstructed and driven in the test suite, produces **rc=0 and
no output at all** — the banner above it had already told the operator the check
happened.

**Prevention:** the exit vocabulary now partitions the outcomes — `0`/`1`/`2` mean
*ran*, `75` (`EX_TEMPFAIL`) means *did not run* — so a caller cannot conflate them
by accident. Three consumers handle `75` explicitly (pre-push: BLOCK; onboarding
test: report not-evaluated; cron: immune via its logger pipe). Guarded by
`tests/unit/t2930_audit_contention_exit_code.bats`: both producer arms including
the no-flock fallback the developer's host does not take, all four consumer
outcomes asserted mutually distinct in status *and* message, the reconstructed
pre-fix consumer as anti-vacuity, the cron immunity pinned so it stops being an
accident, and two L-533 enumerating guards that go red if a future contention arm
exits `0` or omits `75`.

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

### 2026-08-12 — no cron-side change, against the spec as filed

- **Chose:** leave every cron call site untouched, and pin the existing immunity
  with a test instead.
- **Why:** OBS-224 specifies "cron call sites map 75→0". Measured before
  implementing: every generated audit line ends `2>&1 | logger -t agentic-cron`,
  and a pipeline's status is the last command's — so cron already discards *every*
  audit exit code, verified empirically (`(exit 75) 2>&1 | logger` → rc=0, and the
  same for rc=2). The mapping the spec asks for is already in effect. Adding an
  explicit one would change no behaviour while touching the registry and
  triggering the whole registry→generated→deployed drift chain for nothing.
- **But the immunity is an ACCIDENT of the logging convention, not a decision** —
  remove the logger pipe or add `set -o pipefail` and every contended cron run
  starts reporting a failure. So the test asserts both that the lines are piped to
  logger and that such a pipeline really does swallow 75. The accident is now a
  guarded invariant; that is the part worth having, not the redundant mapping.
- **Rejected:** implementing the spec literally. It would have been defensible —
  it is what was agreed — but it would have added a moving part whose only effect
  was to look like it was doing something. Deviation reported to 832 rather than
  taken silently, since they wrote the spec.

### 2026-08-12 — BLOCK at the push gate rather than warn

- **Chose:** exit 1 (block) when the pre-push audit returns 75.
- **Why:** the asymmetry decides it. A push blocked on contention costs seconds —
  wait for the other audit, push again — and the block message says exactly that.
  A push waved through on an unevaluated gate costs whatever the unaudited commit
  does downstream, discovered later and attributed elsewhere. False block is loud
  and cheap; false allow is silent and open-ended.
- **Rejected:** warn-and-allow. It reads as the considerate option and reproduces
  the original defect with a nicer message: the push still lands unaudited, and a
  warning in a passing push is read by nobody.

### 2026-08-12 — mislabelling "did not run" as "failed" is its own defect

- **Chose:** distinct messages at every consumer — "COULD NOT RUN … this is not an
  audit failure" at the push gate, "could not run (lock contention) — day-1 audit
  NOT evaluated" in the onboarding test.
- **Why:** the bug was two states sharing one code. A repair that leaves two
  states sharing one *message* is the same bug one layer up, and sends the reader
  hunting for a defect that does not exist. The suite asserts all four outcomes
  are distinct in status and message, not just in status.
- **Rejected:** letting 75 fall into the existing failure branch. Safe (loud), and
  the onboarding test would have reported "fw audit failed (exit 75)" on a
  perfectly healthy day-1 project.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-12T06:09:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2930-audit-contention-exits-75extempfail-in-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-784d9dca
- **Timestamp:** 2026-08-12T06:18:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-08-12T06:18:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
