---
id: T-2834
name: "safe-command fast path exits before the task and focus gates for A-and-B chains"
description: >
  safe-command fast path exits before the task and focus gates for A-and-B chains

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/lib/safe-commands.sh, 
      tests/unit/safe_commands_chain.bats]
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
created: 2026-08-06T17:57:06Z
last_update: '2026-08-16T22:25:19Z'
date_finished: 2026-08-06T18:15:18Z
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
  - ts: '2026-08-06T18:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T18:00:14Z'
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
  - ts: '2026-08-16T22:25:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2834: safe-command fast path exits before the task and focus gates for A-and-B chains

## Context

`is_bash_safe_command()` (agents/context/lib/safe-commands.sh:36) derives the
command base with `awk '{print $1}'` — the first word. The comment above it
states the assumption in its own words:

> Extract the base command (first word, strip path).
> **For compound commands, the first word is still the primary command.**

That is false for `A && B`, `A; B`, `A || B`. `check-active-task.sh:95` exits 0
on a "safe" verdict, so when the first word is allowlisted and the string carries
no write pattern, the hook returns **before** the no-active-task check, the
task-is-active check, the G-020 readiness gate, and the T-1730 focus-drift gate.
Everything after `&&` is unexamined.

Measured (`scratchpad/obs180/probe4.sh` + `probe6.sh`, sandbox PROJECT_ROOT):

| command | expected | actual |
|---|---|---|
| `git commit -m 'B: x'` (focus A) | BLOCK | BLOCK |
| `echo hi && git commit -m 'B: x'` (focus A) | BLOCK | **allow** |
| `bin/fw task update B --status work-completed` | BLOCK | BLOCK |
| `ls && bin/fw task update B --status work-completed` | BLOCK | **allow** |
| `echo hi && bash deploy.sh` (no active task) | BLOCK | **allow** |
| `ls && python3 mutate.py` (no active task) | BLOCK | **allow** |
| `echo hi > /tmp/x && git commit -m 'B: x'` | BLOCK | BLOCK (write pattern) |
| `echo hi && rm -rf <dir>` (no active task) | BLOCK | BLOCK (write pattern) |
| `true && …`, `pwd; …` | BLOCK | BLOCK (bases not allowlisted) |
| `cd /x && bin/fw doctor`, `ls && git status` | allow | allow (all segments safe) |

The script-execution rows are the sharp end. The allowlist admits `bash` only
with `-n` and `python3` only with `-c` and no write indicators (safe-commands.sh
:167-182) — the chain form defeats both conditions, and Tier 0 is documented as
matching the command string only, never the contents of a file it runs.

**Withdrawn claim, recorded not silently edited.** An earlier draft of this table
asserted `echo hi && rm -rf <dir>` was allowed with no active task. It is not.
That row came from a probe run whose sandbox still held an active anchor task
from the previous probe, so `allow` meant "a task was active", not "the gate was
bypassed". `has_bash_write_pattern` runs *before* the allowlist and greps the
whole string, so `rm` is caught in both forms. The near-miss is worth keeping:
it is exactly why this fast path reads as string-aware when it is only word-aware.

**Scope bound — this is a task-gate bypass, not a destructive-action bypass.**
Tier 0 is a separate hook that pattern-matches the whole command string;
`scratchpad/obs180/probe5.sh` confirms `echo hi && git push --force` and `echo hi
&& git reset --hard` are still blocked by `check-tier0.sh`. Claiming otherwise
would be an overclaim.

Related: L-433 (T-2054) already warns that allowlisting a command in
`is_bash_safe_command` short-circuits later gates — that learning was about
*which verbs* to add, and did not reach the base-extraction itself.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `is_bash_safe_command` returns non-safe for a chained command whose later
      segments are not themselves safe (`echo hi && git commit …`,
      `ls && fw task update …`), so the call reaches the gates below it
- [x] A chain whose segments are **all** safe stays safe — `ls && git status`,
      `cd /x && bin/fw doctor` must not start blocking (no false positives; this
      is the shape agents use constantly)
- [x] Bare safe commands are unaffected (`ls`, `git status`, `bin/fw doctor`)
- [x] The false-open rows in the Context table now block, verified by re-running
      the probe harness against the patched hook
- [x] Regression test pins both directions — chained-unsafe blocks, chained-safe
      allows — so the base-extraction assumption cannot silently return
- [x] `tests/unit` suites covering the hook and safe-commands stay green
- [x] Gap registered in `.context/concerns.yaml` before the fix lands

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

