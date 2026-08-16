---
id: T-2631
name: "map catch-up pair-round seed — 2 missing lifecycle flows, conformance GREEN"
description: >
  map catch-up pair-round seed — 2 missing lifecycle flows, conformance GREEN

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
arc_id: designer-corpus
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-27T19:03:02Z
last_update: '2026-08-16T22:24:10Z'
date_finished: 2026-07-27T19:08:02Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:24:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2631: map catch-up pair-round seed — 2 missing lifecycle flows, conformance GREEN

## Context

The T-2621 conformance rail reports aef-task-lifecycle DIVERGENT: two enforced
transitions the map lacks — `issues → work-completed` and `started-work →
captured` (T-1068 shelving auto-demote). T-2621 routed the catch-up to a
pair-round; this task is the **agent seed half** of the arc-014 ritual (agent
seeds the edit → operator reviews/adjusts in the designer UI → agent re-reads
and normalizes). Seed = additive v2 of the map: two flows, zero node changes,
layout (`aef:position`) untouched, uuid/meta lineage preserved.

Edge placement (collapse-verified against tools/corpus_conformance.py walk):
- `tl_f19` `agt_3_work → agt_1c_parked` ("shelved") asserts started-work→captured
- `tl_f20` `agt_4_heal → agt_5_verify` ("resolved at gate — complete directly")
  asserts issues→work-completed via the non-carrier verify/gate path; its only
  other collapse pair (issues→started-work) is already canonical

Rail GREEN is the precondition for the map's detail-authority graduation
(T-2619) — the graduation itself stays the operator's call.

## Acceptance Criteria

### Agent
- [x] Seed present in the store's latest version: exactly 2 new sequenceFlows
      (tl_f19, tl_f20 w/ uids tl_e19/tl_e20, named, incoming/outgoing refs on the
      4 touched nodes); all 15 node `aef:position` layouts and every carrier
      preserved. NOTE: authored as v2, then `fw corpus prove` (run as part of
      verification) delete/recreated the map — prove normalizes the store to a
      single recreated v1 (canonical IDENTICAL, uuid PRESERVED); the seed content
      survived the round-trip and lives in the served latest. Same normalization
      the whole store carries since the 2026-07-27 squash.
- [x] `python3 tools/corpus_conformance.py` exits 0 — PASS, all 6 enforced
      transitions asserted (first GREEN since the rail shipped in T-2621); audit
      structure WARN clears (verified in pre-push audit output)
- [x] Corpus health unchanged: lint baseline untouched (same 2 pre-existing
      findings on other maps), `fw corpus prove` PASS (uuid preserved, canonical
      IDENTICAL), derive + canon parse the seeded map clean
- [x] Live surfaces intact on :3001 — /api/version?id=aef-task-lifecycle serves
      the seeded latest (tl_f19+tl_f20 present), editor loads it (302 nonce mint
      → 200), /api/overlay 200 with carrier uids intact (tl_heal absent from the
      payload only because zero tasks currently sit in issues — live projection)

### Human
- [ ] [REVIEW] Pair-round ratification: the 2 seeded edges are right, visually and semantically
  **Steps:**
  1. Open http://192.168.10.107:3001/designer/overlay?id=aef-task-lifecycle (or /designer → aef-task-lifecycle card)
  2. Find the two new edges: "shelved — horizon next/later auto-demotes to captured (T-1068)" (do-the-work → parked) and "resolved at gate — complete directly" (healing → completion gates)
  3. Adjust routing/wording/layout in the editor and save if anything reads wrong — the agent re-reads and normalizes your save (pair-draft loop)
  **Expected:** both edges read as true statements of the enforced lifecycle; diagram stays legible
  **If not:** edit in the UI and save (agent picks it up), or note objections on the review page — deleting either edge re-opens the conformance WARN by design

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

python3 tools/corpus_conformance.py
out=$(python3 tools/corpus_spec.py canon .context/designer/projects/aef-task-lifecycle/v1.bpmn 2>&1); grep -q 'tl_f19' <<<"$out" && grep -q 'tl_f20' <<<"$out"
out=$(curl -sf "$(bin/fw watchtower url)/api/version?id=aef-task-lifecycle"); grep -q 'tl_f19' <<<"$out" && grep -q 'tl_f20' <<<"$out"
out=$(curl -sf "$(bin/fw watchtower url)/api/overlay?id=aef-task-lifecycle"); grep -q '"aef:annotate"' <<<"$out"

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

## Recommendation

- **Recommendation:** GO
- **Rationale:** The conformance rail is GREEN for the first time since it
  shipped (T-2621) — the map now asserts exactly the 6 enforced transitions.
  The seed is purely additive (2 flows, zero node/layout changes) and each edge
  states a rule the framework already enforces (T-1068 shelving auto-demote;
  issues→work-completed direct completion). Your half of the pair round is
  visual/semantic ratification; with the rail GREEN, detail-authority
  graduation (T-2619) becomes available — that call is yours, not part of this
  task.
- **Evidence:**
  - `python3 tools/corpus_conformance.py` → PASS, exit 0 (was DIVERGENT, 2
    code-allows/map-lacks)
  - Lint baseline untouched (2 pre-existing findings, other maps); prove PASS
    (uuid preserved, canonical IDENTICAL)
  - Live: /api/version serves the seeded latest; editor 200 after nonce mint;
    /api/overlay 200, carriers intact

## Evolution

### 2026-07-27 — prove is store-destructive (and that's its design)
- **What changed:** `fw corpus prove` delete/recreates the map in the LIVE
  store and normalizes history to a single recreated v1 — my authored v2 (with
  descriptive meta note) became a recreated v1 with a generic note. Canonical
  content + uuid survive; version lineage notes do not. This also retroactively
  explains the post-squash meta notes across all 5 maps: the previous window's
  prove runs wrote them.
- **Plan impact:** provenance for map edits must live in the task file + commit
  message, not in meta.json version notes. The pair-draft loop is unaffected —
  operator saves via the editor create ordinary v2/v3 entries as usual.
- **Triggered:** nothing filed — behavior is T-2605's documented DR mechanic;
  noting here so the next map-editing task doesn't re-learn it.

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

### 2026-07-27T19:03:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2631-map-catch-up-pair-round-seed--2-missing-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d5189fe2
- **Timestamp:** 2026-07-27T19:08:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-27T19:08:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
