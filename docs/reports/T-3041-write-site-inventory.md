# T-3041 — `.context/` write-site inventory (static, read-only)

**Task:** T-3041 (inception) — AEF has a single-principal assumption baked in everywhere.
**Scope:** every write site under `.context/` reachable from `lib/`, `agents/`, `bin/`, `web/`, and the PreToolUse/PostToolUse hook scripts.
**Method:** two variable-resolving scanners over the code tree, then per-site code reading. Every classification below cites `file:line`. Nothing is inferred from a filename.
**Deliverable:** classification table only. No behaviour changed, nothing refactored, nothing fixed.

---

## 0. The reference case, and the one correction it forces

`lib/outcome.py:172-229` (`backprop_outcome` → `append_outcomes`) is the model:

> Append-only design: NEVER touches dispatches.jsonl. […] O_APPEND is atomic for small writes (<= PIPE_BUF, ~4KB) on POSIX. Each outcome row is a single line (well under 4KB).

That property holds and it is the right bar. The write is `OUTCOMES_LOG.open("a")` at `lib/outcome.py:223`.

**The correction this inventory forces, and it changes how the whole table reads:**

Roughly two dozen sites in this codebase carry a comment of the form
`# T-100190/T-100191: same-dir temp + os.replace — atomic write (L-493 class)`.
Read the origin (`agents/audit/audit.sh:5938-5940`): *"a kill mid-dump must not truncate the live file […] a cron audit killed mid-write corrupted this YAML."* That is **crash-atomicity**, and it works.

**Crash-atomicity is not concurrency-safety.** `os.replace` guarantees a reader never sees a half-written file. It guarantees nothing about a *lost update*: principal A loads, principal B loads, A dumps, B dumps — B's rename wins and A's edit is gone, cleanly and silently. Every `tmp + os.replace` site in the dangerous set below is therefore still a lost-update site. Treating the `L-493 class` comment as "this one is already safe for multi-principal" is the single most likely misreading of this codebase, so it is stated here rather than in a footnote.

Only two things in this tree actually serialise writers: `flock` (`lib/keylock.sh:89-95`) and `mkdir` test-and-set (`lib/bus.sh:127`). Those are in §4.

### Cross-cutting hazard: temp+rename destroys the group bit

Independent of lost updates, and it will bite on day one of a shared POSIX group:

- `lib/gaps.py:219-224` uses `tempfile.NamedTemporaryFile` → the temp file is created **0600**. `os.replace` at `:228` makes *that* the live `concerns.yaml`.
- `lib/compat.sh:19` (`_sed_i`, used on `inbox.yaml`, `focus.yaml`, task files) uses `mktemp` → also **0600**, then `mv` at `:21`.
- `Path.write_text` temps (`lib/bvp.sh:68-70`, `lib/reviewer/overrides.py:116`, `web/designer_registry.py:60-62`, `lib/verify_queue.py:204-206`) create **0644 & ~umask** — not group-writable under the default `umask 022`.

So: `chgrp -R` + `chmod g+w` over `.context/` survives exactly until the first write by either principal, after which the file is owned by that uid with the group bit stripped and the *other* principal gets EACCES. The mode has to be re-established by the writer (umask, explicit `chmod`, or setgid dir + a mode-preserving write helper), not just once at setup time.

---

## 1. THE DANGEROUS SET — shared content, read-modify-write, no lock

These are the sites where a shared POSIX group converts a clean `EACCES` into a silent lost update. Ordered by blast radius.

