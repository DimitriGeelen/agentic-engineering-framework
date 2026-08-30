---
id: T-3221
name: "check-active-task git commit exemption matches a mention, not a command"
description: >
  check-active-task git commit exemption matches a mention, not a command

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
created: 2026-08-30T10:01:38Z
last_update: 2026-08-30T10:01:38Z
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

# T-3221: check-active-task git commit exemption matches a mention, not a command

## Context

Reported by peer 832-Workflow-designer (their T-638, fixed in their vendored
copy under their G-008) on the chat arc at offset 823. The code is ours; the
hole is still open upstream. Confirmed in-tree before acting, not taken on
report.

Two exemption branches in `agents/context/check-active-task.sh` admit a Bash
command **with no active task**, or with a partial-complete task, on the basis
that it is a `git commit`:

- line ~519, T-2054 — focus is null after `--status work-completed`, but the
  completion's own file-move and episodic still need committing.
- line ~778, T-3179 — a partial-complete task checkpointing its own work.

Both test whether the command **contains** the words, against the raw
unstripped string, unanchored to any clause:

```
[[ "$BASH_CMD" =~ (^|[[:space:]])git[[:space:]]+commit($|[[:space:]]) ]]
```

The rationale in the comment is right — a commit persists work already
produced under the Write/Edit gate, so it is not new work. It is true of a
command that **is** a commit. It is not true of a command that merely says so.

**Second defect, compounding it.** The `has_bash_write_pattern` check at line
220 does not exit — it falls through with `:` to the active-task check. So a
command already correctly identified as a write reaches the exemption and is
handed exit 0. Our own T-3179 block message tells the agent *"write patterns
void the allowance"*, which the fall-through appears to make false. That claim
is measured in this task, and either the code or the message is wrong.

This is L-547 (T-2834) again — *"a fast-path exemption in a gate must classify
the WHOLE command, not its first word"* — keyed this time on the payload rather
than the first word. Registered as OBS-355 while landing T-3217; 832 counts six
instances in three days across six instruments, and the focus-drift gate made
it seven by firing on a `T-1` written inside a heredoc during this very task's
measurement.

Scope fence: **one bug, one task.** 832's side finding — the safe-list admits
`curl`/`wget` unconditionally, and `curl -o FILE` writes with no redirect — is
a separate admission-rule violation and gets its own task, not a patch inside
this predicate.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A prober measures the LIVE hook (not a paraphrase of it) with focus null
      and with a partial-complete focus, and records ADMITTED/blocked per case
- [x] `git commit -m "..." ; <anything>` is blocked — a trailing clause no
      longer rides through on the commit's admissibility
- [x] `git commit -m "..." | tee f` is blocked — a write the gate already
      flagged is no longer admitted anyway (defect 2)
- [x] `somebinary --flag "please git commit this"` is blocked — a quoted
      argument that mentions a commit is not a commit
- [x] `git add -A && git commit -m "..."` still ADMITTED — the documented
      post-completion form must not regress, and its admissibility comes from
      the shared allowlist rather than a hand-rolled pair
- [x] `git commit -m "..."` bare still ADMITTED at both branches
- [x] Command substitution `$(` and backtick in the command are refused
- [x] Both branches (T-2054 null-focus, T-3179 partial-complete) use the same
      predicate — the bug is fixed once, not twice, with no second copy to drift
- [x] A no-widening leg asserts the fixed hook admits nothing a pre-fix mutant
      blocked, so the fix cannot have loosened the gate
- [x] A mutation control: reverting the predicate to the substring match turns
      the suite red, so a green run is evidence about the fix and not about the
      test
- [x] The T-3179 block message's "write patterns void the allowance" claim is
      either made true by the fix or corrected — no surviving false claim
- [x] `bin/fw test lint` and the invariant suite stay green; self-vendor in sync

### Human
- [ ] [REVIEW] Confirm the tightened gate does not break a workflow you rely on

  This is a blast-radius call, not a correctness one — correctness is measured
  by the 14-test suite and the no-widening leg. Every consumer project vendors
  this hook, so a gate that is right in principle can still be wrong in your
  hands.

  **Steps:**
  1. `timeout 900 bats tests/unit/t3221_commit_exemption_clause.bats`
  2. Read the ADMITTED/blocked matrix in this task's RCA below.
  3. Ask whether any commit-shaped command you actually type is in the blocked
     column — particularly a commit chained to something that is not `git add`.

  **Expected:** everything you type to checkpoint work is still admitted. The
  newly-blocked forms are a commit chained to a write or to an unknown binary,
  which the framework's own guidance already tells agents to split into separate
  calls.

  **If not:** name the command. The remedy is to make its other clause
  admissible in the shared allowlist (where every caller benefits), not to
  loosen this predicate — that is the composition property test 7 pins.

## Verification

