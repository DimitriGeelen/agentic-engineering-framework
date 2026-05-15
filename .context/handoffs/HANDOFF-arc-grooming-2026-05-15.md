---
handoff_id: HANDOFF-arc-grooming-2026-05-15
version: 1
supersedes: null
topic: "Arc primitive grooming — canonicalisation and lifecycle gaps that block dependent work"
research_dates: 2026-05-15..2026-05-15
researcher: "Claude (Anthropic) + Dimitri Geelen"
intended_workflow: inception
intended_scope: "An inception that closes three parked T-1653 design questions, adds two lifecycle states (draft, abandoned) needed by downstream work, adds two audit warnings, and promotes the Arc primitive into the numbered canonical doc set."
blast_radius: project
decided_by_overall: jointly
human_decisions_pending: [Q1, Q2, Q3]
depends_on_handoffs: []
related_handoffs: [HANDOFF-value-prioritisation-2026-05-15]
constraints:
  - "Cannot break the four currently-in-progress arcs (dispatch-safety, orchestrator-rethink, embeddings-strategy, project-shape-resilience) during the lifecycle refactor or the tag→field migration."
  - "Must preserve §ACD enforcement (--demo on close, agent-gate under $CLAUDECODE=1) untouched."
  - "Single refactor of lib/arc.sh state machine — both new states (draft, abandoned) land together, not in two passes."
non_goals:
  - "Building any value-driver, scoring, or prioritisation mechanic — that work belongs in HANDOFF-value-prioritisation-2026-05-15."
  - "Resolving the five other parked T-1653 questions (multi-arc focus, prompt injection Phase B, arc nesting, decisions cross-linking, anchor-task-as-board-state) — those are explicitly out of scope."
  - "Migrating existing arcs to new states. New states apply to new arcs and to new transition actions on existing arcs."
related_tasks:
  - T-1641   # umbrella-task rethink (originating context for arcs)
  - T-1653   # arcs-as-first-class research artefact (the design anchor this handoff operationalises)
  - T-1661   # arcs Phase 1 build (completed)
  - T-1662   # arcs Phase 2 Watchtower (completed)
  - T-1668   # §ACD discipline implementation
  - T-1671   # arc close agent-gate
  - T-1816   # audit YAML-parse hardening (relevant for new field acceptance)
related_files:
  - lib/arc.sh
  - web/blueprints/arcs.py
  - agents/audit/audit.sh
  - CLAUDE.md
  - FRAMEWORK.md
  - 010-TaskSystem.md
  - docs/reports/T-1653-arcs-as-first-class.md
  - .context/arcs/
  - .context/working/arc-focus.yaml
---

## 1. TL;DR

The Arc primitive is operational in `lib/arc.sh`, `web/blueprints/arcs.py`, and `.context/arcs/`, but eight design questions from T-1653 are parked in `docs/reports/T-1653-arcs-as-first-class.md` with no follow-up tasks filed, three of which block reliable arc-level reasoning. Arc is also absent from the numbered canonical doc set (`FRAMEWORK.md` contains zero arc mentions). This handoff recommends GO on an inception that resolves the three blocking questions, adds two new lifecycle states needed by downstream work, adds two audit warnings, and writes `012-ArcSystem.md`. First deliverable: file the inception task and decide the three open governance questions (Q1–Q3) before any build work proceeds.

## 2. Problem framing

T-1653 (completed) produced a design artefact for arcs-as-first-class and made the initial Arc primitive real (T-1661 build, T-1662 Watchtower). The artefact left eight design questions explicitly parked under "Open design questions" and "Follow-up scope," with the expectation that follow-up tasks would be filed against them as the need arose. They haven't been. Three of those questions now block dependent work that wants to score arcs and rank tasks within arcs — specifically, the BVP / value-prioritisation work (HANDOFF-value-prioritisation-2026-05-15). The current research session surfaced this dependency and traced the blockers back to the parked T-1653 questions. The trigger to investigate now: the value-prioritisation handoff was being scoped, hit reliability gaps in arc-level enumeration, and required clarification on whether arcs even have a stable enumeration contract today. Investigation showed they do not.

## 3. Findings

### F1: Arc is codified in code but missing from the numbered canonical doc set.

- **Evidence:** `FRAMEWORK.md` was fetched in full during research; `grep -i arc FRAMEWORK.md` returns zero hits. `010-TaskSystem.md` (fetched) does not mention arcs. The numbered root docs are 001-Vision, 005-DesignDirectives, 010-TaskSystem, 011-EnforcementConfig, 015-Practices, 020-Experiments, 025-ArtifactDiscovery, 030-WatchtowerDesign — there is no `012-ArcSystem.md` or equivalent. Arc is documented inside `CLAUDE.md` at line 746 (`### Arc Completion Discipline (G-062)`) but that is provider-specific integration, not provider-neutral spec.
- **Confidence:** high
- **Implication:** A new agent (or human) onboarding from `FRAMEWORK.md` will discover arcs only by reading `lib/arc.sh` or hitting Watchtower. This is documentation debt that this handoff should close.
- **Polarity:** negative (gap exists)

### F2: Two parallel sources for "tasks in arc X" exist; one is canonical, one is inconsistent.

- **Evidence:** Per the framework-agent briefing on Arc status (provided in conversation, with file references):
  - `tags: [arc:<id>]` on task frontmatter is the canonical mechanism — `arc_show` and `/tasks?arc=<id>` filter both read by tag scan.
  - `constituent_tasks:` field exists on arc YAML; only `orchestrator-rethink` populates it (31 entries). `dispatch-safety`, `embeddings-strategy`, and `project-shape-resilience` leave it mostly empty.
  - `arc_show` (per the briefing) ignores `constituent_tasks:` and reads by tag.
- **Confidence:** high (sourced from framework-agent briefing with file paths in `lib/arc.sh`)
- **Implication:** Per-arc task enumeration today depends on which code path is consulted. Any feature that needs reliable enumeration (BVP coherence diagnostic, stale-arc audit, abandonment recommendation) must resolve this first. T-1653 Q1 is the underlying open question.
- **Polarity:** negative (inconsistency exists)

### F3: Arc lifecycle has only two states implemented, not the three (or four) the design recommended.

