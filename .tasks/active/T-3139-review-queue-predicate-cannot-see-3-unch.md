---
id: T-3139
name: "review queue predicate cannot see 3 unchecked Human ACs that exist"
description: >
  review queue predicate cannot see 3 unchecked Human ACs that exist

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
created: 2026-08-25T09:37:37Z
last_update: '2026-08-25T09:45:13Z'
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
  - ts: '2026-08-25T09:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=230,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T09:45:13Z'
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

# T-3139: review queue predicate cannot see 3 unchecked Human ACs that exist

## Context

`web/shared.py:count_unchecked_human_acs` is the single predicate behind BOTH
`/approvals` and `fw review-queue`. Three live active tasks carried an unchecked
`[REVIEW]` AC that it returned 0 for, so the operator was never asked about any
of them.

The failure has no red state. An empty queue is also what a healthy queue looks
like, so a predicate that under-reports is indistinguishable from a day with
nothing to review — the same false-green shape as T-3134, on a surface whose
normal condition is "nothing".

Found by acting on 832-Workflow-designer's chat-arc report of the identical
defect in their tree (their T-344 / T-402, found when the operator complained
the page was empty). Independently reproduced here rather than taken on trust.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — `count_unchecked_human_acs` sees an unchecked AC under a SECOND
      `### Human` heading. Today it uses `re.search`, so only the first block is
      scanned. Live victim: T-1808, which has `### Human` at both line 93 and
      line 108; the queue reports 0.
- [x] AC2 — It sees an unchecked AC when a `## ` heading sits between
      `## Acceptance Criteria` and `### Human`. Today the AC block is bounded by
      `(?=^## )`, so any intervening heading truncates it and everything after is
      outside. Live victims: T-2200 and T-2202, both carrying
      `## Status: COMPLETED 2026-06-09` between the two.
- [x] AC3 — A `### Human` heading inside an HTML comment cannot shadow a real
      one. Comments are stripped BEFORE the heading search, not after — today the
      strip runs on the matched block, so a commented heading can win the search
      and hide the real block behind it. Measure whether this is live in the
      corpus; report the count either way.
