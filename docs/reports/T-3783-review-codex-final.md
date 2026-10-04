**Surfacing remains NOT MET. Both round-4 blocking findings are still open at HEAD `d06a584010d3f8e8bbb28ae6f9aa027d122b5c77`.**

Reviewed the brief, all five earlier review files, and the cited implementation/tests from HEAD, including T-3786.

| Agent AC | Verdict | Evidence |
|---|---|---|
| RCA for AEF and TermLink | **MET** | The [task RCA](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3783-vector-database-semantic-recall-health-a.md:275) covers missing consumer scheduling, import failures, misleading checks, and silent recall fallback, including TermLink. Historical measurements were not independently reverified. |
| Configurable freshness check; stale produces audit/doctor failure | **MET** | [Age checking](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:144) rejects invalid/stale timestamps. Source drift hashes current content and counts deleted indexed sources. Excessive lag produces FAIL; audit calls `fail`, and doctor increments `issues`. |
| Index liveness and actual canary query; failure produces FAIL | **MET** | The predicate rejects missing, unreadable and empty indexes, import failures, timeouts and canary misses. [Production search](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:1287) embeds the query and executes sqlite-vec `MATCH`; canary verification requires the expected top hits. |
| Handover, operator push when red, consumer delivery | **NOT MET** | [Handover wiring](/opt/999-Agentic-Engineering-Framework/agents/handover/handover.sh:450) and upgrade delivery exist; nine inspected source/vendor pairs match. However, startup failures produce no dedicated notification, and repeated audits independently notify for an unchanged red state. |
| Hermetic stale/missing-index/failing-canary tests | **MET by inspection** | The [29-test suite](/opt/999-Agentic-Engineering-Framework/tests/unit/t3783_vector_index_health.bats:99) contains the required fixtures and explicit exit-2/FAIL assertions. The canary stub queries fixture SQLite data. |

The two blocking findings are reproducible without filesystem writes:

1. **Repeated audit notifications — still open.** The [audit notification block](/opt/999-Agentic-Engineering-Framework/agents/audit/audit.sh:8570) calls `fw_notify` whenever `FAIL_COUNT > 0`, independently of vector transition recording. Executing that HEAD block twice with `FAIL_COUNT=1` and a notification stub produced **two notification calls**. A persistent vector failure therefore generates repeated generic audit notifications, in addition to its initial dedicated alert.

2. **Checker-startup failure lacks a transition notification — still open.** The [shell fallback](/opt/999-Agentic-Engineering-Framework/lib/vector-index-health.sh:32) prints FAIL but never records it or emits `TURNED_RED`. Running the actual wrapper twice with a stubbed unavailable Python returned **FAIL/exit 2 twice, with zero notification calls**.

Earlier finding disposition:

| Earlier finding | Final status |
|---|---|
| R1: NaN/Infinity timestamps passed | **Fixed.** Finite timestamp validation; direct probes returned manifest and age FAIL. |
| R1: edits to decisions, episodics, reports and existing items escaped freshness | **Fixed.** Content hashes now contribute to drift. |
| R1: canary paths did not establish manifest/index token agreement | **Fixed for the reported mismatch.** Separate `check_token()` requires the manifest token in indexed canary content. |
| R1: concurrent recorders claimed duplicate transitions | **Fixed.** [Recording uses an exclusive lock](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:474). |
| R1: state-write failures could repeatedly push | **Fixed against repetition.** Failed persistence claims no transition; this also means no dedicated push in that case. |
| R1: failed notification is never retried | **Still present, explicitly documented.** Notification is fire-and-forget; deduplication guarantees neither delivery nor retry. |
| R1–R3: legacy manifest checks can mislead | **Still open outside the new predicate.** Details below. |
| R2: preserved timestamps hid changed content | **Fixed.** Hashing no longer depends on mtime. |
| R2: older OK overwrote newer FAIL | **Fixed.** Recording rejects older observation timestamps under the lock. |
| R3: deleted indexed sources escaped drift | **Fixed.** Missing paths from `file_state` count toward drift. |
| R3: evaluation exceptions suppressed recording/push | **Fixed for exceptions inside evaluation.** The [exception verdict preserves full-run status](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:575). Startup failures remain distinct and unfixed. |
| R3: nonfinite configuration crashed or disabled limits | **Fixed.** Invalid numeric values fall back to defaults. |
| R4 and unnumbered review: repeated audit pushes; startup failure without push | **Both still open**, reproduced above. |

Answers to the requested checks:

- **Can stale, empty or unimportable pass?** The shared full predicate rejects excessive age/drift, zero documents and failed imports. Drift within the configured allowance is intentionally accepted. T-3786’s [`_get_db()`](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:470) now raises `IndexUnavailable` instead of rebuilding, so the canary no longer triggers that destructive reader behavior.
- **Does any check accept missing/empty manifests?** The new predicate rejects both. But legacy [`index_freshness()`](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:380) still falls back to database mtime; `corpus_health()` returns `unknown` for missing manifests and can return `ok` for `{}`. Direct probes confirmed these behaviors. [Watchtower `/health`](/opt/999-Agentic-Engineering-Framework/web/app.py:350) can still report embeddings `status: ok` with an open handle, without validating the manifest or requiring a positive document count.
- **Does the canary really query the index?** **Yes**, through production embedding and sqlite-vec retrieval. Hermetic tests establish wiring using SQLite-backed lexical retrieval.
- **Is operator push once per transition?** **No across all surfaces.** Dedicated normal-transition attempts are deduplicated; audit notifications bypass that state, and startup failures generate no dedicated attempt.

Validation remained read-only: HEAD inspection and in-memory/stub probes. No files were modified, no notifications were sent, and filesystem-writing test suites or handover commands were not run.

VERDICT: FAIL