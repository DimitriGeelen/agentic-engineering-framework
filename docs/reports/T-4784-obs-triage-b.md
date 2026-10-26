# T-4784 — Observation triage, range B (OBS-256 .. OBS-456)

- **Scope:** the 126 entries in `.context/inbox.yaml` with `status: pending` and ids from OBS-256 to OBS-456.
- **Method:** each entry was checked against the code, git history, task status, and commands run on 2026-10-26. No verdict rests on age alone.
- **Counts:** RESOLVED 71 · DUPLICATE 15 · STILL-VALID 31 · UNCLEAR 9 (total 126)
- **Read-only:** this worker changed nothing except this report. The parent applies the verdicts serially.

Probes run today and cited below:
- **P1 (safe-commands):** `is_bash_safe_command` from `agents/context/lib/safe-commands.sh`, run on the command line each observation reported. The script was `/tmp/t4784b/safe.sh`. The control `echo hi > /tmp/x` came back UNSAFE, as it should.
- **P2 (BVP):** `bin/fw bvp --include-proposed`.
  - 208/500 tasks are flagged UNASSESSED and left out of the quadrant (T-4486).
  - 445/500 tasks have no cost.
  - Score ties: 161 tasks at 0, 49 at 9, 47 at 108, 45 at 18.
- **P3 (renderer):** `web.shared.render_markdown_safe`. Input `` `<that URL>` `` gave `<code>&amp;lt;that URL&gt;</code>`, while `` `<b>` `` gave `<code>&lt;b&gt;</code>`.

