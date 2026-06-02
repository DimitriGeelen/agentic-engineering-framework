---
id: T-2176
name: "Reviewer FAIL fix batch C — fresh fw reviewer scan over completed/ to surface 12 missing FAILs + write-back current verdicts"
description: >
  Today's audit reports FAIL=31 but only 19 are cached in completed/ task bodies via grep. The 12-task gap is the cache-vs-current drift (older verdict blocks written before catalogue v1.3 grew). Fix C: run fw reviewer T-XXX --no-write OR with write-back over every completed/ task, capture current per-task verdict + findings, surface the 12 untyped FAILs into one of T-2173 Clusters 1-6 (or a new cluster if shape differs). After Fix C, grep-l on Overall:.*FAIL in completed/ matches the audit's count exactly.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [reviewer-quality, fail-fix, corpus-rescan, T-2173-child, cache-gap-close]
components: []
related_tasks: [T-2173, T-2174, T-2175, T-1443, T-1951]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T08:41:56Z
last_update: 2026-06-02T08:41:56Z
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

# T-2176: Reviewer FAIL fix batch C — fresh fw reviewer scan over completed/ to surface 12 missing FAILs + write-back current verdicts

## Context

Parent: T-2173. Today's audit (.context/audits/reviewer/2026-06-02.yaml) reports FAIL=31. T-2173's cluster extraction via `grep -l "Overall:.*FAIL" .tasks/completed/T-*.md` found only 19 — a 12-task gap. The gap is because individual task verdict blocks (`## Reviewer Verdict (v1.4)`) cache the result of the *last* `fw reviewer T-XXX` run on that task, not today's audit scan. Many completed tasks haven't been per-task-scanned since the v1.3 catalogue grew.

This task closes the cache gap structurally:

1. Iterate completed/ tasks (1951 files).
2. For each, run `fw reviewer T-XXX` (write-back mode — updates the `## Reviewer Verdict` block).
3. Use `--dispatch` (T-1951) for isolation when running over the corpus; a single TermLink worker per batch of N tasks keeps the parent session context cost zero. Alternative: GNU parallel-style sequential since each scan is <2s.
4. Post-batch: `grep -l "Overall:.*FAIL" .tasks/completed/T-*.md | wc -l` should match the audit's count exactly (31 today).
5. Diff the new FAIL list against T-2173's cluster mapping — the 12 missing tasks land in one of Clusters 1-6 OR surface a new cluster. If a new cluster appears, file Fix D as sibling.

**Cost note:** 1951 × ~1s/scan = ~30 min serial. With `--dispatch` and 5 parallel workers, ~6 min. Acceptable.

**Side effect:** all 1951 completed/ task files get a fresh `## Reviewer Verdict` block (rewriting the cached one). This is a large diff but mechanically safe — only verdict-block content changes, not any AC/Verification/Decisions text.

## Acceptance Criteria

### Agent
- [ ] Fresh per-task verdict written for every task in `.tasks/completed/`. Verification: `n_scanned=$(grep -l "Scan ID:" .tasks/completed/T-*.md | wc -l); test "$n_scanned" -ge 1900` (allow ~50 task slack for any that the reviewer skips legitimately — e.g. tasks with no body / fragments).
- [ ] Verdict cache matches today's audit count. Verification: `n_fail=$(grep -l "Overall:.*FAIL" .tasks/completed/T-*.md | wc -l); audit_fail=$(python3 -c "import yaml; print(yaml.safe_load(open('.context/audits/reviewer/2026-06-02.yaml'))['totals']['FAIL'])"); test "$n_fail" -ge "$audit_fail"` (or `==` if scan-day timing aligns).
- [ ] The 12 previously-uncached FAILs are mapped to T-2173 clusters or surface as a new cluster. Output: `docs/reports/T-2176-cache-gap-resolution.md` lists each newly-surfaced FAIL with its pattern fingerprint.
- [ ] If a new cluster surfaces (not in T-2173's 1-6), file Fix D as captured + horizon: later sibling — same shape as Fix A/B.
- [ ] Single commit per batch of N tasks (suggest N=50 or per-cluster) — keeps diff reviewable. Each commit message references this task ID.
- [ ] No edits to AC / Verification / Decisions sections during the scan write-back (verdict block only). Verification: spot-check 5 tasks pre/post — `git diff` should show only `## Reviewer Verdict` block changes.

### Human
- [ ] [REVIEW] The newly-surfaced FAILs (the 12) are routed to the correct cluster, not lumped into a catch-all.
  **Steps:**
  1. Read `docs/reports/T-2176-cache-gap-resolution.md`
  2. For each newly-surfaced task, confirm the cluster assignment makes sense given the AC + Verification text
  3. If a "new cluster" is declared, confirm it's genuinely distinct from Clusters 1-6 (not just a minor variant)
  **Expected:** Cluster routing is principled.
  **If not:** Push back; agent re-routes.

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

### 2026-06-02T08:41:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2176-reviewer-fail-fix-batch-c--fresh-fw-revi.md
- **Context:** Initial task creation