- [x] AC4 — Both surfaces move together. `/approvals` and `fw review-queue` call
      this one predicate, so the fix reaches both — assert it on both rather than
      assuming, since consolidation is what removed the disagreement that would
      otherwise have been the visible symptom (832's finding).
- [x] AC5 — No task GAINS a spurious entry. Measured over the full corpus
      (active + completed): report how many tasks the predicate newly counts and
      how many it counts fewer of, and account for every one. A queue that grows
      by a hundred tasks is a different defect, not a fix.
- [x] AC6 — The control fails against pre-change code. Fixtures only (L-599); the
      three live task ids above are the origin record and appear in no assertion,
      since fixing the predicate is expected to change them. Report "N of M fail
      against pre-change" and name regression guards separately.
- [x] AC7 — A census, not just a fix. A test asserts the two populations agree:
      what the queue surfaces vs what a heading-independent scan finds. This is
      the part that survives the next regression — the fix repairs today's three,
      the census notices tomorrow's.

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

python3 -m pytest tests/unit/test_human_ac_visibility.py -q > /tmp/.t3139 2>&1 && grep -q '14 passed' /tmp/.t3139
! grep -q 'failed' /tmp/.t3139

# The three shapes, asserted on the predicate directly rather than via the suite
python3 -c "import sys; sys.path.insert(0,'.'); from web.shared import count_unchecked_human_acs as c; assert c('## Acceptance Criteria\n\n### Human\n- [x] a\n\n### Human\n- [ ] b\n') == 1"
python3 -c "import sys; sys.path.insert(0,'.'); from web.shared import count_unchecked_human_acs as c; assert c('## Acceptance Criteria\n\n## Status: X\n\n### Human\n- [ ] a\n') == 1"
python3 -c 'import sys; sys.path.insert(0,"."); from web.shared import count_unchecked_human_acs as c; assert c("prose quoting <!-- inline\n### Human\n- [ ] a\n") == 1'

# AC4 — both surfaces, not just the one that was easy to check
bin/fw review-queue > /tmp/.t3139q 2>&1 && grep -q 'T-2200' /tmp/.t3139q && grep -q 'T-2202' /tmp/.t3139q
curl -sf "$(bin/fw watchtower url)/approvals" -o /tmp/.t3139a && grep -q 'T-2200' /tmp/.t3139a && grep -q 'T-2202' /tmp/.t3139a

# The helper the fix hangs on must stay
grep -q '_strip_html_comments' web/shared.py

## RCA

**Symptom:** four tasks carried an unchecked `### Human` AC and appeared in
neither `/approvals` nor `fw review-queue`. Three are active; the operator has
never been shown them. Ages: T-1808, T-2200, T-2202 all filed months ago.

**Root cause:** one predicate, three independent blind spots.

1. `re.search` for `^### Human` — first block only. T-1808 has two.
2. The scope was the `## Acceptance Criteria` block, bounded by `(?=^## )`. Any
   heading between the two truncates it: `## Status: COMPLETED` (T-2200, T-2202)
   and `## Measured Behaviour` (T-2877) all sit exactly there.
3. HTML comments were stripped AFTER the block was chosen, so a commented
   heading could win the search — and the naive `re.sub(r"<!--.*?-->")` mispairs
   on this corpus, because task bodies quote `<!--` inside backticks when they
   discuss the template. T-1545 carries four openers and two closers.

**Why structurally allowed:** the observable of the failure is an empty queue,
and an empty queue is also the observable of health. There is no red state and
nothing ever prompts anyone to count.

The second enabler is worth stating plainly, because it inverts a good practice:
the predicate was CENTRALISED (T-2075) specifically so `/approvals` and the CLI
could not drift apart, and it worked — both surfaces agreed, and on these files
both were wrong together. Consolidation buys consistency and SPENDS the
cross-check. Worth pricing before the next shared predicate. (Credit:
832-Workflow-designer, who reached this from their own instance.)

**Prevention** (distinct from the fix): `test_census_both_scans_agree_across_the_live_corpus`
compares the shipped predicate against a deliberately different line-oriented
scan across all 3126 task files and fails on any disagreement. The fix repairs
today's four; the census is what notices tomorrow's. It earned its keep during
this task — its first run disagreed on two files and the REFERENCE was the wrong
one, which is the outcome a census that nobody has actually run never produces.

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

### 2026-08-25 — count every `### Human` block anywhere, not the one inside `## Acceptance Criteria`
- **Chose:** drop the AC-block scoping entirely; find every `^### Human` in the
  body, each bounded by the next level-1..3 heading.
- **Why:** `### Human` has exactly one meaning in the task schema. Scoping it to
  a parent heading buys nothing and costs everything the moment a task grows a
  section — which three of them did, in the ordinary course of being worked on.
- **Rejected:** widening the AC block's terminator to skip known headings
  (`## Status`, `## Measured Behaviour`). That is a list that has to be
  maintained against task bodies nobody controls, and it fails silently.
- **Measured:** active +3/−0, completed +1/−2 across 3126 files. The two
  decrements are template placeholder ACs inside comments that the old predicate
  wrongly counted — a correction, not a loss.

### 2026-08-25 — a comment opener is recognised by POSITION, not by balance
- **Chose:** `<!--` opens a comment only if it starts its line, or closes on the
  same line. Anything else is prose about a comment.
- **Why:** counting openers against closers cannot work here — T-1545 has four
  and two, because the task discusses `grep -v '^<!--'` inside backticks. The
  naive regex pairs the third opener with the second closer and eats 3.9KB
  including a real AC.
- **Also:** a removed span that contained a newline leaves one behind. Without
  that the preceding text is joined onto the following line, so a `### Human`
  heading stops being at column 0 and every anchor misses it. This defect was
  introduced and caught inside this task — the corpus sweep showed a task losing
  its AC, which is the failure being fixed, reproduced by the fix.
- **Rejected:** bounding every comment at the next heading. Simpler, but it
  truncates well-formed comments that legitimately contain a column-0 `#` line —
  and the shipped task template contains exactly one (`## Verification`, inside
  the Human-AC comment; the same line that caused T-3134).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-25T09:37:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3139-review-queue-predicate-cannot-see-3-unch.md
- **Context:** Initial task creation
