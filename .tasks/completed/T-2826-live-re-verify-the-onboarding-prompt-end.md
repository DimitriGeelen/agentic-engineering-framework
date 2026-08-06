---
id: T-2826
name: "live re-verify the onboarding prompt end-to-end after T-2818 + T-2821"
description: >
  live re-verify the onboarding prompt end-to-end after T-2818 + T-2821

status: work-completed
workflow_type: test
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
created: 2026-08-06T13:14:08Z
last_update: 2026-08-06T13:19:56Z
date_finished: 2026-08-06T13:19:56Z
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
  - ts: '2026-08-06T13:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 1
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=1 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T13:15:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2826: live re-verify the onboarding prompt end-to-end after T-2818 + T-2821

## Context

The operator asked directly: *"CAN WE NOW REALIABLY RUN THE ONBOARDING PROMPT?"*

The last full live answer was T-2819/T-2820, which **predates two landed fixes**:
- **T-2818** — `fw init` leaked the tokenised origin URL into every project's tracked
  `.framework.yaml`; the identity blocker is now stated in init's closing block.
- **T-2821** — `fw init` now leaves a **resolvable HEAD** via an empty `T-000` bootstrap
  commit. Its real target is background-agent isolation: `git worktree add` on an unborn
  HEAD returns **RC=0** and silently yields an *empty* worktree (OBS-175) — a git-level
  false-green, so the deadlock was emptiness, not refusal.

So the prior answer is stale in the direction that matters. This task re-runs the prompt
against **published bytes** (public GitHub mirror, not the working tree) so the measurement
is of what a consumer actually receives.

Scope fence: this measures the *by-hand consumer path* + the worktree-isolation
precondition. It does NOT re-open OBS-172 / OBS-173 (both filed, both non-blocking), and
it does NOT measure bare-`fw` PATH resolution — that is unmeasurable on this host
(`fw` exists in both `/usr/local/bin` and `/usr/bin`; T-2796 wrong-object class).

## Acceptance Criteria

### Agent
- [x] Published mirror is at or ahead of the local commit carrying T-2818 + T-2821, so the
      run measures bytes a consumer can actually clone (not the local working tree).
      → **GREEN.** Mirror `master` = `7b143ad5e` = local HEAD exactly; `lib/init.sh` in the
      *clone* carries the bootstrap block (`LEG0_HAS_BOOTSTRAP=1`).
- [x] A fresh `fw init` in an empty directory exits 0 and leaves a **resolvable HEAD**
      (`git rev-parse HEAD` succeeds) — the T-2821 fix, measured live rather than by unit test.
      → **GREEN.** `LEG1_INIT_RC=0`, `LEG2_HEAD_RC=0`, HEAD subject = `T-000: fw init bootstrap
      commit (empty — gives the project a resolvable HEAD)`.
