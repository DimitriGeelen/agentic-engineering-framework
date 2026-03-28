# T-635: Deterministic Human-Facing Action Routing

## The Problem

The framework has three great tools for presenting human-facing actions:
1. `fw task review` — QR code + clickable Watchtower link + research artifacts
2. Watchtower `/approvals` — Tier 0 approval queue with approve/reject buttons
3. `emit_review()` auto-fire — triggers on partial-complete and inception decide

But the agent keeps bypassing all three by pasting raw commands as text. Evidence from the current session alone:

| When | What agent did | What agent should have done |
|------|---------------|----------------------------|
| GO decisions (T-625/629/630) | Pasted `fw tier0 approve && fw inception decide...` | Run `fw inception decide` → get blocked → point to Watchtower `/approvals` |
| Human AC review | Showed `fw task show` output | Run `fw task review` |
| Earlier: T-633 review | Gave raw URL | Run `fw task review T-633` |

This is the same pattern that T-372 (blind task-completion) and T-325 (human AC handoffs) tried to fix — but those were behavioral rules. The agent reverts within minutes.

## Root Cause Analysis

### Why behavioral rules fail

1. **Agent context pressure** — Under budget pressure or mid-flow, the agent optimizes for "get the human unblocked fast" by pasting commands directly
2. **No structural feedback** — Nothing blocks or warns the agent when it presents raw commands instead of using the standard flow
3. **Workflow shortcutting** — The agent knows the command and the result, so it skips the intermediate step (running the command itself, getting blocked, routing through Watchtower)
4. **Skill amnesia** — `/review` skill exists but the agent doesn't invoke it because it's not in the hot path

### The four-layer gap

| Layer | Human AC Review | GO Decisions | Tier 0 Approval |
|-------|----------------|-------------|-----------------|
| CLI | emit_review auto-fires on update-task | emit_review auto-fires on inception decide | check-tier0.sh just prints "BLOCKED" |
| Command | lib/review.sh | lib/review.sh | No Watchtower link emitted |
| Skill | /review exists, rarely invoked | No /go-decision skill | No skill |
| Agent | Pastes raw commands | Pastes raw commands | Pastes raw commands |

## Spike 1: What hooks fire when the agent presents human actions?

The key moments when the agent presents human-facing actions:

1. **Tier 0 block** — `check-tier0.sh` PreToolUse hook fires, writes to `.context/approvals/`, prints error. This is the ONLY structural enforcement point.
2. **Partial-complete** — `update-task.sh` runs, detects human ACs, calls `emit_review()`. Structural.
3. **Inception decide** — `inception.sh` runs, calls `emit_review()`. Structural.
4. **Agent text output** — Agent writes a message with raw commands. NO hook fires. Zero enforcement.

**Finding:** Moments 1-3 are structurally enforced but only fire when the agent RUNS the command. The agent bypasses by not running the command and presenting raw text instead.

## Spike 2: Can we detect raw command presentation?

Claude Code hooks fire on tool calls, not on text output. There is no `PreTextOutput` hook. So we cannot structurally block the agent from pasting raw commands.

However:
- **PostToolUse hooks** fire after every tool call. A PostToolUse hook could check if the agent's recent output contains patterns like `fw tier0 approve` or `fw inception decide` as raw text.
- But PostToolUse hooks are advisory (exit code ignored) — they can warn but not block.

**Finding:** We cannot structurally prevent the agent from pasting raw commands. We can only make the correct path the path of least resistance.

## Spike 3: Make check-tier0.sh emit Watchtower link

When `check-tier0.sh` blocks a command:
- Currently: prints "BLOCKED" + raw `fw tier0 approve` command
- Proposed: prints "BLOCKED" + Watchtower approval link + QR code

This way, even when the agent is blocked, the OUTPUT already contains the Watchtower link. The agent doesn't need to remember — the hook does it.

**Feasibility:** High. `check-tier0.sh` already sources `lib/paths.sh`. Adding Watchtower URL detection and emitting the link is ~10 lines.

## Spike 4: Workflow skills that encapsulate the correct flow

Create skills that make the correct path easier than the wrong path:

- `/go-decision T-XXX` — Runs `fw inception decide`, handles tier0 block, shows Watchtower link
- `/review` (exists) — Shows all pending human ACs with QR + links
- `/approve` — Shows Watchtower approval queue link

The agent invokes the skill instead of composing the flow manually. The skill encapsulates the correct routing.

**Feasibility:** High. Skills are markdown files in `.claude/commands/`.

## Spike 5: CLAUDE.md rule + agent self-check

Add to CLAUDE.md:
> When presenting any action requiring human approval (Tier 0, GO decisions, Human AC review): NEVER paste raw commands. Instead, trigger the workflow (fw inception decide, fw task update) and let the framework emit the standard review. If the command gets Tier 0 blocked, point the human to Watchtower /approvals.

This is behavioral (least reliable) but combined with the structural fixes above, it closes the gap.

## Recommendation

**GO** — Three build deliverables:

1. **`check-tier0.sh` enhancement** — On block, emit Watchtower approval link using `lib/review.sh` URL detection. ~10 lines of code.
2. **`/go-decision` skill** — Encapsulates inception decide flow. Agent invokes skill, skill runs command, handles block, shows Watchtower link.
3. **CLAUDE.md rule** — "Never present raw tier0/inception commands. Use `/go-decision` or let the CLI auto-emit." (Behavioral backup only.)

This closes the loop: CLI auto-emits on success, hook auto-emits on block, skill encapsulates the correct flow, rule is behavioral backup.
