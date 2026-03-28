# Agentic Engineering Framework — README Showcase Features

## Wow Factor (Most Impressive)

### 1. **Structural Task Enforcement — "Nothing Gets Done Without a Task"**
- **Wow:** File edits are pre-blocked by Claude Code hooks until an active task exists
- **Why:** Not aspirational — enforced at the agent level via `.claude/settings.json` PreToolUse hooks
- **Showcase:** "The framework enforces what most teams only suggest. No task? No code changes allowed. Ever."
- **Differentiation:** No other framework implements file-edit enforcement for task coupling

### 2. **Antifragile Self-Healing Loop** 
- **Wow:** When tasks fail, the framework automatically diagnoses, suggests fixes, and learns patterns
- **Why:** Uses Error Escalation Ladder (A→B→C→D) to graduate from "don't repeat" to "change ways of working"
- **Features:**
  - `fw healing diagnose` classifies failures (code/env/design/external)
  - Searches patterns.yaml for similar known failures
  - `fw healing resolve` captures the fix as a pattern for future reference
- **Showcase:** "Your failures become institutional knowledge. Every bug fix updates the collective memory."
- **Differentiation:** Most tools log errors; this one learns from them

### 3. **Three-Layer Memory System (Context Fabric)**
- **Wow:** Persistent multi-layered memory across sessions
- **Layers:**
  1. **Working Memory** — Current focus, pending actions (session-scoped)
  2. **Project Memory** — Patterns, decisions, learnings (project-lifetime)
  3. **Episodic Memory** — Condensed task histories auto-generated on completion
- **Showcase:** "The framework remembers what worked last time and suggests it again next time."
- **Advanced:** Semantic + hybrid search across episodic history using sqlite-vec + Ollama embeddings

### 4. **Tier 0 Enforcement — Gated Destructive Actions**
- **Wow:** Force-push, `rm -rf`, `DELETE TABLE` are blocked until human approval
- **Why:** Prevents accidental catastrophes from autonomous agents
- **Implementation:** PreToolUse hook on Bash commands, human-issued `fw tier0 approve` to bypass
- **Showcase:** "Destructive operations require explicit human sign-off, always audited."
- **Differentiation:** No other framework implements graduated approval tiers

### 5. **Semantic Search + Hybrid BM25 Ranking**
- **Wow:** Query project knowledge using semantic embeddings + keyword search fusion
- **Features:**
  - `fw search --semantic "authentication patterns"`
  - `fw search --hybrid` combines vector + BM25 with RRF (Reciprocal Rank Fusion)
  - Ollama-based embeddings, sqlite-vec storage, LRU query cache
- **Showcase:** "Find patterns by meaning, not just keywords. 'How do we handle timeouts?' returns the right answer."

## Differentiation (What No Other Tool Does)

### 6. **Component Fabric — Structural Topology Map**
- **Wow:** `.fabric/` tracks every significant file, its dependencies, who depends on it
- **Capabilities:**
  - `fw fabric deps <path>` — What depends on this file?
  - `fw fabric impact <path>` — Full transitive downstream impact
  - `fw fabric blast-radius HEAD` — What will this commit affect?
  - `fw fabric drift` — Detect unregistered/orphaned/stale components
- **Showcase:** "Know the full downstream impact before you commit. Prevents cascading failures."
- **Differentiation:** Unique structural dependency tracking for impact analysis

### 7. **Inception Phase (Exploration Before Build)**
- **Wow:** Dedicated workflow for pre-build exploration with go/no-go decisions
- **Features:**
  - `fw inception start "Explore X"` — Creates inception task + structured template
  - Builds research artifacts incrementally
  - Commit gate blocks further commits after 2 exploratory commits until decision is recorded
  - `fw inception decide T-XXX go` → Auto-creates follow-up build tasks
- **Showcase:** "Explore the problem space rigorously BEFORE committing to build. Prevents sunk-cost builds."

### 8. **Graduation Pipeline (Learnings → Practices)**
- **Wow:** Learnings from completed tasks become project practices
- **Flow:**
  - Tasks capture decisions, patterns, learnings
  - `fw promote suggest` identifies practices ready for graduation
  - `fw promote L-XXX --name "..."` converts learning to practice (joins D1-D4 directives)
  - Graduated practices auto-apply to future tasks
- **Showcase:** "Your best practices self-propagate. Learnings become directives."

### 9. **Session Capture + Auto-Handover**
- **Wow:** At session end, auto-generate forward-looking context document
- **Features:**
  - `fw handover` writes `.context/handovers/LATEST.md` with:
    - Current state summary
    - Suggested First Action (prioritized by task horizon)
    - In-progress work + blockers
    - Recent decisions + learnings
  - Auto-compaction on critical context budget (>75%) triggers auto-restart wrapper
  - Session State Recovery syncs fresh session context from handover