| # | File written | Writing code | Write pattern | Why shared | Lost-update mechanism |
|---|---|---|---|---|---|
| 1 | `.context/project/learnings.yaml` | `agents/context/lib/learning.sh:102,137,139` | `mktemp` (in `$TMPDIR`, **not** same-dir) → `awk` full rewrite → `mv` | Project memory, corpus-wide | Whole-file rewrite. **Also an ID race**: `corpus_max_id` is read at `:74` and the new `L-NNN` written at `:139` with no lock — two principals mint the same id. T-2902's comment documents 24 historical duplicate ids from a *different* cause; this is a second, unaddressed one. Cross-device `mv` is copy+rename, so not even rename-atomic. |
| 2 | `.context/inbox.yaml` | `agents/observe/observe.sh:154,347` (`_sed_i`) + `:174,185` (append) | **Mixed**: RMW *and* append to the same file | Observation queue, all agents | Worst shape in the tree. `_sed_i` at `:347` snapshots the file, rewrites, renames — silently discarding any record another principal appended at `:174` in between. The two-statement append (`:174` heredoc then `:185` `echo`) can also interleave mid-record. |
| 3 | `.context/arcs/<slug>.yaml` | `lib/arc.sh:486, 638, 666, 780, 896` | `open(fn,"w").write(...)` — **in-place truncate-rewrite, no temp, no rename** | Arc definitions, shared governance | Not even crash-atomic: a concurrent reader can see a truncated arc file, and a concurrent writer's edit vanishes. These five predate the T-100191 sweep that fixed `:1307`, `:1421`, `:1566`. |
| 4 | `.context/dispatches.jsonl` | `lib/spawn.py:216-258` (`update_outcome_row`) | Full-file read → rewrite all rows → `tmp` + `os.replace` | Dispatch ledger, fleet-wide | The one RMW on a log that is otherwise append-only (`lib/resolver.py:813`). A dispatch appended between the read at `:232` and the `os.replace` at `:258` is **erased entirely**, not merely un-updated. This directly violates the invariant `lib/outcome.py:177` relies on ("NEVER touches dispatches.jsonl"). |
| 5 | `.context/project/concerns.yaml` | `lib/gaps.py:300-365` → `_atomic_write` at `:216-228` | load-mutate-dump → `NamedTemporaryFile` + `os.replace` | Gap register, shared | Lost update on gap closure. Also the 0600 mode-strip described above. Note `lib/hook-threshold.py:174` writes the *same file* append-only (`concerns_path.open("a")`) — so a `gaps.py` close can silently drop a concurrently auto-registered `G-XXX`. |
| 6 | `.context/project/patterns.yaml` | `agents/context/lib/pattern.sh:124,155,157` | `mktemp` + `awk` rewrite + `mv` | Project memory | Same shape as #1, same non-same-dir `mktemp`. |
| 7 | `.context/project/practices.yaml` | `lib/promote.sh:337-343` | yaml load → append to list → `tmp` + `os.replace` | Project memory | Lost update on concurrent promote. |
| 8 | `.context/project/assumptions.yaml` | `lib/assumption.sh:134-138` (add), `:218-222` (validate) | yaml load → mutate → `tmp` + `os.replace` | Assumption register | Lost update; add and validate race each other. |
| 9 | `.context/cron-registry.yaml` | `web/blueprints/cron.py:56-59` (`_save_registry`); `bin/fw:4859` | `write_text(yaml.dump(...))` — **truncate-rewrite, not atomic**; and `open(...,'w')` | Scheduler source of truth | Watchtower (may run as a different uid than the CLI) and `fw cron` both rewrite the whole registry. Non-atomic, so also crash-corruptible — and corruption here breaks the doctor cron-sync gate. |
| 10 | `.context/settings.yaml` | `web/blueprints/settings.py:314-317` | `write_text(yaml.dump(...))` — truncate-rewrite | Project settings | Same as #9. Web-only writer today, but the file is shared state. |
| 11 | `.context/bypass-log.yaml` | `agents/context/check-tier0.sh:290-293` and `:364-367`; `bin/fw:7096` | yaml load-dump + `os.replace` | **Tier-0 audit trail** | A lost update here loses an audit record of a consequential action. Severity is out of proportion to its size. |
| 12 | `.context/working/reviewer-overrides.yaml` | `lib/reviewer/overrides.py:113-117` (`save_overrides`) | Full load-mutate-dump of every override + `tmp.replace` | Shared FP-suppression registry (not per-principal despite living in `working/`) | Concurrent `override add` loses one of the two. |
| 13 | `.context/bvp-weight-history.yaml` | `lib/bvp.sh:146-154` → `_atomic_write_text` at `:65-70` | `read_text` → append to `entries` → `tmp` + `os.replace` | BVP weight audit trail | **Documented as append-only at `lib/bvp.sh:1434` ("All mutations append to .context/bvp-weight-history.yaml (append-only)") but implemented as full read-modify-write.** The doc/impl divergence makes this likely to be mis-triaged as safe. |
| 14 | `.context/bvp-auto-promote-log.yaml` | `lib/bvp.sh:1369` | `write_text(yaml.safe_dump(data))` — truncate-rewrite, not atomic | Auto-promote ledger | Lost update + crash-corruptible. |
| 15 | `.context/designer/registry.yaml` | `web/designer_registry.py:57-62` (`save_registry`) | full dump → `tmp.replace` | Designer corpus registry | Lost update. Web-uid vs CLI-uid is the live split here. |
| 16 | `.context/project/received-learnings.yaml` | `lib/subscribe-learnings-from-bus.sh:59` | `{ … } > "$RECEIVED_FILE"` — truncate-rewrite | Cross-project learning inbox | Runs from cron; truncate-rewrite with no temp. |
| 17 | `.context/working/pending-updates.yaml` | `web/blueprints/pending.py:30`; `lib/pending.sh:60` | `open(...,'w')` full dump; `cat > "$PENDING_FILE"` | Cross-project pending register (shared, not per-principal) | Lost update between web and CLI. |
| 18 | `.context/cron/agentic-audit.crontab` | `bin/fw:4692`; `web/blueprints/cron.py:542`; `agents/audit/audit.sh:77` | `open(...,'w')` / `write_text` / `cat >` | Generated crontab | Three independent full-file generators. |
| 19 | `.context/audits/upgrades.yaml` | `lib/upgrade.sh:2089-2094` | `echo > file` then two `>>` appends | Upgrade audit trail | Truncate-then-append is a three-statement non-atomic sequence; a concurrent upgrade interleaves. |
| 20 | `.context/monitors/watchtower-rss.jsonl` | append `agents/monitor/watchtower-rss-sample.sh:88,91`; **retention** `:98` | Appends are safe; `tail -n N > tmp && mv` at `:98` is RMW | Monitor series | Mixed: the retention leg discards any line appended during the `tail`. Same shape at `agents/monitor/liveness-check.sh:88`. |
| 21 | `.context/monitors/*-latest.yaml` | `agents/monitor/liveness-check.sh:72`; `watchtower-rss-sample.sh:116` | `cat > FILE` / `{…} > FILE` truncate-rewrite | Monitor snapshot | Last-writer-wins; both run from cron. |
| 22 | `.context/project/traceability-baseline` | `bin/fw:7256` | `echo "$head_sha" > "$BASELINE_FILE"` | Shared audit baseline | Single-value file; last writer wins and the other principal's baseline silently moves. |
| 23 | `.context/project/enforcement-baseline.sha256` | `bin/fw:8083`; `lib/upgrade.sh:2105` | `echo "$EF_HASH" > "$EF_BASELINE"` | Shared enforcement baseline | Same as #22. |
| 24 | `.context/project/learnings.yaml` (consolidation path) | `agents/context/consolidate.py:360` | load → consolidate → `os.replace` | Project memory | Second, independent full-rewrite path into #1's file. |
| 25 | `.context/qa/*.json`, `.context/qa/conversations/*` | `web/blueprints/discovery.py:441,501,520` | `filepath.write_text(...)` truncate-rewrite | Q&A flywheel corpus | Per-file, so collision needs same-id; included because ids are derived, not uuid'd. |
| 26 | `.context/sessions/<id>.yaml` | `web/terminal/registry.py:130-131` | `open(path,'w')` + `yaml.dump` | Terminal session registry | Per-session file; shared directory. Non-atomic. |
| 27 | `.context/secrets/api-keys.enc` | `web/secrets_store.py:83` | `KEYS_FILE.write_bytes(encrypted)` — truncate-rewrite of the whole keyring | Shared secret store | Lost update loses a key. No temp, no rename, no lock. |

