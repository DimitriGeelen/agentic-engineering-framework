---
id: T-1842
name: "fabric exclude: blindness — honor exclude in do_scan + do_drift (consumer Penelope
  T-1458 pickup)"
description: >
  fabric exclude: blindness — honor exclude in do_scan + do_drift (consumer Penelope
  T-1458 pickup)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [consumer-pickup, fabric, bug]
components: [agents/fabric/lib/drift.sh, agents/fabric/lib/register.sh]
related_tasks: []
arc_id: project-shape-resilience
created: 2026-05-14T22:30:42Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-22T08:10:03Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 0
      D4: 0
    rationale: D1=2 (body:concern-ref); D2=2 (body:telemetry-or-audit-entry); 
      D3=0 (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=2 (body:telemetry-or-audit-entry); 
      D3=0 (no-signal); D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1842: fabric exclude: blindness — honor exclude in do_scan + do_drift (consumer Penelope T-1458 pickup)

## Context

`fw fabric scan` and `fw fabric drift` both read `.fabric/watch-patterns.yaml` `patterns:` but silently drop the `exclude:` key on each pattern. Consequence (Penelope T-1458, 2026-05-07): in projects with `node_modules/` (or any bulk-excluded tree), bash globstar descends into the excluded subtree, creating 5946/6339 (93.8%) junk cards. Undetected for ~22 days because both code paths share the bug.

The framework's own schema (`web/templates/*.html` with `exclude: ["web/templates/_*.html"]`) demonstrates the documented behaviour, and both `_*.html` and `*.html` files end up with separate cards in `.fabric/components/` — confirming the exclude is documentation-only at the current code paths.

Origin pickup: `framework:pickup` offset 5 (RCA) + offset 6 (Penelope's working patches).
Code surface: `agents/fabric/lib/register.sh:272-322` (do_scan) and `agents/fabric/lib/drift.sh:5-46` (do_drift).

## Acceptance Criteria

### Agent
- [x] `agents/fabric/lib/register.sh` `do_scan` filters paths matching per-pattern `exclude:` (fnmatch on relative path)
- [x] `agents/fabric/lib/drift.sh` `do_drift` filters paths matching per-pattern `exclude:` (same predicate)
- [x] Both call sites delegate to a single shared Python helper (DRY — the same exclude bug shouldn't be able to recur in one path independently)
- [x] Top-level `data.get('exclude', [])` also honored (Penelope's RCA references it; safe to support both since the YAML schema admits either)
- [x] `tests/unit/test_fabric_exclude.bats` pins both `do_scan` and `do_drift` against a synthetic fixture with per-pattern + top-level exclude
- [x] `bash -n` on both modified files

### Human
- [ ] [REVIEW] Confirm the fix is the right shape — shared helper vs. inlined duplicates — and that it doesn't regress the per-pattern schema framework already uses for `web/templates/_*.html`
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && git diff master -- agents/fabric/lib/register.sh agents/fabric/lib/drift.sh agents/fabric/lib/expand_patterns.py`
  2. Inspect that the exclude predicate is shared via one helper (not two inlined copies that could drift)
  3. `cd /opt/999-Agentic-Engineering-Framework && bin/fw fabric drift 2>&1 | grep -E "Summary|unregistered:" | head -3` — confirm framework's own scan summary stays sane
  4. Skim the synthetic fixture in `tests/unit/test_fabric_exclude.bats` — is it realistic (per-pattern exclude as documented in the framework's own watch-patterns)?

  **Expected:** Single helper used by both, framework drift summary unchanged from prior run (no new false positives).
  **If not:** Note the divergence; agent should reroute fix through a single function.

## Verification

bash -n agents/fabric/lib/register.sh
bash -n agents/fabric/lib/drift.sh
test -f agents/fabric/lib/expand_patterns.py
python3 -c "import yaml; yaml.safe_load(open('.fabric/watch-patterns.yaml'))"
python3 agents/fabric/lib/expand_patterns.py .fabric/watch-patterns.yaml >/tmp/t1842-helper.out 2>&1
test -s /tmp/t1842-helper.out
bats tests/unit/test_fabric_exclude.bats > /tmp/t1842-bats.out 2>&1
grep -q "^ok " /tmp/t1842-bats.out

## RCA

**Symptom:** Consumer Penelope (email-archive, T-1458 2026-05-07) reported `.fabric/components/` had 5946/6339 (93.8%) junk cards from `node_modules/` after `fw fabric scan`. `fw fabric drift` reported 7455 false-positive "unregistered" files (the same node_modules tree, surfaced from the other direction). Undetected for ~22 days (oldest junk card mtime 2026-04-22).

**Root cause:** Both `do_scan` (`agents/fabric/lib/register.sh:305-311`) and `do_drift` (`agents/fabric/lib/drift.sh:37-43`) read `data.get('patterns', [])` from `watch-patterns.yaml` and emitted only `p['glob']`. The schema documents `exclude:` (both per-pattern and arguably top-level) — the framework's own `watch-patterns.yaml` uses it for `web/templates/_*.html` — but neither reader consumed it. Shell globstar then expanded the glob and descended into every excluded subtree.

**Why structurally allowed:**
1. Schema-vs-code drift: the YAML schema accepted `exclude:` (no rejection by yaml.safe_load), but the code silently ignored unknown keys. No lint or test enforced that documented keys are read.
2. Two parallel readers with the same shape, no shared helper. The duplication meant the bug had to manifest twice for the symptom to surface twice — and even then, an operator seeing 5946 junk cards reads it as "noisy project" rather than "broken scanner".
3. Framework's own usage masked the bug: the framework has no `node_modules/` or other bulk-excluded tree, so its drift summary always read `unregistered: 0`. The framework was blind to a class of bug that only surfaces in real consumer trees — same shape as G-063 (project-shape conflation).

**Prevention:**
1. Centralised expansion in `agents/fabric/lib/expand_patterns.py` — single source of truth for glob + exclude. If a future agent inlines a python heredoc again in either call site, the DRY test (`bats T-1842 case 9`) fires.
2. Synthetic fixture in the bats test exercises a node_modules-shaped tree the framework itself doesn't have — closes the framework-blindness gap for this specific class.
3. Test case 5 pins the framework's own `web/templates/_*.html` shape — regression catches if a future change drifts away from per-pattern exclude support.

What the prevention does **not** cover (out of scope for this task):
- Schema-vs-reader divergence in general (other keys may be silently dropped elsewhere) — would need a separate lint task per schema. Not filed; record as observable if a similar bug surfaces.

## Evolution

### 2026-05-14 — fits project-shape-resilience arc retroactively
- **What changed:** Originally filed as a standalone fabric-bug. During Recommendation drafting it became clear this is the same class as the rest of the arc: framework code that assumes one project shape (no `node_modules/`) and silently misbehaves on another (consumer with bulk-excluded trees). Framework's own drift always read `unregistered: 0` because the framework has no node_modules; the framework was blind to its own bug.
- **Plan impact:** Tagged `arc:project-shape-resilience` post-implementation. Triggers Evolution gate (this section). RCA section 3 already names the class explicitly ("same shape as G-063 (project-shape conflation)").
- **Triggered:** No new tasks — the prevention (DRY test + synthetic fixture exercising a node_modules-shaped tree) is in scope. If schema-vs-reader divergence surfaces elsewhere (e.g. `audit/watch.yaml`, `cron-registry.yaml` keys silently dropped), file as a separate lint task — out of scope here.

### 2026-05-14 — exclude semantics: top-level vs per-pattern
- **What changed:** Penelope's RCA (offset 5) referenced top-level `exclude:`. The framework's own `watch-patterns.yaml` uses per-pattern `exclude:` (under each pattern dict). I initially assumed only per-pattern needed support; reading both reports confirmed both shapes are valid.
- **Plan impact:** Helper supports both — top-level applies to all patterns, per-pattern adds to that. No schema migration required; existing files (per-pattern) keep working; new ones (top-level for bulk exclusion) just work.
- **Triggered:** Test case 2 (per-pattern), test case 3 (top-level), test case 6 (deduplication when patterns overlap with different excludes). All shipped.

## Recommendation

**Recommendation:** GO — ship the fix.

**Rationale:** The bug is documented (Penelope's 22-day undetected silent-junk class), the fix shape is minimal (one shared helper + two call-site swaps), the framework's own scan is unchanged (`unregistered: 0` before and after), and the prevention layer (DRY test pinning both call sites to the same helper) closes the class. The Human AC is a shape-review on the helper-vs-inline trade-off — that judgement call is what the human should adjudicate, not whether the code works.

**Evidence:**
- Bats: 11/11 tests pass (`tests/unit/test_fabric_exclude.bats`)
- Framework's own `bin/fw fabric drift`: `unregistered: 0` (unchanged from baseline)
- Helper smoke against framework's own watch-patterns: 258 paths emitted, deduplicated, exclude honored
- Per-pattern exclude case (case 2): node_modules tree skipped, src/*.js paths kept
- Top-level exclude case (case 3): cross-pattern exclude honored
- Framework's web/_*.html shape (case 5): fragment files correctly excluded from the parent pattern
- DRY pin (case 9): both call sites reference `$LIB_DIR/expand_patterns.py` — if either drifts to an inlined python heredoc again, this test fires

**Origin:** `framework:pickup` offset 5 (Penelope's RCA, 2026-05-07) + offset 6 (her working patches).

## Decisions

### 2026-05-14 — shared helper vs. inlined exclude predicate
- **Chose:** Single Python helper at `agents/fabric/lib/expand_patterns.py`, called from both register.sh and drift.sh.
- **Why:** The exclude bug existed identically in two parallel readers. A shared helper means the bug-class cannot recur in one path independently. The DRY test enforces this structurally — if a future agent inlines a python heredoc in either call site, the test fails.
- **Rejected:** Inlining the exclude logic in each call site's existing python heredoc. Smaller diff, but reintroduces the original duplication-shape that allowed this bug to fester for 22 days. Penelope's own working patches (pickup offset 6) used inlined Python; centralising is a small additional cost for a meaningful structural improvement.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-14T22:30:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1842-fabric-exclude-blindness--honor-exclude-.md
- **Context:** Initial task creation

### 2026-05-14T22:32:36Z — status-update [task-update-agent]
- **Change:** tags: +consumer-pickup

### 2026-05-14T22:32:42Z — status-update [task-update-agent]
- **Change:** tags: +fabric

### 2026-05-14T22:32:42Z — status-update [task-update-agent]
- **Change:** tags: +bug

### 2026-05-14T22:38:34Z — status-update [task-update-agent]
- **Change:** tags: +arc:project-shape-resilience

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f96fc282
- **Timestamp:** 2026-06-11T12:12:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-22T08:10:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
