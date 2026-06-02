---
id: T-2174
name: "Reviewer FAIL fix batch A — Verification-block hygiene across 17 completed/
  tasks (clusters 1-4 from T-2173)"
description: >
  Apply uniform Verification-block edits to 17 completed/ tasks where reviewer FAIL
  fingerprint is one of: skip-as-pass (8), swallowed-errors (6), tautology+empty-output
  (2), empty-body (1). All four clusters are real verification gaps (89% of cached
  FAILs); the detector is high-precision. Edit shape is uniform per cluster — see
  T-2173 Recommendation + docs/reports/T-2173-reviewer-fail-sweep.md for cluster→task
  mapping.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [reviewer-quality, fail-fix, completed-corpus-hygiene, T-2173-child]
components: []
related_tasks: [T-2173, T-1443]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T08:39:47Z
last_update: 2026-06-02T11:47:00Z
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
bvp_scores_proposed:
  - ts: '2026-06-02T08:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T08:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
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

**Scope revised 2026-06-02 — see `## Evolution` for the §ACD pivot. Clusters
1+2 are detector-FP-dominant (14/19 of cached FAILs); the mechanical 17-task
batch is the wrong fix. Cluster 1+2 work moved to a new sibling task (detector
tightening). This task retains only the genuine + borderline cases.**

- [x] Cluster 3 — T-1517 + T-1518: trailing `echo "T-XXXX verification ok"`
  line deleted. Per-task verification (T-1517): `out=$(bin/fw reviewer T-1517 --no-write --json); echo "$out" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); ok = all(f.get('pattern_id') != 'tautology' for f in d.get('findings',[])); print(ok)"` returns `True` (also FAIL→CONCERN overall). Same for T-1518 (FAIL→PASS overall).
- [x] Cluster 4 — T-1644: **NO EDIT NEEDED.** Body was already retro-filled in
  May 2026 (5 Agent ACs filled and ticked); cached `## Reviewer Verdict (v1.4)`
  block dated 2026-05-01T13:08:53Z reflected the pre-fill placeholder state.
  Fresh scan today: FAIL→CONCERN (empty-body gone, residual AC-verify-mismatch
  is different class). This is a cache-staleness instance — T-2176 (Fix C)
  write-back over completed/ will materially close this leg.
- [ ] Borderline T-1594 + T-2072: **DEFERRED to post-T-2177.** Both use `--dry-run`
  with `--quiet` suppression / exit-code-only assertion — the genuine "safe smoke"
  pattern for commands with side effects. Detector tightening (T-2177) will likely
  drop these to PASS naturally without rewriting historical verification semantics.
  Re-evaluate after T-2177 lands.
- [x] Sibling detector-tightening task filed (id **T-2177**, "Reviewer FAIL fix
  batch D — tighten skip-as-pass + swallowed-errors detectors…", captured +
  horizon: later, owner: agent). Verification:
  `ls .tasks/active/T-2177-*.md >/dev/null`.
