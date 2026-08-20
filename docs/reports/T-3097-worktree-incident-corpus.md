# T-3097 — Worktree incident corpus

**Scope:** every recorded incident in this repo involving git worktrees, mined from
`.tasks/{active,completed}/`, `.context/inbox.yaml`, `.context/project/concerns.yaml`,
`.context/project/learnings.yaml`, `docs/reports/*.md`, and `git log --all`.

**Mined against:** branch `t2539-staging`, HEAD `7e1cecbbc`, 2026-08-20.
Corpus sizes at time of mining: 3086 task files (188 mention `worktree`),
329 observations (13 match `worktree|strand`), 91 concerns (5 match),
671 learnings (7 match), 36 reports (mention), 25 worktree-bearing commit subjects.

**This is evidence collection only.** No fixes are proposed. Where a claim could not be
verified it is written `unknown`, not guessed.

---

## 1. Incident table

Sorted oldest first. `still live?` states the check used. Verification commands were run
in the main checkout at HEAD `7e1cecbbc` on 2026-08-20 unless noted.

| # | date | id | one-line symptom | mechanism in one clause | what shipped as the fix | still live? |
|---|------|----|------------------|-------------------------|-------------------------|-------------|
| 1 | 2026-04-25 | D-026 / T-1483 | (not a defect — the *only* recorded worktree decision) | WorktreePool: one worktree per audit run, checkout per task | `decisions.yaml:167-172`; reviewer Pass B worktree-reuse re-execution (T-1483) | **n/a** — baseline. Verified sole worktree decision by `grep -n D-026 .context/project/decisions.yaml`; T-2822 report re-verified independently (`docs/reports/T-2822-worktree-policy.md:97`) |
| 2 | 2026-04-26 | T-1488 / L-281 | CTL-013 bats false positive on T-1472; 3 sessions could not localise the Heisenbug | inline re-execution shares dirty shell state; worktree isolation is the clean alternative | deferred to Pass B (`fw reviewer audit --pass-b`, T-1484) which re-executes in worktree isolation; `learnings.yaml` L-281 | **no** — superseded by design. `T-1488:118` records "the signal moves; it doesn't vanish". Worktree used here as *remedy*, not as fault |
| 3 | 2026-06-13 | T-2375 / L-482 | budget gauge blind in every worktree session — "no transcript" | `${PROJECT_ROOT//\//-}` replaces only `/`; Claude Code replaces every non-alnum, so `.claude/worktrees/` mismatches the real projects dir | `fw_claude_project_dir_name()` in `lib/paths.sh:207`; gauge migrated | **no** for this leg — helper present at `lib/paths.sh:207`. But see rows 4-6, 9, 11: the *class* recurred five times |
| 4 | 2026-06-13 | T-2377 | gauge still blind after T-2375 — loop never armed | base path still derived from cwd; Claude Code writes the transcript to the *launch* cwd's dir, not `PROJECT_ROOT` | prefer `transcript_path` from hook stdin JSON, reconstruction as fallback (`T-2377` Context) | **no** for the stdin leg — `agents/context/budget-gate.sh`/`checkpoint.sh` consume stdin first. Recurrence is at reconstruction sites, rows 5-6, 9, 11 |
| 5 | 2026-06-13 | T-2380 / L-483 | `fw costs session` → "No JSONL directory found at …Framework-.claude-worktrees-…" | `fw costs`, `discard-manifest.sh`, `read-transcript.py` kept the slash-only sanitizer T-2375 replaced | three call sites migrated to `fw_claude_project_dir_name` | **no** — commit `ceb4fcccf`. L-483 names the class explicitly: "T-2375 created the helper … but never swept the corpus" |
| 6 | 2026-06-14 | T-2392 | PostToolUse hook reads 0 tokens despite a *correct* `PROJECT_ROOT` | Claude Code keys the projects dir on launch cwd (main repo), so a correctly-anchored worktree lookup still finds nothing | `fw_claude_project_dirs()` union resolver, `lib/paths.sh:226`; both gauge sites search both candidate dirs | **no** — `lib/paths.sh:226` present. Commit `6f3ca8aee` is itself titled "corrected RCA" — the first RCA was wrong |
| 7 | 2026-06-14 | T-2389 / T-2390 | spawned `claude-fw` session ran hooks with `PROJECT_ROOT=/root`; gauge blind, loop never armed | **not** cwd-walking (that hypothesis is marked SUPERSEDED in `T-2390`) — a stale `PROJECT_ROOT=/root` inherited from the tmux-server daemon env; `bin/fw` only resolves when the var is empty | T-2391: `bin/fw` validates inherited `PROJECT_ROOT` and rejects `=$HOME` poison (commit `67893ed78`) | **unknown** — validation code present per commit `67893ed78`; not re-driven live from a tmux daemon in this mining pass |
| 8 | 2026-06-14 | T-2393 | divergent worktree/master state, resolution unclear without loss | worktree and master both carrying unique work with no reconciliation verb | inception → `docs/reports/T-2393-consolidation-options.md`; executed by T-2395 (merge master into branch + vendor sync) | **yes** (class) — see rows 24, 30, 47. The one-off was resolved; the class was not |
| 9 | 2026-06-14 | T-2400 | three more transcript-dir consumers blind in worktrees | same as row 6, at sites T-2392 did not sweep | swept `read-transcript.py`, `discard-manifest.sh`, `lib/costs.sh` onto `fw_claude_project_dirs` | **no** for those three; `lib/costs.sh` needed row 11 |
| 10 | 2026-06-14 | OBS-076 / T-2398 / T-2436 | self-vendor gate reports phantom drift, blocks **all** master pushes | `_self_vendor_libs` `find` does not prune `node_modules`/`__pycache__`; true on main where `npm install` ran, **false on fresh worktrees → silent until you push from main** | `find` prunes added (commit `8c4073cb8`); T-2436 added the `--check` silent-mutation trap | **no** — `inbox.yaml` OBS-076 `status: promoted`. Worktree relevance is the *asymmetry*: the worktree hid the bug |
| 11 | 2026-06-16 | T-2425 | `fw costs` still blind in worktree after T-2380 + T-2400 | `lib/costs.sh:_costs_jsonl_dir` migrated the *name* helper in T-2380 but kept single-dir lookup; needed the *union* leg | costs.sh consumes `fw_claude_project_dirs` | **no** — fifth and final fix in this chain |
| 12 | 2026-06-18 | OBS-077 / T-2435 / L-486 | audit cron checks FAIL inside a linked worktree | cron is installed once from the main checkout under the MAIN slug; its absence under the worktree slug is expected, not drift | `fw_is_linked_worktree` INFO-skip for host-environment legs, `agents/audit/audit.sh:1836,1906,1991` | **no** — three guarded call sites verified live. **Caveat:** OBS-077's own text is LOST, see §4 |
| 13 | 2026-06-18 | T-2437 / L-486 | sibling cron *misload-lint* leg unguarded — latent false-FAIL in worktrees | T-2435 guarded one of two legs; the second had the same shape and was missed | second leg guarded; L-486 codifies CONTENT-vs-HOST-ENVIRONMENT classification | **no** — `agents/audit/audit.sh:1906` guarded. Note the shape: a same-day sibling miss, identical to rows 3→5 |
| 14 | 2026-06-21 | OBS-083 | `resolve_framework.bats` 17/18/19 FAIL in the worktree checkout | suspected worktree-path canonicalisation in fixtures (`readlink -f` on `.claude/worktrees/`) — never confirmed | **nothing** | **unknown** — `inbox.yaml` OBS-083 `status: dismissed`, `promoted_to: None`. Triage question ("does it reproduce on a non-worktree master checkout?") was never answered in the record |
| 15 | 2026-06-21 | T-2446 | `fw serve` from a fresh consumer misidentifies the project as /opt/999 | inherited `CLAUDE_PROJECT_DIR` from a long-lived TermLink daemon; trusted without a cwd-consistency check. **Original F10 framing was disproven** | cwd-consistency check on `CLAUDE_PROJECT_DIR` (T-2446) | **unknown** — fix committed; not re-driven through a TermLink daemon in this pass |
| 16 | 2026-06-22 | T-2462 | `git push` blocked by the active-task gate in worktree sessions | gate misfires in worktrees (row 17); push was safe-listed to sidestep the symptom | git push/fetch added to the gate safe-list | **no** as a workaround; it treated the symptom. T-2464 predicted the safe-list "may become unnecessary once resolution is correct" |
| 17 | 2026-06-23 | T-2463 / OBS-080(cited) | worktree work blocks "No active task" whenever main's focus is null | hook is wired by main's absolute path, so `bin/fw` resolves `PROJECT_ROOT` from the hook process cwd (main) while the agent's own commands run cwd=worktree — "the two never meet" | inline re-anchor from stdin `cwd` in `check-active-task` (commit `640d22885`) | **no** — generalised by row 19. **Note the OBS-080 collision**, §4 |
| 18 | 2026-06-23 | T-2464 | *the meta-incident*: same root patched 7+ times, never centrally | `docs/reports/T-2464-worktree-reliability-rca.md:48-57` tabulates 7 tasks, one mechanism: "This is whack-a-mole. Each fix re-implements 'figure out the real root' locally" | inception, GO Candidate C (resolution first, then lifecycle) | **yes** (partially) — resolution shipped (rows 19-20); lifecycle shipped (`fw worktree` verbs); the *class* recurred at an unswept surface, row 29 |
| 19 | 2026-06-23 | T-2465 | (fix) per-hook re-implementation of root resolution | — | `fw_reanchor_from_cwd()`, `lib/paths.sh:110` — one shared per-call resolver | **live and present** — verified `grep -n 'fw_reanchor_from_cwd()' lib/paths.sh` → :110 |
| 20 | 2026-06-23 | T-2468 | python hooks still read `os.environ['PROJECT_ROOT']` → misanchored to MAIN | bash hooks were swept in T-2465; the python hooks (`check-arc-id`, `check-inception-*`) were a separate surface | `lib/hook_paths.py:reanchor_project_root` | **live and present** — verified `lib/hook_paths.py:30` |
| 21 | 2026-06-23 | T-2464 §Problem 2 | vendored `.agentic-framework/agents/context/*.sh` lost the executable bit; bare `fw` → "Permission denied" | worktree creation / vendor sync does not preserve `+x` | T-2467 (slice 3, vendored +x preservation) | **unknown** — recorded in `T-2464` report as "observed, **unfiled**". See §4 |
| 22 | 2026-06-25 | T-2501 | `claude-fw --worktree` sessions silently unsupervised; auto-restart never arms | the `--worktree` launch path strips `FW_CLAUDE_FW_SUPERVISED` despite `bin/claude-fw:33` exporting it unconditionally | T-2501 fix + T-2502 vendored-drift audit | **unknown** — fix committed (`T-2503` landed it); not re-driven live |
| 23 | 2026-06-27→07-01 | G-075 (filed as G-071, stranded) | operator paste of a handoff one-liner failed at `cd: No such file or directory`; 6 commits never reached origin | handoff command hard-coded `cd …/.claude/worktrees/livefire-t2389 && …` per §Copy-Pasteable Commands, which is worktree-**blind** — the branch is durable, the directory is not | CLAUDE.md §Copy-Pasteable Commands point 6 (`CLAUDE.md:726`); reviewer detector `detect_worktree_handoff_durability` (`lib/reviewer/static_scan.py:2528`, wired :2666); 15 tests | **no** for this instance (`concerns.yaml` G-075 `status: resolved`). Class recurred — row 44 |
| 24 | 2026-06-27→07-01 | G-076 (filed as G-072, stranded) | worktree `livefire-t2389` removed while its branch held 6 commits on no remote; nothing warned | worktree removal is a teardown path the T-1144 handover push guard does not cover; `WorktreeRemove` hook unconfigured | `fw worktree remove` guard, `lib/worktree.sh:506` + `_wt_unpushed_summary:448`; refuses unless some remote has every commit; `--force` logs Tier-2 (`:622`); `tests/unit/t2825_worktree_remove.bats` | **partially** — guard verified present and fails-closed on undecidable input (`lib/worktree.sh:469-472`). It covers `fw worktree remove` only; bare `git worktree remove` and harness reaping are untouched. See §2 |
| 25 | 2026-07-01 | G-074 (filed as G-083, stranded) | no detector for MAIN↔worktree stranded divergence | `.git/info/exclude` keeps `git status` clean and `fw doctor`'s `diverged-fork` watches only the *session's* branch, never siblings | **nothing** — GO recorded 2026-08-06 (T-2822 slice 2), not built | **YES** — verified live: `fw_branch_hygiene` reports the two stranded worktree branches only as `behind-threshold` (49 days), never as ahead/unlanded; `do_worktree_doctor_line` (`lib/worktree.sh:140-146`) returns 1 unless run *from inside* a worktree. `concerns.yaml` G-074 `status: watching`, "PREVENTION NOT YET SHIPPED" |
| 26 | 2026-07-01 | T-2505 / T-2506 (stranded) | an inception answering *this same question* was filed at operator request and lost | authored inside a worktree; the tree never landed; the commits are `54adb1fcf` / `f59472365` on `worktree-inception-gov-payload-mediation` | recovered 2026-08-06 as `docs/reports/T-2822-prior-art-stranded-worktree-usage-policy.md` (T-2824) | **strand still live** — verified: `git rev-list --count origin/master..worktree-inception-gov-payload-mediation` = **6**, last commit 2026-07-01, worktree still on disk today (50 days) |
| 27 | 2026-07-01 | (same strand) | `worktree-rca-worktree-push-strand` holds 37 unlanded commits | same | T-2824 declined the source (superseded by newer master versions); commits left in place | **YES** — `git rev-list --count origin/master..worktree-rca-worktree-push-strand` = **37**, last commit 2026-07-01. `git log … --not --remotes` = 1 commit on no remote at all |
| 28 | 2026-07-01 | (same strand) | task IDs `T-2505`, `T-2506`, `T-2428` and gaps `G-071`/`G-072`/`G-083` and learning `L-486` each name **two different things** depending on which tree you read | worktree-local allocators scan only their own checkout, compute a stale max, and mint duplicates | T-2824 re-minted (T-2825, G-074/075/076); T-100202 AC3 union-scans all worktree views + one keylock at the main checkout (`agents/task-create/create-task.sh:252,309-310`) | **no** for task IDs (`create-task.sh:252` union-scan verified live). **YES** for L-/G-: `concerns.yaml` still has a *second* `G-083` (line 2997, 2026-08-16, unrelated); master's `L-486` is T-2437's, and the strand's `L-486` was never recovered — see §4 |
| 29 | 2026-07-05 | T-100194 / L-497 | operator's go-live merge produced 100+ conflicts and a broken mid-merge state | host branch and origin/master genuinely forked — 198 vs 287 commits from merge-base — because sessions committed real work straight to the branch and never landed it | T-100195 `diverged-fork` detector (`lib/branch-hygiene.sh:115`); T-100196 session-on-master flow | **YES** — verified live: `diverged-fork t2417-fw-sessions ahead=58 behind=1728`. The fork is *detected* and unreconciled 46 days later |
| 30 | 2026-07-05 | L-497 (recursive) | the branch-hygiene rail was itself stranded on origin/master and never ran on the branch it policed | a detector that lives only on the trunk cannot police a branch that never merges the trunk | rescued onto master via T-100199 (L-497 `context:` field records "original L-489 stranded on t2416") | **no** for the rail; the *shape* is the same one that produced rows 25-28 |
| 31 | 2026-07-05 | T-100199 | 28 local + 4 remote merged branches and an arc012 worktree as debris | no hygiene process at all | audit + cleanup executed (commit `4784e4211`) | **yes** (class) — 15 branches stranded again by 2026-08-19, row 48 |
| 32 | 2026-07-05 | OBS-095 | strand census claimed 4 tasks "proven DONE and live on origin/master per session memory" — one disproven on inspection | session memory records branch-local truth as global truth; no content verification | none — `status: dismissed` | **unknown** — `inbox.yaml` OBS-095 `promoted_to: None`. The remaining three (T-2335, T-2171, T-2390) are recorded as unverified and no follow-up verification exists in the corpus |
| 33 | 2026-07-05 | T-100202 / L-506 | task IDs jumped to the T-100xxx band; worktrees minting duplicates | ID allocator is global `max_id+1` over the *local* checkout; three composable legs (no plausibility bound, split filesystem views, self-feeding emitters) | union-scan across all worktree views + allocation keylock anchored at the main checkout; recursion gate (commit `ba9e56826`) | **no** — `create-task.sh:252` union-scan and `:309-310` main-worktree lock verified live. L-506 warns the same shape is unfixed for `L-/P-/D-/FP-` ids — row 28 confirms that warning was correct |
| 34 | 2026-07-05 | T-100201 / OBS-090(concern) | CLAUDE.md §Trunk-Based Session Flow contradicts the live T-2394 master-merge-only gate; operator hit `BLOCKED: direct commit on 'master'` | two policies both live: "session commits on master" vs `PROTECT_MASTER=1` merge-only guard | interim `⚠ KNOWN CONFLICT` note in `CLAUDE.md:1156`; mechanism reconciliation deferred | **YES** — `.framework.yaml:15` `PROTECT_MASTER: 1`; `T-100201` `status: started-work` (unresolved, 46 days); and the session is on `t2539-staging`, not master, right now |
| 35 | 2026-08-05 | OBS-169 / T-2812 | `fw git install-hooks` printed "Hooks Installed" and exit 0 while every hook write failed | `hooks.sh:53` writes to a hard-coded `PROJECT_ROOT/.git/hooks/`; wrong for a project inside another repo, **and wrong for worktrees and submodules** | resolve via `git rev-parse --git-path hooks` (commit `176445c64`) | **no** — commit landed. This is row 18's class recurring 43 days after the shared resolver shipped, at a surface T-2465 never swept |
| 36 | 2026-08-06 | T-2821 / OBS-175 | fresh project: background agent deadlocks; harness demands `EnterWorktree`, worktree has nothing in it | **`git worktree add` on an unborn HEAD returns RC=0**, prints "inferring --orphan", and silently yields a worktree containing only `.git`. A git-level false green (verified live, git 2.43.0) | `fw init` bootstrap commit so HEAD resolves; `tests/unit/init_head_bootstrap.bats` | **no** for orphan-inference; superseded by row 38's mechanism |
| 37 | 2026-08-06 | OBS-174 | 3 live worktrees hold 43 unlanded commits, dormant 5 weeks, invisible to every surface | `.git/info/exclude` + `diverged-fork` watching only the session branch (= G-074, row 25) | triage/recovery task T-2824 | **YES** — 2 of the 3 still present on disk with 6 + 37 unlanded commits; dormant **50 days** as of mining date |
| 38 | 2026-08-06 | OBS-178 / T-2827 | after T-2821, `git worktree add` *still* yields an empty worktree | T-2821's `--allow-empty` bootstrap commit has an **empty tree**, so checkout produces nothing. Same symptom, different mechanism. "T-2821's unit tests assert HEAD resolvability, which is why they are green on a state that still fails the real use" | bootstrap commits the scaffolding `fw init` created, and runs last (commit `5199f6ade`) | **no** — commit `1cb8d515f` records CONFIRMED on published bytes: worktree went from 1 entry to 9 |
| 39 | 2026-08-06 | OBS-177 / T-2829 | `fw worktree remove t100199-close` refused with "31 commits not on any remote" while the branch was fully landed | the G-076 guard compared only against the **same-named** remote branch; under FF-landing to master that ref is stale/absent. "The message's own claim … is false; the check never consults any remote but one" | predicate widened to any-remote reachability + fails-closed on unresolvable refs (`lib/worktree.sh:448-472`) | **no** — `_wt_unpushed_summary` verified live at `lib/worktree.sh:448`; `:469-472` documents the near-regression it avoided |
| 40 | 2026-08-06 | OBS-179 / T-2831 | after the OBS-177 fix, removal *still* refused — now on git's own dirty check, 17 modified `.context/` files | **OBS-179's stated mechanism was falsified by T-2831**: the dirt was not main-session hook noise; mtimes were 2026-07-06, written by the session that worked *inside* the worktree and never committed | `fw worktree remove` classifies dirt: content-register (`:556`) vs regenerable machine-local (`:567`), and names what it would destroy | **no** for the opacity. The underlying condition (worktree holds an independently-mutated fork of governance state) is row 41's root cause and is unfixed |
| 41 | 2026-08-06 | T-2822 (F1) | *the root cause, named* | **governance state is tracked content, so a worktree is by construction a fork of it, diverging the moment either side writes** (2812 `.tasks/` + 4582 `.context/` tracked files; only `.budget-status` gitignored) | GO recorded: source-only, enforced at the **write** layer. Four slices specified | **YES — none of the four slices shipped.** Verified: (1) no worktree write-refusal among the 25 registered hooks in `.claude/settings.json`; (2) `do_worktree_doctor_line` only fires from inside a worktree (`lib/worktree.sh:140-146`); (3) no `worktree`/`bgIsolation` key in `.claude/settings.json`; (4) `fw_reanchor_from_cwd` audit — unknown |
| 42 | 2026-08-06 | T-2823 | operator's GO on T-2822 was written to disk but the **commit was refused** by the G-052 duplicate-task-ID gate | the duplicate IDs the gate tripped on are the worktree-minted ones from row 28 — a worktree-caused fork blocking the decision about worktrees | T-2823 (unblock) | **no** for the instance; recurred as row 45 |
| 43 | 2026-08-06 | OBS-176 | a TermLink worker passed the close gate then died before committing; the whole deliverable sat uncommitted with the task in `completed/` | the close gate runs verification, not git state; and `update-task.sh` has no `work-completed → issues` transition, so the task cannot be reopened | none recorded | **unknown** — `inbox.yaml` OBS-176 `status: pending`, `promoted_to: None`. Adjacent (worker isolation), not strictly worktree |
| 44 | 2026-08-07 | T-2861 | in a background session, `Write` is refused until `EnterWorktree` — so an inception's **first** act (C-001 artifact) hits the guard | Claude Code's `worktree.bgIsolation` default; `fw init` never writes the key. "Accepting the guard's advice is actively wrong for an AEF consumer" — the worktree forks governance state (row 41) | **nothing** | **YES** — `.claude/settings.json` has no `worktree`/`bgIsolation` key (verified); `T-2861` `status: captured`, never started, 13 days |
| 45 | 2026-08-07 | L-549 / T-2850 | greenfield suite reported "Untracked task files" — a plausible wrong answer, not an error | a stray `fw init` made `/tmp` a git repo, so every fixture under it inherited that worktree and `fw init` skipped `git init` | precondition assertion in the integration suite | **unknown** — L-549 is recorded; whether the assertion shipped was not verified in this pass |
| 46 | 2026-08-08 | T-2864 | operator's GO on T-2863 written to disk, commit refused: same G-052 duplicate-task-ID block | recurrence of row 42, two days later, same gate, same underlying ID fork | T-2864 (unblock) | **no** for the instance. Two occurrences of the identical shape is the signal |
| 47 | 2026-08-14 | T-2993 | a worktree-isolated session was refused `git -C <sibling> status`, believed the refusal, and deferred real hygiene work out of the session that had the context | **the guard is the harness's, not ours** (absent from all source; wrong error shape; `EnterWorktree`/`ExitWorktree` are built-ins). Three findings: refusal is a dead end; teardown-from-inside is a recurring class patched only as instances; **the corpus has no worktree map** | inception only | **YES** — verified live: 8 canonical maps under `.context/designer/projects/aef-*`, occurrences of "worktree" across them = **0**. Also: the blocked command (`git status --short`) was itself a false green — it cannot see unpushed commits |
| 48 | 2026-08-14 | OBS-248 | a consumer vendored *correctly* and still received month-old defects | framework work accumulates on a staging branch never landed; `FW_BRANCH_BEHIND_WARN` watches branches BEHIND master, nothing watches consumer-facing commits AHEAD of it | none | **YES** — `inbox.yaml` OBS-248 `status: pending`; and this session is on `t2539-staging` at HEAD `7e1cecbbc`, the same condition |
| 49 | 2026-08-16 | G-083 (new) / T-3030 | a dispatched worker edited a governance gate, created a bats suite, and deleted 4 tracked handovers **in the live checkout**, concurrent with the interactive session | resolver-loop worker runs with `WorkingDirectory` pinned to the MAIN checkout; the only separator is a single-slot `focus.yaml` that the completion path itself nulls. "Dispatched workers are the one class of writer that bypasses [the worktree primitive]" | T-3030 **chose the dispatch-id record over the worktree** — `lib/spawn.py` `_git_state`/`_writes_between`; `tests/unit/t3030_two_writer_guard.bats` (11 tests) | **YES** for write isolation — `concerns.yaml` G-083 `status: watching`, `what_remains`: "Not fixed — registered". Provenance shipped; isolation did not |
| 50 | 2026-08-18 | OBS-326 | `workflow_sha` in `dispatches.jsonl` attests content that never executed | `lib/resolver.py:455` `git rev-parse HEAD:<path>` succeeds for any tracked file **regardless of worktree modification**; the mtime fallback (:475) only fires for untracked paths | none | **YES** — `inbox.yaml` OBS-326 `status: pending`. Matters because that ledger is the join for CLAUDE.md's own dispatch outcome table |
| 51 | 2026-08-19 | OBS-331 / T-3092 | scan reported `t2416` as `merged-undeleted` (deletable) while `origin/t2416` held **202 unlanded commits** | `fw_branch_hygiene` classified remote refs only as `remote-contained`; a remote ref carrying unlanded commits matched no arm and was silently omitted | `remote-unlanded` class added, `lib/branch-hygiene.sh:142-175` | **no** — verified live: scan now emits `remote-unlanded origin/t2416-fw-safe-mode-hook-timing ahead=204` |
| 52 | 2026-08-19 | T-3091 | 15 branches stranded, carrying content absent from master | **FF-only landing + master advancing past the fork point.** "The moment master passes a branch's fork point, the branch becomes unlandable by the only sanctioned route" (`docs/reports/T-3091-branch-manifest.md:12-16`) | salvage manifest + `strand-backup/*` tags for the 4 dead refs | **YES** — the two worktree strands are rows 26-27 in that manifest, both **KEEP — carries absent content**, both still unlanded today |

