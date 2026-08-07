---
id: T-2852
name: "install-hooks compares the git agent's version to the commit-msg hook's marker — two unrelated numbers"
description: >
  install-hooks compares the git agent's version to the commit-msg hook's marker — two unrelated numbers

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/git/git.sh, agents/git/lib/hooks.sh, tests/unit/hook_version_marker_parity.bats]
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
created: 2026-08-07T06:18:49Z
last_update: 2026-08-07T06:24:25Z
date_finished: 2026-08-07T06:24:25Z
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
---

# T-2852: install-hooks compares the git agent's version to the commit-msg hook's marker — two unrelated numbers

## Context

A fresh-install run on `/opt/001-test-install` (2026-08-07) reported
`Updating hooks from version 1.11 to 1.6` and read it as a version *downgrade*,
diagnosing it as "a lexical string comparison treating 1.11 < 1.6".

**That diagnosis is wrong** — `agents/git/lib/hooks.sh:55` is a string *equality*
(`[ "$existing_version" = "$VERSION" ]`), never an ordering. There is no `<`
anywhere. But the report was pointing at something real.

The two operands are unrelated quantities:

| Operand | Value | What it actually is |
|---------|-------|---------------------|
| `existing_version` | `1.11` | the `# VERSION=` marker grepped out of the **installed commit-msg hook** |
| `$VERSION` | `1.6` | `agents/git/git.sh:19` — the **git agent's own** version |

`agents/git/git.sh:15-18` states the invariant in its own comment: *"Bump this
when ANY hook template in lib/hooks.sh changes — the value must match the
commit-msg template's `# VERSION=X.Y` marker or install-hooks gets confused
(T-1079: previous drift left consumers silently on old hooks)."*

**The shipped tree violates that invariant.** The commit-msg template carries
`# VERSION=1.11` (`hooks.sh:75`, and the deployed `.git/hooks/commit-msg` agrees);
`git.sh` carries `1.6`. Consequences:

1. The equality can never hold, so the `Hooks already installed` fast path at
   `hooks.sh:53-56` is **unreachable code**.
2. Every `fw git install-hooks` without `--force` rewrites all four hooks and
   prints a message that reads as a downgrade — which is what produced a
   confident, wrong bug report from a real onboarding run.
3. PL-078's documented cure ("bump the commit-msg marker so consumers' next
   install-hooks redeploys all three") is **inert in both directions**: the
   short-circuit never fires whether you bump the marker or not.
4. It is latent-dangerous. The moment someone "tidies" `VERSION` to `1.11`, the
   fast path goes live for the first time and PL-078's stale-hook failure
   (T-1252, dormant on two consumers for unknown days) becomes reachable again.

This is a documentation-vs-code divergence that a comment could not prevent —
the comment already said exactly the right thing and was ignored for 5 marker
bumps. The fix has to be a test.

## Acceptance Criteria

### Agent
- [x] The comparison's right-hand side is the **commit-msg hook template's own**
      version, not the git agent's version. The two are separate concerns and
      should stop sharing a variable.
      → `COMMIT_MSG_HOOK_VERSION` in `agents/git/lib/hooks.sh`; `git.sh:VERSION`
      keeps its own meaning and its comment now says so.
- [x] The `Hooks already installed` fast path is **reachable**: running
      `install-hooks` twice in a row, without `--force`, short-circuits on the
      second run. This is the load-bearing AC — it is what proves the operands
      now denote the same thing.
      → Live on this repo, same command, before/after:
      - pre-fix comparison (`git show HEAD:agents/git/lib/hooks.sh:53`):
        `[ "$existing_version" = "$VERSION" ]` — `1.11` vs `1.6`, never equal
      - current: `bin/fw git install-hooks` → `Hooks already installed (version 1.11)`
      → Also pinned in the suite (test 5), against an isolated fixture.
- [x] Negative control: when the installed hook's marker does **not** match the
      template's, the fast path does **not** fire and the hooks are rewritten.
      Without this, hard-coding the fast path to always fire would pass the AC above.
      → Suite test 6: ages the installed marker to `0.1`, asserts no short-circuit
      AND that the stale marker is actually gone from the rewritten file.
