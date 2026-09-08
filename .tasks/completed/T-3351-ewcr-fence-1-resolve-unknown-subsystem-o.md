---
id: T-3351
name: "EWCR fence-1: resolve Unknown subsystem on the 3 CORE + 17 agents/ write-set
  Fabric cards"
description: >
  From T-3147 measurement: 3 CORE write-set cards (agents/dispatch/single-host-parallel-demo.sh,
  agents/dispatch/yield-point.sh, policy/standards/aef-bpmn-mapping-v1-partI.md) plus
  17 agents/ BROAD write-set cards carry subsystem Unknown. Classify each into its
  real subsystem so fence-1's Unknown-count clause can reach 0. Framework Fabric hygiene
  — needs no D1 ruling. Evidence: docs/research/executable-workflow/arc0-falsifier1-result.md

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:ewcr-arc0-contract-evidence, ewcr-v1]
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
created: 2026-09-08T19:56:50Z
last_update: 2026-09-08T20:14:38Z
date_finished: 2026-09-08T20:14:38Z
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
  - ts: '2026-09-08T20:00:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=275,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-08T20:00:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-09-08T20:08:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3351: EWCR fence-1: resolve Unknown subsystem on the 3 CORE + 17 agents/ write-set Fabric cards

## Context

EWCR fence-1 hygiene (from T-3147 measurement, evidence: docs/research/executable-workflow/arc0-falsifier1-result.md): classify the Unknown-subsystem Fabric cards that intersect the runtime write set so the fence's Unknown-count clause can reach 0. Live re-derivation found 23 cards in scope: 3 CORE (2× agents/dispatch + the policy/standards BPMN mapping doc), 1 BROAD-only (agents/designer/designer.sh), and 19 further agents/-rooted Unknown cards (the T-3147 "17 agents/ (BROAD)" cohort, grown to 22 total agents/-rooted by measurement drift). All 23 re-classified into existing taxonomy values (framework-core, governance, watchtower, audit, testing, termlink-integration) with real purposes replacing the TODO placeholders.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The 3 CORE write-set cards (agents/dispatch/single-host-parallel-demo.sh, agents/dispatch/yield-point.sh, policy/standards/aef-bpmn-mapping-v1-partI.md) carry a real (non-Unknown) subsystem chosen from the existing subsystem taxonomy in `bin/fw fabric overview`
- [x] Every agents/-rooted Fabric card that `python3 tools/ewcr-arc0-unknown-overlap.py` counted as Unknown in the BROAD write set is re-classified to a real subsystem (17 cards at T-3147 measurement time; re-derive the live list, do not trust the count)
- [x] Re-running `python3 tools/ewcr-arc0-unknown-overlap.py` reports intersection 0 for both CORE and BROAD write sets, and the run's summary is recorded in the task Updates or a docs/research/executable-workflow/ artefact (never editing prior blocks)
- [x] Only .fabric/components/ card YAMLs and documentation are modified — no file under lib/, bin/, agents/, web/ or tests/ changes

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
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

# Invariant: overlap tool reports intersection 0 for both write sets (redirect-then-grep; pins the 0 target, not a live Unknown count)
python3 tools/ewcr-arc0-unknown-overlap.py > /tmp/.t3351-overlap.out 2>&1 && grep -qE "Intersection with CORE write set *: 0 " /tmp/.t3351-overlap.out && grep -qE "Intersection with BROAD write set *: 0 " /tmp/.t3351-overlap.out

# Invariant: none of the 3 CORE write-set cards carries subsystem unknown
! grep -q "^subsystem: unknown" .fabric/components/agents-dispatch-single-host-parallel-demo.yaml .fabric/components/agents-dispatch-yield-point.yaml .fabric/components/policy-standards-aef-bpmn-mapping-v1-partI.yaml

# Invariant: zero agents/-rooted Fabric cards remain Unknown (property holds, no live count pinned); also re-parses every card YAML
python3 -c "import glob,yaml,sys; bad=[f for f in glob.glob('.fabric/components/*.yaml') if (lambda d: isinstance(d,dict) and str(d.get('subsystem') or 'unknown').strip().lower()=='unknown' and str(d.get('location') or '').lstrip('./').startswith('agents/'))(yaml.safe_load(open(f)))]; sys.exit(1 if bad else 0)"

