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

- **Human's answer (2026-05-15):** **Tier-1 block**, BUT conditional on a separate
  structural axiom the human surfaced — see D-Immutability below. With that axiom,
  the hostage-state failure mode I worried about is eliminated, and block-on-save
  becomes the better choice (faster feedback, structural rather than 30-min-cron).
- **Original handoff recommendation:** Audit warning, fearing the deleted-arc cascade.
  **Superseded** by D-Immutability — there is no deleted-arc cascade because arcs
  are never deleted.
- **Decided at:** 2026-05-15 (this inception)
- **Implementation note:** Validation triggers only when `arc_id:` is set and
  non-empty. Empty `arc_id:` (unassigned task) passes through. The check resolves
  against `.context/arcs/*.yaml` filenames (or `id:` field, post T-NEW-1.5).

### Q2: `arc_id:` migration — emit committable report at `.context/audits/arc-id-migration-<date>.yaml`?

- **Human's answer (2026-05-15):** **Yes, committable.** "Traceability and low cost,
  that is a yes." No serious strawman against. Matches existing `arc-bypass.jsonl`
  pattern for one-shot governance events.
- **Decided at:** 2026-05-15 (this inception)

### Q3: Multi-arc tagged tasks — what does the migration do?

- **Human's answer (2026-05-15):** Delegated to agent ("you decide"). Agent makes
  per-task call based on actual task content (option (b) executed inline).
- **Decided at:** 2026-05-15 (this inception)

**Per-task canonical-arc decisions:**

- **T-1717** → `arc_id: embeddings-strategy`
  - Evidence: title "Embeddings generation strategy for context and component fabric";
    workflow_type inception; pain points all retrieval-related (catastrophic amnesia,
    decision-quality drift, arc-coherence failure); components touched (evolution_log,
    update-task.sh, inception lib) are embeddings-substrate governance hooks;
    headline mechanic referenced by T-1719 is `fw recall → resolver routes to
    optimal embedding provider`. The `arc:orchestrator-rethink` tag is a genuine
    cross-link (G-064 closure pilot) but the WORK is embeddings-strategy.
- **T-1719** → `arc_id: embeddings-strategy`
  - Evidence: tag `T-1717-implementation` and BLOCKED-on-T-1717 status make this
    the explicit build slice of T-1717. Inherits canonical home.

**Cross-link preservation:** Both tasks retain `G-064-closure-pilot` as a regular
tag (non-arc tag, preserved through migration). `related_tasks` chain already
links to T-1696/T-1697/T-1698 (orchestrator substrate work), so the cross-arc
relationship survives via that chain.

**Initial false-positive correction:** An earlier scan flagged T-1843 as multi-arc;
its `tags:` line carries only `arc:project-shape-resilience`. Body-text mentions
of `arc:` inflated the initial regex. T-1843 is single-arc.

## 3a. Structural decisions surfaced during inception dialogue

### D-Immutability: arc records (like task records) are immutable

- **Decided 2026-05-15, human-initiated, agent-agreed.**
- **The rule:** Arc YAML records in `.context/arcs/` are **never deleted**. Once
  created, an arc persists forever. State transitions (in-progress, closed,
  abandoned, future "in-progress-again-after-resurrection") happen via the
  `status:` field; the file itself stays.
- **Arc IDs are immutable.** Once `arc-001` is allocated, it stays `arc-001` forever.
  Renaming the slug is allowed; renumbering the ID is not.
- **Why:** Matches existing task semantics — tasks in `.tasks/completed/` are never
  deleted either. Preserves traceability for cross-arc references (predecessor
  chains, G-064 closure pilots, etc.). Eliminates the "deleted-arc cascade" failure
  mode that drove the original Q1 default of audit-warning.
- **Implication for Q1:** Tier-1 block on `arc_id:` validation is now safe — there
  is no path by which a valid reference goes invalid. Block-on-save becomes the
  better choice.
- **Implication for `fw arc abandon` (T-NEW-6):** Abandonment is a status update,
  not a deletion. The arc YAML remains queryable, referenceable, and (in principle)
  re-openable.
- **Edge case:** Truly mistaken arc creation (fat-finger, agent error) with zero
  references — manual `rm` is acceptable as an escape valve at this stage (no
  traceability loss when nothing points at it). Once any reference exists,
  `fw arc abandon` is the principled path. No special "cancel" verb needed for v1.
- **Long-term archival:** At worst, arc body content could be compacted with full
  body archived (e.g. `.context/arcs/archived/`). Not needed for v1 — defer to
  when archival becomes a real concern. We have 4 arcs today.
- **Operationalised by:** T-NEW-1.5 (immutable ID allocation), T-NEW-5a (state machine
  treats abandoned as status not deletion), T-NEW-6 (`fw arc abandon` semantics).

## 4. Build-slice manifest (filled after Q1/Q2/Q3 resolved)

Each slice maps to a T-NEW-<n> in the handoff §7. The manifest below is the
**proposed** sequencing — finalise after Q1/Q2/Q3 answers, then run the
`fw task create` invocations as a checklist.