**Distinct incidents: 52** (row 1 is the baseline decision, not a defect; rows 2 and 19-20 are remedies recorded inside the incident chain). Defect incidents: **48**.

---

## 2. Fix ledger

The question for each shipped fix: did it PREVENT recurrence (nothing of that shape recorded
after it), or only DETECT it? Ordered by how badly the answer diverges from the intent.

### 2.1 Fixes that shipped and PREVENTED the instance but NOT the class

**Transcript-dir reconstruction (rows 3-6, 9, 11).** Five successive fixes over four days.

| fix | date | what it prevented | what recurred, and when |
|---|---|---|---|
| T-2375 — `fw_claude_project_dir_name()` | 06-13 | the dot-encoding leg in the budget gauge | T-2380 the **same day**: `fw costs`, `discard-manifest.sh`, `read-transcript.py` kept the old sanitizer |
| T-2377 — prefer stdin `transcript_path` | 06-13 | gauge blindness on the hook path | T-2392 **next day**: reconstruction fallback still wrong, because CC keys on launch cwd |
| T-2380 — migrate 3 call sites | 06-13 | those three sites' name encoding | T-2392, T-2400: the *base path* was still wrong at those same sites |
| T-2392 — `fw_claude_project_dirs()` union | 06-14 | gauge + session-metrics | T-2400 the **same day** (3 unswept sites), T-2425 three days later |
| T-2425 — costs.sh union leg | 06-16 | the last known site | nothing recorded since — 65 days |

