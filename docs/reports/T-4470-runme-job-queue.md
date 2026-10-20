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
- **2026-10-20.** Three isolated reviews in. All dispute "without weakening any gate" for the code as written, while
  agreeing the friction reduction is real. Recommendation: GO, adapt, with prerequisites (§7).

## 6. Review synthesis (2026-10-20)

Three isolated seats (outside the repo, tools off): codex, opencode and claude. Verbatim: `docs/reports/T-4470-reviews/`.

- codex ran in a read-only sandbox in an empty directory rather than with its shell tool disabled.
- opencode's glm-5.2 is no longer served, so glm-5.3 was used.
- claude logged 0 tool-use events.

| Seat | Verdict | Headline |
|---|---|---|
| codex | **adapt** | Friction falls, but "without weakening any gate" is false for this implementation |
| claude | **adapt, do not adopt as is** | "Can a queued job carry a Tier 0 action or an approval past the operator? Yes, as written." |
| opencode | adopt 1 and 5, adapt 2-4, defer 6-8 | No gate is weaker than AEF *today*: the current fw runme has no rehearsal and no per-step consent at all |

**Where codex and claude converge independently:**

1. **Jobs are shell loaded into the launcher, not data.** The launcher loads `job.sh` into its own shell. A job can
   define `confirm() { return 0; }` (or `ask`, `fail`, `run_checks`) and silently replace the launcher's safeguards,
   which defeats per-step consent.
2. **The load-time probe catches accidents only.** An empty PATH stops external commands, not shell builtins: a
   redirect writing a file, re-pointing the answers descriptor, loading another file, or testing PATH to evade the
   probe all slip through. The probe also executes the file once.
3. **The "dry run" runs arbitrary checks** under the agent's identity, so "nothing was run" is not accurate.
4. **The operator does not have the plan in view.** They see an agent-written title and WHY, not the helper body or
   the resolved arguments.
5. **The sha binds `job.sh` only.** It does not cover helpers, external scripts, tool versions, environment or
   expanded arguments.
6. **The scripted-answer override for tests** applies whenever the jobs dir is not the canonical one, while steps
   still run in the project.

**opencode's counterpoint holds:** relative to today the queue only *adds* gates. The operator's claim is right
in that relative sense and wrong in the absolute sense for this code.

**Take** (all three): the fixed command; the menu with job states; the dry-run requirement; the per-step confirm with
typeahead drain; the retired/done lifecycle; ordered batches with up-front refusal; the test discipline.

## 7. Recommendation

**GO: adapt, not port.** These prerequisites land before or with the first slice:

1. **Jobs run out-of-process.** Never loaded into the launcher's shell. The launcher's confirm, ask, fail and check
   functions must be unreachable from job code: the job runs in a child process that only receives the step list
   from a declarative manifest.
2. **What the operator confirms is what runs.** The dry run shows each step's resolved command, including helper
   bodies and expanded arguments, not a title.
3. **A sha manifest** covers `job.sh` plus every helper and script it calls, checked again immediately before each
   step.
4. **No scripted-answer path outside tests.** The override is keyed to an explicit test flag and refused when steps
   would run in a real project.
5. **The queue is never an authorisation.** Tier 0 actions and approvals stay enforced by their own gates; a "y" in
   the queue does not satisfy them.
6. **Port order:**
   - slice 1: the fixed command, menu and lifecycle, on out-of-process jobs (prerequisites 1, 2, 4, 5);
   - slice 2: the sha manifest (prerequisite 3) and per-step confirm;
   - slice 3: ordered batches with up-front refusal.
   - Items 6-8 are deferred.

Findings against 832's own code (1-6 above) go back to 832 as one item each; they offered to fix on their side.
