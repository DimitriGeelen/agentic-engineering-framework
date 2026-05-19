# Arc System — Agentic Engineering Framework

## Overview

An **arc** is a multi-task workspace grouping work by theme. Where a task is
a single deliverable, an arc holds the longitudinal narrative that wraps
multiple tasks: what is the *user-observable* mechanic we are building, how
does each constituent task move that mechanic forward, and what is the
explicit closure decision that retires the arc?

**Core principle: arcs make the *meta-question* visible.** A task answers
"what are we doing right now?" — an arc answers "what is the whole thing
this row of tasks is in service of, and how will we know when it's done?"

Arcs are **optional** for tasks. Standalone tasks remain first-class. But
when work spans more than ~3 tasks with a shared headline mechanic, an arc
captures the cohering thread that would otherwise be folklore — implicit in
commit chains and only visible to whoever was there.

This document describes the post-arc-grooming state shipped by the
`arc-grooming` arc (T-1846 → T-1857, 2026-05): sequential immutable IDs,
four-state lifecycle, task-side `arc_id:` frontmatter, abandon verb,
freshness audit, Watchtower lifecycle filter tabs.

---

## Arc Structure

Arcs are **YAML files** in `.context/arcs/`. The filename stem is the
arc's *slug* (human-readable). The frontmatter `id:` field is the arc's
*immutable numeric id* (`arc-NNN`, allocated sequentially at create-time).
Both forms route to the same arc — see Dual Identity below.

### Location

```
.context/arcs/
  arc-grooming.yaml
  dispatch-safety.yaml
  embeddings-strategy.yaml
  orchestrator-rethink.yaml
  project-shape-resilience.yaml
```

### File Format

```yaml
id: arc-005                                    # T-1848: immutable, sequential, never reused
slug: arc-grooming                             # filename stem (human-readable)
name: "Arc grooming — canonicalisation, lifecycle, audit, doc"
description: "..."
status: in-progress                            # T-1852: draft|in-progress|closed|abandoned
anchor_task: T-1846                            # the inception or umbrella task
headline_mechanic: "agent runs `fw arc create` → arc is born `draft` →
                    `fw arc start` moves it to `in-progress` → operator
                    sees the lifecycle state on Watchtower /arcs"
demo_evidence: null                            # set by `fw arc close --demo`
created: 2026-05-15T14:53:00Z
closed_at: null                                # set by `fw arc close`
decision: null                                 # set by `fw arc close --decision`
abandoned_at: null                             # set by `fw arc abandon` (T-1854)
abandonment_reason: null                       # set by `fw arc abandon` (T-1854)
```

**T-1851 deprecation:** the `constituent_tasks:` field is no longer
written by `fw arc create`. Source-of-truth for arc membership is the
**task-side** `arc_id:` frontmatter field (T-1849). Legacy arcs retain
their existing `constituent_tasks:` lists untouched (D-Immutability —
see below).

---

## Arc Fields Reference

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `arc-NNN`. Immutable, sequential, never renamed/reused (T-1848). |
| `slug` | yes | filename stem. The `name` ↔ `slug` mapping should be stable, but a slug rename via filesystem `git mv` is permitted in rare cases. |
| `name` | yes | Quoted free-text. Avoid bare colons (T-1816 yaml-safe-quote enforced). |
| `description` | yes | Quoted free-text. |
| `status` | yes | One of `draft`, `in-progress`, `closed`, `abandoned` (T-1852). |
| `anchor_task` | yes | The inception/umbrella task this arc was born from (T-1856 audit checks existence). |
| `headline_mechanic` | yes | Required at `fw arc create` (T-1668 §ACD/G-062). Substrate-only phrasing is refused. Describes the **user-observable** deliverable, not the substrate. |
| `demo_evidence` | optional | wire-level artefact set by `fw arc close --demo`. |
| `created` | yes | ISO-8601 timestamp set at `fw arc create`. |
| `closed_at` | optional | Set by `fw arc close` on `in-progress → closed`. |
| `decision` | optional | Free-text closure decision, set by `fw arc close --decision`. |
| `abandoned_at` | optional | T-1854: set by `fw arc abandon` on `draft|in-progress → abandoned`. |
| `abandonment_reason` | optional | T-1854: free-text reason (≥30 chars), set by `fw arc abandon --reason`. |
| `bvp_scores` | optional | T-1918 (arc-006): arc-level BVP scores (map; same shape as task `bvp_scores:`). Aggregate may differ from `sum(task.bvp_scores)` because arcs apply scoped_drivers. |
| `scoped_drivers` | optional | T-1918 (arc-006): list of `{name, weight}` entries — max **3**, weight integer **≤6** (M2, T-1926). Approved by `fw arc approve-driver` (§ACD-gated). Drives per-arc BVP. Empty list is the safe default. |
| `proposed_scoped_drivers` | optional | T-1918 (arc-006): list of timestamped `{name, source, ts}` proposals from `fw arc show-suggestions` (T-1926) or the estimator. Uncapped (D7-reframe: persists for reuse, not audit). |

