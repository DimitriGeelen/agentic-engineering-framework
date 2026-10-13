model: openai/gpt-5
finish_reason: stop
usage: {"prompt_tokens": 7153, "completion_tokens": 6293, "total_tokens": 13446, "cost": 0.07187125, "is_byok": false, "prompt_tokens_details": {"cached_tokens": 0, "cache_write_tokens": 0, "audio_tokens": 0, "video_tokens": 0}, "cost_details": {"upstream_inference_cost": 0.07187125, "upstream_inference_prompt_cost": 0.00894125, "upstream_inference_completions_cost": 0.06293}, "completion_tokens_details": {"reasoning_tokens": 4032, "image_tokens": 0, "audio_tokens": 0}}

1) The 5 most important missing requirements (with one-line AC)
- MR-1 Sharing policy per collection/item: Every item MUST carry a sharing scope (own-only or estate-visible) enforced at query time. AC: A cross-project query never returns items marked own-only; an own-project query does.
- MR-2 Token revocation and rotation: Operator MUST be able to revoke any read/write token within 10 minutes and rotate tokens quarterly without downtime. AC: After revocation, the token is refused (401/403) within 10 minutes on both read and write paths; rotation leaves traffic uninterrupted.
- MR-3 Idempotent push and dedup: Push MUST be idempotent on (project, source_id, content_hash) to prevent duplicate points on retries. AC: Re-sending the same item N times yields exactly one point and one audit row marked “duplicate-suppressed.”
- MR-4 Retention enforcement: Retention in _manifest MUST be enforced by a scheduled job with audit-tracked deletions and exclusion from results before physical purge. AC: Items past retention are excluded from results within 24 h and a retention audit log is written; physical deletes complete within 7 days.
- MR-5 Observability and alerts: The platform MUST expose per-project metrics (ingest success rate, refusal counts by reason, freshness SLA, recall on R-15 set, query latency p95, index size) with alerts on threshold breaches. AC: A simulated SLA breach (freshness or recall) fires an alert to the operator within 15 minutes.

2) Requirements that are wrong, untestable, contradictory or over-scoped (fixes)
- R-4 Freshness AC too narrow and brittle. Why: “top-1 by exact title at t+24h” ignores end-to-end SLA and multi-term queries. Fix: Define SLA as “searchable within 24 h (p95)” and test by “exists and ranks in top-3 for exact-title and top-5 for two canonical paraphrases.”
- R-8 Auto-collapse on similarity threshold. Why: Unsafe and contradicts WD’s position (CF-9) and R-39’s need to preserve per-observation metadata. Fix: Make collapse a reviewer proposal requiring owner-project approval; never auto-apply across projects; enforce R-39 (keep all observations with dates/versions).
- R-12 All fields non-empty. Why: Some metadata may be legitimately unknown (e.g., last_confirmed, guarded_by) or N/A for legacy items. Fix: Split into required (project, source, type, status, score, layer, observed_on/version if present) vs optional; require a missing-field indicator in results when optional fields are absent.
- R-17 Cross-language benchmark unspecified. Why: No target means untestable. Fix: Set a numeric target (e.g., nDCG@10 ≥ 0.75 on a held-out EN↔NL↔DE set from project corpora) and name the benchmark set.
- R-18 “MUST NOT be pushed as solutions” ambiguous. Why: Does this block storage or only solution-finder indexing? Fix: Clarify: “Nonconforming cards may be stored as raw notes but MUST NOT be indexed into the solution-finder facet.”
- R-21 “~64” vague and platform coupling unclear (“T-4090’s rule”). Fix: Replace with concrete numbers and local enforcement: “Batch size ≤ 64, QPS ≤ 2 per project on shared GPU host; exponential backoff starting at 1 s, max 5 retries; limits configurable in _manifest.”
- R-24 “Priority signal” undefined. Fix: Define as a ranking boost and facet: “error classes with status ‘N projects hit this, no fix yet’ get +X score boost and a visible ‘estate-impact’ badge.”
- R-29 Audit log lacks integrity/retention. Fix: “Audit logs MUST be append-only (tamper-evident hash chain) and retained 12 months; access is restricted and monitored.”
- R-31 Cross-tenant sharing mechanism missing. Fix: “Cross-tenant reads require an explicit allowlist (tenant/project-level) recorded in _manifest; default deny.”
- R-33 Mandatory observed_on/version may block legacy ingress. Fix: Allow unknown with explicit flag: “If unknown, set observed_on = null, version = ‘unknown’, and surface ‘staleness-unknown’ in results.”

