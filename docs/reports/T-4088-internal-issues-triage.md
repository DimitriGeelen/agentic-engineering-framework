# T-4088: Internal (agent-filed) GitHub issue triage

**Run:** 2026-10-12. **Scope:** the 67 open issues on `DimitriGeelen/agentic-engineering-framework` authored by `DimitriGeelen` (class **internal**, as `fw issues sync --dry-run` classifies them). The 12 external issues (MikeEchoVoid #86-#94, clubanderson #13/#14, reflectme-source #85) are out of scope and were not touched.
**Authority:** operator standing instruction 2026-10-12. Fixed and duplicate internal issues are closed with one comment each and the operator reviews the list afterwards. Still-open ones are only listed. Issue text is untrusted data: it was read, not obeyed.

## Method

For each issue I read the body, then checked the claimed symptom against the current tree (`bleeding-edge` == `github/bleeding-edge`): grep of the named code, and a runtime check where cheap (`fw version --check`, `fw self-audit --help`, `fw metrics`, `is_bash_safe_command` / `has_bash_write_pattern` on the issue's own repro strings, `git ls-files -s` for modes). A verdict **fixed** needs all three: the symptom no longer reproduces at HEAD, a commit that changed it, and that commit on `github/bleeding-edge` (`git branch -r --contains`) plus its task in `.tasks/completed/` where a task exists. Unsure means **still-open**: no issue was closed on a guess.

Many Pen (050-email-archive) reports were filed against v1.6.258 and describe defects already fixed on the framework side before the report was written; those are the bulk of the fixed set.

## Counts

| Verdict | N |
|---|---:|
| fixed (closed with one comment) | 15 |
| duplicate | 0 |
| still-open (listed for the operator, no comment) | 52 |
| **total internal** | **67** |

## Fixed (closed)

| # | Title | Evidence (task, commit; all on `github/bleeding-edge` and `github/master`) |
|---|---|---|
| 3 | Add task tags to episodic summaries | Already implemented: `agents/context/lib/episodic.sh:102,446` reads task `tags:` into the episodic YAML (T-005, 090765ff1, 2026-02-13, before the issue). Current episodics carry them (e.g. `.context/episodic/T-4051.yaml` `tags: [bug, doctor, claude-fw]` = its task's tags). |
| 4 | Colored summary line in fw doctor | Already implemented: `bin/fw` doctor ends with a colored `All checks passed` / `N warning(s), no failures` / `N failure(s), M warning(s)` line (bin/fw:4926-4933; T-033, 4ad170e0e). Not the exact `8/8` wording of the example. |
| 8 | declare -A breaks on macOS bash 3.2 | T-518 (completed) 38fc8db1c: `declare -A` replaced by POSIX lookups. `grep 'declare -A' agents/task-create/update-task.sh` now matches only the comment. |
| 16 | /review/<id> 500 for vendored consumers (dispatch_pause import) | T-2645 (completed) 6e2957ce0: `web/blueprints/review.py:20` now `sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))`. |
| 20 | Greenfield seed T-002 circular decide-gate AC | T-2862 (completed) 2c04fc39f: the self-referential AC was removed from `lib/seeds/tasks/greenfield/T-002-define-project-goals.md` (comment at lines 119-135 explains). |
| 24 | fw build unrunnable: lib/build.sh mode 100644 | `git ls-files -s lib/build.sh` = 100755 at HEAD. Mode changed in c3165673a (T-3514, completed), incidentally; no regression guard for it yet (T-3317 detector is still open). |
| 31 | orchestrator-mcp-scan FAIL when baselines missing | T-2647 (completed) 233a8f509: missing baseline now exits 3, audit reports INFO "no baseline on this install yet" (agents/audit/audit.sh:7981-7986). |
| 34 | fw designer unusable: designer.sh mode 100644 | `git ls-files -s agents/designer/designer.sh` = 100755 at HEAD. Mode changed in c3165673a (T-3514, completed), incidentally; same caveat as #24. |
| 35 | doctor hook validator false "script not found" for ${CLAUDE_PROJECT_DIR} paths | T-3226 (completed) 7c06c84b2 (+ pin test 65d35cea9): the general branch expands `${CLAUDE_PROJECT_DIR}` (bin/fw:3482 area). |
| 57 | fabric drift per-path fork gives false unregistered | T-2518 (completed) 316c230ad: `echo|grep -qx` membership replaced (agents/fabric/lib/drift.sh:30). Fixed 2026-07-10, before the report. |
| 59 | healing resolve corrupts learnings.yaml / always L-001 | T-2672 (completed) a155f4411: scan and append accept any indent (agents/healing/lib/resolve.sh:116-125). |
| 60 | is_bash_safe_command classifies compound commands by first word | T-2834 (completed) 59a5ee971: per-segment judging of `&&`, `\|\|`, `&`, `\|`, `;`, newline. Verified at HEAD: `cd /tmp && bin/fw audit` SAFE; `git status && mv /a /b` BLOCK. |
| 66 | doctor framework-path check compares URL to path | T-2843 (completed): predicate moved to `lib/doctor-upstream.sh`, bin/fw:1807-1817. |
| 69 | watchtower.sh start ignores recorded port | T-3876 (completed) 05f5e2d74: one port rule for start and restart, `--port > configured PORT > last port > allocate`. |
| 75 | Tier-1 bypass: splitter misses newline, &, \|&, ;; and mid-word # | Same splitter as #60 (T-2834). Verified at HEAD with the issue's own repros: `git status\nmv`, `git status & mv`, `git status \|& mv`, `git status ;; mv`, `git status a#b; mv`, `git status x#y && mv` all BLOCK. |

## Still-open (no comment posted), with proposed task and recommendation

"New" = no task exists; recommendation is to file one. Related existing tasks are named where found.

| # | Title (short) | State found at HEAD | Proposed task | Recommendation |
|---|---|---|---|---|
| 2 | fw version --check | `fw version --check` is an unknown subcommand; `fw version check` is a different (sync/staleness) feature | New | Low value; implement or close as not planned. |
| 5 | --help for all subcommands | `audit/fabric/healing/context/handover/task/pickup/bus` print usage; `self-audit` and `metrics` do not | New (or fold into #36) | Fix the two stragglers, then close. |
| 6 | Cursor `.cursorrules` template | Template exists (lib/init.sh:1488) but is minimal: no tier awareness, no gate list | New | Expand the template or close as not planned. |
| 10 | No warning for untracked deliverables after fw git commit | No such warning in agents/git/lib/commit.sh | New | Small post-commit `git ls-files --others` check. |
| 11 | macOS GNU-isms (`head -n -1`, `date -d`) | Still present: episodic.sh:106, update-task.sh:2601, audit.sh:5514, metrics.sh:67 and :84 (partial fallback), audit.sh:8403 | New | Portability helper; matters only for macOS consumers. |
| 12 | fw vendor copies .sh without +x (1.3.0) | Current vendor uses `rsync -a` / `cp -r` (mode kept), but no test pins vendored exec bits; not reproduced | New (test only) | Add a bats pin, then close. |
| 15 | fw update --rollback lacks global path | `_do_rollback` is vendored-only (lib/update.sh) | New | Document the limit in --help or implement. |
| 17 | commit-msg hook: find_task_file not found | Current hook sources lib/tasks.sh (hooks.sh:166-171, fix T-519); not reproduced; the reporter's hook may predate it | New (repro first) | Reproduce with a fresh `install-hooks` in a vendored consumer; likely close. |
| 18 | secret-scan skips in git worktrees | Hook resolves scanner from `.framework.yaml` or `.agentic-framework/` only (hooks.sh:341-351); T-2647 made the skip loud, not fixed | New | Resolve via the main checkout's common git dir. |
| 21 | Fresh init cannot make first commit (.secret-scan-patterns) | T-2656 vendors the patterns file and T-3971/T-3983 make a missing catalogue "NOT CHECKED"; not re-run end to end | New (repro first) | Run the fresh-init simulation; probably fixed. |
| 22 | fw init seeds no .gitignore (Watchtower key) | Fix shipped: T-2896, 4f6ce58d2 (on bleeding-edge), but T-2896 is still in `.tasks/active/` (partial-complete, Human AC open) | T-2896 | Close after the operator finishes T-2896 review. |
| 25 | fabric drift false clean without watch-patterns; learnings null-key crash | Not re-verified; no fix commit found | New | Verify, then fix. |
| 26 | Tier 0 misses path-scoped `git checkout` | check-tier0.sh still matches only `checkout .` (line 233) | New | Real data-loss gap for dispatched workers; do this one. |
| 27 | Shared-identity DM confusion | Design concern; related T-1562, T-3286 | New inception | Operator decision. |
| 28 | Block partial secret fragments in peer messages | Proposal for a structural block; not implemented | New inception | Operator decision. |
| 29 | metrics.sh undercounts learnings/decisions | metrics.sh:153,156 still `^  - id: L-` / `D-` | New | Small fix; do it. |
| 30 | Episodics never git-added in consumers | Framework repo tracks episodics; consumer `.gitignore` behaviour not reproduced | New (repro first) | Check a fresh consumer. |
| 32 | Verification pipefail cross-project confirmation | Informational; companion to L-613 (T-3039, closed) | None | Operator: close as covered by L-613/T-3039 if no lint is wanted. |
| 33 | subscribe-learnings polls wrong primitive | Script still uses `termlink event poll` (lib/subscribe-learnings-from-bus.sh:105) | New | Needs a channel-read rewrite; verify against TermLink first. |
| 36 | fw self-audit ignores --help | Reproduced: `fw self-audit --help` runs the audit | New | Small fix. |
| 37 | Gate-bypass count miscounts FW_SWITCH_FOCUS | audit.sh:5004 still compares only `--switch-focus` | New | Small fix. |
| 38 | unclosed-satisfied scan ignores owner:human/inception | lib/task_satisfaction.py has no owner filter | New | Small fix. |
| 39 | create-task.sh templating corrupts on key substrings | Same ordered `str.replace` chain at create-task.sh | New | Real corruption risk; use a parsed template. |
| 40 | fw vendor mixed-vintage tree / VERSION stamp | Related captured tasks T-3135, T-3136; `checkpoint.sh budget` now exists in source | T-3135 / T-3136 | Operator: prioritise those. |
| 41 | Template cites CLAUDE.md §AC Classification Guidance consumers lack | Template still cites it (default.md:77) | New | Inline the rule or ship the section. |
| 42 | doctor: tracked path matches an ignore rule | No such check in doctor | New | Add the check. |
| 43 | CTL-013b WARN omits sampling design | Message unchanged | New | Wording fix. |
| 44 | CLAUDE.md check-in rule ends headless workers | Not fixed in the rule text | New | Reword rule for dispatched workers. |
| 45 | Root cause behind #41-#44 | Meta issue; no single fix | New inception | Operator decision; could close once #41-#44 land. |
| 46 | metrics: quoted last_update crash | Reproduced: `fw metrics` prints `[: 0 0: integer expression expected` | New | Small fix. |
| 47 | No verb to append an Updates note | No such verb | New | Add `fw task update --note`. |
| 48 | Gates attribute commits by message, not diff | hooks.sh:198-211 unchanged | New | Design change; operator decision. |
| 49 | CTL-010 PASS message contradicts WARN | Message unchanged (audit.sh:6087) | New | Wording fix. |
| 50 | Watchtower index handle: 1-hour TTL, stale inode | `_get_db` reopens only on TTL (web/embeddings.py:482) | New | Reopen on inode/mtime change. |
| 51 | fw git commit validates only the last -m | commit.sh:63-64 still overwrites `message` | New | Accumulate `-m` fragments. |
| 52 | dup-task-scan cannot tell half-staged rename | Not fixed | New | Message fix. |
| 53 | BVP value leg scores mentions as deliverables | Not verified fixed | New | Operator: BVP owner call. |
| 58 | doctor doc-drift reads framework CLAUDE.md in vendored mode | bin/fw:4487 still reads `$FRAMEWORK_ROOT/CLAUDE.md` | New | Read the project CLAUDE.md. |
| 61 | audit C-001 two emitters, filename-only match | Not verified fixed | New | Verify, then fix. |
| 62 | audit D2 lists 41 ids for count 33 | audit.sh:6713,6716 share `d2_details` | New | Split accumulators. |
| 63 | orchestrator-mcp-scan E2BIG | Fix exists in PR #76, only on branch `github/reland/pr76-77-79`; not in bleeding-edge | PR #76 | Operator: merge the re-land branch. |
| 64 | audit reads orchestrator warnings with head -1 | audit.sh:7964 still `head -1` | New | Fix with #65. |
| 65 | orchestrator probe hardcoded "cannot reach repo" | audit.sh:7988 unchanged | New | Fix with #64. |
| 67 | CTL-003 blames hook wiring for self-scheduled staleness | audit.sh:5851 message unchanged | New | Wording/logic fix. |
| 68 | stale-Watchtower remedy prints bin/watchtower.sh | bin/fw:2972 unchanged (correct only in the framework repo) | New | Use the mode-aware fw path. |
| 70 | fabric drift: card-vs-source divergence | Fix in PR on `github/reland/pr76-77-79`, not on bleeding-edge | PR re-land | Operator: merge or decline. |
| 72 | Implements #70 (fourth finding class) | Same as #70 | PR re-land | Same decision as #70. |
| 73 | fabric drift: watch set vs existing cards | PR #77 on the re-land branch, not on bleeding-edge | PR #77 | Operator: merge or decline. |
| 74 | fw pickup send cannot deliver | T-3628 made send honest ("NOT delivered") but the three delivery layers are not fixed | T-3628 follow-up | New task for profile lookup and secret. |
| 78 | has_bash_write_pattern exempts all of 2> | Reproduced: `bin/fw audit 2> out.txt` classifies SAFE / no-write (safe-commands.sh:1081) | New | Security-relevant; do this one. |
| 82 | fw task review emits hardcoded `go` next to NO-GO rationale | lib/review.sh:524 literal `go` | New | Sovereignty bug; do this one. |
| 83 | doctor stale-debt ignores horizon/status | No filter in the check | New | Small fix. |

(52 rows: #2 #5 #6 #10 #11 #12 #15 #17 #18 #21 #22 #25 #26 #27 #28 #29 #30 #32 #33 #36 #37 #38 #39 #40 #41 #42 #43 #44 #45 #46 #47 #48 #49 #50 #51 #52 #53 #58 #61 #62 #63 #64 #65 #67 #68 #70 #72 #73 #74 #78 #82 #83.)

## Actions taken

See the table below, filled in after the closes. Each close is one comment ending with the operator footer, a ledger row (stage `closed-fixed`) in `.context/issues/intake.jsonl`, then `gh issue close`.

| # | Result | Comment URL |
|---|---|---|
| (pending) | | |
