---
id: T-1747
name: "harden web._discover_project_root + remove stray /.framework.yaml (G-069)"
description: >
  harden web._discover_project_root + remove stray /.framework.yaml (G-069)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, watchtower, path-discovery]
components: [bin/fw, tests/unit/test_project_root_discovery.py, web/shared.py]
related_tasks: [T-1727, T-1310]
arc_id: orchestrator-rethink
created: 2026-05-05T17:57:51Z
last_update: '2026-08-16T22:24:43Z'
date_finished: 2026-05-05T18:05:58Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1747: harden web._discover_project_root + remove stray /.framework.yaml (G-069)

## Context

G-069 follow-up. During T-1727 ship the Watchtower :3002 instance silently resolved `PROJECT_ROOT=/` after a restart — `/escalation-drift` returned the empty-state page despite a live 170-row v0.5 LATEST.yaml. Two compounding bugs:

1. **Filesystem pollution.** A stray `/.framework.yaml` (15 bytes, `version: 1.5.0`, dated 2026-05-01, owned by root) sits at filesystem root. Origin uncertain — likely a misfired `fw upgrade` from earlier exploration.
2. **Discovery walk has no upper bound.** `web/shared._discover_project_root` walks ancestors looking for `.framework.yaml` and only stops at fs root. From inside the framework repo with no `PROJECT_ROOT` env, it climbs past `FRAMEWORK_ROOT` and lands on `/` because the marker file there matches.

The framework process running from FRAMEWORK_ROOT should never resolve PROJECT_ROOT *above* FRAMEWORK_ROOT — that climb is structurally wrong. Fix the walk so framework-repo discovery falls through to the FRAMEWORK_ROOT fallback explicitly. Add a `fw doctor` host-hygiene warning so the next stray `/.framework.yaml` surfaces loudly. Pin the regression so future refactors don't reintroduce the climb.

Per gap resolution_path:
1. Delete `/.framework.yaml`
2. Harden `_discover_project_root` — refuse to walk past FRAMEWORK_ROOT
3. `fw doctor` warns if `/.framework.yaml` exists
4. Regression test pinning the resolved root

## Acceptance Criteria

### Agent
- [x] **A1.** `/.framework.yaml` no longer exists (or, if it does, the discovery walk no longer returns `/` from FRAMEWORK_ROOT cwd). Verifiable: `! test -f /.framework.yaml || python3 -c 'import sys; sys.path.insert(0,"web"); from shared import _discover_project_root, FRAMEWORK_ROOT; from pathlib import Path; r=_discover_project_root(FRAMEWORK_ROOT); assert r != Path("/"), f"discovery returned {r}"'`
- [x] **A2.** `_discover_project_root(start)` does NOT return `/` when `start` is inside FRAMEWORK_ROOT and the only marker above FRAMEWORK_ROOT is `/.framework.yaml`. Verifiable via unit test.
- [x] **A3.** `_discover_project_root(start)` still returns the correct consumer root when called from a real consumer dir (i.e. the framework-aware bound MUST NOT break the `fw init`/consumer use case). Verifiable via unit test (mock cwd = `/tmp/<fakeconsumer>` with `.framework.yaml` present).
- [x] **A4.** `_resolve_project_root()` from cwd=FRAMEWORK_ROOT with `PROJECT_ROOT` env unset returns `(FRAMEWORK_ROOT, "framework")` — NOT `(/, "discovered")`. Verifiable via unit test.
- [x] **A5.** `fw doctor` emits a WARN line when `/.framework.yaml` exists at filesystem root (host-hygiene check). Verifiable: `bin/fw doctor 2>&1 | grep -i 'framework\.yaml.*root\|stray.*framework'` (gated on file existing) or grep on the `--check` line in the doctor source.
- [x] **A6.** Regression test in `tests/unit/` pins A2+A3+A4 — refactors that reintroduce the unbounded climb fail the test.

## Verification

# T-1747 verification — each line a single shell command (L-356, single-line only).
# A1: stray file gone OR discovery from framework root no longer returns /
test ! -f /.framework.yaml
# A2/A3/A4/A6: regression test passes
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_project_root_discovery.py -q --no-header
# A5: fw doctor mentions the host-hygiene check (either fires or names the check)
cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor > /tmp/_t1747_doctor.out 2>&1; grep -q -E 'framework\.yaml|stray' /tmp/_t1747_doctor.out
# Sanity: web.shared imports clean
cd /opt/999-Agentic-Engineering-Framework && python3 -c "import sys; sys.path.insert(0,'.'); from web import shared; print('OK')"

## RCA

**Symptom:** Watchtower :3002 returned the empty-state page on `/escalation-drift` after a restart during T-1727 build, despite a live 170-row `escalation-drift-LATEST-v0.5.yaml` on disk. Every project-relative route that read `.context/working/...` content silently degraded. No error logs — just empty pages. Workaround applied at the time: explicit `PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework` in the launch command.

**Root cause:** Two compounding flaws.
1. A stray `/.framework.yaml` (15 bytes, `version: 1.5.0`, dated 2026-05-01, owned by root) sat at the filesystem root. Origin uncertain — most likely a misfired earlier `fw upgrade` exploration that walked into `/` and wrote there.
2. `web/shared._discover_project_root` walked ancestors looking for `.framework.yaml` and only stopped at the filesystem root. From inside FRAMEWORK_ROOT with `PROJECT_ROOT` env unset, it climbed past FRAMEWORK_ROOT and matched the stray marker at `/`, returning `Path("/")`. `_resolve_project_root` happily returned that, and every blueprint built `(PROJECT_ROOT / ".context" / ...)` paths against `/`, hit non-existent files, and rendered the empty-state branch.

