---
id: T-3030
name: "dispatched workers run in the live checkout, not a worktree — concurrent writes
  to governance code"
description: >
  dispatched workers run in the live checkout, not a worktree — concurrent writes
  to governance code

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
created: 2026-08-16T09:01:25Z
last_update: '2026-08-16T09:15:13Z'
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
  - ts: '2026-08-16T09:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T09:15:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=4 
      (body:prompt-material); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3030: dispatched workers run in the live checkout, not a worktree — concurrent writes to governance code

## Context

**Observed live, 2026-08-16 08:34-08:41Z.** Closing T-3028 caused the dispatch
substrate to spawn a worker (session `2a9815a0-…`, opening prompt = the framework's
own Default Workflow Prompt, `Task ID: T-3028`). That worker ran **in
`/opt/999-Agentic-Engineering-Framework` itself**, not in a worktree, while the
interactive session was mid-edit in the same tree.

What it did, all uncommitted, all concurrent with me:

- added a 26-line guard to `agents/task-create/update-task.sh` — a governance gate
- created `tests/unit/ac_structure_close_gate.bats`
- edited `.tasks/active/T-2420-…md`
- deleted four tracked `.context/handovers/CHECKPOINT-*.md`
- ~~cleared `current_task` in the shared `.context/working/focus.yaml`~~ — **wrong,
  see Trigger below.** `update-task.sh` cleared it, not the worker. The correction
  matters: it moves the null focus from a *consequence* of the dispatch to its
  *precondition*.

The work was *good* and aligned — it read my in-flight T-3029 and executed its ACs.
That is the problem, not the mitigation: I discovered it only because I happened to
read the file I was about to edit and did not recognise my own task ID in a comment.
Had I not, I would have committed another agent's unreviewed edit to a completion
gate under my name. Alignment here was luck, and luck is not a control.

**Three distinct hazards, only the first of which is about this incident:**

1. **No write isolation.** Two agents, one working tree, no locking. Interleaved
   writes to the same file are silent corruption; `git status` shows a merged result
   with no indication two authors produced it.
2. **Shared single-slot state.** `.context/working/focus.yaml` holds one
   `current_task`. A worker setting or clearing it moves the interactive session's
   focus underneath it — which is what happened, and is why the next command hit the
   task gate with `current_task: null`.
3. **No provenance.** Nothing in the repo records that a file was touched by a
   dispatched worker. The only evidence was a process listing and a transcript path.

The framework already has the primitive: `fw worktree create` + `fw integrate run`
(T-100196), used for exactly this reason — real code lands via a worktree, never from
the session directly. Dispatched workers are the one class of writer that bypasses it.

Scope fence: this task establishes isolation and provenance for dispatched workers.
It does not redesign the dispatcher, and it does not change what triggers a dispatch.

## Trigger

Named by evidence, not inference. The dispatch record for this exact worker is
`.context/dispatches.jsonl`, `dispatch_id 9dba824d-b938-4cb0-bc0b-6badeacc72b9`,
`session_id 2a9815a0-7015-4792-a148-9b8ccb1af3d2` — the session id I observed in
the process listing. It carries `origin: systemd:unlabeled-unit`.

**The premise in AC #1 was wrong.** Nothing spawned this on
`--status work-completed`. The envelope's own `task_snapshot` reads
`status: started-work, ac_ticked: 8`, and the trigger is a clock:

| Link | Location |
|------|----------|
| Timer, every 30 min | `deploy/resolver-loop.timer:14` — `OnUnitActiveSec=30min` |
| Runs in the live checkout | `deploy/resolver-loop.service:39` — `WorkingDirectory=/opt/999-Agentic-Engineering-Framework` |
| The command | `deploy/resolver-loop.service:55` — `bin/fw resolver loop --dispatch --max 1` |
| Picks the task | `lib/resolver.py:1571 _select_eligible` → `:1523 _pick_eligibility` |
| Spawns the worker | `agents/termlink/termlink.sh:861` — `claude -p … --output-format stream-json` |

`journalctl -u resolver-loop.service` shows the tick at **10:33:56 CEST**
(08:33:56 UTC) and the dispatch envelope is stamped **08:34:00.595Z** — four
seconds later. Every other tick that day logged
`nothing to do — no eligible tasks`. One tick differed, and the difference is
the whole finding.

### Why that one tick differed

There *is* a guard, and it is the right guard:

```python
# lib/resolver.py:1526
if focused and meta["id"] == focused:
    return "in focus (main agent working it)"
```

