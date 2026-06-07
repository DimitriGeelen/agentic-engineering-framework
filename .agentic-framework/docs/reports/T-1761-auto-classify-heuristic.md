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

## Re-evaluation — 2026-05-31 (S-2026-0531-2025+1)

The DEFER decision listed three triggers. **Trigger #1 has fired twice.**

### Batch cadence since filing

| Batch | Task | Date | Tools | Gap from prior |
|-------|------|------|-------|----------------|
| 1 | T-1755 | 2026-05-06 | 59 | (filing) |
| 1b | T-1755 f/u | 2026-05-06 | 2 | same day |
| 2 | T-1760 | 2026-05-06 | 18 | same day |
| 3 | T-1867 | 2026-05-15 | 14 | 9 days |
| 4 | T-2073 | 2026-05-28 | 74 | 13 days |
| 4b | T-2073 f/u | 2026-05-28 | 4 | same day |
| 5 | T-2150 | 2026-05-31 | 5 | **3 days** |

**Cadence is sustained.** The filing-time assumption ("3 batches in one day looks like a pulse") was wrong — the third batch was followed by 4 more over 25 days. Trigger #1 (4th batch in <14 days) is satisfied by T-2073 (13 days post T-1867) AND by T-2150 (3 days post T-2073).

### Cumulative toil vs implementation cost

| | Filing estimate | Actual to date |
|--|----------------|----------------|
| Toil per batch | ~15 min | ~15 min (consistent) |
| Implementation | ~30-45 min | unchanged |
| Batches | 3 | 7 (5 main + 2 follow-ons) |
| Cumulative toil | ~45 min | **~105 min** |

We have now spent **2.3× the implementation estimate** on the toil. Status quo is no longer cost-neutral.

### Misclassification record

In 7 batches across ~196 tools, zero `_typing`-style misclassifications have been reported. The naming convention is holding. Filing-time concern ("conservative manual review catches naming-shape ambiguities") proved over-weighted — the convention is robust enough that manual review is mostly rubber-stamping.

### Revised recommendation

**Recommendation:** GO (implement the heuristic)

**Rationale:** Both the cadence trigger AND the cost ratio have crossed. Adding the heuristic now (~30-45 min) saves all future ~15min batches; the misclassification fear that justified DEFER is no longer evidence-supported after 196 correct classifications. Lower-risk alternative (ratchet command) from the original artifact remains a viable implementation shape — see §Implementation shapes below.

### Implementation shapes (for build follow-up)

If GO is approved, the build task should consider:

1. **Auto-classify mode (default off)**: Heuristic runs in `orchestrator-mcp-scan.sh`, emits suggested classification per new tool, requires `--apply` to write to baseline. Keeps human in the loop, removes YAML editing toil.
2. **Ratchet command**: `fw orchestrator-mcp ratchet --apply` reads current scan output, applies the convention, opens a diff for human review. Slightly more lifting for the operator.
3. **Hybrid**: Convention auto-applies for `termlink_agent_*` / `termlink_channel_*` namespaces (proven safe); other namespaces continue to require manual classification (where ambiguity is higher).

Option 3 minimizes blast radius — keeps manual review where it adds value (new namespaces), removes it where it doesn't (sustained `termlink_agent_*` and `termlink_channel_*` growth).

## Original DEFER recommendation (2026-05-06 — historical)

**Recommendation:** DEFER

**Rationale:** Marginal leverage at current cadence. Implementation cost roughly equals 3 batches of manual toil. Misclassification risk asymmetric (mutator-as-readonly bypasses governance silently). Status quo provides per-batch human review at low cost.

**Evidence:**
- T-1755 + T-1755 follow-up + T-1760 cumulative ~35 min effort across 3 commits
- Naming convention works but is informal — codifying it formalizes an assumption that may not hold for non-`termlink_agent_*` namespaces
- Lower-risk alternative (ratchet command) noted above

(Superseded by the 2026-05-31 re-evaluation above.)