The framework process running from FRAMEWORK_ROOT had no business resolving PROJECT_ROOT to an *ancestor* of FRAMEWORK_ROOT. That climb is structurally wrong regardless of whether a stray file is present — it's a discovery routine without an upper bound.

**Why structurally allowed:** No test pinned `_resolve_project_root()` for the framework-cwd case. The function had a 3-source fallback (env / discovered / FRAMEWORK_ROOT) but the discovery path was free to capture any ancestor with a marker, and "discovered" silently won over the FRAMEWORK_ROOT fallback. Empty-state pages render cleanly in Flask — no 5xx, no log line — so the failure was visually identical to a fresh project. The bash side (`lib/paths.sh`) uses `git rev-parse --show-toplevel` which is naturally bounded by the git tree, so this class of bug never surfaced there.

**Prevention:**
- `_discover_project_root` now refuses to walk past FRAMEWORK_ROOT when `start` is inside it. Returns None at the boundary, which forces `_resolve_project_root` into the explicit FRAMEWORK_ROOT fallback (source label `framework`).
- `tests/unit/test_project_root_discovery.py` (7 cases) pins:
  - the bound (walks from FRAMEWORK_ROOT and a subdir don't escape it);
  - the consumer-use-case (cwd outside FRAMEWORK_ROOT with a real marker still resolves correctly);
  - the resolve-fallback contract (env unset + framework cwd → `(FRAMEWORK_ROOT, "framework")`);
  - a direct G-069 replay (synthetic stray marker above a fake FRAMEWORK_ROOT does not capture).
- `fw doctor` host-hygiene WARN fires loudly when `/.framework.yaml` exists, so the next instance surfaces during the next routine `fw doctor` run instead of waiting for a Watchtower restart to produce silent degradation.

## Evolution

### 2026-05-05 — bash-vs-python parity claim was misleading
- **What changed:** Original docstring said `_discover_project_root` "matches bash `paths.sh` behaviour (T-1310)". Read `lib/paths.sh` to confirm parity before refactoring; bash side actually uses `git rev-parse --show-toplevel`, naturally bounded by the git tree. Python uses an unbounded marker walk. They never matched — the docstring was aspirational.
- **Plan impact:** No plan change, but the new docstring drops the false parity claim and explicitly documents the bound (T-1747, G-069). Future refactors won't think they need to match an unbounded bash walk that never existed.
- **Triggered:** None — observation captured in code comment.

### 2026-05-05 — bound logic chosen over marker validation
- **What changed:** Considered two fix shapes: (a) bound the walk at FRAMEWORK_ROOT when start is inside it, or (b) validate the discovered marker (e.g. require sibling `bin/fw` or `.tasks/`). Picked (a) — simpler, has no false-negatives on legitimate consumer dirs that lack `bin/fw` (consumers vendor under `.agentic-framework/bin/fw`, not `bin/fw`). (b) would have required additional consumer-shape heuristics with their own edge cases.
- **Plan impact:** AC list pinned to bound-based pinning (test names reflect this). The `fw doctor` host-hygiene check (A5) and the regression test (A6) compose with the bound rather than replace it.
- **Triggered:** None — design choice locked at filing.

## Decisions

### 2026-05-05 — fix the bound, not the marker semantics
- **Chose:** Bound `_discover_project_root` to refuse walking past FRAMEWORK_ROOT when start is inside it.
- **Why:** The framework process running from FRAMEWORK_ROOT has no semantic reason to climb into ancestors. The bound is simple, has no consumer-shape heuristics, and composes cleanly with the existing `_resolve_project_root` fallback chain (env / discovered / framework). Resolves the bug class, not just this instance.
- **Rejected:** Marker-validation (require `bin/fw` or `.tasks/` next to the marker). Adds heuristics that need maintenance per consumer shape, and would still allow climbing if a consumer-shaped ancestor existed. Bound is structurally tighter.

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 agent ACs pass. Verification gate runs clean (4/4 commands green). The fix addresses both the immediate G-069 incident and the structural class — `web._discover_project_root` is now bounded against FRAMEWORK_ROOT, regression test pins the bound for future refactors, and `fw doctor` will surface any future stray `/.framework.yaml` loudly during the next routine doctor run instead of letting it cause silent Watchtower degradation. No human-judgement criteria — the bound is a deterministic structural property pinned by unit tests.

**Evidence:**
- `web/shared.py:24-58` — bounded walk + `_is_within` helper
- `bin/fw:720-728` — host-hygiene WARN block (Check 2c)
- `tests/unit/test_project_root_discovery.py` — 7/7 PASS (`python3 -m pytest tests/unit/test_project_root_discovery.py -v`)
- `/.framework.yaml` removed (verified `test ! -f /.framework.yaml`)
- `fw doctor` WARN fires when stray file present (verified by transient touch/rm test)
- All 4 Verification gate commands green

## Updates

### 2026-05-05T17:57:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1747-harden-webdiscoverprojectroot--remove-st.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ed6c0a9d
- **Timestamp:** 2026-06-02T14:59:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-05T18:05:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
