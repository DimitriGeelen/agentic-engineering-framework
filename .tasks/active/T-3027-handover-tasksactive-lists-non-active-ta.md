---
id: T-3027
name: "handover tasks_active: lists non-active tasks — OBS-276, T-3025 GO condition 2"
description: >
  handover tasks_active: lists non-active tasks — OBS-276, T-3025 GO condition 2

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
created: 2026-08-16T07:46:47Z
last_update: 2026-08-16T07:53:03Z
date_finished: null
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

# T-3027: handover tasks_active: lists non-active tasks — OBS-276, T-3025 GO condition 2

## Context

`tasks_active:` in every handover's YAML frontmatter is built by listing
`.tasks/active/*.md` and reading `id:` — the `status:` field is never consulted
(`agents/handover/handover.sh:263-273`, and the checkpoint path at :154-178 reads
`task_status` for the rendered detail line but still ignores it for the frontmatter).
`.tasks/active/` is a *directory*, not a state: it holds `captured` (parked),
`started-work`, `issues`, and partial-complete `work-completed` tasks awaiting a
human. So the field asserts ~119 tasks are active when ~37 are actually in flight.

This is OBS-276, and it is condition 2 of the T-3025 GO ("`tasks_active:` must mean
active"). It matters more after T-3025 than before: today the field is contradicted
a few hundred lines later by the Work in Progress dump, which carries per-task
`Status`. Option (3) elides that dump — at which point the frontmatter becomes the
*only* carrier of task state, and it is the one that is wrong. The T-3025 IW-2 probe
demonstrated the failure directly: given the digest, the reader read 82 parked tasks
as live work and stated one as in-progress with high confidence.

No code parses the field — `grep -rn tasks_active web/ lib/ agents/ bin/ tests/`
returns only the two producer lines, an AGENT.md doc line, and a fixture string in
`web/watchtower/test_scan.py`. Its consumers are readers: humans, the semantic index,
and agents recovering context. So the semantics can be corrected without a migration.

Fix is not merely a filter — filtering alone is lossy, since a parked or
awaiting-review task is still worth surfacing. Correct the field to mean what it
says and add sibling fields for the states it currently absorbs.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `tasks_active:` lists only tasks whose `status:` is in flight (`started-work` or `issues`); a `captured` or `work-completed` task in `.tasks/active/` does not appear in it
- [x] Information parity is preserved, not dropped: `tasks_parked:` (status `captured`) and `tasks_awaiting_review:` (status `work-completed`, still in `active/` — the partial-complete state) are emitted alongside it
- [x] Both emission sites are fixed — the full handover (`handover.sh:584`) and the checkpoint handover (`:188`) — so a checkpoint does not reintroduce the wrong claim
- [x] A task whose `status:` is missing or unreadable is classified as `tasks_unknown_status:` rather than silently counted as active (a parse failure must not read as a live-work assertion)
- [x] `tests/unit/handover_task_classification.bats` builds a real `.tasks/active/` containing one task of each status and asserts each lands in exactly one bucket, with the union equal to the directory listing
- [x] The live generated handover shows the corrected split, and `tasks_active:` count matches `bin/fw task list --status started-work`

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

bash -n agents/handover/handover.sh
out=$(bats tests/unit/handover_task_classification.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Both emission sites carry all three sibling fields (checkpoint + full handover).
[ "$(grep -c '^tasks_parked: \[\$PARKED_TASKS\]' agents/handover/handover.sh)" -eq 2 ]
[ "$(grep -c '^tasks_awaiting_review: \[\$AWAITING_REVIEW_TASKS\]' agents/handover/handover.sh)" -eq 2 ]
[ "$(grep -c '^tasks_unknown_status: \[\$UNKNOWN_STATUS_TASKS\]' agents/handover/handover.sh)" -eq 2 ]
# The old shape — accumulating every directory entry — survives in exactly one
# place, inside the classifier. Anywhere else means a site bypassed it.
[ "$(grep -c 'ACTIVE_TASKS="\$ACTIVE_TASKS\$task_id, "' agents/handover/handover.sh)" -eq 1 ]

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

**Symptom:** Every handover's frontmatter declared `tasks_active:` with ~119 task
IDs when ~37 were in flight. Given only the frontmatter, a reader takes parked
backlog for live work — measured, not hypothesised: the T-3025 IW-2 digest arm read
82 parked tasks as active and named one as in-progress, with high confidence.

**Root cause:** The producer read `id:` and never `status:`
(`agents/handover/handover.sh:263-273`). It equated *directory membership* with
*state*. `.tasks/active/` is a workspace holding four distinct states — captured,
started-work, issues, and partial-complete `work-completed` awaiting a human — and
the field named only one of them while listing all four.

**Why structurally allowed:** Two reasons, and the second is the interesting one.

1. Nothing reads the field. `grep -rn tasks_active web/ lib/ agents/ bin/ tests/`
   finds two producer lines, a doc line, and a fixture string — no parser. A field
   with no consumer has no test, so nothing could go red.
2. **A second, correct carrier was masking it.** The Work in Progress dump, a few
   hundred lines below, renders per-task `Status`. Any reader who noticed the
   contradiction believed the dump, because the dump is specific and the
   frontmatter is a bare list. So the wrong claim was *load-bearing for nobody* —
   until T-3025's GO elides that dump and promotes the frontmatter to sole carrier.
   This is the general shape worth naming: **a redundant correct source does not
   fix a wrong one, it hides it, and the error surfaces at the moment the redundancy
   is removed for unrelated reasons.** Removing a dump for size reasons is not
   obviously a correctness change, which is exactly why it nearly shipped as one.

**Prevention:** `tests/unit/handover_task_classification.bats` (10 tests) gives the
field the consumer it never had. Beyond the per-status cases, three tests exist
specifically to stop the regression rather than the bug: the *partition* test
(union of the four buckets equals the directory listing, so a future "just filter
it" change cannot silently drop parked tasks), the *both-sites* test (the checkpoint
and full handovers are separate heredocs ~350 lines apart — fixing one is how this
returns), and a *live-corpus parity* test that compares the classifier against a
grep which does not go through it. The unknown-status bucket is prevention too: a
parse failure now reports itself instead of being absorbed into an assertion about
live work.

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

### 2026-08-16T07:46:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3027-handover-tasksactive-lists-non-active-ta.md
- **Context:** Initial task creation
