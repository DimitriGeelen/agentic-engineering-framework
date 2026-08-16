---
id: T-1856
name: "Anchor-task existence audit check (T-NEW-8)"
description: >
  agents/audit/audit.sh adds check: warn when arc YAML's anchor_task: T-X references
  a non-existent task. Warning only, never blocks (audit exit code unaffected). Check
  passes silently for arcs without anchor_task: set. Deps: T-1846 (logical sequencing,
  not functional). Mirrors D4 from inception (anchor-task missing = warn not block,
  symmetric to arc_id validation via D-Immutability for the reverse direction).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [build, audit, T-NEW-8]
components: [C-004, tests/unit/audit_anchor_task_existence.bats]
related_tasks: [T-1846, T-1847]
arc_id: arc-grooming
created: 2026-05-15T14:53:17Z
last_update: '2026-08-16T22:24:46Z'
date_finished: 2026-05-16T09:37:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1856: Anchor-task existence audit check (T-NEW-8)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` adds anchor-task check: WARN when arc YAML's `anchor_task: T-X` references a task not found in `.tasks/active/` or `.tasks/completed/`. Placed in STRUCTURE section after YAML-parse loop.
- [x] Check passes silently for arcs without `anchor_task:` set OR with `anchor_task: null`. Pass line only when ≥1 anchor was checked (no false-positive pass on zero-anchor scans).
- [x] Warning only — `fw audit` exit code unaffected. Verified: orphan-anchor fixture exits ≤1, never 2.
- [x] Test: `tests/unit/audit_anchor_task_existence.bats` covers 5 cases. 5/5 pass.

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
#
# L-393: scope `bin/fw audit` to a section; use `grep -c >=1` not `grep -q`.

# Bats coverage passes
bats tests/unit/audit_anchor_task_existence.bats >/dev/null 2>&1
# Audit clean (structure section) — anchor check is now part of it
test "$(bin/fw audit --section structure 2>&1 | grep -c 'Fail: 0')" -ge 1
# Anchor check pass line emitted on our 5 real arcs (all have anchor_task pointing at existing tasks).
# Use `grep -c >=1` not `grep -q` (L-393 SIGPIPE-141 trap, learned T-1848).
test "$(bin/fw audit --section structure 2>&1 | grep -c 'anchor_task references')" -ge 1

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

### 2026-05-16 — pass-line only when at least one anchor checked

- **What changed:** Initial plan: always emit a pass line for the anchor check. Building revealed this would emit a false-positive pass when ZERO arcs had `anchor_task:` (the check did nothing yet "succeeded"). Right behavior: only emit the pass line when `anchor_checked > 0` AND `anchor_missing == 0`. Zero-anchor case stays silent — there's nothing to report.
- **Plan impact:** AC text updated to capture this nuance. Mirrors the existing audit convention where pass lines are emitted per-check-actually-run, not per-check-attempted.
- **Triggered:** No new sub-task. Captured in AC #2.

## Recommendation

**Recommendation:** GO

**Rationale:** T-1856 closes the symmetric half of T-1849's hostage-state guard: task→arc references are checked by the PreToolUse hook (write-time), arc→task references are checked by audit (background). WARN-only by design per T-1846 §4 D4 — fixing a stale anchor_task is a maintenance task, not a blocker. Implementation is ~25 lines added to audit.sh's STRUCTURE section, between YAML-parse and fabric-drift checks. 5/5 bats fixtures cover all branches. Live audit on the 5 real arcs returns Pass=14, Warn=1, Fail=0 (was Pass=13 — one new anchor pass line added).

**Evidence:**
- `agents/audit/audit.sh`: anchor-task check inserted after YAML parse loop (line ~588)
- `tests/unit/audit_anchor_task_existence.bats`: 5/5 pass
  - valid anchor → pass line
  - orphan anchor (T-99999) → WARN, exit ≤1
  - no anchor field → silent
  - anchor_task: null → silent
  - mix of valid + orphan → only orphan warns
- Real-world audit run: 14 PASS (1 new vs T-1848 close baseline), 1 WARN (pre-existing fabric-enrich), 0 FAIL

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

### 2026-05-15T14:53:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1856-anchor-task-existence-audit-check-t-new-.md
- **Context:** Initial task creation

### 2026-05-16T09:29:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d909129a
- **Timestamp:** 2026-06-02T15:00:03Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 13
     - evidence: `bats tests/unit/audit_anchor_task_existence.bats >/dev/null 2>&1`
### 2026-05-16T09:37:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** L-393 fix applied to V3 idiom (grep -c >=1, not grep -q)
