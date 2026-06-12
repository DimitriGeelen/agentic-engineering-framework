---
id: T-2358
name: "BVP estimator arc-scoped driver helper — accept name: as fallback when id: is absent (canonical shape per lib/arc.sh:1258 write path)"
description: >
  BVP estimator arc-scoped driver helper — accept name: as fallback when id: is absent (canonical shape per lib/arc.sh:1258 write path)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, estimator, hot-fix, arc-scoped]
components: [agents/termlink/bvp-estimator/estimator.py, tests/unit/test_bvp_estimator.py]
related_tasks: [T-2356, T-2357, T-2343]
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
created: 2026-06-12T23:32:30Z
last_update: 2026-06-12T23:35:52Z
date_finished: 2026-06-12T23:35:52Z
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
---

# T-2358: BVP estimator arc-scoped driver helper — accept name: as fallback when id: is absent (canonical shape per lib/arc.sh:1258 write path)

## Context

Hot-fix to T-2357. The helper `_arc_scoped_drivers_for_task(fm)` checks `sd.get("id")` only. The canonical write path (`lib/arc.sh:1258` — `entry = {'name': name, 'weight': weight, 'approved_at': ts}`) writes entries with `name:` and NO `id:` field. Census of `.context/arcs/*.yaml`:

| Arc | scoped_drivers shape | Helper sees it? |
|-----|---------------------|-----------------|
| arc-006 value-prioritisation | `[{name: estimator-fidelity, weight: 3, approved_at: ...}]` | ❌ SILENT MISS |
| arc-011 parallel-execution-aef | `proposed_scoped_drivers: [{id: D-DISJOINT, ...}]` | ✓ (id-form from T-2344 retroactive prompt-template) |
| arc-007 watchtower-redesign | `proposed_scoped_drivers: [{name: aesthetic-cohesion, ...}]` (3 entries) | ❌ (when approved, won't surface) |
| arc-001 dispatch-safety | `proposed_scoped_drivers: [{name: uncertainty-recognition, ...}]` (3) | ❌ (when approved, won't surface) |

T-2357 silently regressed arc-006: estimator-fidelity has been APPROVED since 2026-05-21 (`approved_at:` timestamp) but my T-2357 helper would never yield it. Without this fix, only arc-011 benefits from arc-scoped activation. With this fix, arc-006's already-approved driver activates immediately + all future name-form approvals work.

**Fix shape:** in `_arc_scoped_drivers_for_task`, change `d_id = sd.get("id")` to `d_id = sd.get("id") or sd.get("name")` and update the type guard accordingly. Same pattern as estimator's `_load_driver_aliases` (T-2343), which lets a driver's policy-id and canonical-name both reach the dispatch dict.

## Acceptance Criteria

### Agent
- [x] `_arc_scoped_drivers_for_task` accepts entries with `name:` field (no `id:` field) — uses `sd.get("id") or sd.get("name")` as the driver key. Entries with neither field are silently skipped (no crash, no log spam).
- [x] Entries with BOTH `id:` and `name:` use `id:` (preserves T-2356 / arc-011 behaviour).
- [x] New test `test_arc_scoped_drivers_name_only_form_resolves` covers an arc YAML with `scoped_drivers: [{name: foo, weight: 3}]` and asserts the helper returns `{"foo": 3}`.
- [x] New test `test_arc_scoped_drivers_id_wins_when_both_present` covers `{id: A, name: B, weight: 4}` and asserts the helper returns `{"A": 4}` (not `{"B": 4}`).
- [x] New test `test_arc_006_estimator_fidelity_activates` writes a temp arc YAML matching arc-006's real shape (one scoped driver with name+weight+approved_at, no id) and asserts `_arc_scoped_drivers_for_task({"arc_id": "test-arc-006"})` yields `{"estimator-fidelity": 3}`.
- [x] All 12 existing T-2357 tests still PASS (no regression on id-form helper).
- [x] Total bvp_estimator test count ≥ 125 (was 122). Wider BVP regression net ≥ 207/207 (was 204).
- [x] Reviewer PASS on T-2358 (no FAIL).

### Human-omitted
<!-- All ACs agent-verifiable. -->

### Human-template
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
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

python3 -m pytest tests/unit/test_bvp_estimator.py -q > /tmp/.t2358-pytest.out 2>&1; grep -q "passed" /tmp/.t2358-pytest.out && ! grep -qE "failed|error" /tmp/.t2358-pytest.out
grep -q 'sd.get("id") or sd.get("name")' agents/termlink/bvp-estimator/estimator.py
out=$(bin/fw reviewer T-2358 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-12 — name-form is canonical, id-form is the outlier

- **What changed:** I assumed arc-011's `id: D-DISJOINT` shape was canonical when I wrote T-2357. Survey of `lib/arc.sh:1258` showed the actual write path emits `{name, weight, approved_at}` with no `id` field — name-form is canonical, arc-011 is the outlier (T-2344 retroactive prompt-template chose `id:`). arc-006's `estimator-fidelity` has been approved since 2026-05-21 and my T-2357 silently never surfaced it.
- **Plan impact:** T-2357 close gate ran with reviewer PASS + regression net green, but missed this — the test fixtures all used id-form (matching arc-011) so the name-form path was never exercised. Lesson sibling to T-2168 estimator handler-dict-vs-policy decoupling (T-2343): when there are MULTIPLE write paths for the same data shape, the test fixtures must reflect ALL shapes.
- **Triggered:** This task (T-2358). Folded the name-fallback into the same helper, preserving id-wins-on-tie for arc-011 backwards-compat.

## Recommendation

**Recommendation:** GO

**Rationale:** Closes T-2357's silent miss class. 8/8 Agent ACs verified: helper now accepts `id` or `name` (id wins on tie); 3 new tests + 12 pre-existing T-2357 tests stay green (125/125 PASS file-local + 207/207 wider BVP regression net, +3/+3 deltas verified); reviewer R-1b9ed536 PASS, 0 findings. Activates arc-006's already-approved `estimator-fidelity` scoped driver — pre-T-2358 it was silently inert, post-T-2358 it dispatches via `score_free_driver` fallback (no dedicated handler shipped for this driver yet).

**Evidence:**
- `agents/termlink/bvp-estimator/estimator.py:135-148` — `sd.get("id") or sd.get("name")` widening with comment citing lib/arc.sh:1258 as origin
- `tests/unit/test_bvp_estimator.py:1180-1220` — 3 new tests (name-only form, id-wins-on-tie, arc-006 estimator-fidelity end-to-end)
- Reviewer verdict: R-1b9ed536 PASS, 0 findings
- Regression net: 207/207 BVP tests PASS

**Activation note for the operator:** arc-006's `estimator-fidelity` is APPROVED (since 2026-05-21) — this fix lets the BVP estimator score arc-006 member tasks against it via the `score_free_driver` keyword-fallback path. A separate dedicated handler (similar to T-2356's D-DISJOINT / D-WIRE-EVIDENCE) could ship later if estimator-fidelity warrants its own rubric — not in scope for this hot-fix.

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

### 2026-06-12T23:32:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2358-bvp-estimator-arc-scoped-driver-helper--.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dba8d2fc
- **Timestamp:** 2026-06-12T23:35:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-12T23:35:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
