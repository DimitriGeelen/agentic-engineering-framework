---
id: T-3243
name: "claude-fw supervisor dies on healthy runs: lifetime restart cap, off-by-one,
  and clean-exit teardown"
description: >
  The arc-012 continuous loop fires correctly — 7 autonomous budget restarts over
  five
  days — then dies three different ways, none of them a failure of the restart mechanism:
  a lifetime restart cap that kills healthy hours-apart runs, an off-by-one that makes
  MAX_RESTARTS=5 permit 4, and a clean claude exit that tears down the supervisor.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, arc-012, supervisor]
components: [bin/claude-fw]
related_tasks: [T-3239, T-3240, T-3166, T-3182, T-3206]
arc_id: continuous-run
created: 2026-09-01T10:03:09Z
last_update: '2026-09-01T10:15:17Z'
date_finished:
cost_estimate_proposed:
  - ts: '2026-09-01T10:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (single-component); tier=2 (workflow:build); 
      effort=8 (lines=159,acs=11)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-01T10:15:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      Discard fidelity: 0
      Loop closure (conditional): 0
      D1: 2
      D2: 2
      D3: 0
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=2 (body:learning-ref); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3243: claude-fw supervisor dies on healthy runs

## Context

The arc-012 continuous loop **fires correctly** — `.context/working/continuous-run.jsonl`
records 7 autonomous budget restarts across five days with no operator relay. It then
**dies**, three different ways, all of which look to the operator like "the loop is not
working". T-3239 measured the mechanism ends (brakes, trigger, resume injection); this
task fixes the supervisor that wraps them.

Measured from the loop's own log (13 events, 2026-08-29 → 2026-08-31):

```
ts                    event    reason           rc  exit_code   gap
2026-08-29T15:43:41Z  iterate  restart           1        n/a
2026-08-29T22:27:05Z  exit     no-signal         1          0   +6:43:24   <- D3
2026-08-29T22:27:10Z  start    armed             0        n/a
2026-08-29T23:21:53Z  iterate  restart           1        n/a
2026-08-30T08:22:49Z  exit     no-signal         1          0   +9:00:56   <- D3
2026-08-30T08:22:51Z  start    armed             0        n/a
2026-08-30T11:08:31Z  iterate  restart           1        n/a
2026-08-30T19:09:27Z  iterate  restart           2        n/a   +8:00:56
2026-08-30T19:11:26Z  iterate  restart           3        n/a   +0:01:59   <- the ONLY spin
2026-08-31T16:00:52Z  iterate  restart           4        n/a  +20:49:26
2026-08-31T16:04:35Z  exit     max-restarts      5          0   <- D1 + D2
2026-08-31T17:28:13Z  start    armed             0        n/a
2026-08-31T19:45:15Z  iterate  restart           1        n/a
```

Three wrapper deaths, three distinct defects, zero of them a failure of the restart
mechanism itself.

## Acceptance Criteria

### Agent

- [x] **D1 — the restart budget is a sliding window, not a lifetime count.** Restarts
  older than `FW_RESTART_WINDOW` (default 3600s) stop counting against `MAX_RESTARTS`.
  Verified by a bats case that drives `MAX_RESTARTS + 2` restarts spaced beyond the
  window and asserts the supervisor never emits `exit max-restarts`.

- [x] **D1 control leg — a genuine spin is still caught.** A bats case drives
  `MAX_RESTARTS + 1` restarts *inside* the window and asserts the supervisor DOES emit
  `exit max-restarts`. Without this leg, "the cap no longer fires" cannot be told apart
  from "the cap never fires".

- [x] **D2 — off-by-one fixed: `MAX_RESTARTS=N` permits exactly N restarts.** A bats case
  asserts the Nth restart is performed (`iterate restart` with `restart_count=N` present
  in the log) and the N+1th is refused. Today N=5 permits 4.

- [x] **D4 — `MAX_RESTARTS` is actually read from config.** It has been in
  `FW_CONFIG_REGISTRY` since before this task while `bin/claude-fw` hardcoded `5`, so
  `fw config set MAX_RESTARTS 20` wrote `.framework.yaml` and changed nothing. A bats
  case asserts a different configured value produces a different number of restarts.

