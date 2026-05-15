# T-1761 — orchestrator-mcp-scan auto-classify by naming convention

**Status:** Inception, deferred (horizon: later)
**Filed:** 2026-05-06
**Origin:** T-1760 Evolution section — third batch of `termlink_agent_*` classifications in one day

## Problem

`agents/audit/orchestrator-mcp-scan.sh` flags new MCP tools as "unclassified" when they appear in `/opt/termlink/crates/termlink-mcp/src/tools.rs` but aren't yet in `.context/audits/orchestrator-mcp-baseline.yaml`. T-1755 introduced a naming-convention rule:

- Action verbs (`_post`, `_react`, `_pin`, `_edit`, `_redact`, `_reply`, `_ack`, `_emit`, etc.) → mutator
- Read-shape suffixes (`_history`, `_status`, `_summary`, `_stats`, `_state`, `_info`, `_search`, `_recent`, `_threads`, etc.) → readonly

T-1755 (59 tools), T-1755 follow-up (2 tools), T-1760 (18 tools) — three batches in one day, each requiring manual baseline edit + commit + episodic.

## Question

Should the convention be encoded as a heuristic in the scan script — so new read-shape tools auto-classify into `readonly_exempt` without manual intervention?

## Tradeoff

| Factor | Encode heuristic | Status quo |
|--------|------------------|------------|
| Implementation cost | ~30-45 min (heuristic logic + tests + flag for opt-in) | 0 |
| Per-batch savings | ~15 min × N batches | 0 |
| Misclassification risk | Heuristic could mark a mutator as readonly if name shape is misleading | Manual eyes on every tool |
| Auditability | Auto-classifications harder to track | Each commit explains why |
| Reversibility | Trivial — just remove the heuristic | N/A |

## Defer rationale

- **Cadence unclear.** 3 batches in one day looks like a pulse (upstream feature push), not a sustained rate. If upstream slows, savings vanish.
- **Cost-symmetric.** Implementation ≈ ~3 batches of toil. Break-even after 3 future batches.
- **Misclassification cost is high.** A mutator silently classified as readonly bypasses governance. Conservative manual review catches naming-shape ambiguities (e.g. `_typing` was technically observable side effect → mutator despite read-shape name).
- **Better alternative may exist.** A "ratchet" command (`fw orchestrator-mcp ratchet --apply` reading current scan output and applying the convention) is lower-risk than always-on auto-classify — keeps human review in the loop but eliminates manual YAML editing.

## Decision

DEFER. Re-evaluate when:
1. A 4th batch arrives in <14 days (sustained cadence), OR
2. A `_typing`-style naming-shape misclassification is reported, OR
3. The framework gets a generic per-MCP-server convention-based classifier (cross-cutting infrastructure)

## Recommendation

**Recommendation:** DEFER

**Rationale:** Marginal leverage at current cadence. Implementation cost roughly equals 3 batches of manual toil. Misclassification risk asymmetric (mutator-as-readonly bypasses governance silently). Status quo provides per-batch human review at low cost.

**Evidence:**
- T-1755 + T-1755 follow-up + T-1760 cumulative ~35 min effort across 3 commits
- Naming convention works but is informal — codifying it formalizes an assumption that may not hold for non-`termlink_agent_*` namespaces
- Lower-risk alternative (ratchet command) noted above