**Count: 27 dangerous sites.**

---

## 2. FULL INVENTORY

Per-principal = this agent's own state (focus, counters, budget, session metrics). Shared = corpus/governance state.

### 2a. Shared + read-modify-write — see §1 (27 entries, not repeated)

### 2b. Per-principal + read-modify-write or truncate — *different* failure, still real

These do not lose *shared* data, but two principals writing one path means each reads the other's state as its own. That is a correctness failure of a different kind (wrong-agent state, not lost update), and it is why this class is listed rather than dismissed.

| File | Writing code | Pattern | Principal-scoped content |
|---|---|---|---|
| `.context/working/focus.yaml` | `agents/context/lib/focus.sh:115-121` | same-dir tmp + `os.replace` | current task |
| `.context/working/focus.yaml` (fallback) | `agents/context/lib/focus.sh:124` | `_sed_i` (mktemp+mv) | current task |
| `.context/working/focus.yaml` (clear) | `agents/task-create/update-task.sh:2106`; `agents/resume/resume.sh:411` | `_sed_i` | current task |
| `.context/working/focus.yaml` (init) | `agents/context/lib/init.sh:48` | `cat >` truncate | current task |
| `.context/working/session.yaml` | `agents/context/lib/init.sh:26`; `agents/resume/resume.sh:372` | `cat >` truncate | session id |
| `.context/working/session.yaml` (touched) | `agents/context/lib/focus.sh:139` | `_sed_i` | tasks touched |
| `.context/working/arc-focus.yaml` | `lib/arc.sh:499,518`; `web/blueprints/arcs.py:1276` | `cat >` / `write_text` | current arc |
| `.context/working/.session-metrics.yaml` | `agents/context/session-metrics.sh:210` | `open(...,'w')` | session metrics |
| `.context/working/.session-metrics-offset` | `agents/context/session-metrics.sh:241` | `open(...,'w')` | turn offset |
| `.context/working/.budget-status` | `agents/context/budget-gate.sh:375`; `agents/context/post-compact-resume.sh:79` | `printf > FILE` / `cat >` | token budget |
| `.context/working/.budget-gate-counter` | `agents/context/pre-compact.sh:97`; `agents/context/lib/init.sh:73` | `echo >` | counter |
| `.context/working/.edit-counter` | `agents/context/commit-cadence.sh:76`; `agents/git/lib/hooks.sh:519` | `open(...,'w')` / `echo >` | counter |
| `.context/working/.tool-counter` | `agents/git/lib/hooks.sh:513`; `agents/context/lib/init.sh:70` | `echo >` | counter |
| `.context/working/.new-file-counter` | `agents/context/check-fabric-new-file.sh:82` | `open(...,'w')` | counter |
| `.context/working/.agent-dispatch-counter` | `agents/context/check-agent-dispatch.sh:63` | `echo >` | counter |
| `.context/working/.hook-counter`, `.hook-failure-counter` | `lib/hook-telemetry.sh:57,59` (`_fw_telemetry_increment`) | `mapfile` read → mutate → `printf > FILE` **in-place truncate** | per-hook counters — RMW, explicitly documented as such at `lib/hook-telemetry.sh:35` |
| `.context/working/.loop-detect.json` | `lib/ts/src/loop-detect.ts:88` (`writeFileSync`) | truncate-rewrite | loop state |
| `.context/working/.obs-highwater` | `agents/observe/observe.sh:87` | `printf > FILE` | read cursor |
| `.context/working/.verify-queue-state.json` | `lib/verify_queue.py:202-206` | `tmp` + `os.replace` | rotation cursor |
| `.context/working/.revisits-due.txt`, `.revisits-undated.txt` | `agents/context/revisit-due-scan.sh:149,157` | `mv tmp` | scan output |
| `.context/working/.onboarding-complete` | `agents/context/check-active-task.sh:755`; `update-task.sh:2131`; `bin/fw:7079-7080` | `echo >` then `>>` | onboarding marker |
| `.context/working/.tier0-approval[.pending]` | `agents/context/check-tier0.sh:463`; `bin/fw:6127`; `web/blueprints/approvals.py:600` | `echo >` / `write_text` | approval token — **borderline**: consumed cross-process, so a second principal's approval overwrites the first's pending hash |
| `.context/working/.subscribe-learnings-bus.cursor` | `lib/subscribe-learnings-from-bus.sh:37` | truncate | cursor |
| `.context/working/watchtower.{pid,port,url}` | `bin/watchtower.sh:213,256,257` | `echo >` (pid); tmp+`mv` (port/url) | host-local daemon state |
| `.context/working/framework-mcp.{pid,log}` | `bin/fw:5928-5929` | `>` redirect | host-local daemon state |
| `.context/working/.fw-secret-key` | `web/app.py:59` | `write_text` | web instance key |
| `.context/govd/state.json` | `lib/govd_holder.py:70-72` | `tmp` + `os.replace` | holder state |

