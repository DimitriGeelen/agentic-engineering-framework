---
id: T-1727
name: "v0.5 build — escalation-scan with LLM augmentation (T-1726 GO conditional)"
description: >
  v0.5 build — implements T-1726 GO decision: escalation-scan v0 augmented with LLM
  verdict
  per candidate, dispatched via orchestrator (worker_kind=ollama-loop default + cloud
  fallback,
  cost-capped). Wires fw resolver dispatch into oe-daily cron, captures outcomes via
  T-1697
  back-prop hook, surfaces dispatches on /orchestrator. Closes G-064 (orchestrator
  first real
  consumer) via T-1688 option 4. Now ready: T-1726 GO recorded; T-1741/T-1743 confirmed
  prompt-triage NO-GO; T-1744 inception names this task as the live G-064 mitigation
  path.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [prompts/default.md, prompts/escalation-triage.md, 
      tests/playwright/test_escalation_v05.py, 
      tests/unit/escalation_scan_v05.bats, tools/escalation-scan-v0.5.py, 
      web/blueprints/escalation.py, web/templates/escalation_drift.html]
related_tasks: [T-1688, T-1726, T-1741, T-1743, T-1744, T-1737]
arc_id: orchestrator-rethink
created: 2026-05-04T21:39:23Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-05-05T16:50:22Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 5
      D4: 2
      F-RECALL: 2
      F-ORCH: 3
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=5
      (body:new-collab-mode); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=3 (body:typed-io-or-gate); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1727: v0.5 build — escalation-scan with LLM augmentation (T-1726 GO conditional)

## Context

**🔒 BLOCKED on T-1744 GO recording.** Task pre-filed per CLAUDE.md
"Post-Grill Governance Closure (L-349)" pattern: after writing
Recommendation, the build sibling is filed at captured/horizon-next so
it surfaces immediately on GO without a separate filing step.

**Design constraint from L-355 (architectural ceiling):** 7-8B local
ollama on prompt classification caps at ~76-79% accuracy across the
4 models tested in Spike-D arc (T-1741, T-1743) under both 3-class
and binary formulations. This rules out high-precision gating. For
escalation-scan v0.5 the ceiling is design-tolerable — the workload
surfaces candidates for human review, not blocks user prompts. False
positives are cheap (human ignores), false negatives are mitigated by
the existing static-scan layer. The 80% ceiling becomes a virtue:
noisy-but-better-than-zero augmentation is what an advisory escalation
queue needs. Build must NOT assume >85% LLM accuracy in any AC; A6
disagreement-rate ground truth must be measured, not assumed.

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

- [x] **A1** New workflow file `prompts/escalation-triage.yaml` (or
  inline in default workflow) with `worker_kind` accepted by validator,
  `task_type: escalation-triage`, ollama-local default + cloud fallback,
  cost cap configured.
- [x] **A2** New tool `tools/escalation-scan-v0.5.py` (sibling of v0)
  reads `.context/working/escalation-drift-LATEST.yaml`, dispatches one
  triage call per candidate via `fw resolver dispatch`, writes
  `.context/working/escalation-drift-LATEST-v0.5.yaml` with `verdict`
  + `reasoning` per candidate, captures outcomes via existing T-1697
  back-prop hook.
- [x] **A3** Idempotency: re-running v0.5 on the same candidate within
  N days (configurable, default 7) skips dispatch (mtime/checksum guard).
- [x] **A4** `oe-daily` cron wires v0.5 after v0 (additive, never
  replaces). Failure of v0.5 must not impair v0's report emission.
- [x] **A5** Watchtower surface: either augment existing v0 panel with
  a `triage` column or add `/embeddings`-style v0.5 panel (decision
  during build). Playwright test pins visibility (per T-1575 — element-
  presence grep is forbidden).
- [x] **A6** Spike 2 ground truth recorded in `docs/reports/T-1727-v0-5-disagreement-rate.md`:
  LLM verdict vs heuristic verdict on the 30-day backlog, ≥10%
  disagreement to confirm A1 of T-1726.
