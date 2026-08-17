---
id: T-3066
name: "Approving a queued BVP driver proposal drops whichever driver holds that id today, not the one proposed"
description: >
  Approving a queued BVP driver proposal drops whichever driver holds that id today, not the one proposed

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
created: 2026-08-17T12:04:59Z
last_update: 2026-08-17T12:04:59Z
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

# T-3066: Approving a queued BVP driver proposal drops whichever driver holds that id today, not the one proposed

## Context

Reported upstream by the 832-Workflow-designer agent (thread
`aef-upstream-findings-2026-08-16` on `agent-chat-arc`, item 1 — the one item they
said they would not defer). Verified against our own source and our own register
before filing; what follows separates what is true of the code from what is true
of our data, because those differ.

**The code path.** A driver proposal is stored as a row in
`.context/bvp-driver-proposals.jsonl` carrying a literal `drop:` id. On approval,
`web/blueprints/bvp.py:874-875` passes that stored id through verbatim:

```python
if proposal.get("drop"):
    cmd.extend(["--drop", proposal["drop"]])
```

`_driver_add` then resolves it against the register **as it stands at approval
time** (`lib/bvp.sh:963-970`): it filters `free_drivers` for an entry whose `id`
equals `drop_id` and deletes it. Meanwhile ids are allocated to the lowest free
slot (`lib/bvp.sh:955-961`):

```python
next_n = 1
while f'F{next_n}' in free_ids:
    next_n += 1
new_id = f'F{next_n}'
```

So `F1` is not a name, it is a **slot**, and slots are recycled the moment they are
vacated. A proposal written when `F1` meant one driver, approved after `F1` was
reallocated, deletes a driver nobody proposed deleting. There is no record in the
proposal of what it *meant* to drop — only which slot that thing occupied at the
time. 832 measured their register recycling `F1` and `F3` within minutes, with a
pending proposal still holding `drop=F1`.

**Our data, stated separately.** No pending proposal on this register carries a
non-null `drop` — 0 of 95. So the hazard is not currently reachable here, and I am
not going to describe it as if it were.

What makes it reachable is the cap. `policy/value-drivers.yaml` holds 5 free
drivers (`F-RECALL`, `F-AUTONOMY`, `F3`, `F1`, `F2`) plus 4 protected = 9, and
`lib/bvp.sh:950-952` is `if total >= 9 and not drop_id: error`. **We are exactly at
the cap, which means the next proposal that gets approved is required to carry a
drop.** The condition is one proposal away, not hypothetical. And three of our five
free drivers already sit on recyclable numeric slots (`F1` = V_CONTEXT_FABRIC,
`F2` = V_COMPONENT_FABRIC, `F3` = V_PROMPT_QUALITY), so the recycling is not a
theoretical property of the allocator either — it is how our current register is
addressed.

**Why this class matters more than its blast radius.** The driver register is a
Sovereignty boundary: `free_drivers` mutates only through human approval, and the
whole point of `fw bvp driver propose` → operator review is that the human sees
what they are agreeing to. Here the human agrees to a sentence ("add V_X, drop
F1") whose second clause is resolved *after* they agree, against state that may
have changed since it was written. The approval UI shows them the proposal; the
register performs something else. That is not a scoring bug — it is consent
applied to the wrong object.

**Scope fence.** This task fixes the late-dereference only: an approval whose
`drop:` referent no longer means what it meant at propose time must fail safe
rather than delete. Two sibling defects found in the same read are deliberately
NOT in scope (§Task Sizing: one bug = one task) and are named here so the
exclusion is not silent:

- `_driver_add` has **no duplicate-name guard** — nothing stops a second
  `free_drivers` entry carrying an existing `name`. Confirmed by inspection at
  `lib/bvp.sh:972-975`.
- `.context/bvp-driver-proposals.jsonl` holds **92 test-residue rows** of 95
  pending (`V_TEST_DRIVER`, `V_RACEY`, `V_AGENT_PROPOSED`, `V_TASK_REF`, each
  repeated ~19×) — a test suite appending to production state, which also buries
  any real proposal in the operator's queue.

## Acceptance Criteria

### Agent
- [ ] A proposal records what it intends to drop in a form that cannot be
      reallocated — not a bare slot id. Existing rows carrying only `drop:` remain
      readable (the file is append-only history; 100 rows already exist).
- [ ] Approving a proposal whose `drop:` referent no longer denotes the same
      driver **refuses and changes nothing** — no driver deleted, no driver added,
      non-zero exit, and a message naming both what was proposed and what that id
      means now. Fail-safe, not best-effort: a partial apply here is a silently
      corrupted Sovereignty boundary.
- [ ] The refusal is reachable from the Watchtower approve route, not only from
      the CLI — that route is the one an operator actually clicks
      (`web/blueprints/bvp.py:874`), and a guard wired to the CLI leg alone
      reproduces the producer/consumer split this session already fixed once in
      T-3065 (L-399).
- [ ] Approving a proposal whose referent is unchanged still works, including the
      at-cap add-one-drop-one path — the guard must not make the cap unusable.
- [ ] A regression test reproduces the recycle sequence end-to-end (propose with a
      drop → that driver is removed by another route → the slot is reallocated to a
      different driver → approve) and fails against the current code. Mutation
      result recorded in Updates (L-616).

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

### 2026-08-17T12:04:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3066-approving-a-queued-bvp-driver-proposal-d.md
- **Context:** Initial task creation
