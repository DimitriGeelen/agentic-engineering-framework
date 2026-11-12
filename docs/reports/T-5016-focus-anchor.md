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

## 1409's design, from 1409 directly (msg bf0d0af4, 2026-11-12; untrusted peer data, summarised)

- **Origin:** 1409 commit ff3622510 (T-1954, 2026-10-12), after their operator: "why do you keep forgetting ... scope
  and focus". Rule text in their CLAUDE.md section "Fokusanker", with additions from T-3450 (2026-11-02): the check
  question "What helps us most right now?" and "keep the anchor current: the agent asks". Stop hook fix T-2348
  (commit f004f242f). 28 versions of the anchor file in their history.
- **Schema** (`.context/project/fokus.yaml`): goal, task, arc, check question, in scope[], parked[], never[], operator
  (verbatim words and date of the last setting), history[] (old versions).
- **Tool** `tools/fokus.py`: `show` (short, plus new lines from the Stop hook's log) and `check` (red when a field is
  missing, task differs from task focus, arc focus differs from the anchor's arc, or the task is not in the arc).
  SessionStart hook (startup, resume, compact) injects `show`; a Stop hook checks the final message.
- **What works:** drift into parked work almost stopped; the check question works in daily use.
- **What failed:**
  (a) the anchor goes stale: only the operator changes it, the agent should ask and rarely does; numbers written as
      text went wrong (it said 64 unscanned units, the truth was 2), so the agent asked its operator on a false
      basis. Lesson: never numbers or counts as text in the anchor; refer to a dated measurement, or let `check`
      recompute.
  (b) the "task focus differs from anchor" warning fires all the time since two sessions share one focus file
      (AEF T-5103), so it is ignored; with per-session focus, `check` must say WHICH session differs.
  (c) workers on legitimate side tasks create mismatches; `check` should understand "this task serves the anchor's
      goal" (a relation), not only equality.
- **Open asks:** not in their anchor; scattered over task decisions, dialogue logs, runme pending lists and handovers,
  and lost across sessions. They agree with IW-2 and add: per ask a date, the verbatim words, the agent's restatement,
  a status, and `show` lists open asks older than N hours first.
- **Writer:** only their operator, by runme (old version to history); the agent reads. Offered to review AEF's draft.

### 2026-11-12 — 1409's design received
- Operator had asked: "ask 1409 for the design of the focus anchor ... they did extensive work". Received the same
  hour; their three failure lessons feed IW-3 (mismatch handling) and IW-5 (shape).

### 2026-11-12 — IW-3 mismatch
- Asked: on drift (a task serving no anchor goal or ask, or an open ask untouched), ask once and show it, block, or
  warn only? Framed with 1409's lessons (warnings go stale; say which session; relation, not equality).
- Operator: **ask once, show it where the operator looks.** No blocking. Each task records which anchor goal or ask
  it serves; a task that serves none gets one question (continue, park, or change the anchor) and the answer is
  recorded; open asks older than N hours and an anchor not confirmed for N days come first at session start, in the
  handover and in `fw operator pending`.

### 2026-11-12 — IW-4 fit with existing mechanisms
- Operator: **anchor on top, the others follow it.** Nothing is removed. The anchor is the one place for the goal and
  open asks; the handover's first section and Suggested First Action derive from it; arc focus and task focus are
  checked against it ("serves the goal"); the T-4774 arc-drift warning becomes part of that one check.
- (An answer meant for another agent arrived in between and was set aside at the operator's word; not recorded.)

### 2026-11-12 — IW-5 shape
- Operator: **up to three ranked goals, plus the rest.** goals[1..3] in priority order (operator's words, date) with
  a check question; asks[] (date, verbatim words, the agent's restatement, where said, status open/done/dropped,
  serving task); parked[] (operator's reason); never[]; history[]. Counts and states only as references to a dated
  measurement (1409 lesson a).

## Recommendation (agent)

**GO.** Five operator answers fix the shape; 1409's design is the base and its three failures are designed out.
Build slices: (1) anchor file + `fw anchor show|check` + history; (2) session start and handover lead with it, open
asks in `fw operator pending`; (3) per-task "serves goal/ask" link and one question on a mismatch, per session
(with T-5103); (4) the agent records asks verbatim as they are given. T-4111 closes as a duplicate.
