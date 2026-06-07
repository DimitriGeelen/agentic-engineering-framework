# T-1653 — Arcs as first-class entity (research artefact)

> **Deprecation note (T-1851, 2026-05-16):** The `constituent_tasks:` field
> described in MVP scope item 1 + verb `tag` (item 2) is **deprecated for new
> arcs**. Source-of-truth for arc-task membership is now the task-side
> `arc_id:` frontmatter field (T-1849) with a one-shot migration (T-1850 —
> 162 tasks). Legacy arcs (created before 2026-05-16) retain their
> `constituent_tasks:` entries untouched per the D-Immutability axiom
> (T-1848). Read-surfaces (`web/blueprints/arcs.py`, `agents/audit/audit.sh`)
> merge legacy entries with the task-side `arc_id:` scan so both populations
> co-exist. See arc-grooming inception artefact
> [`docs/reports/T-1846-arc-grooming-inception.md`](T-1846-arc-grooming-inception.md)
> and handoff
> [`.context/handoffs/HANDOFF-arc-grooming-2026-05-15.md`](../../.context/handoffs/HANDOFF-arc-grooming-2026-05-15.md)
> for the full grooming arc.

**Status:** inception, exploring
**Trigger:** user feedback on T-1647 `/orchestrator` page — "absolutely unclear what kind of use this page should be." The right model isn't "orchestrator-substrate dashboard"; it's an **Arc** workspace that happens to surface the orchestrator-arc as one instance.

## What the user asked for

Six concrete requirements:

1. An arc needs a clear identifiable **name**
2. We can have **multiple arcs** simultaneously
3. We need to be able to **switch focus** to another arc
4. Tasks for an arc need to be easily identifiable — **suggest tagging the arc-name**
5. The agent prompt needs to be **injected with the arc in focus** — e.g. "focus task for arc :: \<current arc in focus\>"
6. The Arc page should be part of the **work section** and partially integrated with the work page; arc should be a **selectable filter** in the tasks page

## What we already have (and why this isn't from-scratch)

| Existing facility | What it gives us | Gap |
|-------------------|------------------|-----|
| Task tags (free-form `tags:`) | A way to group tasks | No namespace convention; arcs share tag-space with everything else |
| `related_tasks:` field | Manual cross-link | Bidirectional only by convention, no transitive closure |
| Umbrella tasks (T-1641, T-1644) | Closest analog to "arc" | Lifecycle is task lifecycle, not arc lifecycle; closing the umbrella ≠ closing the arc |
| `bin/fw context focus T-XXX` | Per-task focus | One task at a time; no "I am working on the orchestrator-rethink arc, which contains 7 tasks" mode |
| Watchtower `/tasks?tag=X` | Filter by tag (already wired) | No UI affordance to discover available arc tags; no arc landing page |
| Handover prompt injection | Includes "Current Focus: T-XXX" | No "Arc in focus" line |

So the Arc concept is partially-shadow-implemented through tags + umbrella tasks. The proposed change formalises and elevates it — closer to a refactor than a green-field build.

## Open design questions (and my recommendations)

### Q1: Where do arcs live?

| Option | Description | Tradeoff |
|--------|-------------|----------|
| **A. `.context/arcs/<arc-id>.yaml`** | Dedicated registry, parallel to `.context/audits/`, `.context/episodic/` | Clean separation; new dir to learn |
| B. `.tasks/active/<arc-id>/arc.yaml` + child task subdirs | Arc as a folder containing tasks | Conflates filesystem with semantics; child tasks can move on completion → arc folder partial |
| C. Compute arcs from tags (no separate registry) | Arc = set of tasks with `arc:<name>` tag | Zero new state; can't carry arc-level metadata (description, decision, focus history) |

**Recommendation: A.** Arc is its own entity with name, description, focus state, decision (if it ends), and references to constituent tasks. Carries history (when did it start, when did it close, what decisions came out of it).

### Q2: Arc identifier — slug vs T-ID?

