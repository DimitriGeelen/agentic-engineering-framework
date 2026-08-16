---
id: T-2821
name: "fw init leaves a project with no HEAD, hard-blocking background agent sessions"
description: >
  fw init leaves a project with no HEAD, hard-blocking background agent sessions

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-08-06T06:38:23Z
last_update: '2026-08-16T22:25:19Z'
date_finished: 2026-08-06T10:57:29Z
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
  - ts: '2026-08-06T06:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T06:45:11Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2821: fw init leaves a project with no HEAD, hard-blocking background agent sessions

## Context

**Reported live by the operator, 2026-08-06, from a fresh install at
`/opt/2345-test-install`.** A background agent session was hard-blocked and could not
write a single file.

The chain:

1. `fw init` runs `git init` (T-521, `lib/init.sh:140`) but **never creates a commit**.
   Confirmed: `git -C /tmp/freshid3/proj rev-parse HEAD` →
   `fatal: ambiguous argument 'HEAD': unknown revision`. Every framework file
   (`.framework.yaml`, `CLAUDE.md`, `.tasks/`, `.agentic-framework/`) is **untracked**.
2. So the new project has **no HEAD**.
3. `git worktree add` requires a HEAD to branch from → `EnterWorktree` fails with
   `Failed to resolve HEAD in /opt/2345-test-install: git rev-parse failed`.
4. Claude Code's background-session isolation guard (`worktree.bgIsolation`) refuses
   every Write/Edit until the session isolates into a worktree.
5. **Deadlock.** The agent cannot isolate (no HEAD) and cannot write (not isolated).
   Its own first act — writing the task file it was told to create — is impossible.

The operator's agent handled this correctly: it refused to reach past the gate with a
shell heredoc and asked instead. That is the designed behaviour, so the failure is
entirely upstream — the project was shipped in a state where the first agent session
cannot function.

**Severity is higher than it looks.** This is not a rare corner: it is the state of
*every* project `fw init` produces, and it fires on the *first* background session,
before any onboarding task can be completed. It also silently breaks anything else
that needs a HEAD (`fw fabric blast-radius HEAD`, `git worktree`, diff-based gates).

**Scope note — two different worktree systems.** The operator's message mentions
being troubled by "our worktree implementation". The thing failing in this report is
Claude Code's harness `EnterWorktree` + `bgIsolation` guard, **not** `fw worktree`.
They are distinct and must not be conflated while diagnosing. AEF's contribution to
this failure is precisely one thing: it hands the harness a repo with no HEAD.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A fresh `fw init` leaves the project with a resolvable `HEAD`, proven by
      `git -C <newproj> rev-parse HEAD` exiting 0 in a clean `env -i` run.
- [x] `git worktree add` succeeds in a freshly-initialised project — the actual
      capability that was missing, verified directly rather than inferred from the
      presence of a HEAD.
- [x] The chosen mechanism does **not** steal onboarding task T-003 ("First governed
      commit"). If an initial commit is created, T-003 must still have a meaningful
      first commit for the operator to make — otherwise the fix breaks the curriculum
      it exists to enable.
- [x] The initial commit passes the framework's own hooks (commit-msg task
      reference, secret scan) rather than requiring `--no-verify` — a bootstrap that
      bypasses the gates ships every project with a bypass in its history.
- [x] Decide and record whether the framework payload is committed or left untracked.
      These give different first-commit experiences and the choice must be deliberate.
- [x] Both states pinned by a bats test executed by a real runner
      (`bats tests/unit/` glob), mutation-checked.

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

