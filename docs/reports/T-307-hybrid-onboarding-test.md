# T-307: Hybrid Onboarding Test — Inception Research

**Task:** T-307
**Type:** Inception
**Date:** 2026-03-04
**Status:** Template filled, awaiting review

---

## Evidence Base

### T-294 Live Simulation Findings (9 issues)

| ID | Sev | Issue | Type |
|----|-----|-------|------|
| O-001 | P1 | No README/QUICKSTART at framework root | Missing file |
| O-002 | P2 | No `fw preflight` command | Missing feature |
| O-003 | P1 | `fw doctor` FAILS on fresh project (env var parsing) | Flow bug |
| O-004 | P2 | `fw doctor` output printed TWICE | Flow bug |
| O-005 | P2 | `fw context init` exits code 1 on success | Flow bug |
| O-006 | P2 | `fw context init` output TWICE | Flow bug |
| O-007 | P1 | `fw task create` without `--description` hangs on stdin | Flow bug |
| O-008 | P1 | `--start` flag doesn't set focus | Flow bug |
| O-009 | P2 | Audit shows false positives on brand-new project | Integration bug |

**Key insight:** 7 of 9 issues are flow-level bugs that no static audit can catch.

### L-029 Learning

> "Dry-running onboarding on a fictional test project catches bugs that unit tests miss: sentinel logic, cross-function variable scope, git identity inheritance. Always validate wizard flows end-to-end before real use."

### Self-Audit Coverage (T-286)

Self-audit checks **static configuration** (Layers 1-4): file existence, directory structure, JSON validity, hook installation. It cannot detect:
- Wizard step sequence failures
- Focus state persistence across commands
- Sentinel logic correctness
- Hook firing behavior on new tasks
- Audit false positives on new projects
- Platform-specific edge cases

### Gap Analysis

| Category | Self-Audit | Deterministic E2E | Hybrid (T-307) |
|----------|-----------|-------------------|-----------------|
| Static config | Yes | No | No |
| Flow bugs | No | Partial (pass/fail) | Yes (diagnosis) |
| Integration bugs | No | Partial | Yes (adaptive) |
| Platform edge cases | No | Yes (per-platform) | Yes (with reasoning) |
| Failure diagnosis | No | No | Yes |

---

## Design Direction

### Three-Layer Architecture (CLI / Agent / Skill)

**Layer 1: CLI** — `fw test-onboarding [target-dir]`
- Bash script: creates temp project, runs init, exercises first-task flow, captures output
- Deterministic checkpoints: did file X get created? Did command Y exit 0?
- Structured YAML/JSON output for each checkpoint

**Layer 2: Agent** — `agents/onboarding-test/AGENT.md`
- Interprets CLI output: "focus.yaml exists but points to wrong task" vs "focus.yaml missing"
- Diagnoses partial failures: "step 3 failed because step 2 silently produced wrong output"
- Adapts checks to platform (macOS date flags, WSL paths, Alpine missing tools)

**Layer 3: Skill** — `/test-onboarding`
- In-session wrapper: calls CLI, feeds output to agent reasoning, reports findings
- Can be used interactively ("test onboarding on this project") or autonomously

### Checkpoint Design (8 checkpoints)

1. **C1: Project scaffold** — `fw init` creates all expected dirs and files
2. **C2: Hook installation** — settings.json has all 10 hooks, git hooks installed
3. **C3: First task** — `fw work-on "Test task" --type build` succeeds, focus set
4. **C4: Task gate** — Write/Edit blocked without active task (hooks firing)
5. **C5: First commit** — `fw git commit` succeeds with task reference
6. **C6: Audit clean** — `fw audit` passes (no false positives on day-1 project)
7. **C7: Self-audit clean** — `fw self-audit` passes
8. **C8: Handover** — `fw handover` generates valid handover document

### What "Good" Looks Like

Each checkpoint produces:
- **PASS**: Step completed, all assertions met
- **WARN**: Step completed but with unexpected output (agent interprets)
- **FAIL**: Step did not complete (agent diagnoses root cause)
- **SKIP**: Prerequisite checkpoint failed (cascading skip)

Agent interpretation criteria:
- Expected day-1 noise vs real failures (audit warnings on fresh project = normal)
- Output quality (CLAUDE.md has project name substituted, not __PROJECT_NAME__)
- UX clarity (error messages are actionable, not cryptic)

---

## Dialogue Log

*(To be filled during inception review with human)*