It read `current_task: null`, so `focused` was `""` and the condition
short-circuited before the comparison. Focus was null because **the completion
path had just nulled it** — `agents/task-create/update-task.sh:2044-2055`, the
T-354 "clear focus if this was the focused task" block, which fires whenever
`PARTIAL_COMPLETE=false`.

And `PARTIAL_COMPLETE` was `false` for the wrong reason: this was the T-3029 bug
firing. The misplaced `## Measured Result` closed the AC sed range early, the
parser counted zero Human ACs, T-3028 was archived as a full completion, and
focus went to null on the way out. I then reopened T-3028 to `active/` at
`started-work` to reconcile — which made it eligible again — and the timer
ticked into that window.

So the sequence is: **a parser bug caused a false full-completion; the
false full-completion nulled focus; the null focus disarmed the only guard
protecting the interactive session's working set; the timer walked in.**

### What that says about the guard

The incident is not "the guard failed" — the guard did what it says. Three
structural facts survive fixing T-3029:

1. **The guard is one slot.** I had T-3028 and T-3029 both in flight. At most
   one of them can ever be protected, whatever focus holds.
2. **The completion path nulls the slot itself**, so the window opens at the
   moment the interactive session is *most* likely still holding the task —
   during close, reconciliation, or re-open.
3. **Focus is advisory-by-timing.** It is read once at pick time and never
   re-checked; a worker that runs for 20 minutes (this one ran 08:34→08:41) has
   no relationship to focus after the first second.

None of the three is addressed by write isolation alone, and write isolation is
not addressed by any of the three. They are the same hazard seen from the
picker's side; hazards 1-3 above are the same hazard seen from the writer's.

### Adjacent finding — deploy drift (not this task's scope)

The installed unit and the repo's template disagree:

- `/etc/systemd/system/resolver-loop.service:38` → `--cooldown-min 30`
- `deploy/resolver-loop.service:55` → `--stall-after 5`

The repo comment at `deploy/resolver-loop.service:50-54` explains that
`--stall-after` *replaces* `--cooldown-min` because a clock the tick interval
always wins is not a convergence guard (T-2862: 57 dispatches, 0 outcomes).
The host never got that change. This is the T-2494 deploy-mole class and belongs
in its own task — filed as an observation rather than absorbed here.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The trigger is identified and named in this task — cited by file:line, not inferred. See `## Trigger`. The AC's own premise ("spawned on `--status work-completed`") was wrong and is corrected there: the trigger is `resolver-loop.timer` on a 30-minute clock, and the close path's contribution was nulling the focus guard, not spawning anything.
- [x] The concern is registered in `concerns.yaml` — **G-083** (high), `.context/project/concerns.yaml`, visible in `fw gaps`. Also updated **G-004**, which predicted this exact scenario in 2026-02 and whose `decision_trigger` fired here after six months of a `manual` trigger-check nobody ran.
- [x] A dispatched worker's writes are attributable after the fact — **chose the dispatch-id record over the worktree**, implemented in `lib/spawn.py` (`_git_state` / `_writes_between`, bracketing the handler call) and surfaced by `fw resolver explain <id>`. Rationale in `## Decisions`.
- [x] The single-slot focus field is no longer what separates the two writers — **the AC's premise was wrong and is corrected below**; the worker never wrote `focus.yaml`. Replaced the declaration with evidence: `lib/resolver.py` `_dirty_paths` / `_dirty_task_ids` / `_require_clean_tree`.
- [x] A regression test covers the shipped mechanism, exercising the two-writer case — `tests/unit/t3030_two_writer_guard.bats`, 11 tests, all asserting against a **null focus** so nothing passes on the guard that already failed. Mutation-checked: neutering `_dirty_paths` turns tests 2-4 red while the negative controls stay green.

**AC #4 as filed said "focus.yaml is not silently mutated by a worker".** The
worker's own `events.jsonl` refutes that: 41 bash commands, and the single
focus reference is a `cat`. It read focus and never wrote it. `update-task.sh`
nulled it. The AC was aimed at the wrong half of the mechanism, so it was
re-scoped to the half that produced the incident rather than ticked against a
fiction.

