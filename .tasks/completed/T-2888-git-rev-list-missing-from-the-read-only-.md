---
id: T-2888
name: "git rev-list missing from the read-only safe-list, so the session-end unpushed
  check gates at null focus"
description: >
  agents/context/lib/safe-commands.sh:142 enumerates git read-only sub-verbs and has
  rev-parse but not rev-list. Measured: is_bash_safe_command 'git rev-list --count
  origin/master..HEAD' returns GATED while 'git log --oneline -5' returns SAFE. This
  is the command the project's own session-end protocol prescribes for verifying zero
  unpushed commits, and --status work-completed nulls focus immediately before that
  check runs, so the gate fires at exactly the moment the rule it blocks is meant
  to apply. Split out of T-2887 (different root cause: incomplete enumeration, not
  a diverged copy). Sweep the whole enumeration for other read-only verbs with the
  same property rather than adding one word.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/lib/safe-commands.sh, tests/unit/context_safe_commands.bats]
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
created: 2026-08-09T10:34:47Z
last_update: 2026-08-09T10:41:36Z
date_finished: 2026-08-09T10:41:36Z
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
  - ts: '2026-08-09T10:36:05Z'
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

# T-2888: git rev-list missing from the read-only safe-list, so the session-end unpushed check gates at null focus

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Context

Split out of T-2887, which confirmed it by measurement but fixed a different
defect (a diverged regex copy). This one is an incomplete enumeration:
`agents/context/lib/safe-commands.sh:142` lists git's read-only sub-verbs and has
`rev-parse` but not `rev-list`.

Measured: `is_bash_safe_command "git rev-list --count origin/master..HEAD"` →
GATED, while `git log --oneline -5` → SAFE.

Why it matters more than a missing word: this project's session-end rule is to
verify `git rev-list --count origin/master..HEAD` is 0 before ending a session,
and `fw task update --status work-completed` nulls focus immediately before that
check runs. The gate therefore fires at exactly the moment the rule it blocks is
supposed to apply — the same null-focus deadlock shape that T-2052 (`task
create`), T-2054 (`commit`/`add`), T-2462 (`push`/`fetch`) and T-2878 (`context
add-*`, `note`, `handover`) each fixed one verb at a time.

That repetition is the actual finding. Five tasks have now patched this list
reactively, each after an agent hit the deadlock live. Adding `rev-list` and
stopping would be the sixth.

## Acceptance Criteria

### Agent
- [x] The enumeration is swept against a *derived* list, not a remembered one:
      every `git <sub-verb>` appearing in this repo's own scripts, hooks, docs
      and CLAUDE.md is extracted mechanically and classified read-only vs
      mutating, and each read-only verb is tested against the predicate
- [x] The sweep's output is recorded in this file as a table — verb, read-only?,
      current verdict — so the next reader can see what was considered and not
      just what was changed
- [x] Every read-only verb the sweep finds GATED is fixed in one edit, not one
      per future incident
- [x] Mutating verbs stay GATED, asserted explicitly: at minimum `commit`,
      `pull`, `merge`, `rebase`, `reset`, `checkout`, `clean`. A fix that widens
      the list is otherwise satisfiable by allowing everything
- [x] `git pull` in particular is still GATED, with the T-2462 rationale intact
      (it merges into the working tree, so it is a write)
- [x] Teeth: bats cases for the newly-allowed verbs AND the paired mutating
      negatives, in `tests/unit/context_safe_commands.bats`
- [x] The reactive-patching pattern is addressed rather than repeated — either a
      test that fails when a read-only verb used by our own tooling is absent
      from the list, or a written argument in the source for why one-at-a-time is
      the right policy here. Whichever is chosen, the reasoning is recorded
- [x] Existing suites stay green: `context_safe_commands.bats`,
      `safe_commands_chain.bats`

## Sweep

Extraction: every `git <sub-verb>` in `*.sh` / `*.py` / `*.bats` under
PROJECT_ROOT, intersected with `git --list-cmds=main` (163 real commands) to drop
prose matches — the first, looser extraction returned `history`, `hooks`, `repo`,
`identity` and `commits`, none of which are git commands.

Verbs our own tooling uses, by verdict *before* the fix:

