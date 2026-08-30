---
id: T-3222
name: "safe-list admits curl -o and wget -O, which write a file with no redirect"
description: >
  The Bash safe-list admits curl and wget unconditionally, violating the admission
  rule it states for itself: only verbs that cannot write a file WITHOUT a shell redirect.
  That is the basis on which it excludes awk and uniq. curl -o FILE and wget -O FILE
  both write with no redirect and are not flagged by has_bash_write_pattern, so both
  are ADMITTED with no active task. Measured against the live hook under T-3221: curl
  -o /tmp/zz http://x/ returns exit 0 with focus null. Reported as a side finding
  by peer 832-Workflow-designer (their T-638); confirmed in-tree. Separate from T-3221
  per one-bug-one-task: T-3221 fixed the git-commit exemption predicate and correctly
  defers clause admissibility to this shared allowlist, so this hole surfaces through
  it rather than being caused by it.

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
created: 2026-08-30T10:06:38Z
last_update: 2026-08-30T10:36:21Z
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
  - ts: '2026-08-30T10:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=258,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-30T10:15:18Z'
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

# T-3222: safe-list admits curl -o and wget -O, which write a file with no redirect

## Context

Side finding in peer 832-Workflow-designer's report of the sibling defect this
repo closed as T-3221 (their T-638, chat arc @823). Filed separately at the
time, per one-bug-one-task, and confirmed in-tree against the live hook rather
than taken on report:

```
ADMITTED  curl -o /tmp/zz https://e/          # focus null, no active task
ADMITTED  wget -O /tmp/zz https://e/
```

Full RCA below. Three things about it are worth stating up front, because they
are the parts a reader would otherwise have to reconstruct:

1. **The safe-list already had the right rule and two members violating it.**
   The rule is stated in the file — *only verbs that cannot write a file
   WITHOUT a shell redirect* — and it is why `awk` and `uniq` are excluded.
   `curl` and `wget` were filed under "system utilities", a category name that
   invites the wrong reading.

2. **A test asserted the bug.** `t3096_safe_commands_wrappers.bats` pinned
   `curl -sf "$(bin/fw watchtower url)/config" -o /tmp/x` as SAFE, inside a leg
   titled *"the prescribed port-resolution idiom is safe"*. The `-o /tmp/x` was
   not part of the prescribed idiom. Inverted, with the original text quoted in
   place rather than deleted.

3. **The fix is deliberately NOT in `has_bash_write_pattern`**, which is where
   the AC's own stated preference pointed. That function scans the whole raw
   command string and already treats a commit message mentioning `rm -rf` as a
   write (OBS-356). Putting `curl` there would have blocked any commit whose
   message discussed `curl -o` — another instance of the class this cluster
   exists to remove. Measured before deciding.

**Incident during this task, recorded rather than repaired quietly.** A
section-editing script I used to fill this file matched the string
`## Verification` where it appears inside the Human AC template's own prose,
and mangled the heading. That is OBS-355 for the third time, mine both times
before. The repair anchors on exact line content and asserts the real heading
follows. A task about a scanner mistaking a mention for an instance, filled by
a script making the same mistake, is worth leaving on the record.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The admission is reproduced against the LIVE hook with focus null:
      `curl -o /tmp/x https://…` and `wget -O /tmp/x https://…` currently
      return exit 0 with no active task
- [x] The rule the safe-list states for itself is quoted in the fix's comment —
      *"only verbs that cannot write a file WITHOUT a shell redirect"*, the
      basis on which it already excludes `awk` and `uniq`
- [x] `curl -o FILE` / `curl --output FILE` / `wget -O FILE` /
      `wget --output-document FILE` are blocked with no active task
- [x] `curl -o -` and `wget -O -` (write to stdout, not a file) stay ADMITTED —
      the flag is not the hazard, the destination is
- [x] Read-only forms stay ADMITTED: `curl -sf URL`, `curl -I URL`,
      `wget --spider URL`, and the framework's own documented verification idiom
      `curl -sf "$(bin/fw watchtower url)/page"`
- [x] Decide and record WHERE the fix lives — extending `has_bash_write_pattern`
      (so the write is visible to every caller, including the T-3221 commit
      predicate) versus narrowing the allowlist entry. Prefer the former: a
      command that writes a file should read as a write everywhere, not merely
      fail one allowlist test
- [x] A mutation control derived from live source: reverting the fix re-admits
      `curl -o FILE`, so a green suite is evidence about the fix
- [x] A no-widening leg — the fix admits nothing the pre-fix version blocked
- [x] Adjacent gate suites stay green (the 13 suites T-3223 swept: 190 ok,
      0 skips) and `bin/fw vendor self --check` reports in sync

### Human
<!-- No Human AC. Every criterion is a deterministic probe of the shipped
     allowlist, and the audience is the agent that trips the gate rather than
     the operator (CLAUDE.md §AC Classification, T-2143 audience test). The
     blast-radius judgement for this hook is already carried by T-3221's
     [REVIEW] AC, which covers the same file and the same consumers; asking it
     again here would put the same question in front of the operator twice. -->


## Verification

