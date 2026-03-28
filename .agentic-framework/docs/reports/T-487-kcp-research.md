# KCP Research Report for T-477

**Date:** 2026-03-14
**Researcher:** Claude Code agent
**Task:** T-477 — Risk-based governance declaration layer
**Sources:** github.com/Cantara/knowledge-context-protocol (SPEC.md, RFC-0001 through RFC-0008), github.com/Cantara/kcp-commands

---

## 1. KCP Overview

The Knowledge Context Protocol (KCP) is a structured metadata standard for making knowledge navigable by AI agents. Its tagline: "KCP is to knowledge what MCP is to tools."

- **Current version:** 0.10 (spec says 0.9 in some places; README says 0.10)
- **License:** Apache-2.0
- **Format:** YAML file (`knowledge.yaml`) — no server, database, or running process required
- **Philosophy:** Declarative metadata that agents consume to navigate knowledge without loading everything. All metadata is advisory — enforcement is the consumer's responsibility.
- **Conformance levels:** Level 1 (minimal, 5 required fields), Level 2 (structured, adds freshness/access/trust), Level 3 (full, adds auth/federation/relationships)
- **Ecosystem:** Synthesis (reference server), kcp-commands (CLI manifests), opencode-kcp-plugin, kcp-memory (episodic memory)

**Key claim:** 53-80% fewer agent tool calls vs. unguided exploration across 5 agent frameworks.

---

## 2. Manifest Format — Complete Schema

### Root-Level Fields

```yaml
# REQUIRED
project: "project-name"              # Human-readable identifier
units: [...]                          # At least one knowledge unit

# RECOMMENDED
kcp_version: "0.10"                   # Protocol version
version: "1.0.0"                      # Manifest semver

# OPTIONAL
updated: "2026-03-14"                 # ISO 8601 (quoted for YAML safety)
language: "en"                        # BCP 47 default language
license: "Apache-2.0"                 # SPDX identifier (or structured object)
indexing: open                        # open | read-only | no-train | none

hints:                                # Aggregate context window guidance
  total_token_estimate: 45000
  unit_count: 12
  recommended_entry_point: "getting-started"
  has_summaries: true
  has_chunks: false

trust:                                # Publisher provenance
  provenance:
    publisher: "Acme Corp"
    publisher_url: "https://acme.com"
    contact: "admin@acme.com"
  audit:
    agent_must_log: true
    require_trace_context: true

auth:                                 # Authentication methods (ordered)
  methods:
    - type: oauth2
      flow: client_credentials
      token_endpoint: "https://auth.example.com/token"
      scopes: ["read:knowledge"]
    - type: api_key
      header: "X-API-Key"
      registration_url: "https://example.com/register"
    - type: none                      # Fallback

delegation:                           # Multi-agent chain constraints
  max_depth: 2
  require_capability_attenuation: true
  audit_chain: true
  human_in_the_loop:
    required: false
    approval_mechanism: oauth_consent  # oauth_consent | uma | custom
    docs_url: "https://..."

compliance:                           # Regulatory metadata
  data_residency: [EU, CH]
  sensitivity: internal               # public | internal | confidential | restricted
  regulations: [GDPR, NIS2]
  restrictions: [no-ai-training, no-logging, no-cross-border, audit-required, human-approval-required]

rate_limits:
  default:
    requests_per_minute: 60
    requests_per_day: 10000

payment:
  default_tier: free                  # free | metered | subscription

manifests:                            # Federation (cross-manifest linking)
  - id: security-policies
    url: "https://example.com/security/knowledge.yaml"
    label: "Security policies"
    relationship: governs             # child | foundation | governs | peer | archive
    update_frequency: monthly
    local_mirror: "./mirrors/security.yaml"
    version_pin: "2.0.0"
    version_policy: compatible        # exact | minimum | compatible
```

### Knowledge Unit Fields