- [ ] [REVIEW] The default is the tradeoff you want: unattended autonomy now declines to dispatch whenever the checkout carries uncommitted source
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw resolver pick --json > /tmp/on.json && FW_DISPATCH_REQUIRE_CLEAN_TREE=0 bin/fw resolver pick --json > /tmp/off.json && python3 -c "import json;a=json.load(open('/tmp/on.json'));b=json.load(open('/tmp/off.json'));print('guard ON eligible:',a.get('eligible'));print('guard OFF eligible:',b.get('eligible'))"`
  2. Read the two lists. The difference is the work the loop will now decline to start while you have uncommitted changes.
  **Expected:** You agree that "don't start a worker in a tree someone is editing" is worth the autonomy it costs. The per-task clause (never dispatch a task whose own file is uncommitted) is not negotiable and has no switch; only the tree-wide clause is being asked about here.
  **If not:** `cd /opt/999-Agentic-Engineering-Framework && bin/fw config set FW_DISPATCH_REQUIRE_CLEAN_TREE 0` — the per-task clause stays on, and every declined pick is still named in the journal rather than skipped silently.

  *Why this is yours and not mine:* you installed the loop as the deliberate "go
  autonomous unattended" act (`deploy/resolver-loop.service` header). Changing
  when it will and will not run is a change to that authorisation, not an
  implementation detail — and with a permanently dirty checkout the default
  costs you autonomy indefinitely. That is a call about how you want to work.

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

out=$(bats tests/unit/t3030_two_writer_guard.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t2489_resolver_pick.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t2491_resolver_loop.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t2914_resolver_stall_guard.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t2915_resolver_inflight_expiry.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
python3 -m pytest tests/unit/test_resolver.py tests/unit/test_resolver_run.py -q > /tmp/.t3030-pytest.out 2>&1 && grep -q passed /tmp/.t3030-pytest.out
python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"
bin/fw gaps > /tmp/.t3030-gaps.out 2>&1 && grep -q "G-083" /tmp/.t3030-gaps.out
bin/fw resolver explain 9dba824d-b938-4cb0-bc0b-6badeacc72b9 > /tmp/.t3030-explain.out 2>&1 && grep -q "worker_writes:" /tmp/.t3030-explain.out

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

**Symptom:** A systemd-dispatched worker and the interactive session edited the
same governance gate (`agents/task-create/update-task.sh`) concurrently in the
same working tree, uncommitted. Discovered only because the session happened to
read the file before editing it and did not recognise its own task ID in a
comment it had not written.

**Root cause:** Mutual exclusion between the autonomous loop and the interactive
session was implemented as a *declaration* — one advisory field, `focus.yaml`'s
`current_task` — rather than as evidence or a lock. Declarations can be wrong,
stale, or unset by a third party, and this one is unset by the framework itself:
`update-task.sh:2044-2055` nulls it on every full completion. So the guard's
weakest moment is the moment the session is most likely still working the task.

**Why structurally allowed:** three compounding omissions.
1. **The loop writes the shared tree by design** (`deploy/resolver-loop.service:39`
   pins `WorkingDirectory` to MAIN) and the framework's own isolation primitive —
   worktree + `fw integrate`, per CLAUDE.md §Trunk-Based Session Flow — was never
   applied to the one writer class that most needs it.
2. **No provenance.** Nothing recorded that a file was touched by a worker, so
   the failure is invisible after the fact: `git status` shows one merged result.
   The only evidence was a live process listing.
3. **G-004 predicted this in 2026-02 and nothing surfaced it.** Its
   `decision_trigger` was "first project where two agents need to work on the same
   task" and its `trigger_check.type` was `manual` — a promise to remember. Its
   `why_not_now` still read "only one agent exists (claude-code)", which stopped
   being true when the autonomous loop shipped, with nothing watching for that.

**Prevention (distinct from the fix):**
- The guard now reads git rather than a field, so it cannot be nulled by code that
  believes the work is done, and it holds for every task at once rather than one.
- `worker_writes` on the dispatch row makes the two-writer case *detectable after
  the fact* even if the guard is ever bypassed — the missing third leg in the
  origin incident.
- `tests/unit/t3030_two_writer_guard.bats` asserts against a null focus
  specifically, so a future change that restores reliance on the declaration
  fails rather than passes. Mutation-verified.
- G-083 carries the residue (no true write isolation) in a register that outlives
  this task file, per CLAUDE.md §When discovering structural flaws.

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

**Rationale:** All five Agent ACs are done and the mechanism is demonstrated on
live state rather than on fixtures. The one open question is not technical — it
is whether the default tradeoff is the one you want for your unattended
autonomy, which is why it is the single `[REVIEW]` AC. Two of this task's own
filed premises turned out to be wrong when checked against evidence, and both
corrections are recorded rather than quietly dropped; I would rather you see
that than a clean narrative.

**Evidence:**
- **Trigger named, not inferred.** Dispatch `9dba824d`, session `2a9815a0`,
  `origin: systemd:unlabeled-unit`; timer tick 08:33:56Z, envelope 08:34:00.595Z.
  Every other tick that day logged `nothing to do`.
- **Live demonstration, not a fixture.** While mid-edit on `lib/resolver.py`,
  `fw resolver pick` reports 0 eligible with the guard on and
  T-1719/T-1820/T-2171/T-2969 eligible with it off. Four workers would have been
  dispatched into a tree I was editing.
- **Tests bite.** 11/11 green in `t3030_two_writer_guard.bats`; mutation-checking
  by neutering `_dirty_paths` turns tests 2-4 red while the four negative
  controls stay green — so they are not passing vacuously.
- **No regressions.** t2489, t2491, t2497, t2914, t2915 bats green; 42 pytest in
  `test_resolver{,_run}.py` green.
- **Provenance is honest about its own limits.** A missing git snapshot yields no
  record rather than an empty one, and a run with the guard disabled is labelled
  as correlation rather than attribution.
- **Two corrections against my own filing.** The worker never wrote `focus.yaml`
  (its `events.jsonl` shows one `cat`, no write) — `update-task.sh` did. And the
  provenance oracle had to be git, not tool calls, because the worker created a
  file with zero `Write` calls.
- **Residue is registered, not implied closed.** G-083 records that true write
  isolation still does not exist; worktree-per-dispatch is named as needing its
  own inception, not folded in here.
- **Three adjacent findings filed rather than absorbed** (one bug = one task):
  OBS-279 (`fw gaps` hides `status: open` — 7 entries invisible), OBS-280
  (installed resolver-loop unit still runs the superseded `--cooldown-min`),
  OBS-281 (chat-arc write succeeds while read returns nothing, measured
  same-second).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-08-16 — attribution instead of worktree isolation

- **Chose:** record the dispatch's writes against the dispatch row
  (`worker_writes` in `dispatches.jsonl`, surfaced by `fw resolver explain`),
  and keep the worker in the main checkout.
- **Why:** AC #3 offered either. A worktree is the stronger isolation but it is
  a dispatcher redesign, which this task's scope fence excludes — the unit's
  stated premise is running off MAIN with no host install, no crontab, no
  registry entry (`deploy/resolver-loop.service:8-14`), and a worktree also
  splits the `.context/` state that outcome back-prop reads and writes. The
  combination shipped here gets most of the value: the picker refuses to start
  a second writer, and if one ever starts anyway, the record says which files
  were its.
- **Rejected:** worktree-per-dispatch — right answer, wrong task; it needs its
  own inception because landing an unattended worker's branch to master is an
  authority question, not an implementation one.

### 2026-08-16 — git state as the provenance oracle, not the worker's tool calls

- **Chose:** snapshot `git status --porcelain` either side of the worker and
  diff.
- **Why:** measured, not assumed. The origin worker created
  `tests/unit/ac_structure_close_gate.bats` with **40 Bash, 8 Edit and 0 Write**
  calls, so scanning `tool_use` blocks for `file_path` would have reported that
  file as touched by nobody. Redirections, heredocs, `sed -i`, `rm` and `git mv`
  are invisible to tool names and visible to git.
- **Rejected:** parsing `events.jsonl` tool calls — cheaper, and wrong on the
  very file that made this incident worth writing up.

### 2026-08-16 — two clauses, only one of them switchable

- **Chose:** a task whose own file is uncommitted is excluded unconditionally;
  uncommitted source anywhere excludes everything, but that clause honours
  `FW_DISPATCH_REQUIRE_CLEAN_TREE=0`.
- **Why:** the two claims have different strengths. "Do not dispatch a task
  someone is editing" is not a judgement call. "Any uncommitted source means a
  session is live" is a heuristic that costs autonomy on a permanently dirty
  checkout, and that cost belongs to the operator (the Human AC asks).
- **Rejected:** a single switch over both — it would let one config flag
  reopen the exact hole this task closed.

### 2026-08-16 — the churn list is the part that can silently break autonomy

- **Chose:** exclude `.context/working/`, `.context/audits/`, `.context/monitors/`,
  `.context/handovers/`, `.context/episodic/`, the JSONL ledgers,
  `metrics-history.yaml`, `.agentic-framework/`, `docs/generated/`, `VERSION`.
- **Why:** these are dirty on essentially every tick. Counting them would make
  the tree read as permanently busy, and a permanently-excluded backlog logs as
  `nothing to do — no eligible tasks`, which is indistinguishable from an empty
  one. That is the same false-green shape as the guard being replaced, so the
  fix would have reintroduced its failure mode in a new place. `_dirty_paths`
  fails open on git errors for the same reason.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-16T09:01:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3030-dispatched-workers-run-in-the-live-check.md
- **Context:** Initial task creation