# Invariant: every reclassified card carries a real purpose (no TODO placeholder left in the 23-card scope)
! grep -l "TODO: describe what this component does" .fabric/components/agents-antigravity-subagent_dispatch.yaml .fabric/components/agents-bpmn-bpmn.yaml .fabric/components/agents-designer-designer.yaml .fabric/components/agents-dispatch-single-host-parallel-demo.yaml .fabric/components/agents-dispatch-yield-point.yaml .fabric/components/policy-standards-aef-bpmn-mapping-v1-partI.yaml

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

### 2026-09-08 — live scope diverged from the filed counts, in both directions
- **What changed:** The filed scope said "3 CORE + 17 agents/ BROAD". Live re-derivation (per the AC's own instruction) found: (a) the tool's literal BROAD intersection is only 4 cards (3 CORE + agents/designer/designer.sh) because the tool's BROAD prefixes cover just 5 agents/ subtrees; (b) the T-3147 evidence table's "17 agents/ (BROAD)" row actually meant *all* agents/-rooted Unknown cards from the coverage script, and that cohort had grown to 22 by today. Also, no "dispatch" subsystem exists in the live taxonomy — dispatch-substrate lib files (lib/resolver.py, lib/dispatch.sh, lib/write_set.py …) are uniformly `framework-core`, so the agents/dispatch/ and agents/orchestrator/ cards were classified there for cluster coherence rather than into a new value.
- **Plan impact:** Scope widened from ~20 to 23 cards (all 22 agents/-rooted Unknowns + the policy/standards CORE doc) so both readings of the AC are satisfied and the fence result is robust to either interpretation. No new subsystem value was invented.
- **Triggered:** Nothing filed — widening stayed inside this task's fence (card YAMLs only).

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

### 2026-09-08T19:56:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3351-ewcr-fence-1-resolve-unknown-subsystem-o.md
- **Context:** Initial task creation

### 2026-09-08T19:57:24Z — status-update [task-update-agent]
- **Change:** tags: +arc:ewcr-arc0-contract-evidence

### 2026-09-08T19:57:25Z — status-update [task-update-agent]
- **Change:** tags: +ewcr-v1

### 2026-09-08T20:08:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-08 — fence-1 reclassification complete [T-3351 worker]
- **Action:** Re-classified 23 Unknown Fabric cards (22 agents/-rooted + policy/standards/aef-bpmn-mapping-v1-partI.md) into existing taxonomy values and replaced TODO purposes with real one-liners. Assignments: framework-core ×15 (dispatch/orchestrator/mcp/sessions/bvp-estimator/antigravity/gpu-recover clusters — matching lib/resolver.py, lib/dispatch.sh etc.), governance ×2 (bpmn.sh + the BPMN mapping doc, joining its .provenance sibling), watchtower ×2 (designer.sh, ux-review.py), audit ×2 (agents/monitor/*), termlink-integration ×2 (termlink.sh, api-usage.sh), testing ×1 (docgen test). Three .md cards' `type: script` corrected to `document`, docgen test to `test`.
- **Output:** `python3 tools/ewcr-arc0-unknown-overlap.py` post-run summary: cards enumerated 1231; Unknown 556 → 533; **Intersection with CORE write set: 0 (was 3); Intersection with BROAD write set: 0 (was 4)**; all §5.1 row breakdowns 0; `agents` no longer appears in the Unknown-roots table. Machine-readable result at .context/audits/ewcr-arc0-unknown-overlap.json.
- **Context:** Only .fabric/components/*.yaml files modified (plus this task file and the tool's own audit JSON output) — nothing under lib/, bin/, agents/, web/, tests/.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c759fa0a
- **Timestamp:** 2026-09-08T20:14:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — The 3 CORE write-set cards (agents/dispatch/single-host-parallel-demo.sh, agents/dispatch/yield-point.sh, policy/standards/aef-bpmn-mapping-v1-partI.md) carry a real (non-Unknown) subsystem chosen fro
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/dispatch/single-host-parallel-demo.sh in: The 3 CORE write-set cards (agents/dispatch/single-host-parallel-demo.sh, agents/dispatch/yield-point.sh, policy/standards/aef-bpmn-mapping-v1-partI.m`

### 2026-09-08T20:14:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
