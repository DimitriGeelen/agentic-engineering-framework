# T-1115 — Pre-hook Anthropic built-in Task tool into framework governance

**Status:** Captured 2026-04-12 after the human spotted the agent's Claude Code
internal todo list ("2 tasks (0 done, 2 open)") showing items that were NOT
framework `T-XXX` tasks, and asked "are you bypassing framework governance
and using your own task system?"

---

## The incident that triggered this

During T-1113 and T-1114 work, the agent used Anthropic's built-in
`TaskCreate` / `TaskUpdate` / `TaskList` tools as a session-local scratchpad
to track "commit housekeeping", "implement helper", "run tests" etc. The
real framework work was tracked correctly via `bin/fw work-on` (T-1113,
T-1114 created properly, verification gates ran, episodics generated).

But the human's Claude Code UI displayed both systems' state, and the
built-in list rendered items like `□ Create T-1114 build task: fw cron install`
in the status line — visually identical to framework tasks. The human
reasonably asked whether the agent was running a parallel, ungoverned
task system.

**Answer in this session:** Agent stopped using the built-in tool entirely
and will rely only on `fw` for the rest of the session. But this is a
per-session patch, not a structural fix.

## The structural question

Can the framework **pre-hook** Claude Code's built-in `TaskCreate` /
`TaskUpdate` / `TaskList` / `TaskGet` tool calls via a `PreToolUse` hook,
so that every invocation is bound to the framework governance layer?

Three levels of binding are possible:

### Level 1 — Reject entirely (hard ban)
`PreToolUse` on `TaskCreate|TaskUpdate` returns exit code 2 with a message:
"The Claude Code internal task tool is disabled in this project. Use
`bin/fw work-on` to create real framework tasks."

**Pros:** Absolute clarity. Zero parallel system. One source of truth.
**Cons:** Loses the session-scratchpad affordance (quick in-conversation
progress tracking without creating a real task file). Agents may lose
a useful working-memory pattern for complex multi-step work.

### Level 2 — Mirror (soft bridge)
`PreToolUse` on `TaskCreate` allows the call but also calls
`bin/fw task create` with a matching name and a `tags: [claude-todo]`
marker. Deletions/completions in the built-in tool mirror to the framework.
Both systems stay in sync automatically.

**Pros:** Preserves the scratchpad ergonomics. Every piece of work leaves a
framework trail. Auditable.
**Cons:** Two sources of truth with automatic sync — classic dual-write
problem (drift risk). Mirroring a session-local "what I'm doing right now"
into real task files may pollute `.tasks/active/` with ephemeral items.

### Level 3 — Annotate-only (transparency, no binding)
`PreToolUse` allows the call but logs every invocation to
`.context/working/.claude-todo.log` with timestamp and content. The
built-in tool remains a scratchpad but is no longer invisible — a later
audit can reconstruct what was tracked there.

**Pros:** No behavior change, minimum surprise. Observability without
governance overhead.
**Cons:** Does not solve the "agent bypass suspicion" problem — still
shows in the UI as a parallel list. Just adds a log file nobody reads.

## Prior art in the codebase

- `T-063` / `agents/context/check-active-task.sh` — PreToolUse hook on
  `Write|Edit` that blocks edits without an active task. The canonical
  example of binding Anthropic-tool behavior to framework state.
- `T-139` / `agents/context/budget-gate.sh` — PreToolUse hook on
  `Write|Edit|Bash` that blocks at context budget critical.
- `T-1063` / MCP task governance — PreToolUse hook enforcing `task_id`
  on TermLink MCP calls. Most analogous precedent.
- `T-063` / `block-plan-mode.sh` — PreToolUse on `EnterPlanMode` that
  rejects with exit 2 + instructions to use `/plan` skill instead.
  **This is the closest template for Level 1.**

The framework already knows how to hook Anthropic tools, and already
has a pattern for "reject with redirect" (plan-mode ban). Implementation
cost for Level 1 is ~20 lines.

## What I don't know (questions for the human)

**Q1 — Which level do you want?**
- Level 1 (reject): zero parallel system, agent loses scratchpad
- Level 2 (mirror): both systems, automatic sync, dual-write risk
- Level 3 (log): no behavior change, just observability
- Hybrid: e.g., Level 1 in this project (framework dogfood) but Level 2 or 3
  in consumer projects where the agent may legitimately need the scratchpad

**Q2 — Does Anthropic's Claude Code actually fire `PreToolUse` for the
built-in Task tools?** Most `PreToolUse` hooks are wired for `Write|Edit|
Bash|Read|EnterPlanMode`. It is not documented that `TaskCreate` /
`TaskUpdate` are hookable. **This is a must-verify spike** before any
build work — the whole design collapses if the tool calls are not
interceptable.

