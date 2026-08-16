---
id: T-2356
name: "BVP estimator dedicated handlers for arc-011 scoped drivers (D-DISJOINT + D-WIRE-EVIDENCE)
  — latent until arc approval + dispatch wiring"
description: >
  BVP estimator dedicated handlers for arc-011 scoped drivers (D-DISJOINT + D-WIRE-EVIDENCE)
  — latent until arc approval + dispatch wiring

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bvp, estimator, arc-011, latent]
components: [agents/termlink/bvp-estimator/estimator.py, 
      tests/unit/test_bvp_estimator.py]
related_tasks: [T-2328, T-2329, T-2344, T-2303]
arc_id: parallel-execution-aef
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
created: 2026-06-12T23:13:40Z
last_update: '2026-08-16T22:25:03Z'
date_finished: 2026-06-12T23:21:57Z
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
  - ts: '2026-06-12T23:15:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-12T23:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 4
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=4 (body:rubric-routable); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 4
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=4 (body:auto-promote-class-eligibility); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2356: BVP estimator dedicated handlers for arc-011 scoped drivers (D-DISJOINT + D-WIRE-EVIDENCE) — latent until arc approval + dispatch wiring

## Context

Sibling of T-2328 (V_* trio) + T-2329 (F-AUTONOMY). arc-011 (`parallel-execution-aef`) carries two `proposed_scoped_drivers` per `.context/arcs/parallel-execution-aef.yaml` (proposed retroactively via T-2344 Workflow A batch_propose):

- **D-DISJOINT** (weight 5) — Disjoint Write-Set Discipline. Rewards pre-flight collision refusal (`write_set:` scope declared, tested before dispatch). Distinguishes from D2 (reliability) which rewards post-hoc observability of the same failure class.
- **D-WIRE-EVIDENCE** (weight 4) — Wire-Evidence Falsifiability. Rewards captured, re-runnable wire artefacts (`dispatches.jsonl` excerpts, git status snapshots, `timing.yaml`) tied to a specific arc claim. Counters G-062 substrate-vs-deliverable conflation at arc-close time.

Rubric anchors: `docs/reports/T-2344-bvp-driver-arc-011.md` Candidates 1-2.

**Latency rationale:** the estimator's `_load_drivers()` reads only `policy/value-drivers.yaml` (`protected_drivers` + `free_drivers`). Arc-scoped drivers (`scoped_drivers:` in arc YAMLs) are NOT consulted by the estimator dispatch loop today. Handlers therefore stay LATENT (never fire) until two events happen:

1. Operator approves the proposed drivers via Watchtower (`fw arc approve-driver arc-011 D-DISJOINT --weight 5 --from-watchtower` + same for D-WIRE-EVIDENCE)
2. Someone extends `estimate_task()` to also resolve arc-scoped drivers when the task's `arc_id:` matches an arc with `scoped_drivers:` populated (separate follow-on; out of scope for this slice)

Same shape as T-2329 F-AUTONOMY (latent until T-2171 uncomments the policy carve) and T-2328 V_* (latent until T-2306 Sovereign `--add`). The pattern is: ship the handler code now, fire when policy/dispatch lets it through.

## Acceptance Criteria

