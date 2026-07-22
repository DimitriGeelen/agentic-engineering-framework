---
id: T-2604
name: "Corpus lint: per-map + cross-map rules mapped 1:1 to observed defect classes"
description: >
  T-2602 GO child 2/3. Lint rules each citing an observed defect: legacy-ref form
  (T-2600), duplicate/inert handoff glyphs (T-2600/T-2601), emitterless typed events
  (T-2551 gap), ghost refs (T-2584). Extends T-2552 compile-WARN leg.

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
created: 2026-07-22T10:49:18Z
last_update: 2026-07-22T18:30:54Z
date_finished: 2026-07-22T18:30:54Z
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
  - ts: '2026-07-22T11:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-22T11:00:09Z'
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

# T-2604: Corpus lint: per-map + cross-map rules mapped 1:1 to observed defect classes

## Context

T-2602 GO child 2/3. Design basis: `docs/reports/T-2602-spec-driven-corpus-authoring.md`
(design sketch item 3, spike S3: every shipped rule must cite an observed defect).
Builds on T-2603's `tools/corpus_spec.py` (parse/canonical machinery) — `fw corpus lint`
scans the live store maps (and/or specs). Observed defect classes this corpus has
actually produced: (1) legacy `targetWorkflow` name-refs (T-2600 defective fix +
task-lifecycle v2 as-served), (2) duplicate/inert handoff wiring (T-2600/T-2601 —
two throw handoffs where one belongs, handoff throw not a branch terminal),
(3) emitterless typed events — a `kind=message binding=bus:task-channel` catch with
no throw/emitter anywhere in the corpus and no explicit seam marker (T-2551 gap),
(4) ghost refs — workflowRef uuids that resolve nowhere (T-2584 class; explicit
ghost-intent is legal, silent danglers get flagged vs the registry).

## Acceptance Criteria

### Agent
- [x] `fw corpus lint` verb exists (routes to `tools/corpus_lint.py`, scans all store maps by default or named maps/files) and exits 0 on a clean corpus, non-zero when any rule fires; output names rule id, map, node, detail, and the defect-class origin task; `--json` for machine consumption
- [x] Rule `legacy-ref` (origin T-2600 + as-served corpus): flags every `aef:link` carrying `targetWorkflow` without `workflowRef` — live run fires on `aef-task-lifecycle` v2, `aef-dispatch-loop` v3 (the T-2600 defective fix), PLUS two previously-uncatalogued maps (`aef-inception-flow` v2, `t2584-scratch` v1); also fires on the s4-exemplar legacy leg when pointed at that file
- [x] Rule `handoff-wiring` (origin T-2600/T-2601): flags a throw-handoff that is not a branch terminal (has outgoing flows) and two+ throw-handoffs targeting the same workflow from one map (duplicate-glyph defect); pinned both ways by unit fixtures (served v3's wiring is terminal-clean — its live defect is legacy-ref, per XML re-read during AC authoring)
- [x] Rule `emitterless-typed-event` (origin T-2551): cross-map — flags a typed catch (`aef:eventDef`) whose `binding` has no typed throw with the same binding in any scanned map and no explicit `aef:meta seamPending` marker; fires on `agt_msg_result` (bus:task-channel) in the live run
- [x] Rule `ghost-ref` (origin T-2584): flags `workflowRef` uuids resolving to neither a store map nor the pending-ref registry (ghosts AND claims honored); registered ghost 398f4752 not flagged in live run; fires on the s4-exemplar's 4300eae7 leg (832's ghost, unknown to our store — correct)
- [x] Unit tests pin all rules both ways (`tests/unit/test_corpus_lint.py`, 11 passed: fire-on-defective + silent-on-clean per rule, plus a live-corpus expectation pin documenting as-served findings until the T-2605 recreate deliberately shrinks them); live lint run: 8 maps scanned, 5 findings (4× legacy-ref, 1× emitterless-typed-event), recorded above

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

out=$(python3 -m pytest tests/unit/test_corpus_lint.py 2>&1); echo "$out" | grep -q "11 passed"
out=$(bin/fw corpus lint 2>&1 || true); echo "$out" | grep -q "legacy-ref" && echo "$out" | grep -q "emitterless-typed-event"
out=$(bin/fw corpus lint tests/fixtures/832/s4-exemplar.bpmn 2>&1 || true); echo "$out" | grep -q "legacy-ref" && echo "$out" | grep -q "ghost-ref"

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

### 2026-07-22T10:49:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2604-corpus-lint-per-map--cross-map-rules-map.md
- **Context:** Initial task creation

### 2026-07-22T18:25:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-796356da
- **Timestamp:** 2026-07-22T18:30:56Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `fw corpus lint` verb exists (routes to `tools/corpus_lint.py`, scans all store maps by default or named maps/files) and exits 0 on a clean corpus, non-zero when any rule fires; output names rule id, 
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tools/corpus_lint.py in: `fw corpus lint` verb exists (routes to `tools/corpus_lint.py`, scans all store maps by default or named maps/files) and exits 0 on a clean corpus, no`

### 2026-07-22T18:30:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
