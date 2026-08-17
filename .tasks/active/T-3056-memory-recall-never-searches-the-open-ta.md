---
id: T-3056
name: "memory-recall never searches the OPEN task corpus, so an existing open diagnosis
  is rediscovered at full cost"
description: >
  From T-3047 triage M-37 (ring20-management T-1540, 2026-08-04). agents/context/lib/memory-recall.py:30-31
  loads learnings/patterns/decisions only; recall() at :174-176 returns from that
  set with no third source and no .tasks/active/ read. Measured cost upstream: T-1390
  rediscovered as T-1537 25 days later with an accuracy regression.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [upstream-pickup, T-3047-triage]
components: []
related_tasks: [T-3047]
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
created: 2026-08-16T22:33:16Z
last_update: 2026-08-16T23:44:59Z
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
  - ts: '2026-08-16T22:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T22:45:08Z'
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

# T-3056: memory-recall never searches the OPEN task corpus, so an existing open diagnosis is rediscovered at full cost

## Context

Filed from T-3047 triage M-37 (ring20-management T-1540, 2026-08-04).

`agents/context/lib/memory-recall.py:30-93` builds its corpus from exactly three
files — `learnings.yaml`, `patterns.yaml`, `decisions.yaml` — and `recall()` at
`:174-205` searches only that list. There is no fourth source and no read of
`.tasks/active/`. So the two surfaces an agent actually sees at the start of work
(`fw recall "<query>"`, and the *Related knowledge* block `fw context focus`
prints via `agents/context/lib/focus.sh:153`) can only ever return knowledge
harvested from **closed** work.

The consequence is the one the upstream report measured: an open task already
diagnosing the problem is invisible to the agent about to diagnose it again.
Their instance was T-1390 rediscovered as T-1537 twenty-five days later, and the
rediscovery came back *less* accurate than the original.

There are 368 open tasks and 2677 closed ones here, so the missing corpus is not
a rounding error — it is the entire in-flight half of the project's memory.

Two traps this fix has to survive, and they pull in opposite directions:

- **Self-match.** `fw context focus T-XXX` builds its query *from T-XXX's own
  name and description* (`get_task_context()`, `:125-160`). Adding open tasks to
  the corpus without excluding the subject means every focus call proudly recalls
  the task you just focused on. It would look like the feature works.
- **Crowding.** `recall()` returns a single ranked list capped at `limit` (5 by
  default). 368 open tasks against ~600 knowledge items can take every slot, and
  the failure is silent — the caller cannot tell "no learnings matched" from
  "learnings matched but lost the ranking".

## Acceptance Criteria

### Agent
- [x] **A1** `load_knowledge_items()` gains open tasks from `.tasks/active/T-*.md`
  as a fourth item type (`task`), carrying id, name, and description so keyword
  search can score them the same way it scores the other three.
  → `load_open_tasks()`. Scoring ended up on the **name only** — see A3 for why
  the description had to come out. 368 files in 0.56s, regex over the file head
  rather than `yaml.safe_load`, because this is on the `fw context focus` path.
- [x] **A2** A task is never recalled by a query derived from itself.
  `fw context focus T-XXX` must not list T-XXX in its own *Related knowledge*
  block. Verified against a real task, not only a fixture — this is the trap that
  makes a broken fix look like a working one.
  → `exclude_task` threaded from `--task`. Live check: `--task T-1794` returns
  T-1795 and T-1792, not T-1794. Test 4 removes the exclusion and asserts the
  self-match comes back; test 5 pins that the exclusion drops one task, not all.
