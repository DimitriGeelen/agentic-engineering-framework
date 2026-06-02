---
id: T-2174
name: "Reviewer FAIL fix batch A — Verification-block hygiene across 17 completed/ tasks (clusters 1-4 from T-2173)"
description: >
  Apply uniform Verification-block edits to 17 completed/ tasks where reviewer FAIL fingerprint is one of: skip-as-pass (8), swallowed-errors (6), tautology+empty-output (2), empty-body (1). All four clusters are real verification gaps (89% of cached FAILs); the detector is high-precision. Edit shape is uniform per cluster — see T-2173 Recommendation + docs/reports/T-2173-reviewer-fail-sweep.md for cluster→task mapping.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [reviewer-quality, fail-fix, completed-corpus-hygiene, T-2173-child]
components: []
related_tasks: [T-2173, T-1443]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T08:39:47Z
last_update: 2026-06-02T08:39:47Z
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

# T-2174: Reviewer FAIL fix batch A — Verification-block hygiene across 17 completed/ tasks (clusters 1-4 from T-2173)

## Context

Parent: T-2173 (inception, recommendation = GO). Cluster→task mapping is verbatim from the parent's Recommendation:

| Cluster | Pattern | Tasks (cached) |
|---------|---------|----------------|
| 1 | skip-as-pass | T-1516, T-1514, T-1594, T-1734, T-1738, T-1903, T-2072, T-2124 |
| 2 | swallowed-errors | T-1471, T-1581, T-1596, T-1694, T-1751, T-1814 |
| 3 | tautology + empty-output | T-1517, T-1518 |
| 4 | empty-body | T-1644 |

Edit shape per cluster (uniform within cluster):

- **Cluster 1 (skip-as-pass):** replace `if [ -f X ]; then test; fi` (skip-equals-pass) with `if [ ! -f X ]; then echo "expected X missing" >&2; exit 1; fi; test` (fail-loud).
- **Cluster 2 (swallowed-errors):** drop `... || true`, `2>/dev/null || exit 0`, and similar error-discard suffixes. Keep the upstream command as the actual assertion.
- **Cluster 3 (tautology + empty-output):** replace `true`, `[ 1 -eq 1 ]`, `echo done` with the actual check the AC was guarding. If the original intent can't be recovered from git log, write a placeholder check that fails on regression of the AC's stated outcome.
- **Cluster 4 (empty-body):** retro-fill T-1644 body sections (AC, Recommendation if present) from git log + episodic + handover trail dated around the work-completed timestamp.

Low blast-radius: completed/ task Verification commands don't re-run against the gate. The edits are for retroactive scanability and corpus consistency.

## Acceptance Criteria

### Agent
- [ ] Cluster 1 (8 tasks: T-1516, T-1514, T-1594, T-1734, T-1738, T-1903, T-2072, T-2124) — Verification block edited to fail-loud on the skip-as-pass path. Verification per-task: `bin/fw reviewer T-XXX --no-write --json | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); ok = all(f.get('pattern_id') != 'skip-as-pass' for f in d.get('findings',[])); print(ok)"` returns `True` for each.
- [ ] Cluster 2 (6 tasks: T-1471, T-1581, T-1596, T-1694, T-1751, T-1814) — `|| true` and similar swallow patterns removed. Verification per-task: same JSON check above with `pattern_id != 'swallowed-errors'`.
- [ ] Cluster 3 (2 tasks: T-1517, T-1518) — tautology / empty-output replaced with substantive check. Verification per-task: pattern `tautology` and `empty-output-success` no longer fire.
- [ ] Cluster 4 (T-1644) — body retro-filled from git log + episodic. Verification: pattern `empty-body` no longer fires AND body sections are non-template-only.
- [ ] **Aggregate verification:** `count=$(grep -l "Overall:.*FAIL" .tasks/completed/T-*.md | wc -l); echo "$count"` returns a number strictly less than the pre-edit baseline (19) by at least 17 (one per cluster-1/2/3/4 task edited).
- [ ] No edits to `## Decisions` or `## Updates` sections of touched tasks (Verification block only, plus body retro-fill for Cluster 4).
- [ ] Commit message per cluster lists the touched task IDs (single commit per cluster keeps diff reviewable).

### Human
- [ ] [REVIEW] Cluster 3 + Cluster 4 edits reflect genuine intent recovery, not invented placeholders.
  **Steps:**
  1. `git diff <commit-cluster-3> -- .tasks/completed/T-1517-*.md .tasks/completed/T-1518-*.md`
  2. `git diff <commit-cluster-4> -- .tasks/completed/T-1644-*.md`
  3. Verify the replacement Verification command relates to the AC's stated outcome
  **Expected:** Substantive intent recovered, not "while we're editing the file" filler.
  **If not:** Push back; agent re-derives from git log.

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

### 2026-06-02T08:39:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2174-reviewer-fail-fix-batch-a--verification-.md
- **Context:** Initial task creation
