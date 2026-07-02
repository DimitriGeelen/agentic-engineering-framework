---
id: T-1649
name: "Tag-format lint for live TermLink sessions (framework-side half of W10 #4)"
description: >
  W10 #4 — typo'd or wrong-separator task-type tag silently routes to default specialist.
  Framework-side half of T-1649 split: extend agents/audit/orchestrator-mcp-scan.sh
  to
  inspect `termlink list --json` and warn on unrecognized tag prefixes that resemble
  canonical orchestrator prefixes (task-type:, role:, task:, model:, host=, project=).
  Surfaces in Watchtower /orchestrator and via `fw audit --section orchestrator`.
  Cross-repo half (termlink-side spawn validator) goes as a TermLink push to
  termlink-agent — the framework cannot edit /opt/termlink directly. Tracks G-061
  closure.
  Origin: docs/reports/T-1641-worker-10-defenses.md item #4.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004, agents/audit/orchestrator-mcp-scan.sh, 
      web/blueprints/orchestrator.py, web/templates/orchestrator.html]
related_tasks: [T-1641, T-1644, T-1064, T-1646, T-1647]
arc_id: orchestrator-rethink
created: 2026-05-01T12:20:27Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-01T12:56:47Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 2
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=2 
      (components:substrate-edit); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1649: Tag-format lint for live TermLink sessions (framework-side)

## Context

T-1647 surfaced the symptom: 22 live sessions, 0 tagged `task-type:`. Drilling down,
20/22 use `task=` (wrong separator vs canonical `task:`), 1 uses `role=` (vs canonical
`role:`). The orchestrator's tag parser silently ignores these, so any specialist
routing or per-task affinity falls back to defaults — invisibly.

This task adds a tag-format **lint** to the framework audit (the non-cross-repo half).
The actual fix lives in /opt/termlink (validate at spawn) and is filed as a TermLink
push to termlink-agent.

## Acceptance Criteria

### Agent
- [x] `agents/audit/orchestrator-mcp-scan.sh` gains a `tag_format_warnings` finding category
- [x] Output YAML at `.context/audits/orchestrator-LATEST.yaml` includes a `findings.tag_format_warnings` list when drift exists; entries name the bad prefix, count, and nearest canonical match
- [x] Lint detects the 4 known drift patterns: `task=` → `task:`, `role=` → `role:`, `tasktype:` → `task-type:`, `task_type:` → `task-type:`
- [x] `web/blueprints/orchestrator.py` reads `findings.tag_format_warnings` and exposes it to the template
- [x] `web/templates/orchestrator.html` renders the new finding category in the drift panel
- [x] TermLink push delivered to termlink-agent with the spawn-validator proposal (cross-repo half)
- [x] Audit YAML continues to validate as YAML (no schema break)

### Human

(none — purely structural lint, all checks deterministic)

## Verification

# Shell commands that MUST pass before work-completed.
test -x agents/audit/orchestrator-mcp-scan.sh
# Script exit 1 = warn (drift detected), not a script failure. We only fail on exit 2 (regression).
sh -c 'bash agents/audit/orchestrator-mcp-scan.sh >/dev/null 2>&1; [ $? -ne 2 ]'
python3 -c "import yaml; d=yaml.safe_load(open('.context/audits/orchestrator-LATEST.yaml').read()); assert 'tag_format_warnings' in d.get('findings', {}), 'missing tag_format_warnings key'"
python3 -c "import yaml; d=yaml.safe_load(open('.context/audits/orchestrator-LATEST.yaml').read()); w=d['findings']['tag_format_warnings']; assert any(e.get('bad') == 'task=' for e in w), 'expected task= drift in live data'"
python3 -c "import ast; ast.parse(open('web/blueprints/orchestrator.py').read())"
curl -sf -o /dev/null -w "%{http_code}\n" http://localhost:3000/orchestrator | grep -q 200

## Decisions

### 2026-05-01 — Cross-repo split

- **Chose:** Ship framework-side lint in this task; file termlink-side validator as a TermLink push to termlink-agent under their own task ID.
- **Why:** Framework cannot edit /opt/termlink directly (memory: feedback_no_cross_repo_edits). Cross-repo proposals go via TermLink, not direct edits.
- **Rejected:** Bundling both into one task — would force a cross-repo edit or block T-1649 on termlink-agent's response window.

## Updates

### 2026-05-01T12:20:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** Initial task creation under T-1644 Arc C.

### 2026-05-01T14:50:00Z — promoted-and-scoped [agent]
- **Action:** Promoted horizon later→now, status captured→started-work.
- **Context:** Continuing orchestrator-arc work (Arc C drift defenses) per autonomous-mode directive.
- **Scope change:** Split into framework-side lint (this task) + cross-repo proposal (TermLink push to termlink-agent for /opt/termlink spawn validator).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-abf3452f
- **Timestamp:** 2026-06-02T14:58:52Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 2

**Per-AC findings:**

- **AC#5 (Agent)** — `web/templates/orchestrator.html` renders the new finding category in the drift panel
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/orchestrator.html in: `web/templates/orchestrator.html` renders the new finding category in the drift panel`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `curl -sf -o /dev/null -w "%{http_code}
" http://localhost:3000/orchestrator | grep -q 200`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-repo`
### 2026-05-01T12:56:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-01T18:58:38Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
