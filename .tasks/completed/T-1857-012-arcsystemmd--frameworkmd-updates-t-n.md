---
id: T-1857
name: "012-ArcSystem.md + FRAMEWORK.md updates (T-NEW-9)"
description: >
  Write 012-ArcSystem.md at repo root mirroring 010-TaskSystem.md structure: Overview, Arc Structure (file format + lifecycle), Arc Fields Reference, Statuses (draft/in-progress/closed/abandoned), fw arc CLI, Relation to Tasks, Relation to Other Concepts (Inception, Horizon, Learnings, Directives, Component Fabric), D-Immutability. Update FRAMEWORK.md: glossary Arc entry, Quick Reference rows for fw arc create/abandon/close/focus/show, Arc System section paralleling Task System. Deps: T-NEW-1.5, T-NEW-2, T-NEW-3, T-NEW-5*, T-NEW-6 (doc describes post-refactor state).

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [build, documentation, canonical, T-NEW-9]
components: [tests/playwright/test_arcs_lifecycle_tabs.py, web/blueprints/arcs.py, web/templates/arcs_index.html]
related_tasks: [T-1846, T-1847, T-1653]
arc_id: arc-grooming
created: 2026-05-15T14:53:22Z
last_update: 2026-05-18T09:41:02Z
date_finished: 2026-05-16T22:34:46Z
---

# T-1857: 012-ArcSystem.md + FRAMEWORK.md updates (T-NEW-9)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `012-ArcSystem.md` exists at repo root with sections: Overview, Arc Structure, Arc Fields Reference, Statuses (Four-State Lifecycle), Dual Identity (slug ↔ arc-NNN), D-Immutability Axiom, Task ↔ Arc Membership, fw arc CLI, Audit Checks, Watchtower Surface, Relation to Tasks, Relation to Other Concepts (Inception, Horizon, Learnings, Directives, Component Fabric), D-Immutability worked example, Why arcs exist
- [x] `FRAMEWORK.md` glossary contains an `Arc` entry (also added `D-Immutability` entry)
- [x] `FRAMEWORK.md` Quick Reference contains rows for: `fw arc create`, `fw arc abandon`, `fw arc close`, `fw arc focus`, `fw arc show` (plus `fw arc start`, `fw arc list` as bonus)
- [x] `FRAMEWORK.md` has Arc System section paralleling Task System (inline section with lifecycle diagram + membership + D-Immutability summary, links to `012-ArcSystem.md` for full reference)
- [x] `grep -c -i 'arc' FRAMEWORK.md` returns 30 (well above the >5 threshold — doc density confirms first-class treatment)
- [x] Content describes the post-refactor state: arc-NNN sequential immutable IDs (T-1848), four-state lifecycle with `fw arc start` + `fw arc abandon` (T-1852/T-1854), stale + anchor-task audit checks (T-1855/T-1856), `arc_id:` task field with PreToolUse validation hook (T-1849), tag-migration history (T-1850), `constituent_tasks` deprecation (T-1851), Watchtower lifecycle filter tabs (T-1853)
- [x] [REVIEWER] CLI section in `012-ArcSystem.md` mentions every verb that `bin/fw arc help` exposes (no doc-vs-help drift). Verb list: `create, start, focus, list, show, tag, close, abandon, migrate`. Each appears in 012-ArcSystem.md at least once. Re-classified from Human [REVIEW] by T-1894 — mechanical verb-cross-check is deterministic; only the "reads cleanly" / "summary is faithful" judgment remains Human.

### Human
- [x] [REVIEW] `012-ArcSystem.md` reads cleanly as the canonical Arc System reference + `FRAMEWORK.md`'s inline summary is faithful
  **Steps:**
  1. Open `012-ArcSystem.md` in a Markdown viewer.
  2. Read Overview + Four-State Lifecycle ASCII diagram + Dual Identity table — does it land?
  3. Scan FRAMEWORK.md's Arc System section — does it give a complete enough orientation that someone reading only FRAMEWORK.md walks away with the right mental model?
  **Expected:** A new operator could orient using only these two surfaces without falling back to source. (Mechanical CLI ↔ `fw arc help` parity is now verified by Agent AC + `## Verification`, see T-1894.)
  **If not:** Note which section reads thin or feels wrong and reopen — both files are cheap to revise.

## Verification

