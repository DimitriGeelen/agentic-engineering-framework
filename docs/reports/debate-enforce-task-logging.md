# Debate: Should We Enforce Richer Task-File Logging?

**Position:** FOR enforcement
**Date:** 2026-02-17
**Evidence base:** 109 completed tasks, episodic accuracy audit, healing agent source analysis

---

## The Case for Enforcement

### 1. What the Task File Captures That Git Cannot

A git commit records *what changed* in code. A task file records *why it changed, what else was considered, and what failed before the thing that worked.* These are categorically different kinds of knowledge.

Consider T-078 (checkpoint blind spot fix). The task file — had it been logged during execution — would have captured: the diagnosis of four independent bugs, the decision to remove caching rather than add a session-aware cache key, the discovery that synthetic model entries were poisoning token counts, and the reasoning for choosing a 2MB read window over 1MB. The git diff shows 59 lines added to checkpoint.sh. It does not show that two alternative caching strategies were rejected, or why. The enriched episodic for T-078 contains this information only because an LLM reconstructed it after the fact from git diffs and commit messages — a lossy, error-prone process that the 16% episodic inaccuracy rate confirms.

Dead ends, rejected alternatives, and design rationale have no natural home in git. A commit message for a rejected approach is never written. The decision *not* to do something leaves no trace in any diff. Task-file logging is the only mechanism in the framework where an agent can say: "I tried X, it failed because Y, so I chose Z instead." This is the epistemic dark matter of software engineering — invisible in the artifact but critical for understanding it.

### 2. Downstream Systems Depend on Task Content

The framework's downstream consumers — episodic generation, healing diagnosis, handover, and audit — all read the task file's Updates section as their primary input.

**Episodic generator** (`agents/context/lib/episodic.sh`): Lines 36-53 parse the Updates section to extract timeline events, identify challenges (via keyword grep for "issue", "error", "fail"), and count update entries. When 58% of tasks have only 2 entries (created + completed), the generator produces a skeleton with nothing but `[TODO]` placeholders. The enrichment step then requires an LLM to reconstruct the journey from git commits — adding latency, cost, and inaccuracy.

**Healing agent** (`agents/healing/lib/diagnose.sh`): Lines 160-169 extract the "latest update" from the Updates section and feed it to the failure classifier. If the update section contains only "status: started-work -> work-completed," the classifier receives no signal. It classifies the failure as "unknown" and produces generic suggestions. The healing loop — the framework's core antifragility mechanism — is deaf when task files are empty.

**Handover agent**: Synthesizes session state from task files. An empty Updates section means the handover cannot describe what was attempted, only that a task exists. The next session starts blind.

**Audit agent**: Cannot distinguish between "task completed with thorough process" and "task completed with no process" when both have identical 2-entry Updates sections.

### 3. Autonomous Mode Makes This Non-Negotiable

When a human supervises, the conversation transcript serves as an informal log — the human can remember context, catch mistakes, redirect. In autonomous mode, no such safety net exists. An autonomous agent that encounters an error, tries three approaches, and succeeds on the fourth leaves no trace of the first three attempts unless it logs them. If the session compacts (as happened at 177K tokens in T-078's session), even the conversation transcript is destroyed. The task file on disk is the only durable record of agent reasoning during autonomous execution.

### 4. The Analogy to Professional Logbooks

Engineering logbooks, medical records, and scientific notebooks share a common principle: *the record is not optional because the record is the proof that the process occurred.* An engineer's notebook is legally admissible evidence of invention. A medical chart is the proof that standard of care was followed. A scientific notebook is the proof that an experiment was actually run. These professions enforce logging not because practitioners enjoy paperwork, but because the absence of a record is indistinguishable from the absence of the work.

In the framework's terms: a task file with 2 entries is indistinguishable from a task where the agent did nothing between creation and completion. The framework cannot learn from what it cannot observe.

### 5. Cost and Implementation

**Cost:** Each logged entry is approximately 3-5 lines of markdown. At 3-4 entries per task, this adds roughly 100-200 tokens of write operations per task — negligible against the 200K context budget.

**Implementation:** A PostToolUse hook on `fw task update --status work-completed` that checks `updates_count >= 3` (created + at least one work entry + completed). Reject completion if updates are insufficient, with a bypass via `--force` for Tier 2 situations. Alternatively, a softer gate: the episodic generator refuses to mark enrichment as "complete" unless the source task had substantive updates, forcing the enrichment agent to flag the gap.

**Failure modes:** The primary risk is *compliance theater* — agents writing formulaic entries ("Implemented feature. Tests pass.") that satisfy the count check but carry no information. This is mitigated by the episodic enrichment step, which must extract decisions, challenges, and successes from the updates. Formulaic entries produce formulaic episodics, which fail the existing quality audit. The quality pressure propagates backward.

---

## Steelman: Accept Git as the Log

The strongest counter-argument: git commits already exist, are immutable, and are written as a natural byproduct of work. Requiring task-file logging adds friction without adding information — just move the information extraction to the episodic enrichment step, where an LLM can reconstruct the narrative from diffs and commit messages. This is cheaper in agent attention, eliminates the compliance theater risk, and requires zero new enforcement machinery.

## Why Enforcement Is Still Better

The counter-argument assumes that git commits contain enough signal to reconstruct reasoning. They do not. Commits record outcomes; task files record process. A commit that adds retry logic does not explain that three other error-handling strategies were evaluated and rejected. A commit that refactors a function does not record that the refactoring was triggered by a design insight during debugging. The 16% episodic inaccuracy rate is direct evidence that git-based reconstruction is lossy. Enforcement costs ~150 tokens per task. Inaccurate episodics cost every future session that consults them — a compounding debt that grows with every completed task. The framework's constitutional directive of antifragility requires that failures become learning events; learning requires observation; observation requires logging. Enforcement closes the loop.
