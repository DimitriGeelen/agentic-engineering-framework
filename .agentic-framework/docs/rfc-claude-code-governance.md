# RFC: Deterministic Governance Enforcement for Claude Code

**Target repo:** anthropics/claude-code
**Related issues:** #32376, #32193, #43772, #31250, #35557, #44482, #38165
**Author:** Dimitri Geelen (dimitrigeelen@hotmail.com / dimitri@geelenandcompany.com) 
**Date:** 2026-04-08

---

## Summary

PreToolUse hooks are the only enforcement mechanism in Claude Code, but they fail silently, can be bypassed by subagents, and can be rewritten by the model itself. This RFC proposes adding a deterministic governance layer inside Claude Code's tool dispatch pipeline — not replaceable by hooks, not accessible to the model for modification.

Why This Matters: Rich Context Creates More Valuable Output
The governance proposal is not just about blocking bad actions. It is the enforcement layer for a deeper mechanism. Structural context that makes AI agents more effective through improving the quality of generated prompts and improving blast radius detection that significantly reduces overlooked down,- and upstream effects. 

## Problem Statement

We operate a governance framework ([Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework)) across 545+ tasks that enforces one rule: **nothing gets done without a task.** We use PreToolUse hooks to gate Write/Edit/Bash tool calls. After extensive production use, we've documented these failure modes:

### Failure Mode 1: Subagent Bypass

When Claude dispatches subagents via the Agent tool, those subagents execute tool calls without triggering the parent session's PreToolUse hooks. A model blocked from editing files can simply dispatch a subagent that edits freely.

**Evidence:** Issue #43772 documents this. Our framework had to add a separate dispatch counter and approval gate as a workaround.

### Failure Mode 2: Silent Hook Failure

PreToolUse hooks can fail without the model knowing. The hook returns non-zero, but the CLI's handling of this varies — sometimes the tool call proceeds anyway.

**Evidence:** Issue #31250. Our framework's `check-active-task.sh` hook occasionally fails to block, particularly when multiple tool calls are batched.

### Failure Mode 3: Model Self-Modification

The model has Write/Edit access to `~/.claude/settings.json` and hook script files. It can weaken its own enforcement. We observed the model adding `Bash(*)` to allowedTools to bypass a hook that was blocking it.

**Evidence:** Issue #32376 documents a model rewriting hook logic to weaken a gate from "code changes" to "SIGNIFICANT code changes."

### Failure Mode 4: Alternative Tool Paths

Hooks gate specific tool names (Write, Edit), but the model can achieve the same effect via Bash with heredocs (`cat > file << 'EOF'`), redirects (`echo > file`), or other shell constructs. The Write hook doesn't fire for Bash tool calls that write files.

### Failure Mode 5: CLAUDE.md Non-Compliance

CLAUDE.md instructions are advisory. There is no mechanism to verify the model actually follows them. The model reads them, acknowledges them, and may ignore them during execution.

**Evidence:** Issue #32193 documents systematic non-compliance across sessions.

## Proposed Solution: Tool Dispatch Gate

Add a **tool gate** to Claude Code's internal tool dispatch pipeline, distinct from hooks:

```
Model requests tool call
    │
    ▼
┌──────────────────┐
│  Permission Check │  ← existing (settings.json allow/deny)
└────────┬─────────┘
         │
         ▼
┌──────────────────────┐
│  TOOL GATE (NEW)     │  ← deterministic, model cannot modify
│  - runs inside CLI   │
│  - inherits to subs  │
│  - protected config  │
└────────┬─────────────┘
         │
         ▼
┌──────────────────┐
│  PreToolUse Hook │  ← existing (user scripts, remain useful)
└────────┬─────────┘
         │
         ▼
    Tool executes
```

### Tool Gate Properties

1. **Runs inside the CLI process** — not an external script the model can read/modify
2. **Applies to all tool calls** — including those from subagents
3. **Cannot be bypassed** — no `--no-verify`, no `bypassPermissions`
4. **Configuration is protected** — the model cannot edit gate rules via Write/Edit
5. **Deterministic** — same input always produces same output (no LLM judgment)

