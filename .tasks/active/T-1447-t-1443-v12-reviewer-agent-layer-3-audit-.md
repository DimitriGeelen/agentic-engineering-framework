---
id: T-1447
name: "T-1443-v1.2 Reviewer agent: Layer 3 audit cron + AC-verify-mismatch transitive-coverage tuning"
description: >
  v1.2 of T-1443 reviewer. (a) Daily audit cron — Pass A drift re-verification, Pass B catalogue re-scan. Fail-soft. Output into reviewer-audit.yaml. Pure compute, no caching (antifragile). (b) AC-verify-mismatch tuning per L-265: add transitive-coverage heuristic — exempt paths exercised by test runners (bin/fw test unit covers all bats files). Per D-009 staged rollout.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [reviewer-agent, ac-validation, audit-cron, v1.2, antifragile]
components: []
related_tasks: [T-1443, T-1445, T-1446]
created: 2026-04-25T10:54:18Z
last_update: 2026-04-25T10:54:18Z
date_finished: null
---

# T-1447: T-1443-v1.2 Reviewer agent: Layer 3 audit cron + AC-verify-mismatch transitive-coverage tuning

## Context

Third micro-version of T-1443 reviewer. Adds the Layer 3 safety net + tunes AC-verify-mismatch.

**v1.2 IN scope:**
- Layer 3 audit cron (`bin/fw reviewer audit`):
  - Pass B (catalogue re-scan): re-runs reviewer over all completed tasks; new patterns might catch things old runs missed
  - Output: `.context/audits/reviewer/YYYY-MM-DD.yaml`
  - Fail-soft (T3): cron failures don't block other framework operations
  - Antifragile: pure compute, no caching, pure re-verification
- AC-verify-mismatch transitive-coverage heuristic per L-265:
  - If verification runs `bin/fw test unit` → exempt all paths covered by `tests/unit/*.bats`
  - If verification runs `pytest tests/` → exempt all .py files under that root
  - Reduces FP from 226 → expected ~50% lower
- Cron registry entry for daily run
- Watchtower template entry (basic — full UI in v1.5)

**Out of scope (deferred):**
- Pass A drift re-verification (re-run task verification scripts) — high blast radius, deferred to v1.5 with isolation
- Per-AC granular verdicts (v1.3)
- Override mechanism enforcement (v2.1+)

## Acceptance Criteria

### Agent
- [x] `bin/fw reviewer audit` exists — runs Pass B (re-scan all completed tasks with current catalogue)
- [x] Output `.context/audits/reviewer/YYYY-MM-DD.yaml` is valid YAML with: scan_date, catalogue_version, escalation_version, totals (PASS/CONCERN/FAIL/needs_human), pattern_fire_counts, escalation_fire_counts, top_findings (5 by frequency)
- [x] Cron registry entry added (`.context/cron-registry.yaml`) — daily at 04:37
- [x] AC-verify-mismatch transitive-coverage: when verification runs `bin/fw test unit`, paths in `tests/unit/*.bats` / `lib/` / `agents/` are exempted; 4 new tests assert this
- [x] Re-dogfood with v1.2 — AC-verify-mismatch fires dropped 226→192 (15% reduction); result captured as L-266
- [x] All pytest tests pass (62 total, up from 57 in v1.1)
- [ ] No bats regression (`bin/fw test unit`) — pending separate run

### Human
- [ ] [RUBBER-STAMP] Run `bin/fw reviewer audit` and confirm a YAML report appears in `.context/audits/reviewer/`
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer audit`
  2. `ls -la .context/audits/reviewer/`
  3. `cat .context/audits/reviewer/$(date +%Y-%m-%d).yaml | head -30`
  **Expected:** YAML file exists with totals + pattern counts populated
  **If not:** check stderr from the cron command; capture in feedback-stream.yaml

## Verification

python3 -m pytest tests/unit/test_reviewer_static_scan.py -q
bin/fw reviewer audit
test -f ".context/audits/reviewer/$(date +%Y-%m-%d).yaml"
python3 -c "import yaml; d=yaml.safe_load(open(f'.context/audits/reviewer/$(date +%Y-%m-%d).yaml')); assert 'totals' in d and 'pattern_fire_counts' in d"
grep -q "reviewer-audit" .context/cron-registry.yaml

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

### 2026-04-25T10:54:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1447-t-1443-v12-reviewer-agent-layer-3-audit-.md
- **Context:** Initial task creation