Verdict: **PREVENT, five attempts deep.** L-483 states the failure mode in the record itself:
*"T-2375 created the helper + migrated the budget gauge but never swept the corpus."* Each fix
was correct and each was incomplete. The class is now quiet, but the corpus contains no evidence
that a *sweep* was ever proven exhaustive — only that no sixth instance was reported.

**Hook root resolution (rows 17, 19, 20).** `fw_reanchor_from_cwd` (`lib/paths.sh:110`) +
`lib/hook_paths.py:30` were built explicitly to end the whack-a-mole T-2464 tabulated at 7 tasks.

Verdict: **PREVENT within the swept surface; the class recurred outside it.**
Recurrence proof: **T-2812 / OBS-169, 2026-08-05 — 43 days after the shared resolver shipped.**
`hooks.sh:53` wrote to a hard-coded `PROJECT_ROOT/.git/hooks/`; the fix was
`git rev-parse --git-path hooks`, "correct for worktrees and submodules too" (OBS-169 text).
That is the same generating mechanism — a path assumed rather than asked for — at a surface
`fw_reanchor_from_cwd` does not cover, because it re-anchors `PROJECT_ROOT` and this code was
deriving a *git* dir, not a project root. T-2464's own recommendation ("run the *whole* hook
suite under a simulated worktree invocation … the bug lives at the join") was not extended to
non-hook git-path derivations.