**Count: 27 per-principal RMW/truncate sites.**

### 2c. Read-only consumers (safe either way) — not enumerated exhaustively

Confirmed read-only over `.context/`: `agents/resume/resume.sh` (except `:372,411`), `agents/handover/handover.sh` inbox/arc reads (`:468,721,745,759`), `lib/review.sh:26`, `lib/arc_membership.sh:76`, `web/shared.py:417-418`, `bin/fw` `learnings|decisions|practices|timeline` display paths (e.g. `bin/fw:7406,7501,7571`), `lib/notify.sh:76`, `agents/audit/audit.sh` check bodies. Safe under any permission model.

---

## 3. ALREADY-SAFE APPEND-ONLY SET

O_APPEND, one record per `write()`, well under `PIPE_BUF`. These need no change for multi-principal, given the file is group-writable.

| File | Writing code | Note |
|---|---|---|
| `.context/dispatch-outcomes.jsonl` | `lib/outcome.py:223` | **Reference case.** One JSON line per row. |
| `.context/dispatches.jsonl` (append leg) | `lib/resolver.py:813` | Safe — but see §1 #4, `lib/spawn.py:254` rewrites this same file. |
| `.context/project/decisions.yaml` | `agents/context/lib/decision.sh:147` | Single `echo "$entry" >>` — the whole multi-line YAML block is one `write()`. Safe while entries stay < 4KB. |
| `.context/working/feedback-stream.yaml` | `lib/reviewer/static_scan.py:2865-2867` | `open(...,"a")`, `---` doc separator. Two `write()` calls per event (`---\n` then the dump) — technically interleavable, but the separator makes damage recoverable. Documented append-only at `:2849`. |
| `.context/working/happiness.jsonl` | `agents/task-create/update-task.sh:1442` | `printf '%s\n' >>` single line. |
| `.context/bvp-driver-proposals.jsonl` | `lib/bvp.sh:1069`; `web/blueprints/bvp.py:100` | `open(...,'a')`. |
| `.context/audits/arc-bypass.jsonl` | `lib/arc.sh:356` | `{…} >> "$logf"` single block. |
| `.context/audits/arc-abandon.jsonl` | `lib/arc.sh:877` | Same. |
| `.context/audits/arc-scoped-driver-removals.jsonl` | `lib/arc.sh:1435` | Same. |
| `.context/audits/arc-scoped-weight-changes.jsonl` | `lib/arc.sh:1580` | Same. |
| `.context/audits/arc-scoped-driver-bypass.jsonl` | `lib/arc.sh:1790` | Same. |
| `.context/project/concerns.yaml` (auto-register leg only) | `lib/hook-threshold.py:174` | `concerns_path.open("a")`. Safe *in isolation*; unsafe against §1 #5. |
| `.context/govd/audit.jsonl` | `lib/govd_holder.py:46` | Comment at `:46`: *"append mode only — never truncate/rewrite"*. |
| `.context/govd/relay-audit.jsonl` | `lib/govd_relay.py:230` | Append. |
| `.context/working/.gate-bypass-log.yaml` (block form) | `lib/worktree.sh:625`; `lib/inception.sh:135`; `agents/context/check-active-task.sh:558`; `lib/rail-identity.sh:213`; `lib/review.sh:541`; `agents/task-create/create-task.sh:344`; `bin/fw:6844`; `lib/review_link_validator.py:367`; `agents/context/check-arc-id.py:123`; `check-inception-decisions.py:87`; `check-inception-recommendation.py:144`; `check-task-ac-structure.py:148`; `check-active-completed-dup.py:73`; `check-onboarding-gate.py:191`; `check-human-ac-tick.py:146` | All use a single `{ … } >>` block or one `open("a")` write. Safe. |
| `.context/working/.gate-bypass-log.yaml` (**exception**) | `agents/task-create/update-task.sh:79-83` | **Five separate `echo … >>` statements per record.** Each is O_APPEND-atomic individually, so no corruption — but two principals logging concurrently interleave their five lines into two mangled YAML entries. The only append site in the tree that is not record-atomic. Worth noting even though it is not a lost update. |
| `.context/harvest.log` | `lib/harvest.sh:141` | Single-line append. |
| `.context/bus/handler.log` | `agents/context/bus-handler.sh:16` | Single-line append. |
| `.context/working/.mirror-sync.log` | `lib/mirror.sh:83` | `{…} >>`. |
| `.context/working/.pickup-bridge.log` | `lib/pickup-channel-bridge.sh:38` | `printf … >>`. |
| `.context/working/.publish-learning-bus.log` | `lib/publish-learning-to-bus.sh:45` | `printf … >>`. |
| `.context/working/.subscribe-learnings-bus.log` | `lib/subscribe-learnings-from-bus.sh:42` | `printf … >>`. |
| `.context/working/.hook-crashes.log` | `bin/fw:7962` | Single-line append. |
| `.context/working/.compact-log` | `agents/context/pre-compact.sh:91,93`; `agents/context/checkpoint.sh:173,207` | Single-line appends. |
| `.context/working/.inception-checkpoint-log` | `agents/context/checkpoint.sh:418` | Single-line append. |
| `.context/working/peer-miss.log` | `lib/peer.py:131-132` | `MISS_LOG.open("a")`, one JSON line. |
| `.context/pickup/.dedup-log` | `lib/pickup.sh:152` | Single-line append. |