- [x] The worktree-isolation precondition is **measured** end-to-end (not inferred from
      T-2821's unit tests), and the result is recorded whichever way it lands.
      → **MEASURED RED — see F3 + OBS-178.** `git worktree add` returns RC=0 with a resolvable
      HEAD *inside* the worktree, but the worktree holds **1 entry (`.git`) and no `CLAUDE.md`**.
      T-2821 moved the deadlock; it did not remove it. Escalated to OBS-178 + **T-2827**.
- [x] The initialised project's tracked `.framework.yaml` contains **no credential**
      (no `oauth2:`/`x-access-token:`/`@` userinfo in any URL) — T-2818 regression check.
      → **GREEN.** `LEG4_CRED_HITS=0`.
- [x] `fw work-on` in the fresh project creates a first task and exits 0, and the resulting
      first commit passes the project's own commit-msg hook **without `--no-verify`**.
      → **GREEN.** `LEG5_WORKON_RC=0` (T-006 created atop the 5 seeded onboarding tasks);
      `LEG6_COMMIT_RC=0` with no `--no-verify`. Negative control `LEG7_NEG_RC=1` —
      *"ERROR: No task reference found in commit message"* — so the gate genuinely fires
      rather than merely being installed.
- [x] Findings recorded in the task body with an explicit verdict per prompt-shape, and any
      newly-observed defect filed to the inbox rather than left in prose.
      → **GREEN.** F1–F4 below; OBS-178 filed; T-2827 filed for the fix.

## Findings

**F1 — the by-hand consumer path is green on published bytes.** Every leg of STEP 3 →
STEP 6 passed under `env -i`, minimal PATH, no git identity, cloning from the public
mirror. Init 0, HEAD resolvable, work-on 0, governed commit 0, and the commit-msg gate
refuses an untagged message. This is the path the operator actually walks.

**F2 — T-2818 holds.** Zero credential matches in the initialised project's tracked
`.framework.yaml`. The leak class that reached every project is closed on the bytes a
consumer receives, not just in the working tree.

**F3 — T-2821 moved the empty-worktree deadlock rather than removing it.** The bootstrap
commit is `--allow-empty`, so its **tree contains zero files**. `git worktree add` at that
HEAD checks out an empty tree and produces a worktree holding only `.git`. The
user-visible failure is *identical* to OBS-175 — a background agent isolates into an empty
worktree — but the mechanism changed from orphan-inference to empty-tree checkout.

The window is bounded and I measured both ends: at bootstrap HEAD the worktree is empty
(1 entry); after the project's first **content** commit a fresh worktree populates
correctly (10 entries, `CLAUDE.md` and `.tasks/` present). So exposure runs from `fw init`
to first content commit — and `fw init` leaves 11 entries **uncommitted**, so nothing
closes that window on its own. That window is precisely the onboarding window in which a
fresh consumer would plausibly dispatch a background agent.

**F4 — why T-2821's tests are green on a state that still fails.** They assert HEAD
*resolvability*, which is exactly what the fix delivers. The property the real use needs is
HEAD **has content**. Resolvability was a proxy for it, and the proxy diverged from the
thing — the T-1828 / T-2735 class. The test suite is not wrong; it is measuring one axis of
a two-axis precondition (sibling to T-2778's *"bounded is per-axis"*).

## Scope note — what this run does NOT claim

- **OBS-172** (`fw serve` on a port-contended host) and **OBS-173** (secret scanning
  silently disabled when initialising inside an existing repo) were not re-tested. Both
  remain filed and non-blocking.
- **Bare-`fw` PATH resolution is unmeasurable on this host** — `fw` exists in both
  `/usr/local/bin` and `/usr/bin`, so any number produced here would be about the wrong
  object (T-2796 class). Needs a container or clean host.

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

# The live run itself is in the session record (LEG0-LEG7). These lines pin the
# durable artefacts that run produced, so the finding survives the session.

# The T-2821 bootstrap block is present in the shipped init path
grep -q 'fw init bootstrap commit' lib/init.sh

# The bootstrap commit is still --allow-empty (i.e. F3/OBS-178 is still live and
# this task's finding has not been silently invalidated). Flip to a NEGATED grep
# once T-2827 lands, so this line becomes the regression guard.
grep -q 'commit --allow-empty' lib/init.sh

# The finding was escalated to the inbox, not left as prose
out=$(bin/fw note list 2>&1); echo "$out" | grep -q "OBS-178"

# The fix task exists
ls .tasks/active/T-2827-*.md >/dev/null 2>&1 || ls .tasks/completed/T-2827-*.md >/dev/null 2>&1

# This task records a per-leg verdict rather than a bare pass/fail
grep -q 'MEASURED RED' .tasks/active/T-2826-live-re-verify-the-onboarding-prompt-end.md || grep -q 'MEASURED RED' .tasks/completed/T-2826-live-re-verify-the-onboarding-prompt-end.md

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

### 2026-08-06T13:14:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2826-live-re-verify-the-onboarding-prompt-end.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8ac05a09
- **Timestamp:** 2026-08-06T13:19:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 16
     - evidence: `ls .tasks/active/T-2827-*.md >/dev/null 2>&1 || ls .tasks/completed/T-2827-*.md >/dev/null 2>&1`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 19
     - evidence: `grep -q 'MEASURED RED' .tasks/active/T-2826-live-re-verify-the-onboarding-prompt-end.md || grep -q 'MEASURED RED' .tasks/completed/T-2826-live-re-verify-the-onboarding-prompt-end.md`

### 2026-08-06T13:19:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
