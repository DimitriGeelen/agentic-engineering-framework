model: google/gemini-2.5-pro
usage: {"prompt_tokens": 7449, "completion_tokens": 5996, "total_tokens": 13445, "cost": 0.06927125, "is_byok": false, "prompt_tokens_details": {"cached_tokens": 0, "cache_write_tokens": 0, "audio_tokens": 0, "video_tokens": 0}, "cost_details": {"upstream_inference_cost": 0.06927125, "upstream_inference_prompt_cost": 0.00931125, "upstream_inference_completions_cost": 0.05996}, "completion_tokens_details": {"reasoning_tokens": 4218, "image_tokens": 0, "audio_tokens": 0}}

Here is a review of the requirements draft.

### 1. The 5 most important MISSING requirements

1.  **M-1: Token Revocation.** The operator MUST be able to immediately revoke a project's access token without affecting others.
    *   **AC:** A write attempt using a revoked token is refused with a 403 Forbidden error and logged as a security event.
2.  **M-2: Curation Workflow Management.** The platform MUST provide a way to manage the queue of items awaiting curation or approval to prevent operator bottleneck.
    *   **AC:** The operator can view a list of `proposed` items (R-9) and filter/sort them by age, project, and type.
3.  **M-3: Retrieval Feedback Loop.** Agents MUST be able to signal that a retrieved item is unhelpful, incorrect, or outdated.
    *   **AC:** An API endpoint allows an agent to submit a `(item_id, flag_type)` report, which is logged for the reviewer agent.
4.  **M-4: Resource Quotas and Rate Limiting.** The platform MUST enforce per-project limits on writes and queries to prevent resource exhaustion.
    *   **AC:** A project exceeding its configured daily write limit is rate-limited, and an operational alert is logged.
5.  **M-5: Operational Health Alerting.** The platform MUST automatically alert the operator on critical health failures.
    *   **AC:** An alert is raised if a project's push cycle fails to complete for more than 48 hours, violating the freshness guarantee (R-4).

### 2. Requirements that are wrong, untestable, contradictory or over-scoped

*   **R-4 (Freshness):** The acceptance criterion is **untestable and brittle**. "top-1 for its exact title" is too strict and not the goal; semantic findability is. A better, semantically similar item might rightly rank higher.
    *   **Fix:** Change the AC to: "Given a task T closed at time t, when queried with its summary at t+24h, the corresponding item appears in the top-3 results."

*   **R-8 (Collapse):** This requirement is **wrong and dangerous**. "applied automatically when the texts match above an agreed threshold" risks creating incorrect knowledge by merging items with syntactic similarity but different semantic meaning. It also contradicts the safer, ownership-based model proposed by WD (CF-9).
    *   **Fix:** Change "applied automatically" to "proposed automatically". The proposal MUST then be approved according to the process decided for CF-9 (e.g., by the source project owner).

*   **R-17 (Multi-lingual):** This requirement is **untestable and over-scoped** for an initial rollout. "to the benchmark threshold" is untestable as the benchmark is not defined. Adding cross-lingual retrieval is a major undertaking.
    *   **Fix:** Defer this requirement. Re-evaluate after the single-language store is proven stable and valuable.

*   **R-38 (Store peer requests):** This requirement is **vague and potentially wrong**. It risks turning the knowledge store into a message log or task tracker. The value and retrieval use case are undefined.
    *   **Fix:** Remove this requirement. Peer requests are operational events that belong in audit logs or task management systems, not a long-term knowledge store unless a clear "knowledge" use case is defined.

### 3. Your recommendation on each OPEN conflict

*   **CF-1 (Cloud fallback for embedding):** **Do not allow it.** The estate store contains sensitive operational data like internal topology and incident details (R-23, R-24, CF-7). The risk of leaking this information to an external, third-party model provider is too high. The store must be treated as internal-only, exempt from general framework policies like OD-15.

*   **CF-2 (Server-side vs. client-side embedding):** **Recommend the third option: client-side embedding with independent verification.** This avoids the server-side single-point-of-failure for the write path, improving resilience. To mitigate the risk of inconsistency, a separate, trusted verifier agent (not the main platform) should periodically sample new points and re-embed them to ensure their vectors match the canonical model.

*   **CF-5 (Full text in payload):** **Allow full text, but with strengthened security.** Curation (collapse, combine) and review are impossible without the full text. The risk of data leakage from backups is real but can be mitigated.
    *   **Reason:** The system's value depends on curation. Mitigate the risk by adding a new requirement for mandatory encryption-at-rest for all backups and snapshots. This, combined with existing controls (R-2 redaction, R-25 access tokens), provides a reasonable security posture.

*   **CF-7 (Hostnames/IPs in items):** **Mandate replacement with roles.** Hostnames and IPs are brittle (they change) and represent an information leak. For knowledge to be reusable across projects and over time, it must be abstract. An error related to `database(role=primary)` is universally understandable, whereas one related to `db-prod-01.eu-west` is not.
    *   **Reason:** This improves both the security and the long-term value of the stored knowledge.

*   **CF-9 (Who curates):** **Adopt the project-designer (WD) model.** It provides the strongest safety and ownership guarantees.
    *   **Reason:**
        1.  **Collapse:** A reviewer agent *proposes* it, but the *originating project* approves. The owner of the data is the only one who can truly validate the merge.
        2.  **Combine:** An agent *drafts* it, but only a central authority (like the framework owner, AEF) can promote it for operator approval. This prevents a single project from creating estate-wide "practice". This layered approval process correctly reflects the scope of impact.

### 4. Threats the draft does not hold against

1.  **Adversary:** Malicious agent with a valid write token.
    *   **Threat:** **Data Poisoning.** The agent could push plausible-but-incorrect `raw` items (e.g., a "fix" that introduces a security flaw) that bypass the `combine` review process.
    *   **Missing Requirement:** **M-6: Anomaly Detection on Push.** The system SHOULD flag new items that represent a significant semantic departure from existing knowledge about a component for priority review.

2.  **Adversary:** A compromised or buggy agent.
    *   **Threat:** **Resource Exhaustion (Denial-of-Service).** The agent could flood the store with a high volume of valid write or read requests, degrading performance for all other projects.
    *   **Missing Requirement:** **M-4 (from Q1) / API Rate Limiting.** The store MUST enforce per-token rate limits on both read and write API calls, defined in the `_manifest`.

3.  **Adversary:** The operator or a powerful reviewer agent.
    *   **Threat:** **Knowledge Monopoly / Unilateral Curation.** A single point of control could incorrectly supersede or combine knowledge without consensus from the projects that originated it, leading to a loss of trust.
    *   **Missing Requirement:** **M-7: Consensus for Curation.** Curation actions on items from multiple projects (e.g., a `combine` that supersedes the originals) SHOULD require approval from all source projects, not just the operator.

### 5. What you would cut to get a first pilot live safely

To get a pilot with one project writing and one reading safely, I would defer all advanced features and focus exclusively on the core `raw` data pipeline with essential security.

**Cuts:**
*   **The entire Curation layer (Area B):** Defer R-6, R-7, R-8, R-9, R-10, R-11, R-39. The pilot can operate on the `raw` layer only. This eliminates the complexity of review,
