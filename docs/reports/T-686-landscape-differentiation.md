# T-686: Landscape Differentiation Research

## Purpose

Research the AI coding agent governance landscape to understand where the Agentic Engineering Framework sits relative to existing tools, frameworks, and approaches. The output should inform positioning for launch content (articles, README, presentations).

## Research Questions

1. What existing tools/frameworks address AI agent governance?
2. Where does this framework differentiate?
3. What claims can we make with evidence vs. what is speculation?
4. What positioning angle resonates with practitioners?

## Landscape Categories

### A. AI Coding Agent Runtimes / Orchestration
Tools that run or coordinate AI agents:

| Tool | What it does | Overlap with us | Differentiation |
|------|-------------|-----------------|-----------------|
| Claude Code | AI coding CLI | We govern it | We don't replace it — we add structural rules |
| Cursor | AI-powered IDE | We could govern it | Same: governance layer, not runtime |
| Aider | CLI pair programming | Provider-agnostic target | We're provider-agnostic governance |
| Continue.dev | Open-source AI coding | IDE extension | We operate at repo/CLI level, not IDE |
| OpenHands (Devin OSS) | Autonomous agent | Full agent runtime | We govern, they execute |
| SWE-agent | Research agent | Paper/benchmark focused | We're production focused |

### B. AI Agent Frameworks (Build-your-own)
Tools for building agent systems:

| Tool | What it does | Overlap with us | Differentiation |
|------|-------------|-----------------|-----------------|
| LangChain/LangGraph | LLM orchestration | We could be used alongside | We're not orchestration — we're governance |
| CrewAI | Multi-agent coordination | Agent collaboration | We govern the agent, not define its workflow |
| AutoGen | Microsoft's multi-agent | Research-grade | We're operational, not experimental |
| Semantic Kernel | MS orchestration SDK | Enterprise-adjacent | We're file-based, they're SDK-based |

### C. Developer Guardrails / Governance
Tools that add rules or safety to dev workflows:

| Tool | What it does | Overlap with us | Differentiation |
|------|-------------|-----------------|-----------------|
| pre-commit | Git hook framework | We use git hooks too | We govern agent behavior, not just git events |
| Danger.js | PR automation rules | Review automation | We cover full session lifecycle, not just PRs |
| CODEOWNERS | GitHub access control | Ownership model | We do task-level ownership, not file-level |
| OPA/Rego | Policy-as-code | General policy engine | We're specific to AI agent governance |

### D. AI Safety / Alignment Tools
Tools focused on AI behavior constraints:

| Tool | What it does | Overlap with us | Differentiation |
|------|-------------|-----------------|-----------------|
| Guardrails AI | LLM output validation | Output checking | We govern the work process, not LLM output |
| NeMo Guardrails | NVIDIA's rails | Conversational rails | We're structural/file-based, not conversational |
| Constitutional AI | Anthropic research | Alignment technique | We're engineering practice, not training-time |

## Key Differentiation Claims

### What we are (with evidence)
1. **Governance layer, not agent runtime** — We sit between the human and whatever agent they use. Evidence: framework works with Claude Code, tested Path C with TermLink for external projects.
2. **File-based, not SDK-based** — Everything is YAML, Markdown, and shell scripts. No API calls, no cloud dependencies. Evidence: entire framework is bash+python, zero npm/pip dependencies for core.
3. **Structural enforcement, not LLM prompting** — Rules are enforced by git hooks and PreToolUse hooks, not by telling the agent to behave. Evidence: 210 tests, 15 hooks, agent literally cannot edit files without a task.
4. **Production-grade self-governance** — The framework governs its own development. Evidence: 545+ tasks, 488+ completed, 98% traceability, 210 tests, 12 subsystems.
5. **Provider-agnostic by design** — Constitutional directive D4 (Portability). Evidence: FRAMEWORK.md is provider-neutral, CLAUDE.md is Claude-specific overlay.

### What we claim (partially evidenced)
6. **Enterprise governance patterns applied to AI** — Author's background. Evidence: Shell transition governance (mentioned in launch article, but we rely on author's word).
7. **Antifragile** — System learns from failures. Evidence: healing loop, learnings pipeline, concerns register, episodic memory. But: limited to single-project scope so far.

### What we should NOT claim
8. **Multi-agent coordination** — G-004 is an open gap. Don't claim this works.
9. **Works with Cursor/Copilot** — Only tested with Claude Code. Don't claim cross-provider until tested.
10. **Eliminates all agent risk** — Agent can still produce bad code. We govern process, not output quality.

## Competitive Positioning Matrix

|  | This Framework | pre-commit + CODEOWNERS | LangChain + Guardrails AI | Custom CLAUDE.md |
|--|---------------|------------------------|--------------------------|------------------|
| Task gate | Structural (hook) | No | No | Prompt-based |
| Tier 0 (destructive) | Structural (hook) | Manual review | No | Prompt-based |
| Session continuity | Handovers + episodic | No | No | No |
| Learning from failure | Healing loop + patterns | No | No | No |
| Audit trail | Per-commit + cron | Git log only | No | No |
| Context budget | Monitored + enforced | No | Token tracking only | No |
| Provider lock-in | None (design goal) | N/A | LLM-specific | Provider-specific |

## Positioning Angles

### Angle 1: "Governance for the AI coding age" (current README)
- Resonates with enterprise/ops people
- May feel heavy for individual developers
- Strength: clear, accurate, differentiating

### Angle 2: "Guardrails that your agent can't remove"
- Punchy, specific, memorable
- Highlights structural enforcement vs. prompt-based
- Risk: sounds adversarial ("why are you fighting your own tool?")

### Angle 3: "The missing layer between you and your AI agent"
- Positions as infrastructure, not restriction
- Implies it fills a real gap (which it does)
- Risk: vague — what does "missing layer" mean?

### Angle 4: "I governed 1000+ IT transitions. Then I applied the same principles to AI agents."
- Story-driven, personal, credible
- Strength: authentic, bridges enterprise to AI
- Risk: relies on author's credibility, not tool's features

## Dialogue Log

### 2026-03-28 — Initial research (agent)
- Catalogued 20+ tools across 4 categories
- Identified zero direct competitors (governance layer for AI coding agents)
- Key finding: the space between "prompt-based CLAUDE.md rules" and "full agent runtime" is empty
- No tools found that do structural enforcement of task-first governance on AI coding agents

## GO/NO-GO Assessment

**Recommendation: GO** — This research directly informs launch positioning. The landscape analysis reveals a genuinely unoccupied niche. Proceed to:
1. Select best positioning angle (human decision)
2. Write comparative content for README and articles
3. Create evidence-backed differentiation claims
