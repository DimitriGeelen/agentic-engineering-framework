# T-629: Framework Self-Governance Failures — Ultra-Deep Audit

## The Problem

The Agentic Engineering Framework's governance mechanisms are actively impeding productive work. Evidence from session 2026-03-26:

1. **Stale global scripts → total deadlock** (3x this session alone)
2. **Task gate blocks legitimate operations** (memory writes, config changes)
3. **Inception gate blocks commits** when work spans inception + build
4. **Missing hook scripts → cascading failures** (boundary, cadence, loop-detect)
5. **Long command output → terminal paste failures** (3x)
6. **Circular dependency**: fixing the framework requires the framework to work

## Investigation Summary (12 TermLink Agents)

| # | Agent | Key Finding |
|---|-------|-------------|
| 1 | deadlock-patterns | 5 PreToolUse hooks gate all tools. Read/Glob/Grep are NEVER gated — only diagnostic escape hatch |
| 2 | hook-cascade | Missing script → hook exit code treated as block → cascading failure across Write+Edit+Bash |
| 3 | self-healing | Healing loop is fully manual, zero proactive detection, zero auto-recovery |
| 4 | circular-deps | **6 confirmed circular dependencies**, 3 with no clean break path |
| 5 | task-gate | 12 sequential checks on every Write/Edit. Exempt paths exist but don't cover hook scripts themselves |
| 6 | inception-gate | **24+ bypasses** of 2-commit limit recorded. Concern R-032 acknowledged since Feb 19 |
| 7 | command-length | **41 commands >80 chars** across framework output. Inception decide template is 112 chars |
| 8 | session-start | **22K tokens** consumed before first real work (11% of context window) |
| 9 | consumer-health | 4 out of 16 scripts diverged in 001-sprechloop. Consumers drift within hours |
| 10 | error-quality | 87 error messages audited. Good ones score 5/5 (actionable). **12 score 0-2** (cryptic, no fix command) |
| 11 | time-analysis | **27% real work, 27% governance friction, 22% meta-work, 16% housekeeping** |
| 12 | meta-governance | **28:1 add:remove ratio** in CLAUDE.md. 90% of completed tasks are meta. No rule retirement mechanism |

## The Five Structural Flaws

### Flaw 1: No Rule Retirement Mechanism

CLAUDE.md grows monotonically. In 30 days: 224 lines added, 8 removed (28:1 ratio). No concept of:
- Rule TTL or expiry
- Periodic review cadence
- Graduation DOWN (retire rules that proved unnecessary)
- Governance overhead budget

**Result:** 1001-line CLAUDE.md consuming 22K tokens. 76 sections, 117 enforcement keywords (MUST/NEVER/ALWAYS). Agent reads the full document every session.

### Flaw 2: Self-Referential Spiral

Governance failures generate more governance:
```
G-019 → T-393 → new CLAUDE.md rule → G-020 → T-469 → new rule → G-023 → T-614 → more rules
```

Evidence: 90% of recently completed tasks are meta-work (framework maintaining itself). 100% of handover "Suggested First Action" entries pointed to governance work, never to value delivery. The framework is its own biggest customer.

### Flaw 3: Circular Deadlocks Without Escape

**CD-1 (Critical):** Hook script broken → need Write/Edit to fix → Write/Edit gated by the broken hook → BLOCKED. No safe mode, no bootstrap path.

**CD-2 (Critical):** settings.json has bad hook config → need Edit to fix → Edit gated by check-active-task which reads settings.json → BLOCKED.

**CD-3 (Critical):** Global fw resolves to stale install → all hooks call stale scripts → agent can't run ANY tool to fix it → human must manually copy files.

**Mitigations that exist but are fragile:**
- Exempt paths (.context/, .tasks/, .claude/) bypass task gate — but hook scripts at agents/context/ are NOT exempt
- Python try/except fail-open catches parse errors but not logic bugs
- Deleting .context/working/ triggers bootstrap mode — but destroys session state

### Flaw 4: Manual Healing Loop

The healing agent (`agents/healing/`) is a knowledge base with CLI, not a self-healing system:
- Zero proactive detection (nothing watches for failures)
- Zero auto-recovery (no hook triggers healing)
- Zero self-triggering (requires manual `fw healing diagnose`)
- 11 recorded patterns but none prevent recurrence

Compare: the framework monitors CONTEXT budget proactively (checkpoint.sh), but has zero proactive monitoring of its own OPERATIONAL health.

### Flaw 5: Behavioral Rules Without Enforcement

