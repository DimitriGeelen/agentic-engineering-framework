---
id: T-3133
name: "concurrent antigravity work reverted check-active-task.sh, dropping T-3038 and T-2987"
description: >
  The live PreToolUse gate agents/context/check-active-task.sh lost 186 lines mid-session (1012 to 840, uncommitted). The removed blocks are T-3038's _resolve_focus_file helper and T-2987's explain-why-the-remedy-did-not-apply block. The added lines include a */.gemini/antigravity-cli/brain/* path case, identifying concurrent antigravity work that re-applied its changes onto an older base rather than onto HEAD. Nothing detected it; it surfaced only because a self-vendor drift check blocked a push.

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
created: 2026-08-25T08:04:16Z
last_update: 2026-08-25T08:04:16Z
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

# T-3133: concurrent antigravity work reverted check-active-task.sh, dropping T-3038 and T-2987

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
**Symptom (measured, 2026-08-25 ~10:00).** `agents/context/check-active-task.sh`
— a live PreToolUse governance gate — is 840 lines in the working tree against
1012 at HEAD, uncommitted. It was clean at session start (09:23, `9e5fe3cf0`);
its mtime is `10:00:01`. The working content matches **no** commit among the last
25 touching that file, so it is not a `git checkout` of an older revision — it is
a re-derivation.

**What was lost.** Two documented, committed behaviours:

- **T-3038 / OBS-291** — the `_resolve_focus_file` helper and both call sites,
  replaced by a hard-coded `FOCUS_FILE="$PROJECT_ROOT/.context/working/focus.yaml"`.
  Session-scoped focus (`FW_SESSION_SCOPED_FOCUS=1`) is therefore inert in the
  running gate, including the deliberate shared-file fallback for dispatched
  workers.
- **T-2987** — the ~115-line block explaining *why* the advertised remedy did not
  apply (the `has_bash_write_pattern` whole-line classification that voids the
  bootstrap exemption). Its absence restores the identical-message loop T-2987
  was filed to break.

**What was added**, and what it identifies: a path case
`*/.claude/projects/*/memory/*|*/.gemini/antigravity-cli/brain/*)`. That names
the concurrent **antigravity** work also present uncommitted in this tree
(`agents/antigravity/`, `plugins/antigravity/`, `lib/antigravity_bridge.py`,
`lib/antigravity_steps.py`). The conclusion is that antigravity's changes were
applied to an **older base** of this hook and the result written over HEAD's
version, rather than applied onto HEAD.

**How it surfaced — and the part that matters.** Nothing detected it. It became
visible only because `fw vendor self` propagated the regressed source into
`.agentic-framework/`, and the pre-push self-vendor gate then refused a push to
master. That gate answers "does vendored match source?", not "did source
regress?" — so the detection was **incidental**. Had the vendored copy not been
touched, the regression would have shipped at the next commit of that file with
no signal at all.

- [x] AC1 — The working-tree state is preserved before any merge: a patch of
      working-vs-HEAD and a verbatim copy of the 840-line file are committed under
      `docs/reports/T-3133/`, so the in-flight antigravity work cannot be lost by
      the restore.
- [x] AC2 — `agents/context/check-active-task.sh` contains T-3038's
      `_resolve_focus_file` helper and both of its call sites again. Verified by
      grep, not by line count.
- [x] AC3 — The T-2987 explain-block is present again. Verified by grep for its
      anchor comment.
- [x] AC4 — The antigravity path case is **still present** after the restore.
      This is the anti-AC: the fix must not resolve the regression by deleting the
      concurrent work that caused it.
- [x] AC5 — Source and vendored copy agree: `fw vendor self --check` reports in
      sync, and the vendored file satisfies the same greps as AC2-AC4.
- [x] AC6 — The hook still parses and runs: `bash -n` clean, and it correctly
      blocks a Write with no active task (exercised, not assumed).
- [x] AC7 — A detection gap is registered in `concerns.yaml`. The self-vendor gate
      found this by accident; nothing asks "did a committed governance file lose
      committed behaviour without a commit?" State the distinction explicitly:
      AC2-AC6 are mitigation, AC7 is prevention (G-019).

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

# AC2 — T-3038's focus resolver is back (definition + both call sites).
test "$(grep -c '_resolve_focus_file' agents/context/check-active-task.sh)" = 3
! grep -qE '^FOCUS_FILE="\$PROJECT_ROOT/\.context/working/focus\.yaml"$' agents/context/check-active-task.sh

# AC3 — T-2987's explain-block is back.
grep -q 'T-2987: explain WHY the advertised remedy' agents/context/check-active-task.sh

# AC4 (anti-AC) — the concurrent antigravity case survived the restore.
grep -q 'gemini/antigravity-cli/brain' agents/context/check-active-task.sh

# T-3050's richer B-005 message is back too (it had also reverted).
grep -q 'Cannot hand-edit .claude/settings.json' agents/context/check-active-task.sh

# AC5 — source and vendored copy agree, and the vendored copy carries all three.
bin/fw vendor self --check > /tmp/.t3133vs 2>&1 && grep -q 'in sync' /tmp/.t3133vs
grep -q '_resolve_focus_file' .agentic-framework/agents/context/check-active-task.sh
grep -q 'gemini/antigravity-cli/brain' .agentic-framework/agents/context/check-active-task.sh

# AC6 — the hook parses.
bash -n agents/context/check-active-task.sh

# AC1 — the in-flight state is preserved, not discarded.
test -s docs/reports/T-3133/working-vs-HEAD.patch
test -s docs/reports/T-3133/check-active-task.sh.working-1000

# AC7 — the detection gap is registered AND visible in the CLI surface.
grep -q 'id: G-085' .context/project/concerns.yaml
bin/fw gaps > /tmp/.t3133gaps 2>&1 && grep -q 'G-085' /tmp/.t3133gaps

## RCA

**Symptom:** the live PreToolUse gate `agents/context/check-active-task.sh` was
840 lines in the working tree against 1012 at HEAD, uncommitted, having been
clean 37 minutes earlier. Session-scoped focus resolution (T-3038), the
explain-why-the-remedy-did-not-apply block (T-2987) and the richer B-005 message
(T-3050) were all absent from the running hook.

**Root cause:** concurrent antigravity work applied its one-line change — an
extra alternative on the auto-memory `case` pattern, adding
`*/.gemini/antigravity-cli/brain/*` — to an **older base** of the file and wrote
the whole result over HEAD's version. The net effect was a re-derivation, not an
edit: the working content matches no commit in the last 25 touching that file,
so it was neither a checkout nor a revert, but a stale copy plus a new line.

**Why structurally allowed:** every existing check reads either *committed*
state (audit, invariant suite, blast radius, map conformance) or *vendor parity*
(`fw vendor self --check`). Nothing reads the **uncommitted delta of a governed
file** and asks whether it removes behaviour a completed task put there. The
asymmetry is what hides it: adding a line to a `case` pattern is a normal,
welcome edit, and losing 186 lines of committed governance in the same write is
catastrophic — and `git status` renders both as a single ` M`.

Detection here was **incidental**. It surfaced only because `fw vendor self`
propagated the regressed source into `.agentic-framework/`, and the pre-push
self-vendor gate then refused the master push. That gate answers "does vendored
match source?", not "did source regress?" — a different question that happened
to trip over this one. Had the vendored copy not been touched, the tree would
have been committed at the next opportunity and three tasks' worth of governance
would have shipped silently, consumers included.

**Prevention:** G-085 (severity high, `watching`), distinct from the fix. The
fix is the merge in AC2-AC6; the prevention is a check that asks the question
nobody asks. Candidate shapes are recorded on the gap, cheapest first; the one
that would have named T-3038 and T-2987 *by id* is grepping the uncommitted delta
for removed lines carrying a completed task id, which is dense in these files.

**Two false passes on the way, worth recording.** Exercising AC6's block path
returned exit 0 twice before it returned 2 — the harness ran the hook from a
synthetic project directory, but `PROJECT_ROOT` derives from the script's own
location, so the hook read the *real* repo's focus and allowed correctly. A
harness that cannot reach its subject reported the same thing as a subject that
passed. It only became a real test once `cwd` was passed in the stdin JSON, which
is what the hook actually re-anchors from. Same family as T-3125/T-3126/T-3128/
T-3129 and L-575 — the reason this session keeps checking whether a green means
"measured, fine" or "never ran".

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

### 2026-08-25T08:04:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3133-concurrent-antigravity-work-reverted-che.md
- **Context:** Initial task creation
