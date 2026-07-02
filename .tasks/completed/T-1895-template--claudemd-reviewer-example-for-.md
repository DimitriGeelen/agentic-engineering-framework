---
id: T-1895
name: "Template + CLAUDE.md [REVIEWER] example for AC routing default (T-1878 A)"
description: >
  Template + CLAUDE.md [REVIEWER] example for AC routing default (T-1878 A)

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [.tasks/templates/default.md, CLAUDE.md]
related_tasks: [T-1878, T-1811, T-954, T-1894]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T08:01:29Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-18T08:20:35Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 4
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=4 
      (body/components:instruction-sync); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1895: Template + CLAUDE.md [REVIEWER] example for AC routing default (T-1878 A)

## Context

T-1878 inception (GO recorded) found the template surfaces only `[REVIEW]` as the example Human-AC shape; `[REVIEWER]` (T-1811, 4 days old) has no parallel example, contributing to the 59:1 `[REVIEW]:[REVIEWER]` adoption gap. This is intervention **A** of T-1878's A+B plan — pure docs change, the visibility nudge at AC-author time.

Sibling: T-NEW-B (reviewer pattern `human-ac-mechanical-signal`) does the structural catch. A+B together get 4/4 catch on T-1851/T-1857/T-1890/T-1893 (T-1878 validation cases).

Full reasoning: `docs/reports/T-1878-routing-default-bias.md`.

## Acceptance Criteria

### Agent
- [x] `.tasks/templates/default.md` gains a `[REVIEWER]` example alongside the existing `[REVIEW]` example in the `### Human` block comment (template comment, not actual AC — same shape as the `[REVIEW]` Dashboard example today). Example shows: deterministic Expected clause (grep / file-exists / command-output), `Steps/Expected/If-not` triplet, prefix as `[REVIEWER]`.
- [x] Template comment also adds the one-line decision rule: "If your Expected clause is grep-able / file-exists / structural, prefer `[REVIEWER]` (Agent shape + `## Verification` command). If subjective (tone / UX / strategic call), keep `[REVIEW]` (Human shape)."
- [x] `CLAUDE.md` §AC Classification Guidance (the existing T-954/T-1811 section) gains an explicit author-time rule that mirrors the template guidance, with one-line guidance + link to T-1878 + T-1811 + T-1894 (the precedent chain).
- [x] Bats test confirms both examples are present in `.tasks/templates/default.md` and the CLAUDE.md guidance line is present (grep-able pin).
- [x] `## Verification` block on this task passes.

### Human
- [x] [REVIEW] Template + CLAUDE.md additions read naturally — a fresh agent skimming the template recognises `[REVIEWER]` as a peer of `[REVIEW]`, not a footnote
  **Steps:**
  1. Open `.tasks/templates/default.md` and read the `### Human` block comment from top
  2. Open `CLAUDE.md` §AC Classification Guidance and read the new author-time rule
  **Expected:** A fresh agent would default to `[REVIEWER]` for grep-able Expected clauses without needing to be told twice. The template doesn't bury `[REVIEWER]` behind `[REVIEW]`.
  **If not:** Note where the framing falls flat and iterate

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

bats tests/unit/template_reviewer_prefix_example.bats
test "$(grep -c '\[REVIEWER\] example' .tasks/templates/default.md)" -ge 1
test "$(grep -c 'Author-time default' CLAUDE.md)" -ge 1
test "$(grep -c '\[REVIEWER\]' CLAUDE.md)" -ge 3

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

### 2026-05-18 — Producer/consumer gap in prefix list itself
- **What changed:** While editing CLAUDE.md, found that the "Human AC Format Requirements (T-325)" prefix-bullet list omitted `[REVIEWER]` entirely — only listed `[RUBBER-STAMP]` and `[REVIEW]`. The §AC Classification Guidance section (T-1811) already had the three-prefix table, but the format-requirements section (which is what an author would skim) didn't. This is the same producer/consumer split L-399 names structurally — vocabulary added in one place, not propagated to consumers.
- **Plan impact:** Original plan was "add one-line decision rule." Actual fix needed three edits: template example block, CLAUDE.md author-time default rule, AND prefix-list bullet update.
- **Triggered:** No new task — fixed inline. Caught by bats test #5 which I almost didn't write; the author-time-default rule (test #4) would have passed without test #5 noticing the prefix list still omitted [REVIEWER].

## Recommendation

**Recommendation:** GO

**Rationale:** Intervention A from T-1878's A+B plan is in place. The author-time prefix gap (412:7 `[REVIEW]:[REVIEWER]` adoption, 13% mis-class rate) was driven by template + format-requirements both omitting `[REVIEWER]` as a peer example. Three surfaces now carry the routing nudge: (1) template `### Human` block shows a `[REVIEWER]` example side-by-side with `[REVIEW]`, (2) CLAUDE.md §AC Classification gains an author-time-default rule citing T-1878, (3) Human AC Format Requirements bullet list now names `[REVIEWER]` alongside the other two prefixes. Reviewer static scan returns PASS, needs_human=no. Bats `template_reviewer_prefix_example.bats` (5 tests) pins all three surfaces.

The one residual `[REVIEW]` AC is genuine taste — "fresh agent recognises [REVIEWER] as a peer of [REVIEW], not a footnote" is a readability call, not a static-scan target.

**Evidence:**
- `.tasks/templates/default.md` lines around `[REVIEWER] example` — paired example block with grep-able Expected + conversion hint
- `CLAUDE.md` `**Author-time default (T-1878):**` paragraph — explicit nudge citing T-1878 + grep-able heuristic
- `CLAUDE.md` `Human AC Format Requirements (T-325)` bullet list — `[REVIEWER]` now present (closed producer/consumer gap caught during build, see Evolution)
- `tests/unit/template_reviewer_prefix_example.bats` — 5/5 PASS
- `bin/fw reviewer T-1895` — Overall PASS, no findings, needs_human=no
- Verification block: 4/4 commands PASS

**Pair status:** Sibling T-1896 (intervention B — structural catch via reviewer pattern `human-ac-mechanical-signal`) is filed with full ACs, `horizon: next`, ready for a fresh focused-work cycle. A+B together get 4/4 catch on T-1878 spike validation cases (T-1851/T-1857/T-1890/T-1893).

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

### 2026-05-18T08:01:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1895-template--claudemd-reviewer-example-for-.md
- **Context:** Initial task creation

### 2026-05-18T08:02:33Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-18T08:16:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-350373ca
- **Timestamp:** 2026-06-02T15:00:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-18T08:20:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
