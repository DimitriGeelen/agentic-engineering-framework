---
id: T-1752
name: "fw gaps surfaces closure_check_command verdicts inline — generic substrate for mechanical gap closure"
description: >
  Extend fw gaps to honor an optional closure_check_command field on watching gaps. When present, fw gaps shells out to run it (with timeout), parses verdict from JSON output, and renders the result inline alongside the gap (READY in green / NOT_READY in yellow / ERROR in red). First consumer: G-064, whose closure-readiness gauge tools/g064-readiness.py was shipped in T-1750. Generic so future gaps with mechanical closure checks just add the field to concerns.yaml; no code changes per gap. Direct orchestrator-arc work — turns 'human remembers to run the script' into 'human sees verdict on every fw gaps run.'

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [governance, observability]
components: [bin/fw, tests/unit/test_fw_gaps_closure_check.bats]
related_tasks: [T-1750, T-1687]
arc_id: orchestrator-rethink
created: 2026-05-05T21:35:53Z
last_update: 2026-05-05T21:40:05Z
date_finished: 2026-05-05T21:40:05Z
---

# T-1752: fw gaps surfaces closure_check_command verdicts inline — generic substrate for mechanical gap closure

## Context

`fw gaps` (bin/fw lines 4342-4376) lists watching concerns from `.context/project/concerns.yaml`. T-1750 shipped `tools/g064-readiness.py` — a mechanical closure-readiness gauge that emits READY/NOT_READY for G-064. Currently the human has to remember to run that script separately.

Generalisation: any watching gap can declare a `closure_check_command:` field naming a shell command that emits JSON with at least `{"verdict": "READY"|"NOT_READY", ...}`. `fw gaps` runs each such command (with a short timeout) and renders the verdict inline next to the gap.

First consumer: G-064 (escalation-triage cron consumer). Closure threshold check pre-built (T-1750). Future consumers: any gap with a mechanical readiness signal — no code changes needed, just add the field.

Direct orchestrator-arc work: surfaces gauge output without operator memory; the closure decision becomes a passive observation rather than an active recall.

## Acceptance Criteria

### Agent
- [x] `.context/project/concerns.yaml` G-064 entry has a `closure_check_command:` field naming `python3 tools/g064-readiness.py --json`
- [x] `fw gaps` runs each watching gap's `closure_check_command` (when present) with a 10-second timeout
- [x] Gap rendering shows verdict inline: `Closure: READY` (green) / `Closure: NOT_READY (X/Y)` (yellow) / `Closure: ERROR` (red) when the field is present
- [x] Gaps without `closure_check_command` render unchanged (backward compatible)
- [x] Verdict line includes salient counters when present in JSON (`cron_firings`, `cron_firing_dates`, `closure_threshold_dates`)
- [x] Command timeout / non-zero exit / invalid JSON renders as `Closure: ERROR (<reason>)` without crashing fw gaps
- [x] `bin/fw gaps` exits 0 even when one or more closure checks fail (advisory only, never blocking)
- [x] Live verification: `bin/fw gaps | grep -A2 'G-064' | grep -q 'NOT_READY'` succeeds (today's expected state — 0/3 cron-firing dates)
- [x] `python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"` parses cleanly
- [x] `tests/unit/test_fw_gaps_closure_check.bats` exists with ≥3 cases covering: gap without field (unchanged), gap with passing field (verdict rendered), gap with failing/timeout field (ERROR rendered)

### Human

(none — surface-rendering enhancement; no behaviour change beyond display)

## Verification

bin/fw gaps >/dev/null
bin/fw gaps | grep -q 'G-064'
bin/fw gaps | grep -A2 'G-064' | grep -q 'Closure:'
bin/fw gaps | grep -A2 'G-064' | grep -q 'NOT_READY'
python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"
bats tests/unit/test_fw_gaps_closure_check.bats

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

### 2026-05-05 — generic field, not G-064-specific bolt-on

- **What changed:** Initial impulse was to special-case G-064 in `fw gaps` (hard-code the gauge call when the gap id matches). Generalised to a per-gap `closure_check_command:` field so any future watching gap can declare its own readiness check without code changes. Cost: same line count; benefit: durable substrate.
- **Plan impact:** Moved the implementation from "if gap.id == 'G-064'" branch to "for any gap, run cmd if field is set." Tests cover all four states (no field, READY, NOT_READY+counters, ERROR variants).
- **Triggered:** No new task — generalisation is the deliverable.

### 2026-05-05 — advisory only, never blocks fw gaps

- **What changed:** Initial draft had `bin/fw gaps` exit non-zero when a closure check fails. Recognised this would break callers (`fw doctor`, scripts) who treat `fw gaps` as a status query. Fixed: exceptions/timeouts/non-JSON all render as ERROR but `fw gaps` still exits 0.
- **Plan impact:** AC #7 ("exits 0 even when closure checks fail") added explicitly; bats test #6 pins it.
- **Triggered:** No new task — design discipline captured.

## Recommendation

**Recommendation:** GO — close T-1752 as work-completed.

**Rationale:** All 10 Agent ACs satisfied. Generic substrate (any gap can declare a `closure_check_command:` and get inline verdict rendering); first consumer is G-064 (today's view: `Closure: NOT_READY (0/3)` in yellow). Backward compatible (gaps without the field render unchanged). Failure modes (timeout, non-JSON, empty, non-zero exit) all degrade gracefully to `Closure: ERROR (...)` without crashing. 6/6 bats tests pin the contract.

**Evidence:**
- Live `bin/fw gaps` shows `Closure: NOT_READY (0/3)` next to G-064
- `bats tests/unit/test_fw_gaps_closure_check.bats` → 6 passed
- All 6 `## Verification` gates green pre-completion
- concerns.yaml YAML still parses; backward-compatible for all 8 other watching gaps (none have the field; all render unchanged)

## Decisions

### 2026-05-05 — JSON-only contract for closure_check_command

- **Chose:** The command MUST emit JSON to stdout with at least a `verdict` field. Optional counters (`cron_firing_dates`, `closure_threshold_dates`) are surfaced as `(have/need)`.
- **Why:** JSON is unambiguous, parses safely, and matches what `tools/g064-readiness.py --json` already emits. Makes the contract testable and language-agnostic. Future scripts (Python, Bash, Go) all interop trivially.
- **Rejected:** Plain-text exit-code-only — too narrow, can't surface counters. Custom DSL — over-engineered for one field.

### 2026-05-05 — 10-second timeout, render ERROR not crash

- **Chose:** subprocess timeout 10s; failures render `Closure: ERROR (timeout/non-JSON/empty/...)` but `fw gaps` exits 0.
- **Why:** `fw gaps` is a status query — must remain fast and non-blocking. A misbehaving check should be visible (so the human notices) but never break the listing. 10s is generous (T-1750's gauge runs in <0.1s on real data).
- **Rejected:** No timeout — single bad check could hang the whole listing. Re-raise — would break `fw doctor` and other callers.

## Updates

### 2026-05-05T21:35:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1752-fw-gaps-surfaces-closurecheckcommand-ver.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-dee61a49
- **Timestamp:** 2026-05-05T21:40:08Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `.context/project/concerns.yaml` G-064 entry has a `closure_check_command:` field naming `python3 tools/g064-readiness.py --json`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tools/g064-readiness.py in: `.context/project/concerns.yaml` G-064 entry has a `closure_check_command:` field naming `python3 tools/g064-readiness.py --json``

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 1
     - evidence: `bin/fw gaps >/dev/null`

### 2026-05-05T21:40:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
