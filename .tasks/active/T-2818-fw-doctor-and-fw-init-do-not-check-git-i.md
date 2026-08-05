---
id: T-2818
name: "fw doctor and fw init do not check git identity; first governed commit dies
  RC=128"
description: >
  OBS-170. On a genuinely fresh machine there is no global git user.name/user.email,
  so git commit fails RC=128 'Author identity unknown' BEFORE any framework hook runs.
  The seeded onboarding curriculum's T-003 is literally 'First governed commit', and
  the README five-minute path leads there, so a new operator's first instructed action
  fails on an error the framework neither produces nor explains. fw doctor has no
  git-identity check and fw init emits no warning. This is the last open blocker on
  arc-016's headline mechanic ('a person reaches a working first task without hitting
  a block they cannot clear') -- see T-2719 Recommendation. Measured 2026-08-05 under
  isolated HOME during T-2719 persona work. Fix shape: a fw doctor check (WARN, with
  the two git config commands as the remedy) plus a warning at fw init time when identity
  is unset.

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
created: 2026-08-05T21:45:18Z
last_update: 2026-08-05T22:03:55Z
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
bvp_scores_proposed:
  - ts: '2026-08-05T21:46:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-05T22:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2818: fw doctor and fw init do not check git identity; first governed commit dies RC=128

## Context

**The filed premise was wrong, and correcting it is most of this task.**

