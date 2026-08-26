---
id: T-3147
name: "EWCR Arc 0 evidence baseline: measure Fabric Unknown-subsystem overlap with
  the runtime write set"
description: >
  Measurement-only evidence baseline for Arc 0 of the Executable Workflow Contract
  Runtime (initiative ewcr-v1, correlation ewcr-v1-aef-arc0). Falsifier 1 of docs/research/executable-workflow/questions-and-dispositions.md
  6: determine whether the 512 Unknown-subsystem Component Fabric entries intersect
  the runtime write set. Produces the measured number that sizes roadmap 6 fence 1
  and feeds human decision D5 (Q-03 coverage threshold). No runtime code, no schema
  freeze, no implementation.

status: captured
workflow_type: design
owner: agent
horizon: now
tags: [ewcr-v1, ewcr-v1-aef-arc0, evidence-baseline, measurement, arc:ewcr-arc0-contract-evidence]
components: []
related_tasks: [T-3145]
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
created: 2026-08-25T22:12:39Z
last_update: 2026-08-25T22:17:26Z
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
  - ts: '2026-08-25T22:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:design); effort=8 (lines=287,acs=11)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T22:15:14Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3147: EWCR Arc 0 evidence baseline: measure Fabric Unknown-subsystem overlap with the runtime write set

## Context

Smallest local evidence-baseline unit for **Arc 0 — contract evidence and
implementation baseline** of the Executable Workflow Contract Runtime.

- **Initiative:** `ewcr-v1`
- **Correlation:** `ewcr-v1-aef-arc0`
- **Upstream packet:** ingested under T-3145, manifest v1 rev 0
  (`docs/research/executable-workflow/source-manifest.yaml`)
  - architecture dossier — sha256 `c9070637b09493a24abc99982ae966a3b3ae8cd4a358a44fdceb59bdceb6ac2d`
  - delivery roadmap — sha256 `5be23719b976e37a6461b4b1f6f309985b5ba033ef0b801769edd2627fbae5b8`
- **Why this task and not the roadmap's candidate task 1:** the roadmap asks to
  "register/enrich the Component Fabric baseline". `questions-and-dispositions.md`
  §2 revised that to the runtime write set only, and §6 falsifier 1 says the whole
  item "shrinks to near-zero" if the `Unknown`-subsystem components turn out not to
  intersect that write set. Nobody has measured whether they do. This task is that
  measurement and nothing else — it decides how large Arc 0's first real task is.
- **Feeds:** roadmap §6 fence 1 (Fabric non-empty, enriched, validated) and human
  decision **D5** (Q-03 — Fabric coverage threshold and limited-mode policy).
- **Out of scope, explicitly:** no runtime code, no schema freeze, no refusal
  matrix, no Fabric enrichment, no arc start, no BVP confirmation. This task
  produces a number and a written disposition; it does not act on either.

The parent arc could not be created in this session — see `## Decisions`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] The runtime write set is **derived, not assumed**: the set of AEF paths the
      EWCR runtime would write is enumerated from the architecture dossier
      (`architecture-c9070637.md`) with a section reference per path, and written to
      `docs/research/executable-workflow/arc0-write-set.md`
- [ ] The `Unknown`-subsystem Component Fabric population is counted from
      `.fabric/components/` at a named commit — the count is re-derived in this
      task, not carried over from the 512/1117 figure recorded in T-3145
- [ ] The **intersection** of those two sets is computed and reported as a count
      plus the full component-id list, with the empty case stated explicitly if it
      is empty
- [ ] The measurement is reproducible: the derivation is a committed script or a
      committed exact command sequence, and re-running it on the same commit
      reproduces the same numbers
- [ ] Falsifier 1 of `questions-and-dispositions.md` §6 is answered with one of
      exactly two verdicts — `fence-1 blocking (N components in the write set)` or
      `fence-1 not blocking (intersection empty)` — and the verdict is written into
      the status board of `governance-cadence.md` §3 as a **new dated block**
      (never editing a prior block)
- [ ] A coverage-threshold **proposal** for Q-03/D5 is stated with the measured
      number behind it, marked explicitly as a proposal the operator decides —
      no threshold is applied, configured, or enforced by this task
- [ ] No file under `lib/`, `bin/`, `agents/`, `web/` or `tests/` is modified — the
      deliverable is measurement artefacts under `docs/research/executable-workflow/`
      plus this task file

### Human