- **Evidence:** Per framework-agent briefing — `lib/arc.sh` `arc_close` sets `status: closed`; `arc_create` writes `status: in-progress` directly. There is no `draft` state and no `abandoned` state. T-1653 Q7 explicitly recommended a third state (`abandoned`). Not implemented.
- **Confidence:** high
- **Implication:** Work that is dropped without delivery (no demo) has nowhere to land except `closed` (incorrect — claims work was delivered) or remaining `in-progress` forever (incorrect — claims work is ongoing). Both pollute audit. A fourth state (`draft`) is also needed by downstream BVP work for the driver-decision gate; landing both new states in one refactor avoids touching the state machine twice.
- **Polarity:** negative (gap exists)

### F4: No stale-arc detection; no anchor-task existence check.

- **Evidence:** Per framework-agent briefing on audit coverage — `agents/audit/audit.sh:550-555` (T-1816 hardening) added `.context/arcs/*.yaml` to YAML-parse validation only. No stale-arc warning, no orphan-task-tag check, no anchor-task-exists check.
- **Confidence:** high
- **Implication:** An arc whose anchor task gets renamed or deleted becomes silently broken (anchor ref dangles). An arc with no commits referencing its tasks for months has no surfacing mechanism — it sits in-progress invisibly. Both should be audit warnings, not blockers.
- **Polarity:** negative (gap exists)

### F5: Three of T-1653's eight parked questions block downstream work; five do not.

