---
id: T-2883
name: "OBS-170: surface missing git identity before the curriculum's first commit
  dies RC=128"
description: >
  OBS-170: surface missing git identity before the curriculum's first commit dies
  RC=128

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:readme-first-run]
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
created: 2026-08-09T07:41:50Z
last_update: '2026-08-09T07:45:12Z'
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
  - ts: '2026-08-09T07:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-09T07:45:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 5
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=5 (body:class-neutral); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2883: OBS-170: surface missing git identity before the curriculum's first commit dies RC=128

## Context

arc-016's open blocker, named by its own keystone (T-2719 `## Recommendation`) as the
one thing standing between the arc and closure: *"fix OBS-170 (a `fw doctor` check plus
an `fw init` warning is the cheap shape), then run the by-hand path once more."*

**The failure.** `fw init` seeds a curriculum whose T-003 is literally "First governed
commit". On a machine with no git identity, that instruction dies before any framework
hook runs:

```
$ git commit -m "T-003: first commit"
Author identity unknown
*** Please tell me who you are.
RC=128
```

**That premise is stale, and this task is what is actually left.** OBS-170's own wording
("the framework never mentions git identity and `fw doctor` does not check it") was true
when T-2719 wrote it on 2026-08-05 and is false today. Measured 2026-08-09 by running
`fw init` into a clean `/tmp` project: identity is mentioned **three** times, including a
closing block that names the failing task explicitly and hands over a copy-pasteable
one-liner:

```
Done! Governance is active — but this machine cannot commit yet.
  Do this first: set a git identity, or every commit fails with
  "Author identity unknown" — including onboarding task T-003.
    cd /tmp/obs170p && git config user.email '…' && git config user.name '…'
```

`fw doctor` warns (`[host] Git user identity not configured`), and `validate-init` has a
`func-identity` check. Someone fixed it and OBS-170 was never updated.

*(I nearly missed this. My first probe — grepping the framework for `user.name` — ran
from a `/tmp` directory the previous command had `cd`'d into, so it searched a path where
`bin/fw` does not exist and returned nothing. A false negative that read exactly like
confirmation of the bug report. The positive control I insisted on for T-2882 an hour
earlier is the thing that would have caught it: prove the probe can produce a positive
before trusting its negative.)*

**What IS broken — a false positive, measured.** All five surfaces probe identity with
`git config user.email` / `user.name`. That misses identity supplied through the
environment, which is how CI, cron and dispatch workers supply it. With
`GIT_AUTHOR_*`/`GIT_COMMITTER_*` set and no config:

| | |
|---|---|
| `fw doctor` says | `WARN [host] Git user identity not configured (commits will fail)` |
| `git commit` actually does | **RC=0**, commit `4aa0136` created |

So the framework asserts a failure that does not happen, in the one situation where the
operator cannot act on the advice (there is nothing to configure — it already works).
That is the L-527 class: a warning that fires when nothing is wrong stops carrying
information, and this one fires on every automated run.

**The fix is one predicate, five consumers.** `git var GIT_COMMITTER_IDENT` resolves
identity exactly the way `git commit` does — env vars, local, global, system config, and
git's own fallbacks — so it cannot report a problem `git commit` would not have. Verified
both directions before building on it: unresolvable → RC=128, env-vars-only → RC=0. The
five sites currently carry five slightly different `git config` probes, which is the
L-399 producer/consumer split in miniature: they can disagree, and nothing makes them
agree.

Sites: `lib/preflight.sh:154`, `lib/init.sh:147` (the auto-copy guard),
`lib/init.sh:774` (the closing block), `lib/setup.sh:441`, `lib/validate-init.sh:540`,
`bin/fw:1389` (doctor check 5b).

Scope fence: detect and tell, consistently. This task does not set identity for the
operator, does not prompt interactively, and does not touch the commit path. It does not
close arc-016 — that is the operator's call, and it now needs a fresh look because the
blocker its keystone recorded is gone.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] One shared predicate resolves git identity the way `git commit` does
      (`git var GIT_COMMITTER_IDENT`), living in one file rather than being re-derived
      per caller