- [ ] [REVIEW] Operator rules on D5 (Q-03) with the measured number in hand
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cat docs/research/executable-workflow/arc0-write-set.md`
  2. Read the fence-1 verdict block appended to `docs/research/executable-workflow/governance-cadence.md` §3
  3. Accept, revise, or reject the proposed Component Fabric coverage threshold
  **Expected:** a threshold value (or an explicit "limited mode, no threshold yet")
  recorded by the operator. The agent's number is input, not the decision.
  **If not:** leave D5 open in `governance-cadence.md` §4 and say what further
  evidence would settle it — do not let the agent pick a number by default.

- [ ] [REVIEW] Operator rules on D1 — arc-start authorisation for Arc 0
  **Steps:**
  1. Review the draft arc once it exists (see `## Decisions` — arc creation is
     currently blocked in-session)
  2. Decide whether Arc 0 moves `draft → in-progress`
  **Expected:** an explicit start or hold. Per `governance-cadence.md` §4 no agent
  may take this decision.
  **If not:** Arc 0 stays `draft`; this measurement task may still complete, since
  it is measurement rather than arc work.

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

# ── Fence 1: contract freeze. Both ingested sources still hash to manifest v1 rev 0.
#    Re-verified at close, per governance-cadence.md §1 ("before any completion claim").
test "$(sha256sum docs/research/executable-workflow/architecture-c9070637.md | cut -d' ' -f1)" = "c9070637b09493a24abc99982ae966a3b3ae8cd4a358a44fdceb59bdceb6ac2d"
test "$(sha256sum docs/research/executable-workflow/roadmap-5be23719.md | cut -d' ' -f1)" = "5be23719b976e37a6461b4b1f6f309985b5ba033ef0b801769edd2627fbae5b8"

# ── Fence 2: the write-set derivation artefact exists and is substantive.
test -f docs/research/executable-workflow/arc0-write-set.md
test "$(wc -c < docs/research/executable-workflow/arc0-write-set.md)" -ge 1024

# ── Fence 3: the measurement produced an actual number, not prose.
grep -qE "^unknown_subsystem_count: [0-9]+$" docs/research/executable-workflow/arc0-write-set.md
grep -qE "^write_set_component_count: [0-9]+$" docs/research/executable-workflow/arc0-write-set.md
grep -qE "^intersection_count: [0-9]+$" docs/research/executable-workflow/arc0-write-set.md
grep -qE "^measured_at_commit: [0-9a-f]{7,40}$" docs/research/executable-workflow/arc0-write-set.md

# ── Fence 4: falsifier 1 answered with one of exactly two verdicts, on the status board.
grep -qE "fence-1 (blocking|not blocking)" docs/research/executable-workflow/governance-cadence.md

# ── Fence 5: no runtime implementation landed under this task ID.
git log --name-only --format= --grep="T-3147" > /tmp/.t3147-paths 2>&1 && ! grep -qE "^(lib|bin|agents|web|tests)/" /tmp/.t3147-paths

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

### 2026-08-26 — draft Arc 0 could not be created in this session

- **Chose:** create the task, leave `arc_id:` unset, and report the blocker.
- **Why:** every `bin/fw arc …` invocation — including the read-only
  `bin/fw arc list` — returns `This command requires approval` in this session.
  `.claude/settings.local.json` carries `Bash(bin/fw task:*)`, `Bash(bin/fw
  context:*)` and 20-odd sibling `fw` entries but **no `Bash(bin/fw arc:*)`**, and
  the session is non-interactive, so the approval cannot be granted here. This is
  a harness permission boundary, not an AEF gate: `arc_create` in `lib/arc.sh:373`
  has no `$CLAUDECODE` refusal (only `arc_close` (T-1671) and `arc_approve_driver`
  do), and the two gates it *does* enforce — `--name` required and
  `_arc_validate_headline_mechanic` (§ACD/G-062, `lib/arc.sh:256`) — were both
  satisfied by the prepared invocation.
- **Rejected:** adding `Bash(bin/fw arc:*)` to `.claude/settings.local.json`;
  invoking `lib/arc.sh` directly; hand-writing `.context/arcs/*.yaml`. All three
  route around the boundary rather than reporting it, and the third also violates
  the D-Immutability rule that arc state changes go through `fw arc <verb>`
  (`lib/arc.sh:20-27`).
- **Consequence:** `arc_id:` stays unset. Setting it now would trip the
  `check-arc-id` PreToolUse hook, which is correct — the arc does not exist.

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

### 2026-08-25T22:12:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3147-ewcr-arc-0-evidence-baseline-measure-fab.md
- **Context:** Initial task creation

### 2026-08-25T22:17:26Z — status-update [task-update-agent]
- **Change:** tags: +arc:ewcr-arc0-contract-evidence
