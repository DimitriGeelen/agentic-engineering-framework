# Agentic Engineering Framework — Status Report

**Date:** 2026-03-14
**Prepared by:** 3 parallel research agents + synthesis

---

## Executive Summary

The framework is **production-grade and self-governing**. It has governed its own 445-task development with 98.7% commit traceability, zero unauthorized bypasses, and 49 logged Tier 0 approvals. Core infrastructure is complete. The critical path to external adoption is onboarding polish, not missing features.

---

## 1. What We've Built

### By the Numbers
| Metric | Count |
|--------|-------|
| Tasks completed | 463 (70% build, 13.5% inception, 10.5% refactor) |
| Active tasks | 23 |
| Commits traced to tasks | 1,383/1,400 (98.7%) |
| Components tracked | 157 across 12 subsystems |
| Learnings captured | 804 lines |
| Decisions recorded | 450 lines |
| Concerns registered | 21 (11 active) |
| Failure patterns | 170 lines |
| Session handovers | 333 |

### By Subsystem

**Framework Core (`bin/fw`, `lib/`)**
- 30+ CLI commands: task, context, audit, doctor, metrics, fabric, healing, inception, handover, resume, bus, gaps, promote, tier0
- fw init (project onboarding with seed files and task templates)
- fw doctor (health checks across all subsystems)
- fw metrics (task velocity, traceability, effort prediction)

**Enforcement Layer**
- Tier 0: PreToolUse hook blocks destructive commands (force push, rm -rf, DROP TABLE) — requires `fw tier0 approve`
- Tier 1: Task gate blocks Write/Edit without active task
- Budget gate: Reads actual token usage from session transcript, blocks at 900K tokens
- Verification gate (P-011): Shell commands in task files must pass before completion
- AC gate (P-010): Acceptance criteria must be checked before work-completed
- Build readiness gate (G-020): Blocks source edits on tasks with placeholder ACs

**Context Fabric (Memory)**
- Working memory: session state, focus, priorities
- Project memory: learnings, decisions, patterns, concerns
- Episodic memory: auto-generated task summaries with metrics
- 333 handovers with structured context recovery

**Component Fabric**
- 157 components across 12 subsystems
- Dependency tracking with `fw fabric deps/impact/blast-radius`
- Drift detection for unregistered/orphaned files
- Directory registration (recursive with exclusions)

**Watchtower Web UI**
- 69 endpoints across 18 blueprints
- Dashboard, tasks, search, fabric, quality, settings, directives, enforcement, metrics, timeline, cron, docs, discoveries
- Ask AI chat with Ollama/OpenRouter integration
- Component dependency graph visualization
- Python 3.9+ compatible (future annotations)

**Git Traceability**
- commit-msg hook enforces T-XXX prefix
- post-commit hook updates task files
- pre-push hook runs audit
- Bypass logging with mandatory rationale

**Healing Loop**
- Failure classification (code, dependency, environment, design, external)
- Pattern matching against known failures
- Recovery suggestions via Error Escalation Ladder
- Auto-diagnosis on task status → issues

**Audit System**
- 90+ checks across structure, compliance, traceability
- Cron every 15 minutes
- Discovery engine (anomaly detection, lifecycle analysis)
- Deployment gate integration

---

## 2. What's Tested

| Test Suite | Coverage | Type |
|------------|----------|------|
| `web/test_app.py` | 60+ tests, 35 routes | Pytest (Flask test client) |
| `web/smoke_test.py` | 28/28 GET routes + 10 content markers | Runtime discovery |
| `tests/unit/` | 13 bats suites, enforcement layer | Bats-core |
| `tests/integration/` | Healing loop, context fabric | Bats-core |
| `agents/onboarding-test/` | Post-init validation | Shell |
| GitHub Actions `test.yml` | CI runner | GHA |
| `fw doctor` | 15+ health checks | Shell |
| `fw audit` | 90+ compliance checks | Shell |

**Coverage gaps:**
- No end-to-end test: fresh install → init → serve → smoke
- No cross-platform CI matrix (macOS/Linux)
- No multi-agent coordination tests

---

## 3. What's Working in Production

