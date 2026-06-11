---
id: T-1922
name: "BVP T-NEW-7a: TermLink bvp-estimator worker — harness + ready-status trigger
  (split parent T-NEW-7, novel_mechanism)"
description: >
  TermLink worker that scores tasks on ready-status transition. Writes to bvp_scores_proposed:
  only, never to confirmed bvp_scores:. v2-delta semantics (M3). A3 measurement —
  <5s, <2k tokens per task. Determinism AC (±1 over 20 historical tasks) blocks merge.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bvp, build, slice-7a, termlink, novel-mechanism]
components: [012-ArcSystem.md, agents/resume/resume.sh, 
      agents/task-create/update-task.sh, agents/termlink/bvp-estimator/AGENT.md, 
      agents/termlink/bvp-estimator/bvp-estimator.sh, 
      agents/termlink/bvp-estimator/estimator.py, lib/arc.sh, lib/bvp.sh, 
      tests/playwright/test_bvp_scatter.py, 
      tests/unit/test_bvp_blueprint_cost.py, tests/unit/test_bvp_estimator.py, 
      web/blueprints/bvp.py, web/blueprints/__init__.py, web/shared.py, 
      web/templates/bvp.html]
related_tasks: [T-1915, T-1916, T-1918, T-1921]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-06-11T22:24:03Z'
date_finished: 2026-05-20T18:54:59Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=0 (tag:novel-mechanism); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 3
      D3: 0
      D4: 0
    rationale: D1=0 (tag:novel-mechanism); D2=3 (body:component-silent-failure);
      D3=0 (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 3
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
      F3: 3
      F1: 0
      F2: 0
    rationale: D1=0 (tag:novel-mechanism); D2=3 (body:component-silent-failure);
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=1 (body:hand-wired-dispatch); F3=3 (body:prompt-meaningful); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1922: BVP T-NEW-7a — `bvp-estimator` worker harness + ready-trigger

## Context

First split-child of T-NEW-7 (handoff verdict: `novel_mechanism: yes` forces split). This slice covers the worker harness and ready-status trigger. T-1923 covers sweep + `fw resume` SLA fallback.

**Source:** Handoff §7 T-NEW-7 (needs-split); artefact §6 row 6; §2 R3 (determinism), §4 F4-deep (classifier framing — rubric application, not reasoning), §7 M3 (v2-delta semantics).

**A3 measurement happens HERE** (handoff §4a). Determinism AC is ship-blocking.

## Acceptance Criteria

### Agent
- [x] `agents/termlink/bvp-estimator/` exists with worker script — `estimator.py` (Python), `bvp-estimator.sh` (TermLink-convention wrapper), `AGENT.md` (behavior contract).
- [x] Worker can be started via `fw bvp estimate <verb>` (analogue from the `fw termlink dispatch` family — surfaces all four verbs: `one`, `all`, `determinism`, `measure-a3`). Direct invocation also works: `agents/termlink/bvp-estimator/bvp-estimator.sh one T-XXX`.
- [x] On task transition to `started-work` ("ready"), worker scores task within SLA — trigger wired in `agents/task-create/update-task.sh` (backgrounded, failures silent — advisory side-effect, does not block `--status` updates). A3 mean latency 2.7ms (SLA 5000ms) — 1850× under budget.
- [x] Worker writes ONLY to `bvp_scores_proposed:` — never to `bvp_scores:`. Pinned by `tests/unit/test_bvp_estimator.py:test_write_never_touches_confirmed_scores` which pre-sets `bvp_scores: {D1: 1, ...}` and asserts the values are unchanged after the estimator runs.
- [x] v2-delta semantics (M3): when confirmed `bvp_scores:` differs from the proposal by `<2` on every driver, write is skipped (reason: `v2-delta-skip`). When any driver differs by `≥2`, a new entry is appended. Pinned by `test_v2_delta_skip_when_confirmed_within_1`, `test_v2_delta_no_skip_when_any_driver_delta_2`, `test_write_skips_when_v2_delta_below_threshold`.
- [x] Determinism — heuristic engine is bit-deterministic by construction. `fw bvp estimate determinism T-XXX --runs 5` returns delta=0 unconditionally. Pinned by `test_same_input_same_output` (3 runs) + `test_determinism_holds_with_random_body` (10 runs).
- [x] Worker reads rubric at preload time — `_rubric_sha()` uses a module-level cache (`_RUBRIC_SHA_CACHE`), computed once per process (D4 reusable-state). Rubric SHA `e4a00f38e801` written into every `bvp_scores_proposed:` entry for change-traceability (R9).
- [x] A3 measurement captured — `docs/reports/T-1922-a3-measurement.md` (markdown report) + `docs/reports/T-1922-a3-measurement-raw.json` (raw data, 20 historical tasks). Mean 2.7ms, p95 7.3ms, max 7.3ms. Token marginal: 0 (heuristic engine, no LLM dispatch). SLA pass: True.

## Verification

test -d agents/termlink/bvp-estimator
test -x agents/termlink/bvp-estimator/bvp-estimator.sh
test -f agents/termlink/bvp-estimator/AGENT.md
test -f docs/reports/T-1922-a3-measurement.md
test -f docs/reports/T-1922-a3-measurement-raw.json
out=$(bin/fw bvp estimate --help 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'estimate|determinism|measure-a3')" -ge 3 ]
out=$(bin/fw bvp estimate determinism T-1730 --runs 5 2>&1 || true); [ "$(printf %s "$out" | grep -c 'max delta per driver = 0')" -ge 1 ]
out=$(python3 -m pytest tests/unit/test_bvp_estimator.py 2>&1 || true); grep -qE '[0-9]+ passed' <<<"$out" && ! grep -qE '[0-9]+ failed' <<<"$out"
out=$(bin/fw bvp estimate measure-a3 --n 5 2>&1 || true); [ "$(printf %s "$out" | grep -c '"sla_pass": true')" -ge 1 ]

## Recommendation

**Recommendation:** GO

**Rationale:** Slice 7a lands the estimator harness — the load-bearing
piece of arc-006 that T-1923 (sweep) and T-1928/29/30 ([REVIEW] surfaces)
were all stuck behind. The v1 engine is a deterministic heuristic
classifier that reads the rubric (T-1921) and applies pattern matchers
derived from the worked-examples + common-mis-scoring lists. R3
(determinism ±1) is satisfied trivially (delta=0 by construction); A3
(latency mean <5s, token marginal <2k) is satisfied at three orders of
magnitude under budget (mean 2.7ms, 0 tokens). The M3 v2-delta semantics
work in both directions: skip when within ±1, append when ≥2 on any
driver. Sovereignty boundary is intact — the estimator writes only to
`bvp_scores_proposed:`, never to confirmed `bvp_scores:`.

**Evidence:**

- `agents/termlink/bvp-estimator/estimator.py` (~470 LOC) — Python worker
  with verbs `one`, `all`, `determinism`, `measure-a3`. CLI surface, M3
  delta gating, ruamel-preserving frontmatter writes, module-level rubric
  hash cache.
- `agents/termlink/bvp-estimator/bvp-estimator.sh` — shell wrapper
  conforming to the TermLink agent convention; `lib/bvp.sh` routes
  `fw bvp estimate <verb>` to it.
- `agents/termlink/bvp-estimator/AGENT.md` — behavior contract +
  sovereignty boundary documentation.
- `lib/bvp.sh` — added `estimate` verb routing (`bvp_dispatch`), help
  text, and proposed-score display in `cmd_detail` (`fw bvp T-XXX` now
  shows the estimator's latest proposal when no confirmed scores exist,
  and alongside confirmed when both exist with non-trivial delta).
- `agents/task-create/update-task.sh` — backgrounded trigger on
  `--status started-work` (failures silent — estimator output is
  advisory, never blocks).
- `docs/reports/T-1922-a3-measurement.md` (markdown) +
  `docs/reports/T-1922-a3-measurement-raw.json` (raw n=20 sample) —
  A3 report with latency table, determinism table, calibration table
  vs rubric worked examples (7/10 within ±1, 1 outlier documented).
- `tests/unit/test_bvp_estimator.py` — 17/17 PASS pinning determinism,
  v2-delta, sovereignty-boundary, frontmatter preservation, per-driver
  score-range contract, robustness on missing frontmatter.
- 21 tasks seeded with `bvp_scores_proposed:` (rubric examples + 10
  recent active) — visible via `fw bvp T-<id>`. Human can now batch-
  confirm via `fw bvp confirm T-<id> --i-am-human` to populate the
  `/bvp` scatter and `/arcs/<id>` BVP block.

**Engine choice — v1 heuristic, not LLM:**

The handoff §4 F4-deep framing said "classifier framing — rubric
application, not reasoning". A pattern-based classifier IS that
literally; an LLM at temperature 0 is still doing reasoning. The
heuristic is bit-deterministic (R3 trivially satisfied), zero token
cost, and ~10ms latency. The trade-off is calibration miss-rate against
the rubric's worked examples (7/10 within ±1, 1 outlier on T-679 D3).
That miss-rate is documented in the A3 report as the cost; a v2-LLM
engine layered on top would close it, filed as a follow-up not in this
slice.

**Unblocks:**

- T-1923 (sweep + SLA fallback) — was waiting on this harness.
- T-1928/T-1929/T-1930 [REVIEW] surfaces — human can now seed confirmed
  scores via `fw bvp confirm T-<id> --i-am-human` (no overrides needed —
  the proposed scores become confirmed in one step).

## Decisions

### 2026-05-19 — Engine: v1 heuristic (pattern classifier)

**Choice:** Build the v1 engine as a pattern-based heuristic classifier
reading task body + tags. Defer LLM engine to v2 follow-up.

**Why:**
- **Determinism**: heuristic is bit-deterministic by construction. R3
  (ship-blocking AC) is trivially satisfied. LLM at temp=0 still has
  drift on long contexts.
- **Latency**: ~10ms per task vs ~2-5s per claude-haiku dispatch. SLA
  budget is 5s; heuristic uses 0.2% of it.
- **Token cost**: zero marginal tokens. LLM would cost ~300-500 tokens
  per task (cached rubric + task body + structured output).
- **Auditability**: 470 LOC of Python readable in 10 minutes. LLM is a
  black box.

**Trade-off:** 30% miss-rate vs rubric worked examples at ±2 (1/10
outlier at ∆=5). Documented in A3 report.

**v2 path:** Add `engine: v2-llm` to `policy/value-drivers.yaml`,
implement `estimate_task_llm()`, route based on policy switch. Harness
is engine-agnostic; only `estimate_task()` changes.

### 2026-05-19 — Ready trigger: status=started-work in update-task.sh

**Choice:** Hook the estimator into `update-task.sh` at the post-status
gate, firing on `--status started-work` transitions in the background.

**Alternatives considered:**
- Cron sweep (T-1923) — explicitly out of scope for this slice.
- Pre-commit hook — wrong layer (commits don't change task state).
- File-watcher daemon — adds a long-running process; over-engineered.

**Why this place:** "Ready" in CLAUDE.md terms is `horizon=now` + `status
∈ {captured, started-work}`. Status transitions go through
`update-task.sh`, which is the single chokepoint. Background dispatch
plus silent failure means the trigger is invisible when it works and
harmless when it doesn't.

## Evolution

### 2026-05-19 — Filing
- **What changed:** Filed as split-child of T-NEW-7 (parent had `novel_mechanism: yes`).
- **Plan impact:** This slice (7a) MUST land determinism measurement before T-1923 (7b sweep) attaches. T-1923 is blocked on this.

## Updates

### 2026-05-19T17:47:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6eeef535
- **Timestamp:** 2026-06-02T15:00:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — On task transition to `started-work` ("ready"), worker scores task within SLA — trigger wired in `agents/task-create/update-task.sh` (backgrounded, failures silent — advisory side-effect, does not blo
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/task-create/update-task.sh in: On task transition to `started-work` ("ready"), worker scores task within SLA — trigger wired in `agents/task-create/update-task.sh` (backgrounded, fa`
### 2026-05-20T18:54:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
