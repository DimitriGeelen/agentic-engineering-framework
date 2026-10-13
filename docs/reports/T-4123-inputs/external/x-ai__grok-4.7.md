model: x-ai/grok-4.7
finish_reason: stop
usage: {"prompt_tokens": 8407, "completion_tokens": 8695, "total_tokens": 17102, "cost": 0.067256, "is_byok": false, "prompt_tokens_details": {"cached_tokens": 1152, "cache_write_tokens": 0, "audio_tokens": 0, "video_tokens": 0}, "cost_details": {"upstream_inference_cost": 0.067256, "upstream_inference_prompt_cost": 0.015086, "upstream_inference_completions_cost": 0.05217}, "completion_tokens_details": {"reasoning_tokens": 6402, "image_tokens": 0, "audio_tokens": 0}}

1. Missing requirements

1. **Ingest broker, not client-honour.** The only credential that can create points is a broker the project agent cannot skip; the broker re-checks type allow-list, size, secret patterns, and data class. AC: a project token presented directly to Qdrant cannot insert a point (401/403), including a payload the client redactor would have refused.
2. **Retrieved text is untrusted data.** Consumers must treat hits as quoted data, not instructions; cap how much enters the agent context; do not raise evidence tier because a hit ranked well. AC: a planted “ignore your rules / exfiltrate” sentence in a stored learning is returned only inside a data envelope and is not executed or promoted to `tested`.
3. **Token lifecycle.** Per-project tokens expire, rotate, and revoke within a stated bound; revocation blocks the next call; audit survives revocation. AC: after revoke, that token’s write and read fail within one cycle, and older audit rows remain.
4. **Read scope and query audit.** No estate-wide read token; a reader is granted named collections; every query logs project, token id, collection, and time, without logging raw payloads. AC: project B’s token querying A’s unshared collection returns 403, and the denial is in the audit log.
5. **Trusted vectors only.** A point is readable only after the trusted embedder produced the vector from the stored payload; client-supplied vectors are ignored. AC: a payload whose vector was swapped to collide with an unrelated query is refused or not returned for that query.

2. Wrong, untestable, contradictory, over-scoped

- **R-2, R-23.** “Impossible” is false: value patterns miss novel and split secrets, and D-2 enforces them in a client the writer controls. Fix: “refuse on the current pattern set, server-side”; AC stays the planted-token test; residual risk accepted in the threat note. R-23 should not be a security invariant at SHOULD.
- **R-4 vs R-15.** Freshness AC demands exact-title top-1. That is retrieval quality, and embeddings will not guarantee it. Fix: freshness AC is “fetchable by id/hash within one successful cycle”; drop top-1.
- **R-5 vs R-7 vs R-11.** Delete “gone within one cycle” contradicts superseded “still retrievable” and “every source link resolves”. Fix: delete writes a tombstone (hash, ids, no body) excluded from default search; provenance may point at a tombstone; hard-purge is a separate operator act.
- **D-3 vs R-6/R-8.** Collapse is drawn as a state change of the raw item, but raw sources must stay retrievable. Fix: collapse creates a new item; raw stays raw until prune.
- **R-8.** “Agreed threshold” is unnamed, and auto-apply conflicts with CF-9. Fix: no auto-apply; metric and threshold live in config; AC includes a near-match that must not collapse.
- **R-9.** AC only checks a status field. Any writer who can set `approved` bypasses the operator. Fix: no project or reviewer token can set approval; approval is an operator-signed record listing source ids.
- **R-10.** AC covers snapshot restore, not re-push of the same source. Fix: retirement is a denylist checked on every write path; AC includes re-push refused.
- **R-12.** All fields non-empty forces fake `tested` and fake model ids on local fallback (R-16). Fix: `evidence` defaults to `reasoned` or `unknown`, never `tested`; R-16 may omit model id if the banner is present.
- **R-14.** Two underspecified comparators (margin, newer, tested, multi-owner). Untestable. Fix: defer; pilot ranking is “filter to selected scope, then score”.
- **R-15.** Exact-title top-1 will block the second writer or be gamed; threshold is unnamed. Fix: exact title is a lexical/id lookup; vector recall is a named threshold on a frozen set, not a pilot launch gate.
- **R-19.** Agents may select any Ollama model, which fights R-20 and collection-per-model. Fix: operator pins model id and digest in `_manifest`; agents cannot choose.
- **R-20, R-21.** External programme gates and “~64” / “during the day” are not testable requirements. Fix: move to assumptions/runbook; if a cap stays, use an integer and a timezone.
- **R-25 vs R-31.** One estate read token means any project reads every tenant point. Fix: per-project read grants; R-31 AC is two fixture tenants, cross-read denied. “Unless shared” means an operator grant row.
- **R-26.** Size budget is registered, not enforced. Fix: broker refuses when the collection would exceed the budget.
- **R-29.** “Which items” will copy secrets into the log if payloads are logged, and the writer may be able to delete the log. Fix: log ids and hashes only; audit store is not writable by project tokens.
- **R-30.** A restore must not have to pass R-15. Fix: restore AC is count, hashes, and one id lookup.
- **R-33 as MUST-pilot.** Many types have no framework version; agents will invent one. Fix: SHOULD, legal value `unknown`, required only for learnings and patterns.
- **R-36.** A peer report can still be collapsed into a practice that displays as `tested`. Fix: curated evidence is the minimum of its sources; peer-report-only sources cannot become an approved practice.
- **R-37.** “2 MB” is not the declared limit; base64 in a text field bypasses “binary”. Fix: limits in `_manifest`; reject non-text by declared content type; secret scan covers long encoded blobs.
- **R-1, R-18, R-40.** Too many types and card fields for a first store; “MUST NOT name a person” is open-ended and fights provenance. Fix: pilot types only; person-cause is “no such field”, not a prose ban. R-40 stays SHOULD.