| Option | Example | Tradeoff |
|--------|---------|----------|
| **A. Human-readable slug** | `orchestrator-rethink`, `drift-defenses` | Memorable; can collide; rename pain |
| B. T-style ID with a prefix | `A-001` for arc, parallel to `T-XXX` | Stable; impersonal; forces a registry |
| C. Anchor task ID | `T-1641-arc` | Already unique; ties arc lifetime to a task |

**Recommendation: A with optional anchor.** `arc-id: orchestrator-rethink`, `anchor_task: T-1641` field for backward link. Slugs match how humans refer to arcs in conversation.

### Q3: Tag convention?

| Option | Tag format | Tradeoff |
|--------|-----------|----------|
| **A. `arc:<arc-id>`** | `arc:orchestrator-rethink` | Clear namespace; matches `task:T-XXX` convention from orchestrator routing |
| B. `from-T-XXXX` (current convention) | `from-T-1641` | Already in use on T-1646–T-1652; ties arc to anchor task |
| C. Both | A as canonical, B as alias | Soft transition |

**Recommendation: A canonical, migrate B.** `arc:orchestrator-rethink` reads cleanly. Migration: all `from-T-1641` tags get `arc:orchestrator-rethink` added; old tag stays for one release as alias.

### Q4: Focus mechanism — single arc, multiple, hierarchical?

| Option | Description | Tradeoff |
|--------|-------------|----------|
| **A. Single arc focus** | `.context/working/arc-focus.yaml` holds one arc-id | Matches single-task-focus model; clear; sometimes too narrow |
| B. Stack | Last-N arc focus | More natural when context-switching, but overhead |
| C. None — focus stays at task level | Arc is a label, not a focus axis | Loses the "I'm in arc X" workflow signal |