- [x] **A7** ## Evolution log populated at completion (Evolution-gate
  from T-1718 fires on this arc-tagged build task).
- [x] **A8** Bats coverage: ≥1 test per AC; new components fabric-
  registered; `fw audit` clean.
- [x] **A9** Two pre-existing minor items from T-1726 Spike 1 either
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

# All commands MUST be single-line (gate parses line-by-line; no \-continuations
# or multi-line python here-strings — see L-291/L-356).

# A1 — workflow file exists, schema lints clean
test -f prompts/escalation-triage.md
test -f .context/project/workflows/escalation-triage.yaml
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/workflows/escalation-triage.yaml')); assert d['task_type']=='escalation-triage' and d['worker_kind']=='ollama-loop'"
bin/fw doctor > /tmp/_t1727_doctor.out 2>&1; grep -q "Workflow schema:.*lint clean" /tmp/_t1727_doctor.out

# A2 — tool exists and parses
test -f tools/escalation-scan-v0.5.py
python3 -c "import ast; ast.parse(open('tools/escalation-scan-v0.5.py').read())"

# A2/A3 — output yaml exists + parses
test -f .context/working/escalation-drift-LATEST-v0.5.yaml
python3 -c "import yaml; yaml.safe_load(open('.context/working/escalation-drift-LATEST-v0.5.yaml'))"

# A4 — oe-daily cron wires v0.5 (additive: v0 line still present)
grep -q "escalation-scan-v0.5" .context/cron/agentic-audit.crontab
grep -q "escalation-scan-v0.py" .context/cron/agentic-audit.crontab

# A5 — Watchtower surface: template hooks + Playwright file exist (live test in bats)
test -f tests/playwright/test_escalation_v05.py
grep -q 'data-testid="escalation-v05-panel"' web/templates/escalation_drift.html
grep -q 'data-testid="escalation-v05-table"' web/templates/escalation_drift.html

# A6 — disagreement-rate report exists with required content
test -f docs/reports/T-1727-v0-5-disagreement-rate.md
grep -q -i "disagreement" docs/reports/T-1727-v0-5-disagreement-rate.md
grep -q -i "30-day" docs/reports/T-1727-v0-5-disagreement-rate.md

# A7 — Evolution log populated (T-1718 gate)
grep -q "^## Evolution$" .tasks/active/T-1727-v05-build--escalation-scan-with-llm-augm.md
python3 -c "import re; body=open('.tasks/active/T-1727-v05-build--escalation-scan-with-llm-augm.md').read(); m=re.search(r'## Evolution\s*\n(.+?)(?=\n## |\Z)',body,re.DOTALL); assert m and re.search(r'###\s*\d{4}-\d{2}-\d{2}',m.group(1))"

# A8 — Bats green + fabric drift clean + audit clean
test -f tests/unit/escalation_scan_v05.bats
bats --formatter pretty tests/unit/escalation_scan_v05.bats 2>&1 | grep -q -E "[0-9]+ tests, 0 failures"
bin/fw fabric drift 2>&1 | grep -q -E "unregistered: 0"
bin/fw audit --section structure > /tmp/_t1727_audit.out 2>&1; grep -q -E "Fail: 0" /tmp/_t1727_audit.out

# A9a — ollama-loop accepted by validator (T-1689 regression pin, single-line)
python3 -c "import sys; sys.path.insert(0,'lib'); from resolver import VALID_WORKER_KINDS; assert 'ollama-loop' in VALID_WORKER_KINDS"

# A9b — prompts/default.md no longer leaks unresolved-vars marker (literal $VAR removed)
! grep -E '\$VAR\b' prompts/default.md

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