- [x] **A3** Open tasks cannot take every result slot. Either a cap on `task`-type
  results or an equivalent mechanism, with the chosen limit stated and justified;
  plus a measurement on the live corpus (368 active, 2677 completed) showing a
  query with strong learning matches still returns learnings after the change.
  → Two independent searches concatenated: memory keeps its own `limit`, open
  tasks get `OPEN_TASK_SLOTS = 2` **on top**. Crowding is unreachable by
  construction rather than by ranking, and test 7 pins the non-task line count
  as unchanged when five matching tasks are added.
  The harder half was relevance, and it took three measured passes — the write-up
  is in Evolution. Final: name-only haystack, `DF_CEILING = 0.10`,
  `OPEN_TASK_FLOOR = 4` → 22% of tasks get a hit, and the pairs scoring *exactly*
  the floor are real (T-1773 "spawn-side dispatch driver" ↔ T-1774 "CLI
  integration of spawn driver"). Test 10 pins the rate two-sided on the live
  corpus, because 0% and 100% are both failures and neither is visible in code.
- [x] **A4** The hybrid-search path (`search_hybrid`, `:96-109`) is handled
  explicitly, not left to fall through. It filters on
  `category == "Project Memory"` and maps results back by content-matching
  against `items`; adding a source the vector index does not carry that category
  for must either be wired in or documented as keyword-only, with the reason.
  → Keyword-only, deliberately, reasoned in the `recall()` docstring. The
  structural point is separate and mattered more: the old `recall()` **returned
  early** when hybrid matched, so appending open tasks after it would have made
  them invisible on the common path — the fix would have shipped as a no-op in
  exactly the case it is needed. Hybrid is now `_recall_knowledge()`, and the
  open-task leg runs unconditionally beside it.
- [x] **A5** A regression test over a synthetic `PROJECT_ROOT` covers: an open
  task is recalled by a matching query; the same task is NOT recalled when the
  query is derived from itself (A2); a learning-only query is unchanged by the
  new source (A3). Each assertion mutation-checked, and — per L-616 — with a
  positive control proving the harness can distinguish a hit from a miss.
  → `tests/unit/t3056_recall_open_tasks.bats`, 11 tests. Test 4 is the mutation
  (self-exclusion removed → self-match returns). Test 2 is the L-616 positive
  control. Tests 9 and 11 cover the two degenerate corpora (tiny, absent) that
  the frequency cut and the directory read could each silently swallow.

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
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
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
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# 1. The regression suite: 11 tests, mutation + positive control + both
#    degenerate corpora + the live-corpus two-sided rate bound. ~3s.
out=$(bats tests/unit/t3056_recall_open_tasks.bats 2>&1); echo "$out" | grep -q '^ok 11 ' && ! echo "$out" | grep -q '^not ok'

# 2. A2 on the live corpus, against whichever task happens to be first — the
#    self-match must not come back for a real file with a real frontmatter shape.
#    (`ls | head -1` here returns 141 under pipefail — head closes the pipe on 368
#    filenames. `sed -n 1{...}p` reads to EOF. L-387, in a verification line.)
tid=$(ls .tasks/active/T-*.md | sed -n '1s#.*/\(T-[0-9]*\)-.*#\1#p'); python3 agents/context/lib/memory-recall.py --task "$tid" --no-hybrid > /tmp/.t3056-self.out 2>&1 && ! grep -q "$tid" /tmp/.t3056-self.out

# 3. The open-task leg is not behind the hybrid early-return (A4). If `recall`
#    ever regains a `return` before the open-task search, this goes red.
python3 -c "import re,sys; s=open('agents/context/lib/memory-recall.py').read(); b=s.split('def recall(')[1].split('def ')[0]; sys.exit(0 if b.index('search_open_tasks') > b.rindex('_recall_knowledge') else 1)"

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

**Symptom:** an open task already diagnosing a problem is invisible to the agent
about to diagnose it again. Upstream measured the cost: their T-1390 was
rediscovered as T-1537 twenty-five days later, and the second attempt was less
accurate than the first.

**Root cause:** `memory-recall.py:load_knowledge_items()` builds its corpus from
`learnings.yaml`, `patterns.yaml`, `decisions.yaml` and nothing else. All three
are harvested at task *close*, so both recall surfaces — `fw recall` and the
*Related knowledge* block `fw context focus` prints — could only ever see closed
work. Here that is 2677 tasks visible and 368 invisible.

**Why structurally allowed:** the module is named for what it reads, not for what
it is asked. It is "project memory" (`.context/project/*.yaml`), and by that
definition it was complete and correct — every one of its three sources was
present and working. The question it is actually asked at `fw context focus` time
is "has anyone looked at this already", and open tasks are the better answer to
that question than any closed-task learning, because they are the ones nobody has
finished thinking about. Nothing in the code or its tests encoded the second
framing, so there was no place for the absence to show up. A missing *source* is
invisible in a way a broken source is not: every test passes, output looks
plausible, and the only symptom is a rediscovery weeks later that nobody connects
back.

**Prevention:** the fourth source plus
`tests/unit/t3056_recall_open_tasks.bats`. The load-bearing test is #10, which
pins the live-corpus hit rate *two-sided* (0% < rate < 35%). A one-sided test
would have let the two opposite regressions through, and both are silent: a floor
too high ships as a no-op indistinguishable from the original bug, a floor too low
puts wrong answers on half of all focus calls.

**Three near-misses in the build, each of which would have shipped looking fine:**

1. **A dead code path.** `recall()` returned early when hybrid search matched, so
   appending open tasks after it would have made them invisible on the common
   path — a no-op in exactly the case the feature exists for. Split into
   `_recall_knowledge()` with the open-task leg beside it, not after it.
2. **Tokenizer/matcher disagreement.** The query was split on `[a-z0-9]+` (so
   `do_drift` yields `drift`) but the haystack was searched with `\bdrift`, where
   `_` is a word character and the match fails. T-3049's genuine relative scored 2
   instead of 3 and fell under the floor. Invisible in the tuning measurement,
   which used set intersection on *both* sides and so was self-consistent — the
   measurement I used to pick the threshold could not see the bug in the code the
   threshold was for.
3. **A frequency cut that silences small projects.** `int(5 * 0.10) == 0` makes
   the ceiling 1, so any word shared by two tasks is discarded and a fresh
   consumer with a handful of open tasks gets nothing back, permanently. Found
   while writing the fixtures, not while writing the code. `DF_MIN_CORPUS`.

**What is not fixed.** Open-task recall is lexical only. Two tasks describing the
same problem in different words will not match, and that is a plausible shape for
the exact failure this addresses. The upgrade is a second hybrid call with its own
category filter — noted in the `recall()` docstring, not attempted here.

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

### 2026-08-16T22:33:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3056-memory-recall-never-searches-the-open-ta.md
- **Context:** Initial task creation

### 2026-08-16T23:44:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