### 2.2 Fixes that shipped and only DETECT

**T-100195 `diverged-fork` (row 29).** Detection works — verified live:
`diverged-fork t2417-fw-sessions ahead=58 behind=1728 (threshold 50)`.

Verdict: **DETECT ONLY, and the corpus says so explicitly.**
`docs/reports/T-3091-branch-manifest.md:17-19`, written 2026-08-19:

> `lib/branch-hygiene.sh` does detect this — it reports seven of these right now as
> `behind-threshold` / `diverged-fork`, at 1400–7100 commits over a threshold of 50.
> **Detection has never been the missing piece. Nothing consumes the finding.**

Post-fix recurrence proving non-prevention: **T-3091 itself (15 stranded branches, 2026-08-19)**,
45 days after the detector shipped, and the fork it detects on `t2417-fw-sessions` is 46 days old
and unreconciled.

**`fw worktree remove` guard, G-076 (row 24).** Refuses teardown when no remote holds every
commit; fails closed on undecidable input (`lib/worktree.sh:469-472`); `--force` logs Tier-2.

Verdict: **PREVENT on the sanctioned path; NO COVERAGE elsewhere.** The guard is a wrapper
around `fw worktree remove`. It cannot fire on bare `git worktree remove`, on harness reaping,
or on session-exit cleanup — the three paths G-076's own description names
(`concerns.yaml`: *"a worktree can be `git worktree remove`'d, or reaped on session exit"*;
*"The WorktreeRemove hook is unconfigured"*). The `WorktreeRemove` hook remains unconfigured:
it is absent from the 25 hooks registered in `.claude/settings.json`.

