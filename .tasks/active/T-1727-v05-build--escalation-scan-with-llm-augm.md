---
id: T-1727
name: "v0.5 build — escalation-scan with LLM augmentation (T-1726 GO conditional)"
description: >
  v0.5 build — implements T-1726 GO decision: escalation-scan v0 augmented with LLM verdict
  per candidate, dispatched via orchestrator (worker_kind=ollama-loop default + cloud fallback,
  cost-capped). Wires fw resolver dispatch into oe-daily cron, captures outcomes via T-1697
  back-prop hook, surfaces dispatches on /orchestrator. Closes G-064 (orchestrator first real
  consumer) via T-1688 option 4. Now ready: T-1726 GO recorded; T-1741/T-1743 confirmed
  prompt-triage NO-GO; T-1744 inception names this task as the live G-064 mitigation path.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [arc:orchestrator-rethink, T-1726-implementation, G-064-closure-pilot, ready-on-t-1744-go]
components: []
related_tasks: [T-1688, T-1726, T-1741, T-1743, T-1744, T-1737]
created: 2026-05-04T21:39:23Z
last_update: 2026-05-05T10:48:46Z
date_finished: null
---

# T-1727: v0.5 build — escalation-scan with LLM augmentation (T-1726 GO conditional)

## Context

**🔒 BLOCKED on T-1726 GO recording.** Task pre-filed per CLAUDE.md
"Post-Grill Governance Closure (L-349)" pattern: after writing
Recommendation, the build sibling is filed at captured/horizon-next so
it surfaces immediately on GO without a separate filing step.

Implements T-1726 Recommendation if and when it reaches GO. Headline
mechanic locked from T-1726 filing:
> *"Daily oe-daily cron triggers v0.5 → for each v0 candidate, dispatch
> via fw resolver dispatch with task_type=escalation-triage → ollama-local
> grades each candidate (real symptom-fix vs false positive) → outcome
> row written to dispatch-outcomes.jsonl → /orchestrator page shows
> dispatches accumulating + per-task-type model preferences shifting as
> route_cache learns."*

## Acceptance Criteria

### Agent (locked at T-1726 filing — do not modify without ## Evolution entry)

- [ ] **A1** New workflow file `prompts/escalation-triage.yaml` (or
  inline in default workflow) with `worker_kind` accepted by validator,
  `task_type: escalation-triage`, ollama-local default + cloud fallback,
  cost cap configured.
- [ ] **A2** New tool `tools/escalation-scan-v0.5.py` (sibling of v0)
  reads `.context/working/escalation-drift-LATEST.yaml`, dispatches one
  triage call per candidate via `fw resolver dispatch`, writes
  `.context/working/escalation-drift-LATEST-v0.5.yaml` with `verdict`
  + `reasoning` per candidate, captures outcomes via existing T-1697
  back-prop hook.
- [ ] **A3** Idempotency: re-running v0.5 on the same candidate within
  N days (configurable, default 7) skips dispatch (mtime/checksum guard).
- [ ] **A4** `oe-daily` cron wires v0.5 after v0 (additive, never
  replaces). Failure of v0.5 must not impair v0's report emission.
- [ ] **A5** Watchtower surface: either augment existing v0 panel with
  a `triage` column or add `/embeddings`-style v0.5 panel (decision
  during build). Playwright test pins visibility (per T-1575 — element-
  presence grep is forbidden).
- [ ] **A6** Spike 2 ground truth recorded in `docs/reports/T-1727-v0-5-disagreement-rate.md`:
  LLM verdict vs heuristic verdict on the 30-day backlog, ≥10%
  disagreement to confirm A1 of T-1726.
- [ ] **A7** ## Evolution log populated at completion (Evolution-gate
  from T-1718 fires on this arc-tagged build task).
- [ ] **A8** Bats coverage: ≥1 test per AC; new components fabric-
  registered; `fw audit` clean.
- [ ] **A9** Two pre-existing minor items from T-1726 Spike 1 either
  fixed or filed as separate tasks: (a) `worker_kind: ollama-loop`
  validator rejection in `lib/resolver.py`, (b) `<!-- resolver:
  unresolved $VARs: ['VAR'] -->` template leak in `prompts/default.md`.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

