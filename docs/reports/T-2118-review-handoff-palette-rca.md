# T-2118 — Review-handoff palette: RCA + structural enforcement proposal

Research artifact for inception **T-2118**. Codified per CLAUDE.md §Inception
Discipline C-001 — "Research artifact first … the thinking trail IS the
artefact … conversations are ephemeral, files are permanent."

This file mirrors the persistent body of `.tasks/completed/T-2118-review-handoff-palette-inception.md`
so the RCA + Recommendation survive task closure (move to `.tasks/completed/`)
and remain greppable from `docs/reports/` where downstream readers expect them.

Status: **awaiting human GO/NO-GO/DEFER** via
http://192.168.10.107:3000/review/T-2118 (CLAUDECODE-gated, T-1671 — the
agent cannot decide this inception).

---

## TL;DR

Memory-based prevention has failed **four times**. Recommendation: GO on
Option A (close-time palette emit) + Option B (handover-time palette emit)
with config-keyed channel extensibility (notify, slack, email, …).
Defer Option C (PreCompact strict block) until A+B effectiveness can be
measured over 2-3 sessions.

If GO is recorded, three build slices are pre-scoped:

- **T-NEW-A:** `update-task.sh` close-time palette extension (Watchtower URL,
  QR code, copy-pasteable shell, affected-page link if `components:` maps
  cleanly, config-keyed extra channels).
- **T-NEW-B:** `fw handover` palette block — enumerate partial-complete tasks
  closed this session, emit each task's palette.
- **T-NEW-C:** `.framework.yaml` schema addition for `review_channels:`
  extensibility slot + reference docs.

---

## Problem statement — fourth correction on the same class

Recorded memory cites four prior corrections on this exact failure mode:

1. `feedback_use_fw_task_review.md` — "ALWAYS use `fw task review T-XXX` for
   human approvals, never raw CLI commands."
2. `feedback_human_review_links.md` — "When handing work to human (Human ACs,
   inception decide, Tier 0, gaps, observations), always render clickable
   Watchtower URLs inline; never just task IDs."
3. `feedback_review_concrete_links.md` — "Human review steps MUST be full
   clickable URLs (resolved /arcs, /arcs/<id>, /review/T-XXX) + direct
   screenshot links + verify the linked UI state exists. **CURL every link
   before pasting.**"
4. `feedback_post_grill_governance.md` — "after writing Recommendation, four
   mandatory steps: arc, tags, related_tasks, pre-file sibling/build tasks"
   — same class of post-completion forgetting.

The session that filed this inception (2026-05-30) shipped six tasks
(T-2112–T-2117) + one inception (T-2115) and rendered them all as bare
`T-XXXX` lists at session-end — until the user explicitly asked for the
links. Pattern is reliable; prevention is not.

