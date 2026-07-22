---
id: T-2601
name: "RCA T-2600 defective fix: duplicate handoff node + wrongly-connected return
  leg + worker-result-on-bus unconnected (operator report)"
description: >
  RCA T-2600 defective fix: duplicate handoff node + wrongly-connected return leg
  + worker-result-on-bus unconnected (operator report)

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-07-22T10:14:10Z
last_update: 2026-07-22T10:52:11Z
date_finished: 2026-07-22T10:52:11Z
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
  - ts: '2026-07-22T10:15:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-22T10:15:08Z'
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
---

# T-2601: RCA T-2600 defective fix: duplicate handoff node + wrongly-connected return leg + worker-result-on-bus unconnected (operator report)

## Context

Operator escalation after T-2600 shipped: "you just fabricated another handoff wrongly connected — we now have two handoffs and 'worker result on bus' is still unconnected."

## RCA

**What the operator was actually clicking (the original "handoff back does not work"):**
`agt_msg_result` ("worker result on bus") in aef-dispatch-loop is authored as `bpmn:intermediateCatchEvent` with `<aef:eventDef kind="message" binding="bus:task-channel"/>` — a **typed message event** (T-204 vocabulary), NOT a handoff. But the 0.3.0 bundle's editor classifies EVERY intermediateCatchEvent as `linkEventCatch` — the "← Handoff from another workflow" node type. Evidence (live properties panel, 2026-07-22): node type shows `linkEventCatch`, "Target workflow: — none —", and an "↗ Open target workflow" affordance that is permanently inert. So the operator saw a handoff-in node that does nothing. Their report was accurate; the node was never a handoff.

**What T-2600 did wrong (my defect):**
1. Investigated by grepping XML for `aef:link` only → concluded "no handoff node exists" → **fixed the inferred bug, not the reported one**. Never selected the node the operator was clicking, never opened its properties, never looked at the rendered canvas (first screenshot taken only during THIS RCA).
2. Added a NEW outgoing throw handoff (`agt_7_handoff_back`) wired as a fork off `agt_5_outcome` → canvas now shows TWO handoff-glyph circles (the inert linkEventCatch + my throw). "Two handoffs" ✓.
3. Authored the link in the LEGACY form (`targetWorkflow="aef-task-lifecycle"` name-ref, empty linkId) instead of the ratified contract v0 form (`workflowRef` uuid, T-2571 offset-109). Same class as the rename-fragile refs the whole S1-S6 seam exists to eliminate.
4. Verified with a click-path test on MY OWN node only — the "agt_9_handoff" auto-label was visible in my own probe output next to my node and I didn't chase what else rendered as a handoff.

**Root defect split (three owners):**
- **832 bundle (0.3.1 candidate):** eventDef-typed catch events must NOT classify as linkEventCatch / must not offer an inert jump affordance. Vocabulary collision between `aef:eventDef` (T-204) and `aef:link` handoff typing on the same BPMN element. → reported on rail.
- **T-2600 fix (mine):** duplicate node, legacy ref form, fork wiring — needs revert/re-author (this task).
- **Seam (pre-existing, tracked):** "worker result on bus" is also *typed-event unconnected* — nothing in the corpus emits `bus:task-channel` (T-2551/T-2552 consumption gap; that leg blocked on 832 fixture + T-213 kind= ruling).

## Fix Options (operator steer)

- **A (recommended):** v4 removes my `agt_7_handoff_back` + `dl_f10` fork; author the back-affordance as the bundle's designed pair — an incoming "← Handoff from task lifecycle" (linkEventCatch WITH target, near the start, `workflowRef` uuid form) so "Open target workflow" jumps back; leave "worker result on bus" authored as-is (bundle fix will de-collide its rendering).
- **B:** v4 removes my node only; back-navigation waits for 832's bundle fix (eventDef de-collision + IW-2 back-ref markers).
- **C:** keep my throw node (it does work as a back-jump) but re-author to `workflowRef` uuid + reposition/rewire cleanly; plus everything in A.

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] RCA written with evidence: what the operator sees (two handoffs, unconnected "worker result on bus"), what the served v3 actually contains, and where my T-2600 fix diverged from the off-page connector contract (linkId pairing / catch-vs-throw side)
- [x] Corrected dispatch-loop version: SUPERSEDED by operator GO on T-2602 (2026-07-22T10:47Z) — the fix ships as T-2605's first spec-driven recreate of aef-dispatch-loop (options A/B/C dissolved; "worker result on bus" ruled a typed-event seam item — 832 filed T-237 for the rendering collision, T-2551 tracks the emitter gap)
- [x] Live re-verify: moves with the fix to T-2605 (recreate proof includes round-trip + visual inspection as hard ACs there); this task's deliverable — the RCA with evidence — is complete and was confirmed accurate by 832 against their source (rail offset 154: "classifier keys on the BPMN element name, not the extension payload")

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

### 2026-07-22T10:14:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2601-rca-t-2600-defective-fix-duplicate-hando.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2951813a
- **Timestamp:** 2026-07-22T10:52:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-22T10:52:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