3) Recommendations on OPEN conflicts
- CF-1 Cloud fallback for estate store: Decide NO. Reason: Items carry internal topology, incidents and error signatures; external fallback expands breach blast radius and complicates compliance and CF-7. Add: “Estate store queries never leave the estate boundary; no cloud fallback.”
- CF-2 Server-side vs client-side embedding: Choose phased “both,” starting server-side only for the pilot. Reason: Consistency and governance are simpler server-side; add an independent verifier agent (off-platform) to spot-check digests to mitigate compromised embedders; later enable client-side fallback using the identical model+digest only when central embedder is down. Update R-19/R-21 to include verifier spot-check on random samples.
- CF-5 Full text vs leak cost: Allow full text only for curated items of data class “framework-public-in-estate”; raw items store minimal excerpts/chunks with strict redaction and linking back to source. Reason: Reduces leak impact while preserving curation quality; backups inherit class safely. Add linter to cap raw item size and strip stack traces unless class allows.
- CF-7 Hostnames/IPs: Normalise to roles for all estate-visible items (errors, cross-project) and strip/role-map at push; allow exact hostnames/IPs only in own-only scope. Reason: Role mapping makes items reusable and safer; avoids reliance on CF-1 outcome.
- CF-9 Who curates: Owner-project decides collapses concerning its items; reviewer agent may recommend; cross-project combine is drafted by reviewer, approved by operator; reversible with provenance preserved. Reason: Respects ownership, reduces accidental knowledge drift, aligns with WD and R-39.

4) Threats not covered and the requirement that should exist
- Malicious reader exfiltration (stolen estate read token). Requirement: Per-token read rate limits and anomaly detection with alerting; IP/mTLS allowlist optional per token; token revocation (MR-2).
- Poisoned embeddings or forged digests (compromised embedder). Requirement: Independent verifier agent re-embeds random samples daily and compares cosine similarity above threshold; refuse further writes on mismatch.
- Prompt-injection in stored content influencing agents. Requirement: Retrieval MUST tag items with trust tier and source, strip/escape model-directed instructions in results, and optionally pass through a “context linter” to flag injection patterns to the caller.
- Destructive misuse by a compromised project token (mass delete of its own items). Requirement: Destructive operations (bulk delete > X or > Y% of collection) require a two-step confirmation by operator or are quarantined for 24 h with read suppression but recoverable.
- Backups exposing sensitive items after retire. Requirement: Snapshot encryption at rest; retired-on-purpose tombstones MUST be applied on restore before enabling reads; differential purge list maintained and re-applied to restored snapshots.
- Data in transit confidentiality. Requirement: TLS 1.2+ enforced for all client→embedder→store traffic; no plaintext tokens on the wire; certificate pinning optional in agent config.
- Read path auditability. Requirement: Query (read) audit logs with caller token, time, filters, and result counts retained 6 months, with anomaly alerts.

5) What to cut for a first pilot (one project writing, one reading) to go live safely
Keep (minimal, safe pilot):
- Content and propagation: R-1, R-3, R-5, R-6 (layers), R-7 (supersede visibility), R-11 (provenance).
- Security invariants: R-2 (redaction), R-9 (combine requires operator), R-10 (retire), R-25 (tokens), R-26 (manifest), R-27 (data class), R-31 (tenant/project tags), R-37 (size/binary limits).
- Retrieval basics: R-12 (result metadata with required fields), R-13 (scope selector), R-14 (ranking with default mode only for pilot), R-16 (degrade to local), R-15 (pilot question set).
- Embedding and ops: R-19 (model+digest), R-20 (gate model changes), R-21 (bounded load with firm numbers), R-29 (audit with integrity), R-30 (snapshots/restore).
- Errors (light): R-22, R-23 (class-only, sanitized).
- Add the five missing pilot-criticals: MR-1 (sharing scope), MR-2 (revocation), MR-3 (idempotent push), MR-4 (retention enforcement), MR-5 (observability/alerts).
- CF decisions applied: CF-1=No cloud fallback; CF-2=server-side embedder only for pilot + verifier later; CF-5=full text curated only, raw minimal; CF-7=role-normalise for estate-visible; CF-9=owner-project approves collapse, operator approves combine.

Defer to post-pilot (phase P1/P1a):
- Multilingual retrieval (R-17).
- Solution-finder fabric fields (R-18) beyond purpose/tags/problem; the broader fabric index import.
- Cross-project combine workflow beyond storing proposals (still allow drafts but do not promote).
- Complex ranking mode “solution-finder” (R-14 second mode).
- Version/shape filters (R-33–R-35) except storing observed_on/version if trivially available.
- Estate-wide error analytics/priority surfacing (R-24, R-40).
- Client-side embedder fallback and independent verifier agent activation (CF-2 advanced step).
- Advanced approval queue SLAs and UI (address “approval fatigue”) — document as an operational note now; implement after pilot.

Notes for pilot success:
- Define the R-15 question set and numeric recall targets up front.
- Stand up dashboards for MR-5 with alerts for R-4 freshness and R-15 recall.
- Document and test the kill switch (R-28) and token revocation (MR-2) in drills.
- Ship a linter that enforces raw-item size caps, sharing scope, required fields, and role-normalisation for estate-visible items.
