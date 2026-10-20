<!-- backend: codex; 2026-10-20; review of T-4470 bundle, isolated: outside repo, tools off (codex exec -s read-only --ephemeral, shell tool sandboxed read-only in empty dir, not disabled; log shows no command_execution, only agent_message) -->

1. **Friction falls, but “without weakening any gate” is false for this implementation.**

The fixed command, visible queue and ordered selection reduce handoff friction. Per-step confirmation adds useful control. However, the claimed enforcement has critical holes:

- **Jobs are executable shell, not data.** Removing PATH does not prevent builtins, redirections, command substitutions or absolute executable paths. A top-level `printf x > /tmp/marker` executes during the probe without triggering rejection. The probe itself can therefore cause effects before consent.
- **Jobs can redefine safeguards.** A job containing `confirm() { return 0; }` passes the definitions-only probe and replaces the launcher’s confirmation function when sourced. It can also replace `run_checks`, `fail` or other launcher functions. `preflight()` and `steps()` execute unrestricted code while registering commands.
- **“Dry run” executes arbitrary checks.** Checks can perform writes or Tier 0 actions under the agent’s identity. “Nothing was run” is inaccurate.
- **Terminal input is not an authorization boundary.** The test override permits scripted answers whenever `RUNME_JOBS_DIR` differs from the canonical directory, while steps still run in `$PROJ`. A different queue can therefore execute production actions with file-fed answers.

A queued Tier 0 decision is legitimate only if the existing authoritative gate still independently enforces the required operator decision. Neither selecting a batch nor answering generic `y` establishes that. The bundle does not include enough of those gates to certify their preservation; the launcher demonstrably cannot guarantee its own consent boundary.

**SHA binding is narrower than claimed.** It detects ordinary edits to `job.sh` between rehearsal and execution. It does not bind external scripts, executable versions, repository state, environment or expanded arguments. Dry-run output shows step titles, not command bodies or helper implementations. The dry run hashes *after* loading/checking; execution hashes *before* loading. Concurrent replacement can therefore make the hashed file differ from the loaded file. Read-only permissions are reversible, and `dryrun.ok` is writable evidence, not authenticated approval.

Use an immutable execution snapshot and a manifest covering relevant dependencies; display the resolved plan. Explicitly separate rehearsal evidence from approval.

2. **Port selectively, in this order: item 5 with item 1, then item 3, item 4 at rollout; adapt item 2 last.**

| Item | Recommendation and cost against existing AEF |
|---|---|
| **5 — Tests** | Bring over useful behavioral cases first, adding regression tests for the failures above. Moderate effort. Current tests exercise friendly shell jobs and file-fed answers; they do not establish the advertised boundary. |
| **1 — Launcher/queue** | Highest-value adoption: fixed entry point, listing, states, retirement, rehearsal checks and per-step consent. Highest engineering cost: replace shell-sourced metadata with parsed data; isolate executable payloads from launcher state; preserve existing logging and exit semantics; add locking and migration compatibility. Start with typed selection; add picker/batches after correctness. |
| **3 — Signals/identity** | Adapt to AEF’s existing events and signal handling rather than adding a competing protocol. Moderate integration cost. Missing-key/no-create behavior is useful; TermLink should remain optional. |
| **4 — Rules** | Update alongside the working implementation. Small documentation cost, meaningful workflow cost: migration, immutable handoff and explicit separation of consent from Tier 0 approval. A rule cannot repair an executable bypass. |
| **2 — Watcher** | Do not replace AEF’s watcher wholesale. Extend existing per-job/run monitoring with durable cursors and optional topic transport. Moderate-to-high reliability cost; little novelty in armer tracking or WATCH LOST. |

The proposal’s comparison understates AEF: section D already has structured events, signal-specific STOPPED handling, armer records and WATCH LOST, plus T-4464’s start/exit selection.

3. **Principal operational risks**

**Execution and quoting.** `eval` deliberately executes shell syntax; quoting metadata does not make it data. Prefer validated argument arrays for simple actions and separately reviewed, hashed scripts for complex ones. Escape terminal control characters in job titles and event text.

There is also a direct failure-handling regression: the launcher uses `set -uo pipefail`, omitting AEF’s `-e`. A step such as `false; touch marker` returns success if the final command succeeds, permitting later steps and `done`. Simply adding `-e` is insufficient because conditional/function contexts can suppress it. Define and test explicit failure semantics in an isolated execution process.

**Typeahead.** Draining improves normal interaction but is a timing mitigation, not proof of fresh consent. There is a gap between the final drain and reading the answer; continuous input can prolong draining. Existing tests bypass `/dev/tty`, so they do not test the safety claim. Add pseudo-terminal tests for queued and partial input, prompt transitions, EOF and interruption.

**Batch stop/retry.** Stop-on-failure is useful but not transactional. Earlier effects remain; retrying an incomplete job starts again at step one. Require clear partial-completion reporting and explicit retry guidance. The upfront check validates rehearsal hashes, not live preconditions for every job. `run_one` does not recheck `done` or `retired`; there is no lock preventing concurrent execution. Add locking, execution-time eligibility checks and unique log names: timestamps alone collide within a second. Failure to write `done` can also be masked by subsequent successful output.

**Signals/watchers.** In batch subshells, `$$` still identifies the parent shell; `kill -INT $$` does not reliably terminate the current job shell as intended. Tests exercise standalone signal helpers, not this integration.

The watcher can lose completion events between exiting and rearming because each new instance baselines at the current end. File truncation/rotation is unhandled. Its topic cursor never advances during polling, so 50 foreign messages can hide later relevant events indefinitely. Its root follows cwd/git, unlike the signal writer.

Preserve T-4464’s explicit start/exit contract. Wake-ups should prompt observation, never imply authorization or permit agent mutation while operator work remains active. T-4435’s actual policy is absent, so compatibility cannot be certified.

4. **Items 6–8**

- **6, parallelism: later.** `JOB_PARALLEL_SAFE=1` is self-assertion, not enforcement of read-only behavior or isolation.
- **7, resume: later.** Persist the ordered remainder and fingerprints; revalidate eligibility and retain confirmations. Never silently replay a partially completed job or assume its dependants can proceed.
- **8, batch events: worth designing now**, within AEF’s existing schema. Include batch/run IDs and terminal outcomes. Implement when batches land; preserve detailed events while allowing watchers to select batch completion.

5. **Overall: adapt, not adopt unchanged.**

Approve the queue concept and fixed-command interface. Defer production replacement until consent isolation, failure propagation, snapshot binding, concurrency and watcher delivery are addressed. Fifty-six jobs demonstrate practical utility, not gate preservation.