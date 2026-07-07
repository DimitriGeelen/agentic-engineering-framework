# T-1732 — prompt-triage as G-064 first real consumer — orchestrator-driven user-prompt

> **Inception research artifact** (backfilled by T-2515 from the `T-1732` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1732-prompt-triage-as-g-064-first-real-consum.md`. **Decision recorded: GO.**

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Recommendation

**Recommendation:** GO

**Rationale:**

Layer-1 mitigation from T-1729 meta-RCA: UserPromptSubmit hook routes user message through fw resolver dispatch with prompt-triage workflow (ollama-local default, cloud fallback, fail-OPEN, latency target <500ms p95, cost cap $0.001/call). Verdict: GO/NO-GO/DEFER on whether prompt requires task creation. On GO, surface additionalContext warning the agent. Closes G4 (text output has no surface for governance) which structural fixes 1+2 cannot reach. Promotes to v0.5 over T-1726 escalation-scan because: higher severity (governance bypass > symptom-fix), hot-path (per-prompt vs daily), visible win on every prevented breakdown. T-1726 demoted to v0.6 (same envelope shape, near-zero incremental cost). Recommendation GO because spike path is bounded (Spike A: latency/cost; Spike B: precision/recall on 30-day backlog), substrate (T-1689/1690/1691/1692) is shipped, and the failure class is recurring.

**Evidence:**

## Decision

**Decision**: GO

**Rationale**: Layer-1 mitigation from T-1729 meta-RCA: UserPromptSubmit hook routes user message through fw resolver dispatch with prompt-triage workflow (ollama-local default, cloud fallback, fail-OPEN, latency target <500ms p95, cost cap $0.001/call). Verdict: GO/NO-GO/DEFER on whether prompt requires task creation. On GO, surface additionalContext warning the agent. Closes G4 (text output has no surface for governance) which structural fixes 1+2 cannot reach. Promotes to v0.5 over T-1726 escalation-scan because: higher severity (governance bypass > symptom-fix), hot-path (per-prompt vs daily), visible win on every prevented breakdown. T-1726 demoted to v0.6 (same envelope shape, near-zero incremental cost). Recommendation GO because spike path is bounded (Spike A: latency/cost; Spike B: precision/recall on 30-day backlog), substrate (T-1689/1690/1691/1692) is shipped, and the failure class is recurring.

**Date**: 2026-05-05T06:47:22Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-12cebc37
- **Timestamp:** 2026-06-02T14:59:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-05T06:47:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
