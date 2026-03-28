# T-566: OpenClaw Comparative Synthesis — What Would You Steal?

## Summary of All Comparatives

| Task | Topic | Decision | What to steal |
|------|-------|----------|---------------|
| T-561 | Tool call policy enforcement | GO (partial) | Enhanced loop detection (3 missing detectors) |
| T-562 | Safety guardrails | NO-GO | Nothing — our model is more comprehensive |
| T-563 | Extension SDK design | NO-GO | Auto-discovery pattern (later, if needed) |
| T-564 | Agent isolation | NO-GO | Covered by T-582 (session namespace) |
| T-565 | Monitoring/observability | NO-GO | Background health probe (already in T-583) |

## The Three Things Worth Stealing

### 1. Enhanced Loop Detection (from T-561)

**What:** Add 3 detectors to our existing `loop-detect.ts`: same-params duplicate, oscillation between two tools, total session limit.

**Why:** OpenClaw's 4-detector approach is more robust than our single detector. Loop runaway has been observed in our framework (T-578 findings).

**Effort:** ~1 session. **Priority:** Low — advisory only, rare occurrence.

### 2. Session-Scoped Namespacing (from T-582, inspired by T-564)

**What:** Namespace `focus.yaml` and `.budget-status` per session ID. Prevents concurrent agent corruption.

**Why:** Already hit in practice (fw-agent + openclaw-eval concurrent sessions). OpenClaw's session key pattern validates the approach.

**Effort:** ~1 session. **Priority:** Medium — blocks TermLink multi-agent dispatch reliability.

### 3. Background Health Probe (from T-583, inspired by T-565)

**What:** Counter-based quick probe in checkpoint.sh, runs every 20th tool call. 5 checks under 200ms.

**Why:** OpenClaw's 5-min health monitor caught stale connections. We've had silent hook failures mid-session (check-project-boundary.sh incident).

**Effort:** ~1 session. **Priority:** Medium — prevents silent mid-session failures.

## What NOT to Steal

| Pattern | Why not |
|---------|---------|
| Per-tool policies | Our tier model is more principled |
| Rate limiting | Single-agent, no abuse vector |
| Deduplication | Sequential processing, no concurrency |
| Extension SDK | We want governed agents, not community plugins |
| Multi-provider failover | Single provider (Anthropic) |
| Channel isolation | No channels |

## Meta-Finding: Architectural Divergence

OpenClaw is a **multi-tenant platform** optimized for scale, isolation, and community extensibility. Our framework is a **single-agent governance system** optimized for discipline, traceability, and structural enforcement.

Most of OpenClaw's sophistication addresses problems we don't have (multi-tenancy, concurrent agents at scale, community trust). Our sophistication addresses problems they don't have (agent discipline, task governance, human authority).

The three adoptable patterns above are the genuine overlap — problems that exist regardless of architecture.