- [x] All six call sites use it — `lib/preflight.sh`, both `lib/init.sh` sites,
      `lib/setup.sh`, `lib/validate-init.sh`, `bin/fw` doctor check 5b — so no surface
      can disagree with another about whether this machine can commit (L-399)
- [x] The false positive is gone: with identity supplied only through
      `GIT_AUTHOR_*`/`GIT_COMMITTER_*`, no surface claims commits will fail
- [x] The true positive survives: with no identity resolvable at all, every surface still
      warns and still hands over its copy-pasteable remedy — the fix must not be
      "stop warning" (this is the leg that makes the one above mean something)
- [x] TEETH: a bats suite drives both states through git's **real** refusal — isolated
      `HOME` with `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM` at `/dev/null`, not a stub —
      and pins that a commit succeeds in exactly the state the predicate calls OK (L-530)
- [x] Silent in this repo, which has a working local identity, so the change does not
      introduce a line that always fires (L-527)
- [x] The by-hand persona suite still passes — this change lands on the path that suite
      walks, so a regression there is a regression in the thing arc-016 exists to protect
- [x] OBS-170's record is corrected to say what is actually left, so the next reader of
      arc-016 does not re-derive a fixed bug from a stale note

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

# Teeth: both states through the real probe.
out=$(bats tests/unit/git_identity_check.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Silent when identity resolves — this repo has a working local identity.
out=$(bin/fw doctor 2>&1); ! echo "$out" | grep -qi "git identity"
# The path arc-016 protects still walks.
out=$(bats tests/integration/readme_five_minute_by_hand.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

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

### 2026-08-09 — the bug report was stale and the real defect pointed the other way

- **What changed:** the task was filed to build a `fw doctor` check and an `fw init`
  warning that OBS-170 said did not exist. Both already existed, along with a
  `validate-init` check — three surfaces, one of them naming onboarding task T-003
  explicitly. Between T-2719 recording the blocker on 2026-08-05 and this session, it was
  fixed and the note was never updated. The real defect was the mirror image: the shared
  question "can this machine commit?" was answered by reading `git config user.email`,
  which misses env-supplied identity, so the framework told machines whose commits
  succeed that their commits would fail.
- **Plan impact:** the deliverable inverted. Not "add a warning" but "stop a warning
  from firing when nothing is wrong", and — because five files each carried their own
  slightly different probe — consolidate them onto one predicate so they cannot drift
  apart again (L-399). The remedy strings stayed; only the question changed.
- **Triggered:** OBS-170 dismissed with the measurement rather than left open.
  **arc-016's recorded closure blocker is gone** — its keystone's Recommendation says
  "fix OBS-170, then run the by-hand path once more and capture that run as the arc's
  `--demo`". The first clause is now done. The remaining clause is a live by-hand run,
  which is the operator's to walk and the arc's to close (§ACD / G-062 — closure is not
  agent-side, and "substrate is in place" is not the mechanic firing).

### 2026-08-09 — the false negative I nearly shipped

- **What changed:** my first probe for "does the framework mention git identity?" was a
  grep that ran from a `/tmp` directory a previous command had `cd`'d into. It searched
  a path with no `bin/fw` in it and returned nothing, which read exactly like
  confirmation of the bug report. I had insisted on a positive control for T-2882 an hour
  earlier for precisely this shape, and did not apply it to myself.
- **Plan impact:** none to the deliverable, but it is why every assertion in
  `tests/unit/git_identity_check.bats` is paired. The two GROUND TRUTH legs run `git
  commit` in both environments before anything else, so no later reading can be a
  property of a fixture that could not have shown the opposite.
- **Triggered:** nothing filed. It is the same class as L-556 and the T-2881 fast-path
  contamination; the pattern is recorded twice already and the remedy is the discipline,
  not more tooling.

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

### 2026-08-09T07:41:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2883-obs-170-surface-missing-git-identity-bef.md
- **Context:** Initial task creation

### 2026-08-09T07:43:30Z — status-update [task-update-agent]
- **Change:** tags: +arc:readme-first-run