| Slice | Task (proposed name) | Type | Deps | One-line scope |
|---|---|---|---|---|
| T-NEW-1.5 | Introduce `arc-NNN` sequential ID scheme | build | T-1846 | `id:` field on arc YAML; allocate counter; migrate 4 existing arcs to arc-001..004; Watchtower URL routing accepts slug + ID; encode D-Immutability semantics |
| T-NEW-2 | Add `arc_id:` to task frontmatter schema | build | T-NEW-1.5 | Field + template + CLAUDE.md doc; **Tier-1 block on save when set + non-empty + does-not-resolve** |
| T-NEW-3 | One-shot migration `tags:[arc:*]` → `arc_id:` | build | T-NEW-2 | Idempotent script + Q2 committable report; T-1717/T-1719 → `arc_id: embeddings-strategy` (per Q3 decisions); other migrations alphabetical-default (none expected — Q3 verified only 2 multi-arc cases) |
| T-NEW-4 | Mark `constituent_tasks:` deprecated | build | T-NEW-3 | Comment + deprecation note in T-1653 artefact |
| T-NEW-5a | Lifecycle state machine refactor (back-end) | build | T-1846 | Add `draft` + `abandoned` to `lib/arc.sh`; D-Immutability: abandoned is status, not deletion |
| T-NEW-5b | Lifecycle UI in Watchtower | build | T-NEW-5a | `/arcs` filter tabs per state |
| T-NEW-6 | `fw arc abandon` CLI verb | build | T-NEW-5a | Mirrors `fw arc close` §ACD pattern; YAML stays, status flips |
| T-NEW-7 | Stale-arc audit warning (30d) | build | T-NEW-3 | New audit check + Watchtower badge |
| T-NEW-8 | Anchor-task existence audit check | build | T-1846 | Warning only, never block |
| T-NEW-9 | Write `012-ArcSystem.md` + update `FRAMEWORK.md` | build | T-NEW-1.5, T-NEW-2, T-NEW-3, T-NEW-5*, T-NEW-6 | Promote Arc to canonical doc set; document D-Immutability |

**Note on T-NEW-1.5 (new slice from inception dialogue):** Sequential `arc-NNN` IDs
adopt the same identity model as tasks. Adds one slice; the cost is bounded
(4 existing arcs to migrate; clear before/after mapping). Required by D-Immutability
and gives T-NEW-2 a stable target for the Tier-1 validation block.

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

### Entry 1 — Q1 (resolved 2026-05-15)

- **Q (agent → human):** `arc_id:` validation tier — Tier-1 block, or audit warning?
- **A (human):** Tier-1 block — BUT predicated on the immutability principle (next
  entry). Reasoning: typos are rare (programmatic references); abandonment isn't
  a deletion (immutability axiom); staging-order should not be possible (block at
  creation time forces correct sequencing — create arc first, then file tasks).
- **Agent reflection:** Agreed. With D-Immutability, the hostage-state failure mode
  is eliminated and Tier-1 block becomes the safer/faster choice. Flipped from
  original handoff recommendation (audit warning) to block.
- **Decided at:** 2026-05-15

### Entry 2 — D-Immutability surfaced (2026-05-15)

- **Q (human → agent):** Reflect on whether arc records should be deletable. "We will
  not delete these arc IDs — abandoned is a status update, arc_id and body persist;
  at worst they might be compacted with the body archived for possible reference."
- **A (agent):** Strong agreement. Matches existing task semantics (`.tasks/completed/`
  never deletes either). Preserves cross-arc traceability. Eliminates the deleted-arc
  cascade. Flagged one edge case: truly-mistaken-creation-zero-references where
  manual `rm` is the practical escape valve. No special verb needed for v1.
- **Outcome:** Captured as **D-Immutability** structural decision (§3a). Drives Q1's
  flip to Tier-1 block. Drives T-NEW-1.5 (sequential immutable IDs). Drives T-NEW-5a/
  T-NEW-6 semantics (abandoned = status, not deletion).
- **Decided at:** 2026-05-15

### Entry 3 — Q2 (resolved 2026-05-15)

- **Q (agent → human):** Committable migration report at `.context/audits/arc-id-migration-<date>.yaml`?
- **A (human):** Yes. "Traceability and low cost, that is a yes." No strong strawman against.
- **Decided at:** 2026-05-15

### Entry 4 — Q3 (resolved 2026-05-15 by delegation)

- **Q (agent → human):** Multi-arc-tagged task handling (alphabetical-first auto,
  or block migration, or new schema field)?
- **A (human):** "You decide" — delegated to agent given the agent's familiarity with
  the task content and the low-stakes/reversible nature of the call.
- **Agent decision:** Read T-1717 and T-1719 task body + frontmatter; both are
  primarily embeddings-strategy work with orchestrator-rethink cross-link via G-064
  closure pilot. **Canonical assignment: both → `arc_id: embeddings-strategy`.**
  Cross-link survives via `G-064-closure-pilot` tag and existing `related_tasks`
  chain. Migration script for general case uses alphabetical-default (none expected
  outside these 2; Q3 prevalence scan returned only these).
- **Decided at:** 2026-05-15

### Entry 5 — Sequential arc IDs surfaced (2026-05-15)

- **Q (human → agent):** Should arc IDs be sequential like task IDs (`arc-NNN` vs
  slug-as-identity)?
- **A (agent):** Yes — better identity stability (slug renames don't break refs),
  same mental model as tasks, bounded migration cost (4 arcs).
- **Outcome:** New slice T-NEW-1.5 added to manifest. Sequential IDs are also
  immutable per D-Immutability (once allocated, never renumbered, never reused).
- **Decided at:** 2026-05-15

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
