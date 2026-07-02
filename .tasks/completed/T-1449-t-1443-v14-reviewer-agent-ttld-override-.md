---
id: T-1449
name: "T-1443-v1.4 Reviewer agent: TTL'd override mechanism (suppress known false-positive
  findings)"
description: >
  Fifth micro-version of T-1443 reviewer per D-009. Adds per-(task, pattern, ac_index)
  overrides with TTL — humans/authorized agents waive a known false-positive finding
  for a bounded window. Reviewer filters findings through active overrides; suppressed
  findings emit override_applied events to feedback-stream.yaml for audit. fw reviewer
  override add/list/prune/remove subcommands. Out of scope: Pass A drift (v1.5), pattern
  catalogue expansion (v3+).

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [bin/fw, lib/reviewer/override_cli.py, lib/reviewer/overrides.py, 
      tests/unit/test_reviewer_overrides.py]
related_tasks: [T-1443, T-1445, T-1446, T-1447, T-1448]
created: 2026-04-25T11:14:00Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-25T18:17:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1449: T-1443-v1.4 Reviewer agent: TTL'd override mechanism

## Context

Reviewer fires the same false-positive on every re-scan. Without a way to acknowledge "this is a known FP for documented reasons", the signal-to-noise ratio of the verdict erodes — humans learn to ignore CONCERN/FAIL banners. v1.4 adds bounded-time overrides:

- Override declaration: `(task_id, pattern_id, ac_index?)` + reason + TTL → stored in `.context/working/reviewer-overrides.yaml`
- Active overrides suppress matching findings before verdict computation
- Suppressed findings emit `kind: override_applied` events to feedback-stream (full audit trail)
- TTL: when current time > expires_at, override is dropped on next scan; expired overrides are reported in verdict
- `fw reviewer override` subcommands for lifecycle management

Antifragile properties:
- TTL forces re-evaluation — overrides cannot become permanent silent waivers
- Suppressions are logged, not invisible — audit can count them
- Overrides cannot create false positives, only suppress true positives → fail-closed safe

**v1.4 IN scope:**
- `lib/reviewer/overrides.py` — load, match, prune
- `scan_task` filters findings, populates `verdict.suppressed_count` and `verdict.expired_overrides`
- Feedback-stream events: `override_applied`, `override_expired`
- `bin/fw reviewer override add T-XXX --pattern X [--ac N] --reason "..." [--ttl 90d]`
- `bin/fw reviewer override list` — active + days remaining
- `bin/fw reviewer override prune` — drops expired entries
- `bin/fw reviewer override remove <override_id>` — manual removal
- Verdict rendering shows suppressed count + expired overrides if non-zero
- Tests: ≥6 new (load empty, load multi, match exact, match wildcard ac, ttl expiry, prune, suppression event)

**Out of scope:**
- Authority gate on who can add overrides (v2.1 — sovereignty enforcement)
- Watchtower UI for overrides (v1.5 with audit page)
- Pass A drift re-verification (v1.5)

## Acceptance Criteria

### Agent
- [x] `lib/reviewer/overrides.py` exists with `Override` dataclass + `load_overrides`, `is_overridden`, `prune_expired`, `add_override`, `remove_override` functions
- [x] Override schema: `id`, `task_id`, `pattern_id`, `ac_index` (optional), `reason`, `expires_at` (ISO 8601 UTC), `added_by`, `added_at`
- [x] `scan_task` filters findings through `is_overridden`; suppressed findings appear in `verdict.suppressed` and emit `override_applied` events
- [x] Expired overrides are detected during scan, surfaced in `verdict.expired_overrides`, and emit `override_expired` events
- [x] `bin/fw reviewer override add T-XXX --pattern X --reason "..."` creates entry with default TTL 90 days
- [x] `bin/fw reviewer override list` prints table with override id, task, pattern, ac, expires_at, days_remaining
- [x] `bin/fw reviewer override prune` removes expired entries; idempotent
- [x] `bin/fw reviewer override remove <id>` removes specified entry
- [x] Verdict rendering shows "Suppressed: N (by override)" when N > 0
- [x] At least 6 new tests covering: empty file, multi-entry load, exact match, ac-wildcard match, TTL expiry, prune, suppression-event emission (15 new tests in `tests/unit/test_reviewer_overrides.py`)
- [x] All existing tests still pass (68 from v1.3 + 15 new = 83 total)
- [x] Self-dogfood: real override on T-1020 — audit confirmed PASS=1177→1178, CONCERN=158→157, suppressed=2; L-268 captured
- [x] Pass B audit (`bin/fw reviewer audit`) now applies overrides and reports `suppressed_total` + `active_overrides` in YAML output

