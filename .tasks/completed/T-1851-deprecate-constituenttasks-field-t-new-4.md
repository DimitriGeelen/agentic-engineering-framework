---
id: T-1851
name: "Deprecate constituent_tasks: field (T-NEW-4)"
description: >
  lib/arc.sh arc_create stops writing constituent_tasks: [] for new arcs. Existing arc YAMLs retain their entries untouched (legacy data preserved). docs/reports/T-1653-arcs-as-first-class.md gets deprecation note linking to HANDOFF-arc-grooming-2026-05-15. CLAUDE.md/FRAMEWORK.md references updated. Deps: T-NEW-3.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [build, cleanup, deprecation, T-NEW-4]
components: []
related_tasks: [T-1846, T-1847, T-1653]
arc_id: arc-grooming
created: 2026-05-15T14:52:54Z
last_update: 2026-05-18T09:40:20Z
date_finished: 2026-05-16T21:25:15Z
---

# T-1851: Deprecate constituent_tasks: field (T-NEW-4)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `lib/arc.sh` `arc_create` no longer writes `constituent_tasks: []` for new arcs (verified by creating a test arc and grepping its YAML)
- [x] Existing arc YAMLs retain their `constituent_tasks:` entries untouched (legacy data preserved per D-Immutability)
- [x] `docs/reports/T-1653-arcs-as-first-class.md` has deprecation note in or near Q1 section linking to `HANDOFF-arc-grooming-2026-05-15`
- [x] References to `constituent_tasks` in `CLAUDE.md` / `FRAMEWORK.md` / agent docs are updated or removed (CLAUDE.md/FRAMEWORK.md grep returned 0; `lib/arc.sh` arc_help text updated with T-1851 deprecation pointer)
- [x] Bats coverage: `tests/unit/arc_create_no_constituent_tasks.bats` — 5/5 pass (new-arc omission + legacy-arc append preserved + arc_tag non-recreation)
- [x] Render-without-`constituent_tasks` contract pinned by Playwright (per T-971/T-1575): `tests/playwright/test_arcs_renders_without_constituent_field.py` writes a synthetic arc YAML omitting the legacy field, hits `/arcs/<slug>`, asserts 200 + no "Traceback" + no "Internal Server Error" + the arc's name renders. Plus a regression guard pinning legacy `/arcs/arc-grooming` still renders. Re-classified from Human [REVIEW]: post-migration rendering is fully mechanical — fixture creates the post-migration shape; the previously-recommended manual `fw arc create` + delete is now automated.
- [x] [REVIEWER] Deprecation banner mechanical structure on `docs/reports/T-1653-arcs-as-first-class.md`: references T-1851 + T-1850 explicitly, links to `docs/reports/T-1846-arc-grooming-inception.md` and `.context/handoffs/HANDOFF-arc-grooming-2026-05-15.md`, and both link targets exist. Re-classified from Human [REVIEW] by T-1894 — mechanical claims (references + link-target existence) lifted to verification commands below; only "reads as obvious superseded note" remains Human.

### Human
- [x] [REVIEW] Deprecation banner in `docs/reports/T-1653-arcs-as-first-class.md` reads as an obvious "this design has been superseded in part" note
  **Steps:**
  1. Open the file in a Markdown viewer or VSCode preview
  2. Read the top banner block (before "## What the user asked for")
  **Expected:** The voice + framing tells a fresh reader "supersedes" without them needing to chase the references. (Mechanical structure — T-1851 / T-1850 refs + link-target existence — is now verified by Agent AC + `## Verification`, see T-1894.)
  **If not:** Edit the banner prose and reopen.

## Verification

# T-1851 verification commands (scoped per L-291/L-393/L-387 — avoid grep -q under pipefail).
bash -n lib/arc.sh
bats tests/unit/arc_create_no_constituent_tasks.bats
test "$(grep -c '^constituent_tasks:' lib/arc.sh)" -eq 0
test "$(grep -c 'T-1851' docs/reports/T-1653-arcs-as-first-class.md)" -ge 1
# Render-without-constituent_tasks pinned by Playwright (re-classified Human [REVIEW] → Agent):
python3 -m pytest tests/playwright/test_arcs_renders_without_constituent_field.py -q
# T-1894 re-class: mechanical halves of deprecation-banner Human AC lifted to Agent AC.
test "$(grep -c 'T-1850' docs/reports/T-1653-arcs-as-first-class.md)" -ge 1
test -f docs/reports/T-1846-arc-grooming-inception.md
test -f .context/handoffs/HANDOFF-arc-grooming-2026-05-15.md
# Banner block references both T-1851 + T-1850 within the first 30 lines
test "$(head -30 docs/reports/T-1653-arcs-as-first-class.md | grep -c 'T-185[01]')" -ge 2

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

### 2026-05-16 — read-surface absence-tolerance verified before mutation
- **What changed:** Before removing the field from `arc_create`, audited every reader to confirm graceful handling. `web/blueprints/arcs.py:123,228` uses `data.get("constituent_tasks") or []`; `agents/audit/audit.sh:3553` uses `grab("constituent_tasks", "[]")` with the T-1813 tag fallback. Both already coded defensively — no read-surface edits required, only the write site.
- **Plan impact:** AC #4 ("references in CLAUDE.md/FRAMEWORK.md/agent docs updated or removed") simplified — CLAUDE.md/FRAMEWORK.md had 0 references, only `lib/arc.sh` `arc_help` text needed soft-deprecation wording.
- **Triggered:** No new task. AC #4 closed as "already absent in top-level governance docs; lib/arc.sh help text amended."

