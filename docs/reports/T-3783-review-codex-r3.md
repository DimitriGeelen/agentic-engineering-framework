Two gaps remain: deleted sources escape the freshness check, and checker crashes bypass operator notification.

| Agent AC | Verdict | Evidence |
|---|---|---|
| RCA covering AEF and TermLink | **MET** | The [RCA]( /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3783-vector-database-semantic-recall-health-a.md:275) identifies missing consumer cron seeding, import failures, ineffective health checks, and silent recall fallback, including TermLink’s instance. |
| Freshness beyond configured threshold produces FAIL | **NOT MET** | [_source_drift](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:235) scans only surviving files. Deleted sources retained in the index never count. An in-memory SQLite reproduction with **51 deleted indexed reports and `max_lag=0` returned OK, zero drift**. With a recent manifest and healthy canaries, this stale content escapes FAIL. |
| Index liveness and real canary query | **MET** | The checker opens SQLite, checks documents, and tests imports. Its child invokes `verify_canaries(E._semantic_search, token)`; [_semantic_search](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:1239) embeds the query and executes sqlite-vec KNN. Both expected canary paths must rank first. |
| Handover, operator push on red, consumer upgrade | **NOT MET** | Handover wiring and vendored parity are present. However, [exception handling](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:567) assigns `full=False`, suppressing `record()` and notification even for requested full runs. Reproduced with `FW_INDEX_MAX_LAG=Infinity`: exit 2, FAIL, `turned_red=false`; an injected exception likewise produced zero recording calls. |
| Hermetic tests for stale/missing index and failing canary | **MET** | [Tests](/opt/999-Agentic-Engineering-Framework/tests/unit/t3783_vector_index_health.bats:99) explicitly assert exit 2 and the corresponding FAIL messages using isolated fixtures. This verifies test coverage by inspection; I did not execute Bats under the read-only sandbox. |

The specific checks you requested:

- **Stale or unimportable without FAIL:** unimportable modules produce FAIL in the new predicate. Deleted-source staleness can still pass, as reproduced above.
- **Missing or empty manifest:** both produce FAIL in the new predicate. However, legacy [index_freshness()](/opt/999-Agentic-Engineering-Framework/web/embeddings.py:402) still falls back to database mtime, and [web health](/opt/999-Agentic-Engineering-Framework/web/app.py:350) can report embeddings `status: ok` without a valid manifest. The new doctor/audit paths no longer use that fallback.
- **Canary actually queries the index:** yes. Production uses vector search; hermetic tests substitute a SQLite-backed lexical search.
- **Push once per transition:** ordinary recorded transitions are protected by [flock and timestamp ordering](/opt/999-Agentic-Engineering-Framework/lib/vector_index_health.py:489). This provides one notification attempt per recorded transition, not guaranteed delivery. Checker-crash transitions currently produce no attempt.

Validation used read-only inspection and in-memory reproductions. No files were changed; the read-only sandbox also prevented generating the required committed handover.

VERDICT: FAIL