- [x] **D3 — a clean claude exit with no restart signal re-arms when the run is armed.**
  When `.context/working/.continuous-mode.yaml` has `enabled: true`, an `exit_code=0` exit
  with no signal relaunches instead of terminating, recorded as `iterate rearm`.

- [x] **D3 control leg — a DISARMED run still exits on clean exit.** With
  `enabled: false` (or the file absent) the supervisor exits exactly as it does today,
  recording `exit no-signal`. This is the operator's ability to quit; it must not regress.

- [x] **Sovereignty: the halt file breaks the re-arm loop.** With continuous mode armed,
  the presence of the halt file causes the next clean exit to terminate with `exit halted`
  rather than re-arm. Asserted by bats.

- [x] **The re-arm cannot hot-spin.** Re-arms consume the same sliding-window budget as
  budget restarts, so a claude that exits immediately and repeatedly is capped by
  `MAX_RESTARTS` within the window rather than looping unbounded. Asserted by bats.

- [x] **`RESTART_WINDOW` is registered in `FW_CONFIG_REGISTRY`** and resolved by the
  wrapper's own 3-tier `_fw_cfg` reader (env → `.framework.yaml` → default).
  Note: `fw config get <KEY>` returns rc=1 for any key not explicitly set in
  `.framework.yaml` — including long-standing keys like `PORT` and `CONTEXT_WINDOW` —
  so it does **not** implement the documented tier-4 registry fallback. That is
  pre-existing behaviour, out of scope here, and filed separately; this AC therefore
  asserts the registry entry and the wrapper's reader, not `fw config get`.

- [x] **The suite is shown to bite.** Run against the pre-fix `bin/claude-fw` from HEAD
  via `FW_TEST_WRAPPER`, 8 of 11 cases go red; the 3 that stay green are exactly the
  control legs asserting unchanged behaviour (disarmed exit, absent state file,
  `--no-restart`). A suite that has never failed is not evidence that it can.

- [x] **`bash -n bin/claude-fw` parses** and the config library still parses, so the
  launch path every consumer project depends on is not broken by this change.

## Verification

bash -n bin/claude-fw
bash -n lib/config.sh
timeout 600 bats tests/unit/t3243_supervisor_restart_policy.bats > /tmp/.t3243-verify 2>&1 && ! grep -q "^not ok" /tmp/.t3243-verify
test "$(grep -c '# skip' /tmp/.t3243-verify)" -eq 0
bash -c 'source lib/config.sh; printf "%s\n" "${FW_CONFIG_REGISTRY[@]}"' > /tmp/.t3243-cfg 2>&1 && grep -q '^RESTART_WINDOW|3600|' /tmp/.t3243-cfg
timeout 300 bats tests/lint/config-registry-parity.bats > /tmp/.t3243-parity 2>&1 && ! grep -q "^not ok" /tmp/.t3243-parity

## RCA

**Symptom.** The operator runs everything under `claude-fw` and reports the continuous
loop "still not working". Measured: the loop performs 7 autonomous restarts over five
days and then stops, requiring a manual relaunch. From outside, a supervisor that quietly
exited and one that never worked are indistinguishable — both present as a dead terminal.

**Root cause — three, independently sufficient:**

- **D1: `MAX_RESTARTS` counts for the lifetime of the wrapper, never decaying.**
  `restart_count` only increments (`bin/claude-fw:355`). Wrapper 3 performed 4 restarts
  across **28h52m** — one per seven hours — and was terminated as a runaway. The cap's
  stated purpose is *"Safety valve — don't loop forever"*, which is a statement about
  **rate**; it is implemented as a statement about **total**. The only pathological
  interval in the entire corpus is the 1m59s between rc=2 and rc=3, and that is precisely
  the one a lifetime cap is worst at catching, because it costs the same one unit as a
  20-hour-apart restart.

- **D2: the guard increments before it tests.** `restart_count=$((restart_count + 1))`
  then `if [ "$restart_count" -ge "$MAX_RESTARTS" ]`. With `MAX_RESTARTS=5` the fifth
  increment trips the guard, so **four** restarts occur while the message and the log
  both say `MAX_RESTARTS=5` was reached. The configured number is not the number that
  happens, and the log states the configured one — so the record actively misleads
  anyone auditing it.