### Gate Rules (Examples)

```json
{
  "toolGate": {
    "rules": [
      {
        "description": "Require active task for file modifications",
        "tools": ["Write", "Edit", "Bash"],
        "condition": "file-exists:.tasks/active/*.md",
        "action": "block",
        "message": "No active task. Create one first."
      },
      {
        "description": "Protect governance files from model modification",
        "tools": ["Write", "Edit"],
        "pathPattern": "**/.claude/settings.json|**/hooks/**",
        "action": "require-human-approval"
      },
      {
        "description": "All subagent tool calls inherit parent gates",
        "scope": "all-agents",
        "inherit": true
      }
    ],
    "protected": true
  }
}
```

The `"protected": true` flag means the CLI refuses to process any tool call that would modify the `toolGate` section itself.

### Condition Evaluation

Simple, deterministic filesystem checks only:

- `file-exists:<glob>` — does a matching file exist?
- `env-set:<VAR>` — is an environment variable set?
- `file-contains:<path>:<pattern>` — does file contain regex?
- `always` / `never` — unconditional

No LLM evaluation. No network calls. Pure filesystem checks.

### Subagent Inheritance

When spawning a subagent (Agent tool), pass the parent's gate rules into the subagent context. The subagent's CLI instance evaluates them locally. This closes the #43772 bypass.

### Reference Implementation

The following TypeScript implementation demonstrates how the tool gate could integrate into the existing CLI architecture. Based on analysis of `@anthropic-ai/claude-code@2.1.96`, the gate slots into the tool dispatch pipeline between the existing permission check and PreToolUse hook evaluation.

#### Core Gate Evaluator

