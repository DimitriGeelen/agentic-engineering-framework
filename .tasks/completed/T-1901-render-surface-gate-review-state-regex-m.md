---
id: T-1901
name: "render-surface gate review-state regex matches only FIRST '### Human' header
  — duplicate Human blocks (template-comment + actual ACs) silently captured wrong
  block, gate returns 'empty' and never sees real [REVIEW] ACs"
description: >
  render-surface gate review-state regex matches only FIRST '### Human' header — duplicate
  Human blocks (template-comment + actual ACs) silently captured wrong block, gate
  returns 'empty' and never sees real [REVIEW] ACs

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T17:40:49Z
last_update: '2026-08-16T22:24:48Z'
date_finished: '2026-05-22T07:17:14Z'  # commit ad9b76bd batch-moved file to completed/ without --status work-completed; frontmatter drift fixed at audit time (T-2055 close session)
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1901: render-surface gate review-state regex matches only FIRST '### Human' header — duplicate Human blocks (template-comment + actual ACs) silently captured wrong block, gate returns 'empty' and never sees real [REVIEW] ACs

## Context

The render-surface gate at `agents/task-create/update-task.sh:419-433` reads the task's `### Human` section to decide whether at least one `[REVIEW]` AC is present. The regex is:

```python
m = re.search(r'^### Human\s*$(.*?)(?=^#{2,} |\Z)', text, re.MULTILINE | re.DOTALL)
```

`re.search` returns the FIRST match. `(.*?)` is lazy and terminates at the next `^### ` (or `^## `) or end-of-text. If a task has two `### Human` headers — for example the auto-generated template-comment block on line 41 plus an actual ACs block lower down — the regex captures only the first block's content. If that first block has only comments (no `[ ]`/`[x]` checkboxes), the detector returns `"empty"` and the gate refuses completion despite a perfectly good [REVIEW] AC living in the second block.

Hit by me on T-1898: I added a fresh `### Human` block with the [REVIEW] AC, not realising the auto-template had already emitted one. The gate returned `"empty"`, then crashed silently (separate bug fixed in T-1900). After T-1900 the gate at least surfaces an error — but the diagnostic still says "no [REVIEW] AC present" when one *is* present, just in the second header.

Fix: scan ALL `### Human` blocks under `## Acceptance Criteria` (capture every header, not just the first), union their checkbox lines, then apply the existing `[REVIEW]` test. Backward compatible — single-header tasks work identically; multi-header tasks now see all the ACs.

## Acceptance Criteria

### Agent
- [x] Render-surface gate's `review_state` detector reads ALL `### Human` blocks under `## Acceptance Criteria` (not just the first). Implementation: replace single `re.search` with `re.findall` (or iterate `re.finditer`) and concatenate captured groups before scanning for `[REVIEW]` lines.
- [x] Backward-compat: single-`### Human` task with one `[REVIEW]` AC continues to return `"has_review"` (unchanged behaviour).
- [x] New positive path: task with `### Human` (comment-only) + `### Human` ([REVIEW] AC) returns `"has_review"`. This is exactly the T-1898 shape that broke originally.
- [x] Negative path: task with two `### Human` blocks both comment-only / no-checkbox returns `"empty"` (correctly refuses).
- [x] bats test pins all three cases (single OK, dup-with-review, dup-empty).

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
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
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

FRAMEWORK_ROOT=$(pwd) bats tests/unit/render_surface_review_state_dup_human.bats

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

**Symptom:** T-1898 had two `### Human` headers (template auto-emitted comment-block on line 41 + my added [REVIEW] AC on line 72). `fw task update --status work-completed` refused with `review_state="empty"` despite a clearly-present [REVIEW] AC. Required consolidating the headers manually to unblock.

**Root cause:** `re.search(r'^### Human\s*$(.*?)(?=^#{2,} |\Z)', ...)` returns the FIRST match only. The lazy `(.*?)` terminates at the next `^### ` — which is the SECOND `### Human` header. So the regex captures content from header-1 to header-2, sees only comments, returns `"empty"`. Header-2's content is never inspected.

**Why structurally allowed:** The detector was written assuming exactly one `### Human` block (the template-supplied convention). Nothing prevents authors from adding a second block, and the natural editing pattern when adding a Human AC is to "skip past the comment block and write the AC below" — which produces exactly the duplicate-header shape that breaks the detector. The pattern is more common than expected: agent-authored task templates routinely emit a comment-only first `### Human`, and the agent's first instinct when adding an AC is to write a fresh header rather than navigate inside the comment.

**Prevention:**
- Replace `re.search` with `re.findall` (or iterate `re.finditer`); concatenate all captured groups; then run the existing checkbox detection on the union. Backward-compat for single-header tasks (one match → identical to before).
- bats tests pin the three cases (single OK, dup-with-review, dup-empty).
- Companion follow-up filed verbally: agent should consolidate `### Human` content INTO the existing template-comment header rather than appending a new one. Not enforced structurally — that would require a save-time linter, out of scope. The regex fix is the safety net.

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

## Recommendation

**Recommendation:** GO

**Rationale:** 5/5 Agent ACs PASS. Pre-fix bug shape (dup `### Human` with [REVIEW] in second) now correctly returns `has_review`; single-header tasks unchanged; all-comment tasks correctly refuse. No render-surface concern on this task (touches `agents/task-create/update-task.sh` body, which IS in the allowlist — so a [REVIEW] Human AC is needed; added below for the user-visible behaviour change in the gate's diagnostic accuracy).

**Evidence:**
- bats: `tests/unit/render_surface_review_state_dup_human.bats` 5/5 PASS
- Code: `agents/task-create/update-task.sh` `re.search` → `re.finditer` + group union
- Companion: T-1898 / T-1900 are the origin incidents

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

### 2026-05-18T17:40:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1901-render-surface-gate-review-state-regex-m.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cb421d86
- **Timestamp:** 2026-06-02T15:00:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