T-2818 was filed (by me, from T-2719's Recommendation) as: *"fw doctor has no
git-identity check and fw init emits no warning. Fix shape: a fw doctor check plus
a warning at fw init time."* Both already existed before this task opened:

| Claimed missing | Actually present since |
|---|---|
| `fw doctor` git-identity WARN | `bin/fw:1249-1256`, T-685 (commit `d678d6747`) |
| `fw init` identity warning | `lib/init.sh:146-158`, T-880/F4 |

So the recommended fix was a no-op. The condition was warned about **three times**
— and the operator still hit it. That is the actual defect, and it is a different
one: **not a missing warning, but every summary line contradicting the warning.**

Measured on a fresh init with no resolvable identity (`/tmp/idA`, isolated
`HOME` + `GIT_CONFIG_GLOBAL`):

| Surface | What it said |
|---|---|
| init warning | fires — **line 4 of 120**, then 116 lines of green ✓ |
| init validation (44 checks) | **no identity check existed** → `Validation passed: 43/44` |
| init closing line | `Done! Governance is active.` |
| init next step | `Next step: Start your AI agent` |
| `fw doctor` | warns, but scoped `[host]` → project verdict `0 failure(s)` |

The last thing read wins, and the last thing read said ready. Onboarding task
T-003 is *"First governed commit"*; `git commit` dies `RC=128 Author identity
unknown` before any framework hook runs, so the curriculum's third step is
impossible on a project that just reported itself healthy.

**This is not hypothetical on a "fresh machine" — it is this host.**
`git config --global user.email` → rc=1. The framework repo works only because it
carries a *repo-local* identity (`dimitirgeelen@hotmail.com`). Every project
`fw init` has created here inherits the failure. That is why the by-hand persona
run hit it and every agent-assisted run did not: agents work inside the framework
repo, which has the local identity.

Fix: put the blocker where the eye lands (end of output) and give the tally an
opinion. Not a fourth warning at the top.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The filed premise is corrected in writing, with the pre-existing check
      locations cited (`bin/fw:1249`, `lib/init.sh:146`), rather than a redundant
      fourth warning being added on top of three that already fire.
- [x] `fw init`'s **closing** block states the blocker when identity is
      unresolvable — proven in BOTH states by two real inits under isolated
      `HOME`/`GIT_CONFIG_GLOBAL` (L-530), not by reading code.
- [x] The emitted remedy carries its own `cd` (T-609) and, **run verbatim as
      extracted from the init log**, takes the project from `RC=128` to a
      successful governed commit through the commit-msg hook.
- [x] `fw init`'s validation tally counts `func-identity` in both states,
      warn-shaped (counted as passed, `sem-fabric` precedent) — host state must not
      redden CI runs that legitimately have no identity.
- [x] A bats test pins both states and is executed by a real runner
      (`bats tests/unit/` directory glob, `bin/fw:7812`), `bats --count` = 7.
- [x] Mutation-checked: with both legs reverted, **5 of 7 go red**; the 2 survivors
      are exactly the negative controls (identity-present shows no blocker;
      validation still passes). Mutation confirmed present before the result was
      believed, and removed after.

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

bash -n lib/init.sh
bash -n lib/validate-init.sh
# Both-states suite. Guarded form (T-2738): the capture discards the runner's exit
# code, so the absence of 'not ok' is the second half of the verdict.
out=$(bats tests/unit/init_git_identity_blocker.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# T-2726's auditability pin, widened here to accept the '!' warn marker.
out=$(bats tests/unit/validate_init_check_type_join.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The suite must be reachable by the runner that actually runs in CI, not only by
# a hand-typed path (T-2696: tests/lint/ was globbed by no runner for 51 days).
bats --count tests/unit/ >/dev/null && bats --count tests/unit/init_git_identity_blocker.bats | grep -q '^7$'

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

**Symptom:** On the by-hand onboarding path, `git commit` — onboarding task T-003,
*"First governed commit"* — dies `RC=128 Author identity unknown` before any
framework hook runs, on a project `fw init` had just declared ready.

**Root cause:** Not a missing warning. Three warnings already fired
(`lib/init.sh:146`, `bin/fw:1249`, plus doctor's remedy line). The defect is that
**every surface that summarises contradicted them**: the validation tally had no
identity check at all (`Validation passed: 43/44`), the closing line said
`Done! Governance is active.`, the next-step line said start your agent, and
doctor's `[host]` scoping kept it out of the project verdict (`0 failure(s)`).
A warning at line 4 of 120 followed by 116 lines of green is not a warning the
operator receives.

**Why structurally allowed:** two independent reasons, both about *denominators*
rather than checks.
1. `validate-init`'s 44 checks are all about **files init writes**. Nothing in the
   set is about whether the project can perform its own first curriculum step, so
   the tally could be honest and complete and still say "ready" about a project
   that cannot commit — the same shape as T-2727's vendor case (43 green checks,
   none about the 90MB of framework they depended on).
2. The condition is **host state**, and doctor's host/project split — correct on
   its own terms — routes it out of the verdict a project-scoped reader consults.
   Host state that blocks a project action has no home in either verdict.

**Why it survived every agent-assisted run:** agents work inside the framework
repo, which carries a repo-local identity. The host has **no global identity at
all** (`git config --global user.email` → rc=1). Only the by-hand persona, in a
freshly-init'd directory, ever resolves identity the way a consumer does. This is
the arc-016 thesis holding: the personas fail differently, and the agent-assisted
path structurally cannot observe this one.

**Prevention (distinct from the fix):**
- `tests/unit/init_git_identity_blocker.bats` — 7 assertions, both states, run by
  the `bats tests/unit/` directory glob. One asserts the *end* of the output, which
  is the surface that regressed; one runs the emitted command verbatim and commits,
  so the message is pinned as **correct**, not merely present.
- `func-identity` gives the tally an opinion, so the denominator can no longer say
  44/44 about a project that cannot commit.
- T-2726's auditability pin was widened to accept the `!` warn marker — it had a
  latent hole (`sem-fabric`'s warn path never fires on a fresh init, so the omission
  was invisible until a warn row actually appeared).

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

### 2026-08-06 — how hard the validation check should fail

- **Chose:** warn-shaped row, counted as **passed**, following the `sem-fabric`
  precedent already in the file.
- **Why:** this is host state, not project state — `git config user.email` flips it
  green with no re-init, and `fw doctor` scopes the same condition `[host]` for the
  same reason. The tally still gains an opinion, which is the point.
- **Rejected:** counting it as `failed`. It would flip `do_validate_init`'s return
  on every CI job that legitimately runs without an identity (the fresh-machine
  simulation runs under `env -i`), producing a permanent red that teaches people to
  ignore validation output — which is precisely the failure mode this task exists
  to fix. Trading one ignored signal for another is not a fix.

### 2026-08-06 — widening a test's regex rather than changing the row marker

- **Chose:** widen T-2726's row pattern from `^  [✓✗-]` to `^  [✓✗!-]`.
- **Why:** that test's claim is that the summary's denominator is *witnessable line
  by line*. A `!` row is as witnessable as a `✓`. The marker was already in use by
  `sem-fabric`, on a path a fresh init never takes (component count is 0, so it
  always printed `✓`) — so the gap was latent, not absent, and `func-identity` is
  simply the first check whose warn row fires on a fresh init.
- **Rejected:** changing `func-identity` to print `✓`/`-` so the existing regex
  matched. That would make a visible line count as invisible in order to satisfy an
  assertion — inverting the test's intent to get green, which is the move this
  session has already been burned by three times.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-05T21:45:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2818-fw-doctor-and-fw-init-do-not-check-git-i.md
- **Context:** Initial task creation

### 2026-08-05T21:46:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
