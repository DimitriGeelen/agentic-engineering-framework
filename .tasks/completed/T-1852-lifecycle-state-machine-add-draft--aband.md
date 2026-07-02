---
id: T-1852
name: "Lifecycle state machine: add draft + abandoned (T-NEW-5a)"
description: >
  lib/arc.sh defines 4 states: draft, in-progress, closed, abandoned. arc_create writes
  status: draft for new arcs going forward. Existing 5 arcs (incl arc-grooming) stay
  status: in-progress (no force-migration per D3). arc_close transitions in-progress→closed
  unchanged. Block draft→closed (only draft→in-progress or draft→abandoned allowed).
  audit YAML-parse accepts all 4 states. Deps: T-1846. novel_mechanism: yes.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: [T-1846, T-1847, T-1668]
arc_id: arc-grooming
created: 2026-05-15T14:52:59Z
last_update: '2026-06-11T22:24:00Z'
date_finished: 2026-05-16T21:46:05Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (tag:novel-mechanism,body:structural-gate); D2=4 
      (body:fw-audit-or-doctor); D3=2 (body:default-change); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1852: Lifecycle state machine: add draft + abandoned (T-NEW-5a)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `lib/arc.sh` defines four allowed states: `draft`, `in-progress`, `closed`, `abandoned` (constant `ARC_STATES=(...)`)
- [x] `arc_create` writes `status: draft` for newly-created arcs going forward (heredoc + command echoes "use 'fw arc start <id>' to begin")
- [x] Existing 5 arcs (`dispatch-safety`, `embeddings-strategy`, `orchestrator-rethink`, `project-shape-resilience`, `arc-grooming`) remain `status: in-progress` after refactor (no force-migration per D3) — bats test asserts on live in-tree YAMLs
- [x] `arc_close` continues to work on `in-progress` arcs; `in-progress → closed` transition unchanged
- [x] `draft → closed` transition is refused (only `draft → in-progress` or `draft → abandoned`) — `_arc_require_status "$id" "close" "in-progress"` guard
- [x] `agents/audit/audit.sh` YAML-parse accepts all four states without warning — live audit Pass=15/Warn=1/Fail=0; arc-completion check filters on `status == in-progress` (line 3643)
- [x] Transition logic encodes D-Immutability: no file deletion, only `status:` field updates (Python `re.sub` on the `status:` line, file path unchanged; arc_abandon T-1854 will follow same pattern)
- [x] New CLI verb: `fw arc start <id>` for draft → in-progress (wired into `arc_dispatch`; arc_help text updated)
- [x] Bats coverage: `tests/unit/arc_lifecycle_state_machine.bats` — 10/10 pass

### Human
- [x] [REVIEW] Lifecycle change is acceptable as a breaking workflow change for `fw arc create`
  **Steps:**
  1. Read the new lifecycle in CLAUDE.md §Arc Completion Discipline (or `bin/fw arc help`): draft (new arcs) → in-progress (after `fw arc start`) → closed | abandoned
  2. Consider: any existing scripts / docs / habits that do `fw arc create foo` and expect the arc to be immediately workable will now need an explicit `fw arc start foo` step
  3. Smoke-test it:
     ```
     cd /opt/999-Agentic-Engineering-Framework && bin/fw arc create rev-t1852 --name "review smoke" --headline-mechanic "user sees the lifecycle review smoke firing on the page in full view" && bin/fw arc show rev-t1852 && bin/fw arc start rev-t1852 && bin/fw arc show rev-t1852 && rm .context/arcs/rev-t1852.yaml
     ```
  4. Confirm: first `arc show` reports `draft`, second reports `in-progress`
  **Expected:** The two-step (create + start) flow feels acceptable. If the friction outweighs the value of an explicit "draft" state, reopen with a counter-proposal (e.g. `fw arc create --start` flag for one-step).
  **If not:** Document the friction; could add a `--start` flag to `arc_create` as a follow-up.

## Verification