| Capability | Status | Evidence |
|------------|--------|----------|
| Task governance | Production | 445 tasks, 98.7% traceability |
| Tier 0 enforcement | Production | 49 approvals logged, zero bypasses |
| Task gate (Tier 1) | Production | Blocks Write/Edit without active task |
| Budget gate | Production | Reads session transcript, blocks at 900K |
| Context continuity | Production | 333 handovers, session recovery |
| Component fabric | Production | 157 components tracked |
| Healing loop | Production | Pattern matching, auto-diagnosis |
| Watchtower UI | Production | LXC 170 (:5050 prod, :5051 dev) |
| Audit system | Production | Cron every 15min, pre-push gate |
| Git hooks | Production | commit-msg, post-commit, pre-push |
| Smoke tests | Production | 28/28 routes, fw doctor integration |
| Install script | Production | macOS + Linux, global at ~/.agentic-framework |
| Python 3.9 compat | Production | future annotations on all web/*.py |

---

## 4. Critical Path to External Adoption

### P0 — Must have before launch
1. **README rewrite** (T-446) — sharp positioning, evidence-first, 5-min demo
2. **End-to-end onboarding test** — fresh install → init → serve → smoke (NEW)
3. **5-minute quickstart walkthrough** — step-by-step for newcomers
4. **GitHub vs OneDev decision** (T-479) — where does the community go?

### P1 — Should have for credibility
5. **Deep-dive articles cleanup** (T-449, T-450) — strip fabricated stats
6. **CONTRIBUTING.md** — how to contribute (NEW)
7. **Cross-platform CI** — GitHub Actions macOS + Linux matrix
8. **Install model decision** (T-482) — global vs local vs hybrid

### P2 — Nice to have
9. **Provider parity docs** — Cursor, Copilot, Aider integration guides
10. **Troubleshooting guide** — common errors and fixes

---

## 5. High-Value Enhancements (Top 10)

| # | Enhancement | Impact | Effort |
|---|-------------|--------|--------|
| 1 | **`fw self-test`** — agent tests own init/serve/gates in feedback loop | Very High | Medium |
| 2 | **GitHub Actions native** — audit on PR, traceability enforcement | High | Medium |
| 3 | **MCP Server** (`fw serve --mcp`) — expose governance to any agent | High | High |
| 4 | **Self-healing task gaps** — auto-detect missing learnings, stale ACs | Medium-High | Medium |
| 5 | **Terminal streaming** — agent sees live output from background services | Medium | Medium |
| 6 | **VS Code/Cursor extension** — sidebar for tasks, quick actions | High | High |
| 7 | **Smart task decomposition linter** — warns on over-scoped tasks | Medium | Medium |
| 8 | **Automatic metrics dashboards** — time-series, anomaly detection | Medium | Low |
| 9 | **Plugin security audit** — `fw plugin audit` for compliance | Medium | Medium |
| 10 | **KCP integration** — adopt sensitivity vocabulary for governance.yaml | Medium | Low |

---

## 6. Self-Testing Capability — `fw self-test`

### The Vision

The framework agent spawns a clean environment, tests its own init/serve/gates, captures failures, fixes them, and re-tests — all within a single session.

### What Claude Code CAN Do
- Create temp directories and run `fw init`
- Start background processes (`run_in_background: true`)
- Poll health endpoints via curl (2s interval, 3 retries)
- Tail log files after service start
- Parse JSON output from smoke tests
- Check exit codes and branch on failure

### What Claude Code CANNOT Do
- Stream live output from background processes (no pseudo-TTY)
- Subscribe to SSE events mid-flight
- Attach to running processes

### Workaround: Polling + Log Tailing
Instead of real-time streaming, the self-test uses:
1. Health endpoint polling (replaces "watching the terminal")
2. Log file tailing after service start
3. Test-client mode for route testing (no server needed)
4. JSON output for machine-parseable results

### Proposed Command

```
fw self-test [--quick|--full] [--port 9999] [--json] [--keep-temp]

Phase 1: Pre-flight     — check deps, create temp project
Phase 2: Gate validation — Tier 0/1/2 enforcement tests
Phase 3: Task lifecycle  — create → update → complete → verify
Phase 4: Watchtower      — start server, poll health, run smoke
Phase 5: Cleanup         — aggregate results, remove temp

Output:
  ✓ Gate Enforcement      (Tier 0, 1, 2)
  ✓ Task Creation         (create, update, complete)
  ✓ Watchtower Health     (server running, routes responsive)
  ✓ Smoke Tests           (28/28 routes passing)
  ✓ YAML Validation       (config parse, concerns valid)
  ✓ Audit Suite           (structure, compliance, traceability)
  ✗ Ollama Integration    (environmental: cannot reach host)

  Summary: 6/7 passing. 1 environmental dependency.
```

### The Feedback Loop
1. Agent runs `fw self-test --json`
2. Reads failure details + classification (framework bug / environmental / transient)
3. Forms hypothesis, fixes code
4. Re-runs `fw self-test --json`
5. Repeat until green

### File Structure
```
agents/self-test/
  self-test.sh              # Main orchestrator
  phases/01-preflight.sh    # Dep checks, temp project
  phases/02-gates.sh        # Enforcement tier tests
  phases/03-tasks.sh        # Task lifecycle tests
  phases/04-watchtower.sh   # Server + smoke tests
  phases/05-cleanup.sh      # Results + cleanup
  AGENT.md                  # Methodology
```

---

## 7. Recommended Task Priority (Next 10)

| Order | Task | Type | Why |
|-------|------|------|-----|
| 1 | T-446 README rewrite | Build | Blocks all external perception |
| 2 | T-479 GitHub vs OneDev | Inception | Blocks community interaction |
| 3 | NEW: E2E onboarding test | Inception | Validates install experience |
| 4 | NEW: `fw self-test` | Inception | Enables automated verification loop |
| 5 | T-334 Launch sequence | Execute | Depends on 1-2 |
| 6 | T-449/T-450 Article cleanup | Build | Credibility for deep-dive content |
| 7 | T-473 Bats test suite | Build | CI/CD readiness |
| 8 | T-477 Governance declaration | Inception | Informed by T-487 KCP research |
| 9 | T-482 Install model | Inception | Architectural decision for field use |
| 10 | T-434 Update/upgrade process | Inception | Critical for post-launch maintenance |

---

## 8. Missing Tasks Identified

| Gap | Recommended Action | Priority |
|-----|-------------------|----------|
| No end-to-end onboarding test | Create `fw self-test` inception | P0 |
| No CONTRIBUTING.md | Create contributor guide task | P1 |
| No cross-platform CI matrix | Extend GitHub Actions (T-476) | P1 |
| No quickstart walkthrough | Separate doc from README | P0 |
| No provider parity docs | Cursor/Copilot/Aider guides | P2 |
| No troubleshooting guide | Common errors + fixes | P2 |

---

*Generated from 3 parallel research agents examining 463 completed tasks, 23 active tasks, 157 components, 12 subsystems, 333 handovers, and the full codebase.*
