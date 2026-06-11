---
id: T-1803
name: "Workflow coverage audit: stale-workflow WARN class — workflows declared but
  never fired (or last-fired >90d ago) surface as audit warn (T-1802 follow-up)"
description: >
  Workflow coverage audit: stale-workflow WARN class — workflows declared but never
  fired (or last-fired >90d ago) surface as audit warn (T-1802 follow-up)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [audit, observability]
components: [C-004, lib/workflow_coverage.py, 
      tests/unit/test_orchestrator_workflow_coverage.py, 
      tests/unit/test_workflow_coverage.py, web/blueprints/orchestrator.py, 
      web/templates/orchestrator.html]
related_tasks: [T-1798, T-1799, T-1800, T-1801, T-1802]
arc_id: orchestrator-rethink
created: 2026-05-13T06:40:00Z
last_update: '2026-06-11T22:23:25Z'
date_finished: 2026-05-13T06:51:33Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 4
      D3: 3
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=4 (body:fw-audit-or-doctor); 
      D3=3 (body:component-discoverability); D4=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 4
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 2
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=4 (body:fw-audit-or-doctor); 
      D3=3 (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=2 (components:substrate-edit); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1803: Workflow coverage audit: stale-workflow WARN class

## Context

T-1802 surfaced "Last dispatched" per workflow on `/orchestrator` and proved the deprecation-candidate pattern: 5 of 8 declared workflows have never dispatched. The data is now visible to operators looking at the web page, but the **audit doesn't know about it** — `fw audit -s orchestrator` still reports the coverage check as PASS when 5 declared-but-dead workflows clutter the registry.

This slice ratchets the recency data into an audit-time signal — but as a **WARN class, not FAIL**:

- **WARN, not FAIL.** Stale workflows are not runtime crashes (unlike unroutable worker_kind or pi-missing-provider). They're maintenance signals — "consider deprecating". Treating them as FAIL would convert a soft signal into a hard gate (audit.sh exits non-zero, cron alarms fire), which is wrong scope.
- **Threshold:** 90 days since last dispatch, OR never dispatched. 90d picked as a sensible default ≈ one quarter; configurable later if needed (T-819 4-tier config pattern, defer until pressure).
- **No new helper field for `ok`:** the existing `report["ok"]` keeps its meaning (no runtime traps). Stale workflows surface in a NEW field `stale_workflows: [...]` and via a separate `warn` boolean. Audit emits PASS/WARN/FAIL — WARN doesn't fail the cron.

Design decision captured: WARN vs FAIL — see `## Decisions`.

## Acceptance Criteria

### Agent

**1. Helper — stale detection**
- [x] `lib/workflow_coverage.enrich_with_dispatch_recency` (or new helper `flag_stale_workflows`) populates a NEW top-level field `stale_workflows: [{"name", "worker_kind", "last_dispatched"}]` for workflows where `last_dispatched is None` OR is more than `stale_threshold_days` ago.
- [x] Helper takes optional `stale_threshold_days: int = 90` and optional `now_iso: str = None` (test-injectable wall clock).
- [x] `report["ok"]` is **unchanged** by staleness — stale doesn't fail the audit.
- [x] NEW top-level field `warn: bool` — True iff `stale_workflows` non-empty AND `ok` is True (a WARN doesn't override a FAIL).

**2. Audit emit — WARN class**
- [x] `agents/audit/audit.sh` workflow coverage block emits:
      - PASS when `report["ok"]` AND not `report["warn"]`
      - WARN when `report["ok"]` AND `report["warn"]` — message lists stale workflow names
      - FAIL when not `report["ok"]` (unchanged from today)
- [x] WARN message format matches existing audit WARNs (uses the existing `warn` shell function).

**3. format_audit_line update**
- [x] When `warn` is True, the audit-line summary includes "N workflow(s) stale: name1, name2" line alongside any other reasons. PASS line gets a "+0 stale" suffix only when threshold-checked.

**4. Web template — surface stale state**
- [x] Workflow coverage panel header — when `workflow_coverage.warn` is True (and ok is True), badge becomes `badge-warn` "WARN" with text "All workflows route, but N workflow(s) stale (no dispatch in 90d)."
- [x] Stale workflows in the table get a marker on the `Last dispatched` cell when they're stale-and-routable (e.g. `<span class="badge-warn">stale</span>` alongside the date / `never`).

**5. Tests — helper**
- [x] `tests/unit/test_workflow_coverage.py` gains:
      - `test_workflow_never_dispatched_marked_stale` — workflow with `last_dispatched=None` → `stale_workflows` contains it; `warn=True`; `ok` unchanged.
      - `test_workflow_dispatched_recently_not_stale` — workflow dispatched within 90d → not in stale list.
      - `test_workflow_dispatched_long_ago_marked_stale` — workflow dispatched 91d ago → stale.
      - `test_warn_false_when_no_stale` — all workflows fresh → `warn=False`.
      - `test_warn_does_not_override_fail` — workflow unroutable AND stale → `ok=False`, `warn` doesn't fire (FAIL absorbs WARN).
      - `test_threshold_configurable` — pass `stale_threshold_days=1` → workflows dispatched 2d ago marked stale.

**6. Tests — template**
- [x] `tests/unit/test_orchestrator_workflow_coverage.py` gains:
      - `test_panel_renders_warn_state_when_only_stale` — all workflows route but one never dispatched → page shows WARN badge, not OK/FAIL.

**7. Verification**
- [x] `python3 -m pytest tests/unit/test_workflow_coverage.py tests/unit/test_orchestrator_workflow_coverage.py -v` exits 0.
- [x] `bash agents/audit/audit.sh -s orchestrator 2>&1 | grep -E "(PASS|WARN|FAIL).*[Ww]orkflow.*coverage"` — emits the new line.

### Human

- [ ] [REVIEW] WARN message clarity: confirm that an operator scanning audit output can tell the difference between "broken" (FAIL) and "stale" (WARN) without ambiguity.
      **Steps:**
      1. Run `bin/fw audit -s orchestrator` from a shell.
      2. Read the workflow coverage line.
      3. If the substrate has stale workflows (likely — 5 declared but never fired), confirm the line reads as WARN with the stale workflow names.
      **Expected:** WARN message lists stale workflows; PASS/FAIL classification clearly distinct.
      **If not:** Note ambiguity and which workflow names confuse.

## Verification

python3 -m pytest tests/unit/test_workflow_coverage.py tests/unit/test_orchestrator_workflow_coverage.py -v
# Direct helper check (audit.sh has a lock + SIGPIPE under `set -o pipefail`):
PROJECT_ROOT="$(pwd)" python3 -c "import sys; sys.path.insert(0, 'lib'); import workflow_coverage; r = workflow_coverage.check_workflow_dispatcher_coverage(); r = workflow_coverage.enrich_with_dispatch_recency(r); r = workflow_coverage.flag_stale_workflows(r); sys.exit(0 if 'warn' in r and 'stale_workflows' in r else 1)"

## RCA

## Recommendation

**Recommendation:** GO — converts T-1802's recency data into an audit-time soft signal without overloading FAIL semantics.

**Rationale:** T-1802 surfaced staleness on the web; this slice surfaces it in `fw audit -s orchestrator` as a NEW WARN class. The audit chain now reads at three levels of severity — PASS (all healthy), WARN (something to maintain), FAIL (something to fix). The semantic separation matters: 5 stale workflows are not a crash, they're a deprecation prompt; treating them as FAIL would either page operators on non-incidents or force defensive deprecations. The WARN class fits the existing audit.sh helper (`warn` shell fn with 3-arg signature), the helper API stays pure (`flag_stale_workflows` returns a new dict, doesn't mutate), and the threshold (90d) is param-injectable without env-var plumbing — config can be added later when needed.

**Evidence:**
- `lib/workflow_coverage.flag_stale_workflows()` — pure: deepcopy + new `stale_workflows` field + `warn` bool. FAIL absorbs WARN (warn=False when ok=False).
- `agents/audit/audit.sh` — new exit-code 2 case → WARN with stale workflow names + mitigation hint.
- `web/blueprints/orchestrator.py:_workflow_coverage()` — calls `flag_stale_workflows` after enrichment; try/except shielded.
- `web/templates/orchestrator.html` — three-state badge (OK / WARN / FAIL) + per-row `stale` markers in the Last dispatched cell.
- `tests/unit/test_workflow_coverage.py` — 7 new tests (never-dispatched, recent, long-ago, no-stale, FAIL absorbs WARN, configurable threshold, audit-line). 26/26 green.
- `tests/unit/test_orchestrator_workflow_coverage.py` — 1 new test (WARN state renders). 10/10 green.
- Direct verify on live substrate: RC=2 (WARN), 5 stale workflows surfaced by name (cheap-research, design-dialogue, grilling, inception, ollama-research).
- Live page confirmed: WARN badge + 5 per-row `stale` badges visible.

**Headline mechanic:** `bin/fw audit -s orchestrator` → reads `Workflow dispatcher coverage:` → if 5 workflows are dead, the line begins `[WARN]` (not `[FAIL]`, not `[PASS]`) and names the stale workflows; same view on `/orchestrator` as a yellow WARN badge with per-row stale markers.

## Evolution

### 2026-05-13 — stale-workflow WARN class shipped

- **What changed:** The biggest design call was WARN vs FAIL — captured up-front in Decisions (so future agents reading the task understand why the audit doesn't gate on stale). WARN preserves FAIL semantics for genuine crashes and lets staleness be a maintenance signal. The helper API ended up cleaner than expected: `flag_stale_workflows` takes the post-enrichment report and is a pure transform, so the audit can chain `check → enrich → flag` in 3 explicit lines instead of one fat call. Exit code 2 is the standard audit signal for WARN — bash case-stmt makes the dispatch trivial.
- **Plan impact:** The Workflow coverage audit check now has a 3-state ladder (PASS / WARN / FAIL). The web panel mirrors it (OK / WARN / FAIL badges). The substrate observability quartet on `/orchestrator` continues to read cleanly: Dispatch substrate → Outcome quality → Workflow coverage (3-state, 3 columns now telling the maintenance story) → Learned routing.
- **Triggered:** None autonomously. Natural follow-ups: (a) deprecate the 5 surfaced stale workflows (proposal task, since deprecation is a policy decision); (b) `FW_STALE_WORKFLOW_DAYS` env var plumbing if a project pushes back on 90d (no pressure yet); (c) similar stale-signal pattern for unused dispatchers in `_DISPATCHERS` (e.g. `Task` declarable-but-unroutable now also unused) — but that's a different observability dimension.

## Decisions

### 2026-05-13 — WARN, not FAIL, for stale workflows

- **Chose:** Stale workflows surface as audit WARN, not FAIL. `report["ok"]` unchanged by staleness; new `warn` field is independent.
- **Why:** Unroutable / missing-provider workflows are runtime crashes (FAIL is correct). Stale workflows are maintenance signals — "consider deprecating" — not runtime errors. Converting them to FAIL would (a) trip the cron-driven audit and page operators on a non-incident, (b) confuse the FAIL semantics (binary: ship-broken vs. ship-clean), (c) force agents to either deprecate workflows defensively or `--force` past the gate. WARN preserves the soft-signal semantics.
- **Rejected:** FAIL for all stale (too noisy, wrong scope). WARN-then-FAIL ladder (over-engineering for current scale; can be added later if patterns emerge).

### 2026-05-13 — 90-day threshold, not configurable yet

- **Chose:** Hardcode `STALE_THRESHOLD_DAYS = 90` as module constant; helper accepts `stale_threshold_days` param for test injectability.
- **Why:** No live evidence yet that the threshold needs tuning per-project. Adding `FW_STALE_WORKFLOW_DAYS` env var + `.framework.yaml` plumbing is premature (T-819 pattern only when needed). The param signature is forward-compatible — pluming can be added later without breaking callers.
- **Rejected:** Configurable via env var (premature). Configurable via .framework.yaml only (same).

## Evolution

## Updates

### 2026-05-13T06:40:00Z — task-created
- **Action:** Created task
- **Context:** Named follow-up from T-1802 Evolution. Soft-signal class (WARN, not FAIL) keeps audit semantics clean.

## Reviewer Verdict (v1.4)

- **Scan ID:** R-511a4e1d
- **Timestamp:** 2026-05-18T09:30:56Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#5 (Agent)** — `agents/audit/audit.sh` workflow coverage block emits:
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: `agents/audit/audit.sh` workflow coverage block emits:`
- **AC#13 (Agent)** — `bash agents/audit/audit.sh -s orchestrator 2>&1 | grep -E "(PASS|WARN|FAIL).*[Ww]orkflow.*coverage"` — emits the new line.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: `bash agents/audit/audit.sh -s orchestrator 2>&1 | grep -E "(PASS|WARN|FAIL).*[Ww]orkflow.*coverage"` — emits the new line.`
### 2026-05-13T06:51:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