CLAUDE.md contains two types of rules mixed together without distinction:
- **Structural** (hook-enforced): Task gate, Tier 0, budget gate, boundary check — these work
- **Behavioral** (agent-discipline): Hypothesis-driven debugging, commit cadence, bug-fix learning checkpoint, choice presentation — these work only if the agent reads and follows them

13 behavioral rules have zero enforcement. They create a false sense of coverage and consume 22K tokens of context every session for rules that have no structural backing.

## The Structural Fix: Governance v2

### Principle: Governance Should Be Invisible When Working, Obvious When Failing

### Phase 1: Emergency (do now)

1. **Add safe mode** — A `FW_SAFE_MODE=1` env var that disables all PreToolUse hooks except Tier 0. Set it when recovering from deadlocks. Clears on next normal session start.

2. **Hook fail-open for missing scripts** — If hook script doesn't exist, log warning and exit 0 (allow). Currently exits non-zero (block). This single change eliminates the entire stale-script deadlock class.

3. **Expand exempt paths** — Add `agents/context/*.sh` to the task gate allowlist. Hook scripts are infrastructure, not features — they should be editable without a task.

### Phase 2: Pruning (this week)

4. **CLAUDE.md diet** — Cut from 1001 lines to ~300:
   - Keep: Core principle, authority model, enforcement tiers, task lifecycle, context budget, session protocol, quick reference
   - Move to docs/: Sub-agent dispatch protocol, TermLink integration, inception discipline details, Human AC format requirements, all project-specific rules
   - Delete: Behavioral rules with zero enforcement (or add enforcement first)

5. **Raise inception commit limit** — From 2 to 5 (or remove entirely). 24+ bypasses prove the current limit is wrong. Replace with: "inception tasks should have a decision within 5 commits" (advisory, not blocking).

6. **Task backlog purge** — Archive all `started-work` tasks older than 14 days to `horizon: later`. A 73-task active backlog is governance debt generating noise in every handover.

### Phase 3: Self-Healing (next sprint)

7. **Proactive health check** — A PostToolUse hook (advisory) that runs every 50 tool calls:
   - Are all hook scripts present and parseable?
   - Is focus.yaml pointing to an active task?
   - Is the global install in sync?
   - Reports issues BEFORE they become deadlocks

8. **Governance overhead metric** — Track: % of commits that are meta-work vs feature work. Add to `fw metrics`. Target: <30% meta. Alert at >50%.

9. **Rule retirement process** — Every rule in CLAUDE.md gets a `since:` date. Quarterly review: rules older than 90 days with zero enforcement and zero bypass-log references are candidates for removal. Graduation goes both directions.

### Phase 4: Architecture (future)

10. **Separate CLAUDE.md into layers**:
    - `CLAUDE-core.md` (~200 lines): Constitutional directives, task gate, tiers, budget, session protocol
    - `CLAUDE-practices.md` (~300 lines): Behavioral guidance, loaded only when relevant
    - `CLAUDE-project.md` (~100 lines): Project-specific rules (TermLink, Watchtower, deployment)
    - Only core is always loaded. Practices and project are loaded on demand.

## Go/No-Go Criteria

**GO if:**
- Phase 1 (safe mode + fail-open + exempt paths) can be built in one session
- CLAUDE.md can be cut to <400 lines without losing structural enforcement
- The team agrees that 27% real work is unacceptable

**NO-GO if:**
- The governance overhead is acceptable for the project's maturity stage
- Cutting rules would reintroduce problems the rules were created to prevent
- The 90% meta-work ratio is temporary (project is in framework-building phase)

## Evidence Files

Full agent reports (3109 lines total):
- `docs/reports/fw-agent-t629-01-deadlocks.md` — Deadlock pattern matrix
- `docs/reports/fw-agent-t629-02-cascades.md` — Hook failure cascade diagram
- `docs/reports/fw-agent-t629-03-healing.md` — Self-healing gap analysis
- `docs/reports/fw-agent-t629-04-circular.md` — 6 circular dependencies documented
- `docs/reports/fw-agent-t629-05-taskgate.md` — Task gate: 12 checks, friction points
- `docs/reports/fw-agent-t629-06-inception.md` — Inception gate: 24+ bypasses
- `docs/reports/fw-agent-t629-07-cmdlen.md` — 41 commands >80 chars
- `docs/reports/fw-agent-t629-08-session.md` — 22K tokens before real work
- `docs/reports/fw-agent-t629-09-consumers.md` — Consumer health scores
- `docs/reports/fw-agent-t629-10-errors.md` — 87 error messages rated
- `docs/reports/fw-agent-t629-11-time.md` — Session time analysis
- `docs/reports/fw-agent-t629-12-meta.md` — Governance-to-value ratio: 9:1
