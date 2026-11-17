# T-5211: Operator decisions in Watchtower reach the agent

**Status:** inception, exploring. Trigger: operator, 2026-11-17.

## The problem

When the operator records a decision in Watchtower (an inception GO, first of all), nothing tells
the project's agent. The decide chain (web/decide_runner.py, T-3749) runs `fw inception decide`
detached, commits the decision and the post-move writes, and ends. The agent finds out only by
chance: this session learned of T-5199's GO (commits 83676d1ac, 84b9e1cb5) only because its next
commit was refused for a task that had just moved to completed/.

## What exists

- **Idle-aware delivery.** lib/sidecar/inject.py injects one fixed line (a count and ids, no
  content) into the agent's TermLink session only when that session's own record says ready.
  Urgent mail (R5) is the only bypass. That is the operator's "not into a busy interaction".
- **Waiting mail.** With no ready session, the message stays flagged and an INJECT_BLOCKED event
  records why. The next session sees it through `fw sidecar alerts` at start.
- **The trigger is missing.** decide_runner.py has no notify step.

## Candidate shape (to confirm)

At the end of the decide chain, after the decision commit lands, post ONE non-urgent notice to the
project's own inbox, for example: "Inception T-XXXX decided GO by the operator (commit abc123). Read
the task's Decision section and file the build tasks." Do it once per decision, and never block or fail the
chain when posting fails (log it; the inception page's surface() already reports chain problems).

## Questions

See the task's Open Questions IW-1..IW-4.

## Dialogue Log

- 2026-11-17: the operator: "when Inceptions get a go, we get a trigger for the agent to act on
  that. If not immediately, then maybe via our sidecar protocol ... that it doesn't inject in a
  busy interaction ... that's certainly something that now goes unseen and that's not good."