# T-1857 verification (docs-only — pure file/grep checks, no pipefail risk).
test -f 012-ArcSystem.md
test "$(grep -c '^## ' 012-ArcSystem.md)" -ge 9
test "$(grep -c '^## ' FRAMEWORK.md)" -ge 10
test "$(grep -c -i 'arc' FRAMEWORK.md)" -ge 6
test "$(grep -cE 'fw arc (create|abandon|close|focus|show)' FRAMEWORK.md)" -ge 5
test "$(grep -c '\*\*Arc\*\*' FRAMEWORK.md)" -ge 1
test "$(grep -c 'arc-NNN' 012-ArcSystem.md)" -ge 3
test "$(grep -c 'D-Immutability' 012-ArcSystem.md)" -ge 3
test "$(grep -c 'fw arc abandon' 012-ArcSystem.md)" -ge 2
# T-1894 re-class: every verb from `fw arc help` is documented in 012-ArcSystem.md
# (CLI-vs-doc drift check, was Human [REVIEW] → now Agent).
for v in create start focus list show tag close abandon migrate; do test "$(grep -cE "fw arc $v\\b|\\b$v <" 012-ArcSystem.md)" -ge 1 || { echo "MISSING: $v"; exit 1; }; done

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

### 2026-05-17 — doc absorbs *every* arc-grooming slice shipped during the arc

- **What changed:** T-1857's original ACs listed 6 sections; the actual doc landed with 13 (added Dual Identity, Task ↔ Arc Membership, Audit Checks, Watchtower Surface, D-Immutability worked example, Why arcs exist). Reason: the arc shipped more than the original plan scoped. T-1849 (arc_id field), T-1850 (tag migration), T-1851 (constituent_tasks deprecation), T-1853 (Watchtower tabs) each generated facts the doc would be incomplete without.
- **Plan impact:** Section count exceeded spec. ACs were updated to reflect the larger surface. Original "Relation to Other Concepts" subsections preserved verbatim.
- **Triggered:** No new task. Confirms the §ACD pattern from T-1717: "the understanding of what we need and want evolves with the process of materialisation." Doc was always going to absorb whatever shipped — better to write it last in the arc, not first.

### 2026-05-17 — FRAMEWORK.md gets an inline summary + link, not just a link

- **What changed:** Originally considered making FRAMEWORK.md's Arc System section a one-line stub pointing at `012-ArcSystem.md`. Decided against — the inline 60-line summary (with ASCII lifecycle diagram, membership rule, D-Immutability statement) lets someone scanning only FRAMEWORK.md walk away with the right mental model. `012-` is the deep-dive; FRAMEWORK.md is the orientation. Both useful.
- **Plan impact:** FRAMEWORK.md grew ~60 lines. Doc-density grep on `arc` jumped from ~5 to 30. Glossary gained 2 entries (Arc, D-Immutability) instead of just 1.
- **Triggered:** No new task. Pattern lock: subsystem docs (012-, 030-) inherit a *summarised* anchor in FRAMEWORK.md, not a stub.

### 2026-05-17 — "Why arcs exist" anchored in the arc-grooming arc itself

- **What changed:** The doc's tail section "Why arcs exist" uses arc-grooming as the concrete example — 7 slices, 2 days, 1 coherent groom. Recursion: the doc explaining arcs uses the arc that produced the doc as its motivating example.
- **Plan impact:** Strengthens the doc — first-person evidence beats abstract motivation.
- **Triggered:** No new task. Pattern lock: when a meta-feature docs itself, use its own birth as the worked example.

## Decisions

### 2026-05-17 — 012-ArcSystem.md as the canonical doc (vs inline-only in FRAMEWORK.md)

- **Chose:** Standalone numbered doc at repo root, mirroring `010-TaskSystem.md`'s structure and slot.
- **Why:** The arc system is now first-class alongside the task system. A standalone doc gets its own retrieval surface (`fw ask "arc lifecycle"`, `fw docs 012`, `/docs/012-ArcSystem` in Watchtower), can grow without bloating FRAMEWORK.md, and signals "this is a peer concept, not a subsection of tasks."
- **Rejected:** Inline-only in FRAMEWORK.md (would bloat the orientation doc and bury detail); separate `docs/arcs.md` (breaks the numbered-doc-at-root convention shared with 001-, 005-, 010-, 011-, 015-, 020-, 025-, 030-).