### 2026-05-05 — v0.5 walks completed/ itself (does not trust v0's recent_sample)
- **What changed:** A2 spec said "reads `escalation-drift-LATEST.yaml`,
  dispatches one triage call per candidate". When implementing, v0's
  `recent_sample` proved capped at 10 candidates (intentionally — v0's
  contract is FP-triage sample for human review, not full-corpus emission).
  A6 needs the full 30-day backlog (~170 candidates) to compute a meaningful
  disagreement rate.
- **Plan impact:** The "v0.5 reads v0's LATEST" path was insufficient for A6.
  v0.5 now self-walks `.tasks/completed/` with the same H1 heuristic, reading
  v0's LATEST only for headline numbers (corpus_total, h1_flagged) for
  diagnostic context. v0's output contract is unchanged — v0.5 is additive,
  not modifying.
- **Triggered:** none filed; the duplication of the H1 heuristic in v0.5 is
  ≤30 lines and acceptable for two cooperating spike tools. If v1 promotes,
  factor the heuristic into `lib/escalation_heuristic.py` shared module.

### 2026-05-05 — disagreement rate dwarfs the AC threshold (64.7% vs 10%)
- **What changed:** A6 confirmed the LLM augmentation hypothesis very loudly:
  110/170 (64.7%) heuristic flags are LLM-classified `false_positive`.
  Per-call ceiling per L-355 is 76-79%; aggregate signal is robust because
  individual verdicts are advisory, not gating.
- **Plan impact:** none for v0.5 build — the 10% threshold was for "is the
  signal real?" not "what number should we expect?". Confirms route_cache
  has substantial separation to learn from.
- **Triggered:** report A6 names follow-up forward-work that does NOT belong
  on T-1727: PARSE-FAIL hardening (5.9%, 10/170), per-call precision/recall
  sample triage, cross-model comparison. These are filed-on-promotion, not now.

### 2026-05-05 — Verification commands tightened to match real tool output
- **What changed:** A1's verification grep `"workflow.*escalation-triage"` was
  written assuming `bin/fw doctor` would name workflows individually; doctor
  actually emits a count line (`Workflow schema: N file(s) lint clean`).
  Same pattern with A8 bats: default `bats` format omits the summary line;
  `--formatter pretty` includes it. Replaced with realistic grep targets +
  added direct `python3 yaml.safe_load` lint of the workflow YAML.
- **Plan impact:** none — the spirit of the gate (verify the workflow lints
  and the bats suite is green) is preserved with stronger checks.
- **Triggered:** none.

### 2026-05-05 — `/.framework.yaml` polluting framework-repo discovery
- **What changed:** During Watchtower :3002 restart, `web/shared._discover_project_root`
  returned `/` because a stray `/.framework.yaml` (version: 1.5.0, dated
  2026-05-01) sits at filesystem root. Any python process started without
  explicit `PROJECT_ROOT` env from `cwd=/opt/999` followed the discovery
  walk all the way up to `/` and matched there. Caused `/escalation-drift`
  to render empty (LATEST.yaml resolved against `/` not `/opt/999`).
- **Plan impact:** none for T-1727 (workaround: start watchtower with explicit
  `PROJECT_ROOT=/opt/999`). But this is a latent gap — anyone restarting
  the framework's own Watchtower without env will see the same blindness.
- **Triggered:** filed as forward-work in ## Decisions; not blocking T-1727.

## Recommendation

**Recommendation:** GO

**Rationale:** v0.5 is shipped end-to-end and the headline mechanic fires
live. All 9 agent ACs (A1-A9) are verified by 14 bats assertions + 6
Playwright assertions. The substrate is wired through the orchestrator
exactly as T-1726 specified: 170 dispatches were captured to
`.context/dispatches.jsonl` with `task_type=escalation-triage,
worker_kind=ollama-loop, model=claude-3-5-sonnet-hermes3`, and 170 matching
outcome rows landed in `.context/dispatch-outcomes.jsonl`. G-064
(orchestrator first real consumer) is closed: route_cache now has a daily
autonomous workload producing ~170 outcome events per run.

