---
id: T-1445
name: "T-1443-v1.0 Static-scan validator: anti-pattern detection on work-completed (4 patterns + feedback stream + task-body verdict)"
description: >
  Build v1.0 of T-1443 reviewer agent: static-scan validator hooked on `fw task update --status work-completed`. Detects 4 seed anti-patterns (tautology, empty-body, swallowed-errors / --no-verify, output-spoofing). Writes verdict to task body. Initializes append-only `.context/working/feedback-stream.yaml` for Spike I (override mechanism). NO escalation logic, NO orchestrator routing yet — those come v1.1+. v1.0 measures the unmeasured: % of Human ACs that are mechanically evidenceable in production data. Per T-1443 staged micro-version rollout (D-009).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [reviewer-agent, ac-validation, anti-patterns, v1.0, static-scan]
components: []
related_tasks: [T-1442, T-1443, T-954, T-1064]
created: 2026-04-25T10:17:40Z
last_update: 2026-04-25T10:17:40Z
date_finished: null
---

# T-1445: T-1443-v1.0 Static-scan validator: anti-pattern detection on work-completed (4 patterns + feedback stream + task-body verdict)

## Context

First micro-version of T-1443 reviewer agent. **Scope:** static-scan only. **Goal:** measure the unmeasured assumption — what fraction of Human ACs are mechanically evidenceable in real production data?

Design source: `docs/reports/T-1443-independent-reviewer-agent.md` (Recommendation block + Rollout Addendum).

**v1.0 NOT in scope (deferred to later micro-versions):**
- Layer 1 escalation patterns (v1.1)
- Layer 2 frontmatter-declared `risk` / `human_signoff` (v1.1)
- Layer 3 audit cron (v1.2)
- Per-AC granular verdicts (v1.3)
- Slash-command routing / orchestrator integration (v3+)
- Override mechanism enforcement (v2.1+; v1.0 only initializes the stream)
- Anti-pattern catalogue expansion to 12 categories (v3+; v1.0 ships 4 seed patterns)

**v1.0 IN scope:**
- Lib `lib/reviewer/static_scan.py` with 4 anti-pattern detectors
- Hook into `update-task.sh` on `--status work-completed`
- Verdict written to task body `## Reviewer Verdict (v1.0)` section
- `.context/working/feedback-stream.yaml` initialized + structurally append-only
- Anti-pattern catalogue YAML at `policy/anti-patterns.yaml` (4 seed patterns)
- Unit tests for each pattern detector
- `bin/fw reviewer` CLI entry point (manual invocation also supported)

## Acceptance Criteria

### Agent
- [x] `lib/reviewer/static_scan.py` exists with 4 anti-pattern detectors (tautology, empty-body, swallowed-errors/--no-verify, output-spoofing)
- [x] `policy/anti-patterns.yaml` exists with 4 seed pattern definitions (id, name, detection_confidence, lie_severity, detector_ref, examples)
- [x] `bin/fw reviewer T-XXX` invokes static-scan and writes verdict to task body
- [x] `update-task.sh --status work-completed` triggers static-scan and includes verdict in commit-output
- [x] Verdict section format: `## Reviewer Verdict (v1.0)` with timestamp, scan_id, findings list (per-pattern), overall verdict (PASS/CONCERN/FAIL)
- [x] `.context/working/feedback-stream.yaml` is created on first run, structured as append-only (events: scan_emitted, verdict_recorded)
- [x] Unit tests in `tests/unit/test_reviewer_static_scan.py` — 31 test cases (>=2 positive + 2 negative per pattern + sovereignty + idempotency + stream tests)
- [ ] All unit tests pass: `bin/fw test unit`
- [ ] `bin/fw audit` passes (warn allowed, no fail)
- [x] Reviewer never modifies `### Human` AC checkboxes — enforced by code path (no AC-mutation in static_scan.py); test asserts task body checkboxes unchanged

### Human
- [ ] [REVIEW] Verdict format readable + actionable in real production data
  **Steps:**
  1. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer T-1445` (will scan its own task)
  2. Open the task file and read the `## Reviewer Verdict (v1.0)` section
  3. Compare against the actual content — does the verdict feel useful?
  **Expected:** verdict is concise, evidence-cited, actionable. False-positives (if any) are obvious and easy to override.
  **If not:** capture findings in `.context/working/feedback-stream.yaml` via override; will inform v1.1 tuning

## Verification

python3 -m pytest tests/unit/test_reviewer_static_scan.py -q
test -f lib/reviewer/static_scan.py
test -f policy/anti-patterns.yaml
python3 -c "import yaml; d=yaml.safe_load(open('policy/anti-patterns.yaml')); assert len(d.get('patterns',[]))>=4, f'expected >=4 patterns, got {len(d.get(\"patterns\",[]))}'"
python3 -c "import yaml; d=yaml.safe_load(open('policy/anti-patterns.yaml')); ids=[p['id'] for p in d['patterns']]; expected={'tautology','empty-body','swallowed-errors','output-spoofing'}; assert expected.issubset(set(ids)), f'missing: {expected - set(ids)}'"
bin/fw reviewer T-1445 > /tmp/t1445-self-review.txt 2>&1
grep -q "Reviewer Verdict" .tasks/active/T-1445*.md
test -f .context/working/feedback-stream.yaml

## Decisions

### 2026-04-25 — Library + thin CLI architecture
- **Chose:** Python lib at `lib/reviewer/static_scan.py` + bash CLI shim invoking it
- **Why:** Static-scan logic needs YAML/regex/AST work that's awkward in pure bash; Python tested at length in `tests/unit/`. Bash shim aligns with rest of `bin/fw` style.
- **Rejected:** Pure bash (regex-only would miss output-spoofing detection); Pure Python entry point (breaks `fw <verb>` discoverability).

### 2026-04-25 — Verdict written to task body, not bus envelope
- **Chose:** v1.0 writes verdict to `## Reviewer Verdict (v1.0)` section in task .md file
- **Why:** Visible in Watchtower task page without new infrastructure; one-screen UX; greppable. Bus envelope adds complexity v1.0 doesn't need.
- **Rejected:** `fw bus post` envelope (defer to v1.2 when we add signed digest); separate `.context/reviews/` dir (creates discovery problem; task body is the natural surface).

### 2026-04-25 — Sovereignty enforcement at code-path level for v1.0
- **Chose:** static_scan.py never opens task file in write mode for AC sections; only appends to ## Reviewer Verdict
- **Why:** v1.0 only needs one of the three layers (code-path). Schema + UI enforcement come v1.2/v1.3. Keep blast radius small.
- **Rejected:** Full 3-layer enforcement now (premature; 5 invariants doc says staged is correct).

## Updates

### 2026-04-25T10:17:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1445-t-1443-v10-static-scan-validator-anti-pa.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.0)

- **Scan ID:** R-28e7d652
- **Timestamp:** 2026-04-25T10:23:05Z
- **Catalogue:** v1.0-seed
- **Overall:** PASS
- **Findings:** none
