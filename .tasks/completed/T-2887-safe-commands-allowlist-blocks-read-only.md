---
id: T-2887
name: "safe-commands allowlist blocks read-only commands at focus-null resumption
  (832 rail 489 class)"
description: >
  832 reported that their has_bash_write_pattern misclassifies quoted operators and
  2>/dev/null as file writes and runs BEFORE the allowlist, so allowlisted reads get
  blocked. Only changes an outcome when focus is null - i.e. at resumption. I hit
  a live instance at this session's resumption: a compound read-only command (git
  log/status/cat/ls/grep) was blocked while bare git log passed. Measure our equivalent
  before assuming their defect is ours.

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
created: 2026-08-09T10:29:20Z
last_update: '2026-08-09T10:30:12Z'
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
  - ts: '2026-08-09T10:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-09T10:30:12Z'
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
---

# T-2887: safe-commands allowlist blocks read-only commands at focus-null resumption (832 rail 489 class)

## Context

832 reported (rail 489) that their `has_bash_write_pattern` misclassifies quoted
operators and `2>/dev/null` as file writes, and runs BEFORE the allowlist, so an
allowlisted read gets blocked. Their fixes: `4d8a2e43`, `9611f7df` (refs only,
per OBS-108 — no bytes crossed the rail). L-518 says sweep our equivalent.

**Live witness, this session's resumption.** With focus null after the previous
session's close, this read-only command was BLOCKED:

```
git log ... && echo "..." && git rev-list --count origin/master..HEAD && git status --short | head -20 && cat .context/working/.budget-status 2>/dev/null && ls .tasks/active/ | grep -E '2885|2886'
```

while bare `git log --oneline -5` passed. So the safe-list is live and mostly
working; something in that chain classified unsafe.

**Do not assume 832's root cause is ours.** Reading `agents/context/lib/safe-commands.sh`
gives two *candidate* explanations, and the point of this task is to find out which
one actually fired before changing anything:

- **Candidate A — missing enumeration.** `git rev-list` is absent from the git
  read-only sub-verb list (`:142`), which has `rev-parse` but not `rev-list`.
