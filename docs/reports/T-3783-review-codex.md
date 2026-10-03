Two Agent ACs are **NOT MET**: source freshness and reliable operator notification.

1. **RCA — MET.** The task’s [RCA](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3783-vector-database-semantic-recall-health-a.md:273) documents the missing consumer cron job, silent import failures, ineffective health checks, and recall fallback in AEF and TermLink.

2. **Freshness — NOT MET.** [check_age](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:133) measures manifest completion time. [check_lag](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:163) counts missing task and learning IDs. Neither compares indexed content with current decisions, episodics, reports, or edits to existing items. A fresh manifest and retrievable canaries can therefore coexist with stale source content without FAIL. Additionally, read-only probes confirmed `finished_at: NaN` and `Infinity` both produce **OK** for manifest and age.

3. **Liveness + canary — MET.** The checker rejects missing, empty, and unreadable indexes, import failures, timeouts, and canary misses. The [child calls `_semantic_search`](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:205), which [embeds the query and executes sqlite-vec KNN](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:1239). This really queries the index. However, [canary verification](/opt/999-Agentic-Engineering-Framework/web/canary.py:188) checks fixed document paths, **not the manifest token’s presence**, so it does not establish build freshness.

4. **Surfacing — NOT MET.** Handover, doctor, audit, reindex, and upgrade wiring exists; the inspected vendored files match. But **push is not guaranteed once per transition**:
   - [record()](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:383) performs an unlocked read/modify/write. An in-memory concurrency probe returned `[True, True]`: two overlapping callers both claim the same transition.
   - State is recorded before notification. [Notification failures are suppressed](/opt/999-Agentic-Engineering-Framework/lib/vector-index-health.sh:45), so a failed push is not retried while the state remains FAIL.
   - State-write failures are swallowed, potentially causing repeated pushes.

5. **Hermetic regression tests — MET.** The [test suite](/opt/999-Agentic-Engineering-Framework/tests/unit/t3783_vector_index_health.bats:90) contains isolated fixtures and explicit red assertions for stale manifests, missing indexes, and failing canaries. Notification tests exercise sequential calls, leaving the concurrency defect uncovered.

**Missing/empty manifest:** the new shared predicate correctly FAILs both. However, the retained [legacy `corpus_health()`](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:419) returns `unknown` for a missing manifest and can return `ok` for `{}` if canary paths are retrieved. Doctor/audit now use the stricter predicate.

Validation was read-only: inspected code/tests and ran in-memory probes. The Bats suite and `fw handover --commit` were not run because this session prohibits filesystem writes.

VERDICT: FAIL