---

## Arc Statuses (Four-State Lifecycle)

T-1852 introduced the full four-state lifecycle. `fw arc create` no longer
auto-starts an arc — every new arc is born `draft` and must be explicitly
started.

```
       fw arc create
          │
          ▼
       ┌──────┐    fw arc start    ┌─────────────┐    fw arc close    ┌────────┐
       │draft │ ─────────────────► │in-progress  │ ─────────────────► │closed  │
       └──────┘                    └─────────────┘                    └────────┘
          │                              │
          │  fw arc abandon              │  fw arc abandon
          └──────────────────┐  ┌────────┘
                             ▼  ▼
                          ┌─────────────┐
                          │ abandoned   │
                          └─────────────┘
```

| Status | Meaning | Transitions allowed |
|---|---|---|
| `draft` | Created, not yet active. Use for arcs spec'd ahead of pickup. | → `in-progress` (`fw arc start`); → `abandoned` (`fw arc abandon`). |
| `in-progress` | Active work. Default after `fw arc start`. | → `closed` (`fw arc close`); → `abandoned` (`fw arc abandon`). |
| `closed` | Shipped. `demo_evidence` captured. | terminal — no further transitions. |
| `abandoned` | No longer pursued. `abandonment_reason` captured. | terminal — no further transitions. |

**Refusal contract** (T-1852 `_arc_require_status`):
- `fw arc start <closed|abandoned>` → refused with allowed-transitions hint.
- `fw arc close <draft|closed|abandoned>` → refused with allowed-transitions hint.
- `fw arc abandon <closed|abandoned>` → refused with allowed-transitions hint.
- All refusals exit non-zero with an actionable message citing the diagram above.

---

## Dual Identity: slug ↔ arc-NNN (T-1848)

Every arc has two identifiers:

| Form | Example | Role |
|---|---|---|
| **slug** | `arc-grooming` | Filename stem. Human-readable. Used in task frontmatter `arc_id:` for tag-namespace continuity. |
| **arc-NNN** | `arc-005` | Numeric immutable id in YAML `id:` field. Sequential. Never reused even if an arc is abandoned. |

Either form routes to the same arc in every framework surface:

- `fw arc focus arc-grooming` ≡ `fw arc focus arc-005`
- `fw arc close dispatch-safety` ≡ `fw arc close arc-001`
- Watchtower `/arcs/arc-grooming` ≡ `/arcs/arc-005`
- Task frontmatter `arc_id: arc-grooming` ≡ `arc_id: arc-005` (matches the same arc in audit + Watchtower)

**Why both?** The slug is what humans type and grep. The `arc-NNN` id is
the immutable handle: it survives a slug rename (rare but permitted) and
gives the system a stable foreign key.

---

## D-Immutability Axiom

The arc system is **append-only** for identifiers. This is a hard invariant
(T-1846 D-Immutability axiom):

- **No renumber.** `arc-005` always means the same arc that was created as
  `arc-005`. The next arc is always `arc-006`.
- **No reuse.** If an arc is abandoned and a new one occupies the same
  topic, it gets a fresh `arc-NNN` — never the abandoned one's id.
- **No delete.** The YAML file stays in `.context/arcs/` forever, marked
  `closed` or `abandoned`. The historical record is the artefact.
- **Slug rename is permitted but rare** — only when the original slug
  becomes actively misleading. `git mv` the file; the `id:` stays.

Why this matters: agents and audits cross-reference arcs by `arc-NNN`
across months. If `arc-005` could mean different things at different
times, every cross-reference becomes a time-travel puzzle. Immutability
is what makes the audit trail load-bearing.

---

