<!-- backend: opencode; 2026-10-20; review of T-4470 bundle, isolated: outside repo, tools off (opencode zai-coding-plan/glm-5.3 (glm-5.2 no longer served; substituted), all tools false/denied; log has no tool events) -->

# Review of T-4470 (runme job queue)

## 1. Friction vs. gates

Friction is genuinely reduced (one command, menu, ordered batches), and **no gate is weaker than AEF today**. AEF's current path is a generated script that runs through with no rehearsal and no per-step consent; the queue strictly adds gates: sha-bound rehearsal, live preflight re-run, y/N per step from `/dev/tty` with typeahead drained, and `RUNME_TTY` refused on the real jobs dir.

**Can a queued job carry Tier 0 or an approval past the operator? No.** Every step executes only after `confirm` reads y from the terminal; `run_one` preserves per-step y/N inside batches, so batching cannot automate consent. Nothing auto-records on completion — the GO job's step *is* the operator recording their own decision, and `JOB_WHY` invites refusal. Approval authority stays at the keyboard.

**Does the sha bind what runs to what was shown? Only partially.** The full 64-char sha compare binds `job.sh`'s bytes to the last rehearsal, and the plan is regenerated from those same bytes at run time. But:

- **What the operator consents to is the displayed plan, and the display is not the whole execution.** Preflight commands are eval'd live *before the first y/N* (`run_checks` runs after `show_plan`, before the step loop) and the operator sees check *titles*, never check commands — an assumed-observer check could mutate state unseen. Helper functions are likewise opaque: a step may display `runs: run_upgrade` with the body invisible. Fix: print check commands, and expand or ban helpers.
- **The rehearsal gate is agent-operated.** The agent runs `--dry-run`, can `chmod` back (advisory), edit, and re-rehearse; `dryrun.ok` is two forgeable lines. The live preflight is the real operator-visible gate; the sha detects file drift, not agent misbehavior. The operator's tell is the "rehearsed \<timestamp\>" line — the rule should say a rehearsal later than hand-over means stop.
- **The definitions-only probe is a tripwire, not a guarantee.** Sourcing with `PATH=/nonexistent` catches external commands, but builtins run fine: `echo x > /tmp/f` or `source /existing/path` produce no "command not found" and pass (writes to *existing* paths only, but that's enough).
- **Batch consent fatigue:** 3 jobs × N steps multiplies single-keystroke y's; muscle memory is the realistic failure mode, and typeahead discard narrows the 2026-10-02 incident to a sub-100 ms race, not zero.

## 2. Port order and cost (§10 items 1–5)

1. **Items 1 + 5 together, first** (launcher, job format, both test suites). The tests are the review; landing ~370 lines of safety-critical bash without them reproduces the exact failure mode the redesign cites. Cost: `runme_new`'s codegen shrinks to a scaffolder; must resolve the **directory collision** (AEF `.context/runme/<name>/runme.sh` vs 832 `.context/runme/<NNN>-<name>/job.sh`, same parent); bare `fw runme` becomes the operator menu.
2. **Item 3 second, adapted not imported.** AEF already has `events.jsonl` (T-3741) and STOPPED traps; fold in 832's lessons (events path from script location, project-signed topic posts, fail-closed key handling) rather than running two event formats in parallel.
3. **Item 2 third.** Keep AEF's `watch.json`/WATCH LOST (T-3878) and `--until` (T-4464); add the topic channel with the project-label filter and merge the armer record.
4. **Item 4 last.** Cheap, but only truthful once the launcher exists; preserve AEF's Tier 0 wording.

Nothing functional is lost; the real cost is owning ~600 lines of bash as framework safety infrastructure plus migrating in-flight legacy jobs.

## 3. Risks

- **Jobs as data / injection:** within the threat model (agent authors the job), eval of `STEP_C` is equivalent to today's generated script; no operator input reaches eval (typed selection is regex-validated `^[0-9]+(,[0-9]+)*$`; the picker reads raw keys). Practical risks are authoring (nested quoting in `check`/`step` strings) and the builtin hole above.
- **Typeahead discard:** sound design (drain before each read, only on a real tty); residual race is the drain window itself. Acceptable — document it.
- **Batch stop/resume:** coherent. Stop-at-first-failure, "the rest not started," done-jobs-never-offered means re-picking `x` can't re-run completed jobs. Refusing the whole batch up front when any job is CHANGED/not-rehearsed (with a STOPPED event) closes the half-executed-batch hole. No change needed; item 7 is convenience only.
- **Watcher:** complements T-4464 — waking on the first event subsumes `--until start`, at the cost of one wake per step event (noisy for batches; see item 8). It depends on the same session-liveness assumption as the T-4435 notice discussion: background-task exit must re-invoke the agent and WATCH LOST must surface at session start (AEF already has the latter). One concrete concern: `topic_next` bootstraps the cursor by walking `--limit 1000` windows to max offset — on a long-lived, busy topic that can loop or misplace the cursor.

## 4. Items 6–8

**All explicitly later.** 6 (parallel): `JOB_PARALLEL_SAFE` is honor-system — bash has no sandbox and "no writes outside the job dir" is unenforceable; prompt interleaving is unsolved. Keep it out. 7 (resume): marginal; the pending list already shows the remainder. 8 (batch events): the one defensible early pull-in (per-step wakes × multi-job batches), but only ride it with item 2 if batch usage is real.

## 5. Overall

**Adopt 1 and 5; adapt 2–4; defer 6–8** — conditioned on: (a) displayed consent equals executed reality (show check commands and helper bodies, or ban hiding execution in helpers); (b) the rule states plainly that rehearsal is agent-run and the live preflight is the operator's gate; (c) the job-dir collision is resolved before any port. The operator's framing survives testing: Tier 0 and approvals remain on the operator's keyboard, and relative to `fw runme` today every existing gate is preserved while several are added. The one claim that does **not** quite hold is "bound by sha to what will actually run": the sha binds `job.sh`'s bytes to the agent's last rehearsal — nothing more, and the environment the steps execute in (launcher, `fw` binary, repo state) is bound by nothing except the live preflight.