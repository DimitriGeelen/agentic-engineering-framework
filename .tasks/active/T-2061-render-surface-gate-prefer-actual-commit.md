---
id: T-2061
name: "render-surface gate: prefer actual commit diffs over body-text path tokens
  — fix L-435 false-positive class"
description: >
  render-surface gate: prefer actual commit diffs over body-text path tokens — fix
  L-435 false-positive class

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, render-surface, governance, false-positive, p-013, l-435]
components: [lib/render_surface.sh, agents/task-create/update-task.sh, 
      tests/unit/test_render_surface_gate.bats]
related_tasks: [T-1766, T-2056, T-2060, T-1763, T-1764, T-1765]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T11:37:38Z
last_update: '2026-05-28T11:45:02Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-05-28T11:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-28T11:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2061: render-surface gate: prefer actual commit diffs over body-text path tokens — fix L-435 false-positive class

## Context

T-2056 has 4 ticked agent ACs + green Verification (`git diff --quiet HEAD -- web/blueprints/settings.py` confirms settings.py untouched), but the P-013 render-surface gate refuses close. Why: `task_touches_render_surface()` in `lib/render_surface.sh` greps the task BODY for path-like tokens and matches `web/blueprints/settings.py` mentioned 5× in prose ("settings.py is untouched", "production behaviour change", etc.). The gate cannot distinguish "this task modifies file X" from "this task DISCUSSES file X". L-435 documents the class and proposes the fix candidate: cross-check against the task's actual commit diffs (`git log --grep TASK_ID --name-only`) rather than relying on body-text path tokens. This fix unblocks T-2056 and the next instance of the same class, and removes a friction point where the sanctioned escape (`--skip-render-review`) is human-gated under autonomy (forces every false-positive into the human review queue).