- **D3: any clean claude exit tears down the supervisor.** The `else` branch at
  `bin/claude-fw:452` exits whenever no restart signal is present. Its comment reasons
  that *"the operator quit"* and *"the loop broke"* are the two readings and the record
  separates them — true for the record, but the **behaviour** is identical for both, and
  it is the behaviour that ends the run. Two of the three deaths in the log are this
  branch, at 6h43m and 9h01m after a healthy restart, with `exit_code=0`.

**Why structurally allowed.** No test drives `bin/claude-fw`'s loop. All three defects
live in the branch arithmetic of a `while true` that no suite enters, so the only
instrument that ever measured them is the JSONL log T-3182/T-3206 added — and that log
was built to answer *"why did it stop?"*, a question whose answers (`max-restarts`,
`no-signal`) both read as **correct, intended terminations**. The log reported the
defects faithfully for three days in language that made them look like features. This is
L-555 in the supervisor: a brake that fires as designed and a brake that fires wrongly
emit the same shape of event.

**Prevention.** `tests/unit/t3243_supervisor_restart_policy.bats` drives the real loop
with a stub `claude` on PATH, so the branch arithmetic is executed rather than read. Each
fix ships with its control leg — the spin case for D1, the disarmed case for D3 — because
a cap that no longer fires and a cap that cannot fire are the same observation without
one.

## Evolution

### 2026-09-01 — the loop was never the broken part

- **What changed:** I opened this believing the continuous loop did not fire, and said so
  to the operator. That was wrong, and the operator was right to reject it. The loop's own
  log had 7 autonomous restarts in it the whole time. The defect was never in the
  mechanism arc-012 built; it was in the 20-line supervisor block wrapped around it, which
  no test had ever entered.
- **Plan impact:** T-3239 concluded "the substrate is sound, the headline mechanic is not
  demonstrated". Half of that stands and half inverts: the substrate *is* sound, and the
  headline mechanic was firing in production for five days while the demo task said it
  wasn't. What T-3239 could not see is that its two "NOT PROVEN" links were unproven only
  in the sandbox — `continuous-run.jsonl` is wire evidence for the handover→restart leg
  that the harnesses never exercised.
- **Triggered:** this task (T-3243); the observation that `fw config get` does not
  implement tier-4 registry fallback, deliberately left out of scope.

### 2026-09-01 — a fourth defect the first three were hiding

- **What changed:** `MAX_RESTARTS` has been a registered config key in
  `FW_CONFIG_REGISTRY` the entire time, and `bin/claude-fw` hardcoded `5` and never
  sourced config at all. So the documented remedy for the symptom — `fw config set
  MAX_RESTARTS 20` — wrote `.framework.yaml`, reported success, and changed nothing.
  Found only because the D1-control test set `FW_MAX_RESTARTS=3` and got 4 restarts.
- **Plan impact:** added D4 as its own AC rather than folding it into D1. It is a
  different failure — D1 is a wrong-shaped limit, D4 is a limit that was never connected —
  and folding them would have lost the second one in the commit message of the first.
- **Triggered:** `_fw_cfg`, a dependency-free 3-tier reader, because the wrapper is
  vendored into consumers as `.agentic-framework/bin/claude-fw` and must not require
  `lib/config.sh` to be present on disk.

### 2026-09-01 — a bug I wrote, caught before it shipped

- **What changed:** my first version computed the budget as `spent=$(_restart_budget_spent)`,
  which runs the whole body in a command-substitution **subshell** — so the pruned array
  was discarded every call and `restart_times` would grow for the wrapper's entire life.
  The returned *count* stays correct, because the prune is recomputed from scratch each
  time, which is exactly why no test would ever have caught it.
- **Plan impact:** converted to a global (`RESTART_SPENT`) set by `_restart_budget_prune`.
  Recorded here rather than silently fixed, because it is the same class as the defects
  this task exists to fix: correct output, wrong internal state, no instrument pointed
  at the difference.
- **Triggered:** nothing further; the comment at `bin/claude-fw` explains why the function
  sets a global instead of echoing, so the next author does not "tidy" it back.

## Recommendation

<!-- filled if this reaches partial-complete -->

## Decisions

## Updates

### 2026-09-01T10:03:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Context:** Initial task creation