# A1 — workflow file exists, validator-clean
test -f prompts/escalation-triage.md || test -f prompts/escalation-triage.yaml
{ bin/fw doctor 2>&1 || true; } | grep -q "workflow.*escalation-triage" && \
  ! { bin/fw doctor 2>&1 || true; } | grep -q "INVALID.*escalation-triage"

# A2 — tool exists and parses
test -f tools/escalation-scan-v0.5.py
python3 -c "import ast; ast.parse(open('tools/escalation-scan-v0.5.py').read())"

# A2/A3 — running tool against fixture writes expected output + idempotency guard fires
test -f .context/working/escalation-drift-LATEST-v0.5.yaml
python3 -c "import yaml; yaml.safe_load(open('.context/working/escalation-drift-LATEST-v0.5.yaml'))"

# A4 — oe-daily cron wires v0.5 (additive)
grep -q "escalation-scan-v0.5" .context/cron/agentic-audit.crontab || \
  grep -rq "escalation-scan-v0.5" agents/cron/ 2>/dev/null

# A5 — Watchtower surface (Playwright per T-1575: element-presence grep forbidden)
test -f tests/playwright/test_escalation_v05.py
{ bin/fw test playwright -k escalation_v05 2>&1 || true; } | grep -q "passed"

# A6 — disagreement-rate report exists with required content
test -f docs/reports/T-1727-v0-5-disagreement-rate.md
grep -q -i "disagreement" docs/reports/T-1727-v0-5-disagreement-rate.md
grep -q -i "30-day" docs/reports/T-1727-v0-5-disagreement-rate.md

# A7 — Evolution log populated (T-1718 gate)
grep -q "## Evolution" .tasks/active/T-1727-v05-build--escalation-scan-with-llm-augm.md
python3 -c "
import re, sys
body = open('.tasks/active/T-1727-v05-build--escalation-scan-with-llm-augm.md').read()
m = re.search(r'## Evolution\s*\n(.+?)(?=\n## |\Z)', body, re.DOTALL)
sys.exit(0 if m and re.search(r'###\s*\d{4}-\d{2}-\d{2}', m.group(1)) else 1)
"

# A8 — Bats tests + fabric registration + fw audit clean
test -f tests/unit/escalation_scan_v05.bats
{ bats tests/unit/escalation_scan_v05.bats 2>&1 || true; } | grep -q -E "[0-9]+ tests, 0 failures"
{ bin/fw fabric drift 2>&1 || true; } | grep -q -i "no.*unregistered" || \
  ! { bin/fw fabric drift 2>&1 || true; } | grep -q -i "T-1727\|escalation-scan-v0.5"
{ bin/fw audit 2>&1 || true; } | grep -q -E "Fail: 0"

# A9 — pre-existing items resolved (T-1726 Spike 1 leftovers)
# 9a: ollama-loop accepted by validator (already fixed in T-1689 — keep as regression pin)
python3 -c "
import sys; sys.path.insert(0, 'lib')
from resolver import VALID_WORKER_KINDS
sys.exit(0 if 'ollama-loop' in VALID_WORKER_KINDS else 1)
"
# 9b: prompts/default.md no longer leaks unresolved-vars marker on dispatch
! grep -q "resolver: unresolved" prompts/default.md

# Toolchain hint (L-291): no compileable artefacts here (Python only).
# tsc/dotnet/cargo/go not relevant. Python parse-checks above cover syntax.

## RCA

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

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
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

### 2026-05-04T21:39:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1727-v05-build--escalation-scan-with-llm-augm.md
- **Context:** Initial task creation

### 2026-05-04T21:39:48Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** tags: +blocked-on-t-1726-go

### 2026-05-04T21:39:58Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-04T21:39:58Z — status-update [task-update-agent]
- **Change:** tags: +T-1726-implementation

### 2026-05-04T21:39:58Z — status-update [task-update-agent]
- **Change:** tags: +G-064-closure-pilot

### 2026-05-05T10:48:46Z — status-update [task-update-agent]
- **Change:** tags: +ready-on-t-1744-go
