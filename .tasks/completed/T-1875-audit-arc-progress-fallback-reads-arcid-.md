---
id: T-1875
name: "audit arc-progress fallback reads arc_id frontmatter (T-NEW-11)"
description: >
  audit.sh:3619 T-1813 fallback scans tags:^arc:<slug> only when constituent_tasks
  is empty — same post-T-1850 blindness T-1874 fixed for display, mirrored on the
  audit side. Union with arc_id: frontmatter scan so audit progress check sees the
  same members as fw arc show.

status: work-completed
workflow_type: build
owner: claude
horizon: null
components: [C-004, tests/unit/audit_arc_progress_arc_id.bats]
related_tasks: [T-1687, T-1813, T-1849, T-1850, T-1874]
arc_id: arc-grooming
created: 2026-05-16T22:51:42Z
last_update: '2026-06-11T22:24:01Z'
date_finished: 2026-05-17T06:47:37Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1875: audit arc-progress fallback reads arc_id frontmatter (T-NEW-11)

## Context

`agents/audit/audit.sh` runs an arc-progress check that reads each arc's `constituent_tasks:` list (declared in the YAML) and reports completion ratio. T-1813 added a fallback: when `constituent_tasks: []` is empty, scan tasks tagged `arc:<slug>` instead. The fallback at lines 3619-3636 still uses `^tags:.*arc:<slug>` only — blind to T-1849's `arc_id:` frontmatter field after T-1850 ran the migration. Sibling to T-1874 (which fixed the display layer): same root cause, audit layer.

Observable effect today: arc-005 (arc-grooming) has 13 tasks via arc_id and `constituent_tasks: []` — the audit fallback sees zero, so the arc-progress check is silent on a 13-task arc.

The fix extends the existing python fallback block to union `tag_pattern` matches with `arc_id_pattern` matches, mirroring T-1874's `_arc_tasks_for` shape.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` T-1813 fallback (around line 3619-3636) scans BOTH `^tags:.*arc:<slug>` and `^arc_id:\s*(slug|arc-NNN)$` frontmatter, unioning the sets.
- [x] The fallback matches both forms: slug (e.g. `arc-grooming`) and arc-NNN (e.g. `arc-005`). Symmetric to the stale-arc check at audit.sh:643 which already accepts both.
- [x] `bin/fw audit` runs to completion without new FAIL classes attributable to T-NEW-11 — exit code remains 0 or 1, not 2. Live run: Pass=388, Warn=28, Fail=0 (exit 0). Four NEW WARNs are correctly surfaced (arc-001/003/004/005 ≥0.80 completion-ratio but in-progress — G-062 signature) — these are signal, not noise; the previous all-zero blindness was hiding them.
- [x] `tests/unit/audit_arc_progress_arc_id.bats` exercises three cases: (a) arc with `arc_id`-only tasks → audit fallback finds them; (b) arc with legacy `arc:<slug>` tag-only tasks → audit fallback still finds them; (c) arc with both → tasks not double-counted.
- [x] All new bats cases pass: `bats tests/unit/audit_arc_progress_arc_id.bats` exits 0. 8/8 pass (extended: arc-NNN form, sort-stability, quoted-value tolerance, production-regex pinning).

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

bash -n agents/audit/audit.sh
bats tests/unit/audit_arc_progress_arc_id.bats
# L-394: capture-then-grep
out=$(bin/fw audit 2>&1); rc=$?; [ "$rc" -le 1 ] || { echo "audit exit=$rc (>1=FAIL class)"; exit 1; }
grep -q "arc_id_pattern\|arc_id:" agents/audit/audit.sh

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.

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

### 2026-05-16 — fix surfaces 4 G-062-class warnings that were previously silent

- **What changed:** After the fix, `fw audit` raised FOUR new WARNs (arc-001, arc-003, arc-004, arc-005) — all "≥80% complete but in-progress, G-062 signature, run `fw arc close --demo`". These were not new conditions; they had been silently true the whole time. The blind fallback was hiding 11+121+6+13=151 tasks worth of completion data from the audit's coherence check.
- **Plan impact:** Reframes T-1875 from "parity fix" to "make audit re-acquire sight on arc coherence". The 4 WARNs are the headline-mechanic firing for the first time — operator visibility on which arcs are code-complete-but-not-closed. None of these warnings is actionable by an agent (arc closure belongs to the human per T-1671); they're now correctly surfaced for the human.
- **Triggered:** No new sub-task. The 4 arcs surfaced are themselves the next operator actions (review-queue → close via Watchtower). Documented in Recommendation.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Audit-layer parity for T-1874's display-layer fix. Same root cause (T-1850 migration moved arc membership from `tags:` to `arc_id:`), different observer. The fallback at audit.sh:3619 was scanning the empty post-migration tag namespace; now it unions tag-pattern matches with `arc_id:` frontmatter matches (slug OR arc-NNN form). 8/8 bats on the new test, audit runs clean (Pass=388, Warn=28, Fail=0). The Warn count jumped because the audit is finally seeing arc coherence; the new WARNs are real, not regressions.

**Evidence:**
- Diff scope: `agents/audit/audit.sh` (+14 lines, unioned scan in inline python), `tests/unit/audit_arc_progress_arc_id.bats` (new, 8 tests). Zero render-surface paths touched.
- Bats: `bats tests/unit/audit_arc_progress_arc_id.bats` → 8/8 (slug form, arc-NNN form, legacy tag, both-set deduplication, exclusion of unrelated, sort stability, quoted form, production-regex pinning).
- Live audit run: exit 0, Pass=388, Warn=28, Fail=0. Four new G-062-signature WARNs correctly surface arc-001 (11/11=1.0), arc-003 (orchestrator routing), arc-004 (5/6=0.833), arc-005 (arc-grooming itself). These were previously invisible.
- Sibling alignment with T-1874: same shape (slug-OR-arc-NNN), same tolerance (quoted/unquoted/leading-whitespace), same exit-0 behavior on empty input.

**Next operator actions surfaced by this fix (human-only per T-1671 §ACD agent gate):**
1. Review arc-001 (dispatch-safety, 11/11=1.0) — eligible for `fw arc close arc-001 --demo <url|path>`.
2. Review arc-004 (project-shape-resilience, 5/6=0.833) — close or capture remaining task.
3. Review arc-005 (arc-grooming) — this arc just shipped T-1874 + T-1875 on top of the original 9 slices.
4. arc-003 (orchestrator routing) — 121-task arc, completion ratio not in tail of audit output; needs separate review.

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

### 2026-05-16T22:51:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1875-audit-arc-progress-fallback-reads-arcid-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e3e20364
- **Timestamp:** 2026-06-02T15:00:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-17T06:47:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