```yaml
units:
  - id: "getting-started"                    # REQUIRED: unique ID
    path: "docs/getting-started.md"          # REQUIRED: relative file path
    intent: "How to set up the project"      # REQUIRED: one-sentence purpose
    scope: project                           # REQUIRED: global | project | module
    audience: [developer, agent]             # REQUIRED: human | agent | developer | architect | operator | devops

    # Classification
    kind: knowledge                          # knowledge | schema | service | policy | executable
    format: markdown                         # markdown | openapi | json-schema | jupyter | pdf ...
    content_type: "text/markdown"            # MIME type
    language: "en"                           # BCP 47 override

    # Access control
    access: public                           # public | authenticated | restricted
    auth_scope: "read:internal"              # Opaque scope token (for restricted units)
    sensitivity: internal                    # public | internal | confidential | restricted

    # Freshness
    validated: "2026-03-01"                  # ISO date of last human confirmation
    update_frequency: weekly                 # hourly | daily | weekly | monthly | rarely | never
    deprecated: false
    supersedes: "old-getting-started"

    # Navigation
    depends_on: [prerequisites]
    triggers: [setup, install, onboarding]   # Keywords making this relevant
    relationships:
      - from: "getting-started"
        to: "architecture"
        type: enables                        # enables | context | supersedes | contradicts | depends_on | governs

    # Context window hints
    hints:
      token_estimate: 3500
      token_estimate_method: measured        # measured | estimated
      load_strategy: eager                   # eager | lazy | never
      priority: critical                     # critical | supplementary | reference
      density: standard                      # dense | standard | verbose
      summary_available: true
      summary_unit: "getting-started-summary"
      chunked: false

    # Cross-manifest dependencies
    external_depends_on:
      - manifest: security-policies
        unit: gdpr-policy
        on_failure: warn                     # skip | warn | degrade

    # Per-unit overrides
    delegation:
      max_depth: 1
      human_in_the_loop:
        required: true
        approval_mechanism: uma
    compliance:
      sensitivity: confidential
      restrictions: [human-approval-required]
    freshness_policy:                        # RFC-0008
      max_age_days: 30
      on_stale: warn                         # warn | degrade | block
      review_contact: "admin@example.com"
    requires_capabilities: [tool:kubectl]    # RFC-0008
```

### Relationship Types

| Type | Meaning | Navigation Effect |
|------|---------|-------------------|
| `enables` | Source prerequisite unlocks target | Load source first |
| `context` | Source provides background | Load for deeper understanding |
| `supersedes` | Source replaces target | Prefer source, skip target |
| `contradicts` | Source conflicts with target | Surface both as disagreement |
| `depends_on` | Source needs target loaded first | Reverse prerequisite |
| `governs` | Source declares policy for target | Source is authoritative |

### Cross-Manifest Relationships

```yaml
external_relationships:
  - from_manifest: security    # omit = this manifest
    from_unit: gdpr-policy
    to_manifest: null          # omit = this manifest
    to_unit: user-data-schema
    type: governs
```

---

## 3. Authority Model

KCP's authority model operates at the knowledge-access level, not the operation-execution level. Key distinction from T-477: KCP answers "who may read this knowledge" while T-477 answers "who may perform this action."

### Human-in-the-Loop (HITL)

```yaml
delegation:
  human_in_the_loop:
    required: true                           # Boolean gate
    approval_mechanism: oauth_consent        # oauth_consent | uma | custom
    docs_url: "https://..."                  # Required if custom
```

- **oauth_consent:** Synchronous — human must authorize in real-time via OAuth flow
- **uma:** Asynchronous — resource owner pre-authorizes via UMA 2.0 policy (approval exists before request)
- **custom:** Publisher-defined, requires documentation URL

### Delegation Chain

- `max_depth: 0` — humans only, no agent access
- `max_depth: 1` — human or one delegated agent
- `max_depth: N` — N hops from human to resource
- Omission — no constraint on depth

### Capability Attenuation

When `require_capability_attenuation: true`: each delegation hop must narrow permissions, never expand. Parent holds `read:docs` => child cannot receive `write:docs`. This is a monotonic access reduction model.

### Audit Chain

When `audit_chain: true`: agents must inject W3C Trace Context headers (`traceparent`/`tracestate`). Enables full delegation chain reconstruction from access logs. Compatible with OpenTelemetry.

### Trust Model (Critical)