- [x] **Aggregate verification:** Cached FAIL count BEFORE/AFTER this task is
  unchanged at the file-body level (cached `## Reviewer Verdict (v1.4)` blocks
  in completed/ task files are not rewritten until a fresh `fw reviewer T-XXX`
  run with write-back, which is T-2176/Fix C's job). The aggregate gauge for
  this task is the per-task fresh-scan outcome: T-1517 FAIL→CONCERN, T-1518
  FAIL→PASS, T-1644 FAIL→CONCERN (cache-stale). All three verified above with
  `bin/fw reviewer T-XXXX --no-write --json`.
- [x] No edits to `## Decisions` or `## Updates` sections of touched tasks (Verification block edits only on T-1517/T-1518; no edit on T-1644).
- [ ] Single commit listing the touched task IDs; commit body cites the §ACD
  pivot rationale from `## Evolution`.

### Human
- [ ] [REVIEW] T-1644 retro-fill reflects genuine intent recovery from git
  history, not invented placeholders.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && git diff <commit-sha> -- .tasks/completed/T-1644-*.md`
  2. Compare the retro-filled sections against the git log between T-1644's
     `date_created` and `date_finished`
  3. Verify the Recommendation + ACs reflect what the task actually did
  **Expected:** Body density and content match the commit trail; no placeholder text.
  **If not:** Push back with specific paragraph; agent re-derives from git log.

- [ ] [REVIEW] Detector-tightening scope (T-NEW-FIX-D) is right-sized — not
  over-engineered, not too narrow.
  **Steps:**
  1. Read the new sibling task's Problem Statement + Recommendation
  2. Sanity-check that the proposed regex tightening preserves true positives
     (genuine `pytest --collect-only`, `@unittest.skip`, etc.) while excluding
     the assert-absent idiom + `--dry-run + assertion`
  **Expected:** Heuristics are concrete and testable.
  **If not:** Push back with specific case the heuristic misses.

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

### 2026-06-02 — Cluster 1+2 detector-FP discovery (§ACD pivot)

- **What changed:** Fresh per-task reviewer runs (not cached verdicts) on Cluster 1
  (skip-as-pass × 8) and Cluster 2 (swallowed-errors × 6) reveal that the parent
  T-2173 analysis under-counted detector false positives. T-2173 worked off cached
  verdict TEXT (grep'd from completed/ task bodies) and pattern-matched fingerprints
  against the cluster names. It did NOT re-run the detector against the original
  Verification block to inspect what the regex actually matched.
- **Cluster 1 — skip-as-pass (8 tasks):** The detector regex
  `(--collect-only|--skip\b|SKIP=true|--dry-run|--check-only|...)` matches
  `--dry-run` and `--skip-X` substrings textually. Re-running per-task:
  - T-1516: the trigger is `--skip-sovereignty` **inside a `grep -E 'pattern'`
    argument** (searching for stale guidance about that flag in audit.sh) — the
    detector matches the grep pattern as if it were a CLI flag. Pure FP.
  - T-1514, T-1734, T-1738 (×4), T-1903, T-2124 (×2): all use `--dry-run` followed
    by `| grep -q "..."` output assertion. This is legitimate simulation with a
    semantic check, not skip-equals-pass. Detector FP from over-broad `--dry-run`
    match.
  - T-1594: `bin/fw mirror sync --dry-run --quiet` — no output assertion after.
    Borderline genuine (passes if `--dry-run` exits 0, no semantic check).
  - T-2072: `out=$(... --dry-run 2>&1); echo "$?" | grep -q "^0$"` — exit-code-only
    assertion. Borderline genuine (same shape as T-1594).
- **Cluster 2 — swallowed-errors (6 tasks):** Detector matches `|| true`. Re-running:
  All 6 tasks (T-1471, T-1581, T-1596, T-1694, T-1751, T-1814) use the
  **assert-pattern-absent idiom**: `cmd | grep -q PATTERN && exit 1 || true` —
  "if pattern matches, fail; otherwise pass". The trailing `|| true` is structurally
  NECESSARY (grep exit 1 on no-match would kill the script under `set -e`). The
  rewrite `! cmd | grep -qE PATTERN` is the canonical equivalent. Detector FPs
  from idiom-blind matching.
- **Genuine fixable (3 tasks):**
  - T-1517 + T-1518 (Cluster 3 tautology): trailing `echo "T-XXX verification ok"`
    — literal tautology, always passes. Fix: delete the line.
  - T-1644 (Cluster 4 empty-body): 119 lines, no `## Recommendation` section.
    Fix: retro-fill body from git log + episodic.
- **Borderline (2 tasks):** T-1594, T-2072 — `--dry-run` without semantic output
  assertion. Genuine-ish, but the fix is to add an assertion, not "fail loud on
  skip path".
- **Plan impact:** Cluster 1 + Cluster 2 mechanical batch (14 tasks) is the wrong
  scope. Applying "fail-loud" rewrites to legitimate `--dry-run --quiet` or
  `assert-pattern-absent` semantics would BREAK correct verification logic.
  T-2173's NO-GO criterion ">50% detector-FPs → detector needs work before retro
  fix" is now in force: 14/19 of cached FAILs (74%) are detector FPs.
- **Triggered:**
  - **T-2174 scope reduction:** retain only the 3 genuine + 2 borderline = 5 tasks
    (T-1517, T-1518, T-1644, T-1594, T-2072). Clusters 1+2 (12 tasks) removed
    from scope.
  - **Sibling build task filed:** **T-2177** "Reviewer FAIL fix batch D —
    tighten skip-as-pass + swallowed-errors detectors against assert-absent
    idiom and --dry-run + assertion FPs" (captured + horizon: later, owner:
    agent). Distinguishes the `--dry-run + assertion` and
    `&& exit 1 || true` (assert-absent) idioms from genuine
    skip-equals-pass.

### 2026-06-02 — §ACD class learning

- **Lesson:** When an analysis works off cached verdict TEXT (grep'd fingerprints),
  it inherits the detector's blind spots without seeing them. The fresh-scan step
  (Fix C / T-2176) was scheduled to surface MISSING FAILs, but should also have been
  run to AUDIT the cached fingerprints' classification. Future inception sweeps over
  any cached verdict corpus should re-run the detector against a sample to validate
  the cluster→genuine classification before recommending a mechanical fix batch.
- **Captured as:** memory entry [[feedback_cached_verdict_text_blind_spot]] (to file).

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

### 2026-06-02T11:47:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