### Agent
- [x] `score_d_disjoint(fm, body, tags) -> tuple[int, list[str]]` added to `agents/termlink/bvp-estimator/estimator.py` with full 6-level rubric (0-5) anchored to D-DISJOINT rationale in T-2344 §Candidate 1: L5 new structural invariant class, L4 framework-level pre-flight gate, L3 component-level write-set test, L2 partial declaration + lint, L1 incidental disjointness reference, L0 no signal
- [x] `score_d_wire_evidence(fm, body, tags) -> tuple[int, list[str]]` added to the same file with full 6-level rubric (0-5) anchored to D-WIRE-EVIDENCE rationale in T-2344 §Candidate 2: L5 new falsifiability primitive class, L4 framework-level wire-evidence capture surface, L3 component-level evidence artefact (jsonl excerpt + timing.yaml), L2 narrative claim + one re-runnable command, L1 incidental log reference, L0 no signal
- [x] Both handlers registered in the `handlers` dict in `estimate_task()` (alongside D1-D4, F-RECALL/F-ORCH, V_*, F-AUTONOMY) — keys exactly `"D-DISJOINT"` and `"D-WIRE-EVIDENCE"` (match the IDs in arc-011.yaml proposed_scoped_drivers)
- [x] Header docstring on each handler references T-2356 + T-2344 + states the latency invariant explicitly (mirrors T-2329's `Handler stays LATENT until ...` phrasing)
- [x] Test coverage in `tests/unit/test_bvp_estimator.py` matches T-2329 F-AUTONOMY shape: per-level test (0/1/2/3/4/5 for each handler = 12 tests minimum) + dispatch-registration test (when drivers dict contains D-DISJOINT, `estimate_task` returns the dedicated handler's score not the fallback) + non-registration test (when drivers dict doesn't include D-DISJOINT, slot doesn't fire)
- [x] Total new test count ≥ 14 (12 per-level + 2 dispatch). All new tests PASS; existing test suite green (regression net)
- [x] Reviewer PASS on T-2356: `bin/fw reviewer T-2356` returns `Overall: PASS` or `CONCERN`, no FAIL
- [x] Latency verified: with default policy (no D-DISJOINT in `_load_drivers()` output), `estimate_task()` on an arc-011 member task does NOT include `D-DISJOINT` or `D-WIRE-EVIDENCE` in the returned `scores:` dict (the handlers are reachable from the dict but the dispatch loop never asks for them) — covered by the non-registration tests above

<!-- All ACs are agent-verifiable (backend Python, no UI / render surface, no operator
     judgment slot). Per CLAUDE.md §AC Classification Guidance the Human block is
     omitted entirely. Same shape as T-2328/T-2329. -->

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

python3 -m pytest tests/unit/test_bvp_estimator.py -q > /tmp/.t2356-pytest.out 2>&1; grep -q "passed" /tmp/.t2356-pytest.out && ! grep -qE "failed|error" /tmp/.t2356-pytest.out
grep -q "def score_d_disjoint" agents/termlink/bvp-estimator/estimator.py
grep -q "def score_d_wire_evidence" agents/termlink/bvp-estimator/estimator.py
grep -q '"D-DISJOINT": score_d_disjoint' agents/termlink/bvp-estimator/estimator.py
grep -q '"D-WIRE-EVIDENCE": score_d_wire_evidence' agents/termlink/bvp-estimator/estimator.py
out=$(bin/fw reviewer T-2356 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-12 — handler gating widened to catch plain `dispatches.jsonl` mention

- **What changed:** First test run failed `test_d_wire_evidence_narrative_plus_command_scores_two` + `test_d_wire_evidence_framework_surface_scores_four`. The L1-gating `evidence_body` pattern set required either `"dispatches.jsonl excerpt"` / `"dispatches.jsonl rows"` (qualified phrases) or `"wire-evidence"` directly. A plain `cat .context/dispatches.jsonl` in a Verification block — the canonical operator-facing shape — failed to gate and scored L0 across the board. Added `r"\bdispatches?\.jsonl\b"` + `r"dispatch[- ]outcomes\.jsonl"` to evidence_body so the gating fires whenever the filename appears at all, then the L2/L3/L4 rubric levels distinguish narrative-vs-component-vs-surface.
- **Plan impact:** Filing-time rubric (per T-2344 §Candidate 2) was correct on level definitions but understated the *gating* threshold — "wire-evidence" was assumed to be the most common token. Real tasks reach for the filename. Two test failures forced the recalibration before reviewer could ever see the handler.
- **Triggered:** None as separate sub-task — gating fix folded into the same slice. Sibling lesson for future scoped-driver handlers: gate on the *canonical artefact filename* the driver rewards, not the rationale-paragraph term.

### 2026-06-12 — narrative+command L2 regex bound was off-by-some

- **What changed:** `test_d_wire_evidence_narrative_plus_command_scores_two` failed even after the gating fix because the L2 regex `r"`(cat|jq|grep|tail) .{0,40}(dispatches?\.jsonl|outcomes?\.jsonl)`"` required the closing backtick within 40 chars after the command verb. The canonical Verification-block shape `` `cat .context/dispatches.jsonl | jq '.outcome'` `` runs 42+ chars before the close — narrow miss. Dropped the closing backtick from the pattern and widened to `{0,80}` to absorb typical pipe chains.
- **Plan impact:** L2 narrative-vs-component distinction is real (one re-runnable command in body vs a captured artefact) but the regex was an over-constrained pattern. Reading-friendly Verification commands are longer than 40 chars in practice.
- **Triggered:** No follow-on. Folded into the slice.

## Recommendation

**Recommendation:** GO

**Rationale:** Sibling-of-T-2328/T-2329 latent-handler pattern delivered cleanly. All 8 Agent ACs verified: both handlers implemented with 6-level rubrics anchored to T-2344 §Candidates 1-2, registered in `handlers` dict, docstrings carry the explicit LATENT-until-X invariant; 20 new tests (+10 D-DISJOINT incl. dispatch trio + +10 D-WIRE-EVIDENCE incl. dispatch trio) exceed the AC#6 floor of 14; pytest 110/110 file-local + 192/192 BVP regression net green; reviewer R-01e1e502 PASS, 0 findings; latency verified by the two non-registration tests (`estimate_task({})` does not include D-DISJOINT or D-WIRE-EVIDENCE in returned scores). No render surface; pure backend Python.

**Evidence:**
- `agents/termlink/bvp-estimator/estimator.py:1004-1135` — `score_d_disjoint` (6-level rubric, L0-L5)
- `agents/termlink/bvp-estimator/estimator.py:1137-1259` — `score_d_wire_evidence` (6-level rubric, L0-L5)
- `agents/termlink/bvp-estimator/estimator.py:1087-1093` — both registered in `handlers` dict with T-2356 latency comment
- `tests/unit/test_bvp_estimator.py:943-1130` — 20 new tests (per-level 0-5 + 4 dispatch tests per handler)
- Reviewer verdict: R-01e1e502 PASS, 0 findings
- Regression net: 192/192 PASS across `tests/unit/test_bvp_estimator.py` + BVP CLI/dispatch/auto-promote tests

**Activation path (for the operator, when ready):**
1. `http://192.168.10.107:3000/arcs/parallel-execution-aef` → Approve buttons on the proposed_scoped_drivers table (D-DISJOINT and D-WIRE-EVIDENCE). Sovereign action. Per L-482, the URL is the primary affordance.
2. Separate follow-on slice (not this task) wires arc-scoped driver resolution into `estimate_task()`. Until that ships, the handlers remain reachable from the dict but the dispatch loop never asks for them — same latency as T-2329 F-AUTONOMY today.

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

### 2026-06-12T23:13:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2356-bvp-estimator-dedicated-handlers-for-arc.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5c87ea2c
- **Timestamp:** 2026-06-12T23:21:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-12T23:21:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