**"All KCP metadata is advisory."** This is a fundamental design choice:
- Freshness (`validated`) — declaration, not proof
- Compliance — asserts intent, not verified status
- Access controls — advisory signal, requires enforcement at transport/storage
- Restrictions — acknowledged obligations, not technical enforcement
- Publisher identity — free-text, no trust without cryptographic verification

This means KCP declares what SHOULD happen but does not enforce it. Enforcement is the consumer's responsibility.

---

## 4. Compliance Model

### Sensitivity Classification (ISO 27001-aligned)

| Level | Meaning |
|-------|---------|
| `public` | Freely shareable |
| `internal` | Internal use only |
| `confidential` | Need-to-know basis |
| `restricted` | Highest sensitivity, strict controls |

### Indexing Permissions

Shorthand: `open | read-only | no-train | none`

Structured (granular):
```yaml
indexing:
  allow: [read, index, reproduce-in-response, summarise]
  deny: [train, cache-permanently, share-externally]
```

### Regulatory Vocabulary

Predefined regulation identifiers: `GDPR`, `ePrivacy`, `NIS2`, `HIPAA`, `HITECH`, `CCPA`, `MiFID2`, `DORA`, `AML5D`, `FATF`, `ITAR`, `eIDAS`

### Restriction Actions

- `no-external-llm` — forbid sending to external model services
- `no-logging` — no persistent log storage
- `no-cross-border` — must stay within data_residency regions
- `no-ai-training` — not usable for model training
- `audit-required` — full access logging mandatory
- `human-approval-required` — links to delegation controls

### Per-Unit Overrides

Any unit can override root compliance settings. A project-level `sensitivity: internal` can be overridden by a unit-level `sensitivity: confidential`.

---

## 5. Pre-Built Manifests (kcp-commands)

### Overview

289 bundled CLI manifests covering: Git (20+), Linux/macOS (28), text processing (15), build tools (8), package managers (14), container/orchestration (20+), cloud/IaC (12), database CLIs (9).

### Manifest Schema (kcp-commands format — NOT the same as knowledge.yaml)

```yaml
command: "git"                              # Executable name (must match Bash command)
platform: "all"                             # all | linux | macos | windows
subcommand: "log"                           # Optional for subcommands
description: "Show commit history"          # One-line summary

syntax:                                     # Phase A: Pre-execution context
  usage: "git log [options] [revision range]"
  key_flags:                                # Max 5
    - flag: "--oneline"
      description: "Compact single-line output"
      use_when: "Quick overview"
  preferred_invocations:                    # Max 3
    - invocation: "git log --oneline -10"
      use_when: "Recent commits overview"

output_schema:                              # Phase B: Post-execution filtering
  enable_filter: true
  noise_patterns:
    - pattern: "^commit [a-f0-9]{40}$"
      reason: "Full SHA header"
  max_lines: 80
  truncation_message: "... {remaining} more lines"
```

### Sample Manifests

**1. ps.yaml** — Process inspection. key_flags: `aux` (all processes), `-ef` (with PPID), `--sort=-%cpu`. Noise filter: header lines. Max 50 lines.

**2. mvn.yaml** — Maven build. key_flags: `test`, `-pl <module>`, `-DskipTests`. Noise filter: "Scanning for projects", separator lines. Max 80 lines.

**3. docker.yaml** — Container management. key_flags: `ps`, `images`, `logs`, `build`. Noise filter: table headers. Max 100 lines.

**4. terraform.yaml** — IaC. key_flags: `plan`, `apply`, `destroy`, `-var-file`. Noise filter: comments. Max 150 lines.

**5. kubectl.yaml** — Kubernetes. key_flags: `get`, `logs`, `describe`, `apply -f`, `-n`. Noise filter: table headers. Max 200 lines.

### Three Operational Phases

- **Phase A (Syntax Injection):** Before execution — injects key_flags and preferred_invocations as additionalContext. Saves ~532 tokens per call (avoids `--help` lookups).
- **Phase B (Output Filtering):** After execution — noise pattern removal + line truncation. Example: `ps aux` reduced from 30,828 to 652 tokens (98% reduction).
- **Phase C (Event Logging):** After execution — JSONL to `~/.kcp/events.jsonl`. Asynchronous, never blocks.

