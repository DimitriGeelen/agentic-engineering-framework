---
id: T-4394
name: "/approvals readiness cache is discarded on every commit by any worker (_readiness_stamp
  includes .git/logs/HEAD), so /approvals stays ~10-17 s in a busy repo"
description: >
  Found by T-4363's worker: web/shared.py _readiness_stamp (~:1531) includes .git/logs/HEAD,
  so any commit invalidates the whole readiness cache behind /approvals (approvals._queue_groups
  -> review_readiness, ~22 s cold, 8-16 s warm on ~4,400 tasks). Also the warm cost
  itself: arc demo-state subprocesses ~7 s and Human-AC parsing ~5.6 s. Key the cache
  on the inputs that actually change readiness (the task files involved, verdict ledger,
  arc YAMLs) instead of the global git reflog, and cut the two warm costs.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-10-19T14:21:49Z
last_update: 2026-10-19T14:55:40Z
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
  - ts: '2026-10-19T14:30:33Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-19T14:31:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-4394: /approvals readiness cache is discarded on every commit by any worker (_readiness_stamp includes .git/logs/HEAD), so /approvals stays ~10-17 s in a busy repo

## Context

T-4363 (Decisions, "Open (not fixed here)" item 2) measured that `_readiness_stamp`
(web/shared.py:1527) puts `.git/logs/HEAD` into the stamp of every readiness entry that
consulted the verdict ledger, so any commit by any worker discards the /approvals
readiness cache. Re-key on the git inputs the verdict validator actually reads
(lib/verdict_ledger.py): commits that mention the task id or touch its task file, and
commits touching task-independent committed inputs (.context/reviews, .context/costs,
policy/, .fabric/, .framework.yaml, ...). Warm-cost cuts (arc demo-state ~7 s, Human-AC
parsing ~5.6 s) are secondary scope, only if time allows.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A ledger-consulting readiness entry survives a commit that neither mentions its task id nor touches its task file nor any task-independent validator input (`test_ledger_entry_survives_unrelated_commit` in tests/web/test_t4394_readiness_git_key.py; red before the fix, green after)
- [x] The same entry is recomputed after a commit whose message mentions the task id, after a commit touching `.context/reviews/`, after a ref moving backwards (reset), and after a new branch carrying a commit that mentions the task (tests in the same file)
- [x] Substring semantics of the validator's `git log --grep=T-N` are honoured: a commit mentioning `T-91021` invalidates `T-9102` (test)
- [x] `tests/web/test_t4133_readiness_perf.py`, `test_t4053_review_readiness.py`, `test_t4096_review_parity.py`, `test_t4045_board_awaiting_review.py` pass (T-4133's `test_ledger_dependent_entry_recomputes_after_commit` updated: its "elsewhere" commit now keeps the entry; the recompute leg uses a commit that mentions the task)
- [x] `bin/fw vendor self --check` clean for web/shared.py
- [x] Watchtower restarted once at the end; `bin/fw watchtower current` exits 0
  (note 2026-10-19 17:2x: `fw vendor self --check` was red only on `.agentic-framework/.tasks/templates/default.md`, a one-line vendored edit another worker made at 17:20 and still has in flight; web/shared.py is byte-identical to its vendored copy. Not synced here.)

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
- [ ] [REVIEW] /approvals looks and groups exactly as before
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` and open `<url>/approvals`
  2. Compare the Decisions / Ready / Waiting sections against what you saw before this change (same tasks in the same sections, same reasons)
  3. Reload the page right after any commit lands and note whether it is faster than before (~10-17 s previously)
  **Expected:** layout and grouping unchanged; a reload after an unrelated commit no longer pays the cold readiness cost
  **If not:** note which task moved section (or which reason changed) and reopen T-4394

<!--
  Render-touching build tasks (web/templates, web/static, web/blueprints, web/shared.py,
  web/app.py …) add a section headed "Visual Verification" (level-2 heading) after
  Verification, with one checklist table — the check-visual-verification gate reads it
  at commit time (T-4213; T-4202 GO):

    | state | control | 1024 | 1440 | 1920 | note |
    |-------|---------|------|------|------|------|
    | toolbar | Load | ok | ok | ok | |

  Cells: ok / clipped / hidden / overlap / unreachable (non-ok needs a note). Each
  listed state needs screenshots at every UX_SHOT_WIDTHS width:
  fw ux shots <T-ID> <state>=<URL>. This comment is inert: the gate ignores it.
-->

## Verification

python3 -m pytest tests/web/test_t4394_readiness_git_key.py -q -p no:cacheprovider > /tmp/.t4394a 2>&1 && grep -q passed /tmp/.t4394a && ! grep -q failed /tmp/.t4394a
python3 -m pytest tests/web/test_t4133_readiness_perf.py tests/web/test_t4053_review_readiness.py tests/web/test_t4096_review_parity.py tests/web/test_t4045_board_awaiting_review.py -q -p no:cacheprovider > /tmp/.t4394b 2>&1 && grep -q passed /tmp/.t4394b && ! grep -q failed /tmp/.t4394b
sed -n '/^def _readiness_stamp/,/^def _shared_ledger/p' web/shared.py > /tmp/.t4394c && ! grep -q 'logs/HEAD' /tmp/.t4394c
bin/fw vendor self --check
bin/fw watchtower current
# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# Build/refactor/decommission tasks with NO command here are refused. If nothing can be
# run, add the line `# verification: none — <why nothing can be run>`; it is serviced
# (queued for review: add a check / other evidence / accept). See docs/reports/T-4024-servicing-loop.md.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
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

**Symptom:** /approvals stays at ~10-17 s in this repo: every commit by any worker
throws away the readiness cache, so the next page load recomputes readiness for every
task with an open reviewer-judged Human criterion (T-4363 measurement).

**Root cause:** `_readiness_stamp` (web/shared.py:1527-1533) put the mtime of
`.git/logs/HEAD` into the stamp of every readiness entry that consulted the verdict
ledger. The reflog moves on every commit, so the stamp stood in for "git history may
have changed" as a whole, while the verdict for task X depends only on (a) commits that
mention X (producer set, components, rung: `git log --grep=X`, a substring match), (b)
commits touching X's task file, (c) a small set of task-independent committed inputs
(verdict/acknowledgement/cost ledgers, policy/, .fabric/, .framework.yaml, vendored tree),
and (d) history being rewritten or dropped.

**Why structurally allowed:** T-4133 narrowed the stamp for ledger-free entries only and
pinned "ledger-dependent entry recomputes after an unrelated commit" as the *expected*
behaviour (tests/web/test_t4133_readiness_perf.py), so the over-invalidation was codified
by a test rather than flagged; no test checked the cache across a commit irrelevant to the task.

**Prevention:** the stamp is derived from the new commits themselves (per-task and global
generations in web/shared.py), and tests/web/test_t4394_readiness_git_key.py pins both
directions: an irrelevant commit keeps the entry; every relevant class of commit
(mention, task file, global input, rewind, new branch) drops it.

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

**Recommendation:** GO
**Rationale:** The readiness cache behind /approvals no longer drops every entry on every commit. Each entry is now keyed on the commits that concern its task, plus the task-independent inputs the verdict validator reads. Both directions are pinned by tests. A commit that names the task, touches its task file, touches a global input, rewinds a ref, or adds a side branch carrying a mention still drops the entry, so the page cannot serve a stale verdict. Rendering is unchanged (no template or blueprint edit), so the one open question is your look at /approvals.
**Evidence:**
- Red before the fix: `test_ledger_entry_survives_unrelated_commit` and `test_new_branch_with_mention_invalidates` failed (2 failed, 12 passed). The second one is an existing stale-data hole: the validator greps `--all`, but a side branch moving never touched `.git/logs/HEAD`.
- Green after: tests/web/test_t4394_readiness_git_key.py has 17 passed. The neighbouring readiness suites (T-4133, T-4053, T-4096, T-4045), including T-4133's memo on/off equivalence sweep over this repo's active tasks, are green.
- In-process on this repo (355 tasks with an open Human criterion): cold 14.0 s / 355 recomputes; warm 1.0 s / 0. After simulating HEAD 3 commits back, the ref diff costs 0.09-0.16 s and there are **0 recomputes** (the old stamp recomputed all 355).
- Separate instance on :3994: warm /approvals 7.5-8.4 s before and 8.4 s after two real commits (47f59178e/0c76fd224 and another worker's 6a1137ac9). The cold-readiness jump is gone. What remains is the page's own warm cost (below).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-19 — key on the commits themselves, not on a narrower file stamp
- **Chose:** keep a ref snapshot per repo. When `verdict_ledger._git_state_token` moves, walk only the newly reachable commits of the refs that moved, plus HEAD's own old..new range. Then bump a per-task generation for every task id named in a message (all digit prefixes, matching the validator's substring `--grep`) or whose task file was touched. Bump a global generation for a dropped or rewound ref, HEAD leaving its line, a touched task-independent input, or any git failure.
- **Why:** the verdict reads history (`--grep` over `--all`, task-file versions at HEAD, ledger history), not files, so no file mtime can stand in for it. Listing too many commits only over-invalidates, which is safe.
- **Rejected:** keeping `.git/logs/HEAD` (the bug); `git log -1 -- <paths>` per task (one subprocess per task, and it misses `--all` mentions); excluding all ~3,000 refs from the walk (1.3-1.7 s per ref move, measured, vs 0.09-0.16 s for moved refs only).

### 2026-10-19 — warm-cost cuts left open (secondary scope)
- **Chose:** not to cut the warm /approvals costs in this task.
- **Why:** profiled warm in-process (12.5 s under the profiler): `_load_close_ready_arcs` 3.7 s (9 `fw arc demo-check` subprocesses ~0.3 s each), `_load_pending_human_acs` 2.6 s (`_parse_acceptance_criteria` on 355 bodies), `_load_stale_keystones` 1.8 s. Caching demo-check needs its whole input set (demo file, arc YAML, member tasks, traceability) to avoid a stale "valid", and caching AC parsing needs the body key. Both are their own change on a render surface, and stale data on /approvals is worse than slow.
- **Open:** a follow-up task should cache `_arc_demo_state` keyed on those inputs, and cache parsed Human ACs per task-file mtime.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-19T14:21:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4394-approvals-readiness-cache-is-discarded-o.md
- **Context:** Initial task creation

### 2026-10-19T14:55:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
