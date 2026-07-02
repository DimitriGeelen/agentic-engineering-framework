---
id: T-1445
name: "T-1443-v1.0 Static-scan validator: anti-pattern detection on work-completed
  (4 patterns + feedback stream + task-body verdict)"
description: >
  Build v1.0 of T-1443 reviewer agent: static-scan validator hooked on `fw task update
  --status work-completed`. Detects 4 seed anti-patterns (tautology, empty-body, swallowed-errors
  / --no-verify, output-spoofing). Writes verdict to task body. Initializes append-only
  `.context/working/feedback-stream.yaml` for Spike I (override mechanism). NO escalation
  logic, NO orchestrator routing yet — those come v1.1+. v1.0 measures the unmeasured:
  % of Human ACs that are mechanically evidenceable in production data. Per T-1443
  staged micro-version rollout (D-009).

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/task-create/update-task.sh, bin/fw]
related_tasks: [T-1442, T-1443, T-954, T-1064]
created: 2026-04-25T10:17:40Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-25T22:10:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 3
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=2 (body:learning-ref); D2=4 (body:fw-audit-or-doctor); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=3 (body:typed-io-or-gate); F3=0
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
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

## v1.0 Dogfood Results (initial measurement)

Scanned all 1358 completed tasks (entire corpus to date) with the v1.0 catalogue:

| Verdict | Count | Pct |
|---------|-------|------|
| PASS    | 1343  | 98.9% |
| CONCERN | 0     | 0.0%  |
| FAIL    | 15    | 1.1%  |

Pattern fire counts: `swallowed-errors` × 15 (in 15 distinct tasks; `tautology` co-fired in 3 of those).

Inspection of the 15 FAIL findings:
- 14/15 are real signal: `|| true` after a verification command suppresses the only assertion. Examples: `bin/fw doctor >/dev/null 2>&1 || true` (T-1360, T-1356), `bash -n template.md || true` (T-1378).
- 1/15 is a false positive: T-1086 grep-of-literal-string `grep -c 'git commit --no-verify' agents/git/lib/hooks.sh` — the `--no-verify` is a search pattern, not actual usage. Detector should exclude grep/awk/sed contexts.

**v1.1 candidate tunings** (recorded as L-264):
1. Suppress swallowed-errors finding when `--no-verify` appears inside grep/awk/sed/jq pattern arguments.
2. Widen output-spoofing heuristic — zero fires across 1358 tasks suggests pattern is too narrow.
3. Add 4 candidate patterns for v1.1: empty-output-success, skip-as-pass, mock-only-integration, AC-verify-mismatch.

This is exactly the unmeasured assumption v1.0 was scoped to measure — the rate of mechanically-evidenceable false success in the historical corpus. ~1% baseline on 4 seed patterns is the foundation for v1.1 action-matrix tuning.

## Acceptance Criteria

### Agent
- [x] `lib/reviewer/static_scan.py` exists with 4 anti-pattern detectors (tautology, empty-body, swallowed-errors/--no-verify, output-spoofing)
- [x] `policy/anti-patterns.yaml` exists with 4 seed pattern definitions (id, name, detection_confidence, lie_severity, detector_ref, examples)
- [x] `bin/fw reviewer T-XXX` invokes static-scan and writes verdict to task body
- [x] `update-task.sh --status work-completed` triggers static-scan and includes verdict in commit-output
- [x] Verdict section format: `## Reviewer Verdict (v1.0)` with timestamp, scan_id, findings list (per-pattern), overall verdict (PASS/CONCERN/FAIL)
- [x] `.context/working/feedback-stream.yaml` is created on first run, structured as append-only (events: scan_emitted, verdict_recorded)
- [x] Unit tests in `tests/unit/test_reviewer_static_scan.py` — 31 test cases (>=2 positive + 2 negative per pattern + sovereignty + idempotency + stream tests)
- [x] All unit tests pass: `bin/fw test unit` (939 bats tests OK + 31 pytest tests OK; bats run 2026-04-25T10:35Z)
- [x] `bin/fw audit` passes (warn allowed, no fail) — Verified 2026-04-25T18:13Z (`bin/fw audit --quiet` rc=0). OBS-016 fix landed in T-1460 (flock guard, T-1464 lifted QUIET-only wrap); 14 audits in 14 days, no recursive-spawn.
- [x] Reviewer never modifies `### Human` AC checkboxes — enforced by code path (no AC-mutation in static_scan.py); test asserts task body checkboxes unchanged

### Human
- [x] [REVIEW] Verdict format readable + actionable in real production data
  **Steps:**
  1. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer T-1445` (will scan its own task)
  2. Open the task file and read the `## Reviewer Verdict (v1.0)` section
  3. Compare against the actual content — does the verdict feel useful?
  **Expected:** verdict is concise, evidence-cited, actionable. False-positives (if any) are obvious and easy to override.
  **If not:** capture findings in `.context/working/feedback-stream.yaml` via override; will inform v1.1 tuning

## Recommendation

**Recommendation:** GO — accept v1.0 as shipped, proceed to v1.1 tuning.

**Rationale:** The v1.0 scope was to **measure the unmeasured** — what fraction of completed work shows mechanically-evidenceable false success in production data? Result: 1.1% (15/1358 completed tasks fail static scan; 14/15 are real signal). This baseline now exists; before v1.0 it didn't. Verdict format is greppable, evidence-cited, and visible in Watchtower task pages. Default-pass behavior keeps blast radius small while v1.1 tunes the catalogue.

**Evidence:**
- 1358 completed tasks scanned, 98.9% PASS (1343), 1.1% FAIL (15) — baseline established
- 14/15 FAIL findings are real signal (e.g., `bin/fw doctor >/dev/null 2>&1 || true` hides failures behind `|| true`)
- 1 false positive identified (T-1086 grep-of-literal — flagged as v1.1 tuning candidate)
- 31 unit tests pass, 939 bats tests pass (no regression)
- Verdict block already lands on every `--status work-completed` (this task itself has one)
- v1.1 candidate tunings captured as L-264 — the override mechanism (T-1449) is already built and merged

**Out-of-scope (deferred to later micro-versions):** Layer 1 escalation (v1.1), Layer 2 risk-based human signoff (v1.1), Layer 3 daily audit cron (v1.2), per-AC granular verdicts (v1.3), orchestrator routing (v3+). All explicitly NOT in v1.0 per D-009 staged rollout.

**The Human AC asks one question:** when you read the `## Reviewer Verdict` block on this task (or any completed task), does it feel useful? If yes → check the box, close v1.0. If no → drop a note in `.context/working/feedback-stream.yaml` and we'll fold the format change into v1.1.

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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8435aa3d
- **Timestamp:** 2026-06-02T18:58:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T22:10:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Agent ACs all checked; Human AC awaiting review per Recommendation block
