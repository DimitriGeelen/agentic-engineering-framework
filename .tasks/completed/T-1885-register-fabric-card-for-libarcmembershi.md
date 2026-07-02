---
id: T-1885
name: "register fabric card for lib/arc_membership.sh + fill TODO purpose on .py card
  (T-1880 hygiene)"
description: >
  register fabric card for lib/arc_membership.sh + fill TODO purpose on .py card (T-1880
  hygiene)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/arc_membership.sh, lib/arc_membership.py]
related_tasks: [T-1880, T-1687]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-17T19:54:54Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-17T19:57:23Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1885: register fabric card for lib/arc_membership.sh + fill TODO purpose on .py card (T-1880 hygiene)

## Context

T-1880 (T-NEW-15, arc-grooming) created two language-mirror helpers — `lib/arc_membership.py` (Python/Flask consumers) and `lib/arc_membership.sh` (shell consumers). Only the `.py` got a fabric card, and that card's `purpose:` is still the auto-generated `"TODO: describe what this component does"`. `fw fabric drift` reports `lib/arc_membership.sh` as unregistered. Small hygiene slice to land both cards correctly.

## Acceptance Criteria

### Agent
- [x] `.fabric/components/lib-arc_membership-sh.yaml` exists with proper `id: lib/arc_membership.sh`, purpose, depended_by edges
- [x] `.fabric/components/lib-arc_membership.yaml` has its `TODO: describe` placeholder replaced with real purpose pointing at T-1880 / L-397
- [x] `bin/fw fabric drift` reports `unregistered: 0` after the change

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

test -f .fabric/components/lib-arc_membership-sh.yaml
out=$(bin/fw fabric drift 2>&1); echo "$out" | grep -q "unregistered: 0"
! grep -q "TODO: describe" .fabric/components/lib-arc_membership.yaml

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

### 2026-05-17 — arc-grooming hygiene tail
- **What changed:** T-1880 shipped two language-mirror helpers (`.py` + `.sh`) but the fabric registration step only landed a card for the `.py`, and that card never had its `TODO: describe` purpose filled. Surfaced by `fw fabric drift` after T-1884 push triggered an audit cycle.
- **Plan impact:** Confirms that consolidation work in T-1880 was complete *as code* but incomplete *as fabric registry*. Going forward, T-1880-class consolidations that touch >1 language should register both cards in the same commit.
- **Triggered:** No new sub-task. One-shot hygiene fix here, plus a note to consider auto-detecting `language-mirror` helpers in `fw fabric scan` (deferred — not enough recurrence to warrant tooling).

## Recommendation

**Recommendation:** GO — task ready for `--status work-completed`.

**Rationale:** Tiny hygiene slice; three deterministic ACs all ticked with shell-verifiable evidence. `fw fabric drift` now reports `unregistered: 0` (was `unregistered: 1`). The `.py` card's TODO placeholder is replaced with a substantive purpose that ties the helper to T-1880 + L-397, so any future reader following the fabric graph lands on the silent-corpus-prevention context instead of the auto-generated stub. New `.sh` card mirrors the `.py` card structurally, with shell-side consumers in `depended_by`.

**Evidence:**
- New card: `.fabric/components/lib-arc_membership-sh.yaml` (id: lib/arc_membership.sh)
- Updated card: `.fabric/components/lib-arc_membership.yaml` (purpose: full description, id unchanged, depended_by populated)
- `fw fabric drift`: `Summary: unregistered: 0, orphaned: 0, stale: 20` (was: `unregistered: 1, ...`)
- `grep -q "TODO: describe" .fabric/components/lib-arc_membership.yaml` → no match (TODO replaced)

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

### 2026-05-17T19:54:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1885-register-fabric-card-for-libarcmembershi.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-91a29885
- **Timestamp:** 2026-06-02T15:00:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `.fabric/components/lib-arc_membership-sh.yaml` exists with proper `id: lib/arc_membership.sh`, purpose, depended_by edges
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/arc_membership.sh in: `.fabric/components/lib-arc_membership-sh.yaml` exists with proper `id: lib/arc_membership.sh`, purpose, depended_by edges`
### 2026-05-17T19:57:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