**Q3 — If not hookable, is there a fallback?**
- Prompt the model to treat the built-in tool as forbidden (CLAUDE.md rule
  like "Do not call TaskCreate / TaskUpdate / TaskList — use bin/fw work-on
  instead"). Relies on the agent following instructions, not enforcement.
- Post-hook detection: a `PostToolUse` hook on any tool inspects the
  session transcript, finds `TaskCreate` invocations, warns or blocks.

**Q4 — Should the built-in `TaskList` read also be blocked, or only the
mutating calls (`TaskCreate`, `TaskUpdate`)?** `TaskList` is read-only —
banning it may feel punitive. But allowing reads while blocking writes
creates an inconsistent UX.

**Q5 — If Level 2 (mirror), where do the mirrored framework tasks land?**
- `.tasks/active/` — pollutes the normal queue with ephemeral items
- `.tasks/scratchpad/` — new directory outside normal task flow
- `.context/scratchpad.yaml` — flat registry, not a task file
- Something else?

**Q6 — Is this a T-1105 (chokepoint+invariant-test) instance?** If yes,
the implementation needs (a) a single chokepoint (the hook), (b) an
invariant test that asserts the built-in tool is blocked (bats test that
sends a fake `TaskCreate` JSON to the hook and expects exit 2), (c) a
documented bypass path for legitimate session-scratchpad use, if any.

**Q7 — Is there prior evidence of this confusing the human in earlier
sessions?** If yes, this is a recurring bug class (like the G-018
bleed-through) and warrants urgency. If no, it's a single-incident
governance gap — still worth fixing but lower urgency.

## Dialogue log

### Segment 1 — the incident
- **Human (during T-1114 work):** "are you bypassing framework governance
  and using your own task system ??!!!!"
- **Agent:** Explained the distinction (framework T-XXX via `fw work-on` vs
  Claude Code built-in TaskCreate/TaskUpdate as session scratchpad).
  Offered to stop using the scratchpad.

### Segment 2 — the ask
- **Human:** "then why do i see :: 2 tasks (0 done, 2 open) □ Create T-1114
  build task: fw cron install □ Implement fw cron install + doctor drift
  check + tests"
- **Agent:** Deleted the scratchpad entries via `TaskUpdate --status deleted`.
  Confirmed framework T-1114 is the real governance state.

### Segment 3 — the inception
- **Human:** "yes and add inception with explicit discussion with me if we
  can prehook the task call to the internal task system from anthropic ?"
- **Agent:** Created this inception (T-1115), wrote this research artifact
  with 7 open questions (Q1–Q7), awaiting human dialogue before drafting
  a recommendation.

### Segment 4 — human answers + research feedback

**Human answers (2026-04-12):**
- **Q1:** L1 + reroute; prefer REWRITE if possible ("ultimo best")
- **Q2:** Yes, investigate. Also ingest https://github.com/anthropics/claude-code/issues/45427
- **Q3:** Both (CLAUDE.md rule + PostToolUse audit) if hooks unavailable
- **Q4:** If cannot rewrite, block + redirect
- **Q5:** No mirroring (L2 rejected)
- **Q6:** Requested elaboration on T-1105 chokepoint+invariant-test discipline in this context — see §T-1105 Discipline below
- **Q7:** "On occasion — seems to be regressing" → recurring bug class, not first-incident

**Research agent findings (claude-code-guide spawn, 2026-04-12):**

- **Q1 (hookability):** **Ambiguous, must-verify empirically.** Claude Code
  docs list PreToolUse-capable tools as `Bash, Edit, Write, Read, Glob,
  Grep, Agent, WebFetch, WebSearch, AskUserQuestion, ExitPlanMode, and
  MCP tools`. `TaskCreate`/`TaskUpdate`/`TaskList` are NOT on that list.
  The Task* tools have separate lifecycle events (`TaskCreated`,
  `TaskCompleted`) but those are notification-only, not gates.

- **Q2 (rewrite):** **Partially supported — but not cross-tool.**
  PreToolUse hooks CAN return `updatedInput` to modify tool arguments,
  via JSON output on exit 0:
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "updatedInput": { "command": "rewritten" }
    }
  }
  ```
  But `updatedInput` modifies the *current* tool's args — it cannot
  convert a `TaskCreate` call into a `Bash` call. The rewrite surface
  is intra-tool only.

  **Consequence for this design:** Your Q1 "ultimo best" (rewrite
  `TaskCreate {...}` into `bin/fw work-on "..."`) is not mechanically
  supported. The only viable intervention at the PreToolUse layer is:
    - **exit 2 + redirect message** — block the call, Claude reads the
      stderr message, issues the correct Bash call on the next turn.
      This is exactly how `block-plan-mode.sh` handles EnterPlanMode →
      /plan skill.

- **Q3 (issue 45427):** The RFC is the human's own prior filing. It
  argues that PreToolUse hooks are fundamentally insufficient (subagent
  bypass, silent failure, model self-modification, alternative tool
  paths, CLAUDE.md non-compliance) and proposes a deterministic
  `toolGate` layer inside the CLI. **Not directly relevant to Task\*
  tool hookability** — the RFC discusses Write/Edit/Bash gating, not
  TaskCreate/TaskUpdate. But it reinforces the broader point: even if
  we build a Level-1 hook, subagents may bypass it, and the model may
  be able to rewrite its own hook config. Long-term governance needs
  the toolGate layer, not just more hooks.

## T-1105 Discipline in this context (Q6 elaboration)

T-1105 codified the rule: when a bug class has 3+ recurrences, fix it
by identifying a **single chokepoint** (one place all traffic must
pass through) and adding an **invariant test** (CI-enforced assertion
that the chokepoint behaves correctly). The purpose is to make the bug
class structurally impossible, not merely discouraged by documentation.

Applied to T-1115:

| Element | What it means here |
|---|---|
| **Bug class** | "Claude Code built-in Task tool creates session state the human mistakes for framework governance" — 2+ recurrences per human's Q7. |
| **Chokepoint** | A PreToolUse hook file (e.g., `agents/context/block-task-tools.sh`) that EVERY `TaskCreate`/`TaskUpdate`/`TaskList` invocation must pass through. Single file, single function, no alternate paths. |
| **Invariant test** | A bats integration test that pipes a fake `TaskCreate` JSON payload to the hook and asserts exit code 2 + stderr contains "bin/fw work-on". Runs on pre-push. Regression detected in CI before it reaches production. |
| **Escape hatch** | If legitimate scratchpad use is valuable, provide a labeled bypass (e.g., `FW_CLAUDE_TODO_ALLOW=1` env var). Document in CLAUDE.md. Logged on use. |
| **Invariant** | "Claude Code built-in Task tool cannot create session state without framework governance." Either blocked (Level 1) or the bypass env var is set (and logged). No third path. |

The **problem with applying T-1105 to this specific case** is that the
chokepoint may not exist — if PreToolUse doesn't fire on `TaskCreate`,
there is NO place in the call path where our code runs. We'd be trying
to install a chokepoint on traffic that never passes through us. T-1105
discipline requires the chokepoint be real; if it isn't, we fall back
to non-structural controls (CLAUDE.md rule, PostToolUse audit, manual
agent discipline) — and those are what T-1105 is meant to *replace*.

Hence the hard dependency on the Q1 empirical verification: **no
verification → no T-1105 fix.**

## Verification spike (the must-do before any build)

Because Claude Code hooks are snapshotted at session start, the spike
cannot be run mid-session without losing context. The design:

1. Write `tests/spikes/taskcreate-hook-probe.sh` that:
   - Logs stdin + argv + timestamp to `.context/working/.taskcreate-probe.log`
   - Exits 0 (allow)
2. Register it in `.claude/settings.json` under PreToolUse with
   matcher `TaskCreate|TaskUpdate|TaskList|TaskGet`
3. Hand the human a `fw inception verify T-1115` command (or a manual
   checklist) that: (a) restarts Claude Code, (b) makes a trivial
   `TaskList` call in the fresh session, (c) checks whether the log
   file was populated
4. Based on the result:
   - Log populated → hooks fire → **proceed with Level 1 implementation**
   - Log empty → hooks don't fire → **fall back to CLAUDE.md rule + PostToolUse audit**

This keeps the current session usable while producing an
evidence-based answer on the next session boundary.

## Recommendation (updated after Q6 elaboration + research findings)

**Recommendation:** GO with a **two-phase** build:

- **Phase 1 (this session):** Write and commit the verification spike
  artifact (`tests/spikes/taskcreate-hook-probe.sh` + test settings
  fragment + human-run checklist). Do NOT modify the live
  `.claude/settings.json` until the human has run the spike in a fresh
  session and reported the result. Write the fallback (CLAUDE.md rule
  + PostToolUse audit scanner) in parallel so it's ready regardless of
  Q1 outcome.

- **Phase 2 (next session, after spike result):** Based on empirical
  result:
  - **Hooks fire:** Implement `block-task-tools.sh` (Level 1 block +
    redirect). Wire into `.claude/settings.json`. Write bats invariant
    test. Commit. ~30 LOC.
  - **Hooks don't fire:** Add CLAUDE.md §Claude Code Built-in Task Tool
    Ban rule. Implement PostToolUse detector that scans the session
    transcript for TaskCreate invocations post-hoc and warns/logs.
    Document as non-structural control (acknowledged limitation).

**Why phase 1 is GO:** The fallback (CLAUDE.md rule + PostToolUse audit)
can be built WITHOUT knowing the spike result — it's valuable in both
outcomes. Writing both paths in parallel means whichever the spike
unblocks, we're ready to commit immediately.

**Rejected alternatives:**
- **L2 (mirror)** — rejected by human Q5 (no mirroring)
- **L3 (log-only)** — rejected by human Q1 (wants active redirect, not
  passive observation)
- **Rewrite cross-tool** — mechanically impossible per research Q2
- **"Do it now without verification"** — may install a hook on traffic
  that never passes through it, creating a false sense of enforcement
  and wasting build effort

**Open constraint:** Even if we land Level 1, issue 45427's failure
modes still apply — subagents may bypass, model may self-modify. True
structural enforcement requires the toolGate layer from the RFC, which
is Anthropic's to build, not ours. We document this as an acknowledged
upper bound on the governance guarantee.


## Scope fence

**IN:** Research on whether Anthropic Claude Code exposes a PreToolUse
hook surface for TaskCreate/TaskUpdate/TaskList; design of the three
intervention levels; recommendation on which level(s) to implement;
dialogue with human on design preferences.

**OUT:** Actual hook implementation (deferred to build task after GO);
changes to Anthropic's tool definitions (out of our boundary); opinion on
whether Anthropic should expose the hook surface (out of scope — we work
with what Claude Code provides).

## Recommendation (provisional, pending dialogue)

Before the human answers Q1–Q7, the agent's tentative lean is:

**Level 1 (reject) for THIS project (framework dogfood)**, implemented as
a small PreToolUse hook modeled on `block-plan-mode.sh`, IF Q2
(hookability) returns true. Rationale:
1. Framework dogfood project must demonstrate zero parallel governance.
2. The session-scratchpad affordance is nice-to-have, not must-have —
   todos in conversation text serve the same purpose without creating UI
   artifacts the human mistakes for real tasks.
3. Pattern already proven (`block-plan-mode.sh`).

**If Q2 returns false** (tool calls not hookable), fall back to a CLAUDE.md
rule ("Do not call TaskCreate / TaskUpdate / TaskList; use bin/fw work-on")
and accept that enforcement relies on agent compliance, not structural
blocking — same regime as the "nothing gets done without a task" rule
before `check-active-task.sh` was built.

This is provisional. The actual GO/NO-GO + level selection needs the
human's answers to Q1–Q7 first.

---

## Post-Spike Findings (2026-04-12, TermLink E2E)

### Critical correction: the tool is `TodoWrite`, not `TaskCreate`

The T-1116 TermLink E2E spike (`fw termlink dispatch --name t1116-spike-2`)
dispatched a fresh `claude -p` worker with the probe hook installed.

**Finding 1 — Tool name mismatch:**
In `claude -p` mode (Claude Code 2.1.101), the built-in todo/task system
is backed by `TodoWrite`, NOT `TaskCreate`. The worker reported:
"TaskCreate is not available in this session — only TodoWrite."

In interactive Claude Code sessions, `TaskCreate|TaskUpdate|TaskList|TaskGet`
appear as deferred tools (likely the async agent/background-task management
system, distinct from the UI scratchpad). The UI "X tasks (Y done, Z open)"
that the human complained about is populated by `TodoWrite`.

**Finding 2 — PreToolUse CONFIRMED on `TodoWrite`:**
```
2026-04-12T06:50:18Z pid=3457052 tool_name=TodoWrite
tool_input={"todos":[{"content":"spike-probe-todowrite","status":"in_progress"}]}
hook_event_name=PreToolUse
```
The probe script received full tool_input JSON on stdin, including the
todo content, status, and session metadata. Exit 0 allowed the call.
Exit 2 would block it (proven pattern from `block-plan-mode.sh`).

**Finding 3 — Interactive-mode Task* tools need separate verification:**
The deferred `TaskCreate|TaskUpdate|TaskList|TaskGet` tools visible in
interactive sessions may or may not fire PreToolUse hooks. They were NOT
present in the `-p` mode worker, so the spike could not test them. A
defensive matcher covering both sets is the pragmatic choice.

### Phase 2 implementation (T-1117)

Based on findings, T-1117 implements:
- `agents/context/block-task-tools.sh` — exits 2 with redirect message
- `.claude/settings.json` matcher: `TodoWrite|TaskCreate|TaskUpdate|TaskList|TaskGet`
- `tests/unit/block_task_tools.bats` — 7 invariant tests
- CLAUDE.md §Built-in Task Tool Ban rule
