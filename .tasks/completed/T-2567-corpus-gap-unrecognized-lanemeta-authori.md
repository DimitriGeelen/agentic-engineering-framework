---
id: T-2567
name: "corpus gap: unrecognized laneMeta authority value silently folds to owner agent
  (Framework/authority lane)"
description: >
  arc-014 pair-draft finding (T-2566, 832 offset 92): 832's session-handover.bpmn
  has a third lane authority=authority (Framework · Authority). AUTHORITY_OWNER maps
  only sovereignty/initiative; the fallback derived owner: agentagent for all three
  framework-lane task nodes with NO WARN — silent semantic folding (the AEF task model
  has no framework owner). Fix: WARN when a laneMeta authority value is outside the
  known map, naming the lane, the applied fallback owner, and the affected nodes.
  Sibling of T-2537 name-only-lane WARN class.

status: work-completed
workflow_type: build
owner:
horizon: null
tags: [arc:designer-corpus]
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
created: 2026-07-19T21:13:48Z
last_update: 2026-07-19T21:33:56Z
date_finished: 2026-07-19T21:33:56Z
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
  - ts: '2026-07-19T21:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-19T21:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2567: corpus gap: unrecognized laneMeta authority value silently folds to owner agent (Framework/authority lane)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Pass-1 owner derivation WARNs when `aef:laneMeta authority=` carries a value outside AUTHORITY_OWNER (sovereignty/initiative), naming the lane, the fallback owner applied, and the affected node uids
- [x] sovereignty/initiative lanes byte-identical to today (additive-only); regression test on 832's pinned session-handover.bpmn asserts the WARN and moves the T-2566 current-behavior pin; suite green (44/44)

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
python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q > /tmp/.t2567-pytest.out 2>&1 && grep -q "passed" /tmp/.t2567-pytest.out
out=$(python3 tools/bpmn_to_tasks.py tests/fixtures/aef-bpmn/session-handover.bpmn 2>&1); echo "$out" | grep -q "unrecognized aef:laneMeta authority='authority'"
out=$(python3 tools/bpmn_to_tasks.py tests/fixtures/aef-bpmn/typed-events.bpmn 2>&1); ! echo "$out" | grep -q "unrecognized aef:laneMeta"

## RCA

**Symptom:** 832's pair-draft #1 (session-handover.bpmn, 3 lanes) compiled its three Framework·Authority nodes (n_resume/n_gate/n_persist) to `owner: agent` with zero WARN — the authority provenance vanished silently (found in T-2566).

**Root cause:** `AUTHORITY_OWNER` maps only sovereignty→human / initiative→agent. Any other `aef:laneMeta authority=` value made `auth_owner` None, dropping to the name-heuristic/type-default chain with no signal that an explicit authority-of-record had been ignored.

**Why structurally allowed:** the fallback chain was designed for *absent* authority (no laneMeta), so "present but unrecognized" rode the same silent path as "absent" — the WARN-first discipline (T-2552 class) covered typed events and gateways but not owner derivation.

**Prevention:** aggregated Pass-1 WARN per lane naming the unrecognized value + every uid→owner fold; regression test `test_832_handover_authority_lane_warns_not_silent` on 832's pinned fixture + additive-only guard test on sovereignty/initiative fixtures.

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

### 2026-07-19 — peer ratification arrived before build started
- **What changed:** 832 volunteered a design vote (rail offset 95) before this task was picked up: keep owner:agent fallback + WARN, do NOT mint a synthetic "framework" owner — a Framework·Authority node is *enforced by* the framework but *executed by* the agent, so the loss is authority PROVENANCE, not executor identity.
- **Plan impact:** none — vote matched the filed plan exactly; implemented as one aggregated WARN per lane (mirrors the T-2557 gateway-WARN aggregation style) rather than per-node WARNs.
- **Triggered:** landing this BEFORE compiling 832's pair-draft #2 (T-2568), whose frw_3_headroom/frw_14_checkpoint nodes will now surface the WARN live instead of re-pinning silent behavior.

## Decisions

### 2026-07-19 — fallback owner for unrecognized authority lanes
- **Chose:** keep the existing name-heuristic/type-default fold (→ agent for 832's Framework nodes) and surface ONE aggregated WARN per lane listing uid→owner pairs.
- **Why:** 832's rail-offset-95 vote + own analysis — the executor really is the agent; inventing a "framework" owner would over-fit the task model to round-trip a lane. Aggregation keeps WARN volume proportional to lanes, not nodes.
- **Rejected:** (a) synthetic `owner: framework` — AEF tasks can't action it; (b) hard error — the encoding is legitimate 832 dialect, and O-3 already hard-errors the one case where authority is load-bearing (inception sovereignty); (c) per-node WARNs — noisy on large lanes, same information.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-19T21:13:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2567-corpus-gap-unrecognized-lanemeta-authori.md
- **Context:** Initial task creation

### 2026-07-19T21:14:03Z — status-update [task-update-agent]
- **Change:** tags: +arc:designer-corpus

### 2026-07-19T21:30:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-aad69e30
- **Timestamp:** 2026-07-19T21:33:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 33
     - evidence: `out=$(python3 tools/bpmn_to_tasks.py tests/fixtures/aef-bpmn/typed-events.bpmn 2>&1); ! echo "$out" | grep -q "unrecognized aef:laneMeta"`

### 2026-07-19T21:33:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
