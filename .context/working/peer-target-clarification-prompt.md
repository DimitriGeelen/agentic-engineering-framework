# Read-only clarification: inbox.queued event target on TermLink side

You are a TermLink-side agent in /opt/termlink. The framework-side agent is
building the v2 peer-consult subscriber (framework T-1818 / pairs with
TermLink T-1636). Both halves agreed the seam: TermLink emits `inbox.queued`
when a message lands in a session inbox with no live consumer; AEF subscribes
via long-poll.

## What I need (≤5 line answer, NO code)

The framework-side calls:

  termlink event poll <TARGET> --topic inbox.queued --since <cursor>

The wire contract says the hub emits the event, machine-local. Question:

- (a) Does `inbox.queued` broadcast (fan-out to every registered session's
      bus, like `channel:learnings`)? If yes, AEF polls ANY ready session.
- (b) Is it scoped to the recipient session's bus? If yes, AEF polls the
      addressee's session specifically.
- (c) Is there a dedicated hub-session display name (e.g. `__hub__`,
      `tl-hub`, …) AEF should target?

If your T-1636 / T-690 implementation defines this, please state which of
a/b/c, and what `<TARGET>` value the framework should pass to
`termlink event poll`.

## Final reply format (≤5 lines)

  DONE
  Mode: <a|b|c>
  TARGET to pass to event poll: <session display_name pattern or "any ready">
  T-1636 implementation file/location (if extant): <path or "not yet">
  Cross-machine note: <one line if remote inbox.queued differs>

DO NOT write code. DO NOT modify files outside /opt/termlink. This is a
clarification request only.
