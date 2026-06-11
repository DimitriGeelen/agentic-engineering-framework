---
id: T-2343
name: "BVP estimator dispatch — name-alias fallback so V_* handlers fire under F3/F1/F2
  ids"
description: >
  BVP estimator dispatch — name-alias fallback so V_* handlers fire under F3/F1/F2
  ids

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-2306, T-2328, T-2336]
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
created: 2026-06-11T19:10:39Z
last_update: '2026-06-11T19:15:03Z'
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
bvp_scores_proposed:
  - ts: '2026-06-11T19:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 4
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=4 (body:rubric-routable); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-11T19:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2343: BVP estimator dispatch — name-alias fallback so V_* handlers fire under F3/F1/F2 ids

## Context

T-2336 added the V_* trio to `policy/value-drivers.yaml` with `id: F3 / F1 / F2`
and `name: V_PROMPT_QUALITY / V_CONTEXT_FABRIC / V_COMPONENT_FABRIC`. T-2328
shipped dedicated handler functions keyed by the NAMES in the estimator's
dispatch map (estimator.py:1054-1056). The two never connect: `_load_drivers()`
yields the policy `id` (F3/F1/F2) and the dispatch loop looks up by id only,
finding no match and falling through to `score_free_driver` — a generic
weak-signal fallback that defeats the purpose of the dedicated handlers.

Result: the three V_* drivers HAVE rubrics (T-2336), HAVE dedicated handlers
(T-2328), but produce undifferentiated weak scores in practice. The operator's
"implement additional BVP value drivers" directive cannot be satisfied until
the dispatch reaches the handlers.

Two safe fixes:
- **Agent-safe (this task):** extend the dispatch lookup to consult both `id`
  and `name`. Preserves policy as-is (no Sovereign edit). Makes the V_*
  handlers fire under F3/F1/F2 ids the moment this lands.
- **Sovereign-only (NOT this task):** operator runs `fw bvp driver --add` to
  add V_PROMPT_QUALITY/V_CONTEXT_FABRIC/V_COMPONENT_FABRIC entries and remove
  F3/F1/F2. That path remains open for future re-canonicalisation; this task
  unblocks scoring until then.

F-AUTONOMY remains latent as designed (T-2329) because the carve is commented
out — `_load_drivers()` never yields F-AUTONOMY, regardless of how dispatch
looks it up. This task does not change that.

## Acceptance Criteria

### Agent
- [x] `agents/termlink/bvp-estimator/estimator.py` adds `_load_driver_aliases() -> dict[str, str]` returning `{id: name}` for free drivers whose `name:` differs from `id` (non-breaking — separate function from `_load_drivers`)
- [x] Dispatch loop in `estimate_task()` (estimator.py:~1064-1080) updated: when `driver_id` not in `handlers`, try `name_aliases.get(driver_id)` and dispatch via that handler if present; falls through to `score_free_driver` only when neither id nor name resolves — preserves existing behaviour for handler-less drivers
- [x] Comment updates on the dispatch map reflect the new alias mechanism: drivers ARE active now under their policy IDs, no longer awaiting Sovereign --add
- [x] `tests/unit/test_bvp_estimator_v_alias.py` (new) covers: F3 in policy + V_PROMPT_QUALITY in dispatch → `score_v_prompt_quality` called (NOT `score_free_driver`); F1 → `score_v_context_fabric`; F2 → `score_v_component_fabric`; handler-less custom driver (no name match) → falls back to `score_free_driver`; explicit V_PROMPT_QUALITY id still dispatches correctly (backward-compat for future Sovereign re-canonicalisation); F-RECALL regression intact — 10/10 PASS
- [x] Live smoke on T-1062: estimator emits F1 evidence `body/components:context-fabric-incidental` + `→1 (incidental Context Fabric touch)` and F2 evidence `body/components:component-fabric-incidental` + `→1 (incidental Component Fabric touch)` — V_* handler-specific phrasing, distinct from the generic `body:keyword-only` fallback (verified via `bash agents/termlink/bvp-estimator/bvp-estimator.sh one T-1062 --dry-run --json`)
- [x] No regression: `bin/fw bvp` rc=0; 158/158 PASS across `tests/unit/test_bvp_*.py`

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

python3 -m pytest tests/unit/test_bvp_estimator_v_alias.py -q > /tmp/.t2343-pytest.out 2>&1 && grep -q "10 passed" /tmp/.t2343-pytest.out
out=$(bin/fw bvp 2>&1); [ $? -eq 0 ]
out=$(bash agents/termlink/bvp-estimator/bvp-estimator.sh one T-1062 --dry-run --json 2>&1); echo "$out" | grep -q "context-fabric-incidental\|component-fabric-incidental"

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

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 Agent ACs verified. The patch is the minimal viable fix: a non-breaking `_load_driver_aliases()` helper + a 3-line addition to the dispatch loop. Existing handler-less drivers still fall through to `score_free_driver` (no behaviour change). Existing handler-with-matching-id drivers (D1-D4, F-RECALL, F-ORCH) keep their direct dispatch path (no behaviour change). New V_* handlers now fire under F3/F1/F2 ids (the headline value-add). The fix preserves the Sovereign rail: if the operator later runs `fw bvp driver --add` to re-canonicalise the IDs as V_PROMPT_QUALITY/V_CONTEXT_FABRIC/V_COMPONENT_FABRIC, the dispatch keeps working (backward-compat test covers this).

**Evidence:**
- `agents/termlink/bvp-estimator/estimator.py:99-117` — `_load_driver_aliases()`
- `agents/termlink/bvp-estimator/estimator.py:1077-1080` — dispatch loop name-alias branch
- `tests/unit/test_bvp_estimator_v_alias.py` — 10/10 PASS
- Full BVP regression: 158/158 PASS across `tests/unit/test_bvp_*.py`
- Live smoke on T-1062: V_CONTEXT_FABRIC + V_COMPONENT_FABRIC handlers fire (evidence shows handler-specific phrasing `body/components:context-fabric-incidental` instead of generic `body:keyword-only`)
- Net effect: 3 dormant value drivers (V_PROMPT_QUALITY, V_CONTEXT_FABRIC, V_COMPONENT_FABRIC) now produce differentiated scores across the active task pool, satisfying the operator's "implement additional BVP value drivers" directive without requiring a Sovereign --add

## Updates

### 2026-06-11T19:10:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2343-bvp-estimator-dispatch--name-alias-fallb.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bf5aa1f0
- **Timestamp:** 2026-06-11T19:15:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#1 (Agent)
