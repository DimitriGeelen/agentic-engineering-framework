# T-697: KCP Deep-Dive — Knowledge Context Protocol Codebase Ingestion

## Status: Complete

## What KCP Is

Knowledge Context Protocol — a YAML-based metadata standard (`knowledge.yaml`) that makes project knowledge navigable by AI agents. "KCP is to knowledge what MCP is to tools."

**Architecture:** File format spec (v0.14) with multi-language implementations:
- **Java** (primary): Maven, JDK 17+. MCP bridge server, parser, 5 domain simulators
- **TypeScript**: MCP bridge, parser, validator, CLI tool (Vitest tests)
- **Python**: Parser implementation
- **JSON Schema**: Validation schema

**Key patterns:**
- MCP bridge (serve KCP context via MCP tools)
- A2A agent delegation with OAuth2/HITL gates
- Cross-language conformance testing
- Manifest federation
- 17 RFCs extending the core spec

**Validated result:** 53-80% fewer agent tool calls vs unguided exploration.

## Path C Template Validation (T-696)

This was the second Path C experiment, validating the `path-c-deep-dive.md` template.

### Template effectiveness

| Aspect | Result |
|--------|--------|
| Phase 1 (Setup) | Followed from template, all steps worked |
| Phase 2 (Execute) | Worker dispatched, 4/5 seed tasks completed |
| Phase 3 (Harvest) | Findings harvested via TermLink |
| Cold-start test | Agent followed template without reading T-679 doc |

### Friction points discovered

| # | Issue | Severity | Category | Notes |
|---|-------|----------|----------|-------|
| F-1 | Template says T-001 through T-006 but greenfield creates T-001 through T-005 | Low | Template | Fix: say "5 or 6 depending on mode" |
| F-2 | Git identity not in TermLink session | Medium | Known | Already documented in T-679 (F-9) |
| F-3 | Worker dispatched from framework dir, not consumer | Medium | Workflow | Worker needs explicit cd into target |
| F-4 | No mirror terminal for human observation | Medium | Template | Template updated to include mirror step |
| F-5 | `claude -p` headless — no live observability | Medium | UX | Created T-698 inception to evaluate |
| F-6 | Live observability not possible with current dispatch | High | UX | Fundamental gap — `termlink attach` shows nothing |
| F-7 | Boundary hook blocked worker's cross-project ops | Medium | Known | Worker operated from framework dir (F-3 root cause) |
| F-8 | Agent dispatch counter carried from parent | Low | Counter | Minor — worker used direct tools instead |

### Seed task results

| Task | Status | Notes |
|------|--------|-------|
| T-001 Orientation | PASS | fw doctor: 0 fail, 3 warn. fw audit: 44 pass, 10 warn, 2 fail |
| T-002 Project Goals | PARTIAL | Agent ACs done, human AC pending |
| T-003 First Commit | PASS | 29 files, +2156 lines |
| T-004 Task Lifecycle | PASS | 3 completed, 3 episodics |
| T-005 First Handover | PASS | Handover generated + committed |

### Final KCP health

- **fw doctor:** 0 failures, 2 warnings
- **fw audit:** 51 pass, 7 warn, 2 fail (pre-framework git history)

## Patterns Worth Extracting for Framework

1. **KCP manifest format** — `knowledge.yaml` is a declarative knowledge map. Relevant to T-477 (governance declaration layer). The manifest structure (topics, questions, compatibility) could inform how we declare operation classes.

2. **MCP bridge pattern** — KCP wraps its own context format as MCP tools. We could do the same with framework governance data (expose task state, audit results, fabric deps as MCP tools).

3. **Conformance testing** — KCP has cross-language conformance suites. We have bats tests but no conformance testing for consumer projects. Worth considering.

4. **RFC-driven evolution** — KCP uses numbered RFCs (17 so far) to propose and track spec changes. Similar to our decisions.yaml but more formal.

## Template Improvements Made

1. Added directory numbering guidance (`ls -d /opt/0*/ | sort`)
2. Added "verify clone target doesn't exist" pre-flight step
3. Added mirror terminal step for human observation
4. Identified need for template to specify seed task count by mode

## Prior Art

- T-487: KCP spec research (document review only, no codebase ingestion)
- T-678/T-679: vnx-orchestration deep-dive (first proven Path C)
- T-696: Path C template qualification (GO)
