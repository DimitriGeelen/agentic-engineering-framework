---
id: T-2281
name: "T-2275 build: auto-linker prongs A+B (Candidate 2) — add docs/articles/ + root files to VIEWABLE allowlist"
description: >
  T-2275 build: auto-linker prongs A+B (Candidate 2) — add docs/articles/ + root files to VIEWABLE allowlist

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-09T08:45:55Z
last_update: 2026-06-09T08:45:55Z
date_finished: null
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
---

# T-2281: T-2275 build: auto-linker prongs A+B (Candidate 2) — add docs/articles/ + root files to VIEWABLE allowlist

## Context

Build child of T-2275 (inception, GO). Implements Candidate 2 — extends
`web/shared.py:518` `VIEWABLE_DIR_PREFIXES` with `docs/articles/`,
`docs/plans/`, `docs/dispatch-templates/`, adds `ROOT_FILES` allowlist
for `README.md`/`CLAUDE.md`/`FRAMEWORK.md`/`VERSION`/`LICENSE`/`CHANGELOG`,
and extends `_build_artefact_path_re` so both forms emit `<a href="/file/">`.
See `docs/reports/T-2275-auto-linker-rca.md` for the full design.

## Acceptance Criteria

### Agent
- [x] `web/shared.py` extends `VIEWABLE_DIR_PREFIXES` with `docs/articles/`, `docs/plans/`, `docs/dispatch-templates/`
- [x] `web/shared.py` adds `ROOT_FILES` frozenset containing the 6 root file names
- [x] `is_viewable_path("README.md")` returns True; `is_viewable_path("docs/articles/x.md")` returns True
- [x] `tests/unit/test_auto_link_root_and_articles.py` exists with ≥4 tests (positive root, positive docs/articles/, negative random root, traversal rejected)
- [x] `python3 -m pytest tests/unit/test_auto_link_root_and_articles.py -q` exits 0
- [x] Existing `tests/unit/test_render*` and `tests/unit/test_extract_recommendation.py` still pass (no regression)
- [x] Live verification: `curl -s http://localhost:3000/review/T-2274 | grep -oE '<a href="/file/README.md"[^>]*>'` returns non-empty (the operator's specific repro path)
- [x] `bin/fw reviewer T-2281` returns PASS

### Human
- [ ] [REVIEW] Confirm the operator-reported repro path now produces a clickable link
  **Steps:**
  1. Open http://192.168.10.107:3000/review/T-2274 in a browser AFTER this ships (Watchtower auto-reloads on web/shared.py edits; if not, run `bin/fw watchtower restart`).
  2. Find the line in Human AC Steps containing "README.md" — the bug from /inception/T-2275.
  3. Click the README.md text. Expected: navigates to `/file/README.md` and shows the README content.
  4. Repeat for any `docs/articles/...` reference visible on the page.
  **Expected:** Both paths render as clickable anchors (cursor changes to pointer; click navigates to /file/...).
  **If not:** Hard-reload Ctrl+Shift+R. If still failing, share the inspected HTML for that path so we can see whether the regex matched.

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
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

grep -q "docs/articles/" web/shared.py
grep -q "ROOT_FILES" web/shared.py
test -f tests/unit/test_auto_link_root_and_articles.py
out=$(python3 -m pytest tests/unit/test_auto_link_root_and_articles.py -q 2>&1); echo "$out" | grep -q "passed"
out=$(curl -s http://localhost:3000/review/T-2274 2>&1); echo "$out" | grep -qE '<a href="/file/README\.md"'
out=$(bin/fw reviewer T-2281 2>&1); echo "$out" | grep -qE "Overall:.*PASS"

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

## Recommendation

**Recommendation:** GO — tick the [REVIEW] Human AC and close.

**Rationale:** The operator's specific repro (README.md and
docs/articles/launch-article.md rendering as `<code>` not `<a>`) is
verified fixed in production. `web/shared.py` extended with three new
docs prefixes + ROOT_FILES allowlist + alternation in the artefact
regex. All 16 unit tests pass; the `/file/<path>` route serves the
newly-linked paths with HTTP 200; live `curl` on
http://localhost:3000/review/T-2274 emits
`<a href="/file/README.md">` exactly as designed. No regression on
the original T-1722 docs/reports/ surface. Reviewer PASS.

**Evidence:**
- web/shared.py:540-554 — ROOT_FILES allowlist constant.
- web/shared.py:564-577 — is_viewable_path with allowlist branch.
- web/shared.py:594-624 — _build_artefact_path_re with root-files alternative.
- tests/unit/test_auto_link_root_and_articles.py — 16/16 PASS.
- Live verification: `curl -s http://localhost:3000/review/T-2274 | grep
  '<a href="/file/README.md">'` returns the anchor (operator's repro path).
- /file/README.md → HTTP 200; /file/docs/articles/launch-article.md → HTTP 200.
- Reviewer R-646331bf: Overall PASS, 0 findings.
- Existing T-1722 surface (`docs/reports/...`) still emits anchors —
  no regression (test_docs_reports_path_still_works_no_regression PASS).

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

### 2026-06-09T08:45:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2281-t-2275-build-auto-linker-prongs-ab-candi.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-646331bf
- **Timestamp:** 2026-06-09T08:50:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