## Task ↔ Arc Membership (T-1849, T-1850)

A task joins an arc via the **`arc_id:`** field in its frontmatter:

```yaml
---
id: T-1854
name: "fw arc abandon CLI verb"
arc_id: arc-grooming     # slug form (preferred for readability)
# OR
arc_id: arc-005          # arc-NNN form (both resolve to the same arc)
---
```

`arc_id:` is **optional** — tasks without an arc are first-class.

**Validation (T-1849):** a PreToolUse hook (`check-arc-id`) refuses
Write/Edit on a task whose `arc_id:` does not resolve to an existing
arc YAML. Bypass: `FW_ALLOW_ARC_ID_DRIFT=1` (logged Tier-2 in
`.gate-bypass-log.yaml`).

**Migration history (T-1850):** Before 2026-05-16, arcs were referenced
via a legacy `tags: [arc:<slug>, ...]` form. T-1850 migrated 162 tasks
to the `arc_id:` field in one shot. The legacy tag form still parses
(readers merge both sources), but new tasks should use `arc_id:` only.

---

## fw arc CLI

```
fw arc create <slug> --name "..." --headline-mechanic "..." [--anchor T-XXXX] [--description "..."]
                          Register a new arc. Born `draft`. --headline-mechanic
                          is REQUIRED (§ACD/G-062) — substrate-only phrasing is
                          refused.
fw arc start <id>         Transition `draft → in-progress`. Refused from any
                          other source state (T-1852).
fw arc focus <id>         Set/unset the focused arc (one at a time).
fw arc focus --clear      Drop arc focus.
fw arc list               Show all arcs with status; * marks focused.
fw arc show <id>          Detail: metadata + constituent tasks.
fw arc tag <id> T-XXXX    Add `arc:<slug>` tag to a task (legacy; prefer
                          `arc_id:` frontmatter).
fw arc close <id> --demo <path|url|none> [--justification "..."] [--decision "..."]
                          Transition `in-progress → closed`. --demo is REQUIRED
                          (§ACD/G-062). `none` allowed with --justification ≥30
                          chars (logged to `.context/audits/arc-bypass.jsonl`).
                          Refused under $CLAUDECODE=1 unless --i-am-human or
                          --from-watchtower (T-1671 agent gate).
fw arc abandon <id> --reason "<≥30 chars>"
                          T-1854: transition `draft|in-progress → abandoned`.
                          Refused from closed/abandoned. Refused under
                          $CLAUDECODE=1 unless --i-am-human or --from-watchtower.
                          Appends JSON to `.context/audits/arc-abandon.jsonl`.
                          D-Immutability: YAML stays in place.
fw arc migrate <id> --anchor T-XXXX
                          Legacy: seed `constituent_tasks` from anchor's
                          `related_tasks` and `from-T-XXXX` tags. Prefer
                          `arc_id:` + `fw arc tag` for new arcs (T-1851).
```

### Agent gate ($CLAUDECODE)

Both `fw arc close` and `fw arc abandon` refuse under `$CLAUDECODE=1` —
arc terminal transitions belong to the human and are routed through
Watchtower review (T-1671 §ACD/G-062 Default-to-OPEN gate). The agent
should run `fw task review <anchor-task>` and let the human invoke the
verb from a non-Claude-Code shell or the Watchtower button.

Overrides: `--i-am-human` (human typing into an agent session, rare);
`--from-watchtower` (Flask backend invocation).

---

## Audit Checks

Two audit checks (run via `fw audit`) keep the arc registry honest:

| Check | Origin | Behaviour |
|---|---|---|
| **Anchor existence** | T-1856 | WARN if an arc's `anchor_task:` doesn't resolve to a task in `.tasks/{active,completed}/`. Catches stale references after task moves or deletions. |
| **Stale-arc warning** | T-1855 | WARN when an arc has `status: in-progress` AND no commit in the last `FW_STALE_ARC_DAYS` days (default 30) touched any task with matching `arc_id:` (slug or arc-NNN form). Silent on draft/closed/abandoned arcs and on zero-population arcs. |

Both checks WARN-only (audit exit ≤ 1). Configurable threshold:
`FW_STALE_ARC_DAYS` env var (default 30).

---

## Watchtower Surface (T-1853)

`/arcs` renders a four-state lifecycle filter strip:

```
[ draft (0) ] [ in-progress (5) ] [ closed (0) ] [ abandoned (0) ] [ all (5) ]
```

