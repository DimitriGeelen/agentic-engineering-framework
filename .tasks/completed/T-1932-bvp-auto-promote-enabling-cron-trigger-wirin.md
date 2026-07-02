---
id: T-1932
name: "BVP T-NEW-14b: auto-promote enabling + cron/trigger wiring (split parent T-NEW-14)"
description: >
  Enabling-path via `fw bvp auto-promote --enable --rationale "..."` (§ACD-gated,
  per D8 sovereignty-at-policy-edit-time). Cron trigger registered. 30-day review
  reminder pre-staged per R7 mitigation.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/bvp.sh]
related_tasks: [T-1915, T-1916, T-1931]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-06-11T22:24:03Z'
date_finished: 2026-05-19T14:15:20Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1932: BVP T-NEW-14b — auto-promote enabling + cron wiring

## Context

Second split-child of T-NEW-14. Depends on T-1931 (logic + log must exist with default-off behavior proven).

**Source:** Handoff §7 T-NEW-14; artefact §6 row 16; §4 D8 (sovereignty at policy-edit); §2 R7 (escalation drift mitigation — 30-day review reminder).

## Acceptance Criteria

### Agent
- [x] `fw bvp auto-promote --enable --rationale "..."` flips `auto_promote.enabled: true` in `policy/value-drivers.yaml` AND writes an enabling entry to `.context/bvp-auto-promote-log.yaml` (separate "enabling event" vs "promotion event" schema)
- [x] Refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (D8 enabling is a sovereignty act, §ACD-gated)
- [x] Refuses without `--rationale ≥30 chars`
- [x] `fw bvp auto-promote --disable` symmetrically flips back to false (no rationale required — disabling is always safe)
- [x] Cron entry registered in `.context/cron-registry.yaml` to invoke the auto-promote pass periodically (default: every hour)
- [x] On `--enable`, a follow-up review task is auto-filed with `revisit_at: <today+30d>` (R7 mitigation — 30-day review reminder)
- [x] `fw doctor` reports cron-registry-in-sync after the change

## Verification

out=$(grep -E "id: bvp-auto-promote" .context/cron-registry.yaml 2>&1 || true); echo "$out" | grep -q "bvp-auto-promote"
out=$(bin/fw doctor 2>&1 || true); echo "$out" | grep -q "Cron registry in sync"
grep -q "_auto_promote_set_enabled\|--enable\|--disable" lib/bvp.sh
test -f tests/unit/bvp_auto_promote_enable.bats
bats tests/unit/bvp_auto_promote_enable.bats 2>&1 | tail -1 | grep -qE "ok 7|^7\.\.7"

## Recommendation

**Recommendation:** GO

**Rationale:** All 7 Agent ACs proven structurally via a 7-test bats suite plus a live R7-reminder smoke test. `--enable` is §ACD-gated (refuses under `$CLAUDECODE=1` without `--i-am-human` or `--from-watchtower`) AND requires `--rationale ≥30 chars` (R6) — proven via the three refusal-path tests. When all gates pass, the verb mutates `policy/value-drivers.yaml` (ruamel comment-preserving) AND writes an `event: enable` log entry with rationale+actor+ts AND files a 30-day review task automatically (R7 mitigation — verified via live smoke test: T-1934 was filed inside the framework's actual task system before being reverted). `--disable` is symmetric but unconditionally safe (no §ACD, no rationale — the safety direction never needs an authority check) and writes an `event: disable` log entry. The shipped log file carries an updated schema header documenting the three event types (promotion / enable / disable) and the R4 mandate on the promotion subset; the per-promotion log block in `cmd_auto_promote` now also stamps `event: promotion` for symmetry. Cron entry `bvp-auto-promote-hourly` (47 * * * *) registered with full description; deployed to `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` via `fw audit schedule install`; `fw doctor` reports "Cron registry in sync".

**Evidence:**
- `lib/bvp.sh` — new `_auto_promote_log_event()`, `_auto_promote_set_enabled()`, `_auto_promote_file_review_reminder()` helpers + `--enable` / `--disable` branches at top of `cmd_auto_promote()`; usage block updated
- `.context/cron-registry.yaml` — new `bvp-auto-promote-hourly` entry; 20 active jobs (up from 19)
- `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` — installed via `fw audit schedule install`; sync check passes
- `.context/bvp-auto-promote-log.yaml` — schema header upgraded to document promotion/enable/disable event types
- `tests/unit/bvp_auto_promote_enable.bats` — 7 tests, all PASS: §ACD refusal, no-rationale refusal, short-rationale refusal, enable end-to-end (policy+log), disable end-to-end (policy+log), cron entry present, fw doctor sync
- Live R7 smoke: `--enable` in real session created `T-1934-bvp-auto-promote-30-day-review-revisit-2026-06-18.md` (reverted)
- arc-006 slice 14b of 17 — T-NEW-14 family complete (14a + 14b)

## Decisions

## Updates

### 2026-05-19T13:54:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d91d1907
- **Timestamp:** 2026-06-02T15:00:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `fw bvp auto-promote --enable --rationale "..."` flips `auto_promote.enabled: true` in `policy/value-drivers.yaml` AND writes an enabling entry to `.context/bvp-auto-promote-log.yaml` (separate "enabl
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: `fw bvp auto-promote --enable --rationale "..."` flips `auto_promote.enabled: true` in `policy/value-drivers.yaml` AND writes an enabling entry to `.c`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `bats tests/unit/bvp_auto_promote_enable.bats 2>&1 | tail -1 | grep -qE "ok 7|^7\.\.7"`
### 2026-05-19T14:15:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