### Manifest Resolution Chain

1. `.kcp/commands/<key>.yaml` — Project-local override
2. `~/.kcp/commands/<key>.yaml` — User-level (auto-generated)
3. `<package>/commands/<key>.yaml` — Bundled library

First match wins.

### Performance

| Backend | Mean Latency | p95 |
|---------|-------------|-----|
| Java daemon (warm) | 14ms | 17ms |
| Node.js (per-call) | 265ms | 312ms |

---

## 6. Federation/Query (v0.10)

### Federation Model

Manifests can declare relationships with external knowledge bases:

```yaml
manifests:
  - id: security
    url: "https://example.com/security/knowledge.yaml"
    relationship: governs    # child | foundation | governs | peer | archive
    version_policy: compatible
    local_mirror: "./mirrors/security.yaml"
```

**Relationship types:**
- `child` — sub-project owned by parent
- `foundation` — inherited base (e.g., framework standards)
- `governs` — authoritative policy source
- `peer` — equal partners
- `archive` — historical/deprecated reference

**Cross-manifest dependencies** at unit level:
```yaml
external_depends_on:
  - manifest: security
    unit: gdpr-policy
    on_failure: warn    # skip | warn | degrade
```

### Query Vocabulary (RFC-0007)

**Request parameters (all optional — empty query matches all units):**

| Parameter | Type | Purpose |
|-----------|------|---------|
| `terms` | string[] | Free-text matched against triggers, intent, id, path |
| `audience` | string | Filter by audience list membership |
| `scope` | string | Filter by scope value |
| `sensitivity_max` | string | Ceiling: public < internal < confidential < restricted |
| `max_token_budget` | integer | Limit total token_estimate across results |
| `include_summaries` | boolean | Prefer summary_unit when budget-constrained (default: true) |
| `exclude_deprecated` | boolean | Remove deprecated units (default: true) |

**Response format (per result):**

| Field | Type | Purpose |
|-------|------|---------|
| `unit_id` | string | Matching unit |
| `score` | integer | Relevance ranking (higher = better) |
| `path` | string | File path |
| `token_estimate` | int/null | Token cost |
| `summary_unit` | string/null | Summary alternative |
| `match_reason` | string[] | What matched (trigger, intent, id, path) |

**Scoring algorithm:**
- Trigger match: 5 points per term
- Intent match: 3 points per term
- ID/path match: 1 point per term
- Ties broken by declaration order
- Default result limit: 5

**Budget-constrained selection:**
1. Sort by descending score
2. Include units if token_estimate fits remaining budget
3. Substitute summary_unit when available and include_summaries=true
4. Skip units exceeding budget
5. Units without token_estimate treated as 0 cost

**Limitation:** Query is local-manifest only. Cross-manifest queries require fetching remote manifests first.

### Agent Readiness (RFC-0008)

- `requires_capabilities`: capability strings an agent must possess (e.g., `tool:kubectl`, `permission:admin`, `role:ops`)
- `freshness_policy`: `max_age_days`, `on_stale` (warn/degrade/block), `review_contact`
- Network topology in `/.well-known/kcp.json`: `role` (hub/leaf/standalone), `entry_point`
- Future (v0.12): `has_capabilities` filter, `exclude_stale` filter, federation_scope

---

## 7. Relevance to T-477

### Where KCP Overlaps with T-477's 2x2 Matrix

**Sensitivity classification maps to blast-radius axis.** KCP's `public < internal < confidential < restricted` is a four-level impact scale. T-477's blast radius is the same concept applied to operations rather than knowledge. Both ask: "what's the consequence if this goes wrong?"

**Human-in-the-loop maps to authority requirement.** KCP's `human_in_the_loop.required: true` with approval mechanisms is structurally equivalent to T-477's "authority required, every time" cell. The approval_mechanism enum (oauth_consent, uma, custom) provides a vocabulary T-477 currently lacks.

**Delegation depth maps to initiative scope.** KCP's `max_depth` controls how far from human oversight an operation can drift. T-477's initiative/authority distinction is the same gradient: depth 0 = authority required, depth N = initiative delegated N hops deep.