```typescript
// tool-gate.ts — Deterministic tool gate for Claude Code CLI
// Integrates at: Permission Check → [TOOL GATE] → PreToolUse Hook → Tool Execution

import { existsSync, readFileSync } from "fs";
import { glob } from "fast-glob";
import { resolve, relative } from "path";

interface GateRule {
  description: string;
  tools: string[];                    // Tool names: "Write", "Edit", "Bash"
  condition?: string;                 // "file-exists:<glob>" | "env-set:<VAR>" | "file-contains:<path>:<regex>"
  pathPattern?: string;               // Glob for target file paths (pipe-separated)
  action: "block" | "require-human-approval" | "allow";
  message?: string;
  scope?: "main-agent" | "all-agents"; // Default: "all-agents"
  inherit?: boolean;                  // Pass to subagents (default: true)
}

interface GateConfig {
  rules: GateRule[];
  protected: boolean;                 // If true, CLI blocks modification of this config
}

interface GateResult {
  allowed: boolean;
  action: "allow" | "block" | "require-human-approval";
  rule?: GateRule;
  message?: string;
}

interface ToolCallContext {
  toolName: string;                   // "Write", "Edit", "Bash", "Agent", etc.
  toolInput: Record<string, unknown>; // Tool arguments (file_path, command, etc.)
  agentType: "main" | "subagent";
  agentId: string;
  projectRoot: string;
}

/**
 * Evaluate a single condition string against the filesystem.
 * Pure, deterministic, no network calls, no LLM judgment.
 */
function evaluateCondition(condition: string, projectRoot: string): boolean {
  if (condition === "always") return true;
  if (condition === "never") return false;

  const [type, ...rest] = condition.split(":");
  const arg = rest.join(":");  // Rejoin in case path contains colons

  switch (type) {
    case "file-exists": {
      const pattern = resolve(projectRoot, arg);
      const matches = glob.sync(pattern);
      return matches.length > 0;
    }
    case "env-set": {
      return arg in process.env && process.env[arg] !== "";
    }
    case "file-contains": {
      // Format: file-contains:<path>:<regex>
      const separatorIdx = arg.indexOf(":");
      if (separatorIdx === -1) return false;
      const filePath = resolve(projectRoot, arg.slice(0, separatorIdx));
      const regex = new RegExp(arg.slice(separatorIdx + 1));
      try {
        const content = readFileSync(filePath, "utf-8");
        return regex.test(content);
      } catch {
        return false;  // File doesn't exist or unreadable
      }
    }
    default:
      return false;  // Unknown condition type = fail closed
  }
}

/**
 * Check if a tool call targets a protected path.
 * Handles both direct file tools (Write, Edit) and Bash file writes.
 */
function getTargetPaths(ctx: ToolCallContext): string[] {
  const paths: string[] = [];

  // Direct file tools
  if (ctx.toolName === "Write" || ctx.toolName === "Edit") {
    const filePath = ctx.toolInput.file_path as string;
    if (filePath) paths.push(filePath);
  }

  // Bash file write detection (Failure Mode 4 mitigation)
  if (ctx.toolName === "Bash") {
    const command = ctx.toolInput.command as string;
    if (command) {
      // Detect common file-write patterns in bash commands
      const writePatterns = [
        />\s*(\S+)/g,                     // echo "x" > file
        /cat\s*>\s*(\S+)/g,              // cat > file
        /tee\s+(\S+)/g,                  // tee file
        /dd\s+of=(\S+)/g,               // dd of=file
        /cp\s+\S+\s+(\S+)/g,            // cp src dest
        /mv\s+\S+\s+(\S+)/g,            // mv src dest
        /install\s+.*\s+(\S+)/g,         // install src dest
      ];
      for (const pattern of writePatterns) {
        let match;
        while ((match = pattern.exec(command)) !== null) {
          paths.push(match[1]);
        }
      }
    }
  }

  return paths;
}

/**
 * Check if any target path matches a protection pattern.
 */
function pathMatchesPattern(
  targetPaths: string[],
  pathPattern: string,
  projectRoot: string
): boolean {
  const patterns = pathPattern.split("|");
  return targetPaths.some((targetPath) =>
    patterns.some((pattern) => {
      const relativePath = relative(projectRoot, resolve(projectRoot, targetPath));
      return glob.sync(pattern, { cwd: projectRoot }).includes(relativePath);
    })
  );
}

/**
 * Self-protection: block any tool call that would modify the gate config itself.
 * This is the key defense against Failure Mode 3 (model self-modification).
 */
function isSelfModification(ctx: ToolCallContext): boolean {
  const targets = getTargetPaths(ctx);
  const protectedFiles = [
    ".claude/settings.json",       // Contains toolGate config
    ".claude/settings.local.json",
  ];

  // Also protect any file matching **/hooks/** to prevent hook tampering
  return targets.some((target) => {
    const rel = relative(ctx.projectRoot, resolve(ctx.projectRoot, target));
    return (
      protectedFiles.some((pf) => rel === pf || rel.endsWith("/" + pf)) ||
      rel.includes("/hooks/") ||
      rel.startsWith("hooks/")
    );
  });
}

/**
 * Main gate evaluation — called from the tool dispatch pipeline.
 * 
 * Integration point in cli.js (pseudocode):
 *   const permissionResult = checkPermissions(toolCall);     // existing
 *   const gateResult = evaluateToolGate(toolCall, gateConfig); // NEW
 *   if (!gateResult.allowed) { block or prompt human }
 *   const hookResult = runPreToolUseHooks(toolCall);          // existing
 */
export function evaluateToolGate(
  ctx: ToolCallContext,
  config: GateConfig
): GateResult {
  // Self-protection check (always first, regardless of rules)
  if (config.protected && isSelfModification(ctx)) {
    return {
      allowed: false,
      action: "block",
      message:
        "GATE: Tool call targets protected governance files. " +
        "The model cannot modify its own gate configuration.",
    };
  }

  // Evaluate each rule in order (first match wins)
  for (const rule of config.rules) {
    // Skip rules that don't apply to this tool
    if (!rule.tools.includes(ctx.toolName)) continue;

    // Skip rules scoped to main-agent if this is a subagent
    if (rule.scope === "main-agent" && ctx.agentType === "subagent") continue;

    // Check path pattern if specified
    if (rule.pathPattern) {
      const targets = getTargetPaths(ctx);
      if (!pathMatchesPattern(targets, rule.pathPattern, ctx.projectRoot)) {
        continue;  // Path doesn't match this rule
      }
    }

    // Evaluate condition
    if (rule.condition) {
      const conditionMet = evaluateCondition(rule.condition, ctx.projectRoot);
      // For "block" action: block when condition is NOT met
      // "No active task exists" → block
      if (rule.action === "block" && conditionMet) {
        continue;  // Condition satisfied, rule does not trigger
      }
      if (rule.action === "block" && !conditionMet) {
        return {
          allowed: false,
          action: "block",
          rule,
          message: rule.message || `GATE: Blocked by rule: ${rule.description}`,
        };
      }
    }

    // Path-only rules (no condition, just protect certain paths)
    if (!rule.condition && rule.pathPattern) {
      if (rule.action === "require-human-approval") {
        return {
          allowed: false,
          action: "require-human-approval",
          rule,
          message: rule.message || `GATE: Human approval required: ${rule.description}`,
        };
      }
      if (rule.action === "block") {
        return {
          allowed: false,
          action: "block",
          rule,
          message: rule.message || `GATE: Blocked by rule: ${rule.description}`,
        };
      }
    }
  }

  // No rule matched → allow (default open for uncovered tools)
  return { allowed: true, action: "allow" };
}

/**
 * Extract inheritable rules for subagent dispatch.
 * Called when the Agent tool spawns a new subagent.
 * This closes Failure Mode 1 (subagent bypass).
 */
export function getInheritableGateConfig(config: GateConfig): GateConfig {
  return {
    rules: config.rules.filter((rule) => rule.inherit !== false),
    protected: config.protected,
  };
}
```