bash -n agents/context/lib/safe-commands.sh
out=$(bats tests/unit/safe_commands_chain.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/context_safe_commands.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/test_check_active_task_bootstrap.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/check_active_task_switch_focus.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The defect itself, asserted directly rather than only through the suite:
bash -c 'source agents/context/lib/safe-commands.sh; ! is_bash_safe_command "echo hi && git commit -m \"T-1: x\""'
bash -c 'source agents/context/lib/safe-commands.sh; ! is_bash_safe_command "ls && bash deploy.sh"'
# Over-blocking guard — the shape agents run constantly must still pass:
bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "cd /tmp && git status"'
# The corrected contract must stay documented at the base-extraction site.
# Asserted POSITIVELY on purpose: the first draft of this line was
# `! grep -q "the first word is still the primary command"`, which fails against
# the fixed file — the design comment QUOTES the old claim in order to refute it.
# A negative grep cannot tell an assertion from a citation of one, which is
# T-2833's defect wearing a different hat.
grep -q "Callers must pass a SINGLE command" agents/context/lib/safe-commands.sh

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

**Symptom:** a Bash command whose first word is on the safe-command allowlist
skipped every gate below the fast path, however unsafe the rest of the chain
was. `echo hi && git commit -m 'T-OTHER: x'` passed the focus-drift gate;
`ls && bin/fw task update T-OTHER --status work-completed` passed it too; with no
active task, `echo hi && bash deploy.sh` and `ls && python3 mutate.py` passed the
task gate outright, though the allowlist admits `bash` only with `-n` and
`python3` only with `-c`-and-no-write-indicators.

**Root cause:** `is_bash_safe_command` derived the command base with
`awk '{print $1}'` — the first word — and `check-active-task.sh:95` treats a safe
verdict as terminal. A chain has more than one command; the first word names only
the first of them.

**Why structurally allowed:** the assumption was *written down and wrong*, in the
function's own comment — "For compound commands, the first word is still the
primary command" (safe-commands.sh:34). It read as a considered decision rather
than an oversight, so nobody re-derived it. Two further things kept it invisible:

1. **A near-miss made the path look string-aware.** `has_bash_write_pattern` runs
   *first* and does scan the whole string, so the most obvious chain —
   `echo x > file` — is caught. Testing the shape that comes to mind first
   returns the right answer for the wrong reason.
2. **The failure is silent and shaped like success.** A gate that wrongly blocks
   gets reported immediately; a gate that wrongly allows produces a command that
   simply works. Nothing distinguishes "allowed because it was judged safe" from
   "allowed because the judgement never happened."

L-433 (T-2054) already warned that allowlisting a verb short-circuits later
gates — but as guidance about *which verbs to add*, so it was read every time the
`case` list grew and never once against the extraction feeding it.

**Prevention:** `tests/unit/safe_commands_chain.bats` (21 tests) pins both
directions — 9 go red against the pre-fix file (mutation-verified), and 12 guard
the over-blocking direction so a future "safer" rewrite cannot quietly break
`cd X && fw Y`. The wrong comment is replaced with one that states what callers
must pass and why. `_fw_single_command_is_safe` is now a named private function,
so "this classifies ONE command" is enforced by the signature rather than
remembered.

**Not fixed, filed:** command substitution (`echo $(bash deploy.sh)`) is the same
class and still passes — OBS-185 records the measurement and why the obvious fix
would break the framework's own `curl -sf "$(bin/fw watchtower url)/page"` idiom.

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

### 2026-08-06 — fix chain operators, leave command substitution open

- **Chose:** split on unquoted chain operators (`&&`, `||`, `&`, `|`, `;`,
  newline) and require every segment to be safe. Treat `$(…)` and backticks as
  ordinary text.
- **Why:** the two legs have opposite cost profiles. Chain operators are the
  measured, ubiquitous hole and closing them regresses nothing — verified, 12 of
  the 21 new tests exist solely to prove the all-safe shapes still pass. The
  substitution leg cannot be closed the same way: treating substitution contents
  as a segment blocks `curl -sf "$(bin/fw watchtower url)/page"` — the framework's
  own documented verification idiom — because `fw watchtower` is not on the
  allowlist. That denies service in the no-active-task state, which is exactly
  where the agent is trying to recover. Order matters: widen the allowlist first,
  then split substitutions. Measured in `scratchpad/obs180/probe7.sh`, filed as
  OBS-185, and cited by name in the code so the boundary is visible at the site.
- **Rejected:** closing both legs now (regresses everyday commands); shelling out
  to `python3`+`shlex` for real parsing (a third fork in a PreToolUse hook that
  runs on every Bash call, for a case bash handles); doing nothing pending a
  "proper" parser (leaves the ubiquitous leg open indefinitely).

### 2026-08-06 — quote-aware splitting rather than naive `tr`

- **Chose:** a character walk that tracks single/double quote state and escapes.
- **Why:** naive splitting cuts `grep -q "a && b"` into two bogus segments, and
  the second matches nothing on the allowlist — turning a read-only command into
  a blocked one. Three tests pin this.
- **Rejected:** splitting with `tr`/`sed` on the operators (fails the above);
  accepting the false positives as harmless (they land on the recovery path).

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

### 2026-08-06T17:57:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2834-safe-command-fast-path-exits-before-the-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-48adda12
- **Timestamp:** 2026-08-06T18:15:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#7 (Agent)** — Gap registered in `.context/concerns.yaml` before the fix lands
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/concerns.yaml in: Gap registered in `.context/concerns.yaml` before the fix lands`

### 2026-08-06T18:15:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
