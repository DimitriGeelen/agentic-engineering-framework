# T-4470 — Adopt 832's runme job queue into fw runme?

**Phase:** inception. **Decision owner:** the operator.

## 1. The proposal (832-Workflow-designer, msg ff397b49, 2026-10-20)

Proposed by 832 at their operator's request. It has run 56 jobs in 832 since 2026-10-05.

- **One fixed operator command.**
- **Jobs are data, not safety code.**
- **A required dry run, bound by sha** to what will actually run.
- **y/N per step**, read from the terminal, with typeahead discarded.
- **A menu showing each job's state.**
- **Batches in the operator's order:**
  - chosen with an arrow-key picker, or typed (`3,1,2`, or `x` for all);
  - refused up front if any job is not ready;
  - stopped at the first failure.
- **A signal library** (an events file plus a TermLink topic, written from traps) and **a background watcher** whose
  exit wakes the agent.

**Their write-up:** 832 `docs/reports/runme-job-queue-for-aef.md` at 7c1bea00.

- §9 compares it with AEF's fw runme (T-3675).
- §10 is the proposal: items 1-5 to port; items 6-8 are ideas they have not built (parallel runs for opt-in
  prompt-free jobs, resuming a stopped batch, batch-level events).

**Their code:**

- `runme.sh` and `tools/runme-{launcher,signal,watch,new}.sh`;
- tests: `tests/test_t1055_runme_launcher.py` (26 legs) and `tests/test_t1003_runme_signal.sh` (11).

## 2. What AEF has today

- **`fw runme new`** (T-3675) writes one logged script per operator action and hands over one line: `set -euo
  pipefail`, every command echoed, output timestamped into `run.log`, RUNME START/EXIT markers.
- **`fw runme watch`** follows a run to its exit; `--until start|exit` was added today (T-4464).
- **No queue:** there are no batches, no per-step confirmation, no dry run bound to a sha, and no menu of pending
  jobs. Each handoff is a separate line the operator pastes.

## 3. Operator's view (2026-10-20)

The operator considers it an excellent idea, and frames its value precisely. It is **not** a path around Tier 0 or
approvals: those stay exactly where they are. It makes the operator-run path less friction-heavy. One fixed command
replaces a stream of pasted lines; the operator sees and orders the pending jobs; and each step is confirmed with the
dry run in view.

## 4. Questions for the external reviewers (to be sent with the write-up)

1. Does the design reduce operator friction **without** weakening any gate? In particular:
   - can a queued job carry a Tier 0 action, or an approval, past the operator?
   - does the sha-bound dry run actually bind what runs to what was shown?
2. Which of §10 items 1-5 should AEF port, in what order, and what does each cost against fw runme as it is?
3. Risks:
   - jobs as data (injection, quoting);
   - typeahead discard;
   - batch stop and resume semantics;
   - the watcher waking the agent (overlap with T-4464 and with the T-4435 notice discussion).
4. Is anything in items 6-8 worth doing now, or is it explicitly later?
5. Overall: adopt (which parts), adapt, or not.

## 5. Reviews

Three seats, as for T-4435. All are internal backends, run with the bundle only, from a directory outside the repo
with tools disabled (the T-4435 lesson; T-4437):

- codex (OpenAI)
- opencode (Z.ai)
- claude (Anthropic)

Status: waiting for 832 to send the write-up and code. They cannot be read across the project boundary, and 832's
push is blocked until AEF T-4469 lands.

## Dialogue Log

- **2026-10-20.** 832 proposed it. The agent filed inception T-4470 with recommendation DEFER: an evidence gap,
  because the write-up was unreadable from here.
- **Operator:** "I think it's actually an excellent idea, so get some external consultation … it's not a path to get
  Tier 0 interaction and to get approval … this makes it less frictionless." → reviews are to be run; the operator's
  framing is recorded in §3 and is reviewer question 1.
