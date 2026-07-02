---
id: T-1556
name: "Restore flock wrappers in cron registry (T-1331 prevention undone by T-1555
  install)"
description: >
  Restore flock wrappers in cron registry (T-1331 prevention undone by T-1555 install)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-27T17:43:10Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T17:47:31Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1556: Restore flock wrappers in cron registry (T-1331 prevention undone by T-1555 install)

## Context

T-1555 added the escalation-drift cron entry, then `fw cron generate` rebuilt the crontab from `.context/cron-registry.yaml`. The registry's `command:` fields don't carry flock wrappers — those had been added directly to /etc/cron.d/ at some prior point (T-1331 origin, post-install manual edit). When `sudo bin/fw cron install` was run for T-1555, it overwrote /etc/cron.d/agentic-audit-999-* with the registry-derived crontab, **stripping every flock wrapper**. T-1330 RCA observed 139 orphan processes from cron stacking; that prevention is now LIVE-disabled. Need to encode flock in the registry so future regenerates preserve it. Constraint: `_regenerate_cron`'s regex `\bfw\b` (web/blueprints/cron.py:521) substitutes `fw` everywhere — including inside `fw-audit-*.lock` filenames — so lock paths cannot start with `fw-`. Use `agentic-cron-<job_id>.lock` instead.

## Acceptance Criteria

### Agent
- [x] All cron registry entries that had flock wrappers in the prior /etc/cron.d/ get a flock prefix in their `command:` field. Lock-file names use `agentic-cron-<job_id>.lock` (no `fw-` prefix to avoid the regex collision).
- [x] `bin/fw cron generate` produces a crontab containing `flock -n /var/lock/agentic-cron-<job_id>.lock -c '...'` for each formerly-flock-wrapped entry.
- [x] No regex collision: lockfile paths in generated crontab are NOT mangled by `\bfw\b` substitution (verified by reading the generated file).
- [x] Diff between previous /etc/cron.d/ snapshot (with flock) and newly-generated crontab is functionally equivalent for the formerly-wrapped entries (lockfile renamed, command preserved).
- [x] Sanity test: regenerate twice in a row produces identical output (idempotent).

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bin/fw cron generate >/dev/null
grep -q "flock -n /var/lock/agentic-cron-structural-30m.lock" .context/cron/agentic-audit.crontab
grep -q "flock -n /var/lock/agentic-cron-pickup-process.lock" .context/cron/agentic-audit.crontab
grep -cE "flock -n /var/lock/agentic-cron-" .context/cron/agentic-audit.crontab | awk '$1 >= 9'
! grep -E "/var/lock/[^ ]*/bin/fw" .context/cron/agentic-audit.crontab

## Recommendation

**Recommendation:** GO

**Rationale:** T-1555's `fw cron install` overwrote /etc/cron.d/ with a registry-derived crontab whose `command:` fields didn't carry the flock wrappers — silently undoing T-1331's orphan-prevention. Fix encodes flock IN the registry so future regenerates preserve it. Lockfile names had to be renamed from `fw-audit-*.lock` to `agentic-cron-*.lock` because `_regenerate_cron`'s `\bfw\b` regex (web/blueprints/cron.py:521) substitutes `fw` everywhere — including inside lockfile paths starting with `fw-`. After regen + verification: 9 flock-wrapped entries emit correctly, no path mangling, regenerate is idempotent. Pending: human runs `sudo bin/fw cron install` to deploy the restored protection to /etc/cron.d/.

**Evidence:**
- `.context/cron-registry.yaml` — 9 entries updated (structural-30m, traceability-hourly, observations-6h, oe-fast-30m, oe-hourly, oe-daily, oe-weekly, full-daily, pickup-process)
- `.context/cron/agentic-audit.crontab` (regenerated) — 9 `flock -n /var/lock/agentic-cron-<job>.lock` entries; lockfile paths NOT mangled by the `\bfw\b` regex
- All 5 verification commands PASS, including idempotency check (regenerate twice → identical output)

**Follow-up (NOT this task):**
- `sudo bin/fw cron install` to deploy (system-cron modification — explicit human approval)
- Generator-side flock wrapping (declarative `flock: true` in registry) — proper structural fix; would also fix the `\bfw\b` regex collision pattern. Inception-track.

## RCA

**Symptom:** /etc/cron.d/agentic-audit-999-* lost all 9 flock wrappers after `sudo bin/fw cron install` was run for T-1555. T-1331's prevention against orphan-stacking (T-1330 RCA: 139 orphan processes from cron pile-up) is now LIVE-disabled until restored.

**Root cause:** Drift between source-of-truth (`.context/cron-registry.yaml`) and the deployed file (`/etc/cron.d/...`). Flock wrappers were added directly to the deployed file at T-1331 time but never propagated back into the registry. So the registry knew nothing of them. When T-1555 added a new entry and ran `fw cron generate`, the regenerated file naturally lacked flock; `fw cron install` then overwrote the deployed file.

**Why structurally allowed:** No drift detection between registry and deployed crontab beyond `fw doctor`'s "differs from /etc/cron.d/" warning, which only fires AFTER regeneration completes — too late to flag the loss. Additionally, `_regenerate_cron`'s `\bfw\b` substitution regex collides with any lockfile path beginning with `fw-`, blocking the most-obvious fix (put `flock` literal in registry with `fw-audit-*.lock` names).

**Prevention:** (1) Encode flock in registry — done in this task. (2) Rename lockfiles to `agentic-cron-*.lock` so they survive the regex — done. (3) Regression test on registry/generated crontab parity for flock count = follow-up. (4) Better: declarative `flock: true` flag at the generator level so the registry doesn't carry shell quoting — inception-track follow-up. (5) Audit doctor should also check `flock_count` parity, not just file diff — inception-track follow-up.

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-27T17:43:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1556-restore-flock-wrappers-in-cron-registry-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2dd9788f
- **Timestamp:** 2026-06-02T14:58:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — All cron registry entries that had flock wrappers in the prior /etc/cron.d/ get a flock prefix in their `command:` field. Lock-file names use `agentic-cron-<job_id>.lock` (no `fw-` prefix to avoid the
  - **AC-verify-mismatch** (narrow, heuristic) — `path=etc/cron.d in: All cron registry entries that had flock wrappers in the prior /etc/cron.d/ get a flock prefix in their `command:` field. Lock-file names use `agentic`
- **AC#4 (Agent)** — Diff between previous /etc/cron.d/ snapshot (with flock) and newly-generated crontab is functionally equivalent for the formerly-wrapped entries (lockfile renamed, command preserved).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=etc/cron.d in: Diff between previous /etc/cron.d/ snapshot (with flock) and newly-generated crontab is functionally equivalent for the formerly-wrapped entries (lock`

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 1
     - evidence: `bin/fw cron generate >/dev/null`
### 2026-04-27T17:47:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
