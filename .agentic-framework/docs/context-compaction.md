# Context Compaction and Recovery

What `/compact` actually does, why the framework disables auto-compaction, and
why you must run `/resume` afterward — not just read the auto-injected note.

## The one thing to remember

**After `/compact`, run `/resume` (or `fw resume status`). Do not rely on the
"Post-Compaction Context Recovery (automatic)" banner alone.**

That banner looks like a completed recovery. It is not. Claude Code's harness
caps how much a hook can inject directly into the model's context — anything
over the cap is written to a side file and only a small preview is delivered
inline. Measured on real sessions in this project: the recovery hook
(`post-compact-resume.sh`) generates **31–51KB** of recovery context, but only
the **first ~2KB (roughly 4–7% of it)** actually lands in the model's context
window. The rest sits in a `tool-results/hook-*-additionalContext.txt` file
that nothing reads unless you go looking for it.

So the automatic step is a pointer, not a recovery. It tells you *that*
something happened and gives you a fragment — not the full state. `/resume`
(and its CLI equivalents, `fw resume status` / `fw resume sync`) reconstruct
state from ground truth on disk instead: `.context/handovers/LATEST.md`,
`focus.yaml`, git log, and the task files. That is complete; the auto-injected
preview is not.

This is a measured fact, not a caveat — see "How we know" below if you want to
reproduce it yourself.

## What compaction is here

`/compact` asks Claude Code to summarize and discard older conversation turns
to free up context window. In most Claude Code projects this can also happen
automatically. **In this framework, automatic compaction is disabled by
design (D-027)** — compaction destroys working memory, and letting the harness
trigger it unattended risks losing state mid-task with no chance to capture it
first. Compaction here only happens when you type `/compact` yourself.

That trade means the framework has to work harder around the moments *before*
and *after* a manual compact, which is what the rest of this document covers.

## What happens when you run `/compact`

**Before the cut — the PreCompact hook.** `agents/context/pre-compact.sh` runs
automatically and, before any context is discarded:

1. Generates a full handover (`agents/handover/handover.sh --commit`) and
   commits it — so the state of your session is captured on disk, not just in
   the soon-to-be-summarized conversation.
2. Resets the budget-gate cache (`.budget-status`, `.budget-gate-counter`) so
   the fresh session doesn't inherit a stale "critical" reading from before
   the compact.
3. De-duplicates against a second hook firing for the same `/compact` (some
   Claude Code configurations register the hook at both project and user
   level) via a lockfile + a 30-second time window.

If the handover generation fails, that failure is logged honestly to
`.context/working/.compact-log` (not silently swallowed) — check that file if
you suspect a compact didn't actually capture your state.

**Practical implication:** you can run `/compact` with confidence. Your task
files, decisions, and progress are committed to disk *before* the window is
cut, regardless of what happens to the conversation transcript.

**After the cut — SessionStart:compact.** The fresh session fires
`agents/context/post-compact-resume.sh`, which:

- Clears session-scoped volatile state (tool counters, loop-detection cache,
  approval-notification cache) so nothing stale carries over.
- Seeds `.budget-status` back to `{ok, 0, now}` and records a session-start
  timestamp, so budget calculations don't pick up pre-compact usage entries
  from the same underlying transcript file.
- Builds the recovery context described above: handover excerpt (Where We Are
  / Work in Progress / Suggested Action / Gotchas), current task focus,
  current arc focus, active-task summary, git state, a fabric topology
  overview, and any WARN/FAIL discoveries — and emits it as
  `additionalContext` on the `SessionStart` hook output.

This is the payload that gets truncated to ~2KB on the way into your context
(see above). It's genuinely useful as a first orientation — just don't
mistake it for the whole recovery.

## What to do — and when

| Situation | Action |
|-----------|--------|
| You just ran `/compact` | Run `/resume` (or `fw resume status`) before starting new work. Don't act on the auto-injected banner alone. |
| Session auto-restarted (budget-critical auto-restart loop) | Same as above — `claude -c` re-injects via the same truncated path. |
| You're not sure what's stale after a compact | `fw resume sync` reconciles working memory (`focus.yaml`, task status) against what's actually on disk. |
| You just want a one-line gut check | `fw resume quick` |