### 2026-05-17 — Lifecycle ASCII diagram (vs Mermaid / image)

- **Chose:** Plain ASCII diagram with Unicode box-drawing chars in a code fence.
- **Why:** Renders identically in any Markdown viewer, in `cat`, in `less`, in Watchtower's renderer. No mermaid dependency, no image asset to track. Diff-friendly. Total cost: 8 lines.
- **Rejected:** Mermaid (would require a Mermaid renderer; framework's Watchtower doesn't have one); SVG / image (asset to version-control + scale-up cost; loses grep-ability of state names).

### 2026-05-17 — `grep -c -i 'arc'` threshold ≥ 6 (not >5 as spec'd)

- **Chose:** `>= 6` in the Verification block, matching spec's `> 5` intent.
- **Why:** `>5` in shell `test` would be `-gt 5` ≡ `>= 6`. Wrote it as `-ge 6` for clarity. Actual count is 30 — well above the floor.
- **Rejected:** Higher thresholds (would risk false-fail on legitimate doc edits); content matching (more brittle than density check for a quick sanity test).

## Recommendation

**2026-05-18 T-1894 re-class note:** A mechanical sub-claim of this task's Human  AC has been split into a new Agent AC (with verification command in ). Only the genuine taste/judgment claim remains Human. See T-1894 for the classification audit and CLAUDE.md §AC Classification Guidance for the rule.

**Recommendation:** GO

**Rationale:** T-1857 (T-NEW-9) is the final arc-grooming slice — the canonical documentation slot for the Arc System. `012-ArcSystem.md` ships as a 290-line standalone doc with 13 top-level sections (Overview, Arc Structure, Arc Fields Reference, Statuses, Dual Identity, D-Immutability Axiom, Task ↔ Arc Membership, fw arc CLI, Audit Checks, Watchtower Surface, Relation to Tasks, Relation to Other Concepts, D-Immutability worked example, Why arcs exist). FRAMEWORK.md gains a 60-line inline Arc System section (with the same lifecycle diagram), two Glossary entries (Arc, D-Immutability), and seven `fw arc` Quick Reference rows.

The doc absorbs every prior arc-grooming slice's structural shipped state:
- T-1848 (sequential immutable arc-NNN IDs + dual identity)
- T-1849 (arc_id frontmatter field + PreToolUse validation hook)
- T-1850 (162-task tag→arc_id migration)
- T-1851 (constituent_tasks deprecation)
- T-1852 (four-state lifecycle + fw arc start)
- T-1853 (Watchtower lifecycle filter tabs + stale badge)
- T-1854 (fw arc abandon CLI verb)
- T-1855 (stale-arc audit warning)
- T-1856 (anchor_task existence audit check)

All 6 Agent ACs satisfied. The doc is testable (9 grep-based assertions in Verification — section count, doc-density floor, glossary entry presence, CLI verb coverage), the arc closure is now visible (one canonical reference instead of folklore across nine commits), and the loop is sealed: anyone landing on the framework from this point on can read 012-ArcSystem.md and grasp the model end-to-end.

**Evidence:**
- `012-ArcSystem.md` — 290 lines, 13 `## ` headers, present and parseable.
- `FRAMEWORK.md` — 30 occurrences of `arc` (above floor of 6), 7 `fw arc <verb>` rows (above floor of 5), `**Arc**` glossary entry present.
- `bin/fw arc help` output matches the doc's `fw arc CLI` section (no drift between code and doc).
- Doc cross-references every shipped slice (T-1848 through T-1856) — traceable to commits.

**Follow-up:**
- This is the **last** arc-grooming arc slice. Once Human AC review is complete, the **arc-grooming arc itself is closeable** via `fw arc close arc-grooming --demo <evidence> --decision "shipped"`. Per the T-1671 §ACD agent-gate, that close belongs to the human via Watchtower. Suggested `--demo` evidence: this very doc (`012-ArcSystem.md`) — the headline mechanic was "make arcs first-class", and the doc IS that mechanic firing.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:53:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1857-012-arcsystemmd--frameworkmd-updates-t-n.md
- **Context:** Initial task creation

### 2026-05-16T22:29:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-a8c092c9
- **Timestamp:** 2026-05-18T10:09:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-16T22:34:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
