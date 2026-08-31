# arc-012 ultrareview — W1 loop-core

**Scope:** `agents/context/checkpoint.sh`, `agents/context/stop-driver.sh`, `bin/claude-fw`, `lib/continuous-mode.sh`
**Branch:** `arc012-ultrareview` (full post-change files read, not just the diff)
**Cross-read for tracing (not reported on):** `agents/context/inject-next-directive.py`, `agents/context/post-compact-resume.sh`, `agents/task-create/update-task.sh`, `bin/fw` (doctor ledger block), `.claude/settings.json`, `tests/unit/{stop_driver,continuous_task_counter,t3212_human_gate_stop,t3225_continuous_arm}.bats`

---

### F1. The T-3212 termination readback replays a frozen `now` under a fresh timestamp — the exact false green it was written to remove, reproduced live in this repo

- **Severity:** critical
- **Confidence:** confirmed (traced, and reproduced against live repo state)
- **Location:** `agents/context/stop-driver.sh:144`
- **Failure scenario:** `inject-next-directive.py:275-278` composes `last_terminated_reason` as a *sentence containing its own `now`*: `"expires_at 2026-06-17T00:00:00Z passed (now 2026-08-26T12:50:35Z)"`. That string is frozen into `.continuous-mode.yaml` and never rewritten while the loop stays disarmed (the injector returns early at `evaluate()`'s `if not enabled` guard, so nothing refreshes it). `stop-driver.sh:142-144` reads that string back verbatim and `log()` prefixes it with `date -u` — today. The current `.context/working/.stop-driver.log` therefore contains 18 consecutive lines of the form:

  ```
  2026-08-31T11:02:59Z decision=stop reason=terminated(expires_at 2026-06-17T00:00:00Z passed (now 2026-08-26T12:50:35Z))
  ```

  Two different clocks in one line, one of them 5 days stale and still counting. A reader diagnosing "why won't the loop run today" is handed a timestamped record whose embedded `now` is a replay — precisely the T-3202 / 74-day class the driver's own header cites. The state file additionally carries `terminated_at`, which the driver never reads or prints, so the one field that *could* disambiguate a stored reason from a live one is discarded.
- **Why it survives review:** T-3212's intent is correct and its test (`t3212_human_gate_stop.bats:145`) asserts only that the recorded reason *reaches* the log. The sibling `fw continuous status` does label the same string (`(stored last_terminated_reason, NOT re-evaluated: …)`) and `t3225_continuous_arm.bats:138` pins that labelling — so the labelling discipline exists, is tested, and simply was not applied to the second consumer. The log line looks fixed because it now names a cause instead of a flag.
- **Suggested fix:** emit the stored reason with an explicit stored-marker and its own `terminated_at`, e.g. `reason=terminated[stored@2026-08-26T12:50:35Z](human-gate:human-ac:T-3199)`, and strip or refuse to echo any `(now …)` substring the reason carries. Same treatment `status` already gives it.

---

### F2. `fw continuous arm --tier-ceiling N` sets a ceiling the enforcer does not use, and then prints the number it just failed to make effective

- **Severity:** high
- **Confidence:** confirmed
- **Location:** `lib/continuous-mode.sh:340-342` (write), `lib/continuous-mode.sh:309` and `:356` (print)
- **Failure scenario:** `arm` writes the ceiling to **state only** (`state["tier_ceiling"] = ceiling`) and never to `.next-directive.yaml`. The enforcer, `inject-next-directive.py:261`, resolves it **directive-first**: `directive_data.get("tier_ceiling", new_state.get("tier_ceiling"))`. This repo's `.next-directive.yaml` carries `tier_ceiling: 1` today. So `bin/fw continuous arm --hours 4 --iterations 3 --tier-ceiling 5` prints `Ceiling: tier 5`, `fw continuous status` prints `Tier ceiling: 5`, and the bounded-autonomy check enforces **1** — freezing the loop on the first task with blast-radius 2. The inverse is equally reachable: a directive with `tier_ceiling: 6` silently widens a `--tier-ceiling 1` arm.

  A second, quieter leg of the same defect: on a project with no `tier_ceiling` anywhere, `arm` prints `Ceiling: tier -` and `status` prints `Tier ceiling: -`, but `CONFIG_DEFAULTS["tier_ceiling"] = 1` (`inject-next-directive.py:70`) means the effective ceiling is **1**, the tightest possible. The operator is shown "no ceiling" and gets the strictest one.
- **Why it survives review:** `fw_continuous_cli`'s `verdict()` *does* implement directive-first precedence — correctly — for `max_iterations`, `max_tasks` and `expires_at` (`:275`, `:279`, `:282`). Reading it, the precedence discipline looks uniformly applied. `tier_ceiling` is the one field printed straight from `state.get(...)` with no precedence chain, and it sits three lines below two that have one. The file header even names this precedence trap explicitly, for expiry.
- **Suggested fix:** write `directive["tier_ceiling"] = ceiling` alongside the state write when `--tier-ceiling` is given (and delete a stale directive key when it is not), and resolve the printed value through the same directive-first chain `verdict()` uses.

---

### F3. The bound `arm` prints — "Bound: N iteration(s)" — cannot tick inside a Stop-hook-driven run, and on a fresh project cannot tick at all

- **Severity:** high
- **Confidence:** confirmed
- **Location:** `lib/continuous-mode.sh:345-355`
- **Failure scenario:** `current_iteration` has exactly one writer: `inject-next-directive.py`, reached only from `post-compact-resume.sh`, wired only to `SessionStart` (`.claude/settings.json` matchers `compact|resume|startup`). The Stop hook drives turns *inside* one session, where no SessionStart fires. So for a run driven by `stop-driver.sh`, `current_iteration` is frozen for the entire session and `max_iterations` never binds — the driver evaluates `cur + 1 > max_iter` with `cur` permanently 0.

  The second leg is worse and survives restarts. `arm` writes `filed_at`, `expires_at`, `max_iterations`, `filed_by` — and `directive` **only if `--directive TEXT` was passed** (`:348-349`). `inject-next-directive.py:232-234` returns `(state, "")` when `directive` is not a non-empty string, and `main()` at `:470-471` returns before `write_state()`. So on a project whose `.next-directive.yaml` has no `directive:` key — which is exactly what `bin/fw continuous arm --hours 4 --iterations 3` produces on a fresh checkout — the injector writes nothing, forever. Concretely: arm prints `Bound: 3 iteration(s)`, the loop budget-restarts four times, `current_iteration` stays `0`, `max_iterations: 3` never fires, and each restarted session also receives **no directive** (no `FW_NEXT_DIRECTIVE`, no `## Next Directive` block) — it restarts without advancing and without marching orders.
- **Why it survives review:** `t3225_continuous_arm.bats:45` and `:51` arm without `--directive` and assert `ARMED` / `iteration-1` from the *driver*, which reads `current_iteration` but never advances it — so the test is green precisely because the counter is inert. No test in the set exercises arm → SessionStart → counter-advanced end to end. And the arm output is phrased in the operator's units ("Bound: 3 iteration(s)"), which reads as a commitment.
- **Suggested fix:** have `arm` refuse (or loudly warn) when the resulting `.next-directive.yaml` would have no `directive:` string, since the injector is a no-op without one; and state in the arm output which ceiling actually binds a Stop-hook-driven run (expiry and `max_tasks`), rather than leading with the session counter that only advances across restarts.

---

### F4. `arm` resets `tasks_completed` but neither sets `max_tasks` nor clears `completed_task_ids` — a run can end on a task ceiling the operator never set, or silently fail to count work against one they did

- **Severity:** high
- **Confidence:** confirmed
- **Location:** `lib/continuous-mode.sh:334-343`
- **Failure scenario:** `arm` sets `enabled`, `current_iteration=0`, `max_iterations`, `last_terminated_reason=None`, `last_resumed_at`, `tasks_completed=0`, optionally `tier_ceiling`. It has **no `--max-tasks` flag at all** and never touches `max_tasks` in either file.

  *Ceiling never set, still enforced:* a `.next-directive.yaml` or `.continuous-mode.yaml` left carrying `max_tasks: 2` from a prior run survives the arm. The operator runs `fw continuous arm --hours 8 --iterations 5`, is told `Bound: 5 iteration(s), expires …`, and the run halts after the second task with `max_tasks-reached(2>=2)` — a ceiling that appears nowhere in the arm output or in `status`.

  *Ceiling set, under-counted:* `tasks_completed` is reset to 0 while `completed_task_ids` is not (nothing anywhere in the codebase clears it). `fw_continuous_note_task_completed:68` short-circuits on `task_id in seen`. So any task completed in a previous armed run and re-completed in this one — a reopened task, or a partial-complete returning through `work-completed` after the operator ticks its Human ACs — is not counted. `len(completed_task_ids)` and `tasks_completed` diverge permanently after the first re-arm, and anyone reading the id list as this run's audit trail gets prior runs' ids.
- **Why it survives review:** the idempotency guard is genuinely correct and well tested in isolation (`continuous_task_counter.bats:51`); the defect is only visible across an arm boundary, which no test crosses. And `arm` resetting `tasks_completed` reads as "the task counter has been handled".
- **Suggested fix:** add `--max-tasks N` and write it to both files (clearing a stale value when the flag is absent); clear `completed_task_ids` in the same write that zeroes `tasks_completed`; print the resolved `max_tasks` in the arm/status output next to the iteration bound.

---

### F5. The budget self-trigger — the first link in the headline mechanic — never fires when the token scan returns nothing, and the fallback that runs instead looks like coverage but writes no restart signal

- **Severity:** high
- **Confidence:** confirmed (code path traced; frequency plausible)
- **Location:** `agents/context/checkpoint.sh:300-316`
- **Failure scenario:** `warn_by_tokens()` is the **only** writer of `.restart-requested`, and it is reached only when `get_context_tokens` returns a value `> 0`. If the scan yields empty or 0 — a `lib/context_tokens.py` exception, a truncated final JSONL line (Claude Code appends live, so a mid-write read is ordinary), or a usage shape the model-scoping filter does not recognise — `have_tokens` stays `false` and control goes to `warn_by_calls()`, which at `CALL_CRITICAL=80` prints `CRITICAL: 80 tool calls since last commit (no token data)` to stderr and **returns**. No handover. No `.restart-requested`. No terminator kill. In an unattended run there is no operator to read stderr, so the session runs past the configured cap until the real model limit ends it, and the last thing on disk is a stderr line nobody saw.
- **Why it survives review:** `warn_by_calls` is a complete-looking three-level ladder with its own CRITICAL rung, positioned as "Fallback: tool-call warnings". It answers the adjacent question — *should the agent stop?* — while the primary path answers *should the supervisor restart?*, and only one of the two paths can actually cause the restart. A degraded gauge and a healthy one both produce a session that keeps running.
- **Suggested fix:** either fire the same auto-handover + restart-signal block from `warn_by_calls` at CRITICAL, or record a distinct `gauge-blind` event (to `.compact-log` / `continuous-run.jsonl`) so a run that ends without a token reading is distinguishable from one that ended under budget.

---

### F6. A failed auto-handover writes no restart signal *and* burns the 10-minute cooldown, and the loop's own ledger then records the death as "the operator quit"

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `agents/context/checkpoint.sh:155`, consequence at `bin/claude-fw:452`
- **Failure scenario:** `date +%s > "$handover_cooldown"` runs at `:155`, **before** the `if timeout … handover.sh --commit` attempt at `:175`. `.restart-requested` is written only inside the success branch (`:205-207`). So a transient failure — a push that exceeds `FW_HANDOVER_TOTAL_TIMEOUT` (default 60s) on a slow network, an auth prompt, a diverged remote — produces: no restart signal, and a cooldown that suppresses every retry for `HANDOVER_COOLDOWN` (default 600s). For those ten minutes the unattended session runs above critical with the self-trigger structurally disabled. When claude eventually exits, `claude-fw` finds no signal and records `exit no-signal "claude exited without a restart signal"` — the same record an ordinary operator quit produces. `fw doctor` reads that ledger and reports the ordinary case.
- **Why it survives review:** the failure *is* recorded — T-2507 added the `.compact-log` FAILED line and the durable stderr capture, and that fix is correct and visible right there in the else-branch. What is not recorded is the consequence for the *loop*, and the cooldown-before-attempt ordering reads as ordinary re-entrancy hygiene rather than as a retry suppressor.
- **Suggested fix:** write the cooldown only on success (or use a shorter failure-specific backoff), and on failure record a `handover-failed` reason the wrapper can surface so `exit no-signal` cannot absorb it.

---

### F7. Only one of the three human gates the driver's own continuation prose names actually stops the loop; Tier-0 and inception/arc decisions route straight past it

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `agents/context/stop-driver.sh:219-221` (the prose) vs. the single call site of `fw_continuous_note_human_gate`
- **Failure scenario:** the continuation reason injected into every driven turn instructs the agent to "Stop and surface to the operator if you reach a Tier-0 action, a human-owned decision, or an unchecked [REVIEW] acceptance criterion". Exactly one of those three is structural: `update-task.sh:2112` calls `fw_continuous_note_human_gate "$TASK_ID" "human-ac"` on the partial-complete branch. There is no call from `check-tier0.sh`, from `lib/inception.sh`, or from the arc-close path (verified by grep across `.sh`/`.py`/`bin/fw`, excluding tests and the vendored mirror). Concretely: an armed run reaches a Tier-0 command, `check-tier0.sh` blocks it with exit 2, the agent reads the block, `.continuous-mode.yaml` is untouched, the Stop hook fires at end of turn, finds `enabled: true` and under cap, and returns `decision: block` — the run continues past the gate, exactly the "park and take the next task" behaviour `fw_continuous_note_human_gate`'s header says it exists to prevent. Later it ends on the 4-hour expiry, with the real blocker nowhere in `last_terminated_reason`.
- **Why it survives review:** `t3212_human_gate_stop.bats:97` is named *"the gate class is carried through, so Tier-0 slots in unchanged"* and passes — it exercises the `gate_class` **parameter** with a synthetic value. Nothing calls it with `tier-0`. The test reads as Tier-0 coverage and is coverage of the parameter's plumbing only.
- **Suggested fix:** call `fw_continuous_note_human_gate "$TASK_ID" "tier-0"` from the Tier-0 denial path and `"inception-decision"` from the agent-refusal branch of `do_inception_decide`; or narrow the driver's prose to the one gate that is actually enforced, so the instruction does not over-claim.

---

### F8. `arm`'s two-file write is atomic per file but not as a pair, and runs in the order that makes the intermediate state the bad one

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `lib/continuous-mode.sh:343` and `:351`
- **Failure scenario:** `save(sp, state)` (sets `enabled: true`) completes at `:343`; `save(dp, directive)` (sets the fresh `expires_at`) runs at `:351`. Between them the process can die — SIGINT from the operator, ENOSPC on the second `mkstemp`, an EROFS `.context/working`, an OOM kill. The result is `.continuous-mode.yaml: enabled: true` sitting next to a `.next-directive.yaml` whose `expires_at` is still the stale one, which `stop-driver.sh:188` reads **first**. The loop is armed and stops dead on the next turn with `expired-at(2026-06-17T00:00:00Z)` — verbatim the 74-day state the file header says "Both legs are set together here, or not at all." No output is emitted in that window either, since the confirmation `print`s come after both saves, so the operator sees a killed command and an armed flag and no reason to suspect the directive.

  Reversing the order makes the intermediate state harmless: fresh expiry + still-disarmed is a no-op, and the operator simply re-runs.

  Concurrency has the same shape with no locking at all — two `arm` invocations (an operator and a cron/wrapper path) can interleave `state`-from-A with `directive`-from-B.
- **Why it survives review:** `save()` genuinely is atomic — `mkstemp` + `os.replace`, the L-493 pattern, and better than the fixed-name temp used elsewhere in the same file. The header's claim "Both legs are set together here, or not at all" is true of *intent* and of the happy path, and per-file atomicity reads as satisfying it.
- **Suggested fix:** write the directive (expiry) first and the state (`enabled: true`) last, so the only reachable intermediate state is "not yet armed, fresh expiry"; note the ordering rationale inline so it is not re-sorted.

---

### F9. `.continuous-mode.yaml.tmp` is a fixed path shared by three unsynchronised writers — a concurrent write can corrupt the state or silently undo a human-gate disarm

- **Severity:** medium
- **Confidence:** confirmed (shared path), plausible (the interleaving)
- **Location:** `lib/continuous-mode.sh:80-85` and `:156-161`
- **Failure scenario:** three processes do full read-modify-write on `.continuous-mode.yaml`: `fw_continuous_note_task_completed`, `fw_continuous_note_human_gate` (both `tmp = state_path + ".tmp"`), and `inject-next-directive.py:194` (`path.with_name(path.name + ".tmp")`) — **the same literal path**, with no lock and no unique suffix. Two overlapping writers open the same temp file; the shorter dump leaves the longer one's tail behind, and whichever `os.replace` lands last installs a file that is neither. The next `yaml.safe_load` raises, `load()` returns `{}`, and the loop reports `state-unreadable-or-empty` — a stop whose reason names the symptom and cannot name the cause.

  The lost-update direction is more damaging than the corruption. `inject-next-directive.py` reads state at process start and writes at `:473`, after globbing `.tasks/` for blast-radius resolution. If `fw_continuous_note_human_gate` disarms inside that window (a background `fw task update --status work-completed` on a dispatched worker's task, hitting the partial-complete branch), the injector's write restores `enabled: True` from its stale read and sets `last_terminated_reason = ""` (`:304`) — **re-arming the loop and erasing the gate reason in one write**. The loop then routes past the human gate with no record that a gate ever fired.
- **Why it survives review:** every individual writer uses the correct `write to temp → os.replace` idiom, and each is atomic *against a crash*, which is what the L-493 comment at `inject-next-directive.py:189` claims and delivers. Atomic-against-crash and safe-under-concurrency are different properties, and the shared temp name is only visible when you read two files side by side.
- **Suggested fix:** give every writer a unique temp (`tempfile.mkstemp(dir=…)`, as `fw_continuous_cli.save()` already does) and take an `flock` on the state file across the read-modify-write in all three writers.

---

### F10. `claude-fw` records `iterate restart` *before* the cancel window, so an operator Ctrl+C is written to the ledger as a restart that happened — the invariant the code comment three lines below claims to hold

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `bin/claude-fw:376`
- **Failure scenario:** the ordering in the restart branch is: `rm -f "$signal_file"` (`:394`) → `_record_loop_event iterate restart` (`:376`, already executed) → `sleep 3` cancel window (`:411`) → sentinel write (`:414`). Pressing Ctrl+C at the prompt that invites it kills `sleep` and, under `set -e`, exits the wrapper. The sentinel is correctly absent (T-3168's fix holds), but `continuous-run.jsonl` now ends on `{"event":"iterate","reason":"restart",…}` and no exit event, because the wrapper died in a `sleep`. `fw doctor` reads exactly that last line (`bin/fw:2413-2431`) and prints `OK Continuous-run wrapper last recorded ARMED (iterate, restarts=N, …)` followed by `WARN wrapper pid N is GONE with no exit record — killed, not stopped`. A deliberate operator cancel is reported as an unexplained kill of a live loop. The comment at `:407-413` asserts the opposite: *"On disk, a cancelled restart is now indistinguishable from a restart that never fired."* It is distinguishable, and distinguished wrongly.
- **Why it survives review:** the T-3168 fix is real and correct for the sentinel, and the comment describing it is directly above the affected code — so the invariant reads as established. The `iterate` record sits 35 lines earlier, inside the display block, where it looks like part of the "announce the restart" cluster rather than part of the durable record.
- **Suggested fix:** move the `iterate` record to after `sleep 3`, adjacent to the sentinel write, so both durable artefacts of a restart are written at the same moment the restart actually becomes irrevocable.

---

### F11. `status`'s "ALSO blocking (each would stop the loop on its own)" enumerates two of five possible blockers while reading as an exhaustive list

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `lib/continuous-mode.sh:298-307`
- **Failure scenario:** `verdict()` checks five conditions in order — halt file, unreadable state, `enabled`, `max_iterations`, `max_tasks`, expiry — but `blockers` is built from only two of them (`enabled`, directive `expires_at`). Concretely: `current_iteration: 5`, `max_iterations: 5`, `enabled: true`, halt file present. `status` prints `Reason (live): halt-file present at …` and prints **no** ALSO-blocking section at all (`len(blockers)` is 0). The operator removes the halt file, re-runs, and is told `max_iterations reached (6 > 5)`. They reset the counter, re-run, and hit the expiry. Three round-trips against a header that promised to list everything that would stop the loop on its own. The same shape hides `max_tasks` (see F4), which is the ceiling most likely to be set without the operator knowing.
- **Why it survives review:** `t3225_continuous_arm.bats:121` ("status names BOTH blockers when both are live") passes, and the two blockers it covers are the two from the 74-day origin incident — so the feature is tested against the case that motivated it and looks complete. The `len(blockers) > 1` guard also means the section vanishes in the single-blocker case rather than showing an obviously short list.
- **Suggested fix:** have `verdict()` return the full list of failing predicates rather than short-circuiting, and print all of them (including halt, `max_iterations`, `max_tasks`) whenever more than zero are live.

---

### F12. `fw continuous status` exits 4 when pyyaml is missing, and every caller reads any non-zero exit as "not armed" — a cause inferred from an evaluation failure

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `lib/continuous-mode.sh:224-227`
- **Failure scenario:** on a host without pyyaml, `fw_continuous_cli status` prints one line to **stderr** and exits 4. `bin/fw:2444` calls it as `if _crl_live=$(fw_continuous_cli status 2>/dev/null); then` — stderr discarded, non-zero taken as the else-branch — and doctor prints `WARN ...but the TURN DRIVER is not armed — the loop takes no turns` followed by an empty reason line (the `sed -n 's/^  Reason (live): /…/p'` finds nothing in empty stdout) and the advice `Arm it: bin/fw continuous arm …`. Arming will also fail, for the same reason, which doctor also will not say. This is the T-3209 shape: a definite cause asserted from a failure to look. It also inverts the risk — a state file that says `enabled: true` is reported as "not armed" on a host that cannot read it.
- **Why it survives review:** the distinct exit code 4 *is* the right instinct and reads as careful — the defect is that no consumer distinguishes it from 1, so the care has no effect. And `verdict()`'s separate `state-unreadable-or-empty` string shows the author was already thinking about this class.
- **Suggested fix:** print the pyyaml failure to stdout in the same `Reason (live):` shape so the message survives a stderr-discarding caller, and have `bin/fw doctor` branch on exit 4 as "cannot evaluate" rather than "not armed".

---

### F13. `disarm` on an unreadable state file reports success and overwrites the file with two keys, destroying `tier_ceiling`, `max_tasks` and `completed_task_ids`

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `lib/continuous-mode.sh:315-321`
- **Failure scenario:** `load()` (`:234-240`) returns `{}` on *any* exception, including a YAML parse error from a truncated write (see F9). `disarm` then does `state["enabled"] = False; state["last_terminated_reason"] = …; save(sp, state)` on that empty dict, replacing a state file that held `tier_ceiling`, `max_iterations`, `expires_after_seconds`, `max_tasks`, `tasks_completed` and `completed_task_ids` with a two-key file — and prints `Continuous mode: DISARMED` plus the reason, indistinguishable from a clean disarm. A subsequent `arm` sets only its own keys, so `tier_ceiling` is now absent and silently falls back to `CONFIG_DEFAULTS`' value of 1 (F2's second leg), with nothing in any output saying the operator's configured ceiling was discarded.
- **Why it survives review:** disarming is the fail-safe direction, so writing `enabled: False` unconditionally is correct and reads as deliberately defensive. The collateral loss is in what `load()` returning `{}` *silently discards*, which is invisible at the `disarm` call site.
- **Suggested fix:** distinguish "file absent" from "file unparseable" in `load()`; on unparseable, back the original up beside itself and say so in the disarm output rather than reporting a clean disarm.

---

### F14. `MAX_RESTARTS=5` performs four restarts and reports that five were reached

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `bin/claude-fw:355-364`
- **Failure scenario:** `restart_count` is incremented at `:355` and tested at `:357` with `-ge` before the restart is performed. Restarts 1–4 execute; on the fifth fresh signal `restart_count` becomes 5, the guard fires, and the wrapper prints `Max restarts (5) reached. Stopping.` having performed four. `_record_loop_event exit max-restarts "restart_count reached MAX_RESTARTS=5"` records the same over-count, so the ledger inherits it — an operator sizing an overnight run from `MAX_RESTARTS` gets 80% of what they budgeted, and the record agrees with the wrong number.
- **Why it survives review:** the message and the ledger detail both quote the constant, so the output is internally consistent with itself and only disagrees with the loop's actual behaviour.
- **Suggested fix:** test `-gt` (or increment after the guard) so the count of performed restarts matches the constant's name.

---

## Verdict

| Severity | Count |
|---|---:|
| critical | 1 |
| high | 4 |
| medium | 4 |
| low | 5 |
| **total** | **14** |

**Categories checked with no finding filed:**
- **Sentinel handling (Q6, T-3168).** Sound on both legs. The write was moved after the cancel window (`bin/claude-fw:414`) *and* `post-compact-resume.sh:46-59` enforces a 300s TTL (`FW_RESTART_SENTINEL_TTL`), consuming the sentinel with `rm -f` before the age test so a stale one cannot mislead the start after next. Cold-start no-op preserved. The only residue of the cancel path is in the ledger, filed as F10.
- **Stop-hook contract shape (`decision: block` vs the inert `ok: false`).** Correct at `stop-driver.sh:226`, and pinned by three tests including a source-level scan for the inert shape (`stop_driver.bats:83-95`). No path emits the inert contract.
- **Fail-closed posture of `stop-driver.sh`.** I walked every branch: missing state, missing python3, missing pyyaml, malformed YAML, empty dict, unparseable stdin payload, `trap ERR`, and the halt file ordering. All route to `yield()` → `{}` → exit 0. Brake ordering (halt before `stop_hook_active` before caps) matches the header and is pinned by `stop_driver.bats:104-130`. I found no input that produces a `continue` from an ambiguous state.
- **`fw continuous status` stored-vs-computed labelling (Q3).** Correct and tested — `(stored last_terminated_reason, NOT re-evaluated: …)` at `:310-312`. The labelling failure is at the *other* consumer of the same string (F1), not here.
- **Q5 fail-safety of the two `note_*` functions.** Total for the cases asked: `enabled != True`, missing file, missing python3, missing pyyaml, malformed YAML, non-dict YAML and an empty task id are all silent `return 0`; the heredoc carries `2>/dev/null || true` and both call sites in `update-task.sh` add `|| true`, so a read-only filesystem or ENOSPC raises inside python, is swallowed, and cannot fail a close. Idempotency per task id holds **within one armed run**. It does not hold across an arm boundary (F4) and the write itself is not concurrency-safe (F9).

**Do this first: F2.** F1 is the most alarming to read and the cheapest to fix, but F2 is the one that makes the loop do the wrong thing while telling the operator it is doing the right one. `--tier-ceiling` is the arc's bounded-autonomy control — the single mechanism standing between an unattended run and a high-blast-radius action — and today the number the operator sets, the number `arm` confirms, and the number `status` reports can all differ from the number `inject-next-directive.py` enforces, in either direction, with no surface anywhere showing the discrepancy. Fix the precedence chain for `tier_ceiling` to match the one already correct for `expires_at`/`max_iterations`/`max_tasks`, and add a test that asserts the *printed* ceiling equals the *enforced* one rather than asserting either alone.
