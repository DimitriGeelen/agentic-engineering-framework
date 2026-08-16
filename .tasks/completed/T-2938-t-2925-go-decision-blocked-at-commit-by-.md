---
id: T-2938
name: "T-2925 GO decision blocked at commit by G-052 duplicate-task-ID scan"
description: >
  T-2925 GO decision blocked at commit by G-052 duplicate-task-ID scan

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
created: 2026-08-12T10:49:02Z
last_update: '2026-08-16T22:25:23Z'
date_finished: 2026-08-12T11:07:13Z
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
  - ts: '2026-08-12T11:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-12T11:00:15Z'
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
  - ts: '2026-08-16T22:25:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2938: T-2925 GO decision blocked at commit by G-052 duplicate-task-ID scan

## Context

Operator recorded GO on T-2925 via Watchtower. The decision was written to the task
file but the follow-on commit was refused by the G-052 duplicate-task-ID pre-commit
scan (`agents/git/lib/dup-task-scan.sh`), leaving a recorded sovereign decision
uncommitted. The pre-push audit 20 minutes earlier reported
`[PASS] No duplicate task IDs across active/ and completed/`, and `git status
--short .tasks/` shows exactly one change (the T-2925 active→completed rename) — so
the refusing scan and the passing audit disagree about the same repository.

Sibling of L-551 (T-2864): a commit-boundary gate refusing while the repository
looks clean means the gate and the eye are reading different trees — the scan reads
`git ls-files --cached` (the index), the audit reads on-disk filenames.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The tree the refusal was computed against is identified (AMENDED — see Decisions; the premise that a duplicate existed on disk or in the real index was wrong)
- [x] The divergence is explained: `scan-staged`, `scan-worktree` and `fw audit` all pass, because the duplicate existed only in the scratch index built by a stale in-memory `_commit_decision`
- [x] `bash agents/git/lib/dup-task-scan.sh scan-staged` exits 0
- [x] T-2925's GO decision is committed and pushed; `git rev-list --count origin/master..HEAD` = 0
- [x] RCA names the structural gap and a prevention distinct from the fix (`fw doctor` currency check, proven to fire AND to clear)

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

# Each line rehearsed with `bash -c 'set -eo pipefail; <line>'` per T-2743.
out=$(bats tests/unit/t2938_watchtower_source_staleness.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
bash -n bin/fw
grep -q "watchtower_stale_sources" bin/fw && test -f lib/watchtower-staleness.sh
bash agents/git/lib/dup-task-scan.sh scan-staged
out=$(git log --oneline --all -- .tasks/completed/T-2925-version-discards-the-one-component-that-.md 2>&1); echo "$out" | grep -q "inception decision GO"

## RCA

**Symptom.** Operator recorded GO on T-2925 through Watchtower. The decision text
and the active→completed move landed on disk; the auto-commit was refused with
`ERROR: Commit blocked — duplicate task IDs in staged tree (G-052)`. A sovereign
decision sat outside history, which is the same outcome T-2864 was filed to fix.

**Root cause.** The Watchtower process serving :3001 (pid 523280) started
**2026-08-06 23:44**. The fix it needed — T-2864, which teaches `_commit_decision`
to put BOTH sides of a `R old -> new` porcelain line into `wanted` — landed
**2026-08-08 09:38** (`e5672e73b`). `web/app.py` runs `app.run(debug=args.debug)`
and the server was started without `--debug`, so there is no reloader. The process
held the Aug-6 bytes for six days. Its `_commit_decision` seeded a scratch index
from `git read-tree HEAD` (T-2708) — where `.tasks/active/T-2925-*.md` still
exists, the rename being uncommitted — and then added only the destination path.
The active/ side was never removed from that scratch index, so the committer
**manufactured the duplicate it was then refused for**. On disk and in the real
index there was never a duplicate at all.

**Why the investigation nearly went the wrong way.** Everything the repository
could be asked reported clean: `dup-task-scan.sh` exits 0 in *both* modes,
`git status --short .tasks/` shows one well-formed staged rename, and the pre-push
audit 20 minutes before the incident printed `[PASS] No duplicate task IDs`. The
task was filed on the premise that a real duplicate existed and the scan modes
disagreed. They do not. Three instruments agreeing that the tree is clean, while
a fourth refuses it, means the fourth is reading a tree the other three cannot
see — here, a scratch index inside a process running deleted code.

**Why structurally allowed.** `fw doctor`'s Watchtower check (bin/fw ~:1892) asks
two questions: is the pid alive, and does `/api/_identity` claim our PROJECT_ROOT.
Both were true every single run for six days, and it printed
`OK  Watchtower running`. Liveness and identity were being read as currency.
This is the web analogue of the cron `registry → generated → deployed` ladder
(L-364): "wired" is not "deployed", and here "running" is not "current". CLAUDE.md
already records the third rung (`deployed → executable`, L-365) as having no
automated gate; this is the same rung on a different subsystem.

**Blast radius is never one fix.** Five commits touched `web/` inside the stale
window — T-2842, T-2864, T-2885, T-2904, T-2905. All were inert. Two of them
(**T-2904, T-2905**) are human-owned and were sitting in the review queue for the
operator to verify *in the Watchtower that was not running them*. A [REVIEW]
verdict taken against a stale process is worse than no verdict, because it looks
like evidence. The operator should re-verify both against pid 1240191 or later.

**Prevention (distinct from the fix).** The fix was `bin/fw watchtower restart` —
thirty seconds, and it prevents nothing. The prevention is a currency check:
`lib/watchtower-staleness.sh` compares the running process's start time against
the mtimes of `web/**/*.{py,html,css,js}` and `fw doctor` WARNs when any source
is newer, naming files and the remedy. Proven in both directions on the live
server: it fired naming `web/app.py` after a touch, and cleared after restart —
a guard that has only ever been seen green is indistinguishable from one that
cannot go red.

**Deliberate mtime-not-content choice.** `git checkout` / `fw vendor` will
produce spurious WARNs. Accepted: a false WARN costs one restart, a missed WARN
costs another six-day window. This is the opposite call to T-2290 (MCP manifest,
mtime → content compare) and for the opposite reason — there the stale-WARN fired
constantly and the drift was loud; here the drift is silent.

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

### 2026-08-12 — AC #1 amended mid-task after its premise was falsified

- **Chose:** rewrite AC #1 from "the duplicate task IDs are identified, with both
  offending paths named" to "the tree the refusal was computed against is
  identified", and tick it against that.
- **Why:** the original AC encodes a wrong premise. It assumes a duplicate exists
  somewhere findable, because that is what the G-052 message asserts. There is no
  duplicate — not on disk, not in the index, not at the time of the refusal. The
  only tree that ever held one was a scratch index inside a process running code
  that had been deleted from the repository two days earlier. Ticking the AC as
  written would have required naming two paths that do not exist.
- **Rejected:** (a) leaving it unticked and closing with `--skip-acceptance-criteria`
  — that logs a bypass and buries the most interesting finding of the task in a
  gate-bypass entry; (b) ticking it on the grounds that "the duplicate was
  identified as nonexistent" — that is the after-the-fact reinterpretation P-010
  exists to prevent, and it is exactly the pattern the operator has caught before
  (T-1831 C-4). Amending the text and saying so in the open is the honest form.
- **Note:** filing ACs before the root cause is known is normal and correct — the
  alternative is investigating with no task, which the gate rightly refuses. What
  matters is amending them visibly rather than quietly reinterpreting them.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-12T10:49:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2938-t-2925-go-decision-blocked-at-commit-by-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9ef3238c
- **Timestamp:** 2026-08-12T11:07:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-12T11:07:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