**Capability attenuation aligns with the principle that initiative cannot expand beyond what was granted.** T-477 states "Initiative != Authority" and "Broad directives delegate initiative, not authority." KCP formalizes this structurally.

**Per-unit overrides match T-477's need for per-operation classification.** Just as a KCP unit can override root sensitivity, an operation class in T-477 needs to override default enforcement levels.

### Where KCP Differs from T-477

**KCP classifies knowledge; T-477 classifies operations.** KCP asks "what sensitivity does this document have?" T-477 asks "what enforcement does this action need?" The object of classification is fundamentally different, even though the classification dimensions overlap.

**KCP lacks the predictability axis.** KCP has no concept of deterministic vs. stochastic operations. All knowledge units are treated as static content with known properties. T-477's key insight — that stochastic operations need fundamentally different enforcement — has no KCP equivalent.

**KCP is advisory; T-477 needs structural enforcement.** KCP explicitly states "all metadata is advisory" — enforcement is the consumer's problem. T-477 exists precisely because advisory governance (prose rules) fails under context pressure. T-477 needs the declaration to drive enforcement, not just inform it.

**KCP assumes network/API access patterns; T-477 is file-local.** KCP's auth model assumes HTTP-based access with OAuth flows. T-477's enforcement runs in PreToolUse hooks reading local YAML files. The transport models are incompatible.

**KCP's query vocabulary is for navigation; T-477 needs classification lookup.** KCP queries help agents find relevant knowledge. T-477 needs O(1) lookup: "given this tool call, what enforcement level applies?" These are different access patterns.

### What T-477 Could Adopt from KCP