`fw resume status` gives the full synthesis: handover + working memory + git
log + task list — read from disk, not from a 2KB fragment of it.

## The budget ladder

The budget gate watches token usage against `FW_CONTEXT_WINDOW` (default
300,000) and moves through four levels, read directly from
`agents/context/budget-gate.sh` (do not trust a paraphrase — thresholds can be
tuned via config):

| Level | Threshold (default window) | What fires | What you can still do |
|-------|-----------------------------|------------|------------------------|
| `ok` | below 75% (< 225,000 tokens) | nothing | Anything. |
| `warn` | ≥ 75% (225,000 tokens) | A one-line note on the next tool call | Anything — just commit before starting new work. |
| `urgent` | ≥ 85% (255,000 tokens) | A short warning | Anything, but don't start new implementation work — commit and prepare a handover. |
| `critical` | ≥ 95% (285,000 tokens) | Tool calls are **blocked** (exit 2) except an allowlist (git commit/add/push/fetch/status/log/diff, `fw handover`/`git`/`context init or focus`/`resume`/`task`, and Write/Edit under `.context/`, `.tasks/`, `.claude/`) | Wrap-up only: commit, then `fw handover`. |

`agents/context/checkpoint.sh` runs the same three thresholds as a
PostToolUse fallback (in case the PreToolUse gate's cached status is stale),
and additionally auto-triggers a handover + writes a restart signal at
critical, so an unattended session running under `claude-fw` can recover
without a human present.

Both the gate and the checkpoint use the *same* `TOKEN_WARN` /
`TOKEN_URGENT` / `TOKEN_CRITICAL` formulas (75% / 85% / 95% of
`FW_CONTEXT_WINDOW`) — they're two independent readers of the same policy,
not two different policies. If you need to change a threshold, it's a
separate, deliberate change to those scripts — this document only explains
what today's numbers mean.

## How to check current usage

```bash
cd /opt/999-Agentic-Engineering-Framework && bin/fw resume quick
cd /opt/999-Agentic-Engineering-Framework && bash agents/context/checkpoint.sh status
cat /opt/999-Agentic-Engineering-Framework/.context/working/.budget-status
```

`checkpoint.sh status` re-reads the live session transcript for an exact
token count; `.budget-status` is the cached value the hooks use for fast
decisions (refreshed roughly every 5th tool call, or when stale).

## How we know (the truncation measurement)

Claim: the SessionStart:compact hook generates tens of KB of recovery context,
but only a small preview reaches the model.

Verified directly against this project's own session transcripts
(`~/.claude/projects/-opt-999-Agentic-Engineering-Framework/*.jsonl`):

- Files named `tool-results/hook-*-additionalContext.txt` (what the hook
  actually wrote) ranged **31KB–51KB** across 146 samples.
- The transcript records two separate entries for the same hook firing: a
  `hook_success` attachment carrying the **full** stdout (53,335 bytes
  observed in one sample), and a separate `hook_additional_context`
  attachment — the thing actually delivered as context — literally wrapped in
  `Output too large (49.2KB)... Preview (first 2KB):`.
- Measuring that second attachment's `content` field directly across ~140
  occurrences in this project's transcripts: consistently **2.0–2.3KB**,
  regardless of how large the full payload was. That's roughly **4–7% of the
  full recovery payload** landing in the model's context — the other 93–96%
  is discarded from the agent's view unless something explicitly reads the
  side file.

This truncation behavior is a property of the Claude Code harness, not of
this framework's hook code — the hook does its job (it does generate the full
context); the delivery channel is what's capped. Fixing that gap is out of
scope for this document; the point here is to make sure you know it's
happening and to route you to `/resume`, which reads the same source files
directly instead of depending on the truncated preview.

## See also

- `CLAUDE.md` → "Trunk-Based Session Flow" and the "Manual compaction"
  paragraph under Session Start Protocol
- `/resume` skill (`agents/resume/`)
- `agents/context/budget-gate.sh`, `agents/context/checkpoint.sh` — source of
  truth for thresholds
- `agents/context/pre-compact.sh`, `agents/context/post-compact-resume.sh` —
  the two hooks this document describes