- **Showcase:** "Never lose context. The framework bridges sessions automatically."
- **Differentiation:** Unique session continuity model for long-running projects

### 10. **Watchtower Web UI + Smart Scanner**
- **Wow:** Dashboard showing project health, work queue prioritization, antifragility metrics
- **Features:**
  - Real-time task board (active/completed/blocked)
  - Inception phase visualization
  - Enforcement status (git hooks, Tier 0, bypass logs)
  - Pattern/learning/decision explorer
  - Timeline visualization (sessions, milestones)
  - `fw scan` — automated opportunity detection + risk assessment
- **Showcase:** "See your entire project state at a glance. Visual command center."

## Practical Value (Biggest Time Savers)

### 11. **Sub-Agent Dispatch Protocol**
- **Wow:** Structured format for dispatching parallel agents (Explore, Code, Audit)
- **Features:**
  - Result ledger (`fw bus`) prevents 30K+ context spikes from agents returning full content
  - Agents write to disk, return summary + path (content generators)
  - Investigators return structured summaries with file:line references
  - Size gating: <2KB inline, >=2KB → blob storage + reference
- **Showcase:** "Scale from 1 agent to 5 in parallel without context explosion."
- **Evidence:** T-073 used 9 agents → 177K spike. After bus protocol: ~7K overhead.

### 12. **Git Integration with Task Traceability**
- **Wow:** Every commit must reference a task. Pre-push audit validates traceability.
- **Features:**
  - `fw git commit -m "T-XXX: message"` enforces task reference
  - Pre-push hook runs audit, verifies >=80% commit coverage
  - Bypass log documents exceptions (Tier 2 authorization)
  - `fw git log --traceability` — shows task-filtered history
- **Showcase:** "Every change has a why. Audit trails are automatic."

### 13. **Effort Prediction from Episodic History**
- **Wow:** Estimate task effort based on similar completed tasks
- **Command:** `fw metrics predict --type build` → min/median/avg/max times + commits + lines changed
- **Showcase:** "Historical data → realistic effort estimates. Plan with confidence."

### 14. **Automatic Audit Trail Persistence**
- **Wow:** All compliance audits saved to `.context/audits/YYYY-MM-DD.yaml`
- **Features:**
  - Trend detection (comparing current vs. previous audits)
  - Antifragility metrics (pattern/learning capture velocity)
  - Pre-push hook provides gate (FAIL=block, WARN=proceed)
- **Showcase:** "Compliance isn't optional. It's enforced and audited."

### 15. **Context Budget Management (P-009)**
- **Wow:** Framework monitors actual token usage from session transcript
- **Features:**
  - `budget-gate.sh` PreToolUse hook reads session JSONL, blocks at critical (≥150K tokens)
  - `checkpoint.sh` PostToolUse warns + auto-generates handover
  - `.context/working/.budget-status` caches level (ok/warn/urgent/critical)
  - Escalation ladder: 120K→ok, 120-150K→warn, 150-170K→urgent, 170K+→critical
- **Showcase:** "Token budget is real. Framework prevents runaway context and auto-recovers."

## Quick Implementation Highlights

### 16. **One-Command Task Start**
- `fw work-on "Fix login bug" --type build` — Creates task + sets focus + starts work
- `fw work-on T-042` — Resume existing

### 17. **Multi-Stage Compliance Enforcement** (3 layers)
- Layer 1: Claude Code hooks (PreToolUse: check-active-task.sh, check-tier0.sh, budget-gate.sh)
- Layer 2: Git hooks (commit-msg, pre-push)
- Layer 3: Enforcement baseline (detects settings.json changes)

### 18. **Provider-Agnostic Design**
- Works with any agent: Claude, GPT-4, Gemini, Llama, etc.
- CLI-native (bash scripts + Python utilities)
- MCP server support planned
- No vendor lock-in

---

## README Showcase Strategy

**Opening hook (1 paragraph):**
"Not a library. Not a tool. A governance framework that enforces task-first development at the file-edit level, learns from failures, remembers what worked, and grows stronger under stress."

**Showcase order (by impact):**
1. Task enforcement + structural gates (wow + trust)
2. Self-healing loop (wow + practical value)
3. Multi-layer memory (practical + wow)
4. Semantic search + inception (differentiation)
5. Watchtower UI + scanner (usability)
6. Component fabric (differentiation)
7. Tier 0 enforcement (trust + differentiation)
8. Session continuity (practical)
9. Sub-agent dispatch (practical)
10. Git traceability (practical + audit)

**Taglines:**
- "Task-enforced. Antifragile. Remembers everything."
- "When AI agents work, they work by the rules."
- "Structured governance for autonomous teams."
- "Your failures become your practice library."