1. **Sensitivity vocabulary:** `public | internal | confidential | restricted` as the blast-radius axis labels. ISO 27001-aligned, well-understood, four levels (maps to T-477's low/high).

2. **Declaration structure pattern:** Root-level defaults with per-item overrides. This is exactly how T-477's `governance.yaml` should work — default enforcement level at root, per-operation-class overrides.

3. **Human-in-the-loop field structure:**
   ```yaml
   human_in_the_loop:
     required: true
     approval_mechanism: oauth_consent | uma | custom
   ```
   T-477 could adapt this to:
   ```yaml
   human_in_the_loop:
     required: true
     approval_mechanism: tier0_prompt | task_ownership | explicit_request
   ```

4. **Relationship type `governs`:** KCP's `governs` relationship type (source declares policy target must comply with) maps directly to how `governance.yaml` relates to operation classes — it governs them.

5. **Conformance levels:** KCP's Level 1/2/3 progressive adoption model. T-477 could define: Level 1 = Tier 0 patterns only, Level 2 = adds blast-radius, Level 3 = adds predictability dimension.

6. **Freshness/validated field:** For T-477, a `validated` date on governance declarations would signal when a human last confirmed the classification is correct. Stale declarations are a real risk.

---

## 8. Gap Analysis

### What T-477 Needs That KCP Does Not Provide

| T-477 Need | KCP Coverage | Gap |
|------------|-------------|-----|
| **Predictability axis** (deterministic vs. stochastic) | None | KCP has no concept of operation predictability. This is T-477's key differentiator. |
| **Enforcement mapping** (declaration => runtime gate) | None (advisory only) | KCP declares but does not enforce. T-477 needs the declaration to drive PreToolUse hooks. |
| **Operation classification** (tool calls, not documents) | None | KCP classifies knowledge units. T-477 classifies operations/actions. Different domain. |
| **Context-pressure degradation** | None | KCP doesn't model that enforcement quality degrades under context pressure. T-477's central problem. |
| **Migration path from Tier 0-3** | None | KCP has no concept of enforcement tiers. T-477 must backward-compatible with existing tiers. |
| **Stochastic enforcement** (post-hoc review gates) | None | KCP's gates are all pre-access. T-477 needs post-action review for stochastic operations. |

### What KCP Provides That T-477 Does Not Need

| KCP Feature | T-477 Relevance |
|-------------|-----------------|
| Federation (cross-manifest linking) | Not needed — single project scope |
| Payment/monetization tiers | Not applicable |
| Rate limiting | Not applicable (local hooks, no API) |
| OAuth/SPIFFE/DID auth methods | Not applicable (local file system, no network auth) |
| Token estimation/load strategy | Not applicable (governance file is small) |
| Content type/format classification | Not applicable (operations, not documents) |
| Query vocabulary | Not needed — O(1) lookup, not search |

### Synthesis: What This Means for T-477

KCP validates T-477's direction. Both protocols recognize that:
1. Classification should be declarative (YAML, not code)
2. Sensitivity/impact needs a vocabulary (not just "dangerous" or "safe")
3. Human-in-the-loop needs structural declaration, not prose
4. Per-item overrides of root defaults are necessary
5. The declaration must be separate from the enforcement

The critical difference is that **KCP stops at declaration and leaves enforcement to the consumer.** T-477 cannot stop there — the entire motivation is that advisory governance (prose) fails under context pressure. T-477 must go from declaration to enforcement.

**KCP's schema is a useful structural template**, but T-477's `governance.yaml` needs two fields KCP doesn't have:
1. `predictability: deterministic | stochastic` — the outcome certainty axis
2. `enforcement: mechanical | advisory | human_required` — the derived gate type

These two fields, combined with KCP-style `sensitivity` and `human_in_the_loop`, would give T-477 a declaration format that:
- Borrows proven vocabulary from an emerging standard (KCP sensitivity levels)
- Adds the missing predictability dimension that makes the 2x2 matrix work
- Maps declarations to enforcement mechanisms (something KCP deliberately avoids)

### Recommended Draft Structure for governance.yaml

Based on KCP patterns adapted for T-477:

```yaml
governance_version: "0.1"
project: "agentic-engineering-framework"

defaults:
  sensitivity: internal
  predictability: deterministic
  enforcement: mechanical
  human_in_the_loop:
    required: false

operation_classes:
  - id: destructive-commands
    description: "Force push, hard reset, rm -rf, DROP TABLE"
    sensitivity: restricted
    predictability: deterministic
    enforcement: mechanical         # Pattern-match, block or allow
    human_in_the_loop:
      required: true
      approval_mechanism: tier0_prompt
    triggers: [git push --force, rm -rf, DROP TABLE, git reset --hard]

  - id: file-mutations
    description: "Write/Edit to source files"
    sensitivity: internal
    predictability: deterministic
    enforcement: mechanical         # Task gate — binary check
    human_in_the_loop:
      required: false
    requires: [active_task]

  - id: architectural-decisions
    description: "Choosing between implementation approaches, design patterns"
    sensitivity: confidential
    predictability: stochastic
    enforcement: human_required     # Cannot be mechanically gated
    human_in_the_loop:
      required: true
      approval_mechanism: explicit_request

  - id: task-completion
    description: "Closing human-owned tasks"
    sensitivity: confidential
    predictability: stochastic
    enforcement: human_required
    human_in_the_loop:
      required: true
      approval_mechanism: evidence_review
    requires: [human_ac_evidence]

  - id: content-generation
    description: "Public-facing content, README, blog posts"
    sensitivity: confidential
    predictability: stochastic
    enforcement: advisory           # Log + review, cannot mechanically gate quality
    human_in_the_loop:
      required: true
      approval_mechanism: review

  - id: routine-operations
    description: "mkdir, git add, run tests, read files"
    sensitivity: public
    predictability: deterministic
    enforcement: audit_only         # Log, no gate
    human_in_the_loop:
      required: false
```

This preserves KCP's structural patterns while adding the predictability and enforcement axes that define T-477's contribution.

---

## Appendix: KCP Version History

| Version | Key Addition |
|---------|-------------|
| 0.1-0.4 | Core schema: project, units, id, path, intent, scope, audience |
| 0.5 | Extended fields: kind, format, validated, depends_on, triggers |
| 0.6 | Auth and delegation (RFC-0002) |
| 0.7 | Federation (RFC-0003), Trust/Compliance (RFC-0004) |
| 0.8 | Payment/Rate-Limits (RFC-0005) |
| 0.9 | Context-Window-Hints (RFC-0006), cross-manifest relationships |
| 0.10 | Query Vocabulary (RFC-0007), Agent Readiness (RFC-0008) |
