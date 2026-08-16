---
id: T-2927
name: "handover lists 1 of 112 pending observations — T-2514 regex fix never swept
  its sibling sites"
description: >
  handover lists 1 of 112 pending observations — T-2514 regex fix never swept its
  sibling sites

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/handover/handover.sh, 
      tests/integration/t2922_greenfield_first_inception.bats, 
      tests/unit/t2927_observation_inbox_listing.bats]
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
created: 2026-08-11T22:19:54Z
last_update: '2026-08-16T22:25:23Z'
date_finished: 2026-08-11T23:00:19Z
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
  - ts: '2026-08-11T22:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-11T22:30:13Z'
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

# T-2927: handover lists 1 of 112 pending observations — T-2514 regex fix never swept its sibling sites

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Reproduced first against the live inbox: a leg asserts the CURRENT split lists 1 of 112 pending observations, so the defect is measured before it is repaired rather than inferred from reading the regex
- [x] Both sites in `agents/handover/handover.sh` (the `## Observation Inbox` listing at ~931 and the URGENT_OBS count at ~386) list every pending observation the inbox actually holds
- [x] An **enumerating guard** (L-533) fails on any *new* site that splits an inbox/observation file on the 2-space indent — a predicate over shape with no maintained allowlist of known-good sites, so an N+1th site cannot survive the way these two did
- [x] The guard distinguishes an INSTANCE from a MENTION: `agents/audit/audit.sh` carries the defective pattern inside a comment explaining it, and a guard that flags its own documentation is a guard nobody keeps
- [x] `lib/harvest.sh` is verified correct rather than assumed: a leg asserts patterns.yaml genuinely uses the 2-space form, so the sweep does not "fix" a site that was never broken
- [x] Mismatch check (the half that matters, 832 §2): when the listing emits fewer entries than the count it just printed, the handover says so in the document — a section reading "112 pending" above a list of 1 must not look complete
- [x] The end-to-end leg drives the real producer (`agents/handover/handover.sh`) against a fixture inbox, not a re-typed copy of its extraction logic — L-533's second compounding cause was a test that could only ever check sites its author already knew about

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

# 13 legs. Leg 1 reproduces against the live inbox before the repair; legs 9-10
# are the guard's own anti-vacuity (it must flag the pre-fix bytes from git, and
# must NOT flag the audit.sh comment that documents the defect).
bats tests/unit/t2927_observation_inbox_listing.bats

# The two repaired sites, asserted directly rather than only via the suite.
out=$(grep -nE "re[.]split[(]r'..n  - '" agents/handover/handover.sh | grep -vE '^[0-9]+:[[:space:]]*#' || true); [ -z "$out" ]

# The urgent count reads parsed YAML. Measured before repair: 1 against a true 3.
n=$(VALIDATE_FILE=.context/inbox.yaml python3 -c "import os,yaml; d=yaml.safe_load(open(os.environ['VALIDATE_FILE'])) or {}; print(sum(1 for o in (d.get('observations') or []) if isinstance(o,dict) and o.get('status')=='pending' and o.get('urgent') is True))"); [ "$n" -ge 3 ]

# handover.sh is vendored — the consumer copy must carry the fix too.
bin/fw vendor self --check

## RCA

**Symptom:** The handover's `## Observation Inbox` section rendered "112 pending"
above a listing that showed exactly one row, and the URGENT_OBS count (used to
gate the "run `fw note triage` first" escalation) returned 1 against a true 3
urgent-and-pending entries in `.context/inbox.yaml`.

**Root cause:** Both sites in `agents/handover/handover.sh` extracted
observations with a text split on a hard-coded 2-space-indent regex
(`re.split(r'\n  - '...)`), an idiom copied from `agents/audit/audit.sh` at the
time T-2514 fixed audit.sh's own copy. Any observation entry whose YAML
serialised with a different indent, quoting, or line-wrap silently dropped out
of the split with no error — the two sites were never re-derived from the
actual YAML shape after audit.sh's copy was fixed.

