# VALUE-REVIEW whole repo — Evidence D: code-governance surface (bin/, lib/, agents/, policy/)

- **Task:** T-3370 (GATHERER-D)
- **Date:** 2026-09-16
- **Scope:** `bin/` (9 files), `lib/` (140 top-level modules plus `reviewer/`, `ts/`, `migrations/`, `seeds/`, `templates/`), `agents/` (185 files), `policy/` (20 files). Out of scope: `web/`, `tests/` and `docs/`, except as places where references are found.
- **Nature:** facts only. No delete/refactor/add classification; that is the JUDGE's job.
- **Usage data:** **none exists per verb or per module in this repo.** Every row below has "no usage data exists". Zero references does not mean unused, and many references does not mean used.

## Method and how much to trust each column

| Column | How it was obtained | Limits |
|---|---|---|
| What it does | **B** = the function bodies were read (bin/, the `fw` verb arms, and `lib/*.sh`, by a read-only Explore reader). **H** = the header plus call sites were read (all other rows). | H rows can repeat a header claim that the body does not honour. Where a header claim was checked against call sites, the row says so. |
| refs total | `git grep -l -E '<filename-with-ext>'` over all tracked files, excluding the file itself. For `.py` files, `import`/`from <stem>` is also matched. For `AGENT.md`, the full path is matched. Untracked `.claude/settings*.json` is added. Script: `/tmp/gd/ev.py`. | **False zeros:** hooks are wired as `fw hook <name>` without `.sh`, so the "hook wiring" column is the authority for those. `lib/reviewer/*_cli.py` are called as `python3 -m lib.reviewer.<x>`, which the filename match misses. **Inflation:** `.agentic-framework/` (a tracked, vendored self-copy) and `docs/generated/`, `.fabric/` and `.context/` all count, and are broken out in "top ref locations". |
| refs in code | Subset of the matches in bin/, lib/, agents/, web/, policy/, .claude/ and the cron registry. | Same limits as above. |
| test files | Files under `tests/` matching the filename. For verbs, files under `tests/` containing `fw <verb>`. | Tests that call a function directly without naming the file are missed. |
| commits / first / last / origin | `git log --follow --format=%ad\|%s -- <path>`. The origin is the first `T-NNNN` in the adding commit's subject. | `--follow` can over-attribute across renames. |
| audit/doctor | Filename appears in `agents/audit/audit.sh` (= audit) and/or in `do_doctor`, `bin/fw:1429-2726` (= doctor). | This is only a name match. It does not show that the rail checks the item's health. |
| verb refs | `git grep -o -E '\bfw [a-z-]+'`, excluding `.agentic-framework/`. | `bin/fw <verb>` forms count; other invocation forms do not. |

**Churn for verbs:** verbs are case arms inside `bin/fw` (10,032 lines, 394 commits per `git log --follow -- bin/fw`). Per-verb churn was not extracted: UNVERIFIED (it would need `git log -L`).

---

## Section 1 — Inventory

### 1a. bin/ files and `fw` top-level verbs (B; 99 verb arms plus 9 files)

| item | location | what it actually does | tags |
|---|---|---|---|
| bin/claude-fw | bin/claude-fw | Wraps `claude`. Restarts on a restart signal, re-arms continuous runs, optional TermLink registration, startup banner. | CTX, XAGENT |
| bin/claude-fw-router | bin/claude-fw-router:36 | Walks up from cwd to the project's own claude-fw and execs it; otherwise runs plain `claude`. | INSTALL |
| bin/fw | bin/fw:5130 | Main CLI: about 10k lines, with the top-level `case` dispatch plus much inline logic. | ALL |
| bin/fw-router | bin/fw-router | PATH entry: finds the repo or vendored fw, refuses incomplete copies, curl-bootstraps on `init`, guards loops. | INSTALL |
| bin/fw-shim | bin/fw-shim:18 | Older project-detecting wrapper (T-664). **Same job as fw-router.** | INSTALL |
| bin/hook-enable.sh | bin/hook-enable.sh | Adds an `fw hook <name>` entry to `.claude/settings.json` idempotently; supports dry-run. | AUDIT, INSTALL |
| bin/integrate-go-live.sh | bin/integrate-go-live.sh:33 | Checks out lib/agents/bin from origin/master and commits. `REPO=/opt/999…` and `TASK_REF=T-2481` are hardcoded. | GIT |
| bin/migrate-horizon-null-completed.sh | :38 | One-off migration that sets `horizon:` to null in `.tasks/completed`. | TASK |
| bin/watchtower.sh | :473 | Watchtower start/stop/restart/status/port/url/current. | OPS |
| ask | bin/fw:5131 | lib/ask.sh, which calls lib/ask.py (retrieval plus Ollama LLM). | RECALL |
| audit | :5134 | agents/audit/audit.sh | AUDIT |
| reviewer | :5137 | `python -m lib.reviewer.{static_scan,audit,override_cli,drift_cli,reverify_cli,dispatch_cli}` | AUDIT, TASK |
| ux-review | :5218 | agents/ux-review/ux-review.py (headless browser capture) | AUDIT |
| self-audit | :5225 | agents/audit/self-audit.sh | AUDIT |
| gpu | :5228 | `recover` runs agents/gpu-recover/recover.sh; any other argument prints usage. | OPS |
| test-onboarding | :5252 | agents/onboarding-test/test-onboarding.sh | AUDIT, INSTALL |
| plugin-audit | :5255 | agents/audit/plugin-audit.sh | AUDIT |
| context | :5258 | agents/context/context.sh | CTX |
| focus | :5261 | Alias for `context.sh focus`. | CTX, TASK |
| arc | :5267 | lib/arc.sh `arc_dispatch` | TASK |
| bvp | :5275 | lib/bvp.sh `bvp_dispatch` | BVP |
| triage | :5284 | `route`: lib/message_router.py classifies the hub message archive and records dispositions only. | XAGENT |
| write-set | :5335 | lib/write_set.py: checks whether two tasks' write sets overlap. | XAGENT, TASK |
| worktree | :5403 | lib/worktree.sh status/create/gc/remove | GIT |
| integrate | :5494 | lib/integrate.py check/classify/run: pre-merge check plus merge-back with governance auto-resolve. | GIT |
| continuous | :5582 | lib/continuous-mode.sh `fw_continuous_cli` | XAGENT, OPS |
| cron | :5598 | Inline: generate/status/list/run/pause/resume/install from `.context/cron-registry.yaml`. | OPS |
| index | :5977 | `reindex`: inline Python calls `web.embeddings.reindex_incremental`. | RECALL |
| docs | :6027 | agents/docgen generate-article.sh or generate-component.sh | FAB |
| fabric | :6034 | agents/fabric/fabric.sh | FAB |
| designer | :6037 | agents/designer/designer.sh | DESIGNER |
| bpmn | :6041 | agents/bpmn/bpmn.sh, which calls tools/bpmn_to_tasks.py | DESIGNER, TASK |
| corpus | :6045 | tools/corpus_lint.py, corpus_explain.py, corpus_spec.py | DESIGNER |
| git | :6061 | agents/git/git.sh | GIT |
| sync | :6064 | Inline: fetch and pull --rebase from the origin dev branch, then push. | GIT |
| go-live | :6118 | lib/branch-hygiene.sh `fw_go_live` | GIT |
| push | :6137 | Inline: pushes HEAD to origin; skips `no_push` URLs. | GIT |
| handover | :6183 | agents/handover/handover.sh | CTX |
| healing | :6186 | agents/healing/healing.sh | AUDIT, CTX |
| resume | :6189 | agents/resume/resume.sh | CTX |
| inception | :6192 | lib/inception.sh `do_inception` | TASK |
| orchestrator | :6197 | next-dispatch/pre-flight run orchestrator-graph.py; routes/status are inline. **`improve` is a STUB (echo only).** | XAGENT |
| resolver | :6842 | lib/resolver.sh, which calls resolver.py | XAGENT |
| outcome | :6849 | lib/outcome.sh, which calls outcome.py | XAGENT |
| pause | :6856 | lib/pause.sh, which calls pause_cli.py | XAGENT |
| peer | :6862 | lib/peer.py: long-polls TermLink `inbox.queued` and spawns responders. | XAGENT |
| promote | :6868 | lib/promote.sh: moves knowledge up learning → practice → directive. | CTX |
| assumption | :6872 | lib/assumption.sh | CTX |
| bus | :6876 | lib/bus.sh (result ledger) | XAGENT |
| rail | :6880 | lib/rail-identity.sh | XAGENT |
| dispatch | :6884 | lib/dispatch.sh: sends bus envelopes over SSH, plus approve/reset for the Agent gate. | XAGENT |
| pickup | :6888 | lib/pickup.sh | XAGENT |
| pending | :6892 | lib/pending.sh | XAGENT |
| upstream | :6896 | lib/upstream.sh (files reports to the framework repo via `gh`) | INSTALL |
| consolidate | :6900 | agents/context/consolidate.py (duplicate or stale learnings) | CTX |
| mcp | :6903 | Inline: MCP server start/stop/status, manifest emit/show/check, fragment, reap. | OPS, XAGENT |
| fix-learned | :7013 | Shortcut for `context.sh add-learning --source P-001`. | CTX |
| note | :7026 | agents/observe/observe.sh | CTX |
| recall | :7029 | agents/context/lib/memory-recall.py (web.embeddings hybrid search) | RECALL, CTX |
| scan | :7042 | `python -m web.watchtower` | AUDIT |
| serve | :7050 | bin/watchtower.sh start | OPS |
| watchtower | :7062 | bin/watchtower.sh | OPS |
| deploy | :7070 | Calls the external `/opt/claude-shared-toolkit` ring20_deployer.py. | OPS |
| tier0 | :7131 | Inline approve/status. | TASK, AUDIT |
| approvals | :7208 | Inline pending/status/expire; hardcoded 3600s TTL fallback. | TASK |
| review-queue | :7410 | Inline Python queue listing. | TASK |
| verify-queue | :7819 | lib/verify_queue.py | TASK, AUDIT |
| work-on | :7854 | Inline: resumes or creates a task and sets focus. | TASK, CTX |
| task | :8052 | `route_task` (bin/fw:4104), which calls create-task.sh / update-task.sh or inline code. | TASK |
| preflight | :8055 | lib/preflight.sh | INSTALL |
| init | :8059 | lib/init.sh | INSTALL |
| validate-init | :8063 | lib/validate-init.sh | INSTALL |
| update | :8067 | lib/update.sh | INSTALL |
| upgrade | :8071 | lib/upgrade.sh | INSTALL |
| consumer-recover | :8076 | lib/consumer-recover.sh | INSTALL |
| setup | :8082 | **Deprecated alias**: prints a notice, then runs `do_init`. | INSTALL |
| build | :8089 | lib/build.sh (compiles TypeScript with esbuild) | OPS |
| harvest | :8092 | lib/harvest.sh | CTX |
| prompt | :8096 | lib/prompt.sh (prompt register) | XAGENT |
| termlink | :8100 | agents/termlink/termlink.sh | XAGENT |
| sessions | :8103 | agents/sessions/<provider>/list.sh piped to render.py | OPS |
| onboarding | :8157 | Inline marker status/skip/reset. | TASK, INSTALL |
| provisions | :8230 | lib/aef_provision_log.py (read-only view) | AUDIT |
| gaps | :8235 | Inline Python plus lib/gaps.py | AUDIT |
| traceability | :8402 | Inline baseline/status/reset. | AUDIT, GIT |
| decisions | :8447 | Inline print of decisions.yaml plus AD rows. | CTX |
| timeline | :8510 | Inline table of handover frontmatter. | CTX |
| learnings | :8564 | Inline print of learnings.yaml. | CTX |
| patterns | :8659 | Inline print of patterns.yaml. | CTX |
| practices | :8729 | Inline print of practices.yaml. | CTX |
| search | :8784 | Keyword grep; `--semantic` and `--hybrid` use web.embeddings; adds corpus hits. | RECALL, DESIGNER |
| vendor | :8992 | `self` uses the `_self_vendor_*` functions; otherwise `do_vendor` (bin/fw:473). | INSTALL |
| hook | :9101 | Runs agents/context/<name>.sh with telemetry. **A missing script exits 0.** | TASK, AUDIT |
| hook-enable | :9163 | bin/hook-enable.sh | AUDIT |
| doctor | :9173 | `do_doctor` (bin/fw:1429-2726) | AUDIT |
| policy | :9176 | `do_policy` (bin/fw:4060), which calls govd_policy.py | AUDIT |
| verify-acs | :9179 | lib/verify-acs.sh | TASK |
| self-test | :9183 | tests/e2e/*-test.sh | AUDIT |
| enforcement | :9224 | Inline hook baseline hashing and layer status. | AUDIT |
| metrics | :9299 | Inline predict, a dashboard (metrics.sh) and api-usage.sh. | OPS, CTX |
| costs | :9471 | lib/costs.sh | OPS |
| release | :9476 | lib/release.sh | INSTALL, GIT |
| mirror | :9481 | lib/mirror.sh | GIT |
| test | :9486 | Inline shellcheck, bats and pytest suites. | AUDIT |
| notify | :9799 | Inline ntfy setup and test. | OPS |
| config | :9988 | lib/config-file.sh | OPS |
| version | :9992 | `show_version`, plus lib/version.sh | INSTALL |
| help | :10020 | `show_help` | NONE |

### 1b. lib/*.sh (B; 83 modules)

| file | what it actually does | main callers | tags |
|---|---|---|---|
| arc.sh | `fw arc` verbs: create/start/list/show/close/abandon/migrate, driver approve/remove, scoped weights, rescore. | bin/fw | TASK, BVP |
| arc_membership.sh | Finds the task IDs in an arc (via `arc_id:` or tags); resolves slug and ID. | arc.sh, evolution_log.sh, audit.sh, handover.sh | TASK |
| ask.sh | Prints help, then hands off to lib/ask.py. | bin/fw | RECALL |
| assumption.sh | Add/validate/invalidate/list assumptions YAML. | bin/fw, self-audit | CTX |
| audit-anchor-task.sh | Reports arcs whose `anchor_task` has no task file. | audit.sh | AUDIT |
| branch-hygiene.sh | Stale/behind/divergence and wrong-branch checks, plus `fw_go_live`. | bin/fw | GIT, AUDIT |
| build.sh | Compiles lib/ts/src to dist with esbuild when stale. | bin/fw | OPS |
| bus.sh | `fw bus` post/read/manifest/clear/receive. | bin/fw, dispatch.sh | XAGENT |
| bvp.sh | Embedded ~1600-line Python engine: rank/detail/arcs/weight/driver/confirm/auto-promote. | bin/fw, audit.sh, bvp-estimator | BVP |
| colors.sh | ANSI colour variables when output is a TTY. | many | OPS |
| compat.sh | Portable `_sed_i` and date helpers. `_date_relative` has no callers. | paths.sh, episodic.sh | OPS |
| config-file.sh | `fw config` set/get/list/overrides. | bin/fw | OPS |
| config.sh | `fw_config` resolution (env, then .framework.yaml, then registry default). | nearly all | OPS |
| consumer-recover.sh | Re-vendors a remote consumer via SSH or TermLink. | bin/fw | INSTALL |
| continuous-mode.sh | Continuous-mode state plus `fw continuous` CLI. | bin/fw, stop-driver.sh, update-task.sh | TASK, CTX |
| corpus-id.sh | `corpus_max_id` for YAML corpora. | context/lib/learning.sh | CTX |
| costs.sh | Token and cost summaries from session JSONL. | bin/fw, handover.sh | OPS |
| cron-orphans.sh | Finds /etc/cron.d/agentic-* files whose PROJECT_ROOT no longer exists. | doctor | AUDIT |
| cron-registry.sh | Counts registry jobs. | bin/fw, audit.sh | AUDIT |
| dispatch.sh | SSH envelope send and hosts, **plus** approve/reset for the Agent-dispatch gate (an unrelated job). | bin/fw | XAGENT |
| doctor-upstream.sh | Predicate: is the upstream a local path that differs from FRAMEWORK_ROOT? | doctor | AUDIT |
| enums.sh | Loads status/type/horizon/owner enums and transitions; `is_valid_*` checks. | create/update-task | TASK |
| errors.sh | `die`/`warn`/`block` helpers. | many | OPS |
| evolution_log.sh | Finds arc build tasks with an empty `## Evolution` section. | update-task.sh | TASK |
| exec-bit-drift.sh | Lists tracked 755 files that lost the exec bit. | doctor, audit | AUDIT |
| firewall.sh | Opens a UFW port. | bin/watchtower.sh | OPS |
| first-run.sh | Walkthrough that runs doctor and `context init`. **No sourcing caller found.** | none | INSTALL |
| git-identity.sh | Checks and shows git identity; worker identity exports. | bin/fw, preflight, validate-init | GIT |
| gitignore-register.sh | Flags .gitignore deferral comments with no task/gap ID; writes a /tmp scratch file. | audit.sh | AUDIT |
| harvest.sh | Pulls learnings, patterns and decisions from a project into the framework. | bin/fw | CTX |
| hook-parity.sh | Compares hook settings across worktrees. | bin/fw, upgrade.sh | AUDIT |
| hook-telemetry.sh | Per-hook fire and failure counters. | bin/fw, hook-threshold.py | OPS |
| inception.sh | `fw inception` start/status/decide/sweep/retrofit-recommendations. | bin/fw | TASK |
| inception-readiness.sh | Lists Open Questions without a disposition. | review.sh, inception.sh, update-task.sh | TASK |
| inception_recommendation.sh | Checks for a real recommendation; lists inceptions that lack one. | inception.sh, audit.sh | TASK, AUDIT |
| index-health.sh | Doctor verdict on vector index age (`web.embeddings.index_freshness`). | doctor | RECALL, AUDIT |
| init.sh | `fw init` scaffold, CLAUDE.md/.claude config, designer install. | bin/fw | INSTALL |
| keylock.sh | Per-key flock locks. | create/update-task | TASK |
| mirror.sh | Fast-forwards and recovers mirror remotes. | bin/fw | GIT |
| notify.sh | ntfy via an external `/opt/150-skills-manager` alert_dispatcher.py (hardcoded path). | bin/fw, pending, bvp, review, audit | OPS |
| outcome.sh | Exec wrapper for outcome.py. | bin/fw | XAGENT |
| paths.sh | Sets PROJECT_ROOT etc.; re-anchors from cwd or hook stdin. | nearly all | OPS |
| pause.sh | Exec wrapper for pause_cli.py. | bin/fw | XAGENT |
| pending.sh | Registry of actions the agent could not complete. | bin/fw | XAGENT |
| pickup.sh | Validates, dedups and processes pickup envelopes into inception tasks; send. | bin/fw | XAGENT, TASK |
| pickup-channel-bridge.sh | Posts a pickup envelope to TermLink topic `framework:pickup`. | pickup.sh | XAGENT |
| post-write-index.sh | Re-embeds one file into web/embeddings. | context lib learning/pattern/episodic | RECALL |
| preflight.sh | OS dependency checks. | bin/fw, init.sh | INSTALL |
| promote.sh | Promotes learnings into practices. | bin/fw | CTX |
| prompt.sh | Prompt library CRUD in `prompts/`. | bin/fw | OPS |
| publish-learning-to-bus.sh | Publishes a learning to TermLink `channel:learnings`. | context/lib/learning.sh | XAGENT, CTX |
| push-state.sh | Tracks consecutive push failures. | bin/fw, handover.sh | GIT |
| rail-identity.sh | TermLink identity fingerprint and guard. | bin/fw, check-rail-mcp-label.sh | XAGENT |
| recall-usage.sh | Doctor verdict on recall query counts (`web.recall_telemetry`). | doctor | RECALL, AUDIT |
| release.sh | Tag, fast-forward master, GitHub release. | bin/fw, cron | INSTALL, GIT |
| render_surface.sh | Decides whether a task touched render-surface files. | update-task.sh | TASK |
| resolver.sh | Exec wrapper for resolver.py. | bin/fw | XAGENT |
| review.sh | `emit_review` and batch: Watchtower URLs plus gates. | bin/fw, update-task.sh | TASK |
| root-pollution.sh | Lists untracked binaries in the project root. | doctor | AUDIT |
| runtime.sh | `fw_run_ts` (node, else Python). **Only tests source it.** | tests/unit | OPS |
| section-extract.sh | awk extractors for the AC and Recommendation sections. | inception.sh, update-task, check-active-task | TASK |
| setup.sh | Interactive setup wizard. **`fw setup` now routes to init.sh**; the only reference is self-audit.sh:115's existence loop and a comment in upgrade.sh:1749. | none live | INSTALL |
| subscribe-learnings-from-bus.sh | Polls `channel:learnings` into received-learnings.yaml. **No caller and no cron registry entry**; its header says "recommended install: */5 cron". | none | XAGENT, CTX |
| task-audit.sh | Detects placeholder text in tasks. | bin/fw, review, inception, audit | TASK, AUDIT |
| task_pair_acd.sh | Wrapper for task_pair_acd.py (P-012). | update-task.sh | TASK |
| tasks.sh | `find_task_file` and related helpers. | many | TASK |
| traceability.sh | `trace_is_root_commit`. | audit.sh | GIT |
| update.sh | `fw update`: shallow-clones and re-vendors with rollback. **Overlaps upgrade.sh.** | bin/fw | INSTALL |
| upgrade.sh | `fw upgrade` 10 steps plus self-vendor helpers; propagates lib/templates to consumers (:2265). | bin/fw, fw-shim | INSTALL |
| upstream.sh | Files reports as GitHub issues. | bin/fw | INSTALL |
| url-credentials.sh | Strips credentials from URLs; picks the preferred remote. | bin/fw, consumer-recover | GIT |
| validate-init.sh | Checks init output against `#@init:` tags. | bin/fw, init.sh | INSTALL, AUDIT |
| vendor-visibility.sh | Fails when vendored files are gitignored. | vendor | INSTALL |
| verification-port.sh | Flags :3000 literals and `bash -n` failures in the Verification block. | update-task.sh | TASK |
| verification-verdict.sh | Flags grep-"passed"-only verdict lines. | update-task.sh | TASK |
| verify-acs.sh | `fw verify-acs`. | bin/fw | TASK |
| version.sh | VERSION bump/check/sync. `_version_lt` duplicates `release_version_lt` in release.sh. | bin/fw, worktree.sh | INSTALL |
| version-relation.sh | Consumer vs framework ancestry classification. | bin/fw, upgrade.sh | INSTALL |
| watchtower.sh | URL identity probe and review URL building. `_watchtower_open` has no callers. | bin/fw, review, arc | OPS |
| watchtower-staleness.sh | Lists web/ files newer than the running process. | bin/fw, audit | AUDIT |
| worktree.sh | `fw worktree` with governance-aware checks. | bin/fw, paths.sh | GIT |
| worktree-identity.sh | `fw_is_linked_worktree`. | bin/fw, paths.sh | GIT |
| yaml.sh | `get_yaml_field` awk reader. | many | OPS |

