# T-1846 — Arc grooming inception

**Status:** open — awaiting human answers to Q1/Q2/Q3
**Recommendation:** GO (per HANDOFF-arc-grooming-2026-05-15 §5)
**Source handoff:** `.context/handoffs/HANDOFF-arc-grooming-2026-05-15.md`
**Filed:** 2026-05-15

## 1. Why this inception exists

Three of the eight design questions parked in T-1653 (`docs/reports/T-1653-arcs-as-first-class.md`)
block downstream work that wants to score arcs and rank tasks within arcs. They have
been sitting parked without follow-up tasks. The trigger to investigate now: the
research session for HANDOFF-value-prioritisation-2026-05-15 surfaced a dependency
on arc-level enumeration reliability and lifecycle correctness; investigation
showed neither is in place today.

This inception's job is **not** to do the build work. The build work is split into
T-NEW-2..9 in the handoff and must be filed as separate build tasks. This
inception's job is to:

1. Resolve **three governance questions** (Q1, Q2, Q3) with the human.
2. Produce a **build-slice manifest** — a concrete, runnable list of `fw task create`
   invocations for T-NEW-2..9.
3. Create the `arc-grooming` arc YAML as the workspace for the slices (post-decide-go).

## 2. Source-of-truth pointers (read these before deciding)

| Source | Why |
|---|---|
| `.context/handoffs/HANDOFF-arc-grooming-2026-05-15.md` | Full research, Findings F1–F8, Decisions D1–D7, Assumptions A1–A4, Risks, Dialogue log |
| `docs/reports/T-1653-arcs-as-first-class.md` | The design anchor; eight parked questions live here |
| `lib/arc.sh:232` | Where status is written at create-time (A3 evidence) |
| `lib/arc.sh:473-492` | §ACD `--demo` gate (F8 evidence; pattern that `fw arc abandon` will copy) |
| `agents/audit/audit.sh:550-555` | T-1816 YAML-parse extension to arcs (F4/F7 evidence) |
| `.context/arcs/{dispatch-safety, orchestrator-rethink, embeddings-strategy, project-shape-resilience}.yaml` | The four currently in-progress arcs (must remain `in-progress`) |

## 3. Three open governance questions (for human)

### Q1: `arc_id:` validation tier — Tier-1 block on task save, or audit warning only?

- **Default (handoff §6):** Audit warning. Tier-1 block creates unfixable states
  if an arc is deleted while tasks reference it.
- **Trade-off:**
  - **Block** → typos caught at save; downside: deleted-arc cascade.
  - **Warn** → typos surface at next audit cycle; downside: stale references can
    accumulate quietly.
- **Recommendation:** Audit warning. Matches D4 (anchor-task missing is also warn-only).
  Symmetric failure model.
- **Human's answer:** _pending_
- **Decided at:** _pending_

### Q2: `arc_id:` migration — emit committable report at `.context/audits/arc-id-migration-<date>.yaml`?

- **Default (handoff §6):** Yes — emit and commit. Matches existing pattern of one-shot
  governance events being audit-trailed (`arc-bypass.jsonl`).
- **Trade-off:**
  - **Committable report** → migration is one durable auditable event; can be referenced
    later; recovers reverse-mapping if migration ever needs undo.
  - **Non-committable** → less repository noise; harder to reconstruct what happened.
- **Recommendation:** Yes, committable.
- **Human's answer:** _pending_
- **Decided at:** _pending_

### Q3: Multi-arc tagged tasks — what does the migration do?

- **Context:** §11.5 verified there are **2** genuinely multi-arc-tagged tasks
  across `.tasks/{active,completed}/`:
  - **T-1717** — tags: `[arc:embeddings-strategy, arc:orchestrator-rethink, T-1715-family, G-064-closure-pilot, T-679-family, structural-fix]`
  - **T-1719** — tags: `[arc:embeddings-strategy, arc:orchestrator-rethink, T-1717-implementation, G-064-closure-pilot, vertical-slice-1, blocked-on-t-1717-go]`

  Both sit deliberately at the embeddings-strategy ∩ orchestrator-rethink
  intersection (G-064 closure pilot work). The dual-arc relationship is
  semantic, not accidental. **Both tasks need a human decision on which arc
  becomes the canonical `arc_id:` value — auto-picking alphabetically here
  would silently break the cross-arc relationship that was intentional.**

  (Note: an initial scan flagged T-1843 as multi-arc, but its body-text
  references inflated the match; its `tags:` line carries only
  `arc:project-shape-resilience`.)

- **Default (handoff §6):** Pick alphabetically-first `arc:*` tag as `arc_id:`,
  leave the other tag(s) in place, warn loudly in the migration report, list
  affected task IDs for human follow-up.
- **Refinement given the evidence:** For T-1717/T-1719 specifically, the
  intersection is meaningful (G-064 closure pilot). Three options:
  - **a) Auto-pick alphabetically + leave `arc:orchestrator-rethink` as a
    secondary tag, document the constraint that one task can belong to only
    one canonical arc** — keeps the cross-arc semantic visible but downgraded.
  - **b) Block migration on these 2 tasks and resolve manually first** —
    explicit human choice per task before the bulk migration runs.
  - **c) Add a new `secondary_arc_ids:` field on tasks** — formalises the
    intersection, but adds complexity to the schema this inception just
    introduced. Probably scope creep.
