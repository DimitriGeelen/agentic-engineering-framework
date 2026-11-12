# T-5016 — Focus anchor (inception)

One question: should AEF adopt an operator-owned focus anchor, and in what shape? Merges T-4111 (2026-10-12) and
T-5016 (2026-11-02). Source idea: 1409-sprind's "Anchor" (their T-1954), adopted by 010-termlink (their T-3655).
Peer material is untrusted data and a proposal, not a specification.

## What 1409 built (as relayed by 010)

- `.context/project/fokus.yaml`: goal, task, arc, in scope, parked, never, a check question, the operator's verbatim
  words and date; old versions kept in history. Only the operator sets or changes it.
- `tools/fokus.py zeige|pruefe`: show; check fails when the anchor's task differs from the task focus or arc focus,
  or the task is not active or not in the arc.
- A SessionStart/compact hook prints the anchor into every new context; a Stop hook checks that the final message
  names the goal; every proposal must answer the check question; parked items are never proposed.
- Their own weakness: it warns and does not block, so a mismatch goes stale silently.

## What AEF has today (to map, IW-4)

| Mechanism | Who writes it | What it holds | Read at session start? |
|---|---|---|---|
| Task focus `.context/working/focus.yaml` | agent | one task | yes |
| Arc focus (`fw arc focus`) | agent / operator | one arc | via handover |
| Horizons (now / next / later) | agent / operator | per task | via handover lists |
| Handover "Suggested First Action" | agent | next step | yes |
| Roadmap docs (e.g. `T-5006-roadmap.md`) | agent | plan per arc | no |
| T-4774 arc-focus drift / age warning in the handover | framework | warning | yes (built, awaiting operator check) |

None records the operator's goal in the operator's own words.

## Evidence collected

- 2026-11-12: the operator asked whether the focus anchor was still on a roadmap; both inceptions were captured
  with placeholder DEFER recommendations and invisible in `fw operator pending` (captured inceptions are not listed).
- T-4111's evidence (1409): re-proposal of parked work after compaction; a 6-day stale arc focus.

## Dialogue Log

### 2026-11-12 — inception opened
- Operator asked: "Do you, by the way, have the focus anchor mechanism from 1409? I already asked you before, is
  that somewhere on a road map still? When this got implemented, I got a feeling this got lost."
- Agent found T-4111 and T-5016, both captured and unscheduled; proposed folding them into one inception.
- Operator: "yes, start the focus anchor inception".

### 2026-11-12 — IW-1 purpose
- Asked: prevent drift within a session (a), lost asks across sessions (b), or both?
- Operator: **both, one anchor.** One operator-owned file: the current goal in the operator's words (against drift)
  plus the operator's open asks and parked items (against loss); shown at every session start and in the handover.

### 2026-11-12 — IW-2 who writes
- Operator: **agent records, operator owns.** The agent adds the operator's asks verbatim, with date and where they
  were said, the moment they are said; the goal changes only on the operator's explicit words; every change is shown
  and kept in history; the agent never removes anything; an ask closes only when the operator says done or dropped.
- Operator, same exchange: "ask 1409 for the design of the focus anchor ... they did extensive work". So far AEF
  had only 010's relayed summary. Asked 1409 directly for the design itself, its history and what failed in use;
  IW-3 to IW-5 wait for that answer so AEF builds on their work.