| verdict | verbs |
|---|---|
| read-only, already SAFE | `log` `status` `diff` `show` `branch` `remote` `describe` `rev-parse` `tag` `stash` `shortlog` `blame` `ls-files` `ls-tree` `cat-file` `name-rev` `reflog` `add` `push` `fetch` |
| **read-only, GATED — fixed here** | `rev-list` `ls-remote` `merge-base` `grep` `for-each-ref` `count-objects` `check-ignore` `verify-commit` `var` `whatchanged` `cherry` `diff-tree` `show-ref` `help` |
| mutating, correctly GATED | `commit` `pull` `merge` `rebase` `reset` `checkout` `clean` `mv` `rm` `worktree` `config` `init` `clone` `read-tree` `hook` |

Usage counts for the four highest-traffic gaps: `rev-list` 108, `ls-remote` 76,
`merge-base` 69, `grep` 32.

**Not added, deliberately:** `symbolic-ref`, for the same reason `config` is not
in the list. `git symbolic-ref HEAD` reads; `git symbolic-ref HEAD refs/heads/x`
writes. A verb whose read and write forms differ only by an argument cannot be
decided on the verb alone, and this function only sees the verb.

### The last four verbs came from the test, not from me

`cherry`, `diff-tree`, `show-ref` and `help` are in the fixed row above because
the anti-recurrence test failed on its first run and named them. I had swept by
eye and missed all four. That failure is also the positive control for the test —
it is not asserted-green-by-construction; it produced a true positive before it
produced a pass.

It also named `worktree`, which was already in its own denylist two lines up: the
denylist spans several source lines and the membership check is a `" $verb "`
substring match, so a verb sitting at a line break never matched. Fixed by
collapsing the whitespace, and noted in the test.

## Out of scope, filed separately

The sweep surfaced a defect pointing the **other way**: `git stash` classifies
SAFE, and bare `git stash` writes — it stashes the working tree. `branch` and
`tag` are the same shape (`git branch -d`, `git tag -d` delete). All three are
pre-existing and none were introduced here, but they are over-permission where
this task is about under-permission, so the failure direction is the dangerous
one (`:82` — misjudging unsafe as safe skips every gate there is, where the
converse merely gates). Different root cause, different risk direction, own task:
**T-2889**.

## RCA

**Symptom:** `git rev-list --count origin/master..HEAD` — the command this
project's own session-end rule prescribes for verifying zero unpushed commits —
was blocked by the task gate at null focus, which is the exact state
`--status work-completed` leaves behind.

**Root cause:** the read-only sub-verb enumeration was incomplete. Fourteen
read-only verbs used by our own tooling were absent.

**Why structurally allowed:** the list was maintained reactively. T-2052 added
`task create`, T-2054 added `commit`/`add`, T-2462 added `push`/`fetch`, T-2878
added the `context` capture verbs and `note`/`handover` — each after an agent hit
the deadlock live, each fixing the one verb that had just bitten. Nothing ever
compared the list against the verbs the project actually uses, so the list could
only ever be as complete as the last incident. This task was the fifth instance
of that pattern and adding `rev-list` alone would have been the fifth repetition.

**Prevention:** `"no unclassified git verb is used by our own tooling"` derives
the verb set from our own source at test time and fails on any verb that is
neither allowed nor explicitly denied. It does not pin today's answer — it
demands a decision on tomorrow's verb, and accepts "this one mutates" as an
equally valid way to go green. The four verbs I missed by eye are the evidence
that a hand-maintained list and a hand-done sweep fail the same way.

## Verification

out=$(bats tests/unit/context_safe_commands.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/safe_commands_chain.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# the witness command is safe again, and the mutating verbs it sits next to are not
bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "git rev-list --count origin/master..HEAD" && is_bash_safe_command "git merge-base HEAD origin/master" && ! is_bash_safe_command "git pull" && ! is_bash_safe_command "git symbolic-ref HEAD refs/heads/x"'
bash -n agents/context/lib/safe-commands.sh

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

### 2026-08-09T10:34:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2888-git-rev-list-missing-from-the-read-only-.md
- **Context:** Initial task creation

### 2026-08-09T10:36:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c615f0d9
- **Timestamp:** 2026-08-09T10:41:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 35
     - evidence: ``bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.`

### 2026-08-09T10:41:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
