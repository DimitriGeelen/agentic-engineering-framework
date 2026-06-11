---
id: T-2168
name: "BVP estimator extension for F-RECALL + F-ORCH heuristics (T-NEW-A from T-2157/T-2165
  v3 follow-ups)"
description: >
  BVP estimator extension for F-RECALL + F-ORCH heuristics (T-NEW-A from T-2157/T-2165
  v3 follow-ups)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [v3-followup-A]
components: [C-004, agents/termlink/bvp-estimator/estimator.py, 
      tests/unit/test_audit_retire_when.bats, tests/unit/test_bvp_estimator.py]
related_tasks: [T-2157, T-2165, T-2166, T-1922, T-1923, T-1935]
arc_id: value-prioritisation
created: 2026-06-01T20:28:50Z
last_update: '2026-06-11T22:24:10Z'
date_finished: 2026-06-09T22:45:48Z
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
  - ts: '2026-06-01T20:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-ORCH: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 (body:default-change);
      D4=2 (body:env-class-handled); F-RECALL=1 (body/tag hits for 'F-RECALL': 1);
      F-ORCH=1 (body/tag hits for 'F-ORCH': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T20:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 1
      F-ORCH: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=2
      (body:env-class-handled); F-RECALL=1 (body/tag hits for 'F-RECALL': 1); F-ORCH=1
      (body/tag hits for 'F-ORCH': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 5
      F-ORCH: 5
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=5 
      (body/components:retrieval-layer); F-ORCH=5 (body:substrate-expand); F3=1 
      (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-01T20:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T20:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2168: BVP estimator extension for F-RECALL + F-ORCH heuristics (T-NEW-A from T-2157/T-2165 v3 follow-ups)

## Context

Pre-scoped follow-up T-NEW-A from the value-drivers.yaml v3 chain
(T-2157 inception → T-2165 evidence walk → T-2166 schema rename, committed `5a3b643c`).
v3 activated two free drivers: **F-RECALL** (weight 6) and **F-ORCH** (weight 5),
with full rubric + guardrails defined in `policy/value-drivers.yaml` lines 95-149.

The BVP estimator (`agents/termlink/bvp-estimator/estimator.py`) currently scores
D1-D4 via dedicated heuristic functions (`score_d1_antifragility` etc.) with
substantive body-pattern matching, but free drivers fall through to a generic
`score_free_driver()` placeholder that does naive driver-id string-count. This
task even self-scored F-RECALL=1 / F-ORCH=1 from "`'F-RECALL'` appears once in body" —
a degenerate signal that has nothing to do with what the rubric is measuring.

This slice replaces the placeholder with two real heuristic scorers (one per
active free driver), modelled on the D1-D4 pattern, anchored to the rubric +
guardrails text-content in `policy/value-drivers.yaml`.

**Filed as `captured + horizon: later`** — operator's call on when to start work
(per the T-2157/T-2165 memo: T-NEW-A through T-NEW-E are pre-scoped but
prioritisation is the human's choice).

## Acceptance Criteria

### Agent
- [x] `agents/termlink/bvp-estimator/estimator.py` gains `score_f_recall(fm, body, tags) -> (int, list[str])` modelled on `score_d1_antifragility()` structure. The function maps real signals to the 0-5 rubric in `policy/value-drivers.yaml` lines 105-112: level 0 (no durable artifact), level 1 (session-scoped capture only), level 2 (lightly promoted but not retrievable), level 3 (writes `[[memory_slug]]`-linkable / `fw recall`-findable artifact), level 4 (closes capture→encode→synced-into-CLAUDE.md loop), level 5 (improves the retrieval/synthesis layer itself). Heuristic signals must distinguish those levels by genuine file-path / pattern evidence (e.g. wrote to `.context/episodic/` only = 1; wrote `[[memory]]` link in commit msg = 3; touched CLAUDE.md = 4; touched `lib/recall.sh` or embeddings substrate = 5).
- [x] `score_f_orch(fm, body, tags) -> (int, list[str])` follows the same shape, anchored to `policy/value-drivers.yaml` lines 131-141: level 0 (primary-agent serial), level 1 (hand-wired dispatch only), level 2 (single-use routing improvement), level 3 (typed I/O contract / decision gate), level 4 (rubric-scored work routable to TermLink worker), level 5 (expands orchestrator substrate itself). The guardrail in lines 142-146 — "Score CAPABILITY UPLIFT, NOT ease-of-delegating-this-task" — must be enforced as a **refuse-rule**: if the task body matches `wrap.*in.*dispatch|delegate.*this|run via termlink` without also touching dispatch substrate (workflows, resolver, peer, orchestrator namespaces), `score_f_orch` returns 0 with rationale `"f-orch-refuse:wrap-without-substrate"`. This is the F-ORCH-specific anti-Goodhart per R5 of the policy.
- [x] `estimate_task()` (line 395) dispatches free drivers to the new functions: `"F-RECALL": score_f_recall, "F-ORCH": score_f_orch` added to the scorer map alongside D1-D4. Generic `score_free_driver()` is retained as the fallback for any active free driver without a dedicated heuristic (so future free-driver additions don't crash the estimator before this task ships a heuristic for them).
- [x] Rationale strings end up in `bvp_scores_proposed[].rationale` and read informatively — they cite the signal that produced the score (e.g. `F-RECALL=3 (body:fw-recall-mention, body:memory-link)`, not `F-RECALL=1 (body/tag hits for 'F-RECALL': 1)` which is the current placeholder output).
- [x] `tests/unit/test_bvp_estimator.py` gains coverage: at minimum one positive case per rubric level (0/3/5) for F-RECALL, one positive case per level (0/3/5) for F-ORCH, AND the F-ORCH refuse-rule case (body says "delegate this to TermLink" without touching dispatch substrate → returns 0). Tests pin signal-to-score, not implementation.
- [x] Re-running the estimator on existing scored tasks does NOT trigger spurious `bvp_scores_proposed` writes — the v2-delta gate (`_v2_delta_should_skip`) still suppresses re-writes when new heuristic score differs from confirmed `bvp_scores:` by <2 on every driver. (Sanity: stage existing tasks before/after and confirm `git status` shows no spurious AC-bumps on tasks already scored under the old generic.)
- [x] `bin/fw bvp --include-proposed` continues to rank correctly post-extension; spot-check 5 tasks where F-RECALL / F-ORCH heuristics now distinguish what used to all score 0 / 1.

### Human
<!-- All Agent ACs above. No subjective taste call needed — heuristic correctness
     is empirically pinnable via the test cases. Operator may choose to spot-verify
     ranking outputs post-deploy but it's not blocking. -->

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

# T-2168 verification commands:
python3 -m pytest tests/unit/test_bvp_estimator.py -q
python3 -c "import sys; sys.path.insert(0, 'agents/termlink/bvp-estimator'); import estimator; assert callable(estimator.score_f_recall) and callable(estimator.score_f_orch)"
out=$(python3 -c "import sys; sys.path.insert(0, 'agents/termlink/bvp-estimator'); import estimator; print(estimator.score_f_recall({}, '', []))" 2>&1); echo "$out" | grep -q "no recall signal"
out=$(python3 -c "import sys; sys.path.insert(0, 'agents/termlink/bvp-estimator'); import estimator; print(estimator.score_f_orch({}, 'we should delegate this to a worker', []))" 2>&1); echo "$out" | grep -q "f-orch-refuse"
out=$(bin/fw bvp --include-proposed 2>&1); grep -q "^TASK" <<<"$out"

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

### 2026-06-03 — refuse-rule scope: components, not body

- **What changed:** The R5 refuse-rule (anti-Goodhart for "delegate this" busywork) initially treated body-level substrate mentions as sufficient to bypass refusal. The test case `"Suggests we delegate this work to a TermLink worker"` revealed the trap — the body name-drops `TermLink worker` (matching `r"TermLink (worker|dispatch)"`) but produces zero substrate uplift (components is `[docs/notes.md]`).
- **Plan impact:** Refuse-rule narrowed to `substrate_touch` only (components-based signal). Body mentions of substrate-keywords still influence scoring at levels 3-5, but they cannot satisfy the substrate prerequisite for the refuse-rule bypass. Estimator is metadata-driven (components-declared scope) by design — git-diff inspection would defeat pre-completion scoring.
- **Triggered:** Refined wording of the F-ORCH guardrail in the implementation's docstring to make the metadata-vs-content distinction explicit. Test `test_f_orch_refuse_wrap_without_substrate` pins it.

### 2026-06-03 — _components_text helper extracted

- **What changed:** Both F-RECALL and F-ORCH need `components:` content to evaluate substrate touch. Repeating the list-flatten dance twice would invite divergence (one site could grow case-sensitivity, the other not).
- **Plan impact:** Tiny helper `_components_text(fm) -> str` extracted before either scorer. Returns empty string on missing/malformed (defensive — frontmatter can be partial during edits).
- **Triggered:** No new sub-task; deliberate scope choice.

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

**Rationale:** Mechanical extension of the existing D1-D4 heuristic pattern.
Two dedicated free-driver scorers landed, anchored to the rubric text in
`policy/value-drivers.yaml` lines 105-112 (F-RECALL) and 131-141 (F-ORCH).
The R5 anti-Goodhart refuse-rule is enforced via `components:`-based substrate
detection (the metadata-not-body distinction documented in Evolution).
Spot-check across 5 corpus tasks shows the new heuristics distinguish where
the generic placeholder scored everyone 0 or 1 (T-1820 F-RECALL 0→2, T-2169
F-RECALL 1→4 + F-ORCH 1→0, T-1062 F-ORCH 0→1 hand-wired, etc.).

**Evidence:**
- New scorers: `agents/termlink/bvp-estimator/estimator.py` — `score_f_recall`,
  `score_f_orch`, `_components_text` helper. Wired into `estimate_task`
  handlers map alongside D1-D4.
- Tests: `tests/unit/test_bvp_estimator.py` — 10 new test cases. Full suite
  `54 passed in 0.27s`. Pins: empty=0, L3 / L4 / L5 each, refuse-rule case,
  routing via `estimate_task`, generic fallback retained, rationale-not-naive.
- v2-delta gate unchanged — F-RECALL/F-ORCH route through the same
  `_v2_delta_should_skip` and `no-change-since-last` paths as D1-D4. Re-runs
  on existing scored tasks only append when scores actually shifted.
- `bin/fw bvp --include-proposed` continues to render 322 lines with the
  expected TASK / BVP / NORM / COST / QUAD / SOURCE / NAME columns; no crash.
- Corpus spot-check (T-1820, T-2169, T-2189, T-1942, T-1062): four of five
  show meaningful F-RECALL or F-ORCH deltas vs old generic; the fifth
  (T-1942) correctly stays 0 (cron-registry drift has no recall/orch signal).

**What's next:** T-2172 (F-RECALL band 0-2 calibration after ≥10 wakings)
becomes the natural next slice — the dedicated heuristics now produce signal
at every level, so collecting calibration data on whether the L0-L2 boundary
fires too eagerly is real work, not guessing.

## Updates

### 2026-06-01T20:28:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2168-bvp-estimator-extension-for-f-recall--f-.md
- **Context:** Initial task creation

### 2026-06-01T20:31:06Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → later

### 2026-06-03T20:16:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0eb8d770
- **Timestamp:** 2026-06-09T22:45:54Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `agents/termlink/bvp-estimator/estimator.py` gains `score_f_recall(fm, body, tags) -> (int, list[str])` modelled on `score_d1_antifragility()` structure. The function maps real signals to the 0-5 rubr
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/termlink/bvp-estimator/estimator.py in: `agents/termlink/bvp-estimator/estimator.py` gains `score_f_recall(fm, body, tags) -> (int, list[str])` modelled on `score_d1_antifragility()` structu`
- **AC#2 (Agent)** — `score_f_orch(fm, body, tags) -> (int, list[str])` follows the same shape, anchored to `policy/value-drivers.yaml` lines 131-141: level 0 (primary-agent serial), level 1 (hand-wired dispatch only), le
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: `score_f_orch(fm, body, tags) -> (int, list[str])` follows the same shape, anchored to `policy/value-drivers.yaml` lines 131-141: level 0 (primary-age`

### 2026-06-09T22:45:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