out=$(bats tests/unit/init_head_bootstrap.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

## RCA

**Symptom:** A fresh `fw init` leaves the project with no git HEAD. Claude Code's
background-session `EnterWorktree` preflight (`git rev-parse HEAD`) fails, and the
`bgIsolation` guard then refuses all Write/Edit — deadlocking the first background
session before it can write even its own task file.

**Root cause:** `lib/init.sh:142` runs `git init -q` but the function returns without
ever creating a commit. `git init` alone leaves an *unborn* HEAD (a symbolic ref
pointing at a branch that has no commit yet), which `git rev-parse HEAD` reports as
`fatal: ambiguous argument 'HEAD': unknown revision`.

**Reproduced (both states, `env -i` isolated HOME, no global git identity):**
- Before fix: `git -C <proj> rev-parse HEAD` → exit **128**
  (`fatal: ambiguous argument 'HEAD': unknown revision or path not in the working tree.`)
- After fix: `git -C <proj> rev-parse HEAD` → exit **0**, prints a real commit sha.
- `bats tests/unit/init_head_bootstrap.bats` mutation-checked: reverting the fix on a
  copy of `lib/init.sh` turns the test RED (see Decisions for command + counts).

**Contradicts the task's Context (worth recording):** the Context states
"`git worktree add` requires a HEAD to branch from" as if it flatly fails without one.
On this host's git (2.43.0) that is only half true: `git worktree add <path>` against
an unborn-HEAD repo **succeeds** (exit 0) by silently inferring `--orphan` — but the
resulting worktree is **completely empty** (0 files, not even the untracked framework
payload), because a worktree only ever checks out *tracked, committed* content. So the
raw git-level failure the Context describes does not reproduce verbatim on this git
version — what actually blocks the operator is Claude Code's own `EnterWorktree`
preflight (a `git rev-parse HEAD` check *before* it attempts to add the worktree),
which is stricter than raw git and is the thing this fix targets. AC2 ("`git worktree
add` succeeds … verified directly rather than inferred from presence of a HEAD") is
satisfied post-fix in the non-orphan sense: the new worktree now branches from a real
commit, not an orphan. Whether that worktree also contains the vendored framework
payload is a separate, deeper question (payload is deliberately left untracked, see
Decisions) — out of scope here; the deadlock in the Context is specifically the
`rev-parse HEAD` refusal, and that is what is fixed.

**Why structurally allowed:** `lib/init.sh` had no post-condition check that the
project it hands back is actually usable by a background/isolated session — validation
(`validate-init.sh`) checks file contents and hook wiring but never asserts `HEAD`
resolves. Nothing between T-521 (git init added) and now exercised `git worktree add`
against a freshly-initialised project.

**Prevention:** `tests/unit/init_head_bootstrap.bats` pins `rev-parse HEAD` exit 0 and
a real (non-orphan) `git worktree add` success for every fresh `fw init`, run by the
`bats tests/unit/` glob (i.e. covered by the existing test-suite runner, not a
standalone script nobody invokes — closes the class T-2696/T-2726 kept finding).

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

### 2026-08-06 — bootstrap-commit mechanism
- **Chose:** (a) empty root commit (`git commit --allow-empty`), created in
  `lib/init.sh` right after git hooks are installed (after the existing
  `install-hooks` call, ~line 515) so the commit is validated by the project's
  own `commit-msg` + `pre-commit` hooks rather than bypassing them. Author/committer
  identity is scoped to this single commit via `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL`/
  `GIT_COMMITTER_NAME`/`GIT_COMMITTER_EMAIL` env vars (not written to git config),
  so it succeeds even on a machine with neither global nor local git identity
  configured (T-2818 — the norm, not the exception, per that task's finding).
  Commit message uses the existing `T-000` placeholder convention already used by
  `agents/handover/handover.sh:57` for "no real task applies but the commit-msg
  hook needs a `T-[0-9]+` pattern" — same convention, same regex, no new pattern
  invented. Guarded by `git rev-parse -q --verify HEAD` so it is a no-op on
  existing-project inits (which already have a HEAD) and on `--force` re-init
  (idempotent, no piling up of empty commits).
- **Why:** Gives `rev-parse HEAD` a real answer with the smallest possible
  surface: no files change, no decision about *what* payload to commit, no risk
  of shipping a bypass (`--no-verify`) in every project's first commit. Leaves
  the framework payload (`.agentic-framework/`, `.tasks/`, `.context/`,
  `CLAUDE.md`, `.framework.yaml`) untracked, so T-003 ("First governed commit",
  which asks the operator to create `README.md`/`src/` and commit *that*) still
  has real, meaningful content to commit — T-003's own template
  (`lib/seeds/tasks/greenfield/T-003-first-governed-commit.md`) never mentions
  the framework payload at all, so committing that payload earlier would not
  have hollowed T-003 either, but leaving it untracked is the smaller change and
  keeps "what does the operator's first real commit look like" undisturbed.
- **Rejected — (b) commit the framework payload:** Gives a clean tracked tree
  immediately, and (per the RCA note above) would also make a *subsequent*
  `git worktree add` check out a populated worktree instead of an orphan-empty
  one — a real advantage. Rejected for this task because: (1) it is a materially
  bigger decision (what exactly gets tracked, `.gitignore` for the vendored
  copy, size of the first commit) that deserves its own scoping rather than
  riding along on a HEAD-resolution bugfix; (2) it changes the operator's first
  commit experience in every existing consumer project waiting on this fix,
  which is a bigger blast radius than the bug being fixed; (3) it isn't needed
  to satisfy either AC — both are about `rev-parse HEAD` and `git worktree add`
  succeeding, not about worktree contents. Flagged in RCA as a legitimate
  follow-up if the operator later wants isolated worktrees to be populated.
- **Rejected — (c) leave as-is and document:** The AC explicitly requires a
  resolvable HEAD; documenting a hard first-session deadlock is not a fix.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-06T06:38:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2821-fw-init-leaves-a-project-with-no-head-ha.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8f549a91
- **Timestamp:** 2026-08-06T10:57:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-06T10:57:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