**Why structurally allowed:** L-533 ("when you fix N instances of a class in
one file, ask what would fail if there were an N+1th") was already written
after T-2514 but was advisory prose, not a running check — nothing swept
`agents/handover/handover.sh` for the same idiom. The listing block also had no
mismatch check: a count line and a listing block are two independent pieces of
output with no assertion tying them together, so a listing that silently
truncated still rendered as complete-looking, well-formed markdown.

**Prevention:** (1) Both sites now parse `yaml.safe_load` instead of splitting
text, eliminating the indent-fragility class outright. (2) A new enumerating
guard (leg 8, `tests/unit/t2927_observation_inbox_listing.bats`) fails on any
source file that contains the `re.split(r'\n  - '...)` idiom outside a comment
— a predicate over shape, not a maintained allowlist, so a future N+1th site
cannot silently survive the way these two did (legs 9-10 pin that the guard
fires on reconstructed defective bytes and does not fire on the comment in
`audit.sh` that documents the defect). (3) A mismatch check now makes the
listing say so in the rendered document whenever it emits fewer rows than the
count it just printed, closing the "renders complete with payload silently
absent" failure mode 832 flagged independently in their own inbox.

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

**Parse the YAML rather than fix the regex.** The reported defect is one wrong
indent and a one-character repair would have worked. It would also have left the
next reader guessing an indentation convention from memory — which is the
mistake, not the indent. `yaml.safe_load` removes the guess.

**The mismatch line is the more durable half, and it is 832's point.** Their §2:
a listing block that emits nothing under a non-zero count should say so, because
otherwise "fix the regex and this class is invisible again at the next
instance". The regex is one bug; the section that renders well-formed and
complete-looking with its payload absent is why it survived months.

**Two things are worse here than in the reporting tree.** 832 measured 0 of 24
listed and reported site 386 as latent (their inbox holds no `urgent: true`
entries). Ours listed 1 of 112 — a single well-formed row under a "112 pending"
heading reads as a section that worked, where a zero could read as "nothing to
show" — and site 386 was actively miscounting, returning 1 against a true 3, so
the "run `fw note triage` BEFORE starting new work" escalation was firing on a
third of its evidence.

**Scope of the end-to-end leg (AC7).** The legs execute the SHIPPED bytes of the
listing block, extracted from `agents/handover/handover.sh` between its heredoc
markers, so an edit to that block is an edit to what the test runs. They do not
drive `handover.sh` wholesale: a full run does git work (the `--checkpoint` path
attempts a push) and pointing it at a fixture risks touching this repo's remote.
NOT covered: the surrounding shell — the `PENDING_OBS` grep and the
`if [ "$PENDING_OBS" -gt 0 ]` guard deciding whether the section renders at all.
Three lines with no observation-format knowledge in them, which is why the
residue is stated rather than closed.

**L-533 was already written and did not prevent this.** It says: when you fix N
instances of a class in one file, ask what would fail if there were an N+1th,
and prescribes a source-derived predicate with no maintained allowlist. T-2514
fixed audit.sh; these two sites survived. The learning existed and described the
failure exactly — what was missing was a guard that runs. Leg 8 is that guard
for this idiom; legs 9-10 keep it honest.

**The T-2922 suite leaked a task into this repo while this task was open.** Its
`setup_file` exported FRAMEWORK_ROOT without pinning PROJECT_ROOT, so
`fw inception start` allocated from this repo's sequence and filed a real
T-2928. All nine legs passed regardless — the leak was invisible to every
assertion. Removed (untracked, three minutes old), PROJECT_ROOT pinned, and a
containment assertion added that refuses to run the legs if anything lands
outside the fixture. Recorded here rather than only in T-2922 because the class
is this task's: a check that cannot report what it did not look at.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-11T22:19:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2927-handover-lists-1-of-112-pending-observat.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3d4adb62
- **Timestamp:** 2026-08-11T23:00:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/t2927_observation_inbox_listing.bats`

### 2026-08-11T23:00:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
