# T-198: Human Sovereignty Gate Design — R-033 Remediation

**Task:** T-198
**Risk:** R-033 (score 12, HIGH) — Human-owned tasks auto-completed without human
**Date:** 2026-02-19
**Participants:** Human (design decision), Agent (analysis + implementation)

## Problem Statement

R-033 identifies that agents can auto-complete human-owned tasks without human interaction. Evidence: T-151 was completed in 2 minutes with no human consultation. Specification and inception tasks with `owner: human` were completed by the agent unilaterally.

Prior to T-198, the only mitigation was CTL-025 (P-010 AC split from T-193), which creates partial-complete state for tasks with `### Human` ACs — but this doesn't prevent agents from completing human-owned tasks that lack the split headers.

## Options Analyzed

### Option A: Owner Gate in update-task.sh
- When `owner: human` and agent tries `--status work-completed`, block it
- Simple, surgical — one check in the status transition logic
- **Downside:** Agent can change owner first (`--owner agent`), then complete — needs protection of the owner field too

### Option B: Workflow-Type Gate
- Block agent completion for `specification` and `inception` workflow types entirely
- These are inherently human-directed — agent assists but human decides
- **Downside:** Sometimes agent legitimately completes inception tasks after `fw inception decide`; too blunt

### Option C: Combined Owner + Interaction Gate
- Block completion when `owner: human` AND no human message was received since task started
- Requires tracking "last human interaction" timestamp
- **Downside:** Most precise but hardest to implement in bash; complex to audit

### Option D: Owner Field Protection
- Make `owner: human` sticky — agent cannot change it via `fw task update`
- Only human can change ownership (or explicit `--force` with logging)
- Combines well with Option A for two-layer defense

## Dialogue Log

**Agent:** Presented 4 options (A, B, C, D) with trade-offs for each.

**Human:** "D, and A on top of it"

**Rationale:** Two-layer defense — D prevents circumvention (agent can't just change owner to bypass), A blocks the completion action itself. Together they close both attack vectors.

## Decision

**Chose:** Option D (sticky owner) + Option A (completion gate)

**Why:** D prevents circumvention, A blocks the completion. Two-layer defense that's simple, auditable, and bash-implementable.

**Rejected:**
- B (workflow-type gate) — Too blunt, blocks legitimate inception completion
- C (interaction tracking) — Too complex for bash, hard to audit, fragile timestamp tracking

## Implementation

Two structural gates added to `agents/task-create/update-task.sh`:

1. **Sovereignty Gate (line ~198):** Before P-010 AC check, if `owner: human` and transitioning to `work-completed`, exit 1 with clear error message
2. **Owner Protection (line ~344):** When `--owner` changes from `human` to anything else, exit 1

Both gates:
- Bypassed with `--force` (with warning logged)
- Don't interfere with partial-complete re-run path (T-193, line 126 — separate code path)

**Control:** CTL-026 registered in `.context/project/controls.yaml`
**Risk:** R-033 updated to `control_status: implemented` with controls [CTL-025, CTL-026]
**OE Test:** Added to `agents/audit/audit.sh` (oe-daily section)

## Residual Risk

- Agent could use `--force` to bypass both gates
- Tasks could be created with wrong owner (should be `human` but set to `agent`)
- The `--force` flag is available to both human and agent — no way to distinguish caller in bash

## Related Artifacts

- T-194: ISO 27001-aligned assurance model (origin of R-033 analysis)
- T-193: P-010 AC tagging (CTL-025, predecessor control)
- R-033 in `.context/project/risks.yaml`
- CTL-026 in `.context/project/controls.yaml`
