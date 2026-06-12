---
id: T-2357
name: "BVP estimator arc-scoped driver dispatch — wire arc YAML resolution into estimate_task() so latent D-* handlers (T-2356) fire on arc-tagged tasks"
description: >
  BVP estimator arc-scoped driver dispatch — wire arc YAML resolution into estimate_task() so latent D-* handlers (T-2356) fire on arc-tagged tasks

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bvp, estimator, arc-scoped, dispatch]
components: [agents/termlink/bvp-estimator/estimator.py, tests/unit/test_bvp_estimator.py]
related_tasks: [T-2356, T-2328, T-2329, T-2344, T-2303]
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
created: 2026-06-12T23:22:36Z
last_update: 2026-06-12T23:22:36Z
date_finished: null
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

# T-2357: BVP estimator arc-scoped driver dispatch — wire arc YAML resolution into estimate_task() so latent D-* handlers (T-2356) fire on arc-tagged tasks

## Context

T-2356 shipped `score_d_disjoint` + `score_d_wire_evidence` handlers, registered in the `handlers` dict in `estimator.py:estimate_task()`. The handlers stay LATENT because `_load_drivers()` reads only `policy/value-drivers.yaml` — arc YAMLs' `scoped_drivers:` are not consulted today. Even after the operator approves arc-011's proposed_scoped_drivers via Watchtower, no member-task scoring will include `D-DISJOINT` or `D-WIRE-EVIDENCE` until this slice extends `estimate_task()` to resolve arc-scoped drivers.

**Design (Z-hybrid: lazy arc-scope resolution at dispatch time):**

```python
def _arc_scoped_drivers_for_task(fm: dict) -> dict[str, int]:
    """T-2357 — return {driver_id: weight} from the task's arc's scoped_drivers.
    Empty dict if no arc_id, arc YAML missing, or scoped_drivers empty."""
    arc_id = fm.get("arc_id")
    if not arc_id:
        return {}
    # Try both `.context/arcs/<arc_id>.yaml` and slug fallback (T-1849 dual form).
    candidates = [PROJECT_ROOT / ".context" / "arcs" / f"{arc_id}.yaml"]
    if not candidates[0].is_file():
        # Try slug forms for arc-NNN IDs
        for arc_yaml in (PROJECT_ROOT / ".context" / "arcs").glob("*.yaml"):
            try:
                arc_data = yaml.safe_load(arc_yaml.read_text()) or {}
                if arc_data.get("id") == arc_id or arc_data.get("slug") == arc_id:
                    candidates = [arc_yaml]; break
            except yaml.YAMLError:
                continue
    out: dict[str, int] = {}
    if not candidates[0].is_file():
        return out
    try:
        arc_data = yaml.safe_load(candidates[0].read_text()) or {}
    except yaml.YAMLError:
        return out
    for sd in (arc_data.get("scoped_drivers") or []):
        d_id = sd.get("id")
        if d_id:
            out[d_id] = int(sd.get("weight", 0))
    return out
```

Then in `estimate_task()`, after `_load_drivers()` produces the global drivers dict, MERGE with the arc-scoped dict before iterating. Arc-scoped drivers do NOT override global ones if names collide (global wins by convention since they are operator-approved at the policy layer).

Out of scope for this slice: arc-scoped driver weight calibration vs global weights (M6 §ACD-gated, deferred); arc-scoped `bvp_scores_proposed:` writeback shape changes (already supports arbitrary driver IDs).

## Acceptance Criteria

### Agent
- [ ] `_arc_scoped_drivers_for_task(fm: dict) -> dict[str, int]` added to `agents/termlink/bvp-estimator/estimator.py`. Reads task's `arc_id:` frontmatter, resolves to `.context/arcs/<arc_id>.yaml` (direct + slug-fallback per T-1849 dual form), returns `{driver_id: weight}` from arc's `scoped_drivers:`. Returns `{}` on any missing/error path (no arc_id, file missing, YAML parse error, empty scoped_drivers).
- [ ] `estimate_task()` extended to merge arc-scoped drivers into the dispatch loop: after `drivers = _load_drivers()` (callers may override), if the task has `arc_id:` AND that arc has populated `scoped_drivers:`, the arc-scoped driver IDs are added to the dispatch iteration. Global drivers win on name collision (do NOT clobber operator-approved policy weights).
- [ ] When called with a task whose `arc_id: parallel-execution-aef` AND arc-011's `scoped_drivers:` contains `D-DISJOINT` (e.g. via test fixture writing to a tmp arc YAML), `estimate_task()` returns `D-DISJOINT` in the `scores:` dict with the dedicated handler's score — flips T-2356 handlers from latent to active for arc-011 tasks
- [ ] Latency / no-arc behaviour preserved: a task with no `arc_id:` (or arc YAML absent / empty `scoped_drivers:`) still produces the same `scores:` dict as before — no behavioural change for non-arc-tagged tasks. Existing 110 BVP estimator tests stay green.
- [ ] CLI/dispatch surfaces (`fw bvp` and `bvp_auto_promote`) work unchanged for the default policy case — the new helper is read-only and falls through to `{}` whenever arc context isn't present
- [ ] Test coverage in `tests/unit/test_bvp_estimator.py`: per-leg coverage of the helper (no arc_id → `{}`; arc YAML missing → `{}`; valid YAML with scoped_drivers → returns map; invalid YAML → `{}`; arc_id slug-form resolves via dual-form fallback) + integration coverage of dispatch (task with arc-011 tag + arc YAML with D-DISJOINT in scoped_drivers → result has D-DISJOINT score; collision with global driver → global wins). ≥ 8 new tests, all PASS
- [ ] Reviewer PASS on T-2357: `bin/fw reviewer T-2357` returns `Overall: PASS` or `CONCERN`, no FAIL
- [ ] Regression net: 192/192 existing BVP-related tests stay green after the change. Verification block runs `python3 -m pytest tests/unit/ -q -k 'bvp or estimator'` and asserts no failures

<!-- All ACs agent-verifiable (backend Python, no UI / no operator judgment).
     Same shape as T-2356 sibling — Human block omitted entirely. -->

### Human-omitted
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

### 2026-06-12T23:22:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2357-bvp-estimator-arc-scoped-driver-dispatch.md
- **Context:** Initial task creation