### 1c. lib/*.py, lib/reviewer, lib/ts, lib/migrations, lib/seeds, lib/templates (H)

| item | what it does (header, checked against call sites) | callers found (bin/lib/agents/web) | tags |
|---|---|---|---|
| aef_address.py | V9 address grammar parser (arc-020 S1). | aef_circuit/aef_resolve/tests | XAGENT |
| aef_circuit.py | Circuit registry with three-state lifecycle (arc-020 S2). | aef_resolve, aef_election | XAGENT |
| aef_election.py | Claim-based election for exactly-one provisioning (arc-020 S4). | tests (see §3) | XAGENT |
| aef_governor.py | Loadavg-based provisioning admission (arc-020 S5). | aef_resolve / tests | XAGENT, OPS |
| aef_provision_log.py | JSONL audit trail of auto-provision events (S7). | `fw provisions` | AUDIT |
| aef_repo_source.py | Fleet repo-source and integrity verify (S6). | **Only tests import it** (`lib/aef_repo_source.py:45` notes the test import convention). | XAGENT |
| aef_resolve.py | Regressive resolution and provisioning ladder (S3). | tests / arc-020 siblings | XAGENT |
| antigravity_bridge.py | Translates Antigravity CLI hook payloads to Claude Code format and invokes AEF hooks. | referenced by provider package | XAGENT, TASK |
| antigravity_steps.py | Antigravity step handlers (self-provision, subagent scoping). | **No code caller** (4 references, all in docs/fabric/vendored copy) | XAGENT |
| arc_membership.py | Canonical arc-membership scan (T-1880). | arc_membership.sh, web | TASK |
| ask.py | RAG plus Ollama Q&A; imports `web.embeddings` and `web.ask`. | ask.sh | RECALL |
| audit_timing.py | Classifies the full-audit timing record against a warn fraction. | audit.sh | AUDIT |
| bats_red_attribution.py | Maps red bats tests to the paths they cover. | audit/unit-suite | AUDIT |
| cmd_classify.py | Decides "is this command wrap-up?" for the budget-gate critical allowlist. | budget-gate.sh | CTX |
| comment_strip.py | Canonical HTML-comment stripping. | check-human-ac-tick.py, others | TASK |
| context_tokens.py | Token count of the current conversation (shared by budget-gate and checkpoint). | budget-gate.sh, checkpoint.sh | CTX |
| cron_dry_run.py | Regenerates the crontab to stdout for drift comparison. | doctor/audit | AUDIT |
| decided_unclosed.py | Lists inceptions that are decided but still open. | web /approvals, fw | TASK |
| dispatch_pause.py | Reads paused dispatches from dispatches.jsonl. | pause_cli, web | XAGENT |
| doctor-hook-exercise.py | Invokes every configured hook and reports unresolved paths. | doctor | AUDIT |
| episodic_footprint.py | Re-mines an episodic's git footprint after completion. | episodic.sh / update-task | CTX |
| gaps.py | Gap-register closure helpers. | `fw gaps`, web /gaps | AUDIT |
| govd_envelope.py | Authority-envelope decision evaluator (arc-013). | govd_holder, govd.sh | AUDIT |
| govd_holder.py | Privileged state-holder daemon core (arc-013). | govd.sh | AUDIT |
| govd_policy.py | Proxy-policy emit/install/drift. | `fw policy` | AUDIT |
| govd_relay.py | Governance mediation relay (proxy brain). | govd.sh | AUDIT |
| heredoc_guard.py | Parses a PreToolUse payload for check-heredoc-cmd-sub. | check-heredoc-cmd-sub.sh | TASK |
| hook_parity.py | Hook-set extraction and comparison. | hook-parity.sh, doctor | AUDIT |
| hook_paths.py | Python hook project-root resolver (worktree re-anchor). | python hooks | TASK |
| hook_portability.py | Is a hook command host-portable? | doctor, upgrade.sh | AUDIT |
| hook-threshold.py | Hook-failure threshold rule over counters. | doctor | AUDIT |
| human_review_state.py | Classifies Human AC blocks for the P-013 render gate. | update-task.sh | TASK |
| inception_decisions.py | Parses the `inception_decisions:` and `unlocks_inception_decision:` fields. | check-inception-decisions.py, update-task | TASK |
| integrate.py | `fw integrate` preflight and run. | bin/fw | GIT |
| keylock.py | Python sibling of keylock.sh. | python writers | TASK |
| message_router.py | Static `msg_type` router over the recovered hub archive. | `fw triage` | XAGENT |
| ollama_loop.py | Runs a `claude -p` worker against the litellm proxy. | spawn.py | XAGENT |
| ollama_thin_loop.py | Direct /v1/messages tool loop for small local models. | spawn.py | XAGENT |
| outcome.py | Dispatch outcome evaluator, back-prop and join. | outcome.sh, update-task hook | XAGENT |
| pause_cli.py | `fw pause` list/resolve. | pause.sh | XAGENT |
| pause_resolve.py | Captures the operator's answer and re-dispatches via Resolver. | pause_cli | XAGENT |
| peer.py | inbox.queued subscriber and responder spawn. | `fw peer` | XAGENT |
| pi_worker.py | pi RPC JSONL worker protocol. | spawn.py | XAGENT |
| resolver.py | Workflow lookup, prompt assembly and telemetry (2193 lines). | resolver.sh, spawn.py | XAGENT |
| review_link_validator.py | Validates Watchtower handoff links in the Recommendation and Human Steps. | review.sh / update-task | TASK |
| settings_merge.py | Carries non-template settings forward across a regenerate. | init.sh / upgrade.sh | INSTALL |
| spawn.py | Dispatch driver (envelope, spawn worker, finalise). Header: "Other worker kinds raise NotImplementedError" (the ollama and TermLink siblings exist since). | resolver loop / cron (paused) | XAGENT |
| task_pair_acd.py | P-012 substrate-vs-deliverable gate. | task_pair_acd.sh | TASK |
| task_satisfaction.py | Finds active tasks whose ACs are satisfied but that are unclosed. | audit/web | TASK, AUDIT |
| termlink_worker.py | Runs `fw termlink dispatch` as a worker. | spawn.py, reviewer/dispatch_cli | XAGENT |
| tier0_origin.py | Derives the provenance of a Tier-0 approval request. | check-tier0 / approvals | TASK |
| verify_queue.py | Re-runs stored Verification for the review queue. | `fw verify-queue` | TASK, AUDIT |
| worker_identity.py | Git identity for dispatched workers. | git-identity.sh / spawn | XAGENT, GIT |
| worker_kinds_parity.py | Doctor parity check: resolver vs workflow_lint worker kinds. | doctor | AUDIT |
| workflow_coverage.py | Checks that every workflow has a dispatcher. | audit | AUDIT, XAGENT |
| workflow_lint.py | Workflow YAML schema lint. | doctor | AUDIT, XAGENT |
| write_set.py | Disjoint write-set validator. | `fw write-set`, orchestrator-graph.py | XAGENT |
| reviewer/static_scan.py | Anti-pattern static scan of tasks (3137 lines); reads anti-patterns.yaml and escalation-patterns.yaml. | `fw reviewer`, update-task | AUDIT, TASK |
| reviewer/audit.py | Layer-3 daily re-scan of completed tasks. | `fw reviewer audit` (cron) | AUDIT |
| reviewer/classifier.py | Classifies Verification lines by safety. | reverify.py | AUDIT |
| reviewer/dispatch_cli.py | Runs the reviewer in a TermLink worker. | `fw reviewer --dispatch` (`-m`) | AUDIT, XAGENT |
| reviewer/drift.py + drift_cli.py | Pass A: hashes files referenced by Verification. | `fw reviewer drift` (`-m`) | AUDIT |
| reviewer/overrides.py + override_cli.py | TTL'd false-positive waivers. | `fw reviewer override` (`-m`) | AUDIT |
| reviewer/reverify.py + reverify_cli.py | Pass B: re-executes Verification in a worktree. | `fw reviewer reverify` (`-m`) | AUDIT |
| reviewer/recommendation_claims.py | Verifies evidence claims in an inception Recommendation. | static_scan / review | AUDIT, TASK |
| reviewer/\_\_init\_\_.py | Package marker. | — | — |
| ts/src/fw-util.ts, ts/dist/fw-util.js | Utility replacing inline Python blocks. dist is called only by validate-init.sh:64 and self-audit.sh:253, and only if node is present. | 2 | OPS |
| ts/src/loop-detect.ts, ts/dist/loop-detect.js | PostToolUse loop detector. The wrapper `agents/context/loop-detect.sh:19-22` **fails open (allows) when node or the dist file is missing.** | loop-detect.sh | CTX |
| ts/node_modules | **On disk but untracked** (`git ls-files lib/ts` lists 9 files, 0 of them under node_modules). | — | — |
| migrations/arc-id-migration.sh | One-shot `tags:[arc:X]` → `arc_id:` migration (T-1850). | no code caller (1 test) | TASK |
| seeds/ (decisions/patterns/practices.yaml, tasks/{greenfield,existing-project}/) | Seed memory and onboarding tasks copied into new projects. | init.sh:416-430 | INSTALL, CTX |
| templates/claude-project.md, resume-md.md | CLAUDE.md and resume templates for consumers. | init.sh:896,1298; upgrade.sh:1445; harvest.sh:476 | INSTALL |
| templates/scripts/*.sh (12) | Agent chat-arc, DM, listener and presence helper scripts. | .claude/commands/*.md; propagated by upgrade.sh:2265 | XAGENT |
| templates/skills/*.md (9) | Skill definitions for the above (`/peers`, `/pulse`, …). | propagated by upgrade.sh:2265-2280 into consumer `.claude/commands` | XAGENT |

### 1d. agents/context/ (hooks and context agent) — H, with hook wiring checked against `.claude/settings.json`

`.claude/settings.json` wires **28 hook commands**: 16 PreToolUse, 8 PostToolUse, 3 SessionStart, 1 PreCompact, 1 Stop. `.claude/settings.local.json` references only checkpoint and context.

| file | what it does | wiring | tags |
|---|---|---|---|
| audit-task-tools.sh | PostToolUse detector for TodoWrite/TaskCreate use by sub-agents. | PostToolUse:* | TASK |
| block-plan-mode.sh | Echoes BLOCKED for EnterPlanMode (7 lines). | PreToolUse:EnterPlanMode | TASK |
| block-task-tools.sh | Blocks the built-in task tools. | PreToolUse:TodoWrite\|Task* | TASK |
| budget-gate.sh | Blocks Write/Edit/Bash at critical context tokens. | PreToolUse:Write\|Edit\|Bash | CTX |
| bus-handler.sh | Processes `.context/bus/inbox` files; header says "triggered by systemd.path" (T-110 spike). | **NOT-WIRED**: no settings entry, cron entry or code caller | XAGENT |
| chat-bare-path-scan.sh | Stop hook: records bare `/review/T-` paths found in the assistant turn. | **NOT-WIRED** (checkpoint.sh:73 mentions it only in a comment) | TASK |
| chat-bare-path-warn.sh | UserPromptSubmit companion that surfaces those violations. | **NOT-WIRED** | TASK |
| check-active-completed-dup.sh/.py | Blocks a write creating a same-ID task in both active/ and completed/. | PreToolUse:Write\|Edit | TASK |
| check-active-task.sh | Task-first gate (1179 lines). | PreToolUse:Write\|Edit\|Bash | TASK |
| check-agent-dispatch.sh | Caps Agent-tool dispatches (limit 2) with a TermLink redirect. **Fired during this run.** | PreToolUse:Agent | XAGENT |
| check-arc-id.sh/.py | Validates `arc_id:` against the arc YAMLs. | PreToolUse:Write\|Edit | TASK |
| check-dispatch-pre.sh | PreToolUse: blocks a Task dispatch whose prompt lacks the preamble (G-008). | **NOT-WIRED** | XAGENT |
| check-dispatch.sh | PostToolUse: warns on large sub-agent results. | PostToolUse:**Task\|TaskOutput** (see §4) | XAGENT, CTX |
| check-fabric-new-file.sh | Advisory to register new files in the fabric. | PostToolUse:Write | FAB |
| check-heredoc-cmd-sub.sh | Guards against heredoc-in-`$()` edits to bin/fw. | PreToolUse:Write\|Edit | TASK |
| check-human-ac-tick.sh/.py | Refuses agent ticks of `### Human` ACs. | PreToolUse:Write\|Edit | TASK |
| check-inception-decisions.sh/.py | Validates `inception_decisions:` structure. | PreToolUse:Write\|Edit | TASK |
| check-inception-recommendation.sh/.py | Refuses an inception save whose Recommendation is template-only (T-2205). | **NOT-WIRED.** The .py is imported by lib/review.sh. | TASK |
| check-inception-schema.sh/.py | Inception frontmatter schema. | PreToolUse:Write\|Edit | TASK |
| check-onboarding-gate.sh/.py | Onboarding-task invariant. | PreToolUse:Write\|Edit | TASK |
| check-project-boundary.sh | Blocks writes and commands outside PROJECT_ROOT. | PreToolUse:Write\|Edit\|Bash | TASK |
| check-rail-mcp-label.sh | Label gate on the MCP `termlink_channel_post`. | PreToolUse:mcp__termlink__termlink_channel_post | XAGENT |
| check-settings-edit.sh | Nudge to refresh the enforcement baseline after a settings edit. | PostToolUse:Write\|Edit | AUDIT |
| check-task-ac-structure.sh/.py | Refuses a `### Human` section placed after an intervening `## ` heading (T-2420). | **NOT-WIRED** | TASK |
| check-tier0.sh | Tier-0 destructive command gate. | PreToolUse:Bash | TASK |
| check-visual-verification.sh (+ .AGENT.md) | Blocks commits of css/html without a `## Visual Verification` image (adopted from 025, T-2128). | **NOT-WIRED** | TASK |
| check-worktree-governance-write.sh | Refuses governance writes from a linked worktree. | PreToolUse:Write\|Edit | TASK, GIT |
| checkpoint.sh | PostToolUse budget warnings and auto-handover. | PostToolUse:* | CTX |
| commit-cadence.sh | Warns when many edits have gone uncommitted. | PostToolUse:Write\|Edit | CTX, GIT |
| consolidate.py | Finds duplicate or stale learnings. | `fw consolidate` | CTX |
| context.sh + lib/{init,focus,status,learning,pattern,decision,episodic}.sh | Context Fabric CLI: init, focus, status, add-learning/pattern/decision, generate-episodic. | `fw context`; 11 cron refs | CTX |
| lib/extract_decisions.py | Extracts `## Decisions` as YAML for episodic. | episodic.sh | CTX |
| lib/memory-recall.py | Hybrid recall over learnings, patterns and decisions, with a keyword fallback. | `fw recall`, focus | RECALL, CTX |
| lib/safe-commands.sh | Read-only Bash allowlist for the task gate (1237 lines). | check-active-task.sh | TASK |
| continuous-driver.sh | Drives the continuous loop from outside when the agent stops early. | cron (registry: "Continuous-run outside driver (10 min)") | XAGENT, CTX |
| error-watchdog.sh | Investigation reminder when Bash fails. | PostToolUse:Bash | AUDIT |
| inject-next-directive.py | Next-directive injection for continuous mode. | stop-driver.sh, continuous-mode.sh | CTX |
| loop-detect.sh | Wrapper for loop-detect.js; fails open without node. | PostToolUse:* | CTX |
| pl007-scanner.sh | Flags bare commands in Bash output. Header: "REFERENCE ONLY (T-1459)". | NOT-WIRED (by design) | TASK |
| post-compact-resume.sh | Reinjects context on SessionStart. | SessionStart:compact/resume/startup | CTX |
| pre-compact.sh | Generates a handover before /compact. | PreCompact | CTX |
| revisit-due-scan.sh | Scans for ripe `revisit_at:` dates; header says "daily scan". | Not in settings or cron registry; handover.sh:811 only *reads* its output file | TASK |
| session-end.sh | SessionEnd reason log plus handover trigger. Header: "REFERENCE ONLY, deliberately NOT registered" (T-1459, G-016). | NOT-WIRED (by design) | CTX |
| session-metrics.sh | Transcript quality metrics. | handover.sh:647-648 calls it directly | CTX |
| session-silent-scanner.sh | Recovers handovers for silent sessions; header says "invoked via cron every 15 min" **and** "REFERENCE ONLY". | **Not in the cron registry** | CTX |
| stop-driver.sh | Continuous-run turn driver. | Stop (direct path, not via `fw hook`) | CTX, XAGENT |
| stop-guard.sh | Nudge to capture a conversation. "REFERENCE ONLY". | NOT-WIRED (by design) | CTX |
| subagent-stop.sh | Sub-agent return telemetry plus bus auto-migrate. "REFERENCE ONLY". | NOT-WIRED (by design) | XAGENT |
| test-tier0-patterns.py | Standalone test suite for the Tier-0 regexes, **outside tests/**. | none | TASK |
| tests/*.sh (6) | Stub tests for the reference-only hooks and revisit scans, **outside tests/**. | none found | — |
| AGENT.md | Context agent intelligence doc. | 0 code refs | CTX |

### 1e. Other agents/ (H)

| file | what it does | loader | tags |
|---|---|---|---|
| antigravity/subagent_dispatch.py | Prepares and reconciles Antigravity subagents under AEF rules. | **No code loader** (3 refs: vendored copy, fabric, docgen) | XAGENT |
| audit/audit.sh | The audit agent (7300 lines, 35 section/check functions). | `fw audit`; 10+ cron entries | AUDIT |
| audit/active-task-scan.py, completed-task-scan.py | Single-pass scans of active and completed tasks for audit loops. | audit.sh | AUDIT |
| audit/orchestrator-mcp-scan.sh | Drift defence for MCP `task_id` gating, probing /opt/termlink. | audit.sh | AUDIT, XAGENT |
| audit/plugin-audit.sh | Classifies plugins' task-awareness. | `fw plugin-audit` | AUDIT |
| audit/self-audit.sh | fw-independent integrity check of layers 1-4. | `fw self-audit` | AUDIT |
| audit/unit-suite.sh | Nightly tests/unit run with a report. | cron "Unit-suite corpus run" | AUDIT |
| bpmn/bpmn.sh (+AGENT.md) | Wrapper: compile runs tools/bpmn_to_tasks.py; promote runs tools/bpmn_promote.py. | `fw bpmn` | DESIGNER |
| capture/read-transcript.py | Extracts conversation turns from session JSONL for `/capture`. | /capture skill | CTX |
| designer/designer.sh | Vendors and serves the pinned 832 Workflow Designer build (status/verify/install). | `fw designer`, init/upgrade | DESIGNER |
| dispatch/preamble.md, audit/develop/enrich/investigate.md, AGENT.md | Sub-agent prompt templates. Code refs: preamble is named in check-dispatch(-pre).sh and worktree-corpus-guard.sh; the other four in 1 code file each. | the markdown prompts are not loaded programmatically | XAGENT |
| dispatch/single-host-parallel-demo.sh | arc-011 demo composing write-set, yield-point and orchestrator-graph. | demo | XAGENT |
| dispatch/yield-point.sh | Cooperative-poll refuse-write flag file (arc-011 spike). | 3 code refs | XAGENT |
| docgen/generate-component.sh + generate_component.py | Component reference docs from fabric cards. | `fw docs`; cron "Component docs regeneration (daily)" | FAB |
| docgen/generate-article.sh + generate_article.py | Subsystem deep-dive prompt or Ollama article. | `fw docs article` | FAB |
| docgen/test_docgen.py | Tests, **outside tests/**. | — | — |
| fabric/fabric.sh + lib/{register,drift,query,summary,traverse,ui}.sh, enrich.py, expand_patterns.py | Component Fabric: register/scan, drift/validate, search/get/deps, overview, impact/blast-radius, ui, dependency-edge enrichment. | `fw fabric`, check-fabric-new-file | FAB |
| git/git.sh + lib/{commit,log,status,bypass,common,hooks}.sh | Task-referenced commits, log, status, bypass log, git hook installer (hooks.sh, 1389 lines). | `fw git` | GIT, TASK |
| git/lib/{dup-task-scan,large-file-scan,master-guard,secret-scan,worktree-corpus-guard}.sh | Pre-commit guards: duplicate task ID, large file, master-merge-only, secrets, worktree task corpus. | installed git hooks (hooks.sh) | GIT, TASK |
| git/lib/worker-commits.sh | Lists what autonomous workers committed. | `fw git worker-commits` | GIT |
| govd/govd.sh | arc-013 govd agent-safe subcommands: emit-install, evaluate. | `fw` / manual | AUDIT |
| gpu-recover/recover.sh | Kills the largest non-ollama VRAM consumer. | `fw gpu recover` | OPS |
| handover/handover.sh | Handover generation, commit and push (1491 lines). | `fw handover`, pre-compact, checkpoint | CTX |
| handover/discard-manifest.sh | Compaction discard manifest. | handover | CTX |
| healing/healing.sh + lib/{diagnose,patterns,resolve,suggest}.sh | Failure classification, pattern lookup, resolution logging. | `fw healing`, update-task (issues) | AUDIT, CTX |
| mcp/framework_mcp_server.py, manifest.py, *.json | Framework MCP server; manifest emitted from tool-set.yaml. | `fw mcp`, .mcp.json | XAGENT |
| mcp/mcp-reaper.sh | Kills orphaned MCP processes. | `fw mcp reap` | OPS |
| metrics/api-usage.sh | TermLink RPC legacy-primitive share (T-1166 gate). | `fw metrics api-usage` | XAGENT |
| monitor/liveness-check.sh, watchtower-rss-sample.sh | Liveness and RSS samplers. | cron (1 min, @reboot, 5 min) | OPS |
| observe/observe.sh | Observation capture and list. | `fw note` | CTX |
| onboarding-test/test-onboarding.sh | 8-checkpoint onboarding end-to-end test. | `fw test-onboarding` | INSTALL, AUDIT |
| orchestrator/orchestrator-graph.py | Decides parallel vs serial dispatch from write-set overlap. | `fw orchestrator next-dispatch/pre-flight` | XAGENT |
| resume/resume.sh | Post-compaction status/sync/quick. | `fw resume` | CTX |
| session-capture/AGENT.md | Session-end checklist (doc only). | CLAUDE.md, FRAMEWORK.md | CTX |
| sessions/render.py, SCHEMA.md, claude-code/list.sh, antigravity/{list,provision}.sh | Provider-neutral session listing, plus AGY provisioning. | `fw sessions` | OPS |
| task-create/create-task.sh, update-task.sh (2564 lines) | Task creation, and status transitions with all close gates. | `fw task`, `fw work-on` | TASK |
| task-create/tests/revisit-at-preservation-test.sh | Test, **outside tests/**. | none | — |
| termlink/termlink.sh | `fw termlink` wrapper (1132 lines). | `fw termlink` | XAGENT |
| termlink/bvp-estimator/{bvp-estimator.sh, estimator.py (3268 lines), AGENT.md} | Heuristic BVP score proposer; writes `bvp_scores_proposed:`. | cron "BVP estimator sweep (15 min)" via `fw bvp estimate` | BVP |
| ux-review/ux-review.py (+AGENT.md) | Headless-browser capture of Watchtower themes. | `fw ux-review` | AUDIT |
| */AGENT.md (audit, context, git, gpu-recover, handover, healing, onboarding-test, resume, task-create, termlink, ux-review) | Agent intelligence docs. | **0 code references for all of them** (read by humans and agents, not code) | — |

