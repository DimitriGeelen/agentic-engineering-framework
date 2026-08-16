---
id: T-1446
name: "T-1443-v1.1 Reviewer agent: 4 more anti-patterns + L-264 fixes + Layer 1 escalation
  policy"
description: >
  Build v1.1 of T-1443 reviewer. (a) Fix L-264 false-positive: exclude grep/awk/sed-of-literal-string
  contexts in swallowed-errors detector. (b) Widen output-spoofing heuristic. (c)
  Add 4 patterns: empty-output-success, skip-as-pass, mock-only-integration, AC-verify-mismatch.
  (d) Add policy/escalation-patterns.yaml — Layer 1 mechanical needs-human triggers.
  (e) Add Layer 2 frontmatter fields risk/human_signoff to task creation. NO Layer
  3 audit cron yet (v1.2). Re-dogfood after to measure delta. Per D-009 staged rollout.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [reviewer-agent, ac-validation, anti-patterns, v1.1, escalation]
components: [bin/fw]
related_tasks: [T-1442, T-1443, T-1445, T-954]
created: 2026-04-25T10:47:21Z
last_update: '2026-08-16T22:24:32Z'
date_finished: 2026-04-25T14:02:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1446: T-1443-v1.1 Reviewer agent: 4 more anti-patterns + L-264 fixes + Layer 1 escalation policy

## Context

Second micro-version of T-1443 reviewer agent. Builds on T-1445 v1.0 dogfood data (L-264).

Source design: `docs/reports/T-1443-independent-reviewer-agent.md`.

**v1.1 IN scope:**
- (a) L-264 fix: exclude grep/awk/sed-of-literal contexts in swallowed-errors
- (b) Widen output-spoofing heuristic
- (c) 4 new patterns: empty-output-success, skip-as-pass, mock-only-integration, AC-verify-mismatch
- (d) `policy/escalation-patterns.yaml` — Layer 1 mechanical needs-human triggers
- (e) Layer 2 frontmatter fields `risk` (low|medium|high) and `human_signoff` (required|optional) recognised by reviewer
- (f) Re-dogfood + capture delta as L-265

**Still NOT in scope (later micro-versions):**
- Layer 3 audit cron (v1.2)
- Per-AC granular verdicts (v1.3)
- Override mechanism enforcement (v2.1+)
- Slash-command routing (v3+)

## Acceptance Criteria

### Agent
- [x] L-264-(a) fix lands: T-1086 case no longer triggers swallowed-errors finding (test asserts; live verified bin/fw reviewer T-1086 → PASS)
- [x] L-264-(b) output-spoofing widened: detector fires on at least 1 historical task in dogfood (synthetic test on widened token set)
- [x] 4 new pattern detectors land (empty-output-success, skip-as-pass, mock-only-integration, AC-verify-mismatch) with at least 2 positive + 2 negative tests each
- [x] `policy/anti-patterns.yaml` updated to v1.1-seed with 8 total patterns
- [x] `policy/escalation-patterns.yaml` exists with Layer 1 mechanical triggers (destructive-action, external-publish, cross-project-blast, secret-handling — 4 triggers)
- [x] Layer 2: reviewer reads `risk` and `human_signoff` from task frontmatter and includes in verdict envelope (Verdict.risk_declared / human_signoff_declared)
- [x] All pytest tests pass (57 total, up from 31 in v1.0)
- [x] All bats tests pass (no regression from v1.0 — `bin/fw test unit`) — 943/943 OK on 2026-04-25 (T-1458 session)
- [x] Re-dogfood delta captured as L-265

### Human
- [x] [REVIEW] v1.1 catalogue feels right vs framework directives — does the L-264 fix introduce new false-negatives?
  **Steps:**
  1. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer T-1086 --no-write` — confirm PASS
  2. Read v1.1 dogfood findings in this task body
  3. Spot-check 3 PASS tasks for false-negatives by eye (pick T-1340, T-1340, T-1240)
  **Expected:** signal/noise improves over v1.0; any new patterns flagged are real
  **If not:** record finding in `.context/working/feedback-stream.yaml`; will inform v1.2 tuning

## Verification

python3 -m pytest tests/unit/test_reviewer_static_scan.py -q
test -f policy/anti-patterns.yaml
test -f policy/escalation-patterns.yaml
python3 -c "import yaml; d=yaml.safe_load(open('policy/anti-patterns.yaml')); assert len(d.get('patterns',[]))>=8, f'expected >=8, got {len(d.get(\"patterns\",[]))}'"
python3 -c "import yaml; d=yaml.safe_load(open('policy/anti-patterns.yaml')); ids=[p['id'] for p in d['patterns']]; expected={'tautology','empty-body','swallowed-errors','output-spoofing','empty-output-success','skip-as-pass','mock-only-integration','AC-verify-mismatch'}; assert expected.issubset(set(ids)), f'missing: {expected - set(ids)}'"
python3 -c "import yaml; d=yaml.safe_load(open('policy/escalation-patterns.yaml')); assert len(d.get('triggers',[]))>=3, f'expected >=3 triggers, got {len(d.get(\"triggers\",[]))}'"
bin/fw reviewer T-1086 --no-write 2>&1 | grep -q "Overall:.*PASS"

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

### 2026-04-25T10:47:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1446-t-1443-v11-reviewer-agent-4-more-anti-pa.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1122718c
- **Timestamp:** 2026-06-02T14:57:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 2

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_reviewer_static_scan.py -q`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 7
     - evidence: `bin/fw reviewer T-1086 --no-write 2>&1 | grep -q "Overall:.*PASS"`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-project`
### 2026-04-25T14:02:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
