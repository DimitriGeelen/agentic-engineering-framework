<!-- backend: claude; 2026-10-20; review of T-4470 bundle, isolated: outside repo, tools off (claude -p --tools '' --strict-mcp-config --setting-sources '', 0 tool_use events) -->

# Review: T-4470, porting 832's runme job queue into fw runme

**Verdict: adapt.** The friction gains are real. The claim that this happens "without weakening any gate" does not hold for the code as written. The sha and dry-run machinery protects against accidental drift, such as the T-1052 incident where a second agent copy rewrote the script. It does not protect the one property the design says it exists for, that **the operator consents to what actually runs**. One defect in particular must be fixed before anything is ported.

## 1. Friction vs gates

**Can a queued job carry a Tier 0 action or an approval past the operator? Yes, as written.**

- **The job can replace the launcher's safety functions.** `load_job` sources `job.sh` into the launcher's own shell. A job may define functions, and nothing stops it defining `confirm() { return 0; }`, `ask`, `fail`, `run_checks` or `say`. Any of these silently replaces the launcher's version. Every "y/N per step" then auto-passes. The sha binding does not help, because the agent rehearsed that exact file.
  - This contradicts "safety lives once, in a tested launcher". The job shares the launcher's namespace.
- **The load-time probe catches accidents only.** `PATH=/nonexistent` stops external commands, but not builtins:
  - `exec 3<file` re-points the answers descriptor at a file;
  - `printf y > /abs/path` and `: > /abs/file` write or truncate files;
  - `source /abs/other.sh` pulls in other code;
  - `[ "$PATH" = /nonexistent ] || …` evades the probe outright.
  
  The probe also *executes* the file once with those builtins live.
- **The operator does not have the dry run "in view".** They see an agent-written title, an agent-written WHY, and `runs: <string>`.
  - When the step is `run_upgrade`, the helper's body is never shown.
  - When the step uses `$RATIONALE`, the value being recorded is not shown either.
  - The dry-run output was seen by the agent, not the operator.
  - This is *less* visibility than a pasted line, which showed everything.
- **The displayed text is not sanitised.** `JOB_TITLE`, `JOB_WHY` and step strings are printed raw. ANSI escapes such as `\033[1A\033[2K` can erase the `runs:` line on screen.

**Does the sha bind what runs to what was shown? Only partly.**

- The sha covers `job.sh` only. It does not cover:
  - helpers living outside that file;
  - the scripts the steps call (`fw`, repo tools);
  - `runme-signal.sh`, which is sourced;
  - the launcher itself.
- **There is a race between hashing and loading.** The hash is computed, then `load_job` sources the file again later.
- **Read-only is advisory.** The agent owns the file, and the launcher itself runs `chmod u+w "$d"`.
- **The agent can bless any file.** `dryrun.ok` is a plain file the agent can write. More simply, `--dry-run` with no name re-rehearses *every* pending job, so agent copy A can bless copy B's edit. That is the T-1052 incident again.

**Accurate framing:** the sha binds "what runs" to "what the agent last rehearsed". It does not bind it to "what the operator saw". It is also not a gate against the agent. A gate against the agent can only live in fw's Tier 0 enforcement, and the launcher neither adds to nor removes that.

The operator's claim survives only if these are fixed:

1. Run each step in a **child process** that sources the job. Prompts and the answers descriptor stay in a parent the job cannot touch.
2. Refuse jobs that define reserved names. Extract definitions via `declare -f` in a sandboxed subshell, and refuse any top-level command, redirection or `exec`.
3. Hash a **private copy** and source that copy. Also record the launcher's sha in `dryrun.ok`.
4. Show helper bodies (`declare -f helper`) and expanded variable values at the confirm prompt. Strip control characters from everything displayed.
5. Make `--dry-run` require a name.

**Habituation is the remaining risk.** A batch with `x` across several Tier 0 decisions is a long run of `y` presses. For steps tagged Tier 0, require a typed token, such as the task id, instead of `y`, or exclude them from batches.

## 2. What to port from §10 items 1-5, and in what order

AEF already has much of items 2 and 3:

- `events.jsonl` with `_ev`;
- `watch.json` recording who armed a watch;
- WATCH LOST reporting via `fw runme pending`;
- STOPPED traps, including SIGPIPE handling the 832 code lacks;
- `--until start` (T-4464).

Recommended order:

1. **Item 1 (launcher), with the fixes above, together with item 5 (tests).** Add tests for the defects: confirm override, `exec 3<`, PATH-detecting evasion, escape-sequence titles.
   - **Cost: high.** About 370 lines rewritten against AEF's layout.
   - **Signature clash:** the existing `fw runme new <name> -- cmds` and per-name dirs (`run.log` vs `run-<ts>.log`) need a compatibility path.
   - **Root resolution:** AEF resolves the project via `PROJECT_ROOT`/`pwd`, while 832 uses an absolute path. "One command from any directory" needs a project-local stub.
2. **Item 4 (CLAUDE.md rule).** Cheap, but only after item 1. Rewriting the rule around an unfixed launcher would codify the hole.
3. **Items 2 and 3 as a mapping, not a port.** Emit 832-style events into AEF's existing `events.jsonl` and extend `fw runme watch`.
   - Keep the TermLink topic optional.
   - Do not import the global-file cursor (see §3).

## 3. Risks

**Jobs as data.** They are not data.

- `check` and `step` are `eval`'d shell strings, and helpers are arbitrary functions.
- Preflight commands run with side effects at dry-run time.
- Quoting itself is sound: `"$RATIONALE"` inside the eval string expands once and is not re-evaluated.
- The real exposure is the namespace sharing and the display gaps above.
- "Data" should mean an allowlisted declaration format, or the claim should be dropped.

**Typeahead discard.** The mechanism is sound: a 50 ms drain on fd 3 before each prompt, and an empty Enter defaults to N.

- The residual risk is human rhythm in batches, not buffered keys.
- The drain is skipped whenever `TTY` is not `/dev/tty`. That is acceptable only because of the `RUNME_TTY` refusal.
- That refusal does not stop the agent pointing `RUNME_JOBS_DIR` at a copy and answering from a file. This is harmless only because the agent could run the commands directly anyway, which confirms the launcher is not a gate.

**Batch stop and resume.**

- **Re-running a stopped job repeats completed steps.** No per-step progress is recorded, so a job that stopped at step 3 starts again from step 1. Most upgrade and commit steps are not idempotent. Either record per-step completion, or require each preflight to detect partial completion.
- **The up-front refusal checks only sha and rehearsal state.** Job N+1's preflight depends on job N's effects, so mid-batch preflight failures are still likely.
- **"N" counts as failure.** Declining a step stops the whole batch. That is acceptable but should be documented.

**Watcher waking the agent.**

- **Events can be lost.** `runme-watch.sh` takes its baseline line count `f0` when armed. Events written between one wake and the re-arm are never reported. A batch emits started/step/done per job, so many wakes are certain. A persisted cursor is needed.
- **The watcher resolves its root differently from the signal library.** It uses `git rev-parse` on the caller's cwd, while `runme-signal.sh` uses its own location. This is the same bug they fixed on the signal side.
- **It duplicates `fw runme watch --until start|exit` (T-4464).** Pick one wake model. Per-event wakes also bear directly on the T-4435 notice-volume discussion, which is a reason to do item 8.

## 4. Items 6-8

- **8 (batch-level events): do it with the port.** It is cheap and cuts wake noise.
- **7 (resume): later.** It depends on fixing per-step resume first. Otherwise "resume" re-runs half-finished jobs.
- **6 (parallel runs): explicitly later.** `JOB_PARALLEL_SAFE=1` would be agent-declared, so it is a self-certified exemption from prompts. It needs enforcement (a sandbox, or a write-scope check), not a flag.

## 5. Overall

**Adapt, do not adopt as is.**

**Take:**
- the fixed command and the menu with job states;
- the dry-run requirement;
- the per-step confirm with typeahead drain;
- the retired/done lifecycle;
- the ordered batch with up-front refusal;
- the test discipline.

**Reject or rework before landing:**
- sourcing jobs into the launcher's shell;
- the PATH-only probe;
- the job-only sha;
- unnamed `--dry-run`;
- undisplayed helper bodies and variable values;
- raw terminal output;
- the global-cursor watcher.

**Keep 832's code out of AEF:** the TermLink identity export and topic are project-specific and should stay optional.

**Tell the operator:** with these fixes, friction drops and no gate is weakened. Without them, the "one command I always run" becomes the most trusted path on the system and the easiest to subvert. That is the exact failure §1 of the write-up describes.