- **Evidence:** T-1653 followup questions (per framework-agent briefing): Q1 (`constituent_tasks` reconciliation), Q7 (third lifecycle state), and stale detection are operational blockers for any arc-aware scoring or prioritisation work. Q5 (multi-arc focus), Q6 (prompt injection Phase B), Q7-other (nesting), Q8 (decisions cross-linking) are nice-to-haves that don't block coherence diagnostics, enumeration reliability, or lifecycle correctness.
- **Confidence:** high
- **Implication:** Scope this handoff tightly to the blockers plus adjacent gaps (anchor-task audit, canonicalisation). The five non-blocking questions stay parked in T-1653 for future filing.
- **Polarity:** mixed (acknowledges what works as-is alongside what doesn't)

### F6: Four arcs are currently in-progress; none are quiescent.

- **Evidence:** Per framework-agent briefing — `dispatch-safety` (11 tasks, 5 active), `orchestrator-rethink` (123 tasks, 28 active), `embeddings-strategy` (3 tasks, 2 active), `project-shape-resilience` (14 tasks, 4 active). Total active tasks across all in-progress arcs: 39.
- **Confidence:** high
- **Implication:** Migration from `tags: [arc:*]` to `arc_id:` field will touch tasks belonging to all four arcs simultaneously. The migration must be idempotent and reversible. Existing arcs should not be force-migrated to new lifecycle states — they stay `in-progress`.
- **Polarity:** negative (constrains migration approach)

### F7: Audit YAML-parse accepts unknown fields without rejection.

- **Evidence:** Per framework-agent briefing — `web/blueprints/arcs.py:_read_arc` reads arbitrary fields; `arc_close` only edits `status, closed_at, decision, demo_evidence`; the audit YAML-parse check (T-1816) validates well-formed-YAML, not schema. No schema enforcement currently rejects unknown fields.
- **Confidence:** high
- **Implication:** Adding new fields (`arc_id:` on tasks; new states; new audit fields) does not require schema-loader changes. This is a green-field property the migration can exploit.
- **Polarity:** positive (enables addition without coordinated upgrade)

### F8: §ACD enforcement (`--demo` required on close, agent-gate under $CLAUDECODE=1) is the existing pattern for evidence-or-justified-absence gates.

- **Evidence:** Per framework-agent briefing — `lib/arc.sh:473-492` refuses `arc_close` without `--demo` or `--demo none --justification "<≥30 chars>"`; logs bypass to `.context/audits/arc-bypass.jsonl`. `lib/arc.sh:430-468` refuses close under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`. T-1668 §ACD Layer A and Layer B.
- **Confidence:** high
- **Implication:** The `abandoned` state's `--reason "<≥30 chars>"` gate and the downstream BVP driver-decision gate should follow the exact same shape — minimises new patterns the agent and human have to learn.
- **Polarity:** positive (reusable pattern)

## 4. Decisions made during research

### D1: Option A on `constituent_tasks` reconciliation — `arc_id:` frontmatter field on tasks is authoritative; `constituent_tasks:` deprecated.

- **Chose:** Add `arc_id:` as a dedicated single-valued optional frontmatter field on tasks. Migrate existing `tags: [arc:*]` to it. Deprecate `constituent_tasks:` on arc YAML (left in place as legacy data, not read).
- **Rejected:**
  - Option B (list authoritative, auto-populated) — requires writing to two places on every task lifecycle event; adds atomic-update burden for no gain over Option A.
  - Option C (both, with `fw arc reconcile`) — defers the contract decision rather than making it; carries the worst of both options.
- **Why:** Tag namespace is shared across `spike`, `bug`, `cross-repo`, etc. Arc membership is structural metadata, not a tag. `constituent_tasks` is inconsistently populated (only one of four arcs uses it) and `arc_show` already ignores it. Single source-of-truth via dedicated field matches existing usage; the change is mostly notational.
- **Decided-by:** jointly
- **Supports:** F2, F7
- **Reversibility:** costly (migration touches all 545+ task files; reverting would require a second migration)

### D2: Single lifecycle refactor — both new states (`draft`, `abandoned`) land together.

- **Chose:** Refactor `lib/arc.sh` once to support a four-state machine: `draft → in-progress → closed | abandoned`. Both new states ship in one task; downstream work depending on either can proceed independently after the refactor lands.
- **Rejected:** Two separate refactors (abandoned first as part of this arc, draft later as part of value-prioritisation) — touches the state machine twice, doubles the risk of breaking existing arcs.
- **Why:** Both states are needed anyway; the cost of adding two is barely higher than adding one; doing it twice is materially riskier. State machines are usually the wrong thing to revisit incrementally.
- **Decided-by:** jointly
- **Supports:** F3, F6
- **Reversibility:** costly (state machine in `lib/arc.sh` is core; reverting would require regression testing of the four existing arcs)

### D3: Backward compatibility — existing arcs stay `in-progress`; new states apply to new arcs and new transition actions.

- **Chose:** No migration of the four existing in-progress arcs to new states. `arc_create` starts writing `status: draft` for newly-created arcs going forward. `fw arc abandon` becomes available for both new and existing arcs at any time.
- **Rejected:** Force-migrate existing arcs through the new `draft` state retroactively — requires inventing a "completed draft check" for arcs that never had one, adds risk for no benefit.
- **Why:** The four current arcs already have headline mechanics, are past the conceptual phase the `draft` state is meant to gate, and have driver-decision conversations that happened informally (or not at all) outside the new mechanism. Treating them as grandfathered is honest.
- **Decided-by:** jointly
- **Supports:** F6, F3
- **Reversibility:** cheap (backward-compat is permissive; tightening later is easy)

### D4: Anchor-task missing = audit warning, not block.

- **Chose:** Add an audit check that warns when an arc's `anchor_task:` field references a task that doesn't exist (renamed, deleted, never-created). Warning only — no blocking transition, no auto-correction.
- **Rejected:** Tier-1 block on task save (would create unfixable states if an arc is deleted while tasks reference it). Auto-clearing the anchor (silently changes arc state).
- **Why:** Anchor refs go stale through legitimate causes (task supersession, renaming). The right action is human review, not framework veto.
- **Decided-by:** agent (with human confirmation in dialogue)
- **Supports:** F4
- **Reversibility:** cheap (audit check is local to `agents/audit/audit.sh`)

### D5: `draft → abandoned` and `in-progress → abandoned` share the same log.

- **Chose:** Both abandonment transitions write to `.context/audits/arc-abandon.jsonl`. Single shape, single reader.
- **Rejected:** Separate "cancelled-before-starting" log for `draft → abandoned` — adds a log file for a distinction that's derivable from the existing record (`abandoned_at - created_at` delta, or whether the arc ever had constituent commits).
- **Why:** Simplicity. Audit readers can derive the cancelled-before-starting case from existing fields. Two logs would invite divergence between them.
- **Decided-by:** human
- **Supports:** F8
- **Reversibility:** cheap (log shape is append-only; splitting later doesn't break the existing data)

### D6: Stale-arc threshold = 30 days with no commit referencing any task in the arc.

- **Chose:** Warning, not blocker. Surfaced as stale badge in Watchtower `/arcs` index and in `fw audit` output.
- **Rejected:** Stricter thresholds (e.g. 14 days) — too noisy; legitimate slow work would trip it. Looser (e.g. 90 days) — defeats the purpose.
- **Why:** 30 days is per T-1653 Q7 recommendation. No empirical basis to override.
- **Decided-by:** agent (proposes); deferred to human in Q3 if a different threshold is preferred.
- **Supports:** F4
- **Reversibility:** cheap (threshold is a constant in `agents/audit/audit.sh`)

### D7: Scope this handoff tightly — five of eight T-1653 questions stay parked.

- **Chose:** This handoff addresses Q1 (`constituent_tasks`), Q7-abandoned, and stale-detection from T-1653, plus draft state (needed by downstream) plus canonicalisation debt. The five remaining questions (multi-arc focus, prompt injection Phase B, arc nesting, decisions cross-linking, etc.) stay parked in T-1653.
- **Rejected:** Address all eight questions in one handoff — bundles unrelated work, expands blast radius, delays the items that actually block downstream.
- **Why:** Surgical scope. Each parked question is independently fileable when need arises.
- **Decided-by:** jointly
- **Supports:** F5
- **Reversibility:** cheap (the parked questions can be picked up any time)

## 4a. Assumptions

### A1: The four currently-in-progress arcs are quiescent enough during the migration window that we won't be racing live work.

- **Why we believe it:** F6 — 39 active tasks across 4 arcs is the project's current load; the migration is one-shot and idempotent, runnable in a single short window.
- **What breaks if false:** D1 migration could conflict with active task edits, producing partial states (some tasks migrated, some not, mixed within the same arc). Recovery would require re-running the migration.
- **How to test:** `git log --since="1 hour ago" .tasks/` immediately before running migration; if there is recent activity on tasks bearing `arc:*` tags, pause and coordinate. Alternatively: run migration in a session with a dedicated `fw context focus` so no other agent can be writing in parallel.
- **Confidence:** high

### A2: Adding `arc_id:` and new lifecycle states to existing YAML files does not break the audit YAML-parse check.

- **Why we believe it:** F7 — `web/blueprints/arcs.py:_read_arc` reads arbitrary fields; T-1816 audit validates well-formed-YAML, not schema. No known schema enforcement rejects unknown fields.
- **What breaks if false:** D1 and D2 deliverables fail audit immediately on commit. The whole inception's first build slice (`arc_id:` field) would be blocked.
- **How to test:** `grep -rn 'unknown.*field' agents/audit/ web/blueprints/` to confirm no strict-schema rejection exists. If present, the inception must add a schema update slice before the field-introduction slice.
- **Confidence:** high

### A3: `lib/arc.sh` `arc_create` writes `status: in-progress` directly today, and changing it to write `status: draft` won't break the four existing arcs.

- **Why we believe it:** F6, F3 — existing arcs are stored with `status: in-progress` literally in their YAML files; changing what `arc_create` writes affects only new arcs, not stored data.
- **What breaks if false:** If `arc_create` writes `status` somewhere other than the YAML file (e.g. a runtime computation), then changing it could affect existing arcs unexpectedly.
- **How to test:** `grep -A5 'status.*in-progress\|status:.*draft' lib/arc.sh` to confirm the status write happens at file-creation time, not at load-time computation.
- **Confidence:** high

### A4: The framework-agent briefing on Arc status is accurate as of 2026-05-15.

- **Why we believe it:** The briefing was generated by the framework agent in response to a structured request, with specific file paths and line numbers cited.
- **What breaks if false:** Findings F2, F3, F4, F6, F7, F8 are all derived from the briefing. If the briefing is stale or incorrect, the entire handoff's evidence base is undermined.
- **How to test:** Spot-check three citations from F2 / F3 / F8 against the actual files (`lib/arc.sh:215-227`, `lib/arc.sh:473-492`, `agents/audit/audit.sh:550-555`). If they match the briefing, treat the briefing as accurate.
- **Confidence:** medium (this is the load-bearing assumption; deserves explicit verification before task creation)

## 5. Recommendation

**GO.** Supports: F1, F2, F3, F4, F5, F7, D1, D2, D7.

First deliverable: file the inception task. Its scope is to resolve open questions Q1, Q2, Q3 (the three governance questions that affect *how* the migration and lifecycle work get done, not *whether* they get done) and then produce the constituent build-task slices. The inception is required (not bypassable via `fw work-on --type build`) because §12 triggers fire: more than 3 new files, new CLI verb (`fw arc abandon`), schema migration (task frontmatter), and a new canonical doc.

## 6. Open questions for the human

### Q1: Should `arc_id:` validation (referenced arc exists) be a Tier-1 block on task save, or an audit warning only?

- **Why it matters:** Determines whether a typo in `arc_id:` becomes immediately blocking or merely flagged. Affects the failure mode if an arc is deleted while tasks still reference it.
- **Default if unanswered:** Audit warning. Tier-1 block creates unfixable states (a deleted arc means every task referencing it can no longer be saved).
- **What we assumed during research:** Audit warning (per D-leaning above). The default and the assumption match; the question is whether the human disagrees.

### Q2: Should the `arc_id:` migration emit a committable report at `.context/audits/arc-id-migration-<date>.yaml`?

- **Why it matters:** A committable report makes the migration auditable as a single durable event. A non-committable report makes the migration look like ambient activity.
- **Default if unanswered:** Yes — emit and commit. Matches the existing pattern of one-shot governance events being audit-trailed (e.g. `arc-bypass.jsonl`).
- **What we assumed during research:** Yes, committable.

### Q3: For tasks that are multi-arc tagged today (`tags: [arc:foo, arc:bar]`), what should the migration do?

- **Why it matters:** Multi-arc tags are structurally allowed today though not by convention. The migration must do something with them. The wrong choice silently drops work-graph data.
- **Default if unanswered:** Pick the alphabetically-first `arc:*` tag as `arc_id:`, leave the other tag(s) in place, warn loudly in the migration report, and list the affected task IDs for the human to resolve case-by-case post-migration.
- **What we assumed during research:** Alphabetical-first with warning. Worth confirming: is there any multi-arc-tagged task in the current 545+ tasks? `grep -l 'arc:.*arc:' .tasks/active/*.md .tasks/completed/*.md` should answer.

## 7. Proposed task breakdown

### T-NEW-1: Inception — Arc grooming

- **Workflow type:** inception
- **Scope:** Resolve Q1/Q2/Q3 with the human, record decisions in the research artefact, and produce the constituent build-task slices listed below as concrete `fw task create` actions.
- **Operationalises:** F5, D7 (scope decision); creates the runway for all other tasks in this breakdown.
- **Acceptance Criteria — Agent:**
  - [ ] Inception artefact exists at `docs/reports/T-<id>-arc-grooming-inception.md` (covers D7)
  - [ ] Research artefact records human's answers to Q1, Q2, Q3 with timestamps (covers Q1, Q2, Q3)
  - [ ] Inception artefact lists the constituent build tasks with their `fw task create` invocations as a runnable script-or-checklist (covers F5)
  - [ ] Inception decide-go transition is recorded in the arc YAML's `decision:` field at `.context/arcs/arc-grooming.yaml`
- **Acceptance Criteria — Human:**
  - [ ] [REVIEW] Q1, Q2, Q3 answers are recorded as final, not provisional
    - **Steps:** open the inception artefact; verify each Q has the human's answer, not just the agent's default.
    - **Expected:** all three questions have explicit human-chosen values.
    - **If not:** request answers before decide-go.
- **Verification:**
  - `test -f docs/reports/T-*-arc-grooming-inception.md`
  - `test -f .context/arcs/arc-grooming.yaml`
  - `grep -l 'decision:' .context/arcs/arc-grooming.yaml`
- **Sizing:**
  - files_touched: 2 (inception artefact, arc YAML)
  - new_components: 1 (the arc YAML for arc-grooming itself)
  - novel_mechanism: no
  - est_hours: 2
  - verdict: fits-one-session
- **Dependencies:** none

### T-NEW-2: Add `arc_id:` to task frontmatter schema and template

- **Workflow type:** build
- **Scope:** Add `arc_id:` as a recognised task frontmatter field. Update `.tasks/templates/default.md` and the relevant section of `CLAUDE.md` documenting task fields.
- **Operationalises:** F2, D1.
- **Acceptance Criteria — Agent:**
  - [ ] `.tasks/templates/default.md` contains `arc_id:` field with comment explaining purpose
  - [ ] `CLAUDE.md` §Task System documents the field
  - [ ] `fw audit` passes on a hand-edited task that includes `arc_id:` (covers A2 verification)
- **Verification:**
  - `grep -q 'arc_id:' .tasks/templates/default.md`
  - `grep -q 'arc_id' CLAUDE.md`
  - `fw audit 2>&1 | grep -iv 'fail\|error'`
- **Sizing:**
  - files_touched: 2
  - new_components: 0
  - novel_mechanism: no
  - est_hours: 1
  - verdict: fits-one-session
- **Dependencies:** T-NEW-1

### T-NEW-3: One-shot migration script — `tags:[arc:*]` → `arc_id:`

- **Workflow type:** build
- **Scope:** Idempotent script that scans `.tasks/`, moves `arc:<id>` from `tags:` to `arc_id:` for each task. Produces a migration report at `.context/audits/arc-id-migration-<date>.yaml` per Q2 answer.
- **Operationalises:** F2, D1, F6, A1, Q3.
- **Acceptance Criteria — Agent:**
  - [ ] Migration script committed at `lib/migrations/arc-id-migration.sh` (or framework-agent's preferred path)
  - [ ] Running the script twice produces identical output the second time (idempotent)
  - [ ] After migration, `grep -rl 'arc:' .tasks/.../tags:' .tasks/` returns zero matches
  - [ ] Migration report exists at `.context/audits/arc-id-migration-<date>.yaml` with: count migrated, count skipped, multi-arc-tag conflicts listed by task ID
  - [ ] Multi-arc tagged tasks (per Q3 default or human-chosen behaviour) are listed in the report for human follow-up
- **Acceptance Criteria — Human:**
  - [ ] [REVIEW] Migration report's multi-arc-tag list, if non-empty, has been resolved by manual task-by-task editing
    - **Steps:** open the migration report; for each listed task ID, confirm `arc_id:` value matches intended arc.
    - **Expected:** zero remaining multi-arc tagged tasks.
    - **If not:** edit task frontmatter directly and re-run audit.
- **Verification:**
  - `bash lib/migrations/arc-id-migration.sh --dry-run` (must run without error)
  - `bash lib/migrations/arc-id-migration.sh` (must complete)
  - `bash lib/migrations/arc-id-migration.sh` (second run, must be idempotent — no further changes)
  - `! grep -rE 'tags:.*arc:' .tasks/active/ .tasks/completed/`
  - `test -f .context/audits/arc-id-migration-*.yaml`
- **Sizing:**
  - files_touched: ~545 (all task files with arc tags) + 2 new files (script, report)
  - new_components: 1 (migration script)
  - novel_mechanism: no (matches existing one-shot script patterns)
  - est_hours: 3
  - verdict: fits-one-session — but only if A1 holds (quiescent migration window)
- **Dependencies:** T-NEW-2

### T-NEW-4: Mark `constituent_tasks:` deprecated

- **Workflow type:** build
- **Scope:** Add deprecation comment to `lib/arc.sh` `arc_create` template. Update `docs/reports/T-1653-arcs-as-first-class.md` with a deprecation note. `arc_create` stops writing the field on new arcs.
- **Operationalises:** F2, D1.
- **Acceptance Criteria — Agent:**
  - [ ] `lib/arc.sh` `arc_create` no longer writes `constituent_tasks:` for new arcs (verified by inspecting newly-created arc YAML)
  - [ ] `docs/reports/T-1653-arcs-as-first-class.md` has a "Deprecated: see HANDOFF-arc-grooming-2026-05-15" note in or near the Q1 section
  - [ ] Existing arc YAML files retain their `constituent_tasks:` entries untouched (legacy data preserved)
- **Verification:**
  - Create a test arc: `fw arc create test-deprecation --headline-mechanic "..." ; grep -q 'constituent_tasks:' .context/arcs/test-deprecation.yaml && echo FAIL || echo PASS`
  - `grep -q 'Deprecated' docs/reports/T-1653-arcs-as-first-class.md`
- **Sizing:**
  - files_touched: 2
  - new_components: 0
  - novel_mechanism: no
  - est_hours: 1
  - verdict: fits-one-session
- **Dependencies:** T-NEW-3

### T-NEW-5: Lifecycle state machine refactor — add `draft` and `abandoned`

- **Workflow type:** build (sizing flags this as needs-split-or-careful: see verdict)
- **Scope:** Single refactor of `lib/arc.sh` to support a four-state machine: `draft → in-progress → closed | abandoned`. `arc_create` writes `status: draft` going forward. Watchtower `/arcs` index gains filter tabs per state. Audit YAML-parse accepts all four states.
- **Operationalises:** F3, D2, D3.
- **Acceptance Criteria — Agent:**
  - [ ] `lib/arc.sh` defines all four states as allowed values
  - [ ] Newly-created arcs land in `status: draft` (existing arcs unaffected — D3)
  - [ ] `arc_close` still works on `in-progress` arcs as before
  - [ ] Watchtower `/arcs` page renders filter tabs for: draft, in-progress, closed, abandoned (D2 visible end-to-end)
  - [ ] `agents/audit/audit.sh` YAML-parse check accepts all four states without warning (A2 verified)
  - [ ] No transition from `draft → closed` is allowed (only `draft → in-progress` or `draft → abandoned`)
- **Acceptance Criteria — Human:**
  - [ ] [REVIEW] The four existing in-progress arcs (`dispatch-safety`, `orchestrator-rethink`, `embeddings-strategy`, `project-shape-resilience`) remain in `in-progress` after the refactor
    - **Steps:** `for arc in dispatch-safety orchestrator-rethink embeddings-strategy project-shape-resilience; do grep -A1 'status:' .context/arcs/$arc.yaml; done`
    - **Expected:** all four show `status: in-progress`.
    - **If not:** revert and investigate.
- **Verification:**
  - Create a test arc and verify state: `fw arc create test-lifecycle --headline-mechanic "..." ; grep 'status:' .context/arcs/test-lifecycle.yaml | grep -q 'draft'`
  - `fw audit 2>&1 | grep -iv 'fail\|error'`
  - Confirm Watchtower renders: `curl -s http://localhost:3000/arcs | grep -i 'draft\|abandoned'` (or equivalent for whatever serving mechanism is current)
- **Sizing:**
  - files_touched: 3-5 (lib/arc.sh, web/blueprints/arcs.py, agents/audit/audit.sh, possibly template files)
  - new_components: 2 (two new states; one machine refactor)
  - novel_mechanism: yes — the state machine itself is being changed shape
  - est_hours: 4-6
  - verdict: needs-split — recommend splitting into (5a) state machine + `lib/arc.sh` write-side, and (5b) Watchtower rendering. Reasoning: `novel_mechanism: yes` forces split per v3 sizing rules; also separates back-end concern from UI concern, which lets the refactor land before any Watchtower regression risk.
- **Dependencies:** T-NEW-1

### T-NEW-6: `fw arc abandon` CLI verb

- **Workflow type:** build
- **Scope:** Implement `fw arc abandon <id> --reason "<≥30 chars>"`. Works from both `draft` and `in-progress` (per D5). Logs to `.context/audits/arc-abandon.jsonl`. Same agent-gate pattern as `fw arc close` (refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`).
- **Operationalises:** F3, F8, D5.
- **Acceptance Criteria — Agent:**
  - [ ] `fw arc abandon` rejects without `--reason` or with `--reason` text under 30 chars
  - [ ] `fw arc abandon` rejects under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (matches F8)
  - [ ] Successful invocation appends a JSON line to `.context/audits/arc-abandon.jsonl` with: arc_id, status_at_abandon (draft or in-progress), abandoned_at, abandonment_reason
  - [ ] Arc YAML reflects `status: abandoned`, `abandoned_at: <ts>`, `abandonment_reason: <text>` after invocation
- **Verification:**
  - `fw arc abandon test-lifecycle --reason "too short"` (must fail — reason under 30 chars)
  - `fw arc abandon test-lifecycle --reason "abandonment reason long enough to be meaningful"` (must succeed; arc YAML reflects new state)
  - `tail -1 .context/audits/arc-abandon.jsonl | python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); assert all(k in d for k in ["arc_id","status_at_abandon","abandoned_at","abandonment_reason"])'`
  - `CLAUDECODE=1 fw arc abandon test-other --reason "..."` (must fail with agent-gate message)
- **Sizing:**
  - files_touched: 1-2 (lib/arc.sh, possibly bin/fw routing)
  - new_components: 1 (new verb)
  - novel_mechanism: no (mirrors `fw arc close` exactly)
  - est_hours: 2
  - verdict: fits-one-session
- **Dependencies:** T-NEW-5

### T-NEW-7: Stale-arc audit warning

- **Workflow type:** build
- **Scope:** Add audit check to `agents/audit/audit.sh` that warns when an arc has `status: in-progress` and no git commit in the last 30 days references any task with `arc_id:` matching it. Surfaced in `fw audit` output and as a Watchtower badge.
- **Operationalises:** F4, D6.
- **Acceptance Criteria — Agent:**
  - [ ] `fw audit` emits a `stale arc: <id>` warning when an in-progress arc has no relevant commit in 30 days
  - [ ] The check does not fire on `draft` or `closed` or `abandoned` arcs
  - [ ] Watchtower `/arcs` index displays a "stale" badge on affected arcs
  - [ ] The 30-day threshold is configurable via a single constant (in case Q3-style review in future)
- **Verification:**
  - Construct test arc with no recent commits; run `fw audit | grep -i 'stale'`
  - Verify badge appears in Watchtower (manual or automated browser check)
- **Sizing:**
  - files_touched: 2 (agents/audit/audit.sh, web/blueprints/arcs.py)
  - new_components: 1 (new audit check)
  - novel_mechanism: no
  - est_hours: 2
  - verdict: fits-one-session
- **Dependencies:** T-NEW-3 (needs `arc_id:` field to compute "relevant commit")

### T-NEW-8: Anchor-task existence audit check

- **Workflow type:** build
- **Scope:** Add audit check that warns when an arc YAML's `anchor_task:` field references a task that doesn't exist (active or completed). Warning only, never block.
- **Operationalises:** F4, D4.
- **Acceptance Criteria — Agent:**
  - [ ] `fw audit` emits `anchor-task missing: <task-id> for arc <arc-id>` warning when applicable
  - [ ] Check passes silently for arcs without an `anchor_task:` field set
  - [ ] Check is non-blocking — `fw audit` exit code is unaffected
- **Verification:**
  - Manually set `anchor_task: T-NONEXISTENT` on a test arc; run `fw audit | grep -i 'anchor.*missing'`
  - Confirm `fw audit; echo $?` returns 0 even with the warning present
- **Sizing:**
  - files_touched: 1
  - new_components: 1 (new audit check)
  - novel_mechanism: no
  - est_hours: 1
  - verdict: fits-one-session
- **Dependencies:** T-NEW-1 (no functional dep, but logically sequenced after inception)

### T-NEW-9: Write `012-ArcSystem.md` and update `FRAMEWORK.md`

- **Workflow type:** build
- **Scope:** New canonical doc at `012-ArcSystem.md`, mirroring the structure of `010-TaskSystem.md`. Updates to `FRAMEWORK.md`: glossary entry for Arc, new Arc System section paralleling Task System, Quick Reference table additions for `fw arc create`, `fw arc abandon`, `fw arc close`.
- **Operationalises:** F1.
- **Acceptance Criteria — Agent:**
  - [ ] `012-ArcSystem.md` exists at repo root with sections: Overview, Arc Structure (file format + lifecycle), Arc Fields Reference, Statuses, fw arc CLI, Relation to Tasks, Relation to Other Concepts (Inception, Horizon, Learnings, Directives, Component Fabric)
  - [ ] `FRAMEWORK.md` glossary contains `Arc` entry
  - [ ] `FRAMEWORK.md` Quick Reference contains `fw arc create`, `fw arc abandon`, `fw arc close`, `fw arc focus` rows
  - [ ] `grep -c 'arc' FRAMEWORK.md` returns > 5 (sanity check on documentation density)
- **Acceptance Criteria — Human:**
  - [ ] [REVIEW] `012-ArcSystem.md` content is technically accurate and matches the implementation as it stands after T-NEW-2 through T-NEW-8
    - **Steps:** read 012-ArcSystem.md end-to-end; verify each claim against `lib/arc.sh` and `web/blueprints/arcs.py`.
    - **Expected:** no discrepancies.
    - **If not:** edit before merging.
- **Verification:**
  - `test -f 012-ArcSystem.md`
  - `grep -q 'Arc' FRAMEWORK.md`
  - `grep -q 'fw arc' FRAMEWORK.md`
- **Sizing:**
  - files_touched: 2
  - new_components: 1 (new doc)
  - novel_mechanism: no
  - est_hours: 3
  - verdict: fits-one-session — but writing-heavy; estimate may run over for someone unfamiliar with the existing 010-TaskSystem.md style.
- **Dependencies:** T-NEW-2, T-NEW-3, T-NEW-5, T-NEW-6 (doc needs to describe the post-refactor state)

## 8. Constraints, non-goals, blast radius

**Must respect:**

- The four currently in-progress arcs (`dispatch-safety`, `orchestrator-rethink`, `embeddings-strategy`, `project-shape-resilience`) must remain in `status: in-progress` after this work lands. No silent migration of their states. Their content otherwise untouched.
- `§ACD` enforcement (`--demo` required on close, agent-gate under `$CLAUDECODE=1`) is the established discipline pattern. The new `fw arc abandon` verb must follow the same shape: required justification of minimum length, same agent-gate, same audit-log conventions.
- The migration in T-NEW-3 must be idempotent (running it twice produces no further changes the second time) and produce a committable report. It touches all 545+ task files; reversibility is costly. A1 (quiescent window) must hold.
- The schema acceptance of new fields (A2) must be verified before T-NEW-2 ships; if `agents/audit/audit.sh` rejects unknown fields, an audit-schema update slice must precede field introduction.

**Must not do:**

- Do not address the other five parked T-1653 questions (multi-arc focus, prompt injection Phase B, arc nesting, decisions cross-linking, anchor-task-as-board-state). Out of scope for this handoff. Leave them in `docs/reports/T-1653-arcs-as-first-class.md`.
- Do not introduce any scoring, prioritisation, or value-driver mechanic. That work belongs in `HANDOFF-value-prioritisation-2026-05-15` (a related handoff that depends on this one).
- Do not implement the `draft → in-progress` driver-decision gate. The `draft` state itself is added here; the gate that enforces what `draft → in-progress` *requires* is in the value-prioritisation handoff.
- Do not change `fw arc close` behaviour. The `--demo` gate stays as-is. Adding `fw arc abandon` is additive, not a replacement.

**Affected if it ships:**

- All 545+ existing task files (frontmatter migration).
- The four currently in-progress arcs (no migration, but the lifecycle they live in has changed shape underneath them).
- The `agents/audit/audit.sh` audit-check inventory grows by two checks (stale, anchor-missing).
- The `bin/fw` command surface gains `fw arc abandon`.
- `FRAMEWORK.md` and the numbered root doc set gain a new authoritative document.

**Affected if it breaks:**

- Mid-migration partial state (some tasks have `arc_id:`, some still have `tags: [arc:*]`) is recoverable by re-running the migration. The migration must be idempotent for this to be safe.
- A state-machine bug in `lib/arc.sh` could break the four existing in-progress arcs. Mitigation: T-NEW-5 splits into refactor (5a) and Watchtower (5b); 5a's acceptance criterion explicitly verifies existing arcs are unchanged.
- A wrong `fw arc abandon` agent-gate could allow agents to abandon arcs without human approval. Mitigation: gate pattern is copy-paste from `fw arc close`, which has been battle-tested through §ACD.

## 9. Risks and prevention

| Risk | Likelihood | Mitigation | Detection |
|---|---|---|---|
| Migration partial-state — some tasks migrated, others not, mixed within the same arc, leaving enumeration ambiguous | medium | Idempotent script; A1 quiescent-window check before run; commit migration in a single atomic commit | `grep -rE 'tags:.*arc:' .tasks/` after migration — should be zero matches; non-zero is partial state |
| State machine refactor breaks one of the four existing in-progress arcs (e.g. silently transitions to `draft`) | medium | T-NEW-5 acceptance criterion explicitly tests that all four arcs remain `in-progress`; D3 grandfathers existing arcs by leaving their YAML untouched | Daily audit check post-merge for `arcs whose status is not one of: draft, in-progress, closed, abandoned` |
| `arc_id:` field validation chosen too strictly (Tier-1 block) creates unfixable states when an arc is deleted | low (Q1 default is audit warning, not block) | D4 / Q1 default is audit warning, not block — if human flips Q1, document the fragility | Audit log review monthly |
| Multi-arc tagged tasks (per F2 / Q3) silently lose one of their arc associations during migration | medium-low (depends on actual prevalence) | Migration report (Q2) lists every multi-arc task; Q3 default is alphabetical-first plus loud warning in report | Migration report row count for multi-arc cases |
| `fw arc abandon` agent-gate flaw — agent abandons an arc under `$CLAUDECODE=1` without human approval | low | Copy-paste from `fw arc close` agent-gate pattern; test case for `CLAUDECODE=1` rejection in T-NEW-6 verification | `.context/audits/arc-abandon.jsonl` review; any abandonment lacking matching `--i-am-human` invocation context is suspect |
| Stale-arc threshold (30 days, D6) too aggressive — legitimately-slow work surfaces as noise | medium | Threshold configurable in one constant; revisit after 60 days of production use | Manual review of stale-arc warnings; if humans consistently say "this isn't stale," loosen the threshold |
| Canonical doc (012-ArcSystem.md) drifts from implementation over time | high (this is a generic doc-debt risk, not specific) | Document explicitly states "current as of T-NEW-9 merge date"; T-NEW-9 produces it after all other slices land, minimising drift at birth | Periodic audit comparing 012-ArcSystem.md claims against `lib/arc.sh` behaviour |
| **Reversibility risk:** Migration is costly to reverse | n/a | A1 must hold; migration produces a committable report so the reverse mapping is recoverable | n/a — this is structural; flag at slice T-NEW-3 review time |

No one-way doors in this handoff (no irreversible external actions, no destructive data operations on user data, no force-pushes, no schema breaks that break downstream consumers).

## 10. Dialogue log

- **Q (human):** Tell me about the Arc concept and its current implementation status — what exists, what's planned.
- **A (framework agent, via briefing):** Arc is a first-class workspace primitive in `.context/arcs/<id>.yaml`. Codified in `lib/arc.sh`, `web/blueprints/arcs.py`, `CLAUDE.md`. T-1653 design artefact left eight open questions parked. Four arcs currently in-progress, none closed.
- **Outcome:** F2, F3, F4, F5, F6, F7, F8 derived from this briefing; A4 explicitly named the briefing as load-bearing.

- **Q (agent):** The simpler model — task primitive gains an `arc_id:` field, arc primitive holds index of tasks. Should we treat the arc YAML's `constituent_tasks` field as authoritative (option B), the task's `tags: [arc:*]` as authoritative (option A), or both with reconciliation (option C)?
- **A (human):** My simplistic thinking is that tasks gain an optional `arc_id:` field, that's the canonical mechanism. Arc YAML doesn't need to maintain a stored task list — the index is computed by scanning tasks. Option A.
- **Outcome:** D1 emerged. Specifically: tag-scan stays canonical, `constituent_tasks` is deprecated, no two-place write. The 31-entry list on `orchestrator-rethink` becomes legacy data.

- **Q (agent):** The lifecycle refactor — do we land `abandoned` in this handoff and `draft` in the downstream BVP handoff (two refactors of `lib/arc.sh`), or both in one pass here?
- **A (human):** Arc is the primitive; the lifecycle is part of the primitive. Both states land here in one refactor.
- **Outcome:** D2 emerged. State machine work is unified to a single slice (T-NEW-5). The downstream value-prioritisation handoff *uses* `draft` but doesn't *introduce* it. This also drives T-NEW-5's `verdict: needs-split` per v3 sizing rules.

- **Q (agent):** Should `draft → abandoned` use a separate audit log from `in-progress → abandoned`, since they represent different things ("cancelled before starting" vs "abandoned mid-work")?
- **A (human):** Keep it simple and consistent. Same log.
- **Outcome:** D5 emerged. `.context/audits/arc-abandon.jsonl` carries both transitions with `status_at_abandon` distinguishing them at read time.

- **Q (agent):** For driver-decision suggestions (in the downstream value-prioritisation handoff), should `proposed_scoped_drivers:` persist across the arc's life, or get cleared on approval? My initial framing was audit-trail.
- **A (human):** Not for audit — we might want to change focus later, and the suggestions are a good starting point for reference. Persist them.
- **Outcome:** This decision technically belongs in the value-prioritisation handoff, but it surfaced here because it shaped the structural understanding of arc YAML's longevity. The agent's audit framing was rejected in favour of the human's reference-material framing — a small but real reframe that affects how the field is designed.

- **Q (human):** We're being asked to provide a complete work package, but isn't that the framework agent's scope? We provide research and structure; they convert.
- **A (agent):** Correct — the original handoff format asked the research side to do work-package-grade authoring (verification commands, slice IDs, the inception-vs-build routing). That's overreach. Format updated to v2, then v3, with explicit binding "Research is not authorization" at the top, `Operationalises:` per task, and `depends_on_handoffs:` for chains.
- **Outcome:** The handoff format itself was refined during research. v3 now governs this document. The §7 task breakdown is explicitly proposal-shaped, with `T-NEW-<n>` placeholders for the framework agent to assign real IDs.

## 11. Artifacts and links

- `lib/arc.sh` — Arc primitive implementation (referenced via framework-agent briefing; specific lines: 198-206, 215-227, 430-468, 473-492).
- `web/blueprints/arcs.py` — Watchtower arc rendering; `_read_arc` accepts arbitrary fields (F7 evidence).
- `agents/audit/audit.sh:550-555` — YAML-parse validation for `.context/arcs/*.yaml` (T-1816 hardening; F4 / F7).
- `CLAUDE.md:746` — §ACD discipline section (F8).
- `FRAMEWORK.md` — Confirmed via web fetch on 2026-05-15 to contain zero arc mentions (F1 evidence).
- `010-TaskSystem.md` — Confirmed via web fetch on 2026-05-15 to contain zero arc mentions (F1 evidence).
- `docs/reports/T-1653-arcs-as-first-class.md` — The design anchor for arcs; eight parked questions live here.
- `.context/arcs/dispatch-safety.yaml`, `.context/arcs/orchestrator-rethink.yaml`, `.context/arcs/embeddings-strategy.yaml`, `.context/arcs/project-shape-resilience.yaml` — The four in-progress arcs (F6).
- `.context/working/arc-focus.yaml` — Single-pointer focus; `current_arc: dispatch-safety` per briefing.
- `.context/audits/arc-bypass.jsonl` — Existing bypass log shape that `arc-abandon.jsonl` should mirror (F8).
- Geelen blog post, "Using Business Value Points for Backlog Prioritisation" (2019) — Not directly applicable to this handoff; relevant to the related value-prioritisation handoff. Listed here for completeness because the research session originated from a BVP-framing conversation.
- Prior tasks: T-1641 (originating context), T-1653 (design anchor), T-1661 (Phase 1 build), T-1662 (Phase 2 Watchtower), T-1668 (§ACD), T-1671 (arc close agent-gate), T-1816 (audit YAML-parse hardening).

## 11.5. Pre-action checks (for the receiving agent)

Before acting on this handoff, the receiving agent should verify:

- [ ] Every path cited in §3 / §11 still exists at the cited location. Specifically: `lib/arc.sh`, `web/blueprints/arcs.py`, `agents/audit/audit.sh`, `CLAUDE.md`, `010-TaskSystem.md`, `FRAMEWORK.md`, `docs/reports/T-1653-arcs-as-first-class.md`, and the four arc YAMLs in `.context/arcs/`. Files move; cited line numbers in `lib/arc.sh` (215-227, 430-468, 473-492) may drift. Stale references = stale handoff.
- [ ] T-1653 still has status `completed`; T-1661 and T-1662 still have status `completed`. The four in-progress arcs are still in-progress.
- [ ] No newer handoff supersedes this one. Search `prompts/`, `docs/reports/` for `supersedes: HANDOFF-arc-grooming-2026-05-15`.
- [ ] Every tool / command cited in §7 Verification is installed and on PATH (`fw`, `git`, `grep`, `python3`, `bash`).
- [ ] Every Assumption in §4a still holds:
  - A1 (quiescent migration window): `git log --since="1 hour ago" .tasks/ | head` shows no recent activity on tasks bearing `arc:*` tags (or coordinate explicitly with the human if there is).
  - A2 (schema accepts unknown fields): `grep -rn 'unknown.*field\|schema.*reject' agents/audit/ web/blueprints/` returns no strict-schema rejection.
  - A3 (status written at create-time, not load-time): `grep -A5 'status.*in-progress\|status:.*draft' lib/arc.sh` shows status set at file-creation, not computed dynamically.
  - A4 (framework-agent briefing accurate): spot-check three citations — `sed -n '215,227p' lib/arc.sh`, `sed -n '473,492p' lib/arc.sh`, `sed -n '550,555p' agents/audit/audit.sh`. If they match the briefing, treat it as accurate. If any has materially drifted, halt and request a §5 re-evaluation.

If any check fails: post a one-line summary back to the human and do not proceed to task creation.

## 12. Pickup safety markers (REQUIRED)

> **This is a research handoff, not a build mandate.** The receiving agent should create tasks per §7, set focus, write real ACs (replacing any placeholder I wrote), and proceed only after the appropriate governance gate (inception decide / task gate) is satisfied. The imperative tone of §7 is a PROPOSAL, not an instruction to skip scoping.

**Inception-required triggers fire on this handoff.** §7 describes:

- More than 3 new files (012-ArcSystem.md, migration script, migration report file, at least two new audit checks in `agents/audit/audit.sh`)
- A new CLI verb (`fw arc abandon`)
- A schema migration (task frontmatter `tags: [arc:*]` → `arc_id:`), which is destructive in the sense that the source-of-truth shifts — though it is reversible via re-migration

Therefore: the first task (T-NEW-1) is and must be an inception task. Subsequent build tasks (T-NEW-2 through T-NEW-9) can be filed via `fw work-on --type build` (or framework-agent's equivalent) only after the inception's `decide go` transition.

---

*End of handoff. One-line summary on delivery: filename `HANDOFF-arc-grooming-2026-05-15.md`, §5 verdict GO, 3 open Q items (Q1, Q2, Q3).*
