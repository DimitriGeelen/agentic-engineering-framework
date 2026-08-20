# T-3096 — Read/Write classification of every `fw` sub-command

**Status:** research artefact (read-only task — no source file was modified).
**Scope:** every top-level arm of `bin/fw`'s dispatch `case "$cmd" in` (line 4429),
plus every sub-verb of each multi-verb command.
**Method:** each arm traced from its case arm to the handler (`lib/*.sh`,
`lib/*.py`, `agents/*/*.sh`), then the handler body read for mutation sites
(file writes, `os.replace`, `sed -i`, `mkdir`, `git` mutating porcelain, process
spawn, external POST/push). Every verdict carries a `file:line`.
**Bias applied:** when a verb could not be *proved* side-effect-free it is
reported `MIXED` or `UNKNOWN`, never `READ`. This list feeds
`agents/context/lib/safe-commands.sh`; a wrong `READ` silently disables the
Tier-1 task gate, a wrong `WRITE` only costs friction.

## Headline findings

Four verbs **currently in the allowlist** are not read-only:

| Verb | Why it is not READ |
|---|---|
| `audit` | writes `.context/audits/<date>.yaml` + a PID lock (`agents/audit/audit.sh:390`, `:5834-5839`) |
| `context init`, `context focus` | rewrite `session.yaml` / `focus.yaml` (`agents/context/lib/init.sh:26`, `agents/context/lib/focus.sh:117-121`) |
| `task review` | `touch`es the T-973 review marker (`lib/review.sh:389-390`) |
| `resume status` | fire-and-forgets a backgrounded BVP estimator that writes `bvp_scores_proposed:` into task files (`agents/resume/resume.sh:128-135`) |

They are presumably allowlisted deliberately (session bootstrap / handoff), but
they should be listed as *sanctioned* writes, not as reads.

And several verbs named in the T-3096 brief as "read-only but gated" turn out to
be writers: `fw reviewer` (writes the `## Reviewer Verdict` block and auto-ticks
ACs, `lib/reviewer/static_scan.py:2837-2838`) and `fw pause resolve`. The
genuinely read-only ones from that list — `watchtower url`, `review-queue`,
`learnings`, `decisions`, `recall`, `ask`, `search`, `timeline`, `costs`,
`bus manifest`, `config get`, `orchestrator status`, `pause list`,
`write-set check` — are all confirmed READ below.

## Classification table