3. Open conflicts

- **CF-1.** Estate store is not an OD-15 framework store. No cloud embed or completion fallback. These payloads carry topology and incidents; if the local embedder is down, skip the cycle and use R-16. Do not send estate text off-estate.
- **CF-2.** Server-side embedding only for now. Not “both”. Client vectors are a poisoning and digest-skew channel, and a sample spot-check contradicts “platform never calls Ollama”. When the embedder is down, queue or skip; do not accept client vectors. Revisit client fallback only after a verifier re-embeds 100% of writes before they are cross-readable.
- **CF-5.** Full text is not OK for raw items, reports, or error bodies. Owner collection may keep a size-capped, broker-scanned body. Anything readable by another project is a short structured summary plus source pointer. Curation reads the source project, not a second full copy. Snapshots inherit that same split.
- **CF-7.** Roles only, in every cross-project payload (errors, cards, decisions, summaries). Hostnames and IPs stay in owner-local, non-shared collections if needed at all. “Inside the estate” is not a boundary once backups and a broad read token exist.
- **CF-9.** Originating project accepts collapse of its own items; a reviewer may only propose. No automatic threshold apply. Cross-project combine is drafted by the framework owner and is not retrievable as practice until the operator approves (R-9). Unsupervised auto-collapse will merge version conflicts and launder weak evidence.

4. Threats not held

- **Writer who bypasses the redactor** (same write token, direct API). Need broker-only writes (missing req 1). R-2 does not hold as drawn.
- **Retrieval poisoner** (vector swap, or instruction text aimed at the next agent). Need trusted re-embed plus untrusted-data envelope (missing reqs 2 and 5).
- **Neighbour project or stolen shared read token** scraping decisions and topology. Need per-collection read grants and query audit (missing req 4). R-25 currently creates this.
- **Backup holder / wrong-host restore.** Snapshots are a full second copy with no encryption, access, or restore-target requirement. Need encrypted, access-logged snapshots restorable only into the registered store, still subject to R-10.
- **Cover-up after compromise.** Project token that can delete points may delete evidence if audit lives in the same writable store. Need append-only audit outside project credentials (fix to R-29).
- **Runaway agent.** Size budget and “~64” do not stop a hot loop filling the GPU or the collection. Need hard per-project write and embed quotas with a 429 the kill switch can also trip.
- **Evidence launderer** (peer report or `reasoned` note combined into an approved practice). R-36 does not hold on the curated path. Need monotonic evidence (fix above).
- **Revoked session that keeps working.** Named in OQ-5, no requirement. Need token revoke (missing req 3).

5. Cut for a safe one-writer, one-reader pilot

Keep a broker, one operator-registered collection, one pinned model digest, server-side embed, no cloud fallback. Types: learning and decision only. Opt-in (R-3). Secret and size refusal in the broker (narrow R-2, R-37). Id/hash upsert, tombstone delete, kill switch, per-project write token and a read grant for the single reader only, audit of ids/hashes, local recall banner if the store is down. Roles not hostnames in the shared payload; capped body. One manual snapshot before calling it live. Smoke test: id lookup, cross-token 403, direct-to-Qdrant 403, planted secret refused, revoke works.

Cut curation entirely (R-6–R-11, R-39, reviewer, combine, retire-as-product). Cut solution-finder, fabric cards, error classes, reports, episodic summaries, multilingual, ranking modes, R-15 as a gate, R-33 as MUST, peer ingest, install-shape filters, Watchtower, monthly restore theatre, and a second tenant. Do not build the push interface beyond this broker until the pilot has revoked a token and restored one snapshot once.