| id | verdict | evidence | proposed action |
|---|---|---|---|
| OBS-256 | STILL-VALID | `lib/upgrade.sh:290,526,613,679,732` copy +x (in since T-1217, 6db869b09). But `tests/unit/upgrade_fresh_machine_simulation.bats` has no exec-bit leg, which is the leg the OBS asks for | "upgrade simulation: assert exec bits survive fw upgrade into a consumer" (test) |
| OBS-257 | RESOLVED | `git ls-remote origin HEAD` works today; origin/bleeding-edge was pushed 2026-10-26 23:16 | dismiss (transient OneDev credential issue) |
| OBS-258 | RESOLVED | `web/embeddings.py:1042` handles kill+resume (names OBS-258); `lib/vector_index_health.py:565` keeps a `.reindex.resume` marker | dismiss |
| OBS-259 | RESOLVED | `ss -tlnp`: :11435 is served by nginx (a supervised service); `curl 127.0.0.1:11435/api/tags` returns models | dismiss |
| OBS-260 | DUPLICATE | OBS-267 later showed this is not a defect: 0-byte keylocks, bounded by the task count | dismiss as dup of OBS-267 |
| OBS-261 | RESOLVED | Report of T-3016 landing; T-3016 is work-completed | dismiss (informational) |
| OBS-262 | UNCLEAR | T-3020 closed with no named actor. Several automatic paths call `--status work-completed` (`lib/continuous-mode.sh`, `lib/inception.sh`, `agents/context/check-active-task.sh`, …) | settle by checking T-3020's close commit author/hook in git log around 2026-08-15 15:21 |
| OBS-263 | DUPLICATE | Same pgrep self-match class as OBS-266 (OBS-266 is its recurrence) | dismiss as dup of OBS-266 |
| OBS-264 | STILL-VALID | Behavioural lesson (read a gate refusal before retrying); no matching entry in `.context/project/learnings.yaml` (grepped "gate is not transient", "retry.*gate") | promote to a learning: "retry loops hide deterministic gate refusals" (no build task) |
| OBS-265 | STILL-VALID | `grep --version` → ugrep 7.8.4. `**` / mid-pattern `$` still parse as regex; nothing lints Verification greps for this | "Verification lint: flag non-`-F` grep patterns containing `**` or a mid-pattern `$`" (test) |
| OBS-266 | STILL-VALID | No self-match-safe pgrep idiom in the dispatch preamble or CLAUDE.md. The class is only mentioned in passing at learnings.yaml:4736 | "dispatch preamble: self-match-safe pgrep idiom (`pgrep -f 'audi[t]\.sh'`) for wait loops" (refactor) |
| OBS-267 | RESOLVED | The entry itself dissolves OBS-260: `.context/locks/*.lock` are 0-byte keylocks | dismiss |
| OBS-268 | UNCLEAR | Still true: rows in `.context/working/recall-telemetry.jsonl` have no version field (last row checked today). The OBS itself recommends no fix until the slice-6b consumer exists | settle when the T-3005 slice-6b consumer is built; until then dismiss per the OBS's own recommendation |
| OBS-269 | DUPLICATE | Refines OBS-252 (pending). `web/search_utils.py:95-103` now indexes policy/ etc., but `INDEXED_SUFFIXES` (:92) still has no `.bpmn`, so designer prose is still unindexed | merge into OBS-252 |
| OBS-270 | RESOLVED | `.framework.yaml:25` `project_name: 999-Agentic-Engineering-Framework` (b54eca10e, T-3067) | dismiss |
| OBS-274 | STILL-VALID | `agents/git/lib/hooks.sh:1902-1918`: the blocking branch prints "Fix the issues above" and the bypass line. It does not repeat the failing check names; only the worktree-scope branch (:1887) lists them | "pre-push: name the failing audit checks next to the push refusal" (build) |
| OBS-277 | RESOLVED | `git ls-remote origin` succeeds today | dismiss (transient server 403) |
| OBS-278 | RESOLVED | `tests/unit/handover_push_timeout.bats:38` regex now accepts `(bash )?` (T-4385) and matches `checkpoint.sh:299` | dismiss |
| OBS-279 | RESOLVED | `bin/fw gaps` now prints "open 40, mitigated 21, watching 18 …" and lists open entries | dismiss |
| OBS-280 | RESOLVED | `/etc/systemd/system/resolver-loop.service:55` runs `--stall-after 5`; T-3116 is completed | dismiss |
| OBS-281 | RESOLVED | Corrected in-entry; the read-path defect was homed in TermLink by T-3033 (completed) | dismiss |
| OBS-282 | RESOLVED | `agents/audit/audit.sh:7159`: CTL-028 now leads with the clean close and calls `--force` a last resort; T-3034 is completed | dismiss |
| OBS-283 | RESOLVED | `agents/audit/audit.sh:7061` "FORMERLY CTL-029 (renumbered T-3035)"; T-3035 is completed | dismiss |
| OBS-284 | STILL-VALID | `lib/gaps.py:106-124`: rc≠0 → UNKNOWN, discarding stdout; bad JSON → UNKNOWN; the reason is not surfaced. The contract appears only in the docstring | "gap closure gauge: report why a closure_check_command read UNKNOWN; document the contract in concerns.yaml header" (build) |
| OBS-285 | STILL-VALID | `termlink agent info` today: Retention `messages:1000`, Posts 1001. The cap is now lower than the 2000 the OBS reported, and history is still not durable | home in TermLink: "agent-chat-arc retention prunes peer coordination history" (build, termlink repo) |
| OBS-286 | STILL-VALID | The named tasks (T-2411, T-100194, T-100195) are fixed, but 9 files in `.tasks/completed/` still lack `status: work-completed` (T-3735, T-3760, T-4433, T-4434, T-4436, T-4481, T-4486, T-4502, T-4507) | "close the 9 CTL-028 status-drift tasks via the normal close" (refactor) |
| OBS-287 | RESOLVED | The measured table is now codified in CLAUDE.md §Execution Model (T-3037 completed) | dismiss (informational) |
| OBS-288 | STILL-VALID | `.context/dispatches.jsonl`: 4902 rows, `retry_of_dispatch_id` set in 0 and `parent_dispatch_id` in 0 (counted today) | "dispatch telemetry: populate retry_of/parent_dispatch_id lineage" (build) |
| OBS-289 | RESOLVED | Informational: the entry reports linking was already built (T-1722, T-632) | dismiss |
| OBS-290 | RESOLVED | The meta-finding produced the prior-art gate, T-3037 (completed) | dismiss |
| OBS-291 | RESOLVED | T-3038 "session-scoped focus for dispatched workers — OBS-291" is completed | dismiss |
| OBS-292 | RESOLVED | T-1719 is work-completed; `lib/post-write-index.sh` exists (the post-write hook call site) | dismiss |
| OBS-293 | RESOLVED | `bin/fw:11714` `fw test all` skips the pytest leg by default, citing OBS-293 | dismiss |
| OBS-294 | RESOLVED | `curl 127.0.0.1:11435/api/tags` answers today; failover is handled by T-3017 (work-completed) | dismiss |
| OBS-295 | UNCLEAR | The defect is in 150-skills-manager's credential gate (`fw-approve` vs `bin/fw-authority`), outside this repo | settle by checking 150-skills-manager's gate message; home it there (T-1333) |
| OBS-298 | STILL-VALID | `web/embeddings.py:1764` `_rag_retrieve` calls `_embed_single(query)` first, with no BM25-only fallback, so an ollama outage still kills retrieval before generation routing | "fw ask: fall back to BM25-only retrieval when query embedding fails" (build) |
| OBS-309 | RESOLVED | Correction entry; OBS-307 is already dismissed | dismiss |
| OBS-310 | RESOLVED | Correction entry (contention, not deadlock); no defect claimed | dismiss |
| OBS-311 | RESOLVED | T-3054 is completed; reviewer R-3e24a4f6 detected the line; its Verification :216 asserts the URL shape separately | dismiss |
| OBS-312 | STILL-VALID | `agents/audit/audit.sh:5879` greps `P-[0-9]+` from the `Origin:` line (fed by :5890 `grep "Origin:"`); the id lives on the heading, so the WARN still reads "Practice unknown" | "audit practice-origin: take the practice id from the preceding `## P-NNN` heading" (build) |
| OBS-313 | DUPLICATE | Captured as learnings.yaml:4228 ("Mutation tests need a validity check on the mutant") | dismiss as dup of that learning |
| OBS-314 | STILL-VALID | `lib/reviewer/static_scan.py:915-925` counts only `tests/` lines; a Verification line driving the real CLI (no tests/ path) is not counted as integration evidence | "reviewer mock-only-integration: count live-CLI Verification lines as integration" (build) |
| OBS-316 | RESOLVED | T-3060 (sweep, OBS-316) and T-3061 (audit rail) are completed | dismiss |
| OBS-318 | STILL-VALID | `agents/context/check-active-task.sh:1450` now limits the match to the AC section, but any occurrence there counts, so an AC that quotes `[First criterion]` still trips it | "G-020: match only checkbox lines whose text is the template placeholder" (build) |
| OBS-319 | RESOLVED | `agents/context/lib/learning.sh:107,124` emit through escaped `ENVIRON["L_ESC"]` | dismiss |
| OBS-320 | RESOLVED | `lib/config.sh:178-179` exempts usage exits (`_FW_HOOK_USAGE_EXIT`); T-4227 is completed | dismiss |
| OBS-321 | STILL-VALID | No duplicate/sibling-task check in `bin/fw` work-on or `agents/task-create/create-task.sh` (grep for similar/existing active task: none) | "fw work-on: warn when an active task with a near-identical name exists" (build) |
| OBS-322 | STILL-VALID | `bin/migrate-horizon-null-completed.sh:23-24` still defaults PROJECT_ROOT to FRAMEWORK_ROOT | "migrate-horizon-null-completed.sh: resolve PROJECT_ROOT for vendored projects" (build) |
| OBS-323 | STILL-VALID | P2: assessed tasks still cluster (49 at 9, 45 at 18, 18 at 27) despite T-3084 | "BVP estimator: improve value-score spread among assessed tasks" (build) |
| OBS-324 | RESOLVED | The "All workers cleaned up" text is gone; `agents/termlink/termlink.sh:593,767` check `_runtime_alive` and keep live workers (T-3651) | dismiss |
| OBS-325 | STILL-VALID | `stat /var/lib/termlink/hub.sock` → `srwxr-xr-x root root` (2026-10-26 14:02): the 0770 fix was lost on restart again | home in TermLink: "hub socket mode persists across restart" (build, termlink repo) |
| OBS-326 | STILL-VALID | `lib/resolver.py:465` `git rev-parse HEAD:<path>` returns the committed blob even when the working tree is modified | "resolver workflow_sha: hash working-tree bytes when the file differs from HEAD" (build) |
| OBS-327 | RESOLVED | T-3076 is completed; `agents/context/check-project-boundary.sh:206-216` drops only termlink segments (`_drop_termlink_segments`) | dismiss |
| OBS-328 | RESOLVED | `web/blueprints/inception.py:625-660` classifies the outcome (`LANDED_INTERRUPTED` etc.) and runs decide in a detached runner (T-3749, `web/decide_runner.py`) | dismiss |
| OBS-329 | RESOLVED | Self-correction committed (5af747df2) | dismiss |
| OBS-330 | STILL-VALID | `bin/fw:8883-8990`: the approval command has only approve / status / help; no withdraw/deny | "Tier 0: add a withdraw verb for an agent's own pending card" (build) |
| OBS-332 | RESOLVED | P2: the 108-point no-signal ties are flagged UNASSESSED and excluded from the quadrant (T-4486) | dismiss |
| OBS-333 | RESOLVED | `agents/context/lib/safe-commands.sh:2625` (T-3245) judges the line with quoted text stripped, so the Co-Authored-By `<…>` no longer reads as a redirect | dismiss |
| OBS-379 | RESOLVED | P1: `checkpoint.sh budget`, `termlink pty output … --strip-ansi`, `bin/fw bvp` → SAFE; T-3344 is completed | dismiss |
| OBS-380 | RESOLVED | T-3343 is completed (7d5f3a201 re-anchors the pin) | dismiss |
| OBS-381 | STILL-VALID | No framework rule or guard for the shared-index race; "commit -- <paths>" exists only in parent-written briefs (grep lib/ agents/ bin/ policy/: none) | "dispatch preamble: require `git commit -- <paths>` in a shared checkout" (refactor) |
| OBS-382 | RESOLVED | `lib/init.sh:220-229` uses `--show-toplevel` and refuses an enclosing / or $HOME repo | dismiss |
| OBS-383 | RESOLVED | `lib/validate-init.sh:568` wraps the grep in `{ … \|\| true; }` | dismiss |
| OBS-384 | UNCLEAR | Residual questions (idle TUI exits 0 after ~35 min; wrapper returned 1) were not reproduced; T-3358 is still started-work | settle by reproducing an idle `claude-fw --termlink` session and checking the exit-code pass-through |
| OBS-385 | RESOLVED | T-3350 (card the 8 policy/ YAML files) is completed | dismiss |
| OBS-386 | RESOLVED | `.context/audits/unit-suite/LATEST.yaml` has a `timed_out` field (false on 2026-10-26) and per-leg `files_timed_out`; T-3357 is completed | dismiss |
| OBS-387 | RESOLVED | Per-leg `files_timed_out` now separates timeout casualties from failures (`agents/audit/unit-suite.sh`) | dismiss |
| OBS-388 | RESOLVED | `agents/audit/audit.sh:3751` (T-3443, completed) skips the nested lint suite when PROJECT_ROOT is not the framework | dismiss |
| OBS-389 | STILL-VALID | P2: UNASSESSED 108-point tasks still sort above every assessed task except T-3731 in the ranked list (only QUAD shows '-') | "fw bvp: sort UNASSESSED tasks below assessed ones" (build) |
| OBS-390 | STILL-VALID | P1: `f=$(ls … 2>/dev/null \| head -1); …` → UNSAFE; minimal form `f=$(ls .tasks 2>/dev/null \| head -1)` is also UNSAFE | "safe-commands: accept read-only pipelines with stderr suppression inside `$(…)`" (build) |
| OBS-391 | DUPLICATE | About T-3328's own AC4; T-3328 is active (captured) | dismiss as dup of T-3328 |
| OBS-393 | RESOLVED | OBS-250 class handled by WM tasks (`lib/wm_tasks.sh`, T-3537 completed) and the just-closed grace (`check-active-task.sh:984`, T-4182 completed) | dismiss |
| OBS-396 | DUPLICATE | `tests/unit/audit.bats:23-25` still skips on exit 75; this is T-3328's scope | dismiss as dup of T-3328 |
| OBS-397 | RESOLVED | Prediction reconciled by OBS-412 (1183f6eaf) | dismiss |
| OBS-398 | DUPLICATE | P2: 445/500 have no cost; tracked by T-3471 (active, captured) | dismiss as dup of T-3471 |
| OBS-399 | STILL-VALID | T-3302, T-3297, T-3298 and T-3328 still have no `arc_id:` (grep today) | "assign an arc to the unit-suite false-signal cluster (T-3302/3297/3298/3328)" (refactor) |
| OBS-400 | RESOLVED | Corrected by OBS-401; T-3359 is completed; LATEST unit-suite `timed_out: false` | dismiss |
| OBS-401 | RESOLVED | Same as OBS-400 | dismiss |
| OBS-403 | RESOLVED | T-3443 (`audit.sh:3751`) skips the nested lint suite for fixture projects | dismiss |
| OBS-404 | STILL-VALID | `tests/lint/no-untracked-test-files.bats:37-42` `_is_collectable` matches `*.bats\|test_*.py\|*_test.py`, not `conftest.py` | "no-untracked-test-files: treat conftest.py as collectable" (test) |
| OBS-405 | DUPLICATE | Cost half matches T-3471; value half is covered by OBS-323 | dismiss as dup of T-3471 / OBS-323 |
| OBS-406 | STILL-VALID | `.tasks/templates/default.md:75,95` still contain `## Verification` inside the guidance comment, before the real header at :113 | "task template: no literal `## ` section headers inside guidance comments" (refactor) |
| OBS-407 | RESOLVED | Push/ls-remote to origin work today (origin/bleeding-edge 2026-10-26) | dismiss |
| OBS-408 | RESOLVED | OBS-250 class: T-3537 WM tasks + T-4182 grace window | dismiss |
| OBS-409 | RESOLVED | P1: `for … python3 -c "…open(…)…"` → SAFE | dismiss |
| OBS-410 | UNCLEAR | `test_live_corpus_all_versions_census` passes today (pytest, 1.75 s), but whether an exact-count pin should exist at all is still an operator question | settle by an operator ruling on what the census pin is for |
| OBS-411 | STILL-VALID | P3: `` `<that URL>` `` → `&amp;lt;` (double-escaped) in `render_markdown_safe` | "renderer: do not double-escape non-tag `<…>` inside backticks" (build) |
| OBS-412 | RESOLVED | Reconciliation entry; LATEST unit-suite `timed_out: false` | dismiss |
| OBS-413 | RESOLVED | P1: `echo; cat … 2>/dev/null; cat …` → SAFE | dismiss |
| OBS-414 | STILL-VALID | P1: `bin/fw vendor self --check` → UNSAFE | "safe-commands: allowlist `fw vendor self --check`" (build) |
| OBS-415 | DUPLICATE | Quadrant selection fails because cost is missing (only 8 tasks have one, P2): T-3471 | dismiss as dup of T-3471 |
| OBS-416 | STILL-VALID | `agents/termlink/termlink.sh:1382` "this call path has no dispatches.jsonl row" | "fw termlink dispatch: write a dispatches.jsonl row" (build) |
| OBS-417 | RESOLVED | T-3371 (flock-serialised counter, 128fd91d1) is completed | dismiss |
| OBS-418 | RESOLVED | Withdrawn by OBS-420; T-3372 is completed | dismiss |
| OBS-419 | RESOLVED | OBS-250 class: T-3537 + T-4182 | dismiss |
| OBS-420 | RESOLVED | Correction entry; T-3372 is completed | dismiss |
| OBS-421 | UNCLEAR | T-3372 fixed the measured instance (test 14); not checked whether other bats tests still scope only by env PROJECT_ROOT | settle by grepping tests/unit/*.bats for `PROJECT_ROOT=` without a cd / `env -u` |
| OBS-422 | RESOLVED | P1: `WURL=$(cat …)` and `out=$(bin/fw doctor)` → SAFE; T-3373 is completed | dismiss |
| OBS-424 | RESOLVED | `bin/fw vendor self --check --task` scoping, with other tasks' drift reported "in flight, not this task" (`lib/upgrade.sh:248`, T-4419) | dismiss |
| OBS-425 | RESOLVED | OBS-250 class: T-3537 + T-4182 | dismiss |
| OBS-426 | RESOLVED | `cat VERSION` = `git show HEAD:VERSION` = 1.8.14 | dismiss |
| OBS-427 | RESOLVED | Informational (no defect asserted); T-3377 is completed | dismiss |
| OBS-428 | RESOLVED | `lib/continuous-mode.sh:618` re-arm clears `last_terminated_reason`; `status` re-evaluates live (:245-256) | dismiss |
| OBS-429 | DUPLICATE | Concurrent writer in a shared checkout = G-083 (watching) | dismiss as dup of G-083 |
| OBS-431 | RESOLVED | OBS-250 class: T-4182 grace for the just-closed task's commit (`check-active-task.sh:984`) | dismiss |
| OBS-433 | RESOLVED | `bats -f anti-vacuity tests/unit/t2862_greenfield_first_inception_e2e.bats` → ok today | dismiss |
| OBS-434 | STILL-VALID | `lib/watchtower.sh:242` still says "Start one with: fw serve", whatever holds the port | "watchtower url hint: suggest `fw watchtower restart` when the port is held by a foreign service" (build) |
| OBS-435 | RESOLVED | The liveness rail is in cron (`liveness-1m`, cron-registry.yaml:245); T-3380 and T-3382 are completed | dismiss |
| OBS-436 | DUPLICATE | `parent_dispatch_id` set in 0/4902 rows — same finding as OBS-288 | dismiss as dup of OBS-288 |
| OBS-438 | RESOLVED | T-3695 Bash guard: today a python3 heredoc whose body named `.tasks/` was refused by check-human-ac-tick ("python3 runs inline code and the command names a guarded path") | dismiss |
| OBS-439 | DUPLICATE | Quadrant-selection failure = T-3471 (cost); the 108 default is now excluded (T-4486) | dismiss as dup of T-3471 |
| OBS-440 | STILL-VALID | `tests/unit/test_review_markdown_render.py:138-152` asserts the href shape only; nothing asserts that the auto-linkifier fired | "test_parse_ac_body: assert the linkifier fired (non-vacuous)" (test) |
| OBS-441 | RESOLVED | A selection snapshot from 2026-09-20 that asserts no defect | dismiss |
| OBS-442 | RESOLVED | The named blocker T-2918 is now work-completed | dismiss |
| OBS-443 | RESOLVED | P2: no-signal tasks print as UNASSESSED and are excluded from the quadrant (T-4486) | dismiss |
| OBS-444 | UNCLEAR | TermLink-side claim (state:ready ≠ conversational reader); not checked from this repo | settle in TermLink: does discover expose a reader/agent liveness field |
| OBS-445 | UNCLEAR | Stalled dm consult (dm:3bba15e681b3a078, offset 12); not re-read today (shared-identity dm rails) | settle by reading that dm thread for a reply since 2026-09-17 |
| OBS-446 | DUPLICATE | Cost axis needs components: → T-3471 | dismiss as dup of T-3471 |
| OBS-448 | DUPLICATE | Second autonomous run on the same checkout = G-083 (watching) | dismiss as dup of G-083 |
| OBS-449 | RESOLVED | Advisory to check TermLink before building; the arc-011 sidecar has since shipped (T-3404, T-3407 completed) | dismiss |
| OBS-450 | RESOLVED | P1: `python3 -c "import json; json.load(open(…))"` and a grep with `\|`/`>` in its pattern → SAFE | dismiss |
| OBS-451 | RESOLVED | `agents/task-create/update-task.sh:634`: the boundary `[^[:alnum:]_-]` excludes hyphens, so `BVP-CALIB-RCA-832` no longer matches | dismiss |
| OBS-452 | STILL-VALID | `agents/task-create/update-task.sh` has no vendored-drift check at close (grep "vendor self --check": none); it relies on authors adding the line to Verification | "close gate: refuse work-completed when the task's commits leave vendored drift" (build) |
| OBS-454 | UNCLEAR | Operator question (should workflow_type resolve to a design reference?); no recorded ruling found | settle by an operator ruling (related: T-4737, active) |
| OBS-455 | RESOLVED | `agents/termlink/termlink.sh:708,774`: uncollected results are KEPT; cleanup needs `--yes` | dismiss |
| OBS-456 | DUPLICATE | P2: 445/500 have no cost; T-3471 "derive blast_radius before work-completed" (active) | dismiss as dup of T-3471 |