timeout 900 bats tests/unit/t3222_fetch_writes_file.bats > /tmp/.t3222a.out 2>&1 && grep -q "^ok 12" /tmp/.t3222a.out && ! grep -q "^not ok" /tmp/.t3222a.out
test "$(grep -c '# skip' /tmp/.t3222a.out)" -eq 0
timeout 1500 bats tests/unit/t3221_commit_exemption_clause.bats tests/unit/fd_dup_not_chain_split.bats tests/unit/safe_commands_chain.bats tests/unit/check_active_task_cwd_resolution.bats tests/unit/check_active_task_fp_fix.bats tests/unit/check_active_task_memory_exempt.bats tests/unit/check_active_task_switch_focus.bats tests/unit/context_safe_commands.bats tests/unit/safe_commands_env_prefix.bats tests/unit/t3096_safe_commands_wrappers.bats tests/unit/t3179_partial_complete_commit.bats tests/unit/test_check_active_task_bootstrap.bats tests/unit/test_safe_commands_git_commit.bats > /tmp/.t3222b.out 2>&1 && ! grep -q "^not ok" /tmp/.t3222b.out
test "$(grep -c '# skip' /tmp/.t3222b.out)" -eq 0
bash -n agents/context/lib/safe-commands.sh
bash -n agents/context/check-active-task.sh
bash -c 'source agents/context/lib/safe-commands.sh; _fw_fetch_writes_file "curl -o /tmp/x https://e/"'
bash -c 'source agents/context/lib/safe-commands.sh; _fw_fetch_writes_file "wget -O /tmp/x https://e/"'
bash -c 'source agents/context/lib/safe-commands.sh; ! _fw_fetch_writes_file "curl -sf https://e/"'
bash -c 'source agents/context/lib/safe-commands.sh; ! _fw_fetch_writes_file "curl -o - https://e/"'
grep -q 'cannot write a file WITHOUT a shell redirect' agents/context/lib/safe-commands.sh
python3 tools/bats-silent-skip-lint.py tests/
bin/fw vendor self --check > /tmp/.t3222v.out 2>&1 && grep -q "in sync" /tmp/.t3222v.out

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
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

**Symptom.** `curl -o FILE` and `wget -O FILE` were admitted by the Bash task
gate with no active task. Measured against the live hook with focus null before
any change; both returned exit 0.

**Root cause.** `curl` and `wget` sat in Category 5 of the safe-list as
unconditionally safe. The list states its own admission rule — *"only verbs that
cannot write a file WITHOUT a shell redirect"* — and enforces it elsewhere, which
is why `awk` and `uniq` are excluded. Both of these write a file with no
redirect, so `has_bash_write_pattern` (which looks for redirect syntax) never saw
them, and the allowlist waved them through. The rule was right; two entries
violated it.

**Why the framework allowed it.** The safe-list is organised by *verb category*
("system utilities") rather than by the property it actually cares about
(can this write without a redirect). `curl` reads like a fetch tool, and the
category name invites that reading. Nothing re-checked the members against the
stated rule after they were added — the rule lived in a comment, and comments do
not run.

Worse: **a test asserted the bug.** `tests/unit/t3096_safe_commands_wrappers.bats`
contained

```
run is_bash_safe_command "curl -sf \"$(bin/fw watchtower url)/config\" -o /tmp/x"
[ "$status" -eq 0 ]
```

as part of a leg titled *"the prescribed port-resolution idiom is safe"*. The
`-o /tmp/x` was an embellishment — CLAUDE.md's prescribed idiom is
`curl -sf "$(bin/fw watchtower url)/page"` with no `-o` — but once written it
encoded the hole as a guarantee. That is worse than an untested area, because
the next person to look reads it as a decision someone made on purpose. The leg
has been inverted, with the original text quoted in place so the change is
legible rather than silent.

**Where the fix lives, and why not where it "should".** The obvious home is
`has_bash_write_pattern`, so a fetch-write reads as a write to every caller.
It is deliberately NOT there. That function scans the whole raw command string
and already classifies `git commit -m "we no longer rm -rf the output dir"` as a
write — a mention in a commit message treated as an action (measured;
registered as OBS-356; predates this task). Adding `curl` there would have added
another instance of the exact class T-3221 and T-3223 exist to remove, and would
have blocked any commit whose message discussed `curl -o`. The check is
clause-scoped instead, operating on quote-stripped text with the base command
already extracted, so only a real invocation matches. A dedicated test leg pins
that the mention stays admitted.

**The join with T-3221.** T-3221 measured `git commit … && curl -o FILE` as still
admitted and left it open on purpose, because its predicate defers clause
admissibility to this shared allowlist. Closing the hole here closed it there
too, with **no change to the commit predicate** — the composition property that
task was built for, now demonstrated rather than argued.

**Escalation level.** C (tooling), with a D-flavoured note: the category-based
organisation of the safe-list is what let a member drift from the stated rule.
Filed as an observation rather than restructured here — one bug, one task.

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

### 2026-08-30T10:06:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3222-safe-list-admits-curl--o-and-wget--o-whi.md
- **Context:** Initial task creation

### 2026-08-30T10:36:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
