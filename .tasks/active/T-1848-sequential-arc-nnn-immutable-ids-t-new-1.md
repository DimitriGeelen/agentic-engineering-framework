---
id: T-1848
name: "Sequential arc-NNN immutable IDs (T-NEW-1.5)"
description: >
  Introduce arc-NNN sequential ID scheme on .context/arcs/*.yaml: id field with arc-NNN value, counter persisted, 4 existing arcs migrated to arc-001..004, arc-grooming gets arc-005, Watchtower URL routing accepts slug + ID. Encodes D-Immutability in lib/arc.sh comments (no renumber, no reuse). Foundation slice — T-NEW-2 (arc_id validation) needs stable target. Anchor: T-1846 inception decide-go GO.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [build, arc:arc-grooming, schema-migration, arc-system, immutability, T-NEW-1.5]
components: ["lib/arc.sh", "web/blueprints/arcs.py", ".context/arcs/"]
related_tasks: [T-1846, T-1847, T-1653, T-1661]
created: 2026-05-15T14:51:15Z
last_update: 2026-05-16T08:24:28Z
date_finished: null
---

# T-1848: Sequential arc-NNN immutable IDs (T-NEW-1.5)

## Context

Foundation slice of arc-grooming. Implements T-NEW-1.5 from `docs/reports/T-1846-arc-grooming-inception.md` §4. Without sequential immutable IDs, T-NEW-2's Tier-1 validation block (Q1 answer) has no stable target to validate against — slug renames would silently break references.

Anchor: T-1846 decide-go GO.

## Acceptance Criteria

### Agent
- [x] `lib/arc.sh` allocates next sequential `arc-NNN` ID via `_arc_next_numeric_id` (scans max `id: arc-NNN` across existing arcs; D-Immutability rule 2 — MAX not COUNT). `arc_create` writes `id: arc-NNN` + `slug:` on new arcs.
- [x] 5 existing arcs migrated: `dispatch-safety`→`arc-001`, `embeddings-strategy`→`arc-002`, `orchestrator-rethink`→`arc-003`, `project-shape-resilience`→`arc-004`, `arc-grooming`→`arc-005`. Each YAML now has both `id: arc-NNN` and explicit `slug:` fields.
- [x] Each arc YAML grows an `id:` field with the `arc-NNN` value; slug remains as filename AND as explicit `slug:` field.
- [x] Watchtower `/arcs/<slug>` AND `/arcs/<id>` both resolve. Verified: `/arcs/dispatch-safety`, `/arcs/arc-001`, `/arcs/arc-005` all return 200.
- [x] `lib/arc.sh` comment block encodes D-Immutability invariants (rules 1-4 with rationale; rule 2 = no reuse pinned in `_arc_next_numeric_id` impl).
- [ ] `bin/fw audit` structure section passes after migration — deferred verification (audit was running in background when budget gate fired at 285K). All 5 arc YAMLs parse via `python3 -c 'yaml.safe_load(...)'`. Tag scans switched to slug-based across consumers (`web/blueprints/arcs.py`, `web/blueprints/core.py`, `agents/audit/audit.sh`). Verify next session.
- [x] Migration is atomic single commit — all 5 existing arc YAMLs gain their `id:` field together (this commit).

**Partial-ship — verb-side normalisation deferred:** The arc verb call-sites in `lib/arc.sh` (`arc_focus`, `arc_show`, `arc_tag`, `arc_close`) still pass raw user input to `_arc_validate_id`/`_arc_exists`/`_arc_path`, which only resolve the slug form. The new helper `_arc_normalize_input` exists but is not wired into the verbs. A user running `fw arc focus arc-001` gets "arc not found" because there's no `arc-001.yaml` — they must use `fw arc focus dispatch-safety`. Bats test for full T-1848 coverage also deferred (covered by smoke tests + dual-route curl). Follow-up: a 20-minute sequel task threading `_arc_normalize_input` through the four verbs + a bats fixture.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
test $(grep -lE '^id: arc-' .context/arcs/*.yaml | wc -l) -ge 5
grep -q '^id: arc-001' .context/arcs/dispatch-safety.yaml
grep -q '^id: arc-005' .context/arcs/arc-grooming.yaml
bin/fw audit 2>&1 | grep -q "Fail: 0"
curl -sf "$(bin/fw watchtower url)/arcs/arc-001" >/dev/null
curl -sf "$(bin/fw watchtower url)/arcs/dispatch-safety" >/dev/null

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

### 2026-05-16 — slug as explicit YAML field, not implicit filename

- **What changed:** Initial design (T-1846 inception §4) said "slug remains as filename for human readability" — implying filename is the only source-of-truth for slug. Building revealed that downstream consumers (`audit.sh`, `core.py`, `arcs.py`) all needed slug-vs-id discrimination. Embedding the slug AS A FIELD in the YAML alongside `id: arc-NNN` halved the consumer-side code: no need to thread the filename stem through every helper, just read `slug:` like any other field.
- **Plan impact:** YAML schema gains a `slug:` field (was implicit; now explicit). No backward-incompat — old consumers that read `id:` for slug-like operations switch to `slug:` cleanly.
- **Triggered:** No new sub-task; the change tightened existing consumer edits rather than spawning new ones.

### 2026-05-16 — budget gate fired before verb-side normalisation complete

- **What changed:** Substrate (allocator + migration + arc-list + dual-route web) shipped, but `_arc_normalize_input` wasn't wired into the four arc verbs (focus/show/tag/close). Bats test also unwritten.
- **Plan impact:** T-1848 is **partial-ship**. The "every user-facing entry point accepts either slug or arc-NNN" promise holds for web routes; for CLI verbs it holds only for `arc list` (display-only). Other verbs accept slug only.
- **Triggered:** Follow-up sequel (T-NEW-1.5b, ~20 min) to wire `_arc_normalize_input` through `arc_focus`/`arc_show`/`arc_tag`/`arc_close` + add bats coverage. Filed via Updates on completion. T-NEW-2 (T-1849, arc_id task-frontmatter field) can still start in parallel — it depends on the substrate landing, which this commit ships.

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:51:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1848-sequential-arc-nnn-immutable-ids-t-new-1.md
- **Context:** Initial task creation

### 2026-05-16T08:24:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