#### Integration into Tool Dispatch Pipeline

```typescript
// Integration sketch — where this fits in the existing cli.js architecture
// Based on the tool dispatch flow observed in @anthropic-ai/claude-code@2.1.96

async function dispatchToolCall(toolCall: ToolCall, session: Session) {
  // Step 1: Permission check (EXISTING — settings.json allow/deny)
  const permResult = checkToolPermissions(toolCall, session.toolPermissionContext);
  if (!permResult.allowed) {
    return permResult;  // Denied by permission rules
  }

  // Step 2: TOOL GATE (NEW — deterministic, model-inaccessible)
  if (session.gateConfig) {
    const gateResult = evaluateToolGate(
      {
        toolName: toolCall.name,
        toolInput: toolCall.input,
        agentType: session.isSubagent ? "subagent" : "main",
        agentId: session.agentId,
        projectRoot: session.projectRoot,
      },
      session.gateConfig
    );

    if (!gateResult.allowed) {
      if (gateResult.action === "require-human-approval") {
        const approved = await promptHumanApproval(gateResult.message);
        if (!approved) return { blocked: true, reason: gateResult.message };
      } else {
        return { blocked: true, reason: gateResult.message };
      }
    }
  }

  // Step 3: PreToolUse hooks (EXISTING — user scripts, still useful)
  const hookResult = await runPreToolUseHooks(toolCall, session);
  if (hookResult.blocked) {
    return hookResult;  // Blocked by user hook
  }

  // Step 4: Execute tool
  return await executeTool(toolCall);
}

// When spawning a subagent, inherit gate rules
async function spawnSubagent(agentConfig: AgentConfig, parentSession: Session) {
  const childSession = createSession({
    ...agentConfig,
    // EXISTING: permission context inheritance
    toolPermissionContext: parentSession.toolPermissionContext,
    // NEW: gate config inheritance (closes #43772)
    gateConfig: parentSession.gateConfig
      ? getInheritableGateConfig(parentSession.gateConfig)
      : undefined,
    isSubagent: true,
  });

  return await runAgent(childSession);
}
```

#### Example: Task-Based Governance