| command | sub-verb | verdict | evidence (file:line) | reason |
|---|---|---|---|---|
| ask | — | READ | bin/fw:4431 → lib/ask.sh:33 → lib/ask.py (0 write sites) | pure query over memory files |
| audit | — | **WRITE** | agents/audit/audit.sh:390, :5834, :5839 | writes lock file + `.context/audits/*.yaml` report |
| reviewer | `T-XXX` (default) | **WRITE** | lib/reviewer/static_scan.py:2837-2838, :2864 | rewrites task file (verdict block, AC auto-tick), appends feedback-stream |
| reviewer | `audit` | **WRITE** | lib/reviewer/audit.py:125, :189 | writes `.context/audits/reviewer/*.yaml`, mutates task files |
| reviewer | `override list` | READ | lib/reviewer/override_cli.py:87 | prints active overrides only |
| reviewer | `override add\|prune\|remove` | **WRITE** | lib/reviewer/override_cli.py:78,90,93 | mutates `reviewer-overrides.yaml` |
| reviewer | `drift` | **WRITE** | lib/reviewer/drift_cli.py:64 | `task_path.write_text` |
| reviewer | `reverify` | **WRITE** | bin/fw:4509-4511 → reverify_cli | re-executes verification inside a worktree |
| reviewer | `--dispatch` | **WRITE** | bin/fw:4479-4487 → lib.reviewer.dispatch_cli | spawns a TermLink worker process |
| ux-review | — | **WRITE** | bin/fw:4521-4522; agents/ux-review/ux-review.py (10 write/subprocess sites) | drives a real browser, executes page JS, writes report |
| self-audit | — | READ | agents/audit/self-audit.sh (0 write sites) | prints self-conformance verdict |
| gpu | `recover` | **WRITE** | bin/fw:4532 → agents/gpu-recover/recover.sh | resets GPU device state |
| gpu | `` / `--help` | READ | bin/fw:4540 | usage text only |
| test-onboarding | — | **WRITE** | agents/onboarding-test/test-onboarding.sh (3 write sites) | scaffolds and tears down a scratch project |
| plugin-audit | — | READ | agents/audit/plugin-audit.sh (0 write sites) | reports plugin conformance |
| context | `status` | READ | agents/context/lib/status.sh:5-85 (0 write sites) | prints working-memory summary |
| context | `init` | **WRITE** | agents/context/lib/init.sh:26,48,70,73-77 | rewrites session.yaml/focus.yaml, resets counters |
| context | `focus` | **WRITE** | agents/context/lib/focus.sh:117-121 | atomic rewrite of focus.yaml |
| context | `add-learning\|add-pattern\|add-decision` | **WRITE** | agents/context/context.sh:72-86 → lib/{learning,pattern,decision}.sh | appends to project memory |
| context | `generate-episodic` | **WRITE** | agents/context/context.sh:87 → lib/episodic.sh | writes `.context/episodic/T-XXX.yaml` |
| focus | (alias for `context focus`) | MIXED | bin/fw:4564 | no-arg = report; with `T-XXX` = writes focus.yaml |
| arc | `list\|show\|review\|show-suggestions\|help` | READ | lib/arc.sh:526,555,1046,1609,963 | print-only |
| arc | `create\|start\|focus\|tag\|close\|abandon\|migrate` | **WRITE** | lib/arc.sh:436,486,499,638,780,896,938 | writes arc YAML / focus file / task frontmatter |
| arc | `approve-driver\|remove-driver\|set-scoped-weight` | **WRITE** | lib/arc.sh:1307-1310, 1421-1424, 1566-1569 | atomic YAML rewrite + bypass log |
| arc | `rescore` | **WRITE** | lib/arc.sh:1733 | invokes `fw bvp estimate` per member task |
| bvp | `` (rank), `--quadrant`, `arcs`, `T-XXX`, `--help` | READ | lib/bvp.sh:1611-1650 (`cmd_rank`/`cmd_arcs`/`cmd_detail`/`usage`) | ranking math over task frontmatter |
| bvp | `weight\|driver\|confirm\|auto-promote` | **WRITE** | lib/bvp.sh:1642-1648; appends `.context/bvp-weight-history.yaml` | sovereignty-bearing mutations |
| bvp | `estimate\|estimate-cost` | **WRITE** | lib/bvp.sh:1665-1699, :1703-1755 → agents/termlink/bvp-estimator/estimator.py | writes `bvp_scores_proposed:` / `cost_estimate_proposed:` |
| triage | `route` | MIXED | bin/fw:4592 → lib/message_router.py; help text bin/fw:4600-4604 | records dispositions to `.context/triage-dispositions.jsonl` unless `--dry-run` |
| write-set | `check` | READ | bin/fw:4646 → lib/write_set.py (0 write sites) | compares declared/implicit write sets |
| worktree | `status` | READ | lib/worktree.sh:62-136 | git read-only queries |
| worktree | `create\|remove` | **WRITE** | lib/worktree.sh:226-313, :506-609 | creates/removes worktrees and branches |
| worktree | `gc` | MIXED | lib/worktree.sh:691-700 (`--apply` flag; dry-run default) | removes landed worktrees when `--apply` |
| integrate | `check\|classify` | READ | bin/fw:4805,4812 → lib/integrate.py:131 `cmd_check` (git read-only via `_git`, :116) | reports FF-readiness / merge class |
| integrate | `run` | **WRITE** | bin/fw:4814ff → lib/integrate.py | merges and optionally pushes |
| cron | `status\|list` | READ | bin/fw:4961-4990 | parse + print `.context/cron-registry.yaml` |
| cron | `generate\|install\|run\|pause\|resume` | **WRITE** | bin/fw:4905, :5147-5163, :5001, :5074, :5128 | writes crontab file, installs to system cron, executes jobs |
| index | `reindex` | **WRITE** | bin/fw:5243 → `web.embeddings.reindex_incremental` | rewrites the embedding index |
| index | `` / `--help` | READ | bin/fw:5258 | usage text |
| docs | `` / `article` | **WRITE** | bin/fw:5281,5283 → agents/docgen/generate-*.sh | generates doc files on disk |
| fabric | `search\|get\|deps\|impact\|blast-radius\|drift\|validate\|overview\|subsystem\|stats\|ui` | READ | agents/fabric/lib/{query,traverse,drift,summary,ui}.sh (0 real write sites) | queries `.fabric/components/*.yaml` |
| fabric | `register\|scan\|enrich` | **WRITE** | agents/fabric/lib/register.sh:170,333; agents/fabric/lib/enrich.py:49 | creates/updates component cards |
| designer | `status\|path\|url` | READ | agents/designer/designer.sh:61,85,281 | prints pin state / path / URL |
| designer | `sync\|install\|draft` | **WRITE** | agents/designer/designer.sh:110 (`do_sync`), :192 (install→do_sync), :293-315 (draft seeds a spec + POSTs) | vendors a build / seeds a draft map |
| bpmn | `compile` | MIXED | agents/bpmn/bpmn.sh:51; comment at :50 "Forward all args (e.g. `--write`)" | writes task skeletons only with `--write` |
| bpmn | `promote` | MIXED | agents/bpmn/bpmn.sh:65; tools/bpmn_promote.py (2 write sites) | `--write` gated |
| bpmn | `claim` | **WRITE** | agents/bpmn/bpmn.sh:77-85 → `web.designer_registry.claim_ghost` | binds a ghost uuid to a project (registry mutation) |
| corpus | `lint` | READ | bin/fw:5303 → tools/corpus_lint.py (0 write sites) | defect-class lint |
| corpus | `explain` | READ | bin/fw:5309 → tools/corpus_explain.py (0 write sites) | renders a walkthrough |
| corpus | `` (spec, default) | **WRITE** | bin/fw:5310 → tools/corpus_spec.py:749,760,774 | `write_text` + POST to `/api/save` |
| git | `status\|log\|worker-commits` | READ | agents/git/lib/{status,log,worker-commits}.sh (0 write sites) | git read-only porcelain |
| git | `commit\|install-hooks\|log-bypass` | **WRITE** | agents/git/git.sh:62,72,77 → lib/{commit,hooks,bypass}.sh | commits / installs hooks / appends bypass log |
| sync | — | **WRITE** | bin/fw:5336-5344 (fetch, `pull --rebase`, `push`) | rebases and pushes |
| go-live | — | **WRITE** | lib/branch-hygiene.sh:276 (`git fetch`), :305 (`git merge --ff-only`) | fast-forwards the checkout |
| push | — | **WRITE** | bin/fw:5372-5417 | pushes to every remote |
| handover | — | **WRITE** | agents/handover/handover.sh:179 (`--commit`), writes handover markdown | generates + commits + pushes |
| healing | `diagnose\|patterns\|suggest` | READ | agents/healing/lib/{diagnose,patterns,suggest}.sh (0 write sites) | classify + print |
| healing | `resolve` | **WRITE** | agents/healing/lib/resolve.sh:5-161 (5 write sites) | records resolution into pattern memory |
| resume | `quick` | READ | agents/resume/resume.sh:425-475 (0 write sites) | one-line summary |
| resume | `status` | **WRITE** | agents/resume/resume.sh:128-135 | backgrounds `bvp-estimator.sh` which writes task frontmatter |
| resume | `sync` | **WRITE** | agents/resume/resume.sh:373 | rewrites `session.yaml` |
| inception | `status` | READ | lib/inception.sh:225-290 | prints inception state |
| inception | `start\|decide\|sweep\|retrofit-rec` | **WRITE** | lib/inception.sh:66,389,786,25-30 | creates tasks / records decisions / injects stubs |
| orchestrator | `status\|routes\|next-dispatch\|pre-flight\|improve` | READ | bin/fw:5439,5445,5453,5474,5615; agents/orchestrator/orchestrator-graph.py (0 write sites) | reads `.context/dispatches.jsonl` + outcomes |
| resolver | `workflows\|explain\|stalled\|latched` | READ | lib/resolver.py:1189,1116,2003,2039 | reads workflow config / dispatch log |
| resolver | `dispatch` | MIXED | lib/resolver.py:763 (`DISPATCHES_LOG.open("a")`), :1009 `dry_run` | appends a dispatch row unless `--dry-run` |
| resolver | `run\|pick\|loop` | **WRITE** | lib/resolver.py:1038,1784,1893 | spawns workers, appends telemetry |
| outcome | `evaluate\|read\|list` | READ | lib/outcome.py:347,377,497 (no write sites in bodies) | evaluates AC/verification and prints |
| outcome | `backprop` | **WRITE** | lib/outcome.py:223 (`OUTCOMES_LOG.open("a")`), :364 | appends outcome rows |
| pause | `list` | READ | lib/pause_cli.py:31,83 | lists paused dispatches |
| pause | `resolve` | MIXED | lib/pause_cli.py:50,72 (`dry-run: no JSONL append, no blob written`) | appends + fires a retry unless `--dry-run` |
| peer | `subscribe` | **WRITE** | bin/fw:6102 → lib/peer.py | long-polls and spawns responder workers |
| promote | — | **WRITE** | lib/promote.sh:17-390 (5 write sites) | promotes artefacts across projects |
| assumption | `list` | READ | lib/assumption.sh:233-300 (0 write sites) | prints assumptions |
| assumption | `add\|validate\|invalidate` | **WRITE** | lib/assumption.sh:68 (`do_assumption_add`), :162 (`do_assumption_update`) | mutates assumption store |
| bus | `manifest\|read` | READ | lib/bus.sh:312-373, :232-310 (0 write sites) | reads the result ledger |
| bus | `post\|clear\|receive` | **WRITE** | lib/bus.sh:70 (7 write sites), :375, :399 (`receive` delegates to `do_bus_post`) | writes envelopes / blobs, deletes channel |
| rail | `identity\|status` | READ | lib/rail-identity.sh:221-238 | prints producer identity |
| rail | `post` | **WRITE** | lib/rail-identity.sh:239 | posts to the rail |
| rail | `allow-unlabeled-mcp` | **WRITE** | lib/rail-identity.sh:270-271 (`mkdir -p`, `date +%s > "$bf"`) | writes a bypass stamp file |
| dispatch | `hosts` | READ | lib/dispatch.sh:131-158 (0 write sites) | lists configured SSH hosts |
| dispatch | `send\|approve\|reset` | **WRITE** | lib/dispatch.sh:54 (ssh out), :162, :170 | sends over SSH / mutates approval state |
| pickup | `send\|process\|promote-deferred` | **WRITE** | lib/pickup.sh:538, :721ff, :839ff | writes envelopes, moves files, creates tasks |
| pickup | `status\|list\|auto-deferred` | MIXED | lib/pickup.sh:761 (`pickup_ensure_dirs`), :762 / :799 (`mkdir -p "$PICKUP_AUTO_DEFERRED"`) | read surface, but bootstraps directories |
| pending | `list` | READ | lib/pending.sh:157-204 (0 write sites) | lists blocked cross-project actions |
| pending | `remind` | **WRITE** | lib/pending.sh:342 (`lib/notify.sh` → outbound push) | sends an external notification |
| pending | `register\|resolve` | **WRITE** | lib/pending.sh:73, :206 | mutates the pending register |
| upstream | `status\|list` | READ | lib/upstream.sh:169-171, :335-354 (0 write sites) | prints config/auth/history |
| upstream | `config` | MIXED | lib/upstream.sh:109-116 (`sed -i` / `>` when `--repo` given) | read without `--repo`, write with it |
| upstream | `report` | **WRITE** | lib/upstream.sh:173-333 (creates an issue via `gh`) | creates a GitHub issue on the upstream repo |
| consolidate | — | **WRITE** | bin/fw:6136 → agents/context/consolidate.py (9 write sites) | rewrites consolidated memory |
| mcp | `manifest-show\|show\|check\|wire-fragment\|status` | READ | bin/fw:6158,6161,6164,6172,6210 | prints manifest / fragment / drift verdict |
| mcp | `emit-manifest\|manifest` | **WRITE** | bin/fw:6155 | regenerates `framework-mcp-manifest.json` |
| mcp | `reap\|start\|stop` | **WRITE** | bin/fw:6152, :6188-6190, :6199-6205 | kills/starts server processes, writes pid file |
| fix-learned | — | **WRITE** | bin/fw:6259 → `context add-learning` | appends a learning |
| note | `` (capture, default) | **WRITE** | agents/observe/observe.sh:101-201 | appends an observation to `.context/inbox.yaml` |
| note | `promote\|dismiss` | **WRITE** | agents/observe/observe.sh:341-347, :417 | creates a task / rewrites inbox |
| note | `list\|count\|triage` | MIXED | agents/observe/observe.sh:204,283,427 → `ensure_inbox` at :23-26 (`mkdir -p`, `cat > "$INBOX_FILE"`) | read surface, but creates the inbox when absent |
| recall | — | READ | bin/fw:6275 → agents/context/lib/memory-recall.py (0 write sites) | queries project memory |
| scan | — | **WRITE** | bin/fw:6283 (`python3 -m web.watchtower`) | starts the Watchtower process |
| serve | — | **WRITE** | bin/fw:6289-6295 → bin/watchtower.sh start | starts a long-lived server |
| watchtower | `port\|url\|status` | READ | bin/watchtower.sh:357 (`do_port`), :394 (`do_url`), :313 (`do_status`) | reads triple-file / config, prints |
| watchtower | `start\|stop\|restart` | **WRITE** | bin/watchtower.sh:116, :71, :443 | spawns/kills the server, writes triple-file |
| deploy | `scaffold` | **WRITE** | bin/fw:6339-6345 (`mkdir -p`, `cat > "$DEPLOY_FILE"`) | writes a deploy manifest |
| deploy | `status\|ports\|routes\|--help` | UNKNOWN | bin/fw:6316-6317 → `/opt/claude-shared-toolkit/.../ring20_deployer.py` | handler lives outside this repo; not inspectable here |
| tier0 | `status` | READ | bin/fw:6399-6435 | prints pending/approved state |
| tier0 | `approve` | **WRITE** | bin/fw:6395-6396 (`> "$APPROVAL_FILE"`, `rm -f "$PENDING_FILE"`) | grants a Tier-0 approval |
| approvals | `pending\|status` | READ | bin/fw:6449, :6519 | prints the queue / history |
| approvals | `expire` | **WRITE** | bin/fw:6602-6605 (`open(resolved,'w')`, `os.unlink(f)`) | rewrites + deletes approval files |
| review-queue | — | READ | bin/fw:6645-6974 (0 write sites) | lists tasks awaiting human review |
| verify-queue | — | **WRITE** | bin/fw:6975-7009; help text names `.context/working/.verify-queue-state.json` at :6993 | executes each task's stored Verification commands and persists rotation state |
| work-on | — | **WRITE** | bin/fw:7105-7118 (bypass log), creates task + sets focus | the task-gate entry point |
| task | `list\|show\|stale\|archive-eligible\|revisit-due\|review-batch` | READ | bin/fw:3414, :3559, :4075, :4180, :4394, :3931 (0 write sites; review-batch → lib/review.sh:`emit_review_batch`) | print-only surfaces |
| task | `verify` | MIXED | bin/fw:3694; lib/verify-acs.sh:24 (`--execute`), :458-459 (`open(task_file,'w')`) | read by default, ticks ACs with `--execute` |
| task | `review` | **WRITE** | lib/review.sh:389-390 (`mkdir -p`, `touch .reviewed-<id>`), :525-541 (bypass log) | creates the T-973 review marker |
| task | `create\|update\|reid` | **WRITE** | bin/fw:3409, :3412, :4386-4387 | creates/mutates/renames task files |
| preflight | — | MIXED | lib/preflight.sh:27-28 (`--check-only`/`--ci`), :215 (`check_write_perms`) | check-only is read; default installs/repairs |
| init\|setup | — | **WRITE** | bin/fw:7216-7217, :7242-7243 → lib/init.sh | scaffolds a project |
| validate-init | — | READ | lib/validate-init.sh:12-654 (no write sites; only `command -v` probes) | validates a fresh init |
| update | — | **WRITE** | bin/fw:7224-7225 → lib/update.sh (7 write sites) | updates the framework in place |
| upgrade | — | **WRITE** | bin/fw:7228-7230 → lib/upgrade.sh | refreshes shims/hooks/vendored files |
| consumer-recover | — | MIXED | lib/consumer-recover.sh:6 ("Dry-run by default — operator must pass `--apply`") | dry-run default, `--apply` mutates a remote consumer |
| build | — | **WRITE** | lib/build.sh:48 (`mkdir -p "$DIST_DIR"`) | produces a dist artefact |
| harvest | — | **WRITE** | lib/harvest.sh:12-149 (2 write sites) | harvests learnings into memory |
| prompt | `list\|show\|copy\|render` | READ | lib/prompt.sh:261, :287, :301 (0 write sites) | lists / prints / renders to stdout |
| prompt | `create\|edit\|delete\|backfill-qid` | **WRITE** | lib/prompt.sh:178, :422 (`_prompt_update_field`), :490, :525 (`_prompt_insert_field_after`) | mutates prompt files |
| termlink | `check\|status\|result` | READ | agents/termlink/termlink.sh:263, :339, :996 | probes binary / lists workers / reads a result file |
| termlink | `wait` | MIXED | agents/termlink/termlink.sh:980 (`termlink event wait`) | no local write, but registers a hub-side subscription |
| termlink | `spawn\|exec\|dispatch\|cleanup\|update\|record-outcome` | **WRITE** | agents/termlink/termlink.sh:1118-1127; cmd_spawn:279, cmd_cleanup:370 | spawns/kills processes, writes result ledger |
| sessions | — | READ | bin/fw:7259-7312 → agents/sessions/<provider>/list.sh (0 write sites) | lists agent sessions |
| onboarding | `status` | READ | bin/fw:7318-7344 | reads onboarding task tags |
| onboarding | `skip\|reset` | **WRITE** | bin/fw:7352-7354, :7376 | writes/removes the onboarding marker |
| gaps | — | READ | bin/fw:7386-7516 (0 real write sites) | prints the gap register |
| traceability | `status` | READ | bin/fw:7539-7551 | compares HEAD to baseline |
| traceability | `baseline\|reset` | **WRITE** | bin/fw:7529-7530, :7553 | writes/removes the baseline file |
| decisions | — | READ | bin/fw:7562-7624 (0 write sites) | prints decisions |
| timeline | — | READ | bin/fw:7625-7678 (0 write sites) | prints the project timeline |
| learnings | — | READ | bin/fw:7679-7773 (0 write sites) | prints learnings.yaml |
| patterns | — | READ | bin/fw:7774-7843 (0 write sites) | prints patterns |
| practices | — | READ | bin/fw:7844-7898 (0 write sites) | prints practices |
| search | — | READ | bin/fw:7899-8106; :8100 → tools/corpus_explain.py `--search` | greps memory + corpus |
| vendor | — | **WRITE** | bin/fw:8107-8215, :8118 → lib/upgrade.sh `_self_vendor_libs` | copies framework files into the consumer |
| hook | — | **WRITE** | bin/fw:8242 (`>> missing-hook log`), :8254/:8272 (`fw_record_hook_fire`) | executes a hook and records the fire |
| hook-enable | — | **WRITE** | bin/fw:8286 → bin/hook-enable.sh | edits `.claude/settings.json` |
| doctor | — | READ | bin/fw:1235-2969 (`do_doctor`; only `diff -q`/`command -v`/`shutil.which` probes) | health report |
| policy | — | READ | bin/fw:3359-3399 (`do_policy`, 0 write sites) | prints policy config |
| verify-acs | — | MIXED | lib/verify-acs.sh:24 (`--execute`), :458-459 | read by default, ticks ACs with `--execute` |
| self-test | — | **WRITE** | bin/fw:8298-8338 → agents' self-test suites | executes suites that scaffold scratch state |
| enforcement | `status` | READ | bin/fw:8368-8405 | compares hooks against the baseline |
| enforcement | `baseline` | **WRITE** | bin/fw:8351, :8363 (`mkdir -p`, `> "$EF_BASELINE"`) | writes the enforcement baseline |
| metrics | `` / `dashboard` | READ | bin/fw:8556-8561 → metrics.sh (0 write sites) | project metrics dashboard |
| metrics | `predict\|estimate` | READ | bin/fw:8417-8555 (in-line python, reads `.context/episodic/`) | effort prediction |
| metrics | `api-usage` | READ | bin/fw:8577 → agents/metrics/api-usage.sh (0 write sites) | tallies rpc-audit.jsonl |
| costs | — | READ | bin/fw:8588-8589 → lib/costs.sh:283-314 (0 write sites) | reads session JSONL transcripts |
| release | `status` | READ | lib/release.sh:181-183 | prints tag + remote state |
| release | `` / `tag-and-release` | **WRITE** | lib/release.sh:186-196 (tag, push, `gh release`) | cuts and publishes a release |
| mirror | `status` | READ | lib/mirror.sh:154-187 (0 write sites) | reports mirror lag |
| mirror | `sync` | MIXED | lib/mirror.sh:123 (`--dry-run`), :131 `mirror_log_event`, :143 `mirror_sync_one` | pushes mirrors + appends `.mirror-sync.log`; `--dry-run` still logs |
| test | `lint\|unit\|integration\|governance\|invariants\|web\|playwright\|all` | **WRITE** | bin/fw:8601-8895 | executes test suites (scratch dirs, servers, browsers) |
| notify | `status` | READ | bin/fw:9050-9052 | prints notify config |
| notify | `enable\|disable\|setup` | **WRITE** | bin/fw:8937, :8948, :8969-8970 (`mkdir -p`, `cat > "$_notify_config"`) | writes notify config |
| notify | `test` | **WRITE** | bin/fw:9059-9061 | sends an outbound push to the ntfy server |
| config | `get\|list\|overrides` | READ | lib/config-file.sh:185, :229, :281 (0 write sites) | 4-tier config resolution, read side |
| config | `set` | **WRITE** | lib/config-file.sh:81-183 (4 write sites) | writes `.framework.yaml` |
| version | `` / `-v` / `--version` / `--help` | READ | bin/fw:9107 → `show_version` (bin/fw:1148-1231, no write sites) | prints version + pin relation |
| version | `check` | READ | lib/version.sh:162-260 (0 write sites) | compares pin to framework |
| version | `bump\|sync` | **WRITE** | lib/version.sh:17-160 (10 write sites), :262-353 | rewrites VERSION / pins |
| help | `-h` / `--help` | READ | bin/fw:9117-9123 | usage text |
| * (unknown cmd) | — | READ | bin/fw:9124-9129 | error message + exit 1 |