- **Candidate B — divergent regex copies (832's reported shape).** `has_bash_write_pattern`
  (`:333`) uses `[^2>&]>[^>&]|>>`, which correctly exempts `2>` and `>&`. The
  `echo|printf` branch (`:302`) carries its own copy, `[^>]>[^>]|>>`, which never
  got those exemptions — so on that branch `2>/dev/null` and `2>&1` should read
  as file writes.

Two already-disproved guesses, recorded so they are not re-run: a bare
`cat FILE 2>/dev/null` passed (probe B), and quoted `|` inside `grep -E '2885|2886'`
did not split the chain (`_fw_chain_split` tracks quotes). The `2>/dev/null`
hypothesis I opened with was **wrong** — measured, not reasoned.

## Acceptance Criteria

### Agent
- [x] Each candidate is decided by running the predicate directly, one command
      shape per verdict — not by reading the regex and concluding
- [x] The command from the live witness is reproduced as a blocked classification,
      and the specific segment responsible is named
- [x] A positive control shows the probe can produce a "safe" verdict, so a
      "blocked" reading is not an artifact of how the predicate is being invoked
- [x] Every *disproved* candidate is written down as disproved, in this file,
      with the command that disproved it
- [x] Whichever candidate is confirmed is fixed at its root, and the fix is
      justified against the failure direction stated at `:82` (misjudging safe as
      unsafe merely gates; misjudging unsafe as safe skips every gate)
- [x] Teeth: a bats case per confirmed defect, asserting the exact command shape
      from the witness, plus the paired negative — a genuinely unsafe shape that
      must still gate. A fix that only widens is satisfiable by deleting the check
- [x] `tests/unit/safe_commands_chain.bats` stays green (the T-2834 chain suite)
- [x] Any candidate that turns out real but out of scope is filed as its own task
      (one bug = one task), not folded in here

## Measurement

`is_bash_safe_command` run directly over nine shapes, positive and negative
controls in the same batch so a "GATED" reading cannot be an artifact of how the
predicate was invoked:

| command | verdict |
|---|---|
| `git log --oneline -5` | SAFE (positive control) |
| `git status --short` | SAFE (positive control) |
| `echo hi` | SAFE (positive control) |
| `cat f 2>/dev/null` | SAFE |
| `git rev-list --count origin/master..HEAD` | **GATED** ← the live witness |
| `echo hi 2>&1` | **GATED** |
| `echo hi 2>/dev/null` | **GATED** |
| `git commit -m x` | GATED (negative control — must stay gated) |
| `cat f > out.txt` | SAFE (see disproved #3) |

The two redirect regexes, side by side, on the shapes that separate them:

```
echo hi 2>&1           echo-branch:MATCH  has_write:no
echo hi 2>/dev/null    echo-branch:MATCH  has_write:no
echo hi > f            echo-branch:MATCH  has_write:MATCH
echo hi >> f           echo-branch:MATCH  has_write:MATCH
```

They agree on real writes and disagree on exactly the fd forms.

### Disproved

1. **`2>/dev/null` blocks the chain** — my opening hypothesis, and it was wrong.
   Disproved by `cat .context/working/.budget-status 2>/dev/null`, which ran and
   returned output. I had reasoned my way to it from 832's report before testing.
   The measurement is what caught it, exactly as in T-2882.
2. **A quoted `|` splits the chain** — disproved by `ls .tasks/active/ | grep -E
   '2885|2886'`; `_fw_chain_split` tracks quotes (T-2834), and the T-2834 suite
   already pins it.
3. **`cat f > out.txt` is a live hole** — `is_bash_safe_command` alone says SAFE
   (the `cat` branch at `:179` returns 0 with no redirect test), which looks
   alarming in isolation. It is not reachable: `check-active-task.sh:173` runs
   `has_bash_write_pattern` over the whole command *before* consulting the
   allowlist, and that predicate matches ` > `. Compensated by ordering, not by
   the branch. Recorded because the standalone verdict is misleading to the next
   reader, and because the ordering is load-bearing rather than incidental.

### Split out, not fixed here

**`git rev-list` is missing from the git read-only sub-verb list** (`:142` has
`rev-parse`, not `rev-list`). This is the defect that produced the live witness,
and it is a *different root cause* — an incomplete enumeration, not a diverged
copy — so per "one bug = one task" it is filed as **T-2888** rather than folded
in here. It bites hardest at exactly the null-focus moment: this project's own
session-end rule is to verify `git rev-list --count origin/master..HEAD` is 0,
and `--status work-completed` nulls focus immediately before that check runs.

## RCA

**Symptom:** with focus null at session resumption, a read-only compound command
was blocked by the task gate. Separately, any `echo`/`printf` segment carrying
`2>&1` or `2>/dev/null` classifies as a file write and gates.

**Root cause:** two copies of the same redirect test. `has_bash_write_pattern`
(`:333`) uses `[^2>&]>[^>&]|>>`; the `echo|printf` branch of
`_fw_single_command_is_safe` (`:302`) carried its own `[^>]>[^>]|>>`. The `2` and
`&` exemptions — which are what distinguish a file write from a file-descriptor
redirect — were added to one and not the other. The copy was *correct when it was
written*; it became wrong when its sibling was fixed without it.

**Why structurally allowed:** nothing tied the two copies together. Each had its
own tests, and both suites passed throughout, because each asserted its own copy
in isolation and neither asserted that the two agree. This is L-399 (producer/
consumer contract parity) in its purest form and the same shape as T-2883's six
divergent git-identity probes — N copies of a predicate can disagree and nothing
makes them agree.

**Prevention:** the branch now delegates to `has_bash_write_pattern` — one
predicate, so divergence is not expressible. The test that carries the weight is
not the three symptom cases but
`"echo branch and write-pattern agree on every redirect shape"`, which fails if a
second private copy is ever reintroduced, *even if that copy is correct on the
day it lands*. Pinning the symptom would not have caught the original defect,
since the symptom did not exist when the copy was made.

## Verification

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

out=$(bats tests/unit/context_safe_commands.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/safe_commands_chain.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# the fd forms are safe again, and real redirects still gate
bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "echo hi 2>&1" && is_bash_safe_command "echo hi 2>/dev/null" && ! is_bash_safe_command "echo hi > f.txt"'
# no second private copy of the redirect regex survives on the echo branch
! grep -qE "\[\^>\]>\[\^>\]" agents/context/lib/safe-commands.sh
bash -n agents/context/lib/safe-commands.sh

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

### 2026-08-09T10:29:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2887-safe-commands-allowlist-blocks-read-only.md
- **Context:** Initial task creation