Sharper: the guard was *live-proven against the two stranded worktrees* (`concerns.yaml` G-076
resolution text) — and **those two worktrees are still on disk today with 6 and 37 unlanded
commits, dormant 50 days.** The guard correctly refuses to remove them. Nothing lands them.
Refusing to destroy stranded work is not the same as recovering it.

**G-075 handoff durability (row 23).** CLAUDE.md clause + reviewer detector.

Verdict: **PREVENT for the literal `cd …/worktrees/… && push` shape; the class recurred.**
Post-fix recurrence: **T-2993, 2026-08-14.** Its report names the recurrence directly
(`docs/reports/T-2993-worktree-isolation-guard.md`, "The actual gap", item 2):

> Three instances, three separate paragraphs, no shared statement. The general form is one
> sentence: **operations on the set of worktrees belong to the main checkout; operations
> within one worktree belong to that worktree.**

The three instances it lists are §Trunk-Based Session Flow's "never run integrate from inside
the worktree it will remove", G-075/T-2825's handoff rule, and T-2993's own incident. The
reviewer detector matches a command *string shape*; it cannot match the principle.

Also note: the detector's severity is `heuristic/partial → CONCERN` (`static_scan.py:2547`) —
advisory, non-blocking.

### 2.3 The GO that shipped nothing

**T-2822, row 41** — the inception that named the root cause. GO recorded 2026-08-06 with four
dependency-ordered slices. Verified live at HEAD `7e1cecbbc`, 14 days later:

