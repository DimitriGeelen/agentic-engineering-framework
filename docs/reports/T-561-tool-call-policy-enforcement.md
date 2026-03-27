# T-561: OpenClaw Comparative — Tool Call Policy Enforcement

## Comparison: runBeforeToolCallHook vs PreToolUse

### OpenClaw: runBeforeToolCallHook

**Source:** T-549 architecture mapping, `src/agents/tool-loop-detection.ts` (624 LOC)

Enforces 3 things before every tool call:
1. **Tool loop detection** — max consecutive same-tool calls. 4 detectors:
   - Same tool called N times in a row
   - Same tool+params called N times (exact duplicate)
   - Oscillation between two tools
   - Total tool calls exceeding session limit
2. **Policy checks** — allowlist/deny rules with profile inheritance
   - Per-tool policies: allow, deny, require-approval
   - Profile-scoped: different tools available per agent profile
   - Group rules: channel-specific tool restrictions
   - Subagent isolation: spawned agents have limited tool sets
3. **Tool validation** — schema validation of tool parameters before execution

### Our Framework: PreToolUse Hooks

Three hooks, each enforcing different concerns:

| Hook | File | What it enforces |
|------|------|-----------------|
| `check-active-task.sh` | agents/context/ | Task-first gate: task exists, is active, has real ACs |
| `check-tier0.sh` | agents/context/ | Destructive command detection: rm -rf, git push --force, etc. |
| `budget-gate.sh` | agents/context/ | Context budget: blocks Write/Edit at critical (≥190K tokens) |

**Also:** `check-fabric-new-file.sh` (advisory: new file count limit), `error-watchdog.sh` (PostToolUse: error pattern detection).

### Gap Analysis

| Enforcement | OpenClaw | Our Framework | Gap |
|-------------|----------|---------------|-----|
| Task-first gate | No equivalent | `check-active-task.sh` | We're ahead |
| Destructive command detection | No equivalent | `check-tier0.sh` | We're ahead |
| Budget/context management | No equivalent (shorter sessions) | `budget-gate.sh` | We're ahead |
| Tool loop detection | `tool-loop-detection.ts` (624 LOC, 4 detectors) | `loop-detect.ts` (T-594, basic) | **Gap: partial** |
| Per-tool policies (allow/deny) | Full policy engine with profiles | No equivalent | **Gap: medium** |
| Parameter schema validation | Pre-execution validation | Claude Code handles this | N/A (Claude Code responsibility) |
| Subagent tool isolation | Spawned agents get limited tools | No equivalent | **Gap: low priority** |
| Inception enforcement | No equivalent | commit-msg hook | We're ahead |

### Key Finding: Different Architecture, Different Gaps

OpenClaw is a multi-user platform serving many concurrent agents. Its tool policy engine (allow/deny/require-approval per profile) is designed for multi-tenant isolation. Our framework is single-agent, single-user — we enforce governance differently (task gates, tiers, inception discipline).

**What we should adopt:**
1. **Enhanced loop detection** — T-594 already ported basic loop detection to TypeScript. The 4-detector approach from OpenClaw (same tool, same params, oscillation, total limit) is more robust than our single-detector approach.
2. **Tool call rate limiting** — not a current gap but worth adding if agent runaway becomes an issue.

**What we should NOT adopt:**
1. **Per-tool policies** — our enforcement model (tiers, tasks, inception) is more principled than tool-level allow/deny lists. Adding tool policies would be redundant complexity.
2. **Subagent tool isolation** — TermLink workers already have process isolation. Tool-level isolation within a session is overkill for our use case.

## Recommendation: GO on Loop Detection Enhancement

T-594 (loop detector port to TypeScript) is already work-completed. The gap is adding the 3 missing detectors (same params, oscillation, total limit) to our existing `loop-detect.ts`.

**Effort:** ~1 session to add 3 detectors.
**Priority:** Low — loop detection is advisory (doesn't block), and runaway loops are rare.

## Dialogue Log

- Comparative analysis based on T-549 architecture mapping and T-586 prototype comparison
- No new OpenClaw code reading required — findings already documented
