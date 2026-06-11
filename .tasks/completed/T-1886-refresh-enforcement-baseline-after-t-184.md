---
id: T-1886
name: "refresh enforcement baseline after T-1849 / T-1730 / T-1731 hook additions
  — fw doctor FAIL hygiene"
description: >
  refresh enforcement baseline after T-1849 / T-1730 / T-1731 hook additions — fw
  doctor FAIL hygiene

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-grooming, enforcement, hygiene]
components: [.context/project/enforcement-baseline.sha256]
related_tasks: [T-1849, T-1730, T-1731, T-1687]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-17T20:02:11Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-17T20:10:16Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1886: refresh enforcement baseline after T-1849 / T-1730 / T-1731 hook additions — fw doctor FAIL hygiene

## Context

T-1849, T-1730, T-1731 each added new PreToolUse hooks (`check-arc-id`, `focus-drift-gate`, `check-human-ac-tick`). All three are merged. The enforcement baseline at `.context/project/enforcement-baseline.sha256` (df4339c4…) was never refreshed to acknowledge the new hook set, so `bin/fw doctor` reports a FAIL: "Enforcement baseline CHANGED — settings.json hooks differ from baseline." Refreshing the baseline is bookkeeping — the hooks themselves are correct and approved by the merge commits.

## Acceptance Criteria

### Agent
- [x] `bin/fw enforcement baseline` runs cleanly and updates `.context/project/enforcement-baseline.sha256`
- [x] `bin/fw doctor` no longer reports the "Enforcement baseline CHANGED" FAIL (reports OK: "Enforcement baseline intact")

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

# `fw enforcement baseline` computes a canonical hash (not raw file sha256), so
# the authoritative check is `fw doctor` reporting OK on this line.
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Enforcement baseline intact"
out=$(bin/fw doctor 2>&1); ! echo "$out" | grep -q "Enforcement baseline CHANGED"

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

**Symptom:** `bin/fw doctor` reports `[FAIL] Enforcement baseline CHANGED — settings.json hooks differ from baseline`. Single FAIL on otherwise-green doctor output, persisted across multiple sessions.

**Root cause:** Three legitimate hook additions (T-1849 check-arc-id, T-1730 focus-drift-gate, T-1731 check-human-ac-tick) modified `.claude/settings.json` and were merged via their respective task closures. None of those closures included `bin/fw enforcement baseline` as a Verification step, and there is no post-edit nudge from the framework. The canonical hash diverged silently and the FAIL accumulated.

**Why structurally allowed:** Two layered omissions —
1. Each task added a hook (correctly) but did not own the "refresh-baseline" step. The hook-addition workflow has no explicit "refresh-baseline" task in its template.
2. There is no PostToolUse hook on edits to `.claude/settings.json` that nudges "you changed hooks — run `fw enforcement baseline` to acknowledge". The baseline-drift detector is doctor-side (detective), not edit-side (preventive).

**Prevention:** Multi-layered candidate set (none deployed in this slice — captured as candidates):
- **A (lightest):** Add a one-line reminder to the hook-modification path in CLAUDE.md / task templates: "If you edit .claude/settings.json, add `bin/fw enforcement baseline` to your Verification block."
- **B (medium):** PostToolUse hook on `Write|Edit` matching `.claude/settings.json` that emits an advisory WARN reminding the agent to refresh the baseline.
- **C (heaviest):** Make `fw doctor` baseline-drift FAIL block pre-push, so the next push after a hook edit cannot land without acknowledgement. This is the strongest, but couples settings.json edits tightly to operational bookkeeping.

This slice ships only the bookkeeping fix; prevention candidates are noted for arc-grooming follow-up if the drift recurs.

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

### 2026-05-17 — verification command needed canonical-hash awareness
- **What changed:** First-pass `## Verification` checked raw `sha256sum .claude/settings.json` against the baseline file. After running `fw enforcement baseline` and observing `b3f1fc73…` vs my earlier raw-file sha `d953013d…`, realised `fw enforcement baseline` computes a *canonical* hash (presumably sorted keys / normalised whitespace) rather than the raw file hash. The authoritative check is therefore `fw doctor`'s own report.
- **Plan impact:** None — corrected the Verification block in-place.
- **Triggered:** Could be worth a small follow-up to document the canonical-hash form in `bin/fw enforcement` help text, but not needed for closure here.

## Recommendation

**Recommendation:** GO — task ready for `--status work-completed`.

**Rationale:** Tiny one-shot bookkeeping fix. `fw doctor` was reporting one FAIL ("Enforcement baseline CHANGED — settings.json hooks differ from baseline") because three legitimate hook additions (T-1849 check-arc-id, T-1730 focus-drift-gate, T-1731 check-human-ac-tick) had landed without anyone running `fw enforcement baseline` to acknowledge them. Refreshing the baseline accepts the current hook set as the new canonical reference — the hooks themselves are correct and were approved through their respective task closures.

**Evidence:**
- `fw enforcement baseline` output: "Enforcement baseline saved — Hash: b3f1fc734f1931bf…"
- `.context/project/enforcement-baseline.sha256` now contains `b3f1fc734f1931bf559a7d7af5cdc43483f226951f8d9f1ffd93910d1ee5528b` (was `df4339c448a80ac54129528fc605c4a09067be80b45ed25eb5f85143c2b73cfb`)
- `fw doctor` now reports `[OK] Enforcement baseline intact` (was `[FAIL] Enforcement baseline CHANGED`)

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

### 2026-05-17T20:02:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1886-refresh-enforcement-baseline-after-t-184.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9cdb4b71
- **Timestamp:** 2026-06-02T15:00:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `out=$(bin/fw doctor 2>&1); ! echo "$out" | grep -q "Enforcement baseline CHANGED"`
### 2026-05-17T20:10:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
