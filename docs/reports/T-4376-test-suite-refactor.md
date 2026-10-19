# T-4376 — Test-suite refactor (arc-026 test-suite-health)

Inception, anchor of arc `test-suite-health` (arc-026). The go/no-go is the operator's.

## Problem

The unit suite costs about as much as the code it guards. The cost shows up at the push gate. On 2026-10-19 one
`bleeding-edge` push needed two extra full suite runs (about 55 min each) and an operator baseline step:

- 1,172–1,175 test files; 5–8 of them hit the per-file timeout in every run, so their results are "not determined".
- Reds that appear only under parallel load: t3636, t2290, hook_telemetry_race (5355 µs against 5000), audit.bats
  (the audit hit its own 600 s budget, exit 124).
- Tests anchored to live repo state: audit.bats ran the real audit and turned one red into a self-sustaining
  ratchet loop (T-4372); the t4347 key-0 test read this project's `.framework.yaml`.
- Fixture leaks: auto-init reliance (T-4313), the suite stopping the real sidecar (T-4315), fw driven without a
  temp project (T-2746).
- Tests left behind by deliberate behaviour changes: lib_firewall vs T-4330 (T-4366).
- The baseline holds 44 entries, each with an expiry someone has to chase.

## Arc

- **Headline mechanic:** an agent pushes a framework change. The pre-push gate runs only the hermetic fast tier and
  returns a determined verdict in under 10 minutes, with no file timing out. The operator reads one line in the push
  output and never has to baseline a load-only red to unblock a release.
- **Drivers** (reviewer-approved, weight 3 each):
  - `verdict-determinacy`: the test verdict is a function of the code under test.
  - `fault-detection-fidelity`: a refactored or pruned test still fails on its origin bug.
- **Build tasks** (horizon next, after GO):

  | Task | Scope |
  |---|---|
  | T-4377 | tier split |
  | T-4378 | shared hermetic fixture helper |
  | T-4379 | lint for the recurring defect classes |
  | T-4380 | evidence-driven prune and merge |
  | T-4375 | structure audit near its time budget |
  | T-4325 | load-only reds |

## Plan

1. **Measurement (IW-1):** `docs/reports/T-4376-test-suite-measurement.md`, from existing suite reports only.
2. **External review (IW-3):** two other vendors, codex (OpenAI) and opencode (Z.ai). Both are internal backends,
   cost logged, given the measurement and asked how to optimise. Their answers and where they disagree go
   below.
3. **Synthesis:** answer IW-2 (can a fast tier fit 10 min and still catch what the gate is for) and IW-4 (proof of no
   coverage loss), then a recommendation.

## External review

Two independent reviewers from other vendors read the measurement and the plan, read-only on the committed
revision. Costs are logged (internal, unmetered). Verbatim: `docs/reports/T-4376-reviews/codex.md` (OpenAI) and
`docs/reports/T-4376-reviews/opencode.md` (Z.ai).

### Where both agree

- **Tier split by measured duration, not by the hermeticity label.** The regex hermeticity scan is the gate on
  membership, not the selector. Budget for real headroom: 3,600 file-seconds is exactly 10 minutes with perfect
  packing. Aim for about 7–8 minutes, or about 2,400 file-seconds, at first.
- **A timeout is incomplete execution, never a verdict.** The gate needs its own low per-file cap. opencode suggests
  about 120 s against today's 900 s.
- **Pruning (T-4380) must not rest on red history.** No red list is joined to a code revision, so "rarely red"
  cannot separate a flake from a bug that was caught and fixed. Every merge or prune needs a reproduced origin
  defect: a seeded bug, a historical revision or a control leg. There is no baseline today for how often the suite
  catches a seeded defect, so IW-4 has no instrument yet.
- **The heavy doctor and audit tests should become focused checks** plus a few real end-to-end wiring tests.
  `doctor_designer_pin_drift.bats` has a median of 900 s, and a single `fw doctor` taking more than 15 minutes is
  itself a product performance defect.