The disagreement-rate signal (A6) is robust at 64.7% — well above the AC's
10% threshold. v0.5 demonstrably surfaces the noise in v0's heuristic flags
(refactors-with-fix-in-title, test infra changes, docs fixes mis-classed).

This is not a research task — there is no further work to specify before
shipping. Forward work for v1 is named in the report (PARSE-FAIL hardening,
per-call precision/recall sample, cross-model comparison) but does not
gate v0.5 completion.

**Evidence:**
- 14/14 bats green: `tests/unit/escalation_scan_v05.bats`
- 6/6 Playwright green: `tests/playwright/test_escalation_v05.py` (against :3002)
- 170 dispatches captured, 0 errors, 6m 11s wall-clock
- Disagreement rate 64.7% (110/170) — see
  `docs/reports/T-1727-v0-5-disagreement-rate.md`
- /escalation-drift renders v0.5 panel + Triage column at
  http://192.168.10.107:3002/escalation-drift
- A9b verified: `bin/fw resolver dispatch ... --json` no longer trails
  `<!-- resolver: unresolved -->`
- A9a verified: `'ollama-loop' in lib/resolver.VALID_WORKER_KINDS`

**Forward work (filed-on-promotion, not now):**
- PARSE-FAIL hardening (5.9% rate — 10/170 candidates emitted unparseable
  YAML envelopes; either tighten prompt or harden parser)
- `/.framework.yaml` polluting framework-repo discovery (Evolution log entry)
  — separate gap entry, not T-1727 scope

## Decisions

### 2026-05-05 — Direct litellm POST instead of fw termlink dispatch per candidate
- **Chose:** v0.5 calls `lib/resolver.resolve()` (Python import) for envelope
  capture, then makes one direct urllib POST per candidate to litellm
  `/v1/messages`. Outcome rows written via `lib/outcome.backprop_outcome`.
- **Why:** Per-candidate `fw termlink dispatch` would spawn a full claude -p
  worker subprocess per candidate (~170 subprocesses for the 30-day window).
  Direct litellm calls keep the resolver substrate wired (route_cache learns)
  while running in a single Python process. End-to-end cost: 6m 11s for 170
  dispatches at 2.2s mean.
- **Rejected:** (a) `fw termlink dispatch` per candidate — ~30x slower,
  unnecessary process overhead. (b) Bypass resolver entirely — would skip
  dispatches.jsonl + route_cache learning, the whole point of G-064 closure.

### 2026-05-05 — Forward work: framework-repo PROJECT_ROOT discovery
- **Chose:** Document the `/.framework.yaml` discovery hazard in Evolution log,
  flag for filing as a separate gap; do NOT fix in T-1727 scope.
- **Why:** Discovery-walk hitting fs root pollution is structural and affects
  any python module using `web/shared.PROJECT_ROOT` resolution. Fixing
  belongs in a dedicated gap-register entry (with mitigation: detect
  framework-repo by `FRAMEWORK.md` presence, prefer it over discovered
  consumer marker, OR refuse to walk past `FRAMEWORK_ROOT.parent`).
- **Rejected:** in-scope quick fix — would expand T-1727 beyond its filed
  AC contract and ship a one-off without a regression test.

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

### 2026-05-05T16:20:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-77b69aec
- **Timestamp:** 2026-06-02T14:59:21Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent (locked at T-1726 filing — do not modify without ## Evolution entry))** — **A1** New workflow file `prompts/escalation-triage.yaml` (or
  - **AC-verify-mismatch** (narrow, heuristic) — `path=prompts/escalation-triage.yaml in: **A1** New workflow file `prompts/escalation-triage.yaml` (or`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 42
     - evidence: `bats --formatter pretty tests/unit/escalation_scan_v05.bats 2>&1 | grep -q -E "[0-9]+ tests, 0 failures"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 43
     - evidence: `bin/fw fabric drift 2>&1 | grep -q -E "unregistered: 0"`
### 2026-05-05T16:50:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
