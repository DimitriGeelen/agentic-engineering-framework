---
id: T-2831
name: "worktree remove surfaces uncommitted work instead of opaque dirty refusal"
description: >
  `fw worktree remove` refuses a landed worktree with git's raw dirty error. The
  dirt is not runtime noise — measured live it is a month-old fork of governance
  state holding real uncommitted work (a task completion + 2 decisions that never
  landed). The strand guard counts COMMITS only, so uncommitted work is invisible
  to it, and the `--force` the refusal trains toward destroys that work silently.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bug, worktree]
components: [lib/worktree.sh, tests/unit/create_task.bats]
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
created: 2026-08-06T16:02:15Z
last_update: 2026-08-06T16:33:57Z
date_finished: 2026-08-06T16:33:57Z
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
  - ts: '2026-08-06T16:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T16:15:10Z'
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
---

# T-2831: worktree remove surfaces uncommitted work instead of opaque dirty refusal

## Context

Filed from OBS-179 — **whose stated mechanism this task falsifies.**

OBS-179 claimed the dirt was runtime noise written by *main-session hooks* mutating the
worktree's forked governance state, and therefore discardable ("offer to reset those
paths"). Measurement says otherwise, and the correct fix is close to the opposite.

**Evidence (live, `.claude/worktrees/t100199-close`):**

- Every dirty file has mtime **2026-07-06**, the day of that worktree's HEAD commit;
  main's copies are dated today. Main-session hooks did not write these — the session
  that worked *inside* the worktree did, a month ago, and never committed.
- The 17 dirty entries are **not** all regenerable state. They include:
  - `.tasks/completed/T-2509-*.md` — the completion itself (`status: work-completed`,
    `date_finished`, Reviewer Verdict block). **Main's copy still says
    `status: started-work` with `date_finished:` empty, while sitting in `completed/`.**
    Commit `25dafc99c` ("T-2509: complete") landed the file *move* but not the metadata,
    because the metadata was written in the worktree and never left it.
  - `.context/project/decisions.yaml` — D-316 and D-317 for T-2509.
- **ID collision, third instance.** Main also has D-316/D-317 — for *different*
  decisions (T-2510 on 2026-07-07, T-2529 on 2026-07-11). Same IDs, different content,
  both live. Registers allocate by max+1 over the local tree, and a worktree is a fork
  of that tree. Already recorded for task IDs and the gap register; the decision
  register makes three.

**Why the current behaviour is dangerous rather than merely annoying:** the T-2829
strand guard asks "are any *commits* here on no remote?" — uncommitted work is outside
its question entirely. So a worktree can be simultaneously "0 commits stranded"
(guard: safe to remove) and holding a month of unlanded governance edits. The only
thing standing between that work and deletion is git's own dirty check, surfaced as a
raw error with no indication that anything of value is in it — which is exactly the
shape that trains `--force`, and `--force` discards it without a word.

## Acceptance Criteria

### Agent
- [x] `fw worktree remove` classifies dirty paths into **regenerable machine-local
      state** (counters, `.loop-detect.json`, `.pre-compact.*`, `session.yaml`,
      `focus.yaml`, `.hook-counter`) vs **content registers / work**
      (`.tasks/**`, `decisions.yaml`, `learnings.yaml`, `concerns.yaml`,
      `feedback-stream.yaml`, and anything outside `.context/working/`).
- [x] When only regenerable state is dirty, the refusal says so and names the safe
      remedy; when any content register is dirty, the refusal **names the files and
      shows the diffstat**, so the operator sees what `--force` would destroy.
- [x] Content registers are **never** auto-discarded — no code path resets them without
      an explicit, separately-named operator action.
- [x] `tests/unit/worktree_remove_dirty_class.bats` pins both classes, each asserting
      its precondition before its assertion (T-2828 vacuous-control lesson).
- [x] Mutation-checked: reverting the classifier turns the content-register test red.