**Recommendation: A initially.** `bin/fw arc focus <arc-id>` writes to `.context/working/arc-focus.yaml`. Multiple arcs in flight (Q ask #2) is satisfied by SWITCHING focus, not holding multiple in focus simultaneously — the registry holds them all; focus is one-at-a-time.

### Q5: Prompt-injection mechanism

| Option | Description | Tradeoff |
|--------|-------------|----------|
| **A. Extend handover/SessionStart hooks** | Same path as task focus injection — add `## Current Arc` line | Zero new mechanism; lands automatically |
| B. CLAUDE.md per-arc snippet | Each arc carries instructions agents should follow within it | Powerful; risks instruction-creep |
| C. Both A and B | Focus line + optional arc-specific guidance file | Most flexible; most cognitive load |

**Recommendation: A first; B as extension** if a real arc accumulates >3 instructions worth of arc-specific discipline. The orchestrator-rethink arc has none yet.

### Q6: Watchtower integration — separate `/arcs` page, or fold into landing + `/tasks`?

| Option | Description | Tradeoff |
|--------|-------------|----------|
| **A. New `/arcs` listing page + `/arcs/<id>` detail; replace `/orchestrator`** | Each arc gets a workspace; orchestrator-rethink becomes one of N | Clean; new page to maintain |
| B. Arcs are a section ON the landing page (above active tasks); each clicks through to `/tasks?tag=arc:X` | No new pages; arcs surface as filters | Zero new templates; arcs feel second-class |
| **C. Both — `/arcs` page + landing-page section + `/tasks` filter chip** | Arcs as a real navigation peer, with the surface affordances on landing & tasks | Most work; most coherent |

**Recommendation: C, staged**. Phase 1 (this task): landing-page section + `/tasks?arc=X` filter chip. Phase 2 (separate task): `/arcs` page replaces `/orchestrator`. Reason: 6's "part of the work section" matches landing-page integration; the filter chip in /tasks (req #6 second clause) is small.

### Q7: Lifecycle — when does an arc end?

Three plausible end-states:
- **Closed** — all constituent tasks done, decision (if any) recorded, archive
- **Abandoned** — explicitly stopped; no decision; non-failure
- **Forked** — split into two arcs; original keeps a reference

**Recommendation:** Three states, mirroring inception decide (go / no-go / defer). Arc has `status: in-progress | closed | abandoned`, with optional `decision:` and `closed_at:` fields. `bin/fw arc close <id>` closes; sweep audit warns on stale in-progress arcs (>30 days no constituent commit).

## Concrete proposal (if GO)

**MVP scope (Phase 1):**

1. **Data model:** `.context/arcs/<arc-id>.yaml` with: `id, name, description, status, anchor_task, constituent_tasks: [], created, closed_at, decision` — _T-1851: `constituent_tasks:` deprecated; new arcs omit it. Task-side `arc_id:` (T-1849) is the source-of-truth._
2. **CLI:** `bin/fw arc {create|focus|list|show|close|tag} <arc-id>`
   - `create <id> --name "..." --anchor T-XXXX` — register, optionally seed from anchor's `related_tasks`
   - `focus <id>` — write `.context/working/arc-focus.yaml`
   - `list` — table of arcs with focus-status, task counts, last activity
   - `show <id>` — detail
   - `close <id> --decision "..."` — close
   - `tag <id> T-XXXX` — adds `arc:<id>` to task's tags + (legacy) appends to arc's `constituent_tasks` if the field exists. _T-1851: prefer setting `arc_id:` on the task directly._
3. **Tag namespace:** `arc:<id>` in task tags, lint via existing audit
4. **Prompt injection:** handover.sh adds "Current Arc: <name> (X tasks, Y of which now)" line; SessionStart `resume` skill picks it up
5. **Watchtower:** landing page gets an "Arcs in flight" section above active tasks; `/tasks?arc=<id>` filter chip with discoverable arc list
6. **Migration:** auto-create `orchestrator-rethink` arc from T-1641, seed constituent_tasks from `related_tasks` of T-1641/T-1644. _T-1851/T-1850 retrofit: 162 tasks bulk-migrated from `tags:[arc:*]` → `arc_id:` field._

**Out of MVP scope (file separately):**

- `/arcs` dedicated page (Phase 2)
- Arc-specific CLAUDE.md snippets (Phase 2 if needed)
- Multi-arc focus stack (rejected — start single)
- Arc graduation to a separate repo / project (rejected — over-design)

**Estimate:** ~1 session (4h) for MVP. Reversible — no new dependencies, no deletes.

## Risk / what to watch out for

- **Tag explosion**: existing tasks have noisy tags. The `arc:` namespace must be reserved; audit needs to lint stray uses (`task:foo`, `bug:`, etc. — separate gap).
- **Arc focus vs task focus contention**: prompt injection includes both? Both. Task focus is the work *unit*; arc focus is the work *theme*. They compose.
- **Stale arcs**: same problem as stale tasks — D2-style audit.
- **Arc-level decisions**: do they live in the arc YAML or as a `decision` task within the arc? **Recommendation:** YAML carries the headline decision; long-form decisions stay in `.context/project/decisions.yaml` cross-linked.

## Decision needed

Choose:

1. **GO Phase 1** — I implement the MVP as described (data model + 7-verb CLI + handover injection + landing-page section + `/tasks?arc=` filter + migration of T-1641 arc). Approx 4h. `/orchestrator` stays for now; killed in Phase 2.
2. **GO with modifications** — adjust any of Q1–Q7 above before I start
3. **NO-GO** — keep the current model (arcs implicit via tags + umbrella tasks), just iterate `/orchestrator` differently
4. **DEFER** — interesting, not now; revisit later

## Dialogue Log

### 2026-05-01 — User reframes /orchestrator as Arc workspace

**User:** [in response to my T-1647 review attempt] "looked at it me its absoilutly unclear what kind of use this page shoud be to be, how can i use thios information, why is it suefull"

**Agent acknowledged:** Page is a status surface, not a workspace. Offered three options (iterate / demote / keep as-is).

**User reframed (real ask):** "1 an arc need to have a clear identyable name, 2 we can have multiple arc's, 3 we need to be able to switch focus to another arc, 4: taks for an arc need to be easilly identifyable, suggest tagging the arcname, 5 the prompot need to be injected with the arc in focus e.g. 'focus or taks for arc :: current arc in focus', 6 teh ARc page should be part of the work section and partially integrated with the work page, arc should be a selectable filter in the tasks page"

**Outcome:** This is a model change, not a UX iteration. Filed as inception (T-1653) with this artefact. Awaiting GO.
