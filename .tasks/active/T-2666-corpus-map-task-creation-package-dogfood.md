---
id: T-2666
name: "corpus map: task-creation (package dogfood catalog)"
description: >
  Map the task-creation process (capture → classification → BVP estimation → confirmation
  → activation; create-task.sh + estimator worker + fw work-on) as a corpus map +
  conformance rail. Third of the package's four worst-regression processes (T-2662
  gap 6). Gated on the tier0-escalation P4 test outcome.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [process-layer, corpus]
components: []
related_tasks: [T-2662]
arc_id: designer-corpus
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
created: 2026-07-28T16:20:18Z
last_update: 2026-07-29T06:47:49Z
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
  - ts: '2026-07-28T16:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T16:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-29T06:47:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2666: corpus map: task-creation (package dogfood catalog)

## Context

Third dogfood round of the package's four worst-regression processes (T-2662 gap 6).
Baseline pre-mined 2026-07-29 while T-2665's pair round was in flight — see below.

## Regression-History Baseline (AC-1)

Mined 2026-07-29 (git log all branches, concerns.yaml, learnings.yaml, episodics):

- **Churn volume:** ~206 commits across the four surfaces with ~40% pure-fix ratio —
  create-task.sh 34 (17 fix-shaped), check-active-task.sh 36 (17), update-task.sh
  100 (37; the script is 102KB, largest in the machine), templates 36.
- **create-task.sh fix chain (~10 consecutive defect commits):** T-141 wrong
  template, T-143 unquoted name → YAML break, T-165 20 broken links same bug,
  T-297 --start didn't set focus, T-555 placeholder names accepted, T-1279
  ID-allocation race, T-1424 keylock silent fail, T-1687 revert of fake-prevention
  chain, T-100160 non-tty hang, T-100202 worktree duplicate IDs (2 commits).
- **ID-race class hit 3×:** T-1279/L-338 (4 parallel work-on → all minted T-1278),
  T-1345 (single pickup_process minted SEVEN tasks numbered T-1345 — flock protected
  across invocations, not within one; concerns.yaml:1401), T-100202 (stale worktree
  re-opened the hole after T-1279's fix).
- **Template/gate classes:** T-471 = G-020 origin (built on `[First criterion]` ACs,
  3 human interventions); OBS-041 duplicate `### Human` headings recurred across 5
  tasks; T-1941→T-1967 sed comment-strip swallowed 7 ticked ACs (same class re-fired
  T-2554 in check-active-task.sh).
- **Live conformance holes (rail-grade):** `owner` — predicate `is_valid_owner`
  (lib/enums.sh:103) EXISTS but create-task.sh:50 never calls it, accepts any string;
  Watchtower hard-whitelists {human, claude-code} → `--owner orchestrator` renders
  broken (concerns.yaml:1151). `status`-at-creation — no validation path at all.
  `workflow_type` — a THIRD parallel enumeration lives in the Watchtower creation
  form (concerns.yaml:1094; new type silently breaks the web form).
- **Canonical vocab source:** status-transitions.yaml (types :17-24, statuses :7-15,
  horizons :26-29, owners :31-33, transitions :35+) read by lib/enums.sh — which
  itself carries hardcoded fallback duplicates at :62-77 (second drift surface).

**Rail candidates (strongest first):** (1) `owner` at creation — provable hole, the
rail would go in knowingly RED per T-2659 precedent, which is the more interesting
dogfood outcome; (2) `workflow_type` — 3-site enumeration incl. Watchtower form;
(3) `status`-at-creation. Note the machine already HAS a transition-table rail
(aef-task-lifecycle) — this map covers the creation ceremony upstream of it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Regression-history baseline captured in task body before mapping (episodic +
      concerns evidence for task-creation reiterations).
- [ ] `draft-task-creation` seeded via the arc-014 pair-draft ritual from the
      enforced machine (create-task.sh flags/gates incl. inception-recommendation
      gate, BVP estimator worker, `fw work-on` capture→started-work transition);
      operator + 832 iterate; canonical namespace untouched until approval.
- [ ] On approval: promoted, corpus lint baseline unchanged, `fw corpus prove` green.
- [ ] Conformance-rail entry added to `tools/conformance-registry.yaml`; result
      recorded honestly (green, or red with divergent pin test per T-2659 precedent).

## Pair-Round State

- **2026-07-29** — v2 seeded (14 nodes / 20 flows / 3 lanes incl. Human·Sovereignty
  for the Watchtower-form entry — the human ACTION earning the lane per 832's rule
  from the T-2665 round). Dialect lessons applied AT SEED: no merge gateways
  (multi-incoming implicit XOR), agent-lane steps serviceTask, advisory-ness in
  aef:meta notes. Rail dry-run PASS: 7 tokens {specification, design, build, test,
  refactor, decommission, inception} vs status-transitions.yaml workflow_types block
  (block-bounded regex, verified no leak into horizons/owners). Lint baseline 2.
  Round-trip 14/20. Live-verified served v2. Open taste questions posed to round:
  (a) two start events (agent CLI + human form) OK in dialect? (b) fork an
  "activation?" gateway for the bare-create-ends-captured path, or keep note?
  (c) owner/status creation-hole: wire predicates (Level C fix task) or pin the
  hole in the map note?

## AC-4 Prep (ready to paste at promotion)

Registry entry (dry-run verified PASS against draft v2 on 2026-07-29):

```yaml
# Workflow-type gateway branches (7-way fan; inception forks through the
# T-2204 recommendation gate before converging) vs the canonical enum in
# status-transitions.yaml workflow_types block (read by lib/enums.sh
# is_valid_type, enforced at create-task.sh:176). Block-bounded regex —
# capture group spans only the workflow_types items, so horizons/owners
# below it cannot leak in. Added at promotion of draft-task-creation (T-2666).
aef-task-creation:
  primitive: vocabulary-set
  source: status-transitions.yaml
  gateway: "workflow type?"
  branch_vocab:
    regex: "[A-Za-z][A-Za-z-]*"
  source_vocab:
    regex: 'workflow_types:\n((?:[ ]*- [a-z]+\n)+)'
    first_only: true
    split: "- "
```

Pin test: rc==0 and all 7 type tokens in stdout.

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
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
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

### 2026-07-28T16:20:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2666-corpus-map-task-creation-package-dogfood.md
- **Context:** Initial task creation

### 2026-07-29T06:47:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