| slice | intent | shipped? | how checked |
|---|---|---|---|
| 1 — detection + write refusal into `.context/`/`.tasks/` from a linked worktree | prevent new forks | **NO** | no worktree write-refusal among the 25 `fw hook <name>` entries in `.claude/settings.json`; no `worktree` string in any hook |
| 2 — `fw doctor` reports sibling worktrees with unlanded counts + age | surface existing forks (closes G-074) | **NO** | `do_worktree_doctor_line` (`lib/worktree.sh:140-146`) returns 1 unless `git-dir != git-common-dir` — i.e. it only speaks when run *from inside* a worktree, which is exactly the case that does not need it. `fw_branch_hygiene` emits `worktree-merged` only for *merged* worktrees; the two stranded ones get no worktree class at all |
| 3 — turn off ambient isolation explicitly | make worktree creation a decision | **NO** | no `worktree`/`bgIsolation` key in `.claude/settings.json`; T-2861 `status: captured` |
| 4 — audit the shared-state code | — | **unknown** | no task found scoping it |

Consequence, measured rather than inferred: **G-074 is still `status: watching` with
`what_remains: "PREVENTION NOT YET SHIPPED"`**, and the condition it describes was reproduced
live in this mining pass (rows 25-27, 37).

Since the GO, the corpus recorded three further incidents of the same mechanism — rows 44
(T-2861, ambient isolation, the slice-3 subject), 47 (T-2993, sibling-worktree operations), and
49 (T-3030, two writers in one checkout). None is a *counter*-example to the GO; all three are
what slice 1-3 were specified to prevent.

### 2.4 Fixes that PREVENTED cleanly (nothing of that shape recorded after)

| fix | date | evidence of prevention |
|---|---|---|
| T-2437 / L-486 — CONTENT vs HOST-ENVIRONMENT audit classification | 06-18 | three `fw_is_linked_worktree` guards live at `agents/audit/audit.sh:1836,1906,1991`; no worktree-audit false-FAIL recorded in the 63 days since |
| T-100202 AC3 — union-scan + main-checkout keylock for task IDs | 07-21 | `create-task.sh:252` (union across `git worktree list`), `:309-310` (lock at main worktree). No duplicate-*task*-ID incident after 2026-08-08 (row 46). **But** L-506 warned the `L-/G-/P-/D-` allocators share the shape and were not fixed — and row 28 confirms both a duplicate `G-083` and a duplicate `L-486` persist |
| T-2827 — bootstrap commits real scaffolding | 08-06 | commit `1cb8d515f` records the fix CONFIRMED **on published bytes** from a fresh clone of the public mirror (1 entry → 9). Strongest verification in the corpus |
| T-2829 + T-2831 — worktree-remove predicate + dirt classification | 08-06 | `lib/worktree.sh:448-472,556,567`. The chain took three tasks (OBS-177 → OBS-179 → T-2831) and the second falsified the first's stated mechanism |
| T-3092 — `remote-unlanded` class | 08-19 | verified live in scan output: `remote-unlanded origin/t2416-fw-safe-mode-hook-timing ahead=204` |

### 2.5 One fix that made the next failure possible

**T-2821 (row 36) → OBS-178 (row 38).** T-2821 gave `fw init` a resolvable HEAD via an
`--allow-empty` bootstrap commit, and its unit tests asserted HEAD resolvability. OBS-178:

> T-2821 **moved** the empty-worktree deadlock, it did not remove it. … T-2821's unit tests
> assert HEAD resolvability, which is why they are green on a state that still fails the
> real use.

Same user-visible failure, different mechanism (empty-tree checkout vs orphan inference), and
the test suite could not tell the difference. Detected only because T-2826 re-drove the whole
onboarding path live against published bytes.

### 2.6 Aggregate

Of 48 defect incidents: **~20 have a fix verified present in the tree today**;
**~13 are verified still live** (rows 8-class, 25, 26, 27, 28-partial, 29, 34, 37, 41, 44, 47,
48, 49, 50, 52); **~9 are `unknown`** (rows 7, 14, 15, 21, 22, 32, 43, 45, and slice 4 of 41).

The two largest fixes by intent — T-2464's systemic resolution arc and T-2822's source-only GO —
have opposite ledgers. T-2464 shipped its mechanism and the class recurred once, at an unswept
surface, 43 days later. T-2822 named the mechanism precisely and shipped none of it.

---

## 3. Mechanism clusters

Grouped by **generating mechanism**, not symptom. Where two incidents look alike but are
generated differently, that is stated.

### M1 — Governance state is tracked content, so a worktree is a *fork* of it
`T-2822` F1 (`docs/reports/T-2822-worktree-policy.md`, S2): 2812 tracked files under `.tasks/`,
4582 under `.context/`; only `.budget-status` gitignored. `focus.yaml` measured as already
differing between trees moments after creation.
**Members:** rows 25, 26, 27, 28, 37, 40, 41, 42, 46. Plus row 49 as its inverse (see M10).
**Note:** this is the only mechanism in the corpus that is *named as a root cause* rather than
described per-symptom, and it was named 4 months after the first incident.

### M2 — Project-root resolution: the consumer asks the wrong process for its location
Hooks are wired by main's absolute path; `bin/fw` resolves `PROJECT_ROOT` from the hook process
cwd. "The two never meet — the gate and the work operate on different roots" (`T-2464` report).
**Members:** rows 17, 19, 20, 35.
**Explicitly NOT M2:** row 7 (T-2390). Its task file marks the cwd-walking hypothesis
**SUPERSEDED** — the real mechanism was a stale `PROJECT_ROOT=/root` inherited from the tmux
daemon env. Identical symptom (hook reads wrong root, gauge blind), different generator.
T-2822's S1a classification table lumps T-2390 into "Root resolution"; the task file disagrees
with the classification. Flagged rather than silently corrected.

### M2b — Environment inheritance poisoning
A long-lived daemon exports `PROJECT_ROOT`/`CLAUDE_PROJECT_DIR`; every child inherits a root
that has nothing to do with its cwd.
**Members:** rows 7, 15, 22.
Distinguished from M2 because the fix shape is opposite: M2 says *derive from cwd*, M2b says
*distrust what you were handed*. `T-2446` had to disprove the M2 framing to find M2b.

### M3 — Derived-path reconstruction from a project-directory name
Two sub-mechanisms, repeatedly conflated in the record:
- **M3a — name encoding.** Slash-only sanitizer vs Claude Code's full non-alnum→dash. Fails only
  on dotted paths, i.e. only in worktrees. Rows 3, 5.
- **M3b — keying base.** Claude Code keys the projects dir on **launch cwd**, so even a perfectly
  encoded, correctly-anchored worktree lookup finds nothing. Rows 4, 6, 9, 11.
Fixing M3a (T-2375) left M3b entirely intact, which is why T-2392's commit `6f3ca8aee` is titled
"**corrected RCA**". Five fixes in this cluster; the first three targeted the wrong sub-mechanism
or an incomplete site list.