**Count: 29 append-only sites** (28 safe + 1 flagged record-interleaving exception at `update-task.sh:79-83`).

---

## 4. PROTECTED BY A LOCK — shown, not assumed

These are read-modify-write but genuinely serialised. Code cited so the claim is checkable.

| Protected resource | Lock | Code |
|---|---|---|
| Task-ID allocation (`.tasks/`, and `.context/locks/`) | `flock -x` via `keylock_acquire` | `agents/task-create/create-task.sh:311-315` acquires `"task-id-allocation"`; implementation `lib/keylock.sh:73-95` (`flock -w "$timeout"` / `flock -x`), lock dir `lib/keylock.sh:24` = `.context/locks`. Note `:311-312` re-points `KEYLOCK_DIR` at the **main worktree**, so worktrees share one lock — correct. |
| Per-task update | `flock -x` via `keylock_acquire "$TASK_ID"` | `agents/task-create/update-task.sh:1447-1449`, released on EXIT trap. Serialises concurrent updates to the same task id. |
| `.context/audits/*.yaml` + `.context/project/metrics-history.yaml` | `flock -n` on `.context/locks/audit.lock` | `agents/audit/audit.sh:339,351-353`; the metrics write itself is `tmp` + `os.replace` at `:5940-5947`. Since `audit.sh` is the only writer of `metrics-history.yaml` and it holds the lock for the whole run, this file is **safe** despite being RMW. |
| `.context/handovers/*` | `flock -n` on `.handover.lock` | `agents/handover/handover.sh:312-316`. Serialises the many-append handover build (`:254,643,785,1010,1100,1189,1214,1217,1307-1316`). |
| Pre-compact handover | `flock -n` on `.pre-compact.lock` | `agents/context/pre-compact.sh:30-38`. |
| `.context/bus/results/<task>/R-NNN.yaml` id allocation | `mkdir` atomic test-and-set | `lib/bus.sh:120-137` — comment at `:120-122` states the intent (T-605, multi-agent). Envelope write is same-dir `tmp` + `os.replace` at `lib/bus.sh:198-204`. **This is the best-designed multi-writer path in the tree** and is the pattern the dangerous set should be measured against. |
| Prompt-id allocation | `flock` | `lib/prompt.sh:79-80`. |
| `fw integrate` | lockfile at `.fw-integrate.lock` | `lib/integrate.py:270`. Outside `.context/` but gates writes into it. |

