---
id: T-1848
name: "Sequential arc-NNN immutable IDs (T-NEW-1.5)"
description: >
  Introduce arc-NNN sequential ID scheme on .context/arcs/*.yaml: id field with arc-NNN value, counter persisted, 4 existing arcs migrated to arc-001..004, arc-grooming gets arc-005, Watchtower URL routing accepts slug + ID. Encodes D-Immutability in lib/arc.sh comments (no renumber, no reuse). Foundation slice — T-NEW-2 (arc_id validation) needs stable target. Anchor: T-1846 inception decide-go GO.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [build, arc:arc-grooming, schema-migration, arc-system, immutability, T-NEW-1.5]
components: ["lib/arc.sh", "web/blueprints/arcs.py", ".context/arcs/"]
related_tasks: [T-1846, T-1847, T-1653, T-1661]
created: 2026-05-15T14:51:15Z
last_update: 2026-05-15T14:51:15Z
date_finished: null
---

# T-1848: Sequential arc-NNN immutable IDs (T-NEW-1.5)

## Context

Foundation slice of arc-grooming. Implements T-NEW-1.5 from `docs/reports/T-1846-arc-grooming-inception.md` §4. Without sequential immutable IDs, T-NEW-2's Tier-1 validation block (Q1 answer) has no stable target to validate against — slug renames would silently break references.

Anchor: T-1846 decide-go GO.

## Acceptance Criteria

### Agent
- [ ] `lib/arc.sh` allocates next sequential `arc-NNN` ID on `fw arc create`; counter persisted (computed from max `id:` across existing arcs, or a `.context/arcs/.next-id` counter)
- [ ] 4 existing arcs migrated: `dispatch-safety`→`arc-001`, `embeddings-strategy`→`arc-002`, `orchestrator-rethink`→`arc-003`, `project-shape-resilience`→`arc-004`. `arc-grooming` becomes `arc-005`
- [ ] Each arc YAML grows an `id:` field with the `arc-NNN` value; slug remains as filename for human readability
- [ ] Watchtower `/arcs/<slug>` AND `/arcs/<id>` both resolve to the same arc page
- [ ] `lib/arc.sh` comment block encodes D-Immutability invariants (no renumber, no reuse; abandonment is status not deletion; manual rm allowed only for zero-reference fresh-mistake cases)
- [ ] `bin/fw audit` structure section passes after migration (5 arcs each with valid `id: arc-NNN`)
- [ ] Migration is atomic single commit — all 4 existing arc YAMLs gain their `id:` field together

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