# T-1852 verification (scoped per L-291/L-393/L-387 — no grep -q under pipefail).
bash -n lib/arc.sh
bats tests/unit/arc_lifecycle_state_machine.bats
test "$(grep -c '^ARC_STATES=' lib/arc.sh)" -ge 1
test "$(grep -c 'arc_start()' lib/arc.sh)" -ge 1
test "$(grep -c '^status: draft' lib/arc.sh)" -ge 1

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

### 2026-05-16 — new verb `fw arc start` invented during build
- **What changed:** Spec AC #2 says "arc_create writes status: draft going forward" but didn't enumerate how an arc transitions to in-progress. Building this revealed the gap — we either need an explicit `arc_start` verb OR a flag on `arc_create`. Chose the verb (see Decisions). Spec implicitly assumed there's a transition mechanism; explicit invention captured here.
- **Plan impact:** AC #4 ("arc_close transition unchanged") still true; an additional CLI verb is now part of the slice. Added as AC #8 (`fw arc start <id>` verb).
- **Triggered:** No new task. The Watchtower lifecycle-tabs slice (T-1853) will surface "start" alongside the existing "close" + "abandon" actions.

### 2026-05-16 — audit arc-completion check already filters on in-progress
- **What changed:** AC #6 expected explicit YAML-parse acceptance of all 4 states. Reading audit.sh:3643 revealed the existing arc-completion check already does `if [ "$ARC_STATUS" != "in-progress" ]; then continue; fi` — draft/closed/abandoned arcs are silently skipped from completion-threshold scoring, which is exactly the desired behaviour. No audit changes needed for state acceptance — the YAML parser is opaque.
- **Plan impact:** AC #6 ticked without modifying audit.sh.
- **Triggered:** No new task.

### 2026-05-16 — `_arc_require_status` helper added (reused for arc_close, future arc_abandon)
- **What changed:** Originally planned to add an inline status check inside arc_close. Building it that way meant T-1854 (arc_abandon) and the new arc_start would each duplicate the validation. Refactored to `_arc_require_status <id> <verb> <expected...>` — single source of truth + uniform error text listing the allowed transitions.
- **Plan impact:** Mild scope creep into a reusable helper. T-1854 will be cheaper to ship because the validation is already centralised.
- **Triggered:** No new task; T-1854 (already in the queue) absorbs the helper.

### 2026-05-18 — `--start` counter-proposal landed (additive, non-breaking)
- **What changed:** Original Decision (2026-05-16) chose `fw arc start` verb over `arc_create --start` flag, reasoning the draft state "forces a pause". On Human [REVIEW] re-examination, the operator pushed back: "can't it be both, e.g. we start drafting, enriching over time, OR we draft, spend enough effort on it, decide to go, and state-change to in-progress?" — and they're right. The verb made `draft` reachable but cost the one-step muscle memory unnecessarily. Both paths are valuable.
- **Plan impact:** Adds `--start` flag to `arc_create` as additive convenience. Default behaviour unchanged (`status: draft`). `--start` writes `status: in-progress` directly. New bats coverage (`tests/unit/arc_create_start_flag.bats`, 4/4 PASS) pins both paths.
- **Triggered:** No new task. The original Decision's own "Rejected" branch explicitly named this as a follow-up: *"Could be added later as a convenience flag if friction is real (Human [REVIEW] AC tests this)."* Counter-proposal authorised by AC text, shipped same-session as Human review surfaced the friction.

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

### 2026-05-16 — explicit `fw arc start` verb vs. `arc_create --start` flag
- **Chose:** Separate verb `fw arc start <id>` for the draft → in-progress transition.
- **Why:** The lifecycle becomes explicit and uniform with the other transition verbs (`close`, future `abandon`). A `--start` flag on `create` would short-circuit the draft state into a one-line shortcut — useful, but it hides the new lifecycle from operators and undermines the "draft state forces a pause" benefit (the human/agent now has a beat to confirm the headline_mechanic before declaring the arc active). The verb is also greppable across the codebase and trivially extends with future transition-time policy.
- **Rejected:** `arc_create --start`: hides lifecycle, undermines the draft pause. Could be added later as a convenience flag if friction is real (Human [REVIEW] AC tests this).