- **The baseline is a cliff:** 32 of 44 entries expire on 2026-10-31. 22 tests are red in 20 of 20 reports, and an
  always-red test can catch nothing.

### Where they disagree

- **The four "bimodal" files** (audit.bats, fw_doctor_vendored_drift.bats, t2332_bvp_propose_queue.bats,
  fabric_coverage_single_source.bats):
  - opencode calls a 2 s ↔ 900 s swing a hang, most likely audit-lock serialisation between concurrent test files.
  - codex warns that the quick runs may be SKIPS (audit.bats skips on lock exit 75) or older code, so they may be
    less coverage, not health. It wants the history split by revision first.
  - Resolution: both are cheap to test. Run each file ten times alone and ten times in the suite, with per-command
    timings and lock snapshots, before calling anything a deadlock.

### New findings from the reviews (not in the measurement)

1. **The runner's own accounting is not trustworthy enough to tune against** (codex):
   - pytest exit 5 (nothing collected) is accepted.
   - Discovery is `test_*.py` only; `t2974_greenfield_operator_prose.py` is never run.
   - `LAST-COMPLETE.yaml` can include runs with per-file timeouts.
   - 81 runs collapse into 42 daily reports with no revision identity.
2. **`t2332_bvp_propose_queue.bats`** hard-codes the repo path, queries the live Watchtower and calls `curl -sf`
   without a timeout. That is a concrete isolation defect and a plausible source of the unbounded wait (codex).
3. **`audit.bats` contract gaps**, one introduced today (codex):
   - My T-4372 change made "audit exits 0 for all-pass sections" accept exit 2, so it no longer tests its name.
   - "audit --quiet suppresses terminal output" asserts no suppression at all.
   - The real fix is synthetic audit reports in a private root, not a looser exit-code rule.
4. **`t4248_install_init_failure.bats` took 0 s on the base tree** (opencode): a file that normally takes minutes
   finished instantly. That is the "cannot fail" class the arc's second driver exists for. Investigate it before
   trusting any of its passes.
5. **`tests/test_helper.bash` isolation is opt-in** (codex):
   - It does not set PROJECT_ROOT or cwd.
   - Its default teardown does not call `tripwire_assert`, and file-local setup and teardown replace the defaults.
   - `guard_project_root` accepts any `/tmp/*` path.
6. **Wall-clock budget assertions** (hook_telemetry_race 5 ms, hook_telemetry 1000 fires, t1719 latency) are red
   under load by construction. Move them to a serial perf leg, or assert operation counts (opencode).

### Effect on the plan

The order changes. **Make the runner's verdicts trustworthy first, then split, then prune.**

| Step | Work | Tasks |
|---|---|---|
| 0 | Runner accounting and completeness | T-4381 |
| 0 | Triage the four bimodal files and the instant-finish files | T-4382 |
| 0 | Fix the audit.bats contract | T-4383 |
| 0 | t2332 isolation | T-4384 |
| 0 | Defuse the 2026-10-31 baseline cliff | T-4385 |
| 1 | Tier split: duration-selected, own low per-file cap, wall-clock asserts moved to a perf leg | T-4377 |
| 1 | Hermetic helper with mandatory lifecycle | T-4378 |
| 1 | Lint as a membership gate | T-4379 |
| 2 | A seeded-defect detection baseline, then evidence-driven pruning | T-4380 |
| — | fw doctor taking more than 15 minutes, filed as a product defect | T-4386 |

## Dialogue log

- 2026-10-19, operator: "Just as we refactor our main codebase, would it make sense to refactor our testing set too?"
  Agent: yes, as its own refactor that starts with measurement, citing the day's evidence (above).
- 2026-10-19, operator (Dutch, paraphrased): get an external review and a data basis; lay it out, ask how we can
  optimise it, and put it in its own arc with an arc headline, arc drivers and build tasks.