User's exact request:
> "watchtower links pelase, please incept RCA why you keep forgetting this,
> how can we wire in you always print out the full pallete of option (link,
> qr code, full shell command, etc … extend this with other option (like
> notify) … how can we ensure this is consistently presented?"

---

## Assumptions

- **A1.** The convention IS captured (4 memory entries + `fw task review` +
  CLAUDE.md §Presenting Work for Human Review). The gap is enforcement, not
  documentation.
- **A2.** Under budget pressure or session-end fatigue, the agent collapses
  the multi-step "render full palette" routine into the cheap default
  ("just list T-IDs"). The cost of rendering exceeds the agent's perceived
  urgency of the convention.
- **A3.** The fix should be **structural** — i.e. something that fires
  automatically at the moment of partial-complete OR at session-end, not
  "agent should remember harder". Memory-based prevention has failed 4×.
- **A4.** The fix should be **extensible** — future hand-off channels
  (notify, slack, email, Telegram) should plug in via the same mechanism,
  not require a new round of "remember to ALSO send a Slack message".

---

## RCA — why this keeps failing

**Symptom.** Agent ends sessions by listing partial-complete tasks as bare
`T-XXXX` text + brief description, omitting Watchtower URL / QR / shell /
affected-page links. User has to ask for the links explicitly every time.

**Root cause.** The convention is captured as **memory + soft documentation**,
not as a **structural hook**. Four mechanisms exist (`fw task review`,
CLAUDE.md §Presenting Work for Human Review, feedback memories,
render-surface gate P-013) — none of them FIRE at session-end or when the
agent generates a status summary. The "render full palette" step is purely
agent discretion. Under budget pressure (75-95% — this session hit both),
agent discretion collapses to lowest-cost output.

**Why structurally allowed.** The framework's gates fire on **file
operations** (Write/Edit/Bash via PreToolUse hooks) or on **task lifecycle
transitions** (`--status work-completed`). Neither fires on "agent generates
a status summary in chat". The handover agent's output goes to
`.context/handovers/LATEST.md`, but the **chat-output** is unconstrained.
So a memory that says "always do X in chat" is enforceable only by agent
recall — and agent recall under pressure is the exact failure mode we see.

**Why `fw task review T-XXX` doesn't solve it on its own.** The command
renders the palette beautifully, but **only when explicitly invoked**.
Six tasks closed this session = six `fw task review` calls would have been
needed. Under budget pressure the agent skipped all six. The command is
available, but invoking it is itself a remembered behaviour.

**Why existing PostToolUse hooks don't solve it.** PostToolUse fires after
individual tool calls (Write, Edit, Bash), not after the agent generates a
final-summary message. There is no current hook trigger for "agent emitted
a turn-ending text block".

**Pattern class.** Same as **G-018 / G-019 / L-403** — "agent treats
symptom-level fixes as complete; structural prevention requires the
framework to MAKE the right thing easier than the wrong thing." Memory-based
reminders are the wrong-thing-equivalent path; they require the agent to
remember to do work. A hook or generator-side artefact is the right-thing
path — the agent's natural output flow produces the palette without
remembering.

---

## Exploration plan — candidate fixes

### Option A — `fw task update --status work-completed` auto-emits the palette to stdout

After the existing close-time output (Watchtower link + QR for the just-closed
task), extend the same emit to a **palette block** that includes all the
user-asked-for surfaces:

- Direct link (`http://HOST:PORT/review/T-XXXX`)
- QR code (already emitted)
- Copy-pasteable shell (`cd /opt/... && bin/fw task review T-XXXX`)
- Affected-page link if the task touched a render surface (read from
  `components:` frontmatter)
- Future-extension hook: a config-keyed list of additional channels (notify,
  slack, etc.) — when configured, each emits its own line in the palette

**Pros.** Fires at the exact moment of closure. Agent's natural output (the
close command's stdout) already includes Watchtower link + QR — extending
it to also include shell + affected-page is incremental. Extensibility slot
is a config list, easy to add new channels.

**Cons.** Doesn't help when the agent generates a **session-end status
summary** (multiple tasks closed earlier in the session). The user's
complaint is partly that the summary chains together six T-IDs without each
one's palette.

### Option B — `fw handover` (or a new `fw review-queue --palette`) emits the palette for ALL active+partial-complete tasks owned by human

At session-end, before generating the handover document, scan `.tasks/active/`
for tasks with `owner: human` AND `status: work-completed` (i.e.
partial-complete awaiting [REVIEW]). For each, emit the same palette
Option A would emit at close time. The handover doc + the chat summary BOTH
include the palette.

**Pros.** Fires at the natural session-end point. Covers tasks that were
closed earlier in the session and would otherwise be summarised as bare IDs.
Extensibility via the same config list.

**Cons.** Could be noisy if many partial-complete tasks accumulate.
Mitigated by filtering to "closed-this-session" only — `date_finished:`
within the session timestamp window.

### Option C — PreCompact / handover-generation hook that BLOCKS until the agent's last message includes a per-task palette

Hard structural enforcement: the PreCompact hook (which already fires before
context compaction and on `fw handover`) parses the agent's most-recent
assistant message and refuses to proceed if any `T-XXXX` mentioned without
a matching review URL within 200 characters of it.

**Pros.** Forces the convention. Cannot be bypassed by budget pressure or
fatigue. Same enforcement class as the existing `check-active-task.sh`
hook (refuses Edit without a task).

**Cons.** False positives on incidental T-XXXX mentions (commit messages,
related-tasks references). Needs careful regex tuning. May feel adversarial
during normal exploration.

### Option D — Combine A + B + C in tiers

- A: close-time stdout already emits — extend palette here. **Low risk.**
- B: handover/session-end automation that re-emits for all session-closed
  tasks. **Medium risk** (handover already exists; extend its template).
- C: PreCompact / pre-handover validation that warns (not blocks) when
  agent's summary text contains bare T-IDs without nearby URLs. **High
  risk; may be too adversarial.**

### Option E — Defer; rely on the new fourth memory entry

Accept the failure; trust that the next agent will read four memory entries.

**Pros.** No code change.

**Cons.** This is exactly what failed three times before. Defer is "trust
the same mechanism that has failed N times to work the (N+1)th time" —
antifragility's opposite.

---

## Technical constraints

- Output palette must work in both terminal (ANSI/UTF-8 QR) and Markdown
  (clickable URL + bullets + shell-prefixed `cd && bin/fw …`). The current
  `fw task review` output is terminal-friendly; the chat-summary surface
  is Markdown.
- Watchtower URL must come from the triple-file
  (`.context/working/watchtower.url`) — never hard-coded `:3000` per
  CLAUDE.md §Watchtower Port.
- Affected-page link derivation requires reading the task's `components:`
  and mapping to URLs — heuristic, may be imperfect; degrade gracefully
  when components don't map cleanly.
- Extensibility config (Option A's "list of channels") must live in
  `.framework.yaml` per the standard 4-tier resolution.

---

## Scope fence

**IN.** Define the palette schema (what fields), the trigger points
(close-time + session-end), the extensibility slot (config-keyed channels),
and the recommended implementation depth (A+B; defer C+D).

**OUT (for this inception — file as separate builds on GO).**

- Building the Option A patch on `update-task.sh` close-emit
- Building the Option B handover-template extension
- Implementing the first non-Watchtower channel (notify) — gated on
  Option A+B landing first

**OUT (deferred).** Option C (PreCompact strict block) — file separately
if Option A+B don't move the needle after two more sessions.

---

## Go/No-Go criteria

- **GO if:** the convention has demonstrably failed ≥3 times in recorded
  memory (current evidence: **4 times**) AND a bounded structural fix
  exists with reversible cost.
- **NO-GO if:** the structural fix would impose >2 hours of build work per
  channel addition (current estimate: ~1.5 h for A+B combined; under
  threshold).
- **DEFER if:** the broader handover-format-redesign already underway
  (none known) supersedes this.

---

## Recommendation

**GO on Option A + Option B (extensibility built into both).**

**Rationale.** Four documented failures on the same class are NOT noise —
they are a structural class. Memory-based prevention has been tried four
times; antifragility says the next instance must be prevented structurally,
not by adding a fifth memory entry. Options A and B together emit the
palette automatically at two natural trigger points (close-time +
session-end), so the agent's natural output flow includes the palette
without needing to remember. The extensibility slot (config-keyed channels)
means future hand-off channels (notify, slack, email, Telegram) plug in by
adding a single config entry — no new round of "remember to ALSO emit X"
required.

Option C (PreCompact strict block) is appealing but risks adversarial
false positives; defer it until A+B's effectiveness can be measured over
2-3 sessions.

**Evidence.**

- 4 memory entries on this class: `feedback_use_fw_task_review.md`,
  `feedback_human_review_links.md`, `feedback_review_concrete_links.md`,
  `feedback_post_grill_governance.md`.
- This session: 6 tasks + 1 inception closed without palette emission in
  agent summary; user asked for links explicitly.
- Existing partial palette already emitted by
  `fw task update --status work-completed` (Watchtower URL + QR) —
  Option A is incremental extension of working code.
- Existing handover generation pipeline (`agents/handover/`) is the natural
  Option B host.
- L-403 (T-1828) — "gate measures proxy that diverged from reality" —
  same class: memory measured intent, not effect. Structural emit measures
  effect.

**Hand to human:** http://192.168.10.107:3000/review/T-2118 — Watchtower
decision form. Agent cannot decide (CLAUDECODE-gated per T-1671).

---

## Dialogue log

### 2026-05-30 — user surfaced the class

User caught the missing-palette pattern for the fourth time and asked the
inception to be filed: *"watchtower links pelase, please incept RCA why
you keep forgetting this, how can we wire in you always print out the full
pallete of option (link, qr code, full shell command, etc … extend this
with other option (like notify) … how can we ensure this is consistently
presented?"*

Agent acknowledged the four prior memory entries (this is governance debt,
not a one-off lapse), rendered the missing palette inline for the six just-
shipped tasks, then filed this inception capturing the RCA + recommendation.

### 2026-05-30 (later) — artefact codification

`fw audit` raised **C-001 WARN**: "Inception T-2118 has no research
artefact in `docs/reports/`". The inception body in `.tasks/completed/T-2118…`
captures the full thinking; this file mirrors it so the artefact survives
the task's eventual move to `.tasks/completed/` and the audit closes.
Same codification rule the framework applies to itself.
