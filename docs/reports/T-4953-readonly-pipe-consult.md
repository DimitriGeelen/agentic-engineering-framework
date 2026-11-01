# T-4953 — read-only pipes at the Tier 0 gate: external consultation

**Date:** 2026-11-01
**Asked by:** the operator ("Ik suggest een korte externe consultatie").
**Seats:** codex (OpenAI, `consult-t4953-codex-24858c766e0e`) and opencode (Z.ai, `consult-t4953-opencode-098b6bf8c090`). Both are internal-cost subscriptions; cost is logged in `.context/costs/reviews.jsonl`. They ran as review dispatches, read-only, with no tools.
**Brief:** the same text to both. It names no host and does not spell the gate keyword. It covers the system, the field report (dimitri-mint-dev be.3, msg 9f92d563), the three options and three questions.

## The options put to them

1. Keep refusing, but write no approval card for a plain read-only gate query followed by a pipe; the refusal tells the agent to re-run without the pipe.
2. Allow the plain read-only forms followed by one pipe into `grep`, `head`, `tail` or `wc`.
3. Keep block and card; reword the card.

## Answers

### codex

- **Recommends option 1.** Keep an audit record even when no card is written. Suppress the card only for a narrowly parsed shape; everything else is handled as today. Option 3 keeps the fatigue; option 2 adds parsing complexity for a convenience.
- **Option 2 risks:**
  - file operands read repository files or secrets (`grep -f FILE` is a content oracle);
  - `tail -f`, FIFOs and costly regexes hang the session;
  - a trailing `&`, newlines and other operators must all be excluded;
  - PATH or shell functions can make `grep` something else, which the text cannot show;
  - the output can carry terminal controls or prompt injection.
- **Correction:** `--pre` belongs to ripgrep, not GNU grep. A safe *syntactic* grammar exists: fixed executables, stdin only, enumerated options, bounded numbers. It cannot prove runtime safety from text alone.
- **Option 1 residual risk:** suppression loses *visibility*, not the block, as long as the refusal stays unconditional. A loose classifier could hide a disguised attack's card. So keep suppressed refusals auditable, track repeats, never call them verified harmless, and fail closed when classification fails.

### opencode

- **Recommends option 1,** with an immutable audit log. It changes alerting, not the execution decision: the worst case is a missed signal, never a missed block. Fewer cards make the remaining (destructive) ones count. Option 3 does not reduce the count. Option 2 executes a new class of commands unseen and restarts the per-binary allowlist treadmill.
- **Option 2 bypasses:**
  - file reads through operands (`| grep x /etc/shadow`, `| head secret`);
  - `grep -f`, `grep -r`, `grep -P` with pathological patterns, and `tail -f /dev/zero`;
  - future GNU flag drift.
  - A narrow grammar is plausible (grep `-i -v -c -n` plus one non-path operand; head/tail only `-n NUM`; wc with no arguments), but every addition is a new review round.
- **Option 1 residual risk:**
  - **Prefix-only matching:** `fw kw status | sudo …` would be refused silently, so telemetry is lost. Match the whole command: the left side must be exactly an allowed read form, and the right side inert (no redirect, substitution or `;`). Anything else keeps its card.
  - **Covert probing:** silent refusals let an agent map the grammar unobserved. An always-on log mitigates this ("card ≠ log").
  - **Operators reading "no card" as benign:** document the scope.

## Synthesis

Both recommend **option 1**, independently, with the same three conditions:

1. **The refusal stays unconditional.** Only the card is suppressed; nothing new runs.
2. **Whole-command classification, fail closed.** The left segment is exactly a plain read-only form. The right segment is an inert filter (`grep`/`head`/`tail`/`wc` with plain words, no further pipe, redirect, substitution, `;`, `&`, newline or quote). Any other command, or any doubt, keeps its card.
3. **An audit line for every suppressed refusal** (card ≠ log), so repeated attempts stay visible.

Both reject option 2 for the same reason the gate became a grammar in round 5: each allowed filter brings file-read, hang and flag-drift cases that need their own review round, for a convenience the agent can get by dropping the pipe.

**Agent recommendation to the operator:** option 1 with the three conditions above.