- **Recommendation:** Option (b). With only 2 affected tasks and a meaningful
  cross-arc relationship, the 60-second manual choice per task is the right
  trade-off; option (a) silently degrades the data, option (c) inflates scope.
- **Human's answer:** _pending_
- **Decided at:** _pending_

## 4. Build-slice manifest (filled after Q1/Q2/Q3 resolved)

Each slice maps to a T-NEW-<n> in the handoff §7. The manifest below is the
**proposed** sequencing — finalise after Q1/Q2/Q3 answers, then run the
`fw task create` invocations as a checklist.

| Slice | Task (proposed name) | Type | Deps | One-line scope |
|---|---|---|---|---|
| T-NEW-2 | Add `arc_id:` to task frontmatter schema | build | T-1846 | Field + template + CLAUDE.md doc |
| T-NEW-3 | One-shot migration `tags:[arc:*]` → `arc_id:` | build | T-NEW-2 | Idempotent script + Q2 report + Q3 handling |
| T-NEW-4 | Mark `constituent_tasks:` deprecated | build | T-NEW-3 | Comment + deprecation note in T-1653 artefact |
| T-NEW-5a | Lifecycle state machine refactor (back-end) | build | T-1846 | Add `draft` + `abandoned` to `lib/arc.sh` |
| T-NEW-5b | Lifecycle UI in Watchtower | build | T-NEW-5a | `/arcs` filter tabs per state |
| T-NEW-6 | `fw arc abandon` CLI verb | build | T-NEW-5a | Mirrors `fw arc close` §ACD pattern |
| T-NEW-7 | Stale-arc audit warning (30d) | build | T-NEW-3 | New audit check + Watchtower badge |
| T-NEW-8 | Anchor-task existence audit check | build | T-1846 | Warning only, never block |
| T-NEW-9 | Write `012-ArcSystem.md` + update `FRAMEWORK.md` | build | T-NEW-2, T-NEW-3, T-NEW-5*, T-NEW-6 | Promote Arc to canonical doc set |

**Note on T-NEW-5 split:** handoff sized as `novel_mechanism: yes / verdict: needs-split`.
Splitting into 5a (back-end state machine in `lib/arc.sh`) and 5b (Watchtower rendering)
lets the refactor land before any UI regression risk.

## 5. Verification deltas vs. handoff §11.5 (executed 2026-05-15)

| Check | Status | Notes |
|---|---|---|
| 12 cited paths exist | PASS | All present |
| T-1653, T-1661, T-1662 status | PASS | All `work-completed` in `.tasks/completed/` |
| 4 arcs `in-progress` | PASS | dispatch-safety, orchestrator-rethink, embeddings-strategy, project-shape-resilience |
| No superseding handoff | PASS | only the file just written matches |
| A1 quiescent | PASS | only T-1845 completion churn in last hour, no arc-tagged task editing |
| A2 schema-reject grep | PASS | zero hits |
| A3 status-at-create | PASS | `lib/arc.sh:232` literal write |
| A4 three-citation spot-check | PASS | matches verbatim |
| Tools on PATH | PASS | fw, git, grep, python3, bash |
| Q3 prevalence | 3 tasks | trivially case-by-case |

## 6. Dialogue Log

### Entry 0 — Pre-action checks (2026-05-15 — agent)

- **Q:** §11.5 verification of handoff before any task creation.
- **Outcome:** All checks PASS. Filed inception. Awaiting Q1/Q2/Q3 from human.

### Entry 1 — Q1 (pending)

- **Q (agent → human):** `arc_id:` validation tier — Tier-1 block, or audit warning?
- **A (human):** _awaiting_
- **Decided at:** _pending_

### Entry 2 — Q2 (pending)

- **Q (agent → human):** Committable migration report at `.context/audits/arc-id-migration-<date>.yaml`?
- **A (human):** _awaiting_
- **Decided at:** _pending_

### Entry 3 — Q3 (pending)

- **Q (agent → human):** Multi-arc-tagged task handling (alphabetical-first auto, or block migration, or other)?
- **A (human):** _awaiting_
- **Decided at:** _pending_

## 7. Out-of-scope reminders (do NOT do under this inception)

- Do not implement T-NEW-2..9. File them as separate build tasks after decide-go.
- Do not resolve the other five parked T-1653 questions (multi-arc focus,
  prompt injection Phase B, arc nesting, decisions cross-linking,
  anchor-task-as-board-state). They stay parked.
- Do not introduce any scoring / prioritisation / value-driver mechanic. That's
  HANDOFF-value-prioritisation-2026-05-15.
- Do not change `fw arc close` behaviour. `--demo` gate stays as-is.
- Do not force-migrate the four existing arcs to new states. They stay `in-progress`.

## 8. Next action

The next agent action is to surface this inception to the human via:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1846
```

That command opens a Watchtower review page with the recommendation, the handoff
content, and the three questions. The human's answers go into the Dialogue Log
above; the human's decide-go closes the inception.