### Human
- [x] [REVIEW] Override mechanism is safe to leave active without supervision
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer override list`
  2. Verify TTL on each entry is sensible (default 90 days)
  3. Check `.context/working/reviewer-overrides.yaml` for any unexpected entries
  **Expected:** Override list contains only documented entries with future expiry dates
  **If not:** `bin/fw reviewer override prune` for expired; `bin/fw reviewer override remove <id>` for suspicious

## Verification

python3 -m pytest tests/unit/ -k reviewer -q
python3 -c "from lib.reviewer.overrides import Override, load_overrides; print('overrides module loads')"
python3 -c "from lib.reviewer.static_scan import VERSION; assert VERSION == 'v1.4', VERSION"
bin/fw reviewer override list
bin/fw reviewer T-1448 --no-write

## Decisions

### 2026-04-25 — Override storage location
- **Chose:** `.context/working/reviewer-overrides.yaml` (per-project, working memory)
- **Why:** Overrides describe project-local accepted exceptions, not framework policy. `.context/working/` is right tier (vs `policy/` which is framework-shipped and gets sync'd by `fw upgrade`).
- **Rejected:** `policy/reviewer-overrides.yaml` — `fw upgrade` would clobber consumer overrides

### 2026-04-25 — TTL default
- **Chose:** 90 days default; per-entry --ttl override
- **Why:** Long enough to outlast a sprint, short enough to force quarterly re-review. TTL is the antifragile property — without it, overrides drift to permanent silent waivers.
- **Rejected:** No default (forced explicit) — too much friction; users would set very long TTLs anyway

### 2026-04-25 — ac_index as optional wildcard
- **Chose:** Override without `ac_index` matches ALL findings of (task, pattern); with ac_index matches only that AC
- **Why:** Verification-level findings have no AC; wildcard handles them naturally. Per-AC overrides still possible when needed.
- **Rejected:** Mandatory ac_index with -1 sentinel — uglier API

## v1.4 Dogfood Results

End-to-end live test on T-1020 (`AC-verify-mismatch` x 2 fires):

| State                           | Verdict | Findings | Suppressed |
|---------------------------------|---------|----------|------------|
| No override                     | CONCERN |   2      |   0        |
| Wildcard override on T-1020     | PASS    |   0      |   2        |
| Per-AC override (--ac 1)        | CONCERN |   1      |   1        |

Pass B audit shifts (with 1 active wildcard override on T-1020):
- PASS:    1177 → 1178 (+1)
- CONCERN:  158 → 157 (-1)
- AC-verify-mismatch fires: 192 → 190 (-2 suppressed)
- New audit YAML keys: `suppressed_total: 2`, `active_overrides: 1`, `suppressed_fire_counts: {AC-verify-mismatch: 2}`

Antifragile properties verified:
- TTL forces re-evaluation (default 90d, override-able per entry)
- Suppressions emit `override_applied` to feedback-stream
- Expired overrides → `override_expired` events; not silently dropped
- Malformed `expires_at` treated as expired (fail-closed)
- Malformed YAML entries skipped on load (fail-soft)

L-268 captured. Foundation ready for v1.5 (Pass A drift re-verification + Watchtower override UI).

## Recommendation

**Recommendation:** GO

**Rationale:** All 12 Agent ACs verified — override module + dataclass + 4 CLI verbs + suppression rendering + audit integration all land. 15 new unit tests, 83 total passing (no regression). Self-dogfood completed: real T-1020 override produced expected delta (PASS 1177→1178, CONCERN 158→157). Decisions documented (storage tier, default 90-day TTL). The Human AC is a "safe to leave running" sanity check — TTL is precisely the antifragile property the design adds.

**Evidence:**
- lib/reviewer/overrides.py — Override dataclass + 5 functions
- bin/fw reviewer override {add,list,prune,remove} — all 4 verbs working
- Verdict `suppressed` + `expired_overrides` populated in `scan_task`
- 15/15 new tests in tests/unit/test_reviewer_overrides.py + 68 v1.3 = 83 total
- L-268 captured (T-1020 dogfood)
- `bin/fw reviewer audit` reports `suppressed_total` + `active_overrides` in YAML output
- Decisions: storage in `.context/working/` (not policy/), 90-day TTL default — both rationaled

## Updates

### 2026-04-25T11:14:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1449-t-1443-v14-reviewer-agent-ttld-override-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b9a1eca7
- **Timestamp:** 2026-06-02T14:57:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T18:17:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