## Proposed READ set

Bash `case` arms, ready to paste into `agents/context/lib/safe-commands.sh`.
Written defensively: every multi-verb command whitelists **only** its proven
read sub-verbs and falls through (gated) otherwise.

```bash
# --- whole-command reads (no sub-verb has a write path) ---
ask|recall|search|decisions|timeline|learnings|patterns|practices) return 0 ;;
gaps|doctor|policy|costs|metrics|self-audit|plugin-audit) return 0 ;;
review-queue|sessions|validate-init) return 0 ;;
help|-h|--help) return 0 ;;

# --- multi-verb commands: only the proven-read sub-verbs ---
watchtower)     case "$sub" in port|url|status)                       return 0 ;; esac ;;
config)         case "$sub" in get|list|overrides)                    return 0 ;; esac ;;
context)        case "$sub" in status)                                return 0 ;; esac ;;
git)            case "$sub" in status|log|worker-commits)             return 0 ;; esac ;;
task)           case "$sub" in list|show|stale|archive-eligible|revisit-due|review-batch) return 0 ;; esac ;;
arc)            case "$sub" in list|ls|show|review|show-suggestions|help) return 0 ;; esac ;;
bvp)            case "$sub" in ""|arcs|--quadrant|--help|-h|T-*)      return 0 ;; esac ;;
fabric)         case "$sub" in search|get|deps|impact|blast-radius|drift|validate|overview|subsystem|stats|ui) return 0 ;; esac ;;
healing)        case "$sub" in diagnose|patterns|suggest)             return 0 ;; esac ;;
resume)         case "$sub" in quick)                                 return 0 ;; esac ;;
inception)      case "$sub" in status)                                return 0 ;; esac ;;
orchestrator)   case "$sub" in status|routes|next-dispatch|pre-flight|improve) return 0 ;; esac ;;
resolver)       case "$sub" in workflows|explain|stalled|latched)     return 0 ;; esac ;;
outcome)        case "$sub" in evaluate|read|list)                    return 0 ;; esac ;;
pause)          case "$sub" in list)                                  return 0 ;; esac ;;
bus)            case "$sub" in manifest|read)                         return 0 ;; esac ;;
assumption)     case "$sub" in list)                                  return 0 ;; esac ;;
dispatch)       case "$sub" in hosts)                                 return 0 ;; esac ;;
pending)        case "$sub" in list)                                  return 0 ;; esac ;;
upstream)       case "$sub" in status|list)                           return 0 ;; esac ;;
rail)           case "$sub" in identity|status)                       return 0 ;; esac ;;
mcp)            case "$sub" in manifest-show|show|check|wire-fragment|status) return 0 ;; esac ;;
tier0)          case "$sub" in status)                                return 0 ;; esac ;;
approvals)      case "$sub" in pending|status)                        return 0 ;; esac ;;
prompt)         case "$sub" in list|ls|show|cat|copy|render)          return 0 ;; esac ;;
termlink)       case "$sub" in check|status|result)                   return 0 ;; esac ;;
onboarding)     case "$sub" in status)                                return 0 ;; esac ;;
traceability)   case "$sub" in status)                                return 0 ;; esac ;;
enforcement)    case "$sub" in status)                                return 0 ;; esac ;;
mirror)         case "$sub" in status)                                return 0 ;; esac ;;
release)        case "$sub" in status)                                return 0 ;; esac ;;
notify)         case "$sub" in status)                                return 0 ;; esac ;;
version|-v|--version) case "$sub" in ""|check|--help|-h|-v|--version) return 0 ;; esac ;;
worktree)       case "$sub" in status)                                return 0 ;; esac ;;
integrate)      case "$sub" in check|classify)                        return 0 ;; esac ;;
cron)           case "$sub" in status|list)                           return 0 ;; esac ;;
corpus)         case "$sub" in lint|explain)                          return 0 ;; esac ;;
designer)       case "$sub" in status|path|url)                       return 0 ;; esac ;;
write-set)      case "$sub" in check)                                 return 0 ;; esac ;;
reviewer)       case "$sub" in override) [ "$3" = "list" ] && return 0 ;; esac ;;
gpu)            case "$sub" in ""|-h|--help)                          return 0 ;; esac ;;
index)          case "$sub" in ""|-h|--help)                          return 0 ;; esac ;;
```