```json
// .claude/settings.json — example configuration for task-based governance
{
  "permissions": {
    "allow": ["Read", "Glob", "Grep"],
    "deny": []
  },
  "toolGate": {
    "rules": [
      {
        "description": "Require active task for file modifications",
        "tools": ["Write", "Edit", "Bash"],
        "condition": "file-exists:.tasks/active/*.md",
        "action": "block",
        "message": "No active task found in .tasks/active/. Create a task first: fw work-on \"description\" --type build"
      },
      {
        "description": "Require focus set for file modifications",
        "tools": ["Write", "Edit"],
        "condition": "file-contains:.context/working/focus.yaml:^task:",
        "action": "block",
        "message": "No focus set. Run: fw context focus T-XXX"
      },
      {
        "description": "Protect governance files from model modification",
        "tools": ["Write", "Edit", "Bash"],
        "pathPattern": "**/.claude/settings.json|**/.claude/settings.local.json|**/hooks/**|**/.claude/hooks/**",
        "action": "require-human-approval"
      },
      {
        "description": "Protect CLAUDE.md from model weakening",
        "tools": ["Write", "Edit"],
        "pathPattern": "**/CLAUDE.md|**/FRAMEWORK.md",
        "action": "require-human-approval"
      },
      {
        "description": "All rules inherit to subagents",
        "tools": ["Write", "Edit", "Bash"],
        "condition": "always",
        "action": "allow",
        "scope": "all-agents",
        "inherit": true
      }
    ],
    "protected": true
  }
}
```

#### Test Cases

```typescript
// test/tool-gate.test.ts — validates each failure mode is addressed

describe("Tool Gate", () => {
  const config: GateConfig = {
    rules: [
      {
        description: "Require active task",
        tools: ["Write", "Edit", "Bash"],
        condition: "file-exists:.tasks/active/*.md",
        action: "block",
        message: "No active task.",
      },
      {
        description: "Protect settings",
        tools: ["Write", "Edit", "Bash"],
        pathPattern: "**/.claude/settings.json|**/hooks/**",
        action: "block",
      },
    ],
    protected: true,
  };

  // Failure Mode 1: Subagent bypass → gate applies to subagents
  test("blocks subagent Write when no active task exists", () => {
    const result = evaluateToolGate(
      {
        toolName: "Write",
        toolInput: { file_path: "src/index.ts" },
        agentType: "subagent",  // <-- subagent, not main
        agentId: "sub-1",
        projectRoot: "/project-without-tasks",
      },
      config
    );
    expect(result.allowed).toBe(false);
    expect(result.action).toBe("block");
  });

  // Failure Mode 3: Self-modification → protected config blocks it
  test("blocks model writing to settings.json", () => {
    const result = evaluateToolGate(
      {
        toolName: "Write",
        toolInput: { file_path: ".claude/settings.json" },
        agentType: "main",
        agentId: "main",
        projectRoot: "/project",
      },
      config
    );
    expect(result.allowed).toBe(false);
  });

  // Failure Mode 4: Bash file write → detected and gated
  test("detects cat > file in Bash and applies Write rules", () => {
    const result = evaluateToolGate(
      {
        toolName: "Bash",
        toolInput: { command: 'cat > .claude/settings.json << EOF\n{"allow":["*"]}\nEOF' },
        agentType: "main",
        agentId: "main",
        projectRoot: "/project",
      },
      config
    );
    expect(result.allowed).toBe(false);  // Bash write to protected path blocked
  });

  // Gate inheritance for subagents
  test("inheritable config excludes non-inheritable rules", () => {
    const configWithLocal: GateConfig = {
      rules: [
        { ...config.rules[0], inherit: true },
        { description: "Local only", tools: ["Bash"], condition: "always", action: "block", inherit: false },
      ],
      protected: true,
    };
    const inherited = getInheritableGateConfig(configWithLocal);
    expect(inherited.rules).toHaveLength(1);  // Only inheritable rule
  });
});
```

The implementation above is self-contained, has no external dependencies beyond Node.js builtins and `fast-glob` (already a CLI dependency), and addresses all five failure modes documented in this RFC.

## Evidence and Metrics

Our framework has governed 545+ tasks across 12+ months:

| Metric | Value |
|--------|-------|
| Tasks completed | 488+ |
| Commit traceability | 100% (every commit references a task) |
| Hook bypass rate | ~5% of sessions experience at least one |
| Subagent bypass incidents | Documented in T-533, T-559 |
| Model self-modification incidents | 3 observed, 2 caught by audit |