### 2026-05-16 — audit tag-fallback blindness on migrated tasks (follow-up surface)
- **What changed:** `agents/audit/audit.sh:3558` T-1813 fallback scans for `tags:` containing `arc:<slug>`. T-1850 stripped `arc:*` tags from 162 migrated tasks (replacing them with `arc_id:` frontmatter). Consequence: audit's arc-completion check sees zero constituent tasks for any arc whose population came from the T-1850 migration, even though `arc_id:` tells the truth. Behaviour today is "silent no-warn" (not a false alarm) — but the completion-threshold check is now blind.
- **Plan impact:** Out of T-1851 scope (write-side deprecation only). The audit blindness predates this slice's change — the moment T-1850 stripped tags, the fallback went blind regardless of whether `arc_create` writes the field.
- **Triggered:** Follow-up candidate for arc-grooming arc — third audit-fallback layer that scans `arc_id:` frontmatter (sibling of T-1849 hook + T-1856 anchor check). Not filed yet; will surface to operator in Recommendation.

### 2026-05-16 — fixture-test exposed _arc_next_numeric_id octal-parse edge
- **What changed:** Initial smoke fixture used `arc-099` as a legacy arc id. `_arc_next_numeric_id` in `lib/arc.sh:94` tried to compute `099 + 1` and `bash` treated `099` as octal — "value too great for base." Harmless (the function still returned a valid next id), but it's a real latent bug if any future arc number reaches `008+`.
- **Plan impact:** Test fixture changed to `arc-100` to dodge octal. Octal-parse fix is out of T-1851 scope.
- **Triggered:** Latent-bug observation. Could become a 1-line `10#` prefix fix in `_arc_next_numeric_id`. Not filed; logged here for the next arc.sh-touching slice to pick up cheaply.

## Decisions

### 2026-05-16 — leave legacy data in place rather than scrub
- **Chose:** D-Immutability — `constituent_tasks:` entries already committed to in-tree arcs stay untouched.
- **Why:** Two readers already merge legacy + tag/arc_id fallback; scrubbing legacy data risks losing forensic trail (which task joined which arc at which point) for zero functional benefit.
- **Rejected:** "Strip the field from all 5 in-tree arcs" — would destroy historical record, force readers to lose the merge path, and conflict with the T-1848 D-Immutability axiom we've just established for the same registry.

## Recommendation

**2026-05-18 T-1894 re-class note:** A mechanical sub-claim of this task's Human  AC has been split into a new Agent AC (with verification command in ). Only the genuine taste/judgment claim remains Human. See T-1894 for the classification audit and CLAUDE.md §AC Classification Guidance for the rule.

**Recommendation:** GO

**Rationale:** T-1851 (T-NEW-4) was a bounded write-side deprecation. All 4 Agent ACs satisfied:
- `lib/arc.sh` `arc_create` heredoc no longer emits `constituent_tasks: []` (line ~348 — removed).
- `arc_tag` and `arc_help` text updated with T-1851 deprecation pointers; `arc_tag`'s existing `if not m: sys.exit(0)` guard makes the call a silent no-op on new arcs, so the verb stays compatible across legacy and new arcs without code-path branching.
- Top-level governance docs (`CLAUDE.md`, `FRAMEWORK.md`) had 0 references — nothing to update there.
- Design-doc deprecation note added in `docs/reports/T-1653-arcs-as-first-class.md` (banner near top + inline notes at MVP scope items 1, 2-tag, and 6-migration).
- 5/5 bats coverage in `tests/unit/arc_create_no_constituent_tasks.bats`: new arc clean, legacy arc append preserved, arc_tag non-recreation, in-tree D-Immutability sanity, `bash -n`.

The Evolution section captures one observability follow-up (audit's T-1813 tag-fallback is blind to T-1850-migrated tasks because the migration stripped `arc:*` tags) and one latent bug (`_arc_next_numeric_id` parses zero-padded ids as octal — surfaced by my smoke fixture, not a regression).

**Evidence:**
- `lib/arc.sh:341-358` — heredoc no longer contains `constituent_tasks:`
- `bats tests/unit/arc_create_no_constituent_tasks.bats` → 1..5, all `ok`
- `grep -c '^constituent_tasks:' lib/arc.sh` → 0
- `grep -c 'T-1851' docs/reports/T-1653-arcs-as-first-class.md` → ≥1
- `grep -rln "constituent_tasks" CLAUDE.md FRAMEWORK.md` → no matches (already absent)

**Follow-up candidates (do NOT block T-1851 closure):**
1. **Audit arc_id fallback** — extend `agents/audit/audit.sh:3558` to scan task frontmatter for `arc_id: <slug|arc-NNN>` after the existing T-1813 `arc:*` tag fallback. Closes the post-T-1850 blindness.
2. **`_arc_next_numeric_id` octal-parse fix** — single-line `10#` prefix in `lib/arc.sh:94`. Cheap and unrelated to deprecation.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:52:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1851-deprecate-constituenttasks-field-t-new-4.md
- **Context:** Initial task creation

### 2026-05-16T09:28:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9f29f033
- **Timestamp:** 2026-06-02T15:00:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-16T21:25:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