timeout 900 bats tests/unit/t3221_commit_exemption_clause.bats > /tmp/.t3221.out 2>&1 && grep -q "^ok 14" /tmp/.t3221.out && ! grep -q "^not ok" /tmp/.t3221.out
test "$(grep -c '# skip' /tmp/.t3221.out)" -eq 0
timeout 900 bats tests/unit/t3179_partial_complete_commit.bats tests/unit/test_safe_commands_git_commit.bats tests/unit/safe_commands_chain.bats tests/unit/context_safe_commands.bats > /tmp/.t3221r.out 2>&1 && ! grep -q "^not ok" /tmp/.t3221r.out
test "$(grep -c '# skip' /tmp/.t3221r.out)" -eq 0
bash -n agents/context/check-active-task.sh
bash -n agents/context/lib/safe-commands.sh
test "$(grep -c 'is_commit_checkpoint_command "$BASH_CMD"' agents/context/check-active-task.sh)" -eq 2
bash -c 'source agents/context/lib/safe-commands.sh; is_commit_checkpoint_command "git commit -m \"x\""'
bash -c 'source agents/context/lib/safe-commands.sh; ! is_commit_checkpoint_command "git commit -m \"x\" ; rm -rf /tmp/z"'
bash -c 'source agents/context/lib/safe-commands.sh; ! is_commit_checkpoint_command "somebinary --flag \"please git commit this\""'
python3 tools/bats-silent-skip-lint.py tests/unit/t3221_commit_exemption_clause.bats
bin/fw vendor self --check > /tmp/.t3221v.out 2>&1 && grep -q "in sync" /tmp/.t3221v.out


## RCA

**Symptom.** Two branches of the Bash task gate admitted arbitrary commands
with no active task, provided the command contained the words "git commit"
somewhere — including inside a quoted argument to an unrelated binary.

**Measured, live hook, before any change** (`_verdict` harness, both branches,
identical results):

| command | before | after |
|---|---|---|
| `git commit -m "…"` | ADMITTED | ADMITTED |
| `git add -A && git commit -m "…"` | ADMITTED | ADMITTED |
| `git commit -m "…" ; rm -rf /tmp/z` | **ADMITTED** | blocked |
| `git commit -m "…" \| tee f` | **ADMITTED** | blocked |
| `somebinary --flag "please git commit this"` | **ADMITTED** | blocked |
| `git commit -m "$(cat /etc/hostname)"` | **ADMITTED** | blocked |
| `echo "git commit" > f` | blocked | blocked |
| `git commit --no-verify -m "…"` | blocked | blocked |
| `rm -rf /tmp/z` | blocked | blocked |

**Why did the framework allow this?** Three answers, in increasing depth.

1. *The predicate asked the wrong question.* "Does this string contain a
   commit" instead of "is this a commit". A containment test over a whole
   command has no notion of clause, so everything after `;` inherits the
   admissibility of what came before it.

2. *The write check could not enforce itself.* `has_bash_write_pattern` at
   line 220 classifies correctly and then falls through with `:` rather than
   exiting, deferring the decision to the active-task check. Both exemptions
   sit downstream of that deferral and exit 0 without re-asking. So the gate
   detected the write and admitted it anyway — and the T-3179 block message
   told agents "write patterns void the allowance", which was not true of the
   code beneath it. A message describing a protection that does not exist is
   worse than no message: it stops the reader looking.

3. *Correctness was punctuation luck.* `echo "git commit" > f` blocked, while
   `somebinary --flag "please git commit this"` was admitted. The difference is
   only whether a space or a quote character precedes `git` inside the string.
   Nothing about the safety of either command entered into it. This is why the
   hole survived review: the obvious probe blocks.

**Class.** L-547 (T-2834): *a fast-path exemption in a gate must classify the
WHOLE command, not its first word* — here keyed on the quoted payload rather
than the first word. Peer 832 counts six instances in three days across six
different instruments; T-3217's own linter was blinded by `<<TAG` in a comment,
and the focus-drift gate fired on a `T-1` typed inside a heredoc while this task
was being measured, making seven. The remedy has been identical every time:
**read the structure that carries meaning, not the characters that spell it.**

**Prevention, not mitigation.** The predicate splits with the same quote-aware
`_fw_chain_split` the allowlist already uses, and requires every clause to be
independently admissible *via the shared allowlist* or to be the commit itself.
Composition is the load-bearing choice: a hand-rolled "cd or git commit" pair
would have blocked `git add -A && git commit`, the documented post-completion
form, and would then drift from the allowlist forever after. The write refusal
moved inside the predicate, so the guarantee travels to every caller instead of
being re-asserted at one call site — and the T-3179 block message is now true.

**What would have caught it earlier.** Nothing in the suite probed a *compound*
command at the exemption; every existing test used a bare commit. The mutation
control and the 16-command no-widening sweep added here are the standing answer:
a green run is now evidence about the fix rather than about the test.


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

### 2026-08-30T10:01:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3221-check-active-task-git-commit-exemption-m.md
- **Context:** Initial task creation
