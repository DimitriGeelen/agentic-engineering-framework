---
id: T-1696
name: "v1 Resolver port — spike to lib/resolver.py + lib/resolver.sh + bin/fw resolver"
description: >
  v1 Resolver port — spike to lib/resolver.py + lib/resolver.sh + bin/fw resolver

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/resolver.py, tests/unit/test_resolver.py]
related_tasks: []
created: 2026-05-03T12:49:43Z
last_update: 2026-05-03T12:57:55Z
date_finished: 2026-05-03T12:57:55Z
---

# T-1696: v1 Resolver port — spike to lib/resolver.py + lib/resolver.sh + bin/fw resolver

## Context

Build follow-on to T-1689 (inception GO 2026-05-03). Ports the validated
spike at `docs/reports/T-1689-spikes/resolver_spike.py` (290 LOC, all 4
testable assumptions met) to production `lib/resolver.py` (~400 LOC) +
`lib/resolver.sh` shim + `bin/fw resolver` CLI.

The Resolver is the spawn-side primitive that T-1691 (litellm proxy
adapter) and T-1692 (pi backend) BUILD ON. Without it, neither v1 build
can land. Sequence: T-1696 (this) → T-1697 (T-1690 outcome enrichment) →
T-1698 (T-1691 proxy) ‖ T-1699 (T-1692 pi).

Research artifact: `docs/reports/T-1689-resolver-inception.md`
Spike: `docs/reports/T-1689-spikes/resolver_spike.py`
Inception decisions: D-073 (single module + shell shim), D-074..D-079
(spike-validated atomic patterns).

Scope per inception §"v1 build task scope":
1. Port spike → `lib/resolver.py` (~400 LOC) + `lib/resolver.sh` shim (~30 LOC)
2. Wire `bin/fw resolver` for debugging + as the spawn-side primitive
3. Real `_recent_dispatches_summary` (currently a stub) — tail JSONL
4. Real `HEALING_PATTERNS` injection — pull from patterns.yaml
5. Few-shot example loader (`prompts/examples/<task_type>/*.md`)
6. Tier 3 (`meta-prompted`) implementation — substrate ships unconditionally
7. Per-call unique tmp pattern in modify-in-place paths (T-1690 inheritance)
8. CLI: `fw resolver dispatch <task_id> <task_type>` dry-run + `fw resolver explain <dispatch_id>` forensics

## Acceptance Criteria

### Agent
- [x] `lib/resolver.py` exists, parses cleanly with `python3 -c "import ast; ast.parse(open('lib/resolver.py').read())"`
- [x] `lib/resolver.sh` shim exists and is executable
- [x] `bin/fw resolver --help` exits 0 and lists dispatch + explain subcommands
- [x] `bin/fw resolver dispatch T-1696 default --dry-run` exits 0 and prints a JSON envelope (workflow_id, prompt, model, env, dispatch_id)
- [x] Q12 fallback test: `bin/fw resolver dispatch T-1696 nonexistent-type --dry-run` falls back to `default.yaml` (logged) and exits 0
- [x] Q12 hard error: dispatch with no default.yaml present (test setup) exits non-zero with explicit "no default workflow" message
- [x] Inline rejection: `bin/fw resolver dispatch T-1696 inception --dry-run` exits non-zero with "inline workflow cannot dispatch" (per ADR-0002)
- [x] Telemetry round-trip: dispatch writes a row to `.context/dispatches.jsonl` containing dispatch_id, workflow_sha, template_sha, task_type, task_id, ts_start
- [x] `_recent_dispatches_summary` returns a real summary from JSONL tail (not the stub) for an existing task_type
- [x] `HEALING_PATTERNS` injection pulls from `.context/project/patterns.yaml` when present
- [x] Few-shot loader reads `prompts/examples/<task_type>/*.md` if present (tested with at least one example file)
- [x] Atomic back-prop: any modify-in-place path uses `.tmp.<pid>.<tid>` pattern (per D-074)
- [x] Unit tests for resolver pass: workflow lookup (Q12), prompt assembly, variant selection, telemetry capture, inline rejection
- [x] Component fabric registered: `bin/fw fabric deps lib/resolver.py` returns the card
- [x] No regression: `bin/fw doctor` passes with same WARN/FAIL count as pre-port baseline

## Verification

python3 -c "import ast; ast.parse(open('lib/resolver.py').read())"
test -x lib/resolver.sh
bin/fw resolver --help
python3 -m pytest tests/unit/test_resolver.py -q
bin/fw fabric deps lib/resolver.py
bin/fw doctor

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

### 2026-05-03T12:49:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1696-v1-resolver-port--spike-to-libresolverpy.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1b09ac55
- **Timestamp:** 2026-06-02T14:59:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#8 (Agent)** — Telemetry round-trip: dispatch writes a row to `.context/dispatches.jsonl` containing dispatch_id, workflow_sha, template_sha, task_type, task_id, ts_start
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/dispatches.jsonl in: Telemetry round-trip: dispatch writes a row to `.context/dispatches.jsonl` containing dispatch_id, workflow_sha, template_sha, task_type, task_id, ts_`
- **AC#10 (Agent)** — `HEALING_PATTERNS` injection pulls from `.context/project/patterns.yaml` when present
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/project/patterns.yaml in: `HEALING_PATTERNS` injection pulls from `.context/project/patterns.yaml` when present`
### 2026-05-03T12:57:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
