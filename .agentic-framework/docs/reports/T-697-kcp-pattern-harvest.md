# T-697: KCP Pattern Harvest — Scored Against Framework Directives

## Method

5 discovery agents explored the KCP codebase (`/opt/052-KCP`) across 5 domains. Each pattern scored 1-5 against:
- **D1** Antifragility — strengthens under stress
- **D2** Reliability — predictable, auditable
- **D3** Usability — joy to use/extend/debug
- **D4** Portability — no lock-in

43 raw patterns found. After deduplication: **33 unique patterns**. Ranked by composite score (D1+D2+D3+D4, max 20).

---

## Top 15 Patterns (Score >= 17)

| # | Pattern | Domain | D1 | D2 | D3 | D4 | Total | Framework Application |
|---|---------|--------|----|----|----|----|-------|----------------------|
| 1 | Single-source-of-truth generation | DX | 5 | 5 | 5 | 5 | **20** | Generate CLAUDE.md/hooks from a single manifest — prevent drift between config files |
| 2 | Topology-first dependency declaration | Spec | 5 | 5 | 4 | 5 | **19** | Declare skill/component prerequisites and conflict relationships in fabric |
| 3 | Intent-driven selective loading | Spec | 4 | 5 | 5 | 5 | **19** | Declare what each tool/prompt answers — enable dynamic tool selection |
| 4 | Deterministic URI mapping | MCP | 4 | 5 | 5 | 5 | **19** | Stable URIs for governance artifacts (policies, audit logs, decisions) |
| 5 | Interactive CLI with non-interactive fallback | DX | 5 | 4 | 5 | 5 | **19** | `fw` CLI detects TTY, works in both human and CI contexts |
| 6 | Validation as gating & feedback (3-tier) | DX | 5 | 5 | 5 | 4 | **19** | Three-tier validation: errors (blocking), warnings (advisory), clean |
| 7 | Manifest meta-resource | MCP | 5 | 5 | 4 | 5 | **19** | Expose framework governance as discoverable JSON manifest via MCP |
| 8 | Audience-targeted knowledge segmentation | Spec | 4 | 4 | 5 | 5 | **18** | Multi-role agent systems — orchestrators, workers, debuggers get different views |
| 9 | DAG federation with local authority | Federation | 4 | 5 | 4 | 5 | **18** | Cross-machine knowledge graphs without central coordination |
| 10 | Observability-first instrumentation | DX | 4 | 5 | 4 | 5 | **18** | Log all framework operations to local SQLite, expose `fw stats` |
| 11 | Freshness-first validation signal | Spec | 5 | 5 | 3 | 4 | **17** | `validated` + `update_frequency` — detect stale knowledge before acting |
| 12 | External dependencies with graceful degradation | Federation | 5 | 4 | 4 | 5 | **18** | Multi-service coordination with `on_failure: skip|warn|degrade` |
| 13 | Authority declarations (initiative vs approval) | Federation | 3 | 5 | 4 | 5 | **17** | Encode initiative vs approval per operation — machine-readable governance |
| 14 | Compliance as root defaults + unit overrides | Federation | 3 | 5 | 4 | 5 | **17** | Root-level compliance baseline with per-unit overrides |
| 15 | Context window budgeting via hints | Spec | 4 | 4 | 4 | 5 | **17** | Token estimates + load priority + summaries for budget-constrained agents |

## Patterns 16-25 (Score 15-16)

| # | Pattern | Domain | D1 | D2 | D3 | D4 | Total |
|---|---------|--------|----|----|----|----|-------|
| 16 | Incremental adoption onboarding (levels 1/2/3) | DX | 4 | 5 | 5 | 4 | 18 |
| 17 | Artifact classification before specification | DX | 5 | 5 | 3 | 5 | 18 |
| 18 | Cross-language conformance runner | Testing | 5 | 5 | 3 | 5 | 18 |
| 19 | Layered fixture approach (level 1/2/3) | Testing | 4 | 5 | 4 | 4 | 17 |
| 20 | Lenient comparison rules | Testing | 4 | 4 | 5 | 5 | 18 |
| 21 | Cycle detection with silent ignore | Testing | 5 | 5 | 4 | 5 | 19 |
| 22 | Visibility conditions (env + role) | Federation | 4 | 4 | 5 | 5 | 18 |
| 23 | Org hub with progressive disclosure | Federation | 4 | 4 | 5 | 5 | 18 |
| 24 | Benchmark-driven adoption measurement | DX | 4 | 5 | 3 | 4 | 16 |
| 25 | Explicit validation checklist | DX | 5 | 5 | 4 | 3 | 17 |

## Patterns 26-33 (Score < 15 or niche)

| # | Pattern | Domain | Total | Notes |
|---|---------|--------|-------|-------|
| 26 | Chunking for progressive loading | Spec | 16 | Large skill libraries |
| 27 | Rate-limit-aware self-throttling | Spec | 17 | Multi-agent sharing |
| 28 | Audience-aware filtering via annotations | MCP | 17 | Role filters on resources |
| 29 | Search tool with scoring | MCP | 16 | Natural language governance queries |
| 30 | Plugin-based system prompt injection | MCP | 16 | Inject governance at startup |
| 31 | Sensitivity-aware query filtering | MCP | 17 | Clearance-level access |
| 32 | Per-unit delegation depth limits | Federation | 17 | Restrict escalation |
| 33 | Content integrity & manifest signing | Federation | 14 | Cryptographic trust |

---

## Highest-Value Patterns for Immediate Framework Use

### Tier A: Direct applicability (can build now)

1. **Observability-first instrumentation (#10)** — We have metrics.sh but no structured event logging. SQLite + `fw stats` would answer "what do agents actually use?" Evidence-based roadmap.

2. **Validation as 3-tier gating (#6)** — We already do this partially (fw doctor = errors/warnings, fw audit = pass/warn/fail). Codifying the three-tier pattern across ALL framework tools would improve consistency.

3. **Authority declarations (#13)** — This IS T-477 (governance declaration layer, already GO). KCP's `authority.{read, summarize, modify, execute}` with values `initiative|requires_approval|denied` maps directly to our Authority Model.

4. **Context window budgeting (#15)** — We have P-009 (context budget). KCP's `token_estimate + load_strategy + priority` is a more structured version. Could improve our checkpoint.sh and budget-gate.sh.

### Tier B: Worth exploring (inception needed)

5. **Single-source-of-truth generation (#1)** — Generate CLAUDE.md from a structured manifest. Prevents drift when framework evolves. Big architectural shift.

6. **DAG federation (#9)** — Cross-machine knowledge. Relevant for TermLink multi-agent coordination. Future work.

7. **Incremental adoption levels (#16)** — `fw init --level 1|2|3`. Level 1 = tasks only, Level 2 = + context fabric, Level 3 = + full governance. Reduces onboarding friction.

### Tier C: Interesting but premature

8. Capability attenuation in delegation chains
9. Manifest signing / trust provenance
10. Sensitivity-aware filtering

---

## Cross-Reference: KCP Patterns vs Framework Gaps

| KCP Pattern | Framework Gap | Status |
|-------------|--------------|--------|
| Authority declarations | G-017 (execution gates don't cover proposal layer) | T-477 GO |
| Observability instrumentation | No gap registered — but no `fw stats` exists | NEW |
| Incremental adoption | Onboarding friction (10 friction points in T-679) | T-460 (templates) |
| Federation | G-004 (multi-agent untested) | Watching |
| Context budgeting | P-009 exists but not structured | Enhancement |