### M4 — Content vs host-environment confusion in audit gates
A worktree legitimately lacks host-installed state (cron at `/etc/cron.d/` under the MAIN slug);
a check that cannot tell "committed drift" from "expected host absence" false-FAILs.
**Members:** rows 12, 13. Codified as L-486 (master's).

### M5 — Lifetime confusion: the worktree is ephemeral, the branch is durable
Anything that binds an outcome to the worktree *directory* loses it on teardown.
**Members:** rows 23, 24, 47.
T-2993 is the incident that named the general form: *operations on the set of worktrees belong
to the main checkout; operations within one worktree belong to that worktree.* Its three cited
instances (integrate-from-inside, handoff-cwd, sibling-inspection) had three separate CLAUDE.md
paragraphs and no shared statement.

### M6 — FF-only landing plus a trunk that advances past the fork point
The sanctioned route (`fw integrate run master --push`) is fast-forward-only; a FF requires
descent from master. Once master passes the fork point the branch is unlandable by the only
sanctioned route, and nothing rebases it forward or escalates.
**Members:** rows 8, 29, 30, 31, 32, 48, 52. Verbatim mechanism at
`docs/reports/T-3091-branch-manifest.md:12-16`.
**Distinct from M5:** nothing is torn down here. In M5 the container disappears; in M6 the
container is fine and the *route out* closes. Rows 26-27 sit in **both** — a worktree strand
that is also an unlandable fork — which is why they survived two separate remediations.

### M7 — Creation precondition: `git worktree add` succeeds and produces nothing
RC=0 on an unborn HEAD (orphan inference) or on an empty-tree HEAD. A git-level false green;
no AEF hardening removes it, only a preflight.
**Members:** rows 36, 38. Two mechanisms, one symptom — stated as such in OBS-178.

### M8 — Harness-owned worktree policy AEF never chose
`.claude/settings.json` has no `worktree` key (verified). Ambient background-session isolation
and the cross-worktree git guard are Claude Code built-ins (`EnterWorktree`/`ExitWorktree`).
T-2993's three-line proof that the guard is not ours: absent from all source; wrong error shape
(bare `Error:` with no `PreToolUse:<Tool> hook error:` prefix and no `Policy: P-XXX` suffix);
harness owns the primitive.
**Members:** rows 44, 47; T-2822 F4.

### M9 — A predicate narrower than the guarantee its message claims
The check asks one question; the message asserts a broader one; an empty result is read as
"safe".
**Members:** row 39 (`origin/<branch>..` reported as "not on **any** remote"), row 51
(remote refs classified only as deletable, unlanded ones silently omitted), and the near-miss
documented inside the row-39 fix (`lib/worktree.sh:458-468` — an empty `rev-list` that would
have meant "safe to remove" for two different reasons).
**Also here, unfixed:** T-2822 slice 2's absence means `fw_branch_hygiene` reports the two
stranded worktree branches as `behind-threshold` only — never as *ahead*. An operator reads
"behind" as landable lag; 37 unlanded commits are not lag.

### M10 — Two writers, one checkout (isolation absent, not broken)
**Members:** rows 49, 50, 43.
The inverse of M1: M1 is "worktrees fork state that should be shared"; M10 is "workers share a
tree that should be forked". Both are failures of the *same* missing decision — which checkout
owns which writes. G-083's own framing: worktrees are "the worktree primitive that exists and
that dispatched workers are the one writer class not using".

### M11 — Test/fixture environment silently inherits an enclosing worktree
**Members:** rows 45, 14.
L-549's point is the severity ordering: *"contamination that disguises itself as a finding is
worse than contamination that crashes"* — the greenfield suite reported a plausible day-zero
defect that was actually a stray `fw init` in `/tmp`.

### M12 — Two live policies that contradict each other
**Members:** row 34 (T-100196 session-on-master vs T-2394 `PROTECT_MASTER=1`), and T-2822's own
framing of the corpus: *"Two contradictory premises are live in the codebase at once … Each is
coherent alone. Holding both produces defects at the joins, which is the shape of the incident
record."*
This is the only cluster whose members are not defects but *rules*. It is included because
T-2822 identifies it as the generator of the join defects in M1 and M4.

**Distinct mechanisms found: 12** (14 counting M2/M2b and M3a/M3b as separate, which the fix
history argues for — each pair required a separate fix and one member of each pair had its
first RCA formally corrected).

---

## 4. What the corpus does NOT contain

### 4.1 Incidents referenced in prose with no register entry

- **Vendored `+x` loss (row 21).** `docs/reports/T-2464-worktree-reliability-rca.md` lists it
  under Problem 2 and annotates it verbatim `(observed, unfiled)`. No OBS, no G, no task scoped
  to it; T-2467 folded it into a slice. There is no record of the symptom, only of a remedy.
- **The strand's `L-486`.** Commit `ec56fe61e` (2026-07-01, in the stranded worktree) registers
  a learning `L-486`: *"push before teardown; outlives-session handoff commands use durable
  main-repo path + branch ref."* Master's `L-486` is a **different** learning (T-2437, 2026-06-18,
  content-vs-host-environment). T-2824's recovery table lists 11 artefacts and **does not include
  L-486**. Searched master for the content (`teardown|outlives-session|durable main-repo`): 2
  hits, neither is it. The learning exists as CLAUDE.md rule 6 and as G-075's closure criterion —
  but **not as a learning entry**, so `fw learnings` and any learning-driven surface cannot see it.
- **The three unverified strand-census claims.** OBS-095 names T-2335, T-2171 and T-2390 as
  "landed per session memory, not content-verified", `status: dismissed`, `promoted_to: None`.
  No follow-up verification exists for any of the three.
- **OBS-083's triage question.** *"Confirm whether it reproduces on a non-worktree master
  checkout"* — asked 2026-06-21, `status: dismissed`, never answered anywhere in the corpus.

### 4.2 Records that exist but are destroyed or ambiguous

- **OBS-077's text is gone.** `.context/inbox.yaml` OBS-077 reads, in full:
  `[T-2867 LOST NOTE] the captured text was the bare sub-verb "add" — the real observation was
  silently discarded by fw note before the T-2867 guard. Unrecoverable: it was never written
  anywhere.` OBS-077 is the cited origin of L-486 and T-2435/T-2437 (rows 12-13). The mechanism
  survives in the learning; the observation does not. **OBS-087 is identically destroyed.**
- **`OBS-080` names two different things.** `.context/inbox.yaml` OBS-080 is a *fabric-drift
  false-positive* (2026-06-20, T-2440). But T-2463 cites `OBS-080` as
  `"(reads wrong focus.yaml) — OBS-080"`, and T-2465/T-2478/T-2494 all cite OBS-080 as the
  worktree root-resolution observation. Two observations, one ID — the row-28 split-view
  collision reaching the OBS namespace. Neither entry references the other.
