**Surfacing is NOT MET:** repeated audits can push repeatedly for the same red state, while a checker-startup failure produces no dedicated push.

| Agent AC | Verdict | Evidence |
|---|---|---|
| RCA written for AEF and TermLink | **MET** | The task’s [RCA](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3783-vector-database-semantic-recall-health-a.md:275) covers missing consumer scheduling, silent import failures, ineffective health checks, and TermLink/010 findings. |
| Freshness check with configured thresholds and audit/doctor failure | **MET** | [Age and lag checks](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:144) reject stale timestamps and excessive source drift, including edited and deleted sources. [Audit](/opt/999-Agentic-Engineering-Framework/agents/audit/audit.sh:4903) maps FAIL to failure; [doctor](/opt/999-Agentic-Engineering-Framework/bin/fw:2587) increments issues. |
| Liveness and a real canary query; failure = FAIL | **MET** | The predicate checks readable, nonempty documents and imports. Its [child](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:293) calls `verify_canaries(E._semantic_search, token)`. [Production search](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:1239) embeds the query and executes sqlite-vec KNN; this is a real index query. |
| Handover, operator push on red transition, consumer delivery | **NOT MET** | Handover wiring exists and all ten inspected source/vendor pairs match. However, notification behavior has the two gaps below. |
| Hermetic tests for stale index, missing index, failing canary | **MET** | [The test suite](/opt/999-Agentic-Engineering-Framework/tests/unit/t3783_vector_index_health.bats:99) contains all three fixtures with exit-2 and FAIL assertions. Its search stub queries fixture SQLite data. This establishes test coverage, not a fresh suite-pass claim. |

The blocking findings are:

1. **Operator pushes are not once per transition across the audit surface.** The dedicated alert uses locked, timestamp-ordered [transition recording](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:474). But [audit’s final notification block](/opt/999-Agentic-Engineering-Framework/agents/audit/audit.sh:8570) independently calls `fw_notify` whenever `FAIL_COUNT > 0`. A persistent vector failure therefore causes an additional generic push every audit. Executing that actual block twice with a printing notification stub produced two pushes. Existing push tests exercise the wrapper, not this audit path.

2. **Checker-startup failures never claim a transition or push.** The shell [empty-output fallback](/opt/999-Agentic-Engineering-Framework/lib/vector-index-health.sh:32) prints FAIL, but notification requires `TURNED_RED`, which that fallback never emits. I reproduced two full calls with an unavailable checker: both returned FAIL/exit 2, with zero notification calls. The Python crash test only covers exceptions after the checker has successfully started.

Your specific failure-path questions:

- **Stale or unimportable without FAIL?** The new predicate rejects excessive age/drift and failed imports. Drift within the configured allowance remains permitted.
- **Missing or empty manifest accepted anywhere?** The new predicate rejects both; direct probes confirmed manifest and age FAIL. **Legacy checks still can mislead:** [index_freshness()](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:402) falls back to database mtime for either case. [corpus_health()](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:430) returns `unknown` for missing manifests and can return `ok` for `{}` when canaries pass. These are outside the newly wired rails, as the brief acknowledges.
- **Canary really queries the index?** Yes in production; hermetic tests substitute SQLite word-overlap search for embeddings.
- **Push once per transition?** Only the dedicated notification attempt is deduplicated; the complete audit path is not.

Validation was read-only. I ran in-memory probes and notification-stub reproductions; I did not run filesystem-writing Bats fixtures or generate a committed handover under this session’s read-only restriction.

**VERDICT: FAIL**