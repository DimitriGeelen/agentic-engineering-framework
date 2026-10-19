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

Pending.

## Dialogue log

- 2026-10-19, operator: "Just as we refactor our main codebase, would it make sense to refactor our testing set too?"
  Agent: yes, as its own refactor that starts with measurement, citing the day's evidence (above).
- 2026-10-19, operator (Dutch, paraphrased): get an external review and a data basis; lay it out, ask how we can
  optimise it, and put it in its own arc with an arc headline, arc drivers and build tasks.