Affected files:
- `lib/render_surface.sh:67-117` — `task_touches_render_surface()` body-scan logic
- `tests/unit/test_render_surface_gate.bats` — 12 existing cases including "web/blueprints/*.py in body verification block returns 0" (line 70) that explicitly asserts the false-positive behaviour we're fixing
- `agents/task-create/update-task.sh:418` — consumer of the predicate (no change needed if predicate contract is preserved)

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/render_surface.sh:task_touches_render_surface()` prefers git evidence (`git log --all --pretty=format: --name-only --grep TASK_ID`) over body-text path tokens. When git evidence exists, body-text scan is ignored. When git evidence is empty (brand-new task, no commits), body-text scan still runs as a fallback (preserves first-close behaviour for tasks where the very first commit IS the close). Implemented via two helpers `_render_surface_extract_task_id` + `_render_surface_git_touched_paths`; both `task_touches_render_surface` and `render_surface_files_in` use the same source-selection.
- [x] T-2056 predicate now returns NO-TOUCH (false positive fixed) — verified via `bash -c 'source lib/render_surface.sh; task_touches_render_surface .tasks/active/T-2056-fix-stale-preset-nav-unit-tests--t-2011-.md && echo TOUCHES || echo NO-TOUCH'` returning `NO-TOUCH`. Full close to be exercised after this commit (separate AC verifies end-to-end).
- [x] T-2060 (which genuinely touches `web/templates/approvals.html` + `web/templates/review.html`) still trips the gate — verified via `task_touches_render_surface .tasks/active/T-2060-polling-containers-inherit-body-hx-targe.md` returning TOUCHES. `render_surface_files_in` reports both committed templates. No regression.
- [x] `tests/unit/test_render_surface_gate.bats` extended: 3 new T-2061 cases (false-positive rejection, true-positive preservation, files-in correctness) + 12 original cases all green (15/15 pass). The original "body verification block returns 0" case (line 70) still passes because its fixture has no matching git history → falls back to body scan (which still detects the body-mentioned render path).
- [x] `bin/fw doctor` shows 0 failures (19 warnings, all pre-existing). No new doctor regression introduced by this fix.

### Human
<!-- No render surface touched by this fix — predicate change in lib/render_surface.sh
     is governance infrastructure, not a render surface. Gate self-tests via the bats
     update covering both directions (false-positive rejection + true-positive preservation). -->

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

# Full bats suite for the gate stays green (15/15 cases: 12 original + 3 new T-2061)
out=$(bats tests/unit/test_render_surface_gate.bats 2>&1); echo "$out" | tail -1 | grep -qE "^ok 15"
# Predicate still detects a real git-touched render path (T-2060 regression check — committed templates)
out=$(bash -c 'source lib/render_surface.sh; task_touches_render_surface .tasks/active/T-2060-polling-containers-inherit-body-hx-targe.md && echo TOUCHES || echo NO-TOUCH'); echo "$out" | grep -q "TOUCHES"
# Predicate rejects body-text-only mention (L-435 false-positive class — T-2056 was canonical, now in completed/)
out=$(bash -c 'source lib/render_surface.sh; task_touches_render_surface .tasks/completed/T-2056-fix-stale-preset-nav-unit-tests--t-2011-.md && echo TOUCHES || echo NO-TOUCH'); echo "$out" | grep -q "NO-TOUCH"

## RCA

**Symptom:** T-2056 has 4 ticked Agent ACs + 4-line green Verification (`git diff --quiet HEAD -- web/blueprints/settings.py` explicitly confirms settings.py is unchanged), yet `bin/fw task update T-2056 --status work-completed` refuses with `ERROR: Cannot complete build task — touches render surface but has no [REVIEW] Human AC` and lists `web/blueprints/settings.py` as the "touched" file. Same false-positive flagged by L-435 (2026-05-25); no fix shipped.

**Root cause:** `task_touches_render_surface()` in `lib/render_surface.sh:67` derives the candidate file list from (a) the task's `components:` frontmatter and (b) a regex sweep of the task BODY for path-like tokens. Both signals are author-controlled prose — they reflect what the task TALKS ABOUT, not what the task MODIFIES. A task whose entire point is "this file is intentionally untouched" still trips the gate because the file path literal appears in the body 5× in the negative-existence assertion.

**Why structurally allowed:** The gate was designed (T-1766) when the dominant false-negative class was "agent forgets to declare render touches and ships without [REVIEW] AC". Body-text scanning errs on the side of catching that — which is correct as a default. The opposite class (false-positive when prose mentions a path that wasn't modified) wasn't seen until 5 months later. No bats test asserted "body-text mention without git diff returns 1" — the test at line 70 of `test_render_surface_gate.bats` actually CODIFIES the false-positive behaviour as intended ("body verification block returns 0"), making it a pinned anti-feature rather than a guarded one.

**Prevention:** (1) Switch the predicate's primary evidence source from body-text scan to git history scan for the task ID (`git log --grep TASK_ID --name-only` + staged + working-tree). (2) Keep body-text scan as a fallback only when git evidence is empty (brand-new task being closed in the same commit it's being created). (3) Update the bats test that pins the false-positive to instead pin the true-positive contract: "body-mention with no git evidence → predicate returns 1; body-mention WITH git evidence on a render path → predicate returns 0". This new bats case is the regression guard for the next instance.

## Evolution

### 2026-05-28 — fixture id shape gotcha

- **What changed:** Initial bats fixtures used synthetic ids like `T-FP-1` / `T-TP-1` / `T-FILES-1` (kebab-suffixed for "false-positive", "true-positive", "files"). `_render_surface_extract_task_id` matches `T-[0-9]+` only — `T-FP-1` fails the regex, returns empty, and the predicate skips git evidence entirely. Two of three new tests failed silently for the wrong reason (the predicate falling back to body scan, which still matched the body's render-path mention).
- **Plan impact:** Confirmed the gate's task-id contract is "T-NNNN" (digits-only) — matching the on-disk task filenames. Re-wrote fixtures to use `T-90061` / `T-90062` / `T-90063` (numeric, well outside the live range).
- **Triggered:** Worth noting in the AGENT.md docstring of `_render_surface_extract_task_id` (already says "T-NNN") — no extra task needed. The hypothesis-driven debug cycle (extract_task_id returned empty → traced upstream) avoided shotgun-debugging a second round.

## Decisions

### 2026-05-28 — git-evidence as PRIMARY vs. supplement

- **Chose:** Git evidence is the **sole** signal when present (commits matching task id). Body scan is fallback **only** when git evidence is empty.
- **Why:** Halfway designs ("git AND body, with body filtered") still let body-text false-positives leak through whenever the agent's prose happens to mention a render path. Commits are unambiguous proof of modification — there is no honest false-positive case for a path that appears in the commit diff.
- **Rejected:**
  - "Body scan, supplemented by `git diff --quiet HEAD -- <path>` filter" — would unwind the whole body-scan signal for the L-435 class, but at the cost of N filesystem-touching git invocations per task. The branch-clean negative is identical to the simpler "use git history first" approach.
  - "Inspect frontmatter `components:` only" — L-435 origin task (T-2056) had `components: []` empty, so this would have helped, but the contract that consumers update `components:` honestly is itself unenforced — a future task with a misdeclared `components:` would re-introduce false positives. Git diff is verifiable; declared components are not.

### 2026-05-28 — fallback when git evidence is empty

- **Chose:** Fall back to body+components scan when `git log --grep` returns no lines.
- **Why:** Preserves backward-compatible behaviour for the test fixtures (synthetic ids not in git log) and for the legitimate first-close case (task being closed in its first commit, where the close itself isn't yet logged). Without this fallback, the 12 existing bats cases would all fail and the predicate would always return NO-TOUCH for any first-close task.
- **Rejected:** "Hard error if git evidence empty" — would force a per-call double-commit cadence (commit work, then commit close). Friction without value.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO (work-completed)

**Rationale:** L-435 false-positive class fully closed for tasks with commits referencing their id. T-2056 — the canonical blocked task — now closes via the regular path (no `--skip-render-review`, no [REVIEW] AC added, reviewer R-adba2336 PASS). T-2060 (true-positive case, two committed render-surface templates) still trips the gate as designed. The fallback to body+components scan preserves the 12 existing bats cases. The new bats coverage (3 cases — false-positive rejection, true-positive preservation, files-in correctness) pins the contract for the next instance.

**Evidence:**
- `lib/render_surface.sh:67-180` — `task_touches_render_surface` + `render_surface_files_in` use new `_render_surface_extract_task_id` + `_render_surface_git_touched_paths` helpers, body-scan kept as fallback
- `tests/unit/test_render_surface_gate.bats` — 15/15 green (12 original + 3 new T-2061)
- `dc62ea37 T-2056: work-completed under new T-2061 render-surface predicate` — proof closure path
- `b33581f9 T-2061: fix L-435 — render-surface gate prefers git evidence over body-text tokens` — implementation commit
- `bin/fw doctor` — 0 failures (19 warnings, all pre-existing)

## Updates

### 2026-05-28T11:37:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2061-render-surface-gate-prefer-actual-commit.md
- **Context:** Initial task creation
