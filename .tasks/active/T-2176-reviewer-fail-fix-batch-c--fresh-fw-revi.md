---
id: T-2176
name: "Reviewer FAIL fix batch C — fresh fw reviewer scan over completed/ to surface
  12 missing FAILs + write-back current verdicts"
description: >
  Today's audit reports FAIL=31 but only 19 are cached in completed/ task bodies via
  grep. The 12-task gap is the cache-vs-current drift (older verdict blocks written
  before catalogue v1.3 grew). Fix C: run fw reviewer T-XXX --no-write OR with write-back
  over every completed/ task, capture current per-task verdict + findings, surface
  the 12 untyped FAILs into one of T-2173 Clusters 1-6 (or a new cluster if shape
  differs). After Fix C, grep-l on Overall:.*FAIL in completed/ matches the audit's
  count exactly.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [reviewer-quality, fail-fix, corpus-rescan, T-2173-child, cache-gap-close]
components: [lib/reviewer/static_scan.py]
related_tasks: [T-2173, T-2174, T-2175, T-1443, T-1951]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T08:41:56Z
last_update: 2026-06-06T06:25:15Z
date_finished: 2026-06-06T06:25:15Z
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
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 3
      F-ORCH: 5
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-ORCH=5 (body:substrate-expand)
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
- [x] Fresh per-task verdict written for every task in `.tasks/completed/`. Verification: `n_scanned=$(grep -l "Scan ID:" .tasks/completed/T-*.md | wc -l); test "$n_scanned" -ge 1900` (allow ~50 task slack for any that the reviewer skips legitimately — e.g. tasks with no body / fragments).
- [x] Verdict cache matches today's audit count. Verification: `n_fail=$(grep -l "Overall:.*FAIL" .tasks/completed/T-*.md | wc -l); audit_fail=$(python3 -c "import yaml; print(yaml.safe_load(open('.context/audits/reviewer/2026-06-02.yaml'))['totals']['FAIL'])"); test "$n_fail" -ge "$audit_fail"` (or `==` if scan-day timing aligns).
- [x] The 12 previously-uncached FAILs are mapped to T-2173 clusters or surface as a new cluster. Output: `docs/reports/T-2176-cache-gap-resolution.md` lists each newly-surfaced FAIL with its pattern fingerprint.
- [x] If a new cluster surfaces (not in T-2173's 1-6), file Fix D as captured + horizon: later sibling — same shape as Fix A/B.
- [x] Single commit per batch of N tasks (suggest N=50 or per-cluster) — keeps diff reviewable. Each commit message references this task ID.
- [x] No edits to AC / Verification / Decisions sections during the scan write-back (verdict block only). Verification: spot-check 5 tasks pre/post — `git diff` should show only `## Reviewer Verdict` block changes.

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

# T-2176 verification (capture-then-grep per L-387).
# Cache↔audit alignment uses the LATEST audit (T-2176 batch landed across
# multiple audit cycles — hardcoding 2026-06-02 went stale 4 days later when
# subsequent fixes drove the FAIL count to zero; today's audit is the truth).
n_scanned=$(grep -l "Scan ID:" .tasks/completed/T-*.md | wc -l); test "$n_scanned" -ge 1900
latest_audit=$(ls -t .context/audits/reviewer/2026-*.yaml | head -1); n_fail=$(grep -l "^- \*\*Overall:\*\* FAIL$" .tasks/completed/T-*.md | wc -l); audit_fail=$(python3 -c "import yaml,sys; print(yaml.safe_load(open('$latest_audit'))['totals']['FAIL'])"); test "$n_fail" -eq "$audit_fail"
test -s docs/reports/T-2176-cache-gap-resolution.md && grep -q "tautology" docs/reports/T-2176-cache-gap-resolution.md
# AC#4 — Fix D filed (T-2179 exists in active/ OR completed/). Originally
# captured + horizon: later; since shipped to completed/. The AC's intent
# was "the cluster was triaged + filed", which holds whichever side it lives on.
{ ls .tasks/active/T-2179-* 2>/dev/null || ls .tasks/completed/T-2179-* 2>/dev/null; } | head -1 | grep -q .

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

**Symptom:** Audit said FAIL=31, but `grep -l "Overall:.*FAIL"` on completed/ matched only 19 (later precise grep: 20). 12-task delta — undiagnosable without a fresh per-task scan because the cached `## Reviewer Verdict` blocks pre-dated the v1.3-seed catalogue growth.

**Root cause:** Reviewer-verdict cache (per-task `## Reviewer Verdict` block) is **lazy** — it's only updated when `fw reviewer T-XXX` is run on that task. The daily audit cron (`fw reviewer audit`) re-runs static-scan over the whole corpus and tallies fresh — but does NOT write back per-task. So the audit's tally and the cached blocks drift apart silently. Compound with detector catalogue evolution (v1.0 → v1.3-seed) and the cache becomes a stale fossil.

**Why structurally allowed:** No gate compares audit totals against `grep -l "Overall:.*FAIL"` cache. The audit YAML is the source of truth for "today"; the cache is the source of truth for "last per-task run". Two truths, no reconciliation gate.

**Prevention:** Three legs:
1. **This task (T-2176) is the one-shot reconciler** — fresh scan, write-back to every completed task. After this, the cache reflects v1.3-seed reality.
2. **Going forward — bug class identified:** `bin/fw reviewer T-XXX --no-write --json` exits 1 when verdict is FAIL (test-runner semantics). My initial Pass A wrapper used `if json=$(...)` which treats exit 1 as command failure, masking 14 FAILs as ERROR. Filed as L-453 to learnings (capture-then-parse, never gate JSON capture on exit code).
3. **Could close the loop:** an audit-side detector "drift between audit totals and cached verdict-block totals" would auto-flag the next cache-vs-audit gap. Deferred — not filed yet; T-2176 closure is sufficient to clear today's gap.

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

### 2026-06-02 — Exit-code-1-as-error masked 14 FAILs

- **What changed:** Pass A wrapper script (`tools/t2176-corpus-rescan.sh`) used `if json=$(bin/fw reviewer "$tid" --no-write --json 2>/dev/null); then ...` and the reviewer exits 1 on FAIL (test-runner semantics). 14 tasks scanned in Pass A returned exit 1 (genuine FAILs) and were silently bucketed as ERROR. Summary showed `FAIL=0 ERR=14` — wildly inconsistent with the audit's `FAIL=31`. Re-running each ERROR individually returned FAIL with full findings.
- **Plan impact:** Pass A's verdict counts were unreliable; had to do a second per-task pass to extract real verdicts. The write-back (Pass B) was already conditioned on `verdict != ERROR`, so 14 tasks didn't get fresh verdict blocks. Manual write-back patched the gap.
- **Triggered:** L-453 learning ("reviewer JSON capture must be exit-code-tolerant — FAIL is exit 1, valid result"). Tooling note added to `tools/t2176-corpus-rescan.sh`.

### 2026-06-02 — Audit was stale, not the cache

- **What changed:** The premise — "audit count == truth; cache must match" — inverted under analysis. Audit ran at 08:33 UTC against v1.3-seed catalogue. T-2177 detector tightening landed at 13:05 CEST and cleared 21 of 23 `skip-as-pass` fires. Cached verdicts (post-Pass-B writeback) became the LIVE truth; audit needed re-run. Re-running `fw reviewer audit` produced fresh FAIL=14, aligning all three measures.
- **Plan impact:** AC#2 wording ("test n_fail -ge audit_fail") was correct in spirit but predicated on audit-as-baseline. Replaced with `test -eq` after refreshing the audit YAML.
- **Triggered:** Already covered — [[feedback_cached_verdict_text_blind_spot]] memory pointer reinforces "re-run the detector AND inspect each finding before recommending a CLASS"; this turn extended that to "re-run the audit too, don't trust morning snapshots when catalogue drift is suspected".

### 2026-06-02 — tautology surfaced as cluster 7

- **What changed:** Of 14 fresh FAILs, 3 trip the `tautology` detector (T-123, T-445, T-876) — a pattern NOT in T-2173's Clusters 1-6. Filed Fix D as T-2179 horizon:later sibling. The remaining 11 fall into existing Clusters 1+2+4+5+6 (skip-as-pass × 3, swallowed-errors × 8, with mixed secondary patterns).
- **Plan impact:** T-2173's "Clusters 1-6" was not exhaustive — cluster 7 surfaced empirically. Future fix-track planning should treat the cluster taxonomy as open-ended.
- **Triggered:** T-2179 filed (Reviewer FAIL fix batch D — tautology cluster, 3 tasks).

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

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 Agent ACs satisfied. Fresh per-task verdicts written to 1954 completed tasks (up from 547 cached); audit re-run aligns at FAIL=14; the 14 fresh FAILs are mapped — 11 to T-2173 Clusters 1+2+4+5+6, 3 to a new tautology cluster (Fix D filed as T-2179 horizon:later). The 17-task delta between morning audit (FAIL=31) and afternoon audit (FAIL=14) is explained: T-2177's `skip-as-pass` quoted-context + same-line-assertion suppressions cleared 21 of 23 detector fires (audit shows `skip-as-pass: 23 → 2`). The fix-track is on solid empirical footing.

**Evidence:**
- **Scan coverage:** `grep -l "Scan ID:" .tasks/completed/T-*.md | wc -l` → 1954 (≥ 1900 AC threshold). All completed tasks scanned with v1.3-seed catalogue post-T-2177.
- **Cache↔audit alignment:** `grep -l "^- \*\*Overall:\*\* FAIL$" .tasks/completed/T-*.md | wc -l` → 14, matches `fw reviewer audit` totals.FAIL → 14 (refreshed 2026-06-02T15:13Z).
- **Cluster routing:** `docs/reports/T-2176-cache-gap-resolution.md` lists each of the 14 FAILs with its pattern fingerprint and cluster assignment.
- **Fix D filed:** `T-2179-reviewer-fail-fix-batch-d--tautology-pat.md` exists, `horizon: later`, tagged `T-2173-child`.
- **Diff hygiene:** Spot-check of 5 files shows only `## Reviewer Verdict` block additions; AC/Verification/Decisions sections untouched.
- **Bug found:** Reviewer exit-code-1-on-FAIL caused 14 silent ERROR mis-classifications in Pass A. L-453 captured.

**What's next (operator-facing):**
- **T-2174** (Cluster 1+2 §ACD pivot) — already surfaced via `/review/T-2174`.
- **T-2175** (Cluster 3 mock-only-integration) — promoted to `horizon: now` this session.
- **T-2179** (Cluster 7 tautology — NEW) — horizon: later, awaiting prioritisation.
- **T-2173 parent** can close once Fixes A+B+D land.

## Updates

### 2026-06-02T08:41:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2176-reviewer-fail-fix-batch-c--fresh-fw-revi.md
- **Context:** Initial task creation

### 2026-06-02T14:36:48Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-06-02T14:52:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4528f123
- **Timestamp:** 2026-06-06T06:25:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Agent)** — Verdict cache matches today's audit count. Verification: `n_fail=$(grep -l "Overall:.*FAIL" .tasks/completed/T-*.md | wc -l); audit_fail=$(python3 -c "import yaml; print(yaml.safe_load(open('.context/
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/reviewer/2026-06-02.yaml in: Verdict cache matches today's audit count. Verification: `n_fail=$(grep -l "Overall:.*FAIL" .tasks/completed/T-*.md | wc -l); audit_fail=$(python3 -c `

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 42
     - evidence: `{ ls .tasks/active/T-2179-* 2>/dev/null || ls .tasks/completed/T-2179-* 2>/dev/null; } | head -1 | grep -q .`

### 2026-06-06T06:25:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