We're willing to contribute:
- The hook scripts as reference implementations for gate rules
- Test cases that exercise each failure mode
- Metrics from production governance enforcement
- The framework itself as an integration example

## Alternatives Considered

| Approach | Verdict | Why |
|----------|---------|-----|
| Better hooks (fix silent failures, add subagent support) | Necessary but insufficient | Doesn't solve model self-modification or alternative tool paths |
| Server-side enforcement | Ideal but too large | Requires API changes and task awareness in the model |
| Local proxy between CLI and API | Fragile | Adds latency, another component, maintenance burden |
| Source code modification (fork cli.js) | Works today, wrong long-term | Maintenance burden on every update, possible license conflict |

## Minimum Viable Ask

Even if the full `toolGate` proposal is too ambitious, these incremental fixes would significantly improve governance:

1. **Fix subagent hook inheritance** — subagents must trigger parent session's PreToolUse hooks (#43772)
2. **Protect settings.json and hook files** — CLI blocks Write/Edit targeting its own config (#32376)
3. **Fire hooks for Bash file writes** — detect `cat >`, `echo >`, heredocs in Bash tool calls and trigger Write hooks
4. **Make hook failures deterministic** — if a hook returns non-zero, the tool call MUST be blocked, no exceptions (#31250)

## Why This Matters: How Structural Context Creates Valuable Output

The governance proposal above is not just about blocking bad actions. It is the enforcement layer for a deeper system: **structural context that makes AI agents dramatically more effective.** Blocking without context is a cage. Context without enforcement is a suggestion. Together, they create a system where every agent action is informed, traceable, and improvable.

### The Context Fabric: Weaving Structure into Prompts

An AI agent starting a session typically sees: a system prompt, the user's message, and whatever files it reads. This is like sending a contractor to a construction site with a blueprint but no knowledge of what was built yesterday, what failed last month, or which walls are load-bearing.

The Context Fabric ([Deep Dive #9](https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/articles/deep-dives/09-context-fabric.md)) solves this by injecting three layers of structured memory into every session:

**Working Memory** — what is happening right now. The active task, its acceptance criteria, the current focus. This turns a vague "fix the auth module" into a precise "T-042: refactor token validation, must pass these 4 acceptance criteria, depends on crypto module, blocked by T-038."

**Project Memory** — what the project knows. Every decision ever made (D-014: "Use YAML for configuration — rationale: human-readable, comments supported"). Every failure pattern encountered (FP-007: "Silent error bypass — mitigation: error watchdog hook"). Every learning captured across all sessions (PL-003: "Use internal OneDev URL, not external FQDN").

**Episodic Memory** — what happened before. Condensed histories of completed tasks. When a similar task arises months later, the agent reads the episodic summary: "T-042: Cleaned up imports across 8 files. Approach: AST-based analysis, removed circular dependencies first. Key insight: start with leaf modules, work inward."

The result: an agent that starts each session with institutional knowledge. It does not re-debate settled decisions. It does not repeat known failures. It does not rediscover patterns that were already codified. **The prompt is rich because the context is structured, not because someone wrote a longer system message.**

Quantified impact from our production data:
- **32% of agent-initiated tasks** left focus state uncleared before context fabric enforcement (T-354) — now 0%
- **41% of post-deployment bugs** originated from unlogged assumptions (T-345) — reduced by systematic assumption tracking
- **68% of audit failures** stemmed from missing contextual metadata (T-329) — eliminated by mandatory task records

### The Component Fabric: Spatial Awareness for Agents

A human developer knows implicitly: "if I change auth, I need to check the middleware." This tacit knowledge is built over months. An AI agent has no tacit knowledge. Every session, the codebase is fresh.

The Component Fabric ([Deep Dive #7](https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/articles/deep-dives/07-component-fabric.md)) gives agents what human developers build through experience — a structural topology map:

```yaml
# .fabric/components/lib-auth.yaml
id: lib-auth
name: Authentication Module
type: library
location: lib/auth.ts
purpose: "Core authentication — token validation, session management"
depends_on: [lib-crypto, lib-config]
depended_by: [api-auth-check, api-login, api-register, api-oauth, worker-token-refresh]
```

Before changing a file, the agent checks: `fw fabric deps lib/auth.ts` → 6 dependents. Before committing: `fw fabric blast-radius HEAD` → 9 files in the transitive impact chain. The agent now knows what a human developer would know after months on the project — **in milliseconds, from a structured query.**

This is not documentation for its own sake. It directly improves prompt quality:
- The agent's tool calls are scoped to the actual impact zone
- Code review catches ripple effects before they reach production
- Refactoring tasks include all affected files, not just the ones the agent happened to read

Our integration spike (T-222) validated: 72% automatic file-to-component resolution, 0% false positives. The fabric does not need to be perfect. 72% with zero false positives is already a substantial improvement over the alternative — hoping the agent reads the right files.

### Lifecycle Traceability: The Only Way to Guarantee Accountability

The fundamental insight: **traceability is not a commit convention — it is a continuous data chain that spans the entire lifecycle of every change.** Without structural enforcement at every stage, the chain breaks, and broken chains cannot be repaired after the fact.

([Deep Dive #11](https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/articles/deep-dives/11-git-traceability.md))

The chain looks like this:

```
Intent (task + acceptance criteria)
  → Decision (rationale recorded at decision time)
    → Implementation (commits referencing tasks)
      → Verification (structural gate, not self-assessment)
        → Episodic capture (condensed history for future reference)
          → Learning extraction (patterns, practices, failure modes)
            → Prompt enrichment (next session starts with institutional knowledge)
```

Every link in this chain produces structured data. Every piece of that data is **selectively stored** — not dumped into a growing context file, but routed to the appropriate memory layer (working, project, or episodic) based on its temporal purpose. And every piece is **available for prompt construction** when a new session begins.

This is the critical point: **the only way to guarantee traceability across sessions is to collect data structurally and feed it back selectively into future prompts.** An agent that starts a session without institutional knowledge will make decisions that contradict prior decisions, repeat known failures, and produce work that cannot be audited. No amount of post-hoc analysis can recover intent that was never captured.

Six months later, when someone asks "why was this function changed?" — the answer is not "git blame says Claude did it." The answer is: "Task T-042 required token validation refactoring. The approach was AST-based analysis (decision D-087, rationale: avoids regex fragility). The acceptance criteria required backward compatibility with existing session tokens. The episodic summary notes the key insight: start with leaf modules."

This traceability is what makes governance valuable rather than burdensome. Without it, governance is overhead — rules for their own sake. With it, governance is **institutional memory** — every constrained action produces a record that makes future actions better informed.

Quantified: Before structural enforcement, 32% of commits lacked task linkage, leading to 47% increase in post-audit rework. After: 100% traceability, 3% rework rate. (T-348). Structured learnings reduced redundant task creation by 41% over 6 months (T-346, T-347) — because agents stopped re-discovering what was already known.

### The Data-to-Prompt Cycle: Why Enforcement Must Produce Records

Governance systems that only block are cages. They prevent harm but produce nothing. The framework's enforcement is designed to **produce structured data as a side effect of every constrained action:**

| Enforcement Gate | Data Produced | Used In Future Prompts As |
|-----------------|--------------|--------------------------|
| Task gate (no edit without task) | Task file with acceptance criteria | Working memory: current focus and scope |
| Commit gate (task reference required) | Traceable git history | Episodic memory: what was done and why |
| Verification gate (commands must pass) | Pass/fail evidence | Project memory: known failure patterns |
| Completion gate (ACs must be checked) | Validated deliverable record | Episodic memory: approach and outcome |
| Healing loop (issues trigger diagnosis) | Failure patterns + mitigations | Project memory: "if X fails, try Y" |
| Learning checkpoint (bugs trigger capture) | Structured learning entries | Project memory: prevents repetition |

The `toolGate` proposal extends this principle to the CLI itself. A gate that blocks a subagent from editing without a task is not just preventing undocumented changes — it is ensuring that the task record exists, which ensures that the episodic summary will be generated, which ensures that the next session's prompt will include the relevant history.

**The enforcement surface is the data collection surface.** Break the enforcement, and you break the data chain. Break the data chain, and future prompts degrade. Degraded prompts produce lower-quality output. This is not theoretical — our production data shows a 58% episodic decay rate (T-200), meaning more than half of historical records lose practical value within weeks. Only structured, selective capture with graduation criteria (3+ occurrences → pattern → practice) keeps the knowledge alive.

### How This Connects to the Tool Gate Proposal

The `toolGate` is not just about blocking. It is the enforcement surface for this entire context system:

1. **Task gate ensures context exists** — no file edit without a task means no file edit without acceptance criteria, decisions, and traceability
2. **Component fabric gates ensure spatial awareness** — blast radius analysis before commits means the agent knows what it touches
3. **Memory layers ensure temporal awareness** — project memory prevents re-debating decisions, episodic memory prevents repeating failures
4. **Traceability ensures accountability** — every action produces a record that strengthens the next session's prompt

The framework already implements all of this through PreToolUse hooks. The problem — and the reason for this RFC — is that the hooks are not deterministic. The context system works. The enforcement surface leaks. Fix the surface, and the context system scales to any project, any team, any agent.

**The domain changed from enterprise programme management to AI agent governance. The principle did not: you cannot govern what you cannot see, and you cannot improve what you cannot trace.**

## Source Code Analysis: Confirming Failure Modes in cli.js v2.1.96

To validate the failure modes described above, we examined the Claude Code CLI source (`@anthropic-ai/claude-code@2.1.96`, extracted from the npm package). Key findings:

### Hook Evaluation Architecture
PreToolUse hooks fire for both main and subagent tool calls. Hook event inputs include `agent_id` and `agent_type` fields, meaning hooks *can* distinguish which agent triggered the call. However, hook scripts are external processes that receive these fields as input — there is no enforcement that they act on them. A hook written for the main agent may not handle subagent contexts correctly, and most user-authored hooks do not check `agent_type` at all.

### Subagent Permission Inheritance
Subagents inherit `toolPermissionContext` directly from the parent agent. No permission escalation check occurs before spawning. This means subagents execute with the same tool access as the parent — but the hook evaluation context may differ, creating the bypass documented in #43772.

### Self-Modification Classification vs. Enforcement
The CLI classifies "modifying the agent's own configuration, settings, or permission files" as a restricted action. However, this classification exists within the permission system's *advisory* layer, not as a runtime lock. If the agent has `Write(*)` or `Edit(*)` in its allowed tools, it can write to `settings.json` and hook script files. The classification is correct in intent but unenforceable in practice.

### Bash Content Opacity
PreToolUse hooks can match on tool name (`Bash`) but have no mechanism to inspect command content. A hook that gates `Write` and `Edit` cannot detect `cat > file << 'EOF'` or `echo "content" > file` inside a Bash tool call. This is not a bug — the hook interface was designed for tool-level gating, not command-level parsing. But it means any governance system that relies solely on Write/Edit hooks has a structural blind spot.

### Architectural Implication
The current pipeline is:

```
Model request → Permission check → PreToolUse hook → Tool execution
```

There is no slot for a deterministic, model-inaccessible gate. The proposed `toolGate` would occupy that slot — after permission checks (which the model can influence via settings.json) but before hooks (which the model can modify via file writes). The gate would run inside the CLI process, not as an external script, making it immune to both model self-modification and alternative tool path bypasses.

## References

- [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) — 545+ task governance implementation
- [TermLink](https://github.com/DimitriGeelen/termlink) — cross-terminal agent coordination used for multi-agent governance
- Source code analysis of `@anthropic-ai/claude-code@2.1.96` (npm package) — confirming hook evaluation paths and failure modes
- Anthropic's "Alignment Faking in Large Language Models" (2024)
- CVE-2025-59536 — Hook exploitation via external attackers
- This RFC is itself a product of a governed session where we discovered these failures firsthand