- [x] The reinstall message no longer implies a direction it does not check
      → now reports `Hook version differs (installed: X, template: Y) — reinstalling`.
      Pinned negatively by test 7, which greps the file for the old wording.
- [x] `tests/unit/hook_version_marker_parity.bats` pins template-marker ↔ constant
      parity so this specific drift cannot recur silently, and is green. → 7/7, EXIT=0.

**Not changed, deliberately:** no hook template *content* was touched, so PL-078
does not require a marker bump here. `# VERSION=1.11` stays as-is; only the thing
it is compared against moved.

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

bash -n agents/git/lib/hooks.sh
bash -n agents/git/git.sh
out=$(bats tests/unit/hook_version_marker_parity.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
grep -q '^COMMIT_MSG_HOOK_VERSION=' agents/git/lib/hooks.sh
! grep -q 'existing_version" = "$VERSION"' agents/git/lib/hooks.sh
out=$(bin/fw git install-hooks 2>&1); echo "$out" | grep -q "already installed"

## RCA

**Symptom:** `fw git install-hooks` on a fresh install printed
`Updating hooks from version 1.11 to 1.6`, which reads as a version downgrade. A
live onboarding run reported it as "a lexical string comparison treating
1.11 < 1.6".

**That reported cause is wrong, and checking it is what found the real one.** The
line is `[ "$existing_version" = "$VERSION" ]` — an equality. No ordering
comparison exists anywhere in the file, lexical or otherwise. The bug is one
level up: the two operands were never the same quantity. `existing_version` is
the `# VERSION=` marker read back out of the *installed commit-msg hook* (`1.11`);
`$VERSION` is `agents/git/git.sh:19`, the *git agent's own* version (`1.6`).

**Root cause:** a hand-maintained duplicate of a value, with the copies living in
different files and different subsystems. `git.sh` even carried a comment
instructing the reader to keep them equal (*"the value must match the commit-msg
template's `# VERSION=X.Y` marker or install-hooks gets confused"*, citing T-1079
where exactly this drift left consumers on stale hooks). The comment was correct
and was ignored across five template-marker bumps.

**Why structurally allowed:** the failure is *silent in the safe direction*. When
the two disagree, the equality is false, so install-hooks reinstalls — which is
harmless. Nothing breaks, nothing goes red, and the only symptom is a confusing
line of output that everyone reads past. Meanwhile the `Hooks already installed`
branch became unreachable code and PL-078's documented staleness cure went inert
in *both* directions: bumping the marker and not bumping it had identical effect.
The latent danger is the tidy-up — the moment someone aligns `VERSION` to `1.11`
"for consistency", the fast path fires for the first time and T-1252's stale-hook
class becomes reachable again, now with a test-free mechanism.

**Prevention:** `tests/unit/hook_version_marker_parity.bats` — parity between the
constant and the literal baked into the template, plus the *reachability* of the
fast path exercised end-to-end against an isolated fixture, plus a negative
control that ages the installed marker. Prose already told people to keep the
values in sync; only a test can notice when they don't.

**Caught during the fix, worth recording — twice, both the same class:**
1. My explanatory comment *quoted* the old message string while claiming it had
   been removed, so the regression test that greps for that string failed on my
   own file. Identical to the T-2847 slip four hours earlier. Fixed by describing
   the old wording instead of reproducing it.
2. The first draft of the suite only `cd`'d into the fixture. But install-hooks
   resolves its target from `PROJECT_ROOT`, not cwd
   (`agents/git/lib/common.sh:29-36`) — so every run read and would have written
   the **framework repo's own** hooks. It reported "already installed" from
   `/opt/999-…/.git/hooks/commit-msg` and looked like a legitimate pass, and the
   negative control's `sed -i` was one existing file away from ageing the live
   repo's commit-msg hook. Fixed by exporting `PROJECT_ROOT="$FX"` and adding an
   isolation test that md5s the framework's hook before and after. Green about the
   wrong object, destructively — the T-2718/T-2725 family again.

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

### 2026-08-07T06:18:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2852-install-hooks-compares-the-git-agents-ve.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-17f65058
- **Timestamp:** 2026-08-07T06:24:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-07T06:24:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