- **`G-083` names two different gaps.** `concerns.yaml:2997` is the 2026-08-16 dispatch
  two-writer gap (row 49). The 2026-07-01 stranded G-083 was MAIN↔worktree divergence blindness,
  re-minted as G-074 precisely because *"worktree-allocated IDs are not authoritative"*
  (`concerns.yaml` G-074). The ID was then **re-issued** to an unrelated gap six weeks later.
  Anyone reading a pre-2026-08-06 document that cites G-083 will land on the wrong entry.
- **`OBS-090` is filed as a concern.** `concerns.yaml:2285` carries `id: OBS-090` in the gap
  register — an OBS-prefixed id in the G- namespace. It is the T-100194 merge-back fork gap
  (row 29 class), `status: open`, and it will not be found by anyone grepping `concerns.yaml`
  for `G-`.
- **Two incident task files have an empty `## Context`.** T-2829 (row 39) and T-2861 (row 44).
  For T-2861 the entire mechanism lives in the YAML `description:` field; for T-2829 it lives
  only in OBS-177 and the commit message.

### 4.3 Date ranges with suspicious silence

- **2026-04-26 → 2026-06-13 (48 days, zero incidents).** D-026 shipped WorktreePool on
  2026-04-25 and reviewer Pass B ran audits in worktree isolation from 2026-04-26. Either
  worktree use was confined to that one automated path (plausible — D-026 is audit-specific), or
  incidents occurred and were not recorded. The corpus cannot distinguish these.
- **2026-06-25 → 2026-08-05 (41 days, three incidents — all invisible at the time).** G-071,
  G-072 and G-083 were filed 2026-07-01 **inside the stranded worktree** and were not on master
  until T-2824 recovered them on 2026-08-06. The register was not silent; it was unreadable. This
  is the single strongest datum in the corpus: *the gap about invisible worktree divergence was
  itself invisible for five weeks* (`concerns.yaml` G-074).
- **2026-07-06 → 2026-08-05 on master.** After T-100202 (07-05/07-21), no worktree incident is
  recorded until T-2812 on 08-05. The two stranded worktrees were accruing nothing (last commit
  2026-07-01) but were also entirely unobserved — OBS-174 did not file them until 2026-08-06,
  and only because T-2822's S1 grepped for callers.

### 4.4 Sources that turned out empty or near-empty

| source | result |
|---|---|
| `.context/observations/` | one file, `pickup-051-vinix24-20260330.md` — unrelated to worktrees |
| `.context/inbox/` | empty except a `processed/` subdirectory |
| canonical designer corpus (`.context/designer/projects/aef-*`) | **8 maps, zero occurrences of "worktree"** — T-2993's load-bearing finding, re-verified here. The one lifecycle every code change must traverse is the one lifecycle the corpus does not model |
| `write_set:` task frontmatter | **0 of 3086 task files.** `fw write-set check` therefore returns `undecidable` for every real pair, which is why M10 (two writers) has no declared-conflict record to mine |
| `.context/dispatches.jsonl` / `dispatch-outcomes.jsonl` | not mined — 3.0 MB / 858 KB, and no worktree field exists in the envelope schema per OBS-326. A per-dispatch record of *which checkout a worker ran in* does not exist |

### 4.5 What could not be verified in this pass

- `fw doctor` was run and **timed out at 240s** without producing output; the doctor-level
  worktree/branch findings in §1 were verified by calling `fw_branch_hygiene` from
  `lib/branch-hygiene.sh` directly (the same function `agents/audit/audit.sh:2023` and
  `bin/fw:2852` consume) and by reading `do_worktree_doctor_line` at `lib/worktree.sh:140-166`.
  End-to-end doctor output is therefore **unknown**.
- Rows 7, 15, 22 (env-inheritance and `claude-fw --worktree`) have fixes committed but were not
  re-driven live from a tmux/TermLink daemon; marked `unknown` rather than `no`.
- T-2993's central inference — that `fw worktree gc` survives the harness guard because the
  guard reads command text and cannot see into a script — is flagged by its own author as
  *"a strong structural inference, not a measurement … not executed from inside an isolated
  worktree session"* (`docs/reports/T-2993-worktree-isolation-guard.md`, Spike 3). It remains
  unmeasured.
- Row 45 (L-549 precondition assertion) — the learning is recorded; whether the assertion
  shipped into the integration suite was not checked.

---

## Appendix — live state at mining time

Verified 2026-08-20, main checkout, HEAD `7e1cecbbc`, branch `t2539-staging`:

```
$ git worktree list
/opt/999-Agentic-Engineering-Framework                              7e1cecbbc [t2539-staging]
…/.claude/worktrees/inception-gov-payload-mediation  f59472365 [worktree-inception-gov-payload-mediation]
…/.claude/worktrees/rca-worktree-push-strand         ec56fe61e [worktree-rca-worktree-push-strand]
…/.claude/worktrees/t100196-vendor-fix               d95b5f150 [t100196-vendor-fix]
…/.claude/worktrees/t100199-close                    cb008320d [t100199-close]

branch                                     unlanded-vs-origin/master   on-no-remote   last commit
worktree-inception-gov-payload-mediation                           6              3   2026-07-01
worktree-rca-worktree-push-strand                                 37              1   2026-07-01
t100196-vendor-fix                                                 0              0   2026-08-11
t100199-close                                                      0              0   2026-07-06

$ fw_branch_hygiene . origin/master     # excerpt
behind-threshold worktree-inception-gov-payload-mediation behind=1513 days=49 (threshold 50)
behind-threshold worktree-rca-worktree-push-strand        behind=1728 days=49 (threshold 50)
worktree-merged  …/.claude/worktrees/t100196-vendor-fix   branch=t100196-vendor-fix
worktree-merged  …/.claude/worktrees/t100199-close        branch=t100199-close
diverged-fork    t2417-fw-sessions ahead=58 behind=1728 days=48 (threshold 50)
remote-unlanded  origin/t2416-fw-safe-mode-hook-timing ahead=204
```

The two worktrees carrying unlanded work are the two the scan gives **no worktree class** to.
The two it does classify are the two that are clean.

`.claude/settings.json`: no `worktree` or `bgIsolation` key; 25 registered `fw hook` names, none
of which refuses writes from a linked worktree.
`.framework.yaml:15`: `PROTECT_MASTER: 1`.
Canonical designer maps: 8; occurrences of `worktree` across all of them: 0.