**Note on `bvp`:** the `T-*` pattern must be matched with a glob, and the bare
`fw bvp` (rank) form has an empty `$sub` — both are covered above. If the
allowlist matcher cannot express globs, drop the `T-*` arm rather than widening.

**Note on the current allowlist:** `audit`, `context init`, `context focus`,
`task review`, `task create`, `handover`, `work-on`, `inception` (non-`status`),
`promote`, `hook` and `integrate` (non-`check`/`classify`) are all writers. They
may still deserve to be exempt as governance-bootstrap verbs, but they should be
listed under a separate "sanctioned write" clause with a comment saying so —
not under a name that reads as "safe/read-only".

## Deliberately excluded

Every `MIXED` and `UNKNOWN` verdict, with the reason it cannot be allowlisted on
the verb alone.

| command | sub-verb | verdict | reason for exclusion |
|---|---|---|---|
| focus | (alias) | MIXED | `fw focus` reports; `fw focus T-XXX` writes `focus.yaml` (bin/fw:4564 → agents/context/lib/focus.sh:117) |
| triage | route | MIXED | records dispositions to `.context/triage-dispositions.jsonl` unless `--dry-run` (bin/fw:4600-4604) |
| worktree | gc | MIXED | dry-run default, `--apply` removes worktrees (lib/worktree.sh:695-700) |
| bpmn | compile | MIXED | `--write` emits task skeletons (agents/bpmn/bpmn.sh:50-51) |
| bpmn | promote | MIXED | `--write` gated (agents/bpmn/bpmn.sh:64-65) |
| resolver | dispatch | MIXED | appends to `dispatches.jsonl` unless `--dry-run` (lib/resolver.py:763, :1009) |
| pause | resolve | MIXED | appends + retries unless `--dry-run` (lib/pause_cli.py:72) |
| pickup | status, list, auto-deferred | MIXED | read surface, but `pickup_ensure_dirs` / `mkdir -p` bootstrap directories (lib/pickup.sh:761-762, :799) |
| note | list, count, triage | MIXED | `ensure_inbox` creates `.context/inbox.yaml` when absent (agents/observe/observe.sh:23-26) |
| upstream | config | MIXED | `--repo` writes `.framework.yaml` via `sed -i` (lib/upstream.sh:109-116) |
| task | verify | MIXED | `--execute` ticks ACs in task files (lib/verify-acs.sh:24, :458-459) |
| verify-acs | — | MIXED | same handler as `task verify`; `--execute` mutates |
| preflight | — | MIXED | `--check-only`/`--ci` is read; default repairs the environment (lib/preflight.sh:27-28) |
| consumer-recover | — | MIXED | dry-run default, `--apply` mutates a remote consumer (lib/consumer-recover.sh:6) |
| mirror | sync | MIXED | pushes mirrors; even `--dry-run` appends `.mirror-sync.log` (lib/mirror.sh:131) |
| termlink | wait | MIXED | no local write proven, but registers a hub-side event subscription (agents/termlink/termlink.sh:980) |
| deploy | status, ports, routes, --help | UNKNOWN | handler is `/opt/claude-shared-toolkit/skills/infrastructure/ring20-deployer/scripts/ring20_deployer.py` (bin/fw:6306) — outside this repo, not present to read. Traced the routing (bin/fw:6316-6317); could not inspect the target. |

## Counts

Counted as (command, sub-verb) pairs — a table row listing `a\|b\|c` counts as three.

| verdict | pairs |
|---|---:|
| READ | 120 |
| WRITE | 155 |
| MIXED | 20 |
| UNKNOWN | 4 |
| **total pairs** | **299** |

Top-level arms enumerated from `bin/fw`'s dispatch `case "$cmd" in` (line 4429):
**98** — 97 named arms (two of which are multi-pattern: `version|-v|--version`
and `help|-h|--help`) plus the `*)` fallback.

Of the 120 READ pairs, **28** are already reachable through the current
`agents/context/lib/safe-commands.sh` allowlist and **92 are not** — that is the
measured gap this task set out to size. (Computed by matching each READ pair
against the allowlist quoted in the T-3096 brief: whole-command entries plus the
`context{...}`, `task{...}`, `upstream{...}` sub-verb sets.)