### 1f. policy/ (H; loaders found by grepping the basename in bin/lib/agents/web/.claude/tools)

| file | what it is | code that reads it | tags |
|---|---|---|---|
| anti-patterns.yaml | Reviewer anti-pattern catalogue. | reviewer/static_scan.py, reviewer/audit.py, update-task.sh, git hooks.sh, upgrade.sh | AUDIT |
| escalation-patterns.yaml | Escalation pattern catalogue. | static_scan.py, reviewer/audit.py, hooks.sh, upgrade.sh | AUDIT |
| authority-envelope.yaml | govd authority envelope. | govd.sh, govd_holder.py | AUDIT |
| proxy-policy.yaml | Mediation proxy policy. | govd.sh, bin/fw, govd_policy.py, govd_relay.py | AUDIT |
| bvp-scoring-rubric.md | BVP rubric. | estimator.py (preload), audit.sh, bin/fw | BVP |
| value-drivers.yaml | D1-D4 plus free drivers. | estimator.py, audit.sh, bin/fw | BVP |
| capability-overlay/tool-set.yaml | MCP tool catalogue. | manifest.py, framework_mcp_server.py, audit.sh | XAGENT |
| designer-pin.yaml | Pinned Designer build. | designer.sh, init.sh, upgrade.sh, bin/fw | DESIGNER |
| prompts/bvp-driver-session.md, artefact-template.md | BVP driver-session keystone and artefact template. | **Only named in help text** (lib/bvp.sh:726, :1590, :1596). The loader verbs are deferred per CLAUDE.md T-2245 IW-3. | BVP |
| prompts/bvp-references/*.md (5) | Sharpening, failure-mode and example references. | **No code loader** (routed from CLAUDE.md prose) | BVP |
| prompts/arc-delivery-session.md, landing-mode.md | Session prompts. | **No code loader**; references only in .context/handovers and episodics | TASK |
| prompts/README.md | Bundle index. | basename is generic; no specific loader verified (UNVERIFIED) | — |
| standards/aef-bpmn-mapping-v1-partI.md + .provenance.yaml | AEF↔BPMN mapping standard. | **No code loader** in bin/lib/agents/web; tools/aef_meta_census.py references it (tools/ is out of scope) | DESIGNER |

---

## Section 2 — Reverse map (capability → items)

| Capability | Items serving it | Empty or thin? |
|---|---|---|
| **Task system + gates** | `fw task`/`work-on`/`inception`/`arc`/`tier0`/`approvals`/`review-queue`/`verify-queue`/`verify-acs`/`onboarding`/`hook`; create-task.sh, update-task.sh; lib enums, tasks, keylock, section-extract, inception*, review, task-audit, render_surface, verification-port/-verdict, task_pair_acd, evolution_log, human_review_state, inception_decisions, review_link_validator, tier0_origin, comment_strip; 13 wired PreToolUse task hooks; git commit-msg/pre-commit guards. | Served, heavily. **4 task gates exist but are NOT wired:** check-inception-recommendation, check-task-ac-structure, check-visual-verification, chat-bare-path-scan/warn. |
| **Context Fabric (memory/handover)** | context.sh + lib (7), handover.sh, discard-manifest, resume.sh, pre-compact, post-compact-resume, checkpoint, budget-gate, context_tokens, cmd_classify, loop-detect, commit-cadence, observe, promote, harvest, assumption, consolidate, costs, session-metrics, read-transcript, `fw decisions/learnings/patterns/practices/timeline/fix-learned`, seeds. | Served. The SessionEnd leg (session-end.sh, session-silent-scanner.sh) is deliberately unwired (T-1459), so **nothing in scope covers a session that dies without a Stop or PreCompact**. The header of session-silent-scanner.sh claims a cron that is not in the registry. |
| **Component Fabric (blast radius)** | agents/fabric/* (fabric.sh, 6 lib .sh, enrich.py, expand_patterns.py), check-fabric-new-file (advisory PostToolUse), docgen (4), `fw fabric`/`fw docs`. | Served. It is **advisory only**: no gate consumes blast-radius output (none found in update-task.sh; UNVERIFIED beyond a name grep). |
| **BVP value scoring** | lib/bvp.sh (embedded engine), arc.sh (scoped drivers), termlink/bvp-estimator (estimator.py), policy value-drivers.yaml and bvp-scoring-rubric.md, cron: estimator sweep, cost sweep, auto-promote (off by default). | Scoring is served. **Driver-session workflow (policy/prompts/bvp-*) has NO code server**: its CLI verbs (`fw bvp driver suggest/create/...`) are deferred. Also, **no item measures realized value**; see OBS-415 in commit 2f120f9e2. |
| **Audit/doctor rails** | audit.sh (7300 lines) + 2 scan .py, self-audit, plugin-audit, unit-suite, orchestrator-mcp-scan, `do_doctor` (1300 lines inline in bin/fw), cron-orphans, cron-registry, cron_dry_run, exec-bit-drift, root-pollution, gitignore-register, watchtower-staleness, index-health, recall-usage, hook-parity, hook_portability, hook-threshold, doctor-hook-exercise, doctor-upstream, worker_kinds_parity, workflow_lint/coverage, audit_timing, bats_red_attribution, gaps.py, reviewer/* (12), govd_* (4), healing (5), error-watchdog. | Served, heavily. **Only 84 of 371 file items are named in audit.sh or doctor at all** (§3 last column). |
| **Cross-agent coordination** | termlink.sh, bus.sh, dispatch.sh, pickup(+bridge), pending, peer.py, rail-identity, message_router, resolver.py/spawn.py/outcome.py/pause_* and the 3 worker kinds, orchestrator-graph, write_set, yield-point, check-agent-dispatch, check-dispatch, check-rail-mcp-label, continuous-mode/driver, stop-driver, MCP server, templates/scripts+skills (21), aef_* (7, arc-020), antigravity_* (3), publish/subscribe-learnings, api-usage. | Served, and widest in item count. Several items have no live code caller: bus-handler.sh, check-dispatch-pre.sh, subscribe-learnings-from-bus.sh, antigravity_steps.py, subagent_dispatch.py, aef_repo_source.py (tests only). Autonomous resolver-loop cron is PAUSED (registry). |
| **Vector recall** | `fw ask` (ask.sh → ask.py), `fw recall` (memory-recall.py), `fw search --semantic/--hybrid`, `fw index reindex` (cron hourly), post-write-index.sh, index-health.sh, recall-usage.sh. | **Every item here is a wrapper or caller. The engine (`web.embeddings`, `web.ask`, `web.recall_telemetry`) lives in web/, outside this scope.** No embedding or index logic exists in bin/lib/agents/policy. |
| **Workflow designer** | designer.sh (vendors and serves an external 832 build), designer-pin.yaml, bpmn.sh (wraps tools/bpmn_to_tasks.py), `fw corpus` (wraps tools/corpus_*.py), policy/standards/aef-bpmn-mapping (no code loader), init.sh/upgrade.sh designer install. | **Thin.** Nothing in scope implements designer logic. It is vendored from 832, and the compilers and linters live in `tools/` (outside all four scoped dirs). The BPMN mapping standard has no loader in scope. |

**Capabilities with no in-scope server of their own:** vector recall (engine in web/), workflow designer (engine in 832 and tools/), BVP driver-session workflow (prompts only, CLI deferred), realized-value measurement (nothing), and SessionEnd / dead-session capture (deliberately unwired).

---

## Section 3 — Evidence

### 3a. Per file (371 rows; "no usage data exists" applies to every row)

| path | refs total | refs in code (bin/lib/agents/web/policy/.claude/cron) | test files | top ref locations | hook wiring | commits (--follow) | first | last | origin task (first commit) | audit/doctor names it |
|---|---|---|---|---|---|---|---|---|---|---|
| agents/antigravity/subagent_dispatch.py | 3 | 0 | 0 | .agentic-framework:1,fabric:1,docgen:1 |  | 2 | 2026-08-25 | 2026-08-25 | T-3129 | - |
| agents/audit/active-task-scan.py | 135 | 2 | 7 | ctx:96,fabric:9,.agentic-framework:8,tasks:8,tests:7,docs:3 |  | 4 | 2026-04-06 | 2026-08-18 | T-955 | audit |
| agents/audit/AGENT.md | 8 | 0 | 0 | ctx:3,tasks:2,docs:2,.agentic-framework:1 |  | 3 | 2026-02-13 | 2026-02-13 | T-002 | - |
| agents/audit/audit.sh | 2287 | 36 | 98 | ctx:1153,tasks:595,.agentic-framework:171,docs:115,tests:98,fabric:60 |  | 202 | 2026-02-13 | 2026-09-10 | T-002 | doctor |
| agents/audit/completed-task-scan.py | 53 | 1 | 5 | ctx:17,.agentic-framework:8,fabric:7,tasks:7,docs:5,tests:5 |  | 6 | 2026-04-06 | 2026-08-12 | T-955 | audit |
| agents/audit/orchestrator-mcp-scan.sh | 130 | 5 | 6 | ctx:48,tasks:23,.agentic-framework:20,fabric:13,docs:10,tests:6 |  | 7 | 2026-05-01 | 2026-07-28 | T-1646 | audit |
| agents/audit/plugin-audit.sh | 34 | 1 | 0 | ctx:12,.agentic-framework:7,docs:5,tasks:4,fabric:3,docgen:2 |  | 4 | 2026-02-15 | 2026-03-30 | T-067 | doctor |
| agents/audit/self-audit.sh | 71 | 3 | 0 | ctx:25,fabric:15,.agentic-framework:11,tasks:9,docs:6,docgen:2 |  | 11 | 2026-03-01 | 2026-08-25 | T-286 | - |
| agents/audit/unit-suite.sh | 24 | 3 | 1 | ctx:10,tasks:6,.agentic-framework:2,CRON:2,fabric:1,agents:1 |  | 3 | 2026-09-07 | 2026-09-11 | T-3302 | audit |
| agents/bpmn/AGENT.md | 22 | 1 | 0 | ctx:10,tasks:6,.agentic-framework:3,agents:1,docgen:1,docs:1 |  | 8 | 2026-07-12 | 2026-07-19 | T-2533 | - |
| agents/bpmn/bpmn.sh | 28 | 2 | 0 | ctx:11,tasks:5,.agentic-framework:4,docs:3,fabric:2,agents:1 |  | 5 | 2026-07-12 | 2026-07-21 | T-2533 | - |
| agents/capture/read-transcript.py | 29 | 1 | 2 | ctx:9,.agentic-framework:6,docs:4,tasks:3,fabric:2,docgen:2 |  | 3 | 2026-03-17 | 2026-06-14 | T-464 | - |
| agents/context/AGENT.md | 7 | 0 | 0 | ctx:3,docs:2,.agentic-framework:1,tasks:1 |  | 1 | 2026-02-13 | 2026-02-13 | T-005 | - |
| agents/context/audit-task-tools.sh | 13 | 0 | 1 | .agentic-framework:3,fabric:3,ctx:2,docgen:2,tasks:1,docs:1 | PostToolUse:* | 1 | 2026-04-12 | 2026-04-12 | T-1118 | - |
| agents/context/block-plan-mode.sh | 50 | 1 | 2 | .agentic-framework:17,docs:14,tasks:8,ctx:4,fabric:2,docgen:2 | PreToolUse:EnterPlanMode | 1 | 2026-02-22 | 2026-02-22 | T-242 | - |
| agents/context/block-task-tools.sh | 39 | 0 | 2 | ctx:10,.agentic-framework:8,fabric:6,docs:6,tasks:4,docgen:2 | PreToolUse:TodoWrite|TaskCreate|TaskUpdate|TaskList|TaskGet | 2 | 2026-04-12 | 2026-04-12 | T-1117 | - |
| agents/context/budget-gate.sh | 435 | 13 | 15 | ctx:158,.agentic-framework:84,docs:77,tasks:71,tests:15,fabric:7 | PreToolUse:Write|Edit|Bash | 37 | 2026-02-18 | 2026-09-07 | T-139 | audit+doctor |
| agents/context/bus-handler.sh | 27 | 0 | 0 | ctx:8,.agentic-framework:6,tasks:4,docs:4,fabric:3,docgen:2 | NOT-WIRED | 3 | 2026-02-17 | 2026-03-10 | T-110 | - |
| agents/context/chat-bare-path-scan.sh | 20 | 2 | 2 | .agentic-framework:5,ctx:3,tasks:3,fabric:2,agents:2,docgen:2 | NOT-WIRED | 1 | 2026-06-13 | 2026-06-13 | T-2183 | - |
| agents/context/chat-bare-path-warn.sh | 13 | 1 | 1 | .agentic-framework:3,ctx:3,fabric:2,tasks:1,agents:1,docgen:1 | NOT-WIRED | 1 | 2026-06-13 | 2026-06-13 | T-2183 | - |
| agents/context/check-active-completed-dup.py | 23 | 1 | 1 | .agentic-framework:5,ctx:5,fabric:4,docgen:4,docs:2,tasks:1 | PreToolUse:Write|Edit | 1 | 2026-07-10 | 2026-07-10 | T-2517 | - |
| agents/context/check-active-completed-dup.sh | 15 | 0 | 1 | ctx:5,fabric:4,.agentic-framework:2,tasks:1,docgen:1,docs:1 | PreToolUse:Write|Edit | 1 | 2026-07-10 | 2026-07-10 | T-2517 | - |
| agents/context/check-active-task.sh | 1000 | 18 | 41 | ctx:577,tasks:111,.agentic-framework:105,docs:84,tests:41,fabric:37 | PreToolUse:Write|Edit|Bash | 53 | 2026-02-15 | 2026-09-07 | T-063 | doctor |
| agents/context/check-agent-dispatch.sh | 53 | 0 | 1 | .agentic-framework:12,ctx:12,docs:12,tasks:8,fabric:7,docgen:1 | PreToolUse:Agent | 5 | 2026-03-23 | 2026-04-13 | T-533 | - |
| agents/context/check-arc-id.py | 48 | 6 | 2 | .agentic-framework:10,ctx:9,tasks:8,fabric:7,agents:6,docgen:3 | PreToolUse:Write|Edit | 2 | 2026-05-16 | 2026-06-23 | T-1849 | - |
| agents/context/check-arc-id.sh | 41 | 2 | 1 | ctx:10,.agentic-framework:8,tasks:7,fabric:6,docgen:5,agents:2 | PreToolUse:Write|Edit | 1 | 2026-05-16 | 2026-05-16 | T-1849 | - |
| agents/context/check-dispatch-pre.sh | 73 | 0 | 0 | ctx:58,.agentic-framework:5,docs:5,fabric:2,tasks:2,docgen:1 | NOT-WIRED | 1 | 2026-03-17 | 2026-03-17 | T-509 | - |
| agents/context/check-dispatch.sh | 88 | 3 | 1 | ctx:32,.agentic-framework:22,docs:15,tasks:7,fabric:4,docgen:4 | PostToolUse:Task|TaskOutput | 1 | 2026-02-20 | 2026-02-20 | T-225 | - |
| agents/context/check-fabric-new-file.sh | 41 | 1 | 2 | .agentic-framework:12,docs:10,tasks:7,ctx:4,fabric:3,docgen:2 | PostToolUse:Write | 2 | 2026-03-08 | 2026-03-17 | T-371 | - |
| agents/context/check-heredoc-cmd-sub.sh | 26 | 0 | 1 | ctx:7,fabric:7,.agentic-framework:4,docgen:4,tasks:2,docs:1 | PreToolUse:Write|Edit | 1 | 2026-05-20 | 2026-05-20 | T-1945 | - |
| agents/context/check-human-ac-tick.py | 48 | 4 | 2 | ctx:13,.agentic-framework:9,tasks:7,docs:6,fabric:5,agents:2 | PreToolUse:Write|Edit | 4 | 2026-05-05 | 2026-08-12 | T-1731 | - |
| agents/context/check-human-ac-tick.sh | 17 | 0 | 2 | ctx:6,fabric:3,.agentic-framework:2,tasks:2,tests:2,docgen:1 | PreToolUse:Write|Edit | 1 | 2026-05-05 | 2026-05-05 | T-1731 | - |
| agents/context/check-inception-decisions.py | 30 | 3 | 1 | ctx:8,fabric:6,.agentic-framework:5,tasks:3,agents:3,docgen:2 | PreToolUse:Write|Edit | 2 | 2026-05-22 | 2026-06-23 | T-1984 | - |
| agents/context/check-inception-decisions.sh | 20 | 1 | 1 | ctx:6,.agentic-framework:4,fabric:4,docgen:2,tasks:1,agents:1 | PreToolUse:Write|Edit | 1 | 2026-05-22 | 2026-05-22 | T-1984 | - |
| agents/context/check-inception-recommendation.py | 30 | 3 | 1 | ctx:10,fabric:6,.agentic-framework:4,tasks:3,agents:2,docs:2 | NOT-WIRED | 2 | 2026-06-04 | 2026-06-23 | T-2205 | - |
| agents/context/check-inception-recommendation.sh | 17 | 0 | 1 | ctx:8,fabric:3,.agentic-framework:2,tasks:1,docgen:1,docs:1 | NOT-WIRED | 1 | 2026-06-04 | 2026-06-04 | T-2205 | - |
| agents/context/check-inception-schema.py | 34 | 2 | 1 | ctx:12,.agentic-framework:5,fabric:5,tasks:4,agents:2,docgen:2 | PreToolUse:Write|Edit | 2 | 2026-06-03 | 2026-06-23 | T-2188 | - |
| agents/context/check-inception-schema.sh | 18 | 1 | 0 | ctx:6,fabric:5,.agentic-framework:3,tasks:1,agents:1,docgen:1 | PreToolUse:Write|Edit | 1 | 2026-06-03 | 2026-06-03 | T-2188 | - |
| agents/context/check-onboarding-gate.py | 30 | 2 | 2 | ctx:6,tasks:6,fabric:5,docgen:4,.agentic-framework:3,agents:2 | PreToolUse:Write|Edit | 2 | 2026-08-06 | 2026-08-08 | T-2815 | - |
| agents/context/check-onboarding-gate.sh | 14 | 0 | 1 | ctx:6,fabric:4,.agentic-framework:1,tasks:1,docgen:1,tests:1 | PreToolUse:Write|Edit | 1 | 2026-08-06 | 2026-08-06 | T-2815 | - |
| agents/context/checkpoint.sh | 526 | 16 | 20 | ctx:238,tasks:81,.agentic-framework:76,docs:64,tests:20,fabric:18 | PostToolUse:* | 44 | 2026-02-14 | 2026-09-07 | T-059 | audit+doctor |
| agents/context/check-project-boundary.sh | 277 | 2 | 7 | ctx:173,tasks:29,.agentic-framework:26,docs:26,fabric:11,tests:7 | PreToolUse:Write|Edit|Bash | 15 | 2026-03-23 | 2026-08-18 | T-559 | doctor |
| agents/context/check-rail-mcp-label.sh | 80 | 1 | 1 | ctx:65,fabric:6,tasks:3,.agentic-framework:2,docgen:1,docs:1 | PreToolUse:mcp__termlink__termlink_channel_post | 3 | 2026-08-10 | 2026-08-10 | T-2911 | - |
| agents/context/check-settings-edit.sh | 21 | 0 | 1 | ctx:5,fabric:5,.agentic-framework:4,tasks:2,docgen:2,docs:2 | PostToolUse:Write|Edit | 1 | 2026-05-17 | 2026-05-17 | T-1687 | - |
| agents/context/check-task-ac-structure.py | 25 | 1 | 1 | ctx:5,.agentic-framework:4,fabric:4,tasks:4,docgen:3,docs:3 | NOT-WIRED | 1 | 2026-06-16 | 2026-06-16 | T-2420 | - |
| agents/context/check-task-ac-structure.sh | 17 | 0 | 1 | ctx:5,fabric:3,tasks:3,.agentic-framework:2,docs:2,docgen:1 | NOT-WIRED | 1 | 2026-06-16 | 2026-06-16 | T-2420 | - |
| agents/context/check-tier0.sh | 484 | 11 | 12 | ctx:198,.agentic-framework:95,docs:70,tasks:58,docgen:19,fabric:18 | PreToolUse:Bash | 24 | 2026-02-17 | 2026-08-20 | T-092 | audit+doctor |
| agents/context/check-visual-verification.AGENT.md | 6 | 0 | 0 | ctx:2,tasks:2,.agentic-framework:1,docs:1 |  | 1 | 2026-05-30 | 2026-05-30 | T-2128 | - |
| agents/context/check-visual-verification.sh | 83 | 1 | 0 | ctx:68,tasks:6,.agentic-framework:3,fabric:2,docs:2,agents:1 | NOT-WIRED | 3 | 2026-05-30 | 2026-06-23 | T-2128 | - |
| agents/context/check-worktree-governance-write.sh | 23 | 2 | 1 | fabric:6,ctx:5,tasks:3,.agentic-framework:2,docs:2,docgen:2 | PreToolUse:Write|Edit | 1 | 2026-08-20 | 2026-08-20 | T-3098 | - |
| agents/context/commit-cadence.sh | 76 | 0 | 0 | ctx:56,docs:7,.agentic-framework:6,fabric:3,tasks:3,docgen:1 | PostToolUse:Write|Edit | 1 | 2026-03-24 | 2026-03-24 | T-591 | - |
| agents/context/consolidate.py | 34 | 2 | 0 | .agentic-framework:7,ctx:7,docs:7,tasks:6,fabric:4,bin:1 | NOT-WIRED | 2 | 2026-02-19 | 2026-07-05 | T-189 | - |
| agents/context/context.sh | 168 | 14 | 8 | ctx:42,.agentic-framework:37,fabric:21,tasks:21,docs:21,agents:9 | NOT-WIRED | 7 | 2026-02-13 | 2026-03-11 | T-005 | audit+doctor |
| agents/context/continuous-driver.sh | 51 | 2 | 3 | ctx:27,tools:6,tasks:5,fabric:3,tests:3,CRON:2 | NOT-WIRED | 6 | 2026-09-03 | 2026-09-05 | T-3254 | - |
| agents/context/error-watchdog.sh | 77 | 4 | 1 | .agentic-framework:26,docs:21,ctx:12,fabric:6,tasks:5,agents:2 | PostToolUse:Bash | 2 | 2026-02-17 | 2026-02-17 | T-118 | audit+doctor |
| agents/context/inject-next-directive.py | 115 | 4 | 6 | ctx:58,tasks:17,fabric:9,docs:9,.agentic-framework:8,tests:6 | NOT-WIRED | 8 | 2026-06-13 | 2026-09-03 | T-2364 | - |
| agents/context/lib/decision.sh | 53 | 1 | 4 | ctx:19,tasks:8,.agentic-framework:7,fabric:6,docs:5,tests:4 |  | 8 | 2026-02-13 | 2026-05-18 | T-005 | - |
| agents/context/lib/episodic.sh | 252 | 5 | 7 | ctx:181,tasks:18,.agentic-framework:13,docs:13,fabric:12,tests:7 |  | 19 | 2026-02-13 | 2026-08-25 | T-005 | - |
| agents/context/lib/extract_decisions.py | 101 | 1 | 2 | ctx:88,docs:3,.agentic-framework:2,fabric:2,tasks:2,tests:2 |  | 1 | 2026-08-15 | 2026-08-15 | T-3015 | - |
| agents/context/lib/focus.sh | 182 | 3 | 6 | ctx:117,tasks:22,.agentic-framework:12,docs:11,fabric:8,tests:6 |  | 14 | 2026-02-13 | 2026-08-16 | T-005 | - |
| agents/context/lib/init.sh | 696 | 17 | 30 | ctx:293,tasks:142,.agentic-framework:95,docs:63,fabric:32,tests:30 |  | 16 | 2026-02-13 | 2026-06-21 | T-005 | audit |
| agents/context/lib/learning.sh | 109 | 5 | 6 | ctx:39,.agentic-framework:17,tasks:15,fabric:12,docs:10,tests:6 |  | 12 | 2026-02-13 | 2026-08-10 | T-005 | - |
| agents/context/lib/memory-recall.py | 131 | 2 | 1 | ctx:96,docs:9,fabric:8,.agentic-framework:7,tasks:7,agents:1 |  | 2 | 2026-02-22 | 2026-08-17 | T-246 | - |
| agents/context/lib/pattern.sh | 138 | 1 | 3 | ctx:102,tasks:8,.agentic-framework:7,fabric:7,docs:7,docgen:3 |  | 7 | 2026-02-13 | 2026-08-16 | T-005 | - |
| agents/context/lib/safe-commands.sh | 298 | 2 | 15 | ctx:211,tasks:34,tests:15,fabric:13,docs:12,.agentic-framework:8 |  | 23 | 2026-03-28 | 2026-09-07 | T-650 | - |
| agents/context/lib/status.sh | 73 | 8 | 2 | ctx:20,.agentic-framework:17,tasks:7,fabric:6,docs:6,docgen:5 |  | 3 | 2026-02-13 | 2026-03-11 | T-005 | - |
| agents/context/loop-detect.sh | 28 | 0 | 0 | .agentic-framework:7,tasks:6,docs:6,ctx:5,fabric:3,docgen:1 | PostToolUse:* | 1 | 2026-03-24 | 2026-03-24 | T-594 | - |
| agents/context/pl007-scanner.sh | 66 | 0 | 0 | ctx:56,tasks:3,.agentic-framework:2,fabric:2,docs:2,docgen:1 | NOT-WIRED | 2 | 2026-04-22 | 2026-04-25 | T-1188 | - |
| agents/context/post-compact-resume.sh | 284 | 5 | 7 | ctx:161,tasks:49,.agentic-framework:25,docs:23,fabric:9,tests:7 | SessionStart:compact; SessionStart:resume; SessionStart:startup | 23 | 2026-02-17 | 2026-09-04 | T-111 | audit |
| agents/context/pre-compact.sh | 133 | 5 | 5 | ctx:43,.agentic-framework:25,tasks:21,docs:15,fabric:13,docgen:6 | PreCompact:* | 13 | 2026-02-17 | 2026-07-06 | T-111 | audit |
| agents/context/revisit-due-scan.sh | 35 | 3 | 4 | .agentic-framework:8,ctx:8,tests:4,fabric:3,tasks:3,docgen:3 | NOT-WIRED | 3 | 2026-05-15 | 2026-08-08 | T-1452 | - |
| agents/context/session-end.sh | 34 | 4 | 1 | ctx:9,.agentic-framework:7,tasks:6,fabric:3,agents:3,docgen:2 | NOT-WIRED | 3 | 2026-04-24 | 2026-08-26 | T-1212 | - |
| agents/context/session-metrics.sh | 114 | 2 | 0 | ctx:76,.agentic-framework:11,tasks:8,docs:7,fabric:6,docgen:4 | NOT-WIRED | 4 | 2026-04-04 | 2026-06-14 | T-831 | - |
| agents/context/session-silent-scanner.sh | 34 | 3 | 0 | ctx:16,.agentic-framework:5,tasks:5,fabric:3,agents:3,docgen:1 | NOT-WIRED | 3 | 2026-04-24 | 2026-04-25 | T-1212 | - |
| agents/context/stop-driver.sh | 97 | 6 | 7 | ctx:49,tasks:15,docs:11,tests:7,.agentic-framework:5,fabric:3 | Stop:* | 4 | 2026-08-26 | 2026-08-31 | T-3164 | doctor |
| agents/context/stop-guard.sh | 21 | 2 | 0 | ctx:6,.agentic-framework:4,tasks:4,fabric:2,docs:2,agents:1 | NOT-WIRED | 2 | 2026-04-24 | 2026-04-25 | T-1211 | - |
| agents/context/subagent-stop.sh | 18 | 2 | 0 | .agentic-framework:4,tasks:4,ctx:3,fabric:3,agents:2,docgen:1 | NOT-WIRED | 2 | 2026-04-24 | 2026-04-25 | T-1213 | - |
| agents/context/tests/fw-task-revisit-due-test.sh | 6 | 0 | 0 | .agentic-framework:2,ctx:2,fabric:1,docs:1 |  | 1 | 2026-05-16 | 2026-05-16 | T-1453 | - |
| agents/context/tests/revisit-due-scan-test.sh | 9 | 0 | 0 | ctx:4,.agentic-framework:2,fabric:1,tasks:1,docs:1 |  | 1 | 2026-05-15 | 2026-05-15 | T-1452 | - |
| agents/context/tests/session-end-stub-test.sh | 7 | 0 | 0 | .agentic-framework:2,ctx:2,fabric:2,docs:1 |  | 1 | 2026-04-24 | 2026-04-24 | T-1212 | - |
| agents/context/tests/session-silent-scanner-stub-test.sh | 7 | 0 | 0 | .agentic-framework:2,ctx:2,fabric:2,docs:1 |  | 1 | 2026-04-24 | 2026-04-24 | T-1212 | - |
| agents/context/tests/stop-guard-stub-test.sh | 7 | 0 | 0 | .agentic-framework:2,ctx:2,fabric:2,docs:1 |  | 1 | 2026-04-24 | 2026-04-24 | T-1211 | - |
| agents/context/tests/subagent-stop-stub-test.sh | 9 | 0 | 0 | ctx:4,.agentic-framework:2,fabric:2,docs:1 |  | 1 | 2026-04-24 | 2026-04-24 | T-1213 | - |
| agents/context/test-tier0-patterns.py | 15 | 0 | 0 | ctx:8,.agentic-framework:2,tasks:2,fabric:1,docgen:1,docs:1 | NOT-WIRED | 3 | 2026-02-17 | 2026-02-17 | T-092 | - |
| agents/designer/designer.sh | 50 | 2 | 4 | ctx:13,tasks:11,docs:8,fabric:6,.agentic-framework:5,tests:4 |  | 6 | 2026-07-10 | 2026-08-30 | T-2521 | doctor |
| agents/dispatch/AGENT.md | 5 | 0 | 0 | ctx:3,.agentic-framework:1,docs:1 |  | 1 | 2026-02-17 | 2026-02-17 | T-099 | - |
| agents/dispatch/audit.md | 133 | 2 | 1 | ctx:82,tasks:28,.agentic-framework:10,docs:10,agents:2,tests:1 |  | 1 | 2026-02-17 | 2026-02-17 | T-099 | - |
| agents/dispatch/develop.md | 9 | 1 | 0 | ctx:3,.agentic-framework:2,docs:2,tasks:1,agents:1 |  | 1 | 2026-02-17 | 2026-02-17 | T-099 | - |
| agents/dispatch/enrich.md | 12 | 1 | 0 | ctx:5,.agentic-framework:2,tasks:2,docs:2,agents:1 |  | 1 | 2026-02-17 | 2026-02-17 | T-099 | - |
| agents/dispatch/investigate.md | 21 | 1 | 0 | vendor:10,ctx:4,.agentic-framework:3,docs:2,tasks:1,agents:1 |  | 1 | 2026-02-17 | 2026-02-17 | T-099 | - |
| agents/dispatch/preamble.md | 141 | 3 | 1 | ctx:84,.agentic-framework:18,docs:15,tasks:14,fabric:3,agents:3 |  | 7 | 2026-02-20 | 2026-08-20 | T-217 | - |
| agents/dispatch/single-host-parallel-demo.sh | 30 | 1 | 1 | ctx:8,.agentic-framework:7,docs:6,tasks:4,fabric:2,agents:1 |  | 1 | 2026-06-11 | 2026-06-11 | T-2341 | - |
| agents/dispatch/yield-point.sh | 31 | 3 | 1 | .agentic-framework:8,docs:5,ctx:4,docgen:4,fabric:3,tasks:3 |  | 1 | 2026-06-11 | 2026-06-11 | T-2338 | - |
| agents/docgen/generate_article.py | 29 | 1 | 1 | .agentic-framework:7,ctx:6,tasks:5,fabric:4,docs:4,agents:1 |  | 2 | 2026-03-09 | 2026-06-06 | T-366 | - |
| agents/docgen/generate-article.sh | 34 | 1 | 1 | ctx:12,.agentic-framework:6,fabric:5,tasks:4,docgen:3,docs:2 |  | 3 | 2026-03-09 | 2026-03-30 | T-366 | - |
| agents/docgen/generate_component.py | 29 | 1 | 2 | tasks:7,.agentic-framework:5,ctx:5,fabric:4,docs:3,docgen:2 |  | 3 | 2026-03-08 | 2026-06-06 | T-364 | - |
| agents/docgen/generate-component.sh | 33 | 2 | 1 | ctx:8,.agentic-framework:7,fabric:5,tasks:5,docgen:3,docs:2 |  | 3 | 2026-03-08 | 2026-05-25 | T-364 | - |
| agents/docgen/test_docgen.py | 11 | 0 | 1 | ctx:3,fabric:2,tasks:2,.agentic-framework:1,docgen:1,docs:1 |  | 1 | 2026-03-09 | 2026-03-09 | T-387 | - |
| agents/fabric/fabric.sh | 65 | 3 | 2 | .agentic-framework:15,fabric:13,ctx:11,docs:10,tasks:7,docgen:4 |  | 5 | 2026-02-20 | 2026-03-11 | T-208 | - |
| agents/fabric/lib/drift.sh | 171 | 5 | 7 | ctx:108,.agentic-framework:16,tasks:14,docs:10,tests:7,docgen:6 |  | 10 | 2026-02-20 | 2026-08-17 | T-208 | audit+doctor |
| agents/fabric/lib/enrich.py | 241 | 2 | 7 | fabric:111,ctx:87,tasks:13,.agentic-framework:10,docs:9,tests:7 |  | 15 | 2026-02-21 | 2026-08-23 | T-012 | - |
| agents/fabric/lib/expand_patterns.py | 23 | 3 | 2 | .agentic-framework:7,ctx:3,tasks:3,agents:3,fabric:2,docgen:2 |  | 1 | 2026-05-15 | 2026-05-15 | T-1842 | audit |
| agents/fabric/lib/query.sh | 22 | 1 | 0 | .agentic-framework:7,ctx:5,docs:5,fabric:2,docgen:2,agents:1 |  | 2 | 2026-02-20 | 2026-04-27 | T-208 | - |
| agents/fabric/lib/register.sh | 197 | 5 | 6 | ctx:130,.agentic-framework:19,tasks:13,docs:10,fabric:7,docgen:7 |  | 12 | 2026-02-20 | 2026-09-03 | T-208 | audit |
| agents/fabric/lib/summary.sh | 25 | 1 | 0 | ctx:8,.agentic-framework:7,docs:4,fabric:2,docgen:2,tasks:1 |  | 5 | 2026-02-20 | 2026-04-27 | T-208 | - |
| agents/fabric/lib/traverse.sh | 35 | 1 | 0 | .agentic-framework:12,docs:9,ctx:6,docgen:3,fabric:2,tasks:2 |  | 3 | 2026-02-20 | 2026-04-27 | T-208 | - |
| agents/fabric/lib/ui.sh | 19 | 1 | 0 | .agentic-framework:6,ctx:5,docs:3,fabric:2,docgen:2,agents:1 |  | 1 | 2026-02-20 | 2026-02-20 | T-208 | - |
| agents/git/AGENT.md | 4 | 0 | 0 | ctx:2,.agentic-framework:1,docs:1 |  | 1 | 2026-02-13 | 2026-02-13 | T-013 | - |
| agents/git/git.sh | 142 | 16 | 10 | .agentic-framework:33,ctx:32,fabric:20,docs:13,tasks:11,agents:11 |  | 11 | 2026-02-13 | 2026-08-11 | T-013 | audit+doctor |
| agents/git/lib/bypass.sh | 24 | 3 | 0 | ctx:9,.agentic-framework:6,fabric:3,agents:3,docgen:2,docs:1 |  | 1 | 2026-02-13 | 2026-02-13 | T-013 | - |
| agents/git/lib/commit.sh | 105 | 2 | 1 | ctx:80,.agentic-framework:8,docs:5,fabric:3,tasks:3,docgen:3 |  | 3 | 2026-02-13 | 2026-08-19 | T-013 | - |
| agents/git/lib/common.sh | 42 | 4 | 4 | ctx:12,.agentic-framework:8,fabric:5,tasks:5,tests:4,agents:3 |  | 6 | 2026-02-13 | 2026-08-05 | T-013 | doctor |
| agents/git/lib/dup-task-scan.sh | 30 | 2 | 1 | ctx:10,.agentic-framework:5,tasks:5,fabric:3,agents:2,docgen:2 |  | 1 | 2026-05-15 | 2026-05-15 | T-1863 | - |
| agents/git/lib/hooks.sh | 429 | 6 | 12 | ctx:256,tasks:77,.agentic-framework:29,docs:27,fabric:17,tests:12 |  | 61 | 2026-02-13 | 2026-09-07 | T-013 | audit |
| agents/git/lib/large-file-scan.sh | 33 | 4 | 1 | ctx:8,.agentic-framework:7,fabric:5,tasks:5,agents:3,docs:2 |  | 2 | 2026-05-15 | 2026-08-25 | T-1845 | audit+doctor |
| agents/git/lib/log.sh | 95 | 5 | 4 | ctx:29,.agentic-framework:20,docgen:12,tasks:11,fabric:9,docs:4 |  | 1 | 2026-02-13 | 2026-02-13 | T-013 | - |
| agents/git/lib/master-guard.sh | 40 | 2 | 2 | ctx:15,.agentic-framework:7,tasks:6,fabric:4,tests:2,.framework.yaml:1 |  | 2 | 2026-06-14 | 2026-07-28 | T-2396 | - |
| agents/git/lib/secret-scan.sh | 129 | 2 | 4 | ctx:82,tasks:18,.agentic-framework:8,fabric:7,docs:5,tests:4 |  | 6 | 2026-05-15 | 2026-08-25 | T-1844 | audit |
| agents/git/lib/status.sh | 73 | 8 | 2 | ctx:20,.agentic-framework:17,tasks:7,fabric:6,docs:6,docgen:5 |  | 2 | 2026-02-13 | 2026-04-27 | T-013 | - |
| agents/git/lib/worker-commits.sh | 16 | 1 | 1 | ctx:6,fabric:3,.agentic-framework:2,docgen:2,tasks:1,agents:1 |  | 1 | 2026-08-11 | 2026-08-11 | T-2917 | - |
| agents/git/lib/worktree-corpus-guard.sh | 16 | 2 | 1 | ctx:5,.agentic-framework:3,fabric:2,tasks:1,agents:1,docgen:1 |  | 1 | 2026-08-20 | 2026-08-20 | T-3110 | - |
| agents/govd/govd.sh | 24 | 1 | 0 | ctx:6,fabric:6,.agentic-framework:4,tasks:4,docs:2,docgen:1 |  | 2 | 2026-06-18 | 2026-06-18 | T-2430 | - |
| agents/gpu-recover/AGENT.md | 3 | 0 | 0 | .agentic-framework:1,ctx:1,docs:1 |  | 1 | 2026-04-25 | 2026-04-25 | T-1182 | - |
| agents/gpu-recover/recover.sh | 118 | 4 | 2 | ctx:77,.agentic-framework:12,tasks:7,fabric:6,docgen:5,docs:4 |  | 1 | 2026-04-25 | 2026-04-25 | T-1182 | - |
| agents/handover/AGENT.md | 93 | 0 | 0 | ctx:90,.agentic-framework:1,tasks:1,docs:1 |  | 3 | 2026-02-13 | 2026-08-16 | T-012 | - |
| agents/handover/discard-manifest.sh | 186 | 1 | 4 | ctx:162,.agentic-framework:5,fabric:5,tasks:5,tests:4,docs:3 |  | 4 | 2026-06-13 | 2026-08-17 | T-2366 | - |
| agents/handover/handover.sh | 605 | 22 | 34 | ctx:265,tasks:123,.agentic-framework:68,fabric:38,docs:35,tests:34 |  | 81 | 2026-02-13 | 2026-08-29 | T-012 | audit+doctor |
| agents/healing/AGENT.md | 4 | 0 | 0 | ctx:2,.agentic-framework:1,docs:1 |  | 1 | 2026-02-13 | 2026-02-13 | T-007 | - |
| agents/healing/healing.sh | 94 | 8 | 2 | ctx:26,.agentic-framework:20,tasks:13,fabric:12,docs:9,agents:6 |  | 8 | 2026-02-13 | 2026-04-05 | T-007 | doctor |
| agents/healing/lib/diagnose.sh | 52 | 1 | 1 | ctx:18,.agentic-framework:11,tasks:7,docs:7,fabric:4,docgen:3 |  | 6 | 2026-02-13 | 2026-04-09 | T-007 | - |
| agents/healing/lib/patterns.sh | 19 | 1 | 0 | ctx:7,.agentic-framework:4,fabric:2,tasks:2,docgen:2,agents:1 |  | 2 | 2026-02-13 | 2026-03-11 | T-007 | - |
| agents/healing/lib/resolve.sh | 70 | 5 | 3 | ctx:26,tasks:14,.agentic-framework:12,docgen:4,docs:4,tests:3 |  | 5 | 2026-02-13 | 2026-08-09 | T-007 | audit |
| agents/healing/lib/suggest.sh | 32 | 1 | 1 | ctx:13,.agentic-framework:5,tasks:5,fabric:3,docgen:3,agents:1 |  | 3 | 2026-02-13 | 2026-04-05 | T-007 | - |
| agents/mcp/framework-mcp-manifest.json | 65 | 6 | 7 | .agentic-framework:12,docs:10,docgen:9,ctx:8,tasks:8,tests:7 |  | 6 | 2026-06-08 | 2026-08-05 | T-2265 | audit+doctor |
| agents/mcp/framework-mcp.mcp-fragment.json | 30 | 1 | 1 | ctx:9,.agentic-framework:7,tasks:5,docs:4,docgen:2,fabric:1 |  | 2 | 2026-06-09 | 2026-06-09 | T-2272 | - |
| agents/mcp/framework_mcp_server.py | 51 | 5 | 4 | .agentic-framework:12,tasks:8,ctx:7,docs:6,fabric:5,tests:4 |  | 2 | 2026-06-08 | 2026-06-22 | T-2265 | - |
| agents/mcp/manifest.py | 346 | 9 | 8 | ctx:262,.agentic-framework:19,fabric:17,tasks:16,docs:9,tests:8 |  | 3 | 2026-06-08 | 2026-06-22 | T-2265 | audit+doctor |
| agents/mcp/mcp-reaper.sh | 23 | 1 | 0 | ctx:7,.agentic-framework:6,tasks:3,fabric:2,docgen:2,docs:2 |  | 2 | 2026-02-19 | 2026-03-30 | T-180 | - |
| agents/metrics/api-usage.sh | 19 | 1 | 0 | ctx:9,.agentic-framework:3,fabric:2,docs:2,tasks:1,bin:1 |  | 13 | 2026-04-27 | 2026-05-06 | T-1304 | - |
| agents/monitor/liveness-check.sh | 46 | 6 | 0 | ctx:17,.agentic-framework:8,tasks:7,docs:4,SETTINGS:2,CRON:2 |  | 4 | 2026-04-15 | 2026-07-28 | T-1269 | - |
| agents/monitor/watchtower-rss-sample.sh | 69 | 2 | 0 | ctx:57,.agentic-framework:4,docs:3,CRON:2,fabric:1,tasks:1 |  | 1 | 2026-04-30 | 2026-04-30 | T-1615 | - |
| agents/observe/observe.sh | 138 | 1 | 6 | ctx:88,tasks:15,.agentic-framework:10,fabric:8,docs:6,tests:6 |  | 15 | 2026-02-14 | 2026-08-13 | T-039 | - |
| agents/onboarding-test/AGENT.md | 9 | 0 | 0 | tasks:3,.agentic-framework:2,ctx:2,docs:2 |  | 1 | 2026-03-04 | 2026-03-04 | T-318 | - |
| agents/onboarding-test/test-onboarding.sh | 51 | 2 | 0 | ctx:16,.agentic-framework:9,tasks:9,fabric:8,docs:5,docgen:2 |  | 5 | 2026-03-04 | 2026-08-12 | T-317 | - |
| agents/orchestrator/orchestrator-graph.py | 35 | 2 | 2 | .agentic-framework:10,ctx:6,docs:6,fabric:4,tasks:3,docgen:2 |  | 3 | 2026-06-11 | 2026-06-11 | T-2339 | - |
| agents/resume/AGENT.md | 13 | 0 | 2 | ctx:5,.agentic-framework:2,tasks:2,tests:2,docgen:1,docs:1 |  | 2 | 2026-02-13 | 2026-06-10 | T-020 | - |
| agents/resume/resume.sh | 423 | 8 | 10 | ctx:248,tasks:69,.agentic-framework:37,docs:30,fabric:13,tests:10 |  | 22 | 2026-02-13 | 2026-08-17 | T-020 | audit+doctor |
| agents/session-capture/AGENT.md | 21 | 2 | 1 | .agentic-framework:5,ctx:5,fabric:2,tasks:2,CLAUDE.md:1,FRAMEWORK.md:1 |  | 3 | 2026-02-13 | 2026-02-14 | T-001 | - |
| agents/sessions/antigravity/list.sh | 70 | 5 | 1 | ctx:43,.agentic-framework:7,tasks:5,fabric:4,docs:3,lib:2 |  | 2 | 2026-08-14 | 2026-08-15 | T-100201 | - |
| agents/sessions/antigravity/provision.sh | 4 | 1 | 0 | .agentic-framework:2,fabric:1,lib:1 |  | 2 | 2026-08-25 | 2026-08-25 | T-3129 | - |
| agents/sessions/claude-code/list.sh | 70 | 5 | 1 | ctx:43,.agentic-framework:7,tasks:5,fabric:4,docs:3,lib:2 |  | 2 | 2026-06-16 | 2026-06-16 | T-2417 | - |
| agents/sessions/render.py | 48 | 5 | 1 | tasks:13,.agentic-framework:11,ctx:10,docs:4,agents:3,fabric:2 |  | 2 | 2026-06-16 | 2026-06-16 | T-2417 | - |
| agents/sessions/SCHEMA.md | 28 | 4 | 2 | .agentic-framework:9,docgen:4,fabric:3,agents:3,ctx:2,tasks:2 |  | 1 | 2026-06-16 | 2026-06-16 | T-2417 | - |
| agents/task-create/AGENT.md | 12 | 0 | 0 | ctx:6,tasks:4,.agentic-framework:1,docs:1 |  | 3 | 2026-02-13 | 2026-06-01 | T-002 | - |
| agents/task-create/create-task.sh | 408 | 18 | 15 | ctx:190,tasks:73,.agentic-framework:51,docs:33,fabric:18,tests:15 |  | 37 | 2026-02-13 | 2026-08-20 | T-002 | audit+doctor |
| agents/task-create/tests/revisit-at-preservation-test.sh | 5 | 0 | 0 | ctx:2,.agentic-framework:1,fabric:1,docs:1 |  | 1 | 2026-05-15 | 2026-05-15 | T-1451 | - |
| agents/task-create/update-task.sh | 1709 | 30 | 92 | ctx:733,tasks:467,.agentic-framework:169,docs:104,tests:92,fabric:56 |  | 119 | 2026-02-14 | 2026-09-07 | T-041 | audit |
| agents/termlink/AGENT.md | 13 | 0 | 0 | .agentic-framework:4,ctx:4,docs:4,tasks:1 |  | 3 | 2026-03-16 | 2026-03-16 | T-502 | - |
| agents/termlink/bvp-estimator/AGENT.md | 9 | 0 | 0 | .agentic-framework:2,ctx:2,tasks:2,fabric:1,docgen:1,docs:1 |  | 1 | 2026-05-19 | 2026-05-19 | T-1922 | - |
| agents/termlink/bvp-estimator/bvp-estimator.sh | 38 | 4 | 1 | .agentic-framework:9,ctx:8,tasks:6,fabric:5,agents:4,docs:4 |  | 2 | 2026-05-19 | 2026-08-17 | T-1922 | - |
| agents/termlink/bvp-estimator/estimator.py | 209 | 6 | 5 | ctx:118,tasks:37,.agentic-framework:16,docs:11,fabric:10,docgen:6 |  | 17 | 2026-05-19 | 2026-08-17 | T-1922 | - |
| agents/termlink/termlink.sh | 310 | 4 | 12 | ctx:155,tasks:48,.agentic-framework:40,docs:33,fabric:12,tests:12 |  | 33 | 2026-03-16 | 2026-08-25 | T-502 | - |
| agents/ux-review/AGENT.md | 5 | 0 | 0 | ctx:2,.agentic-framework:1,tasks:1,docs:1 |  | 2 | 2026-05-23 | 2026-05-23 | T-2002 | - |
| agents/ux-review/ux-review.py | 80 | 2 | 14 | fabric:17,.agentic-framework:15,tests:14,tasks:12,docgen:11,ctx:7 |  | 6 | 2026-05-23 | 2026-05-29 | T-2002 | - |
| bin/claude-fw | 1319 | 15 | 32 | ctx:1040,tasks:87,docs:61,.agentic-framework:57,tests:32,docgen:17 |  | 20 | 2026-02-19 | 2026-09-07 | T-187 | audit+doctor |
| bin/claude-fw-router | 17 | 0 | 1 | docgen:4,.agentic-framework:3,ctx:3,fabric:3,tasks:2,install.sh:1 |  | 1 | 2026-08-07 | 2026-08-07 | T-2856 | - |
| bin/fw | 10881 | 369 | 711 | ctx:3872,tasks:2735,.agentic-framework:1442,tests:711,docs:700,docgen:586 |  | 391 | 2026-02-14 | 2026-09-07 | T-033 | audit+doctor |
| bin/fw-router | 146 | 5 | 10 | ctx:78,tasks:19,.agentic-framework:16,tests:10,docgen:8,fabric:5 |  | 10 | 2026-08-04 | 2026-08-07 | T-2793 | audit |
| bin/fw-shim | 375 | 3 | 3 | ctx:328,.agentic-framework:16,tasks:10,docs:8,tests:3,fabric:2 |  | 3 | 2026-03-28 | 2026-08-04 | T-664 | audit |
| bin/hook-enable.sh | 153 | 2 | 5 | ctx:109,tasks:11,.agentic-framework:10,docs:7,fabric:5,tests:5 |  | 7 | 2026-04-22 | 2026-08-26 | T-1190 | - |
| bin/integrate-go-live.sh | 31 | 1 | 2 | ctx:9,.agentic-framework:6,tasks:6,docs:3,fabric:2,docgen:2 |  | 3 | 2026-06-24 | 2026-06-25 | T-2482 | - |
| bin/migrate-horizon-null-completed.sh | 105 | 2 | 4 | ctx:71,.agentic-framework:9,tasks:9,docs:4,tests:4,fabric:3 |  | 3 | 2026-06-01 | 2026-08-23 | T-2161 | audit |
| bin/watchtower.sh | 519 | 12 | 10 | ctx:368,.agentic-framework:39,tasks:35,docs:27,fabric:20,tests:10 |  | 18 | 2026-02-22 | 2026-09-05 | T-250 | audit+doctor |
| lib/aef_address.py | 25 | 3 | 11 | tests:11,ctx:4,.agentic-framework:3,tasks:3,lib:3,fabric:1 |  | 1 | 2026-09-07 | 2026-09-07 | T-3307 | - |
| lib/aef_circuit.py | 13 | 2 | 2 | .agentic-framework:3,tasks:3,ctx:2,lib:2,tests:2,fabric:1 |  | 1 | 2026-09-07 | 2026-09-07 | T-3308 | - |
| lib/aef_election.py | 21 | 2 | 5 | ctx:8,tests:5,.agentic-framework:3,tasks:2,lib:2,fabric:1 |  | 2 | 2026-09-07 | 2026-09-07 | T-3310 | - |
| lib/aef_governor.py | 9 | 2 | 1 | .agentic-framework:2,ctx:2,fabric:1,tasks:1,lib:1,tests:1 |  | 1 | 2026-09-07 | 2026-09-07 | T-3311 | - |
| lib/aef_provision_log.py | 7 | 1 | 1 | .agentic-framework:2,ctx:1,fabric:1,tasks:1,bin:1,tests:1 |  | 1 | 2026-09-07 | 2026-09-07 | T-3313 | - |
| lib/aef_repo_source.py | 15 | 0 | 2 | ctx:9,tasks:2,tests:2,.agentic-framework:1,fabric:1 |  | 2 | 2026-09-07 | 2026-09-07 | T-3312 | - |
| lib/aef_resolve.py | 24 | 3 | 8 | tests:8,.agentic-framework:4,ctx:4,tasks:4,lib:3,fabric:1 |  | 2 | 2026-09-07 | 2026-09-07 | T-3309 | - |
| lib/antigravity_bridge.py | 53 | 1 | 0 | ctx:44,tasks:3,.agentic-framework:2,fabric:1,agents:1,docgen:1 |  | 3 | 2026-08-14 | 2026-08-25 | T-100201 | - |
| lib/antigravity_steps.py | 4 | 0 | 0 | .agentic-framework:1,fabric:1,tasks:1,docgen:1 |  | 2 | 2026-08-25 | 2026-08-25 | T-3129 | - |
| lib/arc_membership.py | 45 | 6 | 2 | .agentic-framework:13,docgen:8,fabric:6,tasks:5,ctx:4,web:3 |  | 1 | 2026-05-17 | 2026-05-17 | T-1880 | audit |
| lib/arc_membership.sh | 90 | 4 | 5 | ctx:42,.agentic-framework:13,tasks:9,fabric:8,docgen:7,tests:5 |  | 2 | 2026-05-17 | 2026-05-19 | T-1880 | audit |
| lib/arc.sh | 338 | 11 | 20 | ctx:137,tasks:71,.agentic-framework:42,docs:27,fabric:23,tests:20 |  | 26 | 2026-05-01 | 2026-08-13 | T-1661 | audit |
| lib/ask.py | 206 | 4 | 2 | ctx:119,tasks:25,.agentic-framework:19,fabric:18,docs:15,docgen:4 |  | 3 | 2026-02-24 | 2026-08-16 | T-264 | - |
| lib/ask.sh | 2619 | 57 | 139 | ctx:1156,tasks:602,.agentic-framework:283,docs:186,tests:139,fabric:103 |  | 3 | 2026-02-24 | 2026-03-10 | T-264 | audit+doctor |
| lib/assumption.sh | 40 | 2 | 1 | .agentic-framework:10,docs:8,ctx:7,tasks:5,fabric:4,docgen:3 |  | 3 | 2026-02-16 | 2026-07-05 | T-081 | - |
| lib/audit-anchor-task.sh | 6 | 1 | 1 | .agentic-framework:1,ctx:1,fabric:1,tasks:1,agents:1,tests:1 |  | 1 | 2026-09-09 | 2026-09-09 | T-3356 | audit |
| lib/audit_timing.py | 20 | 1 | 2 | tasks:6,ctx:3,fabric:3,.agentic-framework:2,docs:2,tests:2 |  | 2 | 2026-08-27 | 2026-08-29 | T-3127 | - |
| lib/bats_red_attribution.py | 10 | 1 | 1 | fabric:3,ctx:2,.agentic-framework:1,tasks:1,agents:1,docgen:1 |  | 1 | 2026-08-24 | 2026-08-24 | T-3126 | audit |
| lib/branch-hygiene.sh | 186 | 7 | 10 | ctx:120,tasks:23,.agentic-framework:10,tests:10,fabric:7,docs:6 |  | 12 | 2026-07-04 | 2026-09-11 | T-100143 | audit |
| lib/build.sh | 42 | 4 | 3 | .agentic-framework:9,tasks:8,ctx:5,docs:5,fabric:3,docgen:3 |  | 1 | 2026-03-24 | 2026-03-24 | T-592 | - |
| lib/bus.sh | 107 | 6 | 1 | ctx:27,.agentic-framework:24,tasks:19,docs:18,fabric:7,docgen:5 |  | 6 | 2026-02-17 | 2026-07-05 | T-109 | - |
| lib/bvp.sh | 267 | 9 | 7 | ctx:136,tasks:59,.agentic-framework:25,docs:19,fabric:8,tests:7 |  | 25 | 2026-05-19 | 2026-08-17 | T-1919 | audit |
| lib/cmd_classify.py | 21 | 1 | 3 | ctx:5,fabric:5,.agentic-framework:3,tasks:3,tests:3,agents:1 |  | 2 | 2026-08-11 | 2026-08-11 | T-2919 | - |
| lib/colors.sh | 249 | 18 | 57 | ctx:108,tests:57,fabric:31,.agentic-framework:23,agents:13,tasks:8 |  | 2 | 2026-03-11 | 2026-03-30 | T-423 | audit |
| lib/comment_strip.py | 39 | 3 | 2 | .agentic-framework:8,ctx:8,docs:8,fabric:5,tasks:4,agents:2 |  | 1 | 2026-08-12 | 2026-08-12 | T-2954 | - |
| lib/compat.sh | 232 | 4 | 11 | docgen:71,ctx:58,.agentic-framework:57,fabric:17,tests:11,tasks:8 |  | 2 | 2026-03-08 | 2026-04-12 | T-348 | - |
| lib/config-file.sh | 48 | 3 | 1 | ctx:16,tasks:12,.agentic-framework:6,fabric:5,docs:3,SETTINGS:2 |  | 5 | 2026-04-05 | 2026-07-05 | T-889 | - |
| lib/config.sh | 554 | 27 | 17 | ctx:327,tasks:60,.agentic-framework:53,fabric:35,docs:23,tests:17 |  | 30 | 2026-04-03 | 2026-09-11 | T-819 | audit+doctor |
| lib/consumer-recover.sh | 110 | 2 | 2 | ctx:76,.agentic-framework:9,tasks:7,fabric:5,docgen:4,docs:4 |  | 3 | 2026-06-07 | 2026-07-31 | T-2235 | - |
| lib/context_tokens.py | 74 | 4 | 5 | ctx:35,tasks:9,docs:8,fabric:6,.agentic-framework:5,tests:5 |  | 3 | 2026-08-09 | 2026-09-04 | T-2885 | - |
| lib/continuous-mode.sh | 70 | 5 | 3 | ctx:33,tasks:10,fabric:7,docs:6,.agentic-framework:5,agents:4 |  | 8 | 2026-08-26 | 2026-09-03 | T-3169 | audit+doctor |
| lib/corpus-id.sh | 26 | 1 | 2 | ctx:12,fabric:4,.agentic-framework:3,tasks:3,tests:2,agents:1 |  | 1 | 2026-08-10 | 2026-08-10 | T-2902 | - |
| lib/costs.sh | 166 | 4 | 4 | ctx:116,.agentic-framework:13,fabric:9,docs:9,tasks:8,tests:4 |  | 4 | 2026-04-03 | 2026-08-09 | T-801 | - |
| lib/cron_dry_run.py | 26 | 2 | 0 | ctx:10,.agentic-framework:4,fabric:4,tasks:4,agents:1,bin:1 |  | 1 | 2026-05-20 | 2026-05-20 | T-1944 | audit |
| lib/cron-orphans.sh | 25 | 1 | 1 | ctx:15,fabric:3,.agentic-framework:2,docs:2,tasks:1,bin:1 |  | 2 | 2026-09-05 | 2026-09-05 | T-3281 | - |
| lib/cron-registry.sh | 18 | 7 | 1 | CRON:5,ctx:5,fabric:3,.agentic-framework:2,agents:1,bin:1 |  | 1 | 2026-08-07 | 2026-08-07 | T-2844 | audit |
| lib/decided_unclosed.py | 53 | 3 | 3 | ctx:36,fabric:4,.agentic-framework:3,tasks:3,tests:3,web:2 |  | 1 | 2026-08-26 | 2026-08-26 | T-3175 | - |
| lib/dispatch_pause.py | 33 | 4 | 2 | .agentic-framework:9,ctx:5,tasks:5,fabric:3,docs:3,docgen:2 |  | 2 | 2026-05-13 | 2026-05-13 | T-1808 | - |
| lib/dispatch.sh | 190 | 8 | 3 | ctx:52,.agentic-framework:48,docs:34,tasks:24,fabric:13,docgen:8 |  | 4 | 2026-03-21 | 2026-04-27 | T-517 | - |
| lib/doctor-hook-exercise.py | 36 | 3 | 1 | ctx:11,.agentic-framework:7,tasks:7,fabric:3,docgen:2,docs:2 |  | 3 | 2026-05-01 | 2026-08-25 | T-1629 | doctor |
| lib/doctor-upstream.sh | 13 | 1 | 1 | ctx:4,.agentic-framework:3,fabric:2,tasks:1,bin:1,docgen:1 |  | 1 | 2026-08-07 | 2026-08-07 | T-2843 | doctor |
| lib/enums.sh | 145 | 3 | 6 | ctx:87,tasks:16,.agentic-framework:14,fabric:8,docs:6,tests:6 |  | 4 | 2026-03-10 | 2026-07-29 | T-413 | - |
| lib/episodic_footprint.py | 57 | 1 | 1 | ctx:48,fabric:4,.agentic-framework:1,tasks:1,agents:1,docgen:1 |  | 1 | 2026-08-25 | 2026-08-25 | T-3130 | - |
| lib/errors.sh | 87 | 3 | 22 | tests:22,ctx:21,fabric:16,.agentic-framework:12,tasks:5,docs:5 |  | 3 | 2026-03-10 | 2026-03-30 | T-414 | - |
| lib/evolution_log.sh | 48 | 2 | 3 | .agentic-framework:12,ctx:9,docgen:9,tasks:7,fabric:5,tests:3 |  | 4 | 2026-05-04 | 2026-06-06 | T-1718 | - |
| lib/exec-bit-drift.sh | 8 | 2 | 1 | .agentic-framework:3,fabric:1,tasks:1,agents:1,bin:1,tests:1 |  | 1 | 2026-09-07 | 2026-09-07 | T-3317 | audit+doctor |
| lib/firewall.sh | 27 | 1 | 1 | ctx:9,.agentic-framework:6,fabric:3,tasks:3,docgen:3,bin:1 |  | 1 | 2026-04-05 | 2026-04-05 | T-888 | - |
| lib/first-run.sh | 25 | 0 | 1 | .agentic-framework:7,ctx:5,docgen:5,tasks:3,fabric:2,docs:2 |  | 1 | 2026-03-04 | 2026-03-04 | T-304 | - |
| lib/gaps.py | 126 | 1 | 1 | ctx:108,fabric:5,.agentic-framework:4,tasks:3,docs:3,bin:1 |  | 2 | 2026-06-04 | 2026-08-25 | T-2185 | - |
| lib/git-identity.sh | 44 | 8 | 2 | .agentic-framework:11,fabric:10,ctx:8,lib:5,docgen:3,tasks:2 |  | 2 | 2026-08-09 | 2026-08-11 | T-2883 | doctor |
| lib/gitignore-register.sh | 100 | 2 | 1 | ctx:89,fabric:4,.agentic-framework:2,tasks:1,agents:1,docgen:1 |  | 1 | 2026-08-14 | 2026-08-14 | T-2994 | audit |
| lib/govd_envelope.py | 23 | 3 | 1 | .agentic-framework:5,ctx:5,fabric:3,tasks:3,docs:2,agents:1 |  | 1 | 2026-06-18 | 2026-06-18 | T-2430 | - |
| lib/govd_holder.py | 24 | 2 | 2 | fabric:5,.agentic-framework:4,ctx:4,tasks:3,docs:3,tests:2 |  | 1 | 2026-06-18 | 2026-06-18 | T-2430 | - |
| lib/govd_policy.py | 31 | 2 | 1 | ctx:7,fabric:7,tasks:6,.agentic-framework:5,docgen:2,agents:1 |  | 1 | 2026-06-18 | 2026-06-18 | T-2432 | - |
| lib/govd_relay.py | 25 | 3 | 1 | .agentic-framework:5,ctx:5,fabric:5,tasks:3,docs:2,agents:1 |  | 1 | 2026-06-18 | 2026-06-18 | T-2431 | - |
| lib/harvest.sh | 83 | 2 | 3 | ctx:26,.agentic-framework:18,docs:14,tasks:11,fabric:5,docgen:4 |  | 5 | 2026-02-14 | 2026-08-09 | T-035 | - |
| lib/heredoc_guard.py | 18 | 1 | 0 | ctx:8,.agentic-framework:3,fabric:3,tasks:1,agents:1,docgen:1 |  | 1 | 2026-05-20 | 2026-05-20 | T-1945 | - |
| lib/hook_parity.py | 84 | 2 | 3 | ctx:63,fabric:9,.agentic-framework:3,tests:3,tasks:2,lib:2 |  | 1 | 2026-08-21 | 2026-08-21 | T-3113 | - |
| lib/hook-parity.sh | 89 | 4 | 2 | ctx:63,.agentic-framework:5,fabric:5,tasks:4,docs:4,lib:3 |  | 2 | 2026-08-20 | 2026-08-21 | T-3112 | doctor |
| lib/hook_paths.py | 115 | 7 | 3 | ctx:70,.agentic-framework:12,fabric:9,tasks:7,agents:6,docs:6 |  | 3 | 2026-06-23 | 2026-08-04 | T-2468 | - |
| lib/hook_portability.py | 26 | 3 | 0 | ctx:7,.agentic-framework:6,fabric:4,docs:3,tasks:2,lib:2 |  | 1 | 2026-07-31 | 2026-07-31 | T-2709 | doctor |
| lib/hook-telemetry.sh | 27 | 2 | 2 | .agentic-framework:5,tasks:5,ctx:4,fabric:4,docs:4,tests:2 |  | 1 | 2026-05-01 | 2026-05-01 | T-1628 | - |
| lib/hook-threshold.py | 37 | 4 | 1 | .agentic-framework:9,ctx:8,fabric:8,docs:3,tasks:2,docgen:2 |  | 1 | 2026-05-01 | 2026-05-01 | T-1631 | audit |
| lib/human_review_state.py | 11 | 1 | 1 | ctx:3,tasks:3,.agentic-framework:1,fabric:1,agents:1,docs:1 |  | 1 | 2026-09-06 | 2026-09-06 | T-3288 | - |
| lib/inception_decisions.py | 22 | 3 | 1 | ctx:6,.agentic-framework:5,fabric:4,agents:2,tasks:1,docgen:1 |  | 1 | 2026-05-22 | 2026-05-22 | T-1984 | - |
| lib/inception-readiness.sh | 17 | 4 | 1 | .agentic-framework:5,fabric:5,lib:2,ctx:1,tasks:1,agents:1 |  | 1 | 2026-09-05 | 2026-09-05 | T-3279 | - |
| lib/inception_recommendation.sh | 38 | 3 | 2 | ctx:10,.agentic-framework:8,tasks:6,fabric:5,docgen:2,docs:2 |  | 3 | 2026-05-04 | 2026-05-05 | T-1716 | audit |
| lib/inception.sh | 2069 | 18 | 25 | tasks:1434,ctx:442,.agentic-framework:67,docs:51,tests:25,fabric:21 |  | 43 | 2026-02-16 | 2026-09-06 | T-081 | audit |
| lib/index-health.sh | 102 | 3 | 1 | ctx:87,fabric:4,.agentic-framework:3,docgen:2,tasks:1,bin:1 |  | 1 | 2026-08-15 | 2026-08-15 | T-3013 | doctor |
| lib/init.sh | 695 | 16 | 30 | ctx:293,tasks:142,.agentic-framework:95,docs:63,fabric:32,tests:30 |  | 84 | 2026-02-14 | 2026-09-01 | T-034 | audit |
| lib/integrate.py | 93 | 5 | 9 | ctx:44,tasks:18,tests:9,.agentic-framework:8,fabric:5,docs:3 |  | 9 | 2026-06-14 | 2026-08-27 | T-2399 | - |
| lib/keylock.py | 113 | 4 | 2 | ctx:92,fabric:6,.agentic-framework:4,tasks:3,lib:3,tests:2 |  | 1 | 2026-08-16 | 2026-08-16 | T-3042 | audit |
| lib/keylock.sh | 87 | 3 | 4 | ctx:37,tasks:15,.agentic-framework:8,fabric:8,docgen:7,docs:5 |  | 8 | 2026-03-28 | 2026-04-26 | T-587 | - |
| lib/message_router.py | 98 | 1 | 1 | ctx:86,fabric:4,.agentic-framework:2,docs:2,tasks:1,bin:1 |  | 1 | 2026-08-16 | 2026-08-16 | T-3046 | - |
| lib/migrations/arc-id-migration.sh | 17 | 0 | 1 | ctx:6,.agentic-framework:3,tasks:3,fabric:2,docgen:1,docs:1 |  | 1 | 2026-05-16 | 2026-05-16 | T-1850 | - |
| lib/mirror.sh | 31 | 1 | 2 | .agentic-framework:6,ctx:6,tasks:6,fabric:4,docs:4,docgen:2 |  | 3 | 2026-04-29 | 2026-08-22 | T-1594 | - |
| lib/notify.sh | 419 | 9 | 3 | ctx:356,.agentic-framework:17,tasks:13,fabric:12,docs:7,agents:5 |  | 5 | 2026-03-29 | 2026-06-19 | T-708 | audit |
| lib/ollama_loop.py | 941 | 2 | 2 | ctx:906,.agentic-framework:11,docs:7,tasks:6,fabric:5,docgen:2 |  | 2 | 2026-05-09 | 2026-07-21 | T-1775 | - |
| lib/ollama_thin_loop.py | 16 | 1 | 1 | ctx:4,.agentic-framework:3,fabric:3,tasks:2,docgen:1,docs:1 |  | 2 | 2026-07-21 | 2026-08-11 | T-2592 | - |
| lib/outcome.py | 162 | 5 | 1 | ctx:102,tasks:19,.agentic-framework:15,docs:10,fabric:5,docgen:4 |  | 6 | 2026-05-03 | 2026-08-16 | T-1697 | - |
| lib/outcome.sh | 23 | 1 | 1 | ctx:6,.agentic-framework:4,tasks:4,fabric:3,docs:2,CONTEXT.md:1 |  | 2 | 2026-05-03 | 2026-06-24 | T-1697 | - |
| lib/paths.sh | 1080 | 53 | 58 | ctx:676,.agentic-framework:96,fabric:71,tasks:66,tests:58,agents:39 |  | 15 | 2026-03-10 | 2026-09-04 | T-412 | audit+doctor |
| lib/pause_cli.py | 17 | 1 | 0 | .agentic-framework:4,ctx:3,fabric:3,tasks:2,docgen:2,docs:2 |  | 1 | 2026-05-13 | 2026-05-13 | T-1809 | - |
| lib/pause_resolve.py | 27 | 2 | 2 | .agentic-framework:7,fabric:5,ctx:4,docgen:3,tasks:2,docs:2 |  | 1 | 2026-05-13 | 2026-05-13 | T-1809 | - |
| lib/pause.sh | 21 | 2 | 1 | ctx:6,.agentic-framework:4,fabric:3,tasks:3,agents:1,bin:1 |  | 2 | 2026-05-13 | 2026-06-24 | T-1809 | - |
| lib/peer.py | 24 | 1 | 1 | ctx:5,tasks:5,.agentic-framework:4,docs:4,fabric:3,bin:1 |  | 1 | 2026-05-14 | 2026-05-14 | T-1818 | - |
| lib/pending.sh | 26 | 1 | 0 | ctx:7,tasks:5,docs:5,.agentic-framework:4,fabric:3,bin:1 |  | 3 | 2026-04-23 | 2026-07-05 | T-1397 | - |
| lib/pickup-channel-bridge.sh | 29 | 2 | 1 | ctx:8,.agentic-framework:5,docs:5,tasks:4,fabric:3,agents:1 |  | 4 | 2026-04-24 | 2026-08-17 | T-1165 | - |
| lib/pickup.sh | 221 | 3 | 13 | ctx:123,tasks:29,.agentic-framework:19,docs:18,tests:13,fabric:10 |  | 18 | 2026-03-30 | 2026-08-17 | T-774 | - |
| lib/pi_worker.py | 31 | 2 | 1 | .agentic-framework:9,ctx:6,tasks:4,docs:4,fabric:3,docgen:2 |  | 2 | 2026-05-06 | 2026-08-11 | T-1701 | - |
| lib/post-write-index.sh | 102 | 2 | 1 | ctx:90,fabric:4,.agentic-framework:2,agents:2,tasks:1,docgen:1 |  | 1 | 2026-08-16 | 2026-08-16 | T-1719 | - |
| lib/preflight.sh | 60 | 2 | 2 | .agentic-framework:16,ctx:12,docs:12,tasks:7,fabric:6,docgen:3 |  | 7 | 2026-03-04 | 2026-08-09 | T-303 | - |
| lib/promote.sh | 65 | 2 | 1 | ctx:27,.agentic-framework:10,tasks:10,docs:8,fabric:4,docgen:3 |  | 7 | 2026-02-16 | 2026-08-10 | T-087 | - |
| lib/prompt.sh | 26 | 4 | 1 | ctx:5,tasks:5,.agentic-framework:4,fabric:3,docs:3,SETTINGS:2 |  | 3 | 2026-04-18 | 2026-04-18 | T-1293 | - |
| lib/publish-learning-to-bus.sh | 28 | 3 | 0 | .agentic-framework:7,tasks:6,ctx:5,docs:3,fabric:2,agents:2 |  | 3 | 2026-04-24 | 2026-05-26 | T-1168 | - |
| lib/push-state.sh | 97 | 2 | 1 | ctx:86,.agentic-framework:3,fabric:3,tasks:1,agents:1,bin:1 |  | 1 | 2026-08-17 | 2026-08-17 | T-3063 | - |
| lib/rail-identity.sh | 32 | 2 | 1 | ctx:9,.agentic-framework:5,tasks:5,fabric:4,docs:4,docgen:2 |  | 3 | 2026-08-09 | 2026-08-10 | T-2904 | - |
| lib/recall-usage.sh | 99 | 1 | 0 | ctx:89,tasks:4,fabric:2,.agentic-framework:1,bin:1,docgen:1 |  | 1 | 2026-08-15 | 2026-08-15 | T-3019 | doctor |
| lib/release.sh | 69 | 5 | 4 | ctx:40,.agentic-framework:7,tasks:6,tests:4,docs:3,SETTINGS:2 |  | 4 | 2026-04-14 | 2026-09-07 | T-1256 | doctor |
| lib/render_surface.sh | 38 | 1 | 3 | ctx:14,tasks:10,.agentic-framework:4,fabric:4,tests:3,agents:1 |  | 3 | 2026-05-06 | 2026-08-27 | T-1766 | - |
| lib/resolver.py | 463 | 14 | 15 | ctx:270,tasks:63,.agentic-framework:41,docs:29,fabric:21,tests:15 |  | 22 | 2026-05-03 | 2026-08-16 | T-1696 | - |
| lib/resolver.sh | 34 | 1 | 1 | ctx:12,.agentic-framework:6,tasks:6,docs:4,fabric:3,bin:1 |  | 2 | 2026-05-03 | 2026-06-24 | T-1696 | - |
| lib/reviewer/audit.py | 241 | 10 | 12 | ctx:120,tasks:49,.agentic-framework:21,docs:12,tests:12,fabric:11 |  | 4 | 2026-04-25 | 2026-04-26 | T-1447 | - |
| lib/reviewer/classifier.py | 23 | 1 | 3 | ctx:5,tasks:5,.agentic-framework:4,tests:3,fabric:2,docs:2 |  | 1 | 2026-04-26 | 2026-04-26 | T-1483 | - |
| lib/reviewer/dispatch_cli.py | 21 | 0 | 2 | fabric:5,.agentic-framework:4,ctx:4,tasks:2,docs:2,tests:2 |  | 2 | 2026-05-22 | 2026-07-05 | T-1951 | - |
| lib/reviewer/drift_cli.py | 12 | 0 | 0 | ctx:3,fabric:3,.agentic-framework:2,docs:2,tasks:1,docgen:1 |  | 1 | 2026-04-26 | 2026-04-26 | T-1483 | - |
| lib/reviewer/drift.py | 84 | 5 | 7 | tasks:22,ctx:21,.agentic-framework:12,fabric:8,docs:7,tests:7 |  | 2 | 2026-04-26 | 2026-08-02 | T-1483 | - |
| lib/reviewer/__init__.py | 264 | 5 | 3 | ctx:129,fabric:60,tasks:31,.agentic-framework:18,docs:13,docgen:5 |  | 1 | 2026-04-25 | 2026-04-25 | T-1445 | - |
| lib/reviewer/override_cli.py | 13 | 0 | 0 | ctx:4,.agentic-framework:2,fabric:2,tasks:2,docs:2,docgen:1 |  | 1 | 2026-04-25 | 2026-04-25 | T-1449 | - |
| lib/reviewer/overrides.py | 39 | 5 | 4 | .agentic-framework:10,fabric:7,tasks:4,docs:4,lib:4,tests:4 |  | 1 | 2026-04-25 | 2026-04-25 | T-1449 | - |
| lib/reviewer/recommendation_claims.py | 26 | 2 | 3 | .agentic-framework:7,fabric:5,tasks:3,tests:3,ctx:2,docgen:2 |  | 2 | 2026-07-05 | 2026-08-02 | T-100187 | - |
| lib/reviewer/reverify_cli.py | 12 | 0 | 0 | ctx:5,.agentic-framework:2,fabric:2,tasks:1,docgen:1,docs:1 |  | 1 | 2026-04-26 | 2026-04-26 | T-1483 | - |
| lib/reviewer/reverify.py | 27 | 3 | 2 | .agentic-framework:6,ctx:5,fabric:4,tasks:4,lib:3,docs:2 |  | 1 | 2026-04-26 | 2026-04-26 | T-1483 | - |
| lib/reviewer/static_scan.py | 244 | 10 | 26 | ctx:81,tasks:60,.agentic-framework:29,tests:26,docs:20,fabric:14 |  | 33 | 2026-04-25 | 2026-09-04 | T-1445 | - |
| lib/review_link_validator.py | 37 | 1 | 2 | ctx:9,.agentic-framework:7,fabric:7,tasks:5,docgen:3,docs:3 |  | 3 | 2026-05-25 | 2026-05-31 | T-2050 | - |
| lib/review.sh | 662 | 11 | 16 | tasks:409,ctx:124,.agentic-framework:48,docs:30,fabric:17,tests:16 |  | 26 | 2026-03-27 | 2026-09-05 | T-634 | - |
| lib/root-pollution.sh | 101 | 1 | 1 | ctx:91,fabric:3,tasks:2,.agentic-framework:1,bin:1,docgen:1 |  | 2 | 2026-08-14 | 2026-08-14 | T-2990 | doctor |
| lib/runtime.sh | 24 | 0 | 1 | ctx:8,.agentic-framework:6,docs:3,fabric:2,tasks:2,docgen:2 |  | 1 | 2026-03-24 | 2026-03-24 | T-592 | - |
| lib/section-extract.sh | 15 | 3 | 1 | .agentic-framework:4,ctx:3,tasks:3,agents:2,fabric:1,lib:1 |  | 1 | 2026-09-06 | 2026-09-06 | T-3148 | - |
| lib/settings_merge.py | 16 | 1 | 1 | .agentic-framework:4,fabric:3,tasks:3,ctx:2,docgen:1,docs:1 |  | 1 | 2026-08-01 | 2026-08-01 | T-2710 | - |
| lib/setup.sh | 93 | 2 | 13 | ctx:28,.agentic-framework:16,tests:13,tasks:11,docs:11,fabric:9 |  | 7 | 2026-02-17 | 2026-08-25 | T-104 | - |
| lib/spawn.py | 192 | 5 | 5 | ctx:114,tasks:23,.agentic-framework:19,docs:12,fabric:9,lib:5 |  | 11 | 2026-05-06 | 2026-08-16 | T-1773 | - |
| lib/subscribe-learnings-from-bus.sh | 19 | 1 | 0 | ctx:6,.agentic-framework:4,docs:3,fabric:2,tasks:2,docgen:1 |  | 2 | 2026-04-24 | 2026-04-24 | T-1217 | - |
| lib/task-audit.sh | 442 | 5 | 6 | tasks:374,ctx:24,.agentic-framework:16,fabric:8,docs:7,tests:6 |  | 7 | 2026-04-12 | 2026-05-05 | T-1113 | audit |
| lib/task_pair_acd.py | 84 | 2 | 2 | ctx:67,.agentic-framework:5,fabric:4,tasks:2,tests:2,agents:1 |  | 1 | 2026-05-06 | 2026-05-06 | T-1762 | - |
| lib/task_pair_acd.sh | 33 | 2 | 4 | ctx:10,fabric:7,.agentic-framework:5,tests:4,tasks:3,agents:1 |  | 1 | 2026-05-06 | 2026-05-06 | T-1762 | - |
| lib/task_satisfaction.py | 101 | 1 | 2 | ctx:88,tasks:5,fabric:2,docgen:2,tests:2,.agentic-framework:1 |  | 2 | 2026-08-17 | 2026-08-17 | T-3061 | - |
| lib/tasks.sh | 109 | 5 | 19 | ctx:39,tests:19,.agentic-framework:15,fabric:14,docs:8,tasks:7 |  | 1 | 2026-03-11 | 2026-03-11 | T-424 | - |
| lib/templates/claude-project.md | 91 | 3 | 2 | ctx:46,tasks:17,.agentic-framework:12,docs:11,lib:3,tests:2 |  | 43 | 2026-02-13 | 2026-08-26 | none | - |
| lib/templates/resume-md.md | 12 | 2 | 1 | .agentic-framework:3,ctx:2,tasks:2,docs:2,lib:2,tests:1 |  | 3 | 2026-02-14 | 2026-04-22 | T-059 | - |
| lib/templates/scripts/agent-chat-arc-recent.sh | 31 | 10 | 0 | .agentic-framework:9,lib:7,ctx:5,scripts:5,.claude:3,fabric:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/scripts/agent-conversation-list.sh | 10 | 2 | 0 | .agentic-framework:3,ctx:2,.claude:1,fabric:1,docs:1,lib:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/scripts/agent-conversation-status.sh | 19 | 3 | 1 | ctx:6,.agentic-framework:4,lib:2,scripts:2,.claude:1,fabric:1 |  | 3 | 2026-05-29 | 2026-09-06 | T-1866 | - |
| lib/templates/scripts/agent-identity.sh | 10 | 3 | 1 | .agentic-framework:3,lib:3,ctx:1,fabric:1,tasks:1,tests:1 |  | 1 | 2026-09-06 | 2026-09-06 | T-3286 | - |
| lib/templates/scripts/agent-listeners-fleet.sh | 28 | 10 | 0 | .agentic-framework:9,lib:6,.claude:4,ctx:3,scripts:3,docs:2 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/scripts/agent-listeners.sh | 22 | 4 | 0 | .agentic-framework:7,ctx:4,docs:3,lib:3,scripts:3,.claude:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/scripts/agent-respond.sh | 26 | 4 | 1 | ctx:7,.agentic-framework:6,docs:3,lib:3,tasks:2,scripts:2 |  | 3 | 2026-05-29 | 2026-09-06 | T-1866 | - |
| lib/templates/scripts/agent-send.sh | 40 | 9 | 1 | .agentic-framework:11,ctx:7,lib:7,scripts:5,docs:4,.claude:2 |  | 3 | 2026-05-29 | 2026-09-06 | T-1866 | - |
| lib/templates/scripts/be-reachable.sh | 12 | 2 | 0 | ctx:4,.agentic-framework:3,.claude:1,fabric:1,docs:1,lib:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/scripts/chat-arc-broadcast.sh | 12 | 2 | 0 | .agentic-framework:3,ctx:3,.claude:1,fabric:1,tasks:1,docs:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/scripts/listener-heartbeat.sh | 20 | 3 | 0 | .agentic-framework:6,ctx:4,docs:3,lib:2,scripts:2,.claude:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/scripts/recent-dm.sh | 13 | 2 | 0 | ctx:5,.agentic-framework:3,.claude:1,fabric:1,docs:1,lib:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/skills/agent-handoff.md | 6 | 2 | 0 | .agentic-framework:2,.claude:1,ctx:1,docs:1,lib:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/skills/be-reachable.md | 3 | 0 | 0 | .agentic-framework:1,ctx:1,docs:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/skills/broadcast-chat.md | 3 | 0 | 0 | .agentic-framework:1,ctx:1,docs:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/skills/check-arc.md | 3 | 0 | 0 | .agentic-framework:1,ctx:1,docs:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/skills/conversations.md | 9 | 2 | 0 | .agentic-framework:3,ctx:2,docs:2,.claude:1,lib:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/skills/peers.md | 3 | 0 | 0 | .agentic-framework:1,ctx:1,docs:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/skills/pulse.md | 3 | 0 | 0 | .agentic-framework:1,ctx:1,docs:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/skills/recent-chat.md | 3 | 0 | 0 | .agentic-framework:1,ctx:1,docs:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/templates/skills/recent-dm.md | 3 | 0 | 0 | .agentic-framework:1,ctx:1,docs:1 |  | 2 | 2026-05-29 | 2026-05-29 | T-1866 | - |
| lib/termlink_worker.py | 931 | 3 | 3 | ctx:897,.agentic-framework:10,fabric:6,tasks:5,docs:5,lib:3 |  | 2 | 2026-05-12 | 2026-06-24 | T-1797 | - |
| lib/tier0_origin.py | 81 | 1 | 2 | ctx:70,fabric:3,.agentic-framework:2,docgen:2,tests:2,tasks:1 |  | 1 | 2026-08-20 | 2026-08-20 | T-3078 | - |
| lib/traceability.sh | 18 | 1 | 1 | ctx:5,.agentic-framework:4,fabric:4,tasks:1,agents:1,docgen:1 |  | 1 | 2026-08-07 | 2026-08-07 | T-2851 | audit |
| lib/ts/src/fw-util.ts | 11 | 1 | 0 | ctx:4,.agentic-framework:3,docs:2,tasks:1,lib:1 |  | 1 | 2026-03-24 | 2026-03-24 | T-593 | - |
| lib/ts/src/loop-detect.ts | 41 | 2 | 0 | .agentic-framework:12,ctx:11,docs:10,tasks:3,fabric:2,agents:1 |  | 2 | 2026-03-23 | 2026-03-24 | T-586 | - |
| lib/update.sh | 93 | 1 | 4 | ctx:33,.agentic-framework:17,docs:17,tasks:15,fabric:4,tests:4 |  | 9 | 2026-03-14 | 2026-08-25 | T-493 | - |
| lib/upgrade.sh | 764 | 11 | 39 | ctx:437,tasks:140,.agentic-framework:53,docs:47,tests:39,fabric:26 |  | 84 | 2026-02-18 | 2026-09-01 | T-169 | audit+doctor |
| lib/upstream.sh | 60 | 2 | 2 | ctx:22,.agentic-framework:11,tasks:8,docs:7,fabric:5,docgen:3 |  | 5 | 2026-03-12 | 2026-08-25 | T-454 | doctor |
| lib/url-credentials.sh | 28 | 2 | 2 | ctx:9,.agentic-framework:6,fabric:3,tasks:3,docgen:2,tests:2 |  | 2 | 2026-07-31 | 2026-08-25 | T-2693 | - |
| lib/validate-init.sh | 169 | 2 | 5 | ctx:97,.agentic-framework:20,tasks:20,docs:11,fabric:7,docgen:7 |  | 11 | 2026-03-08 | 2026-08-25 | T-357 | - |
| lib/vendor-visibility.sh | 11 | 1 | 1 | fabric:3,ctx:2,.agentic-framework:1,tasks:1,bin:1,docgen:1 |  | 1 | 2026-08-26 | 2026-08-26 | T-3144 | - |
| lib/verification-port.sh | 229 | 9 | 8 | ctx:160,.agentic-framework:16,tasks:16,fabric:8,docs:8,tests:8 |  | 7 | 2026-08-02 | 2026-08-31 | T-2732 | - |
| lib/verification-verdict.sh | 20 | 1 | 1 | ctx:8,.agentic-framework:4,fabric:2,tasks:2,agents:1,docgen:1 |  | 1 | 2026-08-02 | 2026-08-02 | T-2738 | - |
| lib/verify-acs.sh | 411 | 2 | 4 | ctx:359,tasks:19,.agentic-framework:11,docs:9,fabric:6,tests:4 |  | 8 | 2026-04-04 | 2026-06-15 | T-824 | - |
| lib/verify_queue.py | 118 | 3 | 3 | ctx:94,fabric:7,.agentic-framework:5,tasks:3,tests:3,docs:2 |  | 2 | 2026-08-03 | 2026-08-14 | T-2765 | audit |
| lib/version-relation.sh | 28 | 2 | 3 | ctx:7,.agentic-framework:5,fabric:5,tasks:3,tests:3,docgen:2 |  | 2 | 2026-08-01 | 2026-08-03 | T-2713 | - |
| lib/version.sh | 43 | 2 | 2 | ctx:14,.agentic-framework:8,tasks:7,docs:5,fabric:3,docgen:2 |  | 4 | 2026-03-25 | 2026-09-07 | T-606 | - |
| lib/watchtower.sh | 519 | 12 | 10 | ctx:368,.agentic-framework:39,tasks:35,docs:27,fabric:20,tests:10 |  | 6 | 2026-04-12 | 2026-08-17 | T-1154 | audit+doctor |
| lib/watchtower-staleness.sh | 23 | 3 | 2 | fabric:5,.agentic-framework:4,ctx:4,tasks:3,bin:2,tests:2 |  | 1 | 2026-08-12 | 2026-08-12 | T-2938 | audit+doctor |
| lib/worker_identity.py | 22 | 3 | 2 | .agentic-framework:5,fabric:5,ctx:3,docgen:3,lib:2,tests:2 |  | 1 | 2026-08-11 | 2026-08-11 | T-2917 | - |
| lib/worker_kinds_parity.py | 24 | 1 | 2 | ctx:6,fabric:5,.agentic-framework:4,tasks:3,docgen:2,tests:2 |  | 1 | 2026-05-20 | 2026-05-20 | T-1946 | - |
| lib/workflow_coverage.py | 73 | 2 | 2 | ctx:37,tasks:12,fabric:10,.agentic-framework:6,docgen:3,tests:2 |  | 6 | 2026-05-13 | 2026-09-04 | T-1798 | audit |
| lib/workflow_lint.py | 119 | 2 | 4 | ctx:92,fabric:7,.agentic-framework:5,tasks:5,tests:4,docgen:2 |  | 3 | 2026-05-13 | 2026-08-16 | T-1807 | - |
| lib/worktree-identity.sh | 23 | 2 | 3 | ctx:6,fabric:4,.agentic-framework:3,tests:3,tasks:2,docs:2 |  | 1 | 2026-08-22 | 2026-08-22 | T-3111 | - |
| lib/worktree.sh | 192 | 3 | 9 | ctx:142,tasks:15,docs:12,tests:9,.agentic-framework:6,fabric:4 |  | 9 | 2026-06-23 | 2026-08-27 | T-2466 | - |
| lib/write_set.py | 141 | 3 | 5 | ctx:95,.agentic-framework:12,tasks:9,fabric:8,docs:7,tests:5 |  | 3 | 2026-06-11 | 2026-08-16 | T-2337 | - |
| lib/yaml.sh | 132 | 3 | 4 | ctx:97,.agentic-framework:9,fabric:7,tasks:7,tests:4,docgen:3 |  | 3 | 2026-03-11 | 2026-08-02 | T-424 | - |
| policy/anti-patterns.yaml | 119 | 5 | 17 | ctx:46,tasks:22,tests:17,.agentic-framework:11,vendor:10,docs:7 |  | 13 | 2026-04-25 | 2026-09-04 | T-1445 | - |
| policy/authority-envelope.yaml | 19 | 3 | 1 | .agentic-framework:5,ctx:3,docs:3,fabric:2,tasks:2,agents:1 |  | 1 | 2026-06-18 | 2026-06-18 | T-2430 | - |
| policy/bvp-scoring-rubric.md | 201 | 14 | 5 | ctx:131,.agentic-framework:23,tasks:16,docs:10,tests:5,agents:4 |  | 1 | 2026-05-19 | 2026-05-19 | T-1921 | audit |
| policy/capability-overlay/tool-set.yaml | 117 | 8 | 10 | ctx:39,.agentic-framework:21,tasks:16,docs:10,tests:10,docgen:9 |  | 2 | 2026-06-08 | 2026-06-08 | T-2258 | audit+doctor |
| policy/designer-pin.yaml | 135 | 6 | 8 | ctx:67,tasks:27,.agentic-framework:13,docs:9,tests:8,agents:2 |  | 15 | 2026-07-10 | 2026-08-26 | T-2521 | doctor |
| policy/escalation-patterns.yaml | 110 | 4 | 3 | ctx:79,tasks:10,.agentic-framework:8,docs:5,lib:3,tests:3 |  | 3 | 2026-04-25 | 2026-07-28 | T-1446 | - |
| policy/prompts/arc-delivery-session.md | 9 | 1 | 0 | ctx:3,.agentic-framework:2,docs:2,tasks:1,policy:1 |  | 1 | 2026-08-05 | 2026-08-05 | T-2804 | - |
| policy/prompts/artefact-template.md | 25 | 4 | 0 | .agentic-framework:9,docs:4,ctx:3,tasks:3,policy:3,040-ValueDrivers.md:1 |  | 1 | 2026-06-08 | 2026-06-08 | T-2246 | - |
| policy/prompts/bvp-driver-session.md | 70 | 5 | 2 | ctx:22,.agentic-framework:15,tasks:14,docs:9,policy:4,tests:2 |  | 4 | 2026-06-08 | 2026-06-08 | T-2246 | - |
| policy/prompts/bvp-references/arc-scoped-driver-examples.md | 18 | 2 | 0 | .agentic-framework:6,docs:4,tasks:3,policy:2,ctx:1,040-ValueDrivers.md:1 |  | 1 | 2026-06-08 | 2026-06-08 | T-2246 | - |
| policy/prompts/bvp-references/discipline-failure-modes.md | 25 | 4 | 0 | .agentic-framework:8,ctx:4,docs:4,policy:4,tasks:3,040-ValueDrivers.md:1 |  | 2 | 2026-06-08 | 2026-06-08 | T-2246 | - |
| policy/prompts/bvp-references/global-driver-examples.md | 11 | 1 | 0 | .agentic-framework:3,ctx:2,docs:2,tasks:1,040-ValueDrivers.md:1,CLAUDE.md:1 |  | 1 | 2026-06-08 | 2026-06-08 | T-2246 | - |
| policy/prompts/bvp-references/sharpening-subroutine.md | 20 | 5 | 0 | .agentic-framework:7,policy:5,ctx:3,docs:2,tasks:1,040-ValueDrivers.md:1 |  | 2 | 2026-06-08 | 2026-06-08 | T-2246 | - |
| policy/prompts/bvp-references/sharpening-tactics.md | 13 | 3 | 0 | .agentic-framework:4,policy:3,ctx:2,tasks:1,040-ValueDrivers.md:1,CLAUDE.md:1 |  | 1 | 2026-06-08 | 2026-06-08 | T-2246 | - |
| policy/prompts/landing-mode.md | 42 | 0 | 0 | ctx:35,tasks:5,docs:2 |  | 4 | 2026-08-27 | 2026-08-31 | T-3201 | - |
| policy/prompts/README.md | 501 | 8 | 26 | ctx:359,tasks:53,.agentic-framework:29,tests:26,docs:22,agents:3 |  | 3 | 2026-06-08 | 2026-08-05 | T-2246 | - |
| policy/proxy-policy.yaml | 25 | 4 | 1 | .agentic-framework:7,ctx:5,tasks:4,fabric:2,docs:2,lib:2 |  | 1 | 2026-06-18 | 2026-06-18 | T-2431 | doctor |
| policy/standards/aef-bpmn-mapping-v1-partI.md | 87 | 1 | 4 | ctx:67,tasks:6,tests:4,.agentic-framework:3,docs:3,fabric:2 |  | 1 | 2026-08-08 | 2026-08-08 | T-2869 | - |
| policy/standards/aef-bpmn-mapping-v1-partI.provenance.yaml | 12 | 0 | 1 | ctx:8,tasks:2,fabric:1,tests:1 |  | 2 | 2026-08-08 | 2026-08-08 | T-2869 | - |
| policy/value-drivers.yaml | 266 | 18 | 17 | ctx:73,tasks:62,.agentic-framework:53,docs:37,tests:17,lib:5 |  | 7 | 2026-05-19 | 2026-07-07 | T-1917 | audit |

### 3b. Per `fw` verb (99 arms; churn = bin/fw as a whole, 394 commits; no per-verb usage data exists)

| verb | files mentioning `fw <verb>` (excl. .agentic-framework) | in code | in tests | in cron registry/.context/cron | in .tasks | in .context | in docs/*.md |
|---|---|---|---|---|---|---|---|
| ask | 111 | 12 | 5 | 0 | 16 | 47 | 28 |
| audit | 2527 | 35 | 34 | 2 | 308 | 1989 | 156 |
| reviewer | 2325 | 15 | 13 | 1 | 1219 | 1031 | 46 |
| ux-review | 61 | 1 | 0 | 0 | 10 | 49 | 0 |
| self-audit | 59 | 1 | 1 | 0 | 3 | 50 | 4 |
| gpu | 5 | 3 | 0 | 0 | 0 | 0 | 1 |
| test-onboarding | 18 | 1 | 1 | 0 | 6 | 5 | 5 |
| plugin-audit | 11 | 1 | 1 | 0 | 2 | 5 | 2 |
| context | 501 | 29 | 30 | 0 | 99 | 223 | 105 |
| focus | 10 | 1 | 1 | 0 | 1 | 6 | 1 |
| arc | 1475 | 16 | 21 | 0 | 101 | 1232 | 102 |
| bvp | 1798 | 23 | 23 | 1 | 1324 | 373 | 53 |
| triage | 6 | 2 | 1 | 0 | 2 | 1 | 0 |
| write-set | 43 | 4 | 4 | 0 | 9 | 14 | 12 |
| worktree | 451 | 8 | 9 | 0 | 26 | 387 | 21 |
| integrate | 507 | 11 | 14 | 0 | 41 | 424 | 17 |
| continuous | 56 | 6 | 3 | 1 | 8 | 19 | 20 |
| cron | 235 | 10 | 13 | 1 | 47 | 141 | 23 |
| index | 6 | 2 | 0 | 1 | 1 | 1 | 2 |
| docs | 26 | 3 | 3 | 1 | 6 | 7 | 7 |
| fabric | 733 | 17 | 17 | 0 | 98 | 523 | 72 |
| designer | 75 | 6 | 6 | 0 | 24 | 23 | 14 |
| bpmn | 103 | 6 | 10 | 0 | 36 | 32 | 15 |
| corpus | 157 | 14 | 12 | 1 | 51 | 62 | 14 |
| git | 221 | 21 | 13 | 0 | 28 | 115 | 39 |
| sync | 27 | 2 | 1 | 0 | 8 | 12 | 4 |
| go-live | 302 | 2 | 1 | 0 | 3 | 295 | 1 |
| push | 19 | 3 | 0 | 0 | 5 | 10 | 1 |
| handover | 227 | 16 | 11 | 0 | 33 | 102 | 58 |
| healing | 57 | 5 | 2 | 0 | 9 | 8 | 31 |
| resume | 140 | 4 | 4 | 1 | 20 | 80 | 31 |
| inception | 3670 | 26 | 33 | 1 | 1587 | 1871 | 145 |
| orchestrator | 137 | 5 | 10 | 0 | 40 | 52 | 29 |
| resolver | 1041 | 9 | 11 | 1 | 46 | 944 | 28 |
| outcome | 73 | 5 | 3 | 0 | 18 | 31 | 13 |
| pause | 244 | 5 | 4 | 0 | 8 | 217 | 10 |
| peer | 89 | 1 | 0 | 0 | 5 | 77 | 6 |
| promote | 79 | 6 | 3 | 0 | 6 | 46 | 16 |
| assumption | 170 | 7 | 3 | 0 | 132 | 11 | 15 |
| bus | 253 | 11 | 6 | 0 | 33 | 136 | 61 |
| rail | 93 | 2 | 2 | 0 | 5 | 83 | 1 |
| dispatch | 277 | 3 | 3 | 0 | 10 | 225 | 25 |
| pickup | 111 | 4 | 7 | 1 | 30 | 45 | 25 |
| pending | 29 | 3 | 3 | 1 | 8 | 8 | 7 |
| upstream | 35 | 4 | 4 | 0 | 6 | 7 | 13 |
| consolidate | 17 | 1 | 1 | 0 | 1 | 9 | 5 |
| mcp | 56 | 4 | 9 | 0 | 13 | 18 | 12 |
| fix-learned | 65 | 3 | 1 | 0 | 11 | 41 | 9 |
| note | 975 | 10 | 14 | 0 | 47 | 871 | 33 |
| recall | 100 | 9 | 3 | 0 | 22 | 37 | 19 |
| scan | 19 | 1 | 3 | 0 | 2 | 6 | 6 |
| serve | 503 | 13 | 4 | 0 | 51 | 381 | 49 |
| watchtower | 2132 | 13 | 16 | 0 | 734 | 1326 | 39 |
| deploy | 396 | 3 | 1 | 0 | 7 | 380 | 5 |
| tier0 | 113 | 9 | 6 | 0 | 23 | 27 | 44 |
| approvals | 32 | 3 | 1 | 0 | 7 | 14 | 6 |
| review-queue | 1159 | 9 | 8 | 0 | 40 | 1074 | 28 |
| verify-queue | 18 | 4 | 2 | 0 | 6 | 6 | 0 |
| work-on | 1612 | 37 | 32 | 0 | 1058 | 346 | 132 |
| task | 2146 | 62 | 66 | 1 | 856 | 909 | 242 |
| preflight | 58 | 2 | 1 | 0 | 2 | 38 | 13 |
| init | 1053 | 32 | 48 | 0 | 196 | 585 | 180 |
| validate-init | 28 | 1 | 4 | 0 | 4 | 6 | 12 |
| update | 517 | 5 | 6 | 0 | 20 | 453 | 31 |
| upgrade | 1901 | 23 | 36 | 0 | 204 | 1493 | 138 |
| consumer-recover | 137 | 1 | 1 | 0 | 4 | 123 | 8 |
| setup | 51 | 2 | 2 | 0 | 8 | 25 | 13 |
| build | 21 | 2 | 1 | 0 | 4 | 3 | 9 |
| harvest | 36 | 2 | 2 | 0 | 6 | 14 | 10 |
| prompt | 22 | 4 | 0 | 0 | 6 | 5 | 4 |
| termlink | 1198 | 15 | 16 | 0 | 85 | 997 | 79 |
| sessions | 428 | 5 | 0 | 0 | 4 | 409 | 6 |
| onboarding | 20 | 3 | 1 | 0 | 5 | 4 | 6 |
| provisions | 3 | 1 | 1 | 0 | 0 | 1 | 0 |
| gaps | 73 | 6 | 6 | 0 | 19 | 24 | 14 |
| traceability | 14 | 1 | 1 | 0 | 3 | 5 | 3 |
| decisions | 19 | 0 | 2 | 0 | 2 | 5 | 9 |
| timeline | 18 | 0 | 2 | 0 | 5 | 4 | 6 |
| learnings | 31 | 3 | 3 | 0 | 5 | 9 | 10 |
| patterns | 10 | 0 | 1 | 0 | 1 | 1 | 6 |
| practices | 18 | 0 | 1 | 0 | 1 | 8 | 7 |
| search | 28 | 2 | 1 | 0 | 4 | 12 | 7 |
| vendor | 961 | 18 | 27 | 0 | 161 | 722 | 32 |
| hook | 340 | 26 | 24 | 0 | 73 | 153 | 62 |
| hook-enable | 121 | 8 | 6 | 0 | 19 | 75 | 12 |
| doctor | 3440 | 65 | 91 | 0 | 1497 | 1556 | 217 |
| policy | 10 | 2 | 1 | 0 | 2 | 4 | 1 |
| verify-acs | 121 | 4 | 5 | 0 | 17 | 78 | 17 |
| self-test | 56 | 2 | 5 | 0 | 10 | 27 | 11 |
| enforcement | 1284 | 3 | 2 | 0 | 1246 | 12 | 20 |
| metrics | 54 | 6 | 2 | 0 | 3 | 13 | 28 |
| costs | 1463 | 3 | 5 | 0 | 11 | 1424 | 19 |
| release | 37 | 7 | 2 | 1 | 11 | 7 | 9 |
| mirror | 23 | 2 | 1 | 1 | 8 | 7 | 5 |
| test | 640 | 6 | 11 | 0 | 257 | 321 | 40 |
| notify | 827 | 3 | 1 | 0 | 7 | 804 | 11 |
| config | 245 | 18 | 10 | 0 | 49 | 133 | 33 |
| version | 317 | 8 | 16 | 0 | 27 | 231 | 29 |
| help | 350 | 6 | 4 | 0 | 41 | 267 | 30 |

### 3c. Summary counts

- File items: **371** (evidence rows), plus **99** verb arms = **470** inventory units. Grouped rows in §1 compress some of these.
- **Zero total references anywhere in the repo: 0 items.**
- **Zero code references** (tests, docs and vendored copies excluded) after correcting for hook wiring and `-m` invocation: antigravity/subagent_dispatch.py, lib/antigravity_steps.py, agents/context/{bus-handler, check-dispatch-pre, pl007-scanner, check-task-ac-structure, check-visual-verification, test-tier0-patterns, stop-guard, subagent-stop, session-end, session-silent-scanner}, 7 test scripts inside agents/, lib/{first-run, runtime (tests only), setup (self-audit existence loop only), subscribe-learnings-from-bus}.sh, lib/aef_repo_source.py (tests only), lib/migrations/arc-id-migration.sh, 5 bvp-references plus 2 session prompts plus the bpmn standard in policy/, and all 11 agent AGENT.md files. That is **about 40 items**.
- File items with **0 test files** naming them: 94 of 371. Verbs with 0 test files: ux-review, gpu, index, push, peer, prompt, sessions.
- Verbs with 0 references in the cron registry: 83 of 99.
- **Items with no T-ID in the adding commit: 1** (lib/templates/claude-project.md, added by "v0.1 base start", i.e. pre-task-system). Every other file traces to a task. Whether each origin reason still holds is not assessed per row (UNVERIFIED); §4 lists the cases where header claims and wiring disagree.

---

## Section 4 — Surprises

1. **Four built write-time gates are not wired.** check-inception-recommendation (T-2205), check-task-ac-structure (T-2420), check-visual-verification (T-2128) and chat-bare-path-scan/-warn (T-2183) exist as full implementations, but none is in `.claude/settings.json`. CLAUDE.md's T-2204 table lists T-2205 as "Producer 4" and itself notes the operator has not wired it; the hourly cron is the backstop. The other three are not flagged anywhere I found.
2. **check-dispatch.sh is matched on `Task|TaskOutput`.** The dispatch tool in this harness is named `Agent`, which is what check-agent-dispatch matches. Whether `Task` still fires in current Claude Code is UNVERIFIED. If it does not, the G-008 result-size guard is silent. check-dispatch-pre.sh (the blocking half) is unwired.
3. **`fw hook` exits 0 when the hook script is missing** (bin/fw:9101), and loop-detect.sh fails open without node. `lib/ts/node_modules` is untracked, so a fresh clone's loop detector depends on host node and the committed dist.
4. **Header claims that contradict the wiring:** session-silent-scanner.sh says "invoked via cron every 15 min" but is not in the cron registry. revisit-due-scan.sh says "daily scan"; it has no registry entry, yet handover.sh:811 reads its output file. subscribe-learnings-from-bus.sh recommends a cron that does not exist, while web reads its output.
5. **Duplicates:** fw-shim vs fw-router; update.sh vs upgrade.sh; `_version_lt` vs `release_version_lt`; `_sed_i` in both compat.sh and paths.sh. dispatch.sh mixes SSH send with the local Agent-gate approval.
6. **The recall and designer capabilities are hollow in the governance layer.** Their engines are in web/ and tools/ (or the external 832 repo). A value review scoped to bin/lib/agents/policy would miss where they actually live.
7. **Hardcoded host paths** in governance code: integrate-go-live.sh (`/opt/999…`, T-2481), notify.sh (`/opt/150-skills-manager`), `fw deploy` (`/opt/claude-shared-toolkit`), several cron commands (`/opt/999…/agents/...`).
8. **Tests living inside agents/** (7 scripts plus test_docgen.py plus test-tier0-patterns.py) are outside `tests/` and are therefore invisible to `fw test` and unit-suite.sh (UNVERIFIED whether any runner globs them).
9. **Size concentration:** audit.sh 7300 lines, bin/fw 10,032 lines (`do_doctor` alone ~1300 lines inline), estimator.py 3268, static_scan.py 3137, update-task.sh 2564, resolver.py 2193, upgrade.sh ~2755.
10. **The in-scope reference counts are dominated by a tracked self-vendored copy** (`.agentic-framework/`) plus docs/generated and .fabric. Raw "refs total" overstates reachability; use the "refs in code" column.

---

## Commands run / not run

- **No `fw` verbs were run.** The Agent-dispatch PreToolUse hook (`bin/fw hook check-agent-dispatch`) **fired automatically** on this gatherer's sub-agent launches (3 blocked at limit 2), which touched hook counters. I did not run `fw dispatch approve`.
- Read-only commands: git grep, git log --follow, git ls-files, grep, sed, awk, python3 (analysis scripts in /tmp/gd/). Two read-only Explore sub-agents read bin/ and the verb arms, and lib/*.sh.
