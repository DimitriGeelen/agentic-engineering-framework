---
id: T-2825
name: "worktree teardown strands unpushed commits and handoff commands use ephemeral
  worktree paths"
description: >
  Recovered from stranded worktree (T-2824); fixes G-075 (handoff commands hard-code
  ephemeral worktree cwd) and G-076 (worktree teardown has no unpushed-commit guard)

status: work-completed
workflow_type: build
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
created: 2026-08-06T11:24:15Z
last_update: 2026-08-06T12:02:06Z
date_finished: 2026-08-06T12:02:06Z
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
  - ts: '2026-08-06T11:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T11:30:12Z'
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
---

# T-2825: worktree teardown strands unpushed commits and handoff commands use ephemeral worktree paths

## Context

**Recovered from a stranded worktree by T-2824.** Originally filed 2026-07-01 as a
HIGH-PRIORITY operator-requested remediation, committed only inside
`.claude/worktrees/rca-worktree-push-strand`, and never landed. Re-minted here because
its original ID (`T-2428`) now names a different task on master — worktree-allocated
IDs are not authoritative.

Original RCA, unchanged: branch `t2353-audit-emit-tasks` accrued 6 commits (tip
`b508ceef1`) inside worktree `livefire-t2389`. The push was blocked by three sequential
pre-push gates; the only route left was a human-run `--no-verify` bypass. The handoff
one-liner hard-coded `cd .../.claude/worktrees/livefire-t2389 && …`. Days passed, the
worktree was removed, and the operator's paste failed at `cd: No such file or
directory`. **The commits never reached origin.** They survived only because
`git worktree remove` does not delete the branch.

Two gaps, recovered alongside this task and re-minted for the same reason:

- **G-075** [medium] — handoff commands tied to the ephemeral worktree cwd. The
  Copy-Pasteable Commands rule (T-609/T-1257) mandates a `cd <path> &&` prefix but is
  worktree-blind: it assumes the path persists.
- **G-076** [high] — worktree teardown has no unpushed-commit guard.

**This task is not history.** T-2822/S1 measured the same failure still running: 43
unlanded commits across two worktrees, dormant five weeks — this task's own commit
among them. It is the second-order instance of the very defect it was filed to fix.

**Relationship to T-2822** (GO recorded 2026-08-06, source-only): T-2822 stops
governance *writes* inside a worktree. It does **not** stop a worktree branch from
holding unpushed source commits, which is this task's subject. The two are
complementary, not overlapping — T-2822's own honest bound puts the lifecycle class
outside its 81%.

## Acceptance Criteria

### Agent
- [x] **G-076 teardown guard (primary):** a WorktreeRemove hook or `fw worktree remove` wrapper runs `git log <remote>/<branch>..<branch>` and refuses when the worktree's branch holds commits absent from all remotes; a Tier-2-logged `--force` proceeds. Regression test stages an unpushed-branch worktree and asserts the guard fires
- [x] Mutation-checked: reverting the guard makes that regression test go red
- [x] **G-075 handoff durability:** CLAUDE.md §Copy-Pasteable Commands gains a worktree-durability clause — commands that outlive the session (push, tier0 approve, review handoff) use the durable main-repo path plus an explicit branch ref, never a `.claude/worktrees/<name>` cwd
- [x] **G-075 static backstop:** the reviewer static scan flags a handoff command that combines a `.claude/worktrees/` cd-prefix with a push/approve/review verb
- [x] Guard is proven against the live case, not a synthetic one: run it against the two worktrees T-2824 triaged and show it reporting their actual unlanded counts
- [x] On close: G-075 and G-076 updated with `fixed_in: T-2825`; RCA finalised; `bin/fw reviewer T-2825` PASS

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

bash -n lib/worktree.sh
bash -n bin/fw
out=$(bats tests/unit/t2825_worktree_remove.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
python3 -m pytest tests/unit/test_reviewer_worktree_handoff_durability.py -q > /tmp/.t2825-pytest.out 2>&1 && grep -q passed /tmp/.t2825-pytest.out
python3 -m pytest tests/unit/test_reviewer_static_scan.py tests/unit/test_reviewer_write_set_underdeclared.py -q > /tmp/.t2825-pytest2.out 2>&1 && grep -q passed /tmp/.t2825-pytest2.out
out=$(bin/fw reviewer T-2825 2>&1); echo "$out" | grep -q "Overall.*PASS"
python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"

## RCA

**Symptom:** A worktree branch (`t2353-audit-emit-tasks`, tip `b508ceef1`, 6 commits)
was removed via `git worktree remove` while its commits existed on no remote. The
handoff one-liner that would have pushed them (`cd .../.claude/worktrees/livefire-t2389
&& fw tier0 approve && git push ...`) failed days later with `cd: No such file or
directory` because the worktree directory no longer existed. The commits sat local-only
and undiscovered for 5 weeks (measured again, still live, by T-2822/S1 — 43 unlanded
commits across two worktrees at time of this task's filing).

**Root cause (two compounding gaps, G-075 + G-076):**
1. **G-076 — no guard on the teardown path.** `git worktree remove` has exactly one
   job: detach the worktree directory from git's bookkeeping. It has no opinion about
   whether the branch it points at is reachable anywhere else. Nothing between "worktree
   removed" and "branch reachable only from a local ref" ever fires — no hook, no CLI
   wrapper, no warning.
2. **G-075 — handoff commands assume the worktree cwd persists.** CLAUDE.md's own
   Copy-Pasteable Commands rule (T-609/T-1257) mandates `cd <path> && ...`, correctly
   generalizing across framework-repo vs consumer-project paths, but it never
   distinguished a *durable* path (the main checkout) from an *ephemeral* one (a
   worktree). A command meant to run later inherited a cwd with no persistence
   guarantee.

**Why structurally allowed:** Worktree teardown was never treated as a governed
transition — `fw worktree create` (T-2469) and `fw worktree gc` (T-100196) both exist,
but `git worktree remove` itself was always a raw, ungated git primitive, reachable
directly by any Bash call. The session-end handover guard (T-1144,
agents/handover/handover.sh:1016) pushes to all remotes at *session* end, but a
worktree can be torn down independently of any session boundary, so that guard never
sees it. Two governed lifecycle events (worktree birth, session end) existed; the third
(worktree death) did not.

**Prevention:**
- `fw worktree remove <name> [--force]` (lib/worktree.sh:do_worktree_remove) is now the
  sanctioned teardown path: for every configured remote it checks whether the branch
  tip is fully caught up, refuses when none are, and requires a logged `--force` to
  proceed. No-remotes-configured fails closed. tests/unit/t2825_worktree_remove.bats
  (7/7) pins the guard; mutation-checked (neutralising the refusal turns 2 of 7 red).
- CLAUDE.md §Copy-Pasteable Commands gained a worktree-durability clause (point 6):
  any handoff command that outlives the session must use the durable main-repo path
  + explicit branch ref, never a worktree cwd.
- `lib/reviewer/static_scan.py:detect_worktree_handoff_durability` is the author-time
  backstop for the doc rule — it flags the exact
  `cd .../.claude/worktrees/<name> && <push|approve|review|decide>` shape in any task
  body, CONCERN severity, 11 tests in
  tests/unit/test_reviewer_worktree_handoff_durability.py.
- This closes the mechanism gap, not the historical instance: `fw worktree remove` only
  protects removals that go through it. A raw `git worktree remove` from the Bash tool
  is still possible and outside Tier 0's string-matching scope (see CLAUDE.md's own
  Tier 0 scope-boundary note) — the sanctioned path is the mitigation, not an absolute
  block. G-074 (fw doctor surfacing sibling-worktree unlanded-commit counts, T-2822
  slice 2) is the complementary passive detector for whatever slips past this active
  guard.

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

### 2026-08-06T11:24:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2825-worktree-teardown-strands-unpushed-commi.md
- **Context:** Initial task creation

### 2026-08-06T11:52:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b8eb5c27
- **Timestamp:** 2026-08-06T12:02:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-06T12:02:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