### 2026-05-16 — `_arc_require_status` over inline checks
- **Chose:** Single reusable helper `_arc_require_status <id> <verb> <expected...>`.
- **Why:** Three transition verbs (start, close, future abandon) all need the same "is the arc in the expected state?" check. Single helper means: (a) one place to update the error text when T-1854 adds the abandon transition; (b) one place to add future state-transition policy (e.g. logging, hooks); (c) uniform UX — the operator sees the same "allowed transitions" cheat-sheet no matter which verb refused.
- **Rejected:** Inline `if [ "$status" != "in-progress" ]; then ...; fi` in each verb — duplicates the cheat-sheet, drifts under future edits.

### 2026-05-16 — Python in-place `re.sub` for status flip
- **Chose:** `python3 - "$file" <<PY ... re.sub ...` heredoc, in-place rewrite.
- **Why:** Single-line surgical edit on a known field; preserves all other YAML structure including comments, blank lines, ordering. Mirrors existing patterns in arc_tag (line ~534) and the T-1850 migration script.
- **Rejected:** `yq` / `python3 yaml.safe_load + dump` — would round-trip the entire YAML, potentially reformatting unrelated fields and breaking any operator who has hand-edited the file. Also rejected: `sed -i` — escape complexity on the `status:` line is brittle across platforms.

## Recommendation

**Recommendation:** GO

**Rationale:** T-1852 (T-NEW-5a) ships the lifecycle state-machine foundation for the rest of arc-grooming. All 9 Agent ACs satisfied:

- Four states defined as `ARC_STATES` constant.
- `arc_create` now writes `status: draft` for new arcs (was `in-progress`).
- New `fw arc start <id>` verb for draft → in-progress transition (registered in `arc_dispatch` + `arc_help`).
- `arc_close` refuses unless source state is `in-progress` (D3 preserved: pre-T-1852 arcs already in-progress can close normally).
- Reusable `_arc_require_status` helper centralises validation; T-1854 (arc_abandon) will reuse it.
- Live audit still green (Pass=15/Warn=1/Fail=0) — arc-completion check already filters on `in-progress`, no audit changes needed.
- D-Immutability honoured: Python `re.sub` on the `status:` line, file path unchanged.
- 10/10 bats coverage in `tests/unit/arc_lifecycle_state_machine.bats`.

One [REVIEW] Human AC: confirm the create→start two-step is acceptable as a workflow change.

**Update 2026-05-18:** `--start` counter-proposal landed (Evolution entry). The change is now **additive, not breaking**: default `fw arc create` writes `draft` (new behaviour, makes the state reachable via the natural verb), `--start` flag preserves the old one-step muscle memory. Both paths supported, smoke-tested 4/4 PASS in `tests/unit/arc_create_start_flag.bats`. The [REVIEW] AC reduces to "yes, both paths feel right."

**Evidence:**
- `lib/arc.sh` — ARC_STATES constant (line ~62), `_arc_get_status` + `_arc_require_status` helpers, `arc_start` verb, `status: draft` in arc_create heredoc, `_arc_require_status "$id" "close" "in-progress"` guard in arc_close
- `bats tests/unit/arc_lifecycle_state_machine.bats` → 1..10, all `ok`
- `bin/fw audit --section structure` → Pass=15, Warn=1 (pre-existing fabric-enrich), Fail=0
- D3 sanity: all 5 in-tree arcs still `status: in-progress` (bats test #7 asserts this on the live YAMLs in `.context/arcs/`)

**Follow-up (in arc-grooming queue):**
- T-1854 (T-NEW-6) `fw arc abandon` — will reuse `_arc_require_status` for the draft|in-progress → abandoned transition.
- T-1853 (T-NEW-5b) Watchtower /arcs lifecycle tabs — will read the four states to render filter chips.

**Counter-proposal shipped 2026-05-18:** `fw arc create --start` one-step convenience flag. See Evolution entry for context; `tests/unit/arc_create_start_flag.bats` for coverage.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:52:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1852-lifecycle-state-machine-add-draft--aband.md
- **Context:** Initial task creation

### 2026-05-16T21:39:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-81c5ec5d
- **Timestamp:** 2026-06-02T15:00:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-16T21:46:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