- **Default landing view** = `in-progress`.
- Each tab is a server-side filter (`?status=<label>`); unknown values
  clamp to the default.
- Counter badges reflect the full corpus count, not the filtered count.
- Per-arc `stale` badge (orange) shows when the same staleness condition
  used by the audit (T-1855) is true *live* — Watchtower runs the same
  git-log check on each request (cached 60s).

`/arcs/<slug>` and `/arcs/<arc-NNN>` both resolve to the arc detail page.

---

## Relation to Tasks

| Concept | Task | Arc |
|---|---|---|
| Unit of work | One deliverable | Multiple tasks pursuing one mechanic |
| Identifier | `T-NNNN` | `arc-NNN` + slug |
| Lifecycle | captured → started-work → work-completed | draft → in-progress → closed/abandoned |
| Gate | P-002 (modify only under active task) | T-1671 (terminal transitions need human) |
| Granularity | Hours to a session | Days to weeks |
| Required? | Yes (P-001 "nothing without a task") | No — optional umbrella |

A task **without** an arc is fine. A task **with** an arc references it
via `arc_id:`. An arc **without** tasks is a stub — audit will not WARN
about staleness on zero-population arcs (they are noise, not signal).

---

## Relation to Other Concepts

| Concept | Relationship |
|---|---|
| **Inception** | The anchor task of a build arc is usually the inception that produced it. The inception decides "do this work"; the arc holds the work as it unfolds. |
| **Horizon** | Tasks within an arc still carry their own `horizon` (now/next/later). The arc itself is a thematic grouping, not a priority signal. |
| **Learnings** | Captured at the task level (`fw context add-learning`). An arc's value over its tasks is that learnings *across* tasks become legible: re-reading `arc.yaml` plus its 8 constituent tasks shows a narrative the individual task files don't. |
| **Directives** | The four constitutional directives (Antifragility, Reliability, Usability, Portability) apply to arcs the same way they apply to tasks. An arc's `headline_mechanic` should trace back to one or more directives. |
| **Component Fabric** | Arcs do not have fabric cards (they aren't *components*). But the components touched by an arc's tasks accumulate via the per-task fabric edges — `fw fabric blast-radius <arc-anchor-commit-range>` traces the arc's structural footprint. |

---

## D-Immutability vs Slug Rename: Worked Example

Suppose `arc-007` is created with slug `mcp-discovery` and after two
weeks the work has expanded to cover broader orchestrator surfaces. Two
moves are *not* allowed:

1. **❌ Rename to `arc-001`** — the numeric id is immutable; a more
   "important-looking" id is not a reason to renumber. `arc-007` is what
   it is.
2. **❌ Delete the YAML** — abandonment is the recorded outcome of
   "stop pursuing this", not deletion.

One move *is* allowed (rare):

- **✅ Slug rename via `git mv .context/arcs/mcp-discovery.yaml
  .context/arcs/orchestrator-discovery.yaml`** — the file moves, the
  `id: arc-007` line stays, and any task whose `arc_id:` was the old
  slug needs a mechanical sweep (the PreToolUse hook will refuse
  edits to those tasks until they're updated). Prefer arc-NNN form in
  task frontmatter if you anticipate a slug rename.

---

## Why arcs exist

The arc system was born from a recurring pattern: a feature would take
6–12 tasks across 2–3 weeks, and the cohering "why we are doing this"
would only live in the inception task's body and a few commit messages
— not in any retrieval-friendly surface.

Concrete origin: the `arc-grooming` arc itself. Five separate slices
shipped between 2026-05-15 and 2026-05-17 (sequential immutable IDs,
arc_id frontmatter migration, lifecycle state machine, audit warnings,
Watchtower filter tabs, abandon verb, this doc). Without the arc, the
slices read as seven loosely-related commits. With the arc, the slices
read as a single coherent groom — and the closure decision will be a
single moment, not seven small ones.

That coherence is the arc's headline mechanic. Everything else is
plumbing.

## See also

- `010-TaskSystem.md` — task lifecycle, frontmatter, and the arc_id field
- `040-ValueDrivers.md` — Business Value Points and arc-scoped drivers,
  including the `scoped_drivers` / `proposed_scoped_drivers` / `bvp_scores`
  arc fields and the `fw arc approve-driver` workflow