**Count: 7 lock-protected resources.**

Caveat that applies to all of them: `flock` is advisory and file-descriptor based — it works across uids **provided both principals can open the lock file for writing**. `.context/locks/` must be group-writable and stay that way, and `lib/keylock.sh:42` creates the lock file on demand, so the mode-strip hazard in §0 applies to the locks themselves.

---

## 5. UNDETERMINED — and what would resolve each

Listed as gaps rather than guessed. A wrong classification here would be trusted; these are not.

| Path | What I could not determine | What would resolve it |
|---|---|---|
| `.context/message-archive/**` | No writer found anywhere in `lib/`, `agents/`, `bin/`, `web/`. The `.json` / `.raw.json` / `.err` files are present and actively changing (visible in `git status`), so something writes them. | Identify the external producer — likely the TermLink CLI or a skills-manager dispatcher outside this repo. `lsof`/`fuser` on a live file during a fleet sync, or grep the `termlink` binary's source. |
| `.context/working/qa_feedback.db` | SQLite. `web/qa_feedback.py:16-19` opens a connection; concurrency depends entirely on journal mode (WAL vs rollback) and busy_timeout, neither of which is set in the code I read. | `PRAGMA journal_mode;` on the live DB, plus a grep for any `busy_timeout` / `isolation_level` setting. WAL + busy_timeout would make it multi-writer safe; rollback journal would not. |
| `.context/working/fw-vec-index.db` (+ `.manifest.json`, `.reindex.lock`) | Same SQLite question. A `.reindex.lock` file exists, suggesting *some* mutual exclusion, but I did not locate the code that creates or honours it. | Find the writer (likely the embeddings/indexer path under `web/blueprints/embeddings.py` or `lib/post-write-index.sh`) and read its lock acquisition. |
| `.context/handoffs/`, `.context/research/`, `.context/spikes/`, `.context/prompts/`, `.context/deployments/` | Directories exist; no in-repo write site located by either scanner. May be agent-authored via the Write tool (no code path), or written by external tooling. | Confirm whether these are agent-Write-tool targets only. If so they inherit the Write tool's semantics (truncate-rewrite, no lock) and should be treated as shared+RMW. |
| `.context/observations/`, `.context/working/observations/` | `agents/mcp/framework-mcp-manifest.json:120` advertises `fw note` as writing here, but I did not locate the write in `lib/`. | Read the `fw note` implementation end-to-end (it routes through the MCP manifest, so the write may be in a path my `.context`-literal scanners missed). |
| `.context/approvals/{pending,resolved}-*` | `web/blueprints/approvals.py:622` writes `resolved_file` with `open(...,"w")` — per-approval file, so probably collision-free. But the *pending→resolved* transition (create + delete pair) was not traced. | Read the full resolve path in `web/blueprints/approvals.py` and `agents/context/check-tier0.sh:306,466` together, to see whether the pair is atomic. |
| `.context/working/litellm/`, `.context/litellm-config.yaml` | `bin/fw:2340` only prints a suggested command; no framework-owned write located. | Determine whether litellm is launched by the framework or by the operator. |
| `.context/user-preferences/` | `web/blueprints/settings.py:49` defines `PREFS_DIR`; the write site was not isolated. | Read `web/blueprints/settings.py` prefs handlers. |
| `.context/working/escalation-drift-LATEST*.yaml` | Consumed by `web/templates/escalation_drift.html:26`; producer not located in-repo. | Likely a cron generator — check `.context/cron-registry.yaml` for the job and follow its command. |
| `.context/working/recall-telemetry.jsonl` | `web/recall_telemetry.py:140` computes the path but contains no write primitive I could find; `bin/fw:1939` only reads. | Grep for the appender across the `web/llm/` and `lib/ask.py` paths. Name and consumer both suggest append-only, but **the file name is not evidence** — not classified. |
| `.context/cron/*.crontab` deployed-vs-source | Whether `crontab -` installation is per-uid (it is, at the OS level) and how that interacts with a shared generated file. | Out of static scope — needs the runtime question answered: which uid's crontab is the deploy target. |

**Count: 11 undetermined paths.**

---

## 6. Summary counts

| Category | Count |
|---|---|
| **Dangerous — shared + read-modify-write, unprotected** | **27** |
| Full inventory — per-principal RMW/truncate (distinct failure class) | 27 |
| Already-safe append-only | 29 (28 clean + 1 record-interleaving exception) |
| Lock-protected (shown) | 7 |
| Undetermined | 11 |

---

## 7. Two observations that fall out of the inventory, offered without acting on them

1. **The safe pattern already exists in-tree.** `lib/bus.sh:120-137` + `:198-204` (mkdir test-and-set for id allocation, same-dir temp + `os.replace` for the payload) is a complete, working multi-writer design, written in 2 dozen lines of shell for exactly this reason (T-605). The dangerous set is not a design gap; it is 27 sites that predate or bypassed that pattern.

2. **The `L-493 / T-100190 / T-100191` sweep is a false-safety surface.** It touched ~24 sites and left a comment at each asserting "atomic write". Every one of those comments is true about crashes and silent about concurrency. Anyone triaging this inventory by grepping for that comment will conclude the fleet is in better shape than it is. If the de-rooting work lands, that comment string is the thing most likely to cause a site to be skipped.