### Human
- [ ] [REVIEW] Decide the fate of the real unlanded work found in
      `.claude/worktrees/t100199-close` (T-2509's completion metadata, D-316/D-317).
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && git -C .claude/worktrees/t100199-close diff --stat`
  2. Note that main's `.tasks/completed/T-2509-*.md` reads `status: started-work`.
  3. Decide: replay the completion metadata onto master, or accept it as lost.
  **Expected:** an explicit call, recorded — this is content, not noise, and
  D-316/D-317 cannot be replayed verbatim because those IDs are already taken in main.
  **If not:** leave the worktree in place; it is the only copy.

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

bash -n lib/worktree.sh
out=$(bats tests/unit/worktree_remove_dirty_class.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t2825_worktree_remove.bats tests/unit/worktree_remove_guard.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

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

**Symptom:** `fw worktree remove` on a dirty (but strand-guard-clean) worktree either
fails with git's raw `dirty/locked?` error, or — with `--force` — silently discards
whatever is dirty via `git worktree remove --force`, with no indication of value.
Live measurement on `.claude/worktrees/t100199-close` found 17 dirty files including
a task completion's metadata and two decision-register entries, a month unlanded.

**Root cause:** the framework had two guards for worktree removal — a commit-reachability
guard (T-2829, "would this strand any commit?") and git's own working-tree dirtiness
check — and no guard for "would this destroy uncommitted *content*?" sat between them.
Uncommitted work is structurally invisible to the commit guard (it only walks `git
rev-list`), so a worktree can read "0 commits stranded" while holding real unlanded
governance state. The only thing standing between that state and deletion was git's
opaque dirty refusal, which names nothing and trains the operator toward `--force` —
and `--force` (`git worktree remove --force`) discards dirt indiscriminately, with no
distinction between a stale `.hook-counter` and an unlanded task completion.

**Why structurally allowed:** OBS-179 (this task's origin) initially misdiagnosed the
dirt as main-session-hook noise and proposed offering to reset it — the opposite of
correct, since the dirt's mtimes predate any main-session hook run. No prior task had
classified worktree dirt by content-vs-noise; the guards that did exist (T-2825 strand,
T-2829 reachability question) both operate purely on commits, so "is anything valuable
in the working tree" was never asked at all.

**Prevention:** `_wt_dirty_summary` (lib/worktree.sh) now classifies every dirty path
via an explicit, narrow allowlist (`_wt_is_regenerable_path`) BEFORE `do_worktree_remove`
ever calls `git worktree remove`. Content-register dirt is refused unconditionally —
`--force` cannot reach it, because `--force` is the named strand-override flag, not a
content-discard action. Only paths on the allowlist (counters, `.loop-detect.json`,
`.pre-compact.*`, `session.yaml`, `focus.yaml`) are treated as safe, and the allowlist
is exact-match rather than directory-prefix — `.context/working/feedback-stream.yaml`
sits inside `.context/working/` but is content (a sovereignty log), and a prefix rule
would have misclassified it. Pinned by `tests/unit/worktree_remove_dirty_class.bats`,
including a dedicated test for that exact prefix-vs-exact-match trap, and mutation-
checked: reverting the classifier to always-regenerable turns the content-register
tests red.

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

### 2026-08-06 — implemented by a dispatched worker; verified independently

Implementation was produced by TermLink worker `tl-d016e051`, dispatched automatically by
the `lib/resolver.py loop --dispatch` daemon ~20 minutes after this task was filed (the
framework's own v1 dispatch substrate; dispatch `419c5e0b-835…`). The worker built in the
**shared working tree**, not a worktree — see the Gotcha note below.

The worker ticked AC5 ("mutation-checked") and stated the result in prose in `## RCA`, but
recorded no evidence. Re-run independently rather than taken on trust:

| Mutation | t1 regen-only | t2 content | t3 feedback-stream | t4 clean |
|---|---|---|---|---|
| `_wt_is_regenerable_path` → always regenerable | ok | **red** | **red** | ok |
| (none) | ok | ok | ok | ok |

Claim confirmed, and the discrimination is the right shape: t1 and t4 *should* survive
that mutation (regenerable-only dirt and clean worktrees behave identically either way),
so their green is signal, not slack. `lib/worktree.sh` restored to `c8e95689…` after.

Live end-to-end on the case that motivated the task — `.claude/worktrees/t100199-close`,
17 dirty files: REFUSED, 11 content-register files named with per-file diffstats,
including `.tasks/completed/T-2509-*.md`, `decisions.yaml` and `feedback-stream.yaml`.
Worktree left present with all 17 files intact. Uncommitted state backed up to a patch
before running, since that worktree is the only copy.

### 2026-08-06 — fail-safe classification (worker's call, endorsed)

- **Chose:** exact-match allowlist of regenerable paths; everything unlisted — including
  unrecognised files *inside* `.context/working/` — classified as content and refused.
- **Why:** the failure directions are not symmetric. Misclassifying content as
  regenerable destroys unrecoverable work silently; misclassifying regenerable state as
  content costs one extra `--force`. `.context/working/feedback-stream.yaml` is the
  proof case: it sits in the runtime directory but is the T-1985 sovereignty log.
- **Rejected:** a directory-prefix rule (`.context/working/*` → regenerable), which is
  what my own AC text implied and which would have discarded that file.
- **Note:** `--force` deliberately does **not** override the content refusal. `--force`
  is the named strand-override; overloading it into a content-discard action is what
  OBS-179's original "offer to reset those paths" proposal would have produced.

### 2026-08-06 — Gotcha: the worker built in the shared tree

`bin/fw vendor self`, run for an unrelated task, swept the worker's half-written
`lib/worktree.sh` into `.agentic-framework/`; the T-2240 self-vendor push gate caught it
and blocked the push. Reverted, and the vendored copy re-synced only after the worker
finished. Two agents editing one tree is the same fork hazard T-2822 describes, minus the
git-level isolation — check `ps` for `resolver.py loop` before attributing unexplained
tree changes to yourself.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO — the code change is done and verified; the open Human AC is a
selective-recovery call on the work found in `.claude/worktrees/t100199-close`, and my
advisory is to recover one thing, re-file one thing, and discard the rest.

**Rationale:** the guard now does its job — live-verified refusing the real worktree and
naming all 11 content files. What remains is a judgment about a month-old fork of
governance state, and the three parts of it have genuinely different answers:

| What | Advisory | Why |
|---|---|---|
| `.tasks/completed/T-2509-*.md` completion metadata | **Recover** | Not a preference — a factual correction. The task's work shipped in `25dafc99c` and the file already lives in `completed/`, but its frontmatter still reads `status: started-work` with empty `date_finished`. Main is currently self-inconsistent; the worktree holds the correct values. |
| `.context/project/decisions.yaml` D-316 / D-317 | **Re-file under fresh IDs, do not replay** | The IDs are already taken in main by unrelated decisions (T-2510, T-2529). Replaying verbatim would create two duplicate-ID pairs in the register. The *content* — the T-2505 recreation call and the T-2509 scoping call — is worth keeping if still true; the IDs are not. |
| VERSION, `lib/ts/dist/loop-detect.js`, metrics-history, session-metrics, gate-bypass-log, continuous-mode, 2 untracked audit files | **Discard** | Superseded by a month of main-line activity. VERSION there is 1.6.258 against main's 1.6.259+; the logs are append-only streams whose main-line copies already contain everything after that date. |

Once resolved, that worktree becomes removable through the normal path — no `--force`,
because the content refusal will have nothing left to refuse.

I am not making this call myself: replaying another session's month-old governance state
into the live registers is a content decision with an ID-collision hazard, which is
sovereignty territory rather than initiative.

**Evidence:**
- Live refusal output (11 content files + diffstats): `bin/fw worktree remove t100199-close`
- Uncommitted state backed up before any test touched it — 491-line patch, 17 files
- Main's inconsistency: `.tasks/completed/T-2509-*.md` line 7 `status: started-work`, while
  `git log --oneline -- .tasks/completed/T-2509*` shows `25dafc99c T-2509: complete`
- ID collision: worktree D-316 = "Recreate T-2505's scoped decision…" (T-2509, 2026-07-06);
  main D-316 = "Surface the F-ORCH retire_when finding…" (T-2510, 2026-07-07)
- mtimes of all 17 dirty files: 2026-07-06 — predating any main-session hook run, which is
  what falsifies OBS-179's "hook noise, therefore discardable" premise
- Tests: 4/4 new, 5/5 T-2829 guard, mutation-checked independently (see `## Decisions`)

## Updates

### 2026-08-06T16:02:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2831-worktree-remove-surfaces-uncommitted-wor.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-99abac96
- **Timestamp:** 2026-08-06T16:34:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `destroy`

### 2026-08-06T16:33:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
