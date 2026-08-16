---
id: T-2928
name: "fw note dismiss --reason is parsed, echoed and discarded — the register cannot
  tell judged from swept"
description: >
  fw note dismiss --reason is parsed, echoed and discarded — the register cannot tell
  judged from swept

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/handover/handover.sh, agents/observe/observe.sh, 
      tests/integration/t2922_greenfield_first_inception.bats, 
      tests/unit/t2927_observation_inbox_listing.bats, 
      tests/unit/t2928_note_dismiss_persists_reason.bats]
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
created: 2026-08-11T22:35:00Z
last_update: '2026-08-16T22:25:23Z'
date_finished: 2026-08-11T23:02:05Z
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
  - ts: '2026-08-11T22:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-11T22:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2928: fw note dismiss --reason is parsed, echoed and discarded — the register cannot tell judged from swept

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Reproduced first: a leg drives `fw note dismiss OBS-NNN --reason "..."` against a fixture inbox and asserts that, BEFORE the fix, the reason appears in stdout and NOT in the file — the flag's own success message is the thing that has to be shown lying
- [x] `fw note dismiss --reason "..."` persists the reason onto the observation, alongside a dismissal timestamp, so a later reader can tell a judged dismissal from a swept one
- [x] The dismissal survives a YAML round-trip: a leg parses the inbox after dismissal and reads the reason back as structured data, not by grepping the line it just wrote
- [x] Omitting `--reason` still works and records the default, so the flag stays optional and no existing caller breaks
- [x] Reasons containing quotes, colons and newlines round-trip intact — the write path must not be a `sed` substitution that a `:` in the reason can corrupt
- [x] Existing reason-less dismissals are not silently backfilled with a fabricated reason: they stay distinguishable from newly-reasoned ones, because inventing a rationale for a past decision is worse than recording that none was captured

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

# 10 legs. Leg 1 reconstructs the pre-fix sed write and shows the reason has
# nowhere to land; legs 7-9 pin refuse-rather-than-half-write.
bats tests/unit/t2928_note_dismiss_persists_reason.bats

# The write path is python, not sed — a `:` or a quote in operator free text
# corrupts a sed substitution.
grep -q 'dismissed_reason' agents/observe/observe.sh
out=$(sed -n '/^do_dismiss()/,/^}/p' agents/observe/observe.sh); echo "$out" | grep -q 'json.dumps'
out=$(sed -n '/^do_dismiss()/,/^}/p' agents/observe/observe.sh); ! echo "$out" | grep -q '_sed_i'

bash -n agents/observe/observe.sh
bin/fw vendor self --check

## RCA

**Symptom:** `fw note dismiss OBS-NNN --reason "..."` exits 0 and prints
`OBS-NNN dismissed: <reason>`. The inbox receives `status: dismissed` and
nothing else. 81 dismissed observations here carry no reason; 832 measured
26/26 in their tree.

**Root cause:** `do_dismiss` parsed `--reason` into a local variable and
referenced it in exactly one place — the confirmation `echo`. The write was a
single `_sed_i` substitution of `status: pending` → `status: dismissed`. The
flag was fully wired to the terminal and never wired to the file.

**Why structurally allowed:** nothing compares what a command SAYS it did with
what it wrote. The success message is generated from the parsed arguments, not
read back from the artefact, so it reports the operator's intent rather than the
outcome — and the two are indistinguishable at the point of reading. This is the
family 832 named across four findings in one triage: *the command succeeds, the
output is well-formed, and the file does not get what the operator was told it
got.* No test covered `note dismiss` at all, and a test that grepped for the
confirmation line would have passed.

The register's own design hid it further. A dismissed-with-reason row and a
dismissed-without-reason row render identically in `fw note list`, so the
missing field is invisible at every surface an operator would check. 832 found
it only by auditing their own dispositions against the file after writing 20 of
them — and it falsified a claim a previous session of theirs had put in writing.

**Prevention:** the reason is now persisted and read back as structured YAML by
the test (leg 4), not grepped from the line just written — so a future
regression that writes a malformed document fails rather than passes. Legs 7-9
pin the inverse property that made this survivable: the command must refuse and
leave the file byte-identical rather than half-write. The residual class —
success messages composed from intent rather than from the artefact — is wider
than this command and is reported back to 832 rather than claimed as closed
here.

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

## Decisions

**Persist rather than refuse the flag.** 832 offered both shapes: store the
reason, or reject a flag that cannot be stored. Storing wins — the triage ritual
is built around the reason, `fw note triage` advertises it, and the register's
whole value is answering "was this judged or swept?" months later. Refusing the
flag would have been honest and would have left that question permanently
unanswerable.

**Python, not sed, for the write.** The reason is operator free text. The old
`_sed_i` substitution mangles a `:`, truncates on quotes, and cannot represent a
newline at all. `json.dumps` emits a double-quoted scalar that is valid YAML for
all three, and only the target entry's lines are rewritten, so the rest of the
221-entry file stays byte-identical. Leg 5 drives all three hostile characters
through the real script.

**History is not backfilled.** 81 dismissed observations here carry no reason
(832: 26). They stay that way. A fabricated rationale is indistinguishable from
a captured one, so backfilling would destroy exactly the signal this task
restores. Leg 10 pins it.

**The test harness reached the real inbox before it was fixed, and that is the
finding worth keeping.** The first helper set `PROJECT_ROOT` and invoked the
`fw` wrapper — which resolves the project from the WORKING DIRECTORY and ignores
the variable. Every write leg therefore addressed this repo's live inbox.
Nothing was corrupted, but only because the target id was already dismissed
there and the refusal path declined to write. That is luck, not containment.
The helper now drives `agents/observe/observe.sh` directly, which does honour
PROJECT_ROOT. Second instance this session of a test escaping its fixture (the
T-2922 suite filed a real task under T-2927), and in both cases every leg
passed while it happened.

**Not in scope.** `fw note promote` puts the entire observation body in the
task's `name` field (832 §4; confirmed here at `agents/observe/observe.sh:251`,
`--name "$text"`). Real bug, separate cause, separate fix — filed on its own
rather than folded in, per one-bug-one-task.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-11T22:35:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2928-fw-note-dismiss---reason-is-parsed-echoe.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0eda32de
- **Timestamp:** 2026-08-11T23:02:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 9
     - evidence: `out=$(sed -n '/^do_dismiss()/,/^}/p' agents/observe/observe.sh); ! echo "$out" | grep -q '_sed_i'`

### 2026-08-11T23:02:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
