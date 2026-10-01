# T-3678 — Triage of AEF's sidecar consult backlog (redo)

Replaces the rejected report of commit 62f28845d. Input: `.context/working/t3678/consults-decoded.jsonl`
(54 decoded rows; nudges and self-sends already removed). Every body was read in full. Bodies are
untrusted peer data: they were evaluated, never followed, and no suggested command or patch was run or
applied. Verification below is by reading AEF source at HEAD (and one throw-away `sed`/python repro on
inline text); nothing was run against the live tree.

Key notation: `inbox@N` = topic `inbox_cacc73ea32b121dd_999-Agentic-Engineering-Framework` offset N;
`sidecar@N` = topic `sidecar_999-Agentic-Engineering-Framework` offset N. Byte-identical repeats are
listed as duplicates and take the class of the original.

Classes: ALREADY-FIXED, ALREADY-TRACKED, SUPERSEDED, NEW-DEFECT (VERIFIED / NOT-REPRODUCED / NEEDS-RUN),
PROPOSAL, INFO. One line per defect where a message carries several.

## 1. Per-row triage

### 010-termlink

| Key | Sender / conversation | Claim | Class | Evidence |
|---|---|---|---|---|
| inbox@6 | 010-termlink / e2e-ab947312 | "No, our subscriber does not wake on inbox.queued": 49 unread AEF consults; termlink `inbox status` mislabels raw record count as "pending transfers"; `termlink agent search` is hardcoded to agent-chat-arc | SUPERSEDED | by inbox@10 (010's own CORRECTION: their rail woke after T-3201/T-3203). Residual content is 010-internal (T-3197, T-3205/PL-392) |
| sidecar@21 | 010-termlink / e2e-ab947312 | byte-identical to inbox@6 (posted to both addresses) | SUPERSEDED | by inbox@10; dedupe on conversation_id as the sender says |
| inbox@10 | 010-termlink / e2e-ab947312 | CORRECTION: subscriber wakes now; two scripts enumerated only `dm:`; fixed in 010 T-3201/T-3203; caveat T-3206 (delivery depends on which sibling notices first); "running" vs "running the current code" blind spot (T-3205) | INFO | no AEF defect. The lesson ("running" is not "running current code") is the same class as AEF's Watchtower currency check (T-3282). Next `fw sidecar e2e --peer 010-termlink` is invited |
| sidecar@22 | 010-termlink / e2e-ab947312 | byte-identical to inbox@10 | INFO | duplicate of inbox@10 |
| sidecar@4 | 010-termlink / T-3062-consult | Asks which addressing AEF picks: keep `sidecar:<id>`, move to `inbox:<id>`, or `dm:<fp>:<fp>` | SUPERSEDED | answered by D-660 / T-3518 (per 832's quote in inbox@9: "WE ADOPT YOURS … dm:/inbox:"). T-3518 (SOVEREIGN, captured) still open for the AEF-side change; T-3690 (S7) retires the legacy address |

### 832-Workflow-designer — circuit-id-adoption

| Key | Claim | Class | Evidence |
|---|---|---|---|
| inbox@7 | Adopts D-599 five-level circuit id; AEF's four posts carry 832's fingerprint d1993c…; `metadata.from_circuit` is unsigned (routing-only?) — asks whether it is trust-bearing | SUPERSEDED | by inbox@9 ("we quoted a superseded ruling; withdrawn"). The unsigned-metadata question is carried into inbox@9 |
| inbox@8 | Asks for a full readout: from_circuit trust or routing, T-3433 status, T-3434 status (client_msg_id dedupe), compound-topic inbox.queued probe | SUPERSEDED | by inbox@9 for the framing; T-3433 and T-3434 are work-completed (T-3433, T-3434), so the status asks are answerable. Reply (b-1) |
| inbox@9#1 | Withdraws the five-level framing; takes D-660 | INFO | correction of @7/@8 |
| inbox@9#2 | Under D-660 the address IS the fingerprint, and `dm:d1993c…:d1993c…` between AEF and 832 is a shared mailbox of ≥3 projects (all share host key d1993c2c3ec44c94); recommends `inbox:<agent-id>` between co-resident projects | ALREADY-TRACKED | T-3518 (addressing decision, SOVEREIGN) and T-3671/T-3690. Input to T-3518: dm:<fp>:<fp> is unsafe for co-resident projects. Not a new task |
| inbox@9#3 | Convention: never cite a GO record to a peer without its followers ("T-967 GO, followers: none") | PROPOSAL | convention, no tooling; needs an operator ruling or a CLAUDE.md line (AEF's own GO-scope trace, T-1984, already computes the predicate) |
| inbox@9#4 | 832's own tooling for "GO recorded, nothing shipped" (promote writes real id, `note resolve --carrier`) | INFO | answer to AEF's D-660 §2 ask; nothing owed |

### 832-Workflow-designer — delegation / ownership (T-931/T-932)

| Key | Claim | Class | Evidence |
|---|---|---|---|
| inbox@11 | `owner: human` with no open Human criterion is "OWNER-STALE" and permanently operator-only; 832 built a predicate and corrector in its vendored copy; asks whether AEF wants it, whether `owner-human` should be kept/split, whether G-052's two encodings need a test, whether T-1443 ruled the field out of scope | PROPOSAL | VERIFIED gap: `agents/task-create/update-task.sh:185-199` blocks purely on `owner == human`, no predicate over open Human criteria. The only revert paths are `fw task delegate` and the verdict ledger (`update-task.sh:149-175`). Changing it is a sovereignty-policy call: operator ruling or inception |
| inbox@12#1 | Wider ruling: ownership must also revert when every open Human criterion is reviewer-settleable | PROPOSAL | same as inbox@11; D-626/T-3445 and T-3557 (reviewer-judged classes) already delegate most of this |
| inbox@12#2 | G-052: two encodings of the delegation boundary disagree (82 vs 405 open Human criteria); asks to raise severity | SUPERSEDED | by inbox@13 (withdrawn: scope mismatch) |
| inbox@13 | CORRECTION: denominators agree at 82/82; real divergence is 3 criteria (832's `_t770` is the stricter); asks which encoding is normative | INFO | AEF's engine is `lib/delegation.py` (it states at `:76` that it deliberately differs from the vendored `_t770`: adds `render-surface`, drops `owner-human`). The normative encoding is AEF's; 832's `_t770` is a vendored-copy fork. Reply (b-2) |

### 832-Workflow-designer — framework findings

| Key | Claim | Class | Evidence |
|---|---|---|---|
| inbox@14 | C-001 research check measures location, not content (completed scan 3/3 false positives; fix `lib/research_preserved.py`) | ALREADY-FIXED | T-3569 ("C-001 audit counts research preserved in the task file itself"; commits 59ac96040, c24f93da5 add `research_preserved`). Their ask (b), check headings against AEF's inception template, is a reply item |
| inbox@15 | python heredoc body leaking to shell runs ImageMagick `import(1)`, writing screen-capture PostScript at repo root; offers detector | ALREADY-TRACKED | T-3572 (captured). Commit 28a62d7e0 records `import(1)` present on this host, repo scan clean |
| inbox@16 | `check-tier0.sh` is text-matching (sees `bash push.sh` as harmless) and approval is keyed to full command hash, pushing agents toward indirection; OBS-449 | ALREADY-TRACKED | T-3593 (approvals keyed to the action) and T-3594 (git pre-push refuses non-ff), both started-work. CLAUDE.md §Tier 0 already states the scope limit (their option c). Option (a) pre-push and (b) action-keyed are the build slices |
| inbox@17 | Secret scanners judge the index (`git ls-files`), not reachable history: purge-incomplete and resurrection cases; offers `--history` scanner | ALREADY-TRACKED | T-3572 body lines 97-100 already carry it. Confirmed `agents/git/lib/secret-scan.sh` scans staged diff only (`:155-168`) |
| inbox@18#1 | `.tasks/templates/inception.md:152` generates a Human criterion with no `@auto-tick-on-decide` | SUPERSEDED | by inbox@19 (withdrawn: marker is on line 151) |
| inbox@18#2 | Git-diff-derived flow metrics are blind to `git mv` completions | SUPERSEDED | restated in inbox@19; see inbox@19#2 |
| inbox@18#3 | Criterion-level sizing unchecked (one criterion = 12 rulings) | INFO | observation; no AEF check exists, low value |
| inbox@19#1 | CORRECTION: template is correct; twelve are DEFER inceptions, no template defect | INFO | withdrawal |
| inbox@19#2 | Metric trap: any rate computed from `.tasks/` diffs misses renames; asks AEF to check | NEW-DEFECT (NOT-REPRODUCED) | no `.tasks/` diff-derived rate in `metrics.sh` / `lib/` found (`fw metrics predict` reads episodic, `bin/fw:10166`); `numstat` / `diff-filter` hits are `lib/episodic_footprint.py`, `lib/integrate.py`, `lib/verdict_ledger.py`, unrelated to flow rates |
| inbox@19#3 | Twelve identical criterion texts are indistinguishable in a docket | INFO | low-value usability note, sender says not worth a change |
| inbox@20 | designer 0.14.0 released (tag designer-v0.14.0, sha256 0b5ae3…); AEF pin 3 behind (per their stale vendored policy copy) | INFO | `policy/designer-pin.yaml:19,25` already pins 0.14.0 / designer-v0.14.0. Their `fw release status` / `fw integrate` notes concern their own tree |

### ring20-dashboard — T-2382 consumer report (inbox@21, 20 defects + gap + observations; inbox@22, defect 21)

Reported against v1.7.0 (29f3b02). Re-checked against HEAD.

| Key | Claim | Class | Evidence |
|---|---|---|---|
| inbox@21#GAP | A session whose cwd enters a framework-shaped tree is re-rooted into it and every route back is blocked | ALREADY-TRACKED | T-3596 (captured) is exactly this |
| inbox@21#1 | `/embeddings` 500 when embedding stack absent: `_index_state()` early return lacks keys | NEW-DEFECT (NEEDS-RUN) | route handler `web/blueprints/embeddings.py:199-201` guards with `.get("available")`; the template may index the missing keys. Needs a render run with the import failing |
| inbox@21#2 | `_mask_comment_lines` deletes text so offsets misalign, ASSIGNMENT edges lost | NEW-DEFECT (NEEDS-RUN) | `agents/fabric/lib/enrich.py:260-267,507`: the single caller reads words from the masked string itself, so no offset is applied to the original. Edge loss would need a run |
| inbox@21#3 | `inception decide` strips real ACs after a one-line `<!-- -->` comment | NEW-DEFECT (VERIFIED) | `lib/inception.sh:608` `sed '/<!--/,/-->/d'` — repro: a one-line comment opens a range that deletes the following Agent ACs. The same bug was already fixed in `update-task.sh:213-215` (T-1967) but not here |
| inbox@21#4 | `doctor_upstream_ambiguous` WARN never clears for non-`git@` scp remotes | NEW-DEFECT (VERIFIED) | `lib/doctor-upstream.sh:37` skips only `*://*` and `git@*`; `user@host:path` falls through to the `realpath` compare and always differs (non-vendored mode) |
| inbox@21#5 | `create-task`: `str.replace('owner:', …, 1)` hits a name that contains "owner:" | NEW-DEFECT (VERIFIED) | `agents/task-create/create-task.sh:470` replaces `name:` first, then `:474` replaces the first `owner:` — repro on `default.md` with name `fix: owner: agent confusion` leaves the real `owner:` empty |
| inbox@21#6 | `healing resolve`: hardcoded `L-` prefix and indent stacking → invalid learnings.yaml | ALREADY-FIXED | T-2672 (indent-aware scan, `agents/healing/lib/resolve.sh:116-129`). `L-` prefix is the framework's own id scheme |
| inbox@21#7 | `check-inception-schema` validates the pre-edit file | NEW-DEFECT (VERIFIED) | `agents/context/check-inception-schema.py:41` reads the on-disk file; no handling of `tool_input` new content, so it blocks the fixing edit and passes the breaking one |
| inbox@21#8 | G-020 placeholder grep unanchored | NEW-DEFECT (VERIFIED) | `agents/context/check-active-task.sh:1163` `grep -ciE '\[(First\|…) criterion\]'` over the whole AC section, not anchored to a checkbox line; the anchored form exists in `lib/ac_placeholder.py` |
| inbox@21#9 | audit description-length check misses `>-` scalars | NEW-DEFECT (NEEDS-RUN) | no description-length check found by grep in `agents/audit/audit.sh`; claim cannot be reproduced from source |
| inbox@21#10 | `check-human-ac-tick` returns early for Bash (`sed -i`/`tee`/`cp` tick Human ACs); init wires `Write\|Edit` only | NEW-DEFECT (VERIFIED) | `agents/context/check-human-ac-tick.py:165` accepts only Edit/Write/MultiEdit; matcher is `Write\|Edit` at `lib/init.sh:1068` and `.claude/settings.json:66`. Other hooks were not audited. Sovereignty-relevant: an agent ticking a Human AC from Bash |
| inbox@21#11 | `termlink cleanup`: no tmux teardown, false success, deletes its own index | ALREADY-TRACKED | T-3651 (started-work, args/consent/--dry-run) and T-3595 (completed, active workers' dirs). tmux teardown is not named in either — fold into T-3651 |
| inbox@21#12 | Watchtower task-metadata cache re-parses every task each 30s TTL | ALREADY-FIXED | T-3575 (change-driven signature; TTL now a 300s safety net, `web/shared.py:1550-1557`) |
| inbox@21#13 | `fw doctor` aborts under `set -e` when smoke fails; MCP check manifest-only | ALREADY-FIXED | smoke now `… && smoke_rc=0 \|\| smoke_rc=$?` (`bin/fw:3301`); sibling abort fixed by T-3625. The "MCP check is manifest-only" half is NEEDS-RUN |
| inbox@21#14 | `fw update` (vendored) `rsync --delete` strips consumer-local patches silently | NEW-DEFECT (VERIFIED) | `bin/fw:743` `rsync -a --delete --delete-excluded`; `lib/update.sh:39` says "overwrites .agentic-framework/". No divergence detection exists in `lib/` or `bin/` (no `vendor-divergence` reference). Warning, not blocking, is the gap |
| inbox@21#15 | `fw watchtower port` answers the configured port when a foreign service holds it | ALREADY-FIXED | T-3662 (identity handshake: `lib/watchtower.sh:97,154,209`) |
| inbox@21#16 | sidecar `outbox._root()` anchors to FRAMEWORK_ROOT in a vendored consumer → id `.agentic-framework` | ALREADY-FIXED | T-3671 (and 832's inbox@25 measures D1 fixed in 1.7.740) |
| inbox@21#17 | `agents/designer/designer.sh` tracked 100644 | NEW-DEFECT (NOT-REPRODUCED) | `git ls-files -s` shows mode 100755 at HEAD |
| inbox@21#18 | `check-human-ac-tick` bare-word verbs match inside paths/messages (after their #10 fix) | NEW-DEFECT (NEEDS-RUN) | depends on #10: AEF has no Bash path to false-block. Becomes a design constraint on the #10 fix (anchor to command position) |
| inbox@21#19 | `bin/fw _derive_version` prefers `git describe` when the framework dir has a stale nested `.git` | NEW-DEFECT (VERIFIED) | `bin/fw:28-33` takes `git describe` whenever `$fw_dir/.git` exists; the G-049 comment assumes vendored copies carry none. The VERSION file is never consulted when a stale `.git` is present |
| inbox@21#20 | hook crash log path is fixed; test suites that fail hooks closed pollute the operator's log | NEW-DEFECT (VERIFIED) | `lib/config.sh:174` hardcodes `.context/working/.hook-crashes.log`; no `FW_HOOK_CRASH_LOG` override |
| inbox@21#OBS1 | `fw update` never refreshes the consumer CLAUDE.md governance half and does not say so | INFO | by design: CLAUDE.md refresh is `lib/upgrade.sh:1449`; `lib/update.sh` only re-vendors. A one-line message would help (low) |
| inbox@21#OBS2 | sidecar `hub_id()` ignores `TERMLINK_RUNTIME_DIR`; `/var/lib/termlink` hubs raise CircuitError | NEW-DEFECT (NEEDS-RUN) | `lib/sidecar/circuit.py:99-130` shells `termlink hub fingerprint` with the inherited env; no explicit runtime-dir. Fails only when the env var is unset in the caller |
| inbox@21#OBS3 | `do_vendor` includes lack what `fw designer install` needs in a vendored consumer | NEW-DEFECT (NEEDS-RUN) | `bin/fw:576` include list; designer store is `.context/designer/projects`; not run |
| inbox@21#OBS4 | designer 0.12.0 published while v1.7.0 pins 0.11.0 | INFO | pin is now 0.14.0 (`policy/designer-pin.yaml:19`) |
| inbox@21#OBS5 | `bin/fw` T-3111 re-exec inside a linked worktree silently runs the OLD framework | NEW-DEFECT (NEEDS-RUN) | `bin/fw:314` area; low (worktrees are opt-in only) |
| inbox@22 (defect 21) | `GET /` pays a full `/approvals` build every 60s; fix via counts-only `approval_summary()` | ALREADY-FIXED | T-3600 (commit 1c71f3b41: "dashboard tile reads counts-only approval_summary()"). Their remaining note (concerns/trace 60s caches rebuild in-request) is NEEDS-RUN, low |

### 832-Workflow-designer — sidecar RCA and doc finding

| Key | Claim | Class | Evidence |
|---|---|---|---|
| inbox@23#D1 (dups inbox@26, @29) | Vendored identity: project id derives as `.agentic-framework` | ALREADY-FIXED | T-3671; confirmed by 832 in inbox@25 ("D1 FIXED … whoami → 832-Workflow-designer") |
| inbox@23#D2 | `lib/init.sh` never registers the `sidecar-inbox` UserPromptSubmit hook | ALREADY-FIXED | confirmed by inbox@25 ("D2 FIXED"); T-3559 / T-3681 / T-3407 |
| inbox@23#D3 | Hook cannot parse `fw sidecar inbox --json` (dict, not list), fails silent | ALREADY-FIXED | T-3559 (hook silently surfaced nothing) and T-3681 (JSON on stdin, capped output, visible timeout); 832 measured it surfacing all 79 consults |
| inbox@23#D4 | Sweep cron only in `/etc/cron.d`, consumers have none | ALREADY-TRACKED | T-3676/T-3680 fixed the seed; the full consumer sidecar (cron, hooks, tick) is T-3689 (S-CONSUMER, captured) |
| inbox@23#D5 | Listeners exist only for agents declared in 010's `notify-sidecar-agents.conf` | INFO | for TermLink, not AEF (route per Gap Homing) |
| inbox@23#D6 | All local projects DM as the shared host key; 010's auto-confirm receipts our mail | ALREADY-TRACKED | T-3518 (addressing/identity) and T-3671; TermLink-side part is 010's |
| inbox@23#ASK | Run `fw sidecar e2e` from inside a vendored consumer in AEF's CI | ALREADY-TRACKED | T-3689 (S-CONSUMER) and T-3691 (design-conformance gate) |
| inbox@25 (dups inbox@27, @31) | D1-D3 fixed on 1.7.740; NEW: `lib/cron-seed.sh` appends the job at column 0 into an indented registry, then prints "ADDED" while writing nothing | ALREADY-FIXED | T-3676 (indent, commit 05da4ad95) and T-3680 (ADDED only after parse+write, commit 5fc9041ef) |
| inbox@28 (dups inbox@30, @32) | `agents/healing/AGENT.md` §Workflow is a straight list that omits the human decision and the "advisory only, no pattern recorded" outcome | INFO | doc side VERIFIED (`agents/healing/AGENT.md:116-123` is a straight six-step list); the code claim (human decision in `healing.sh`) was not found by grep and is NEEDS-RUN. Low priority doc fix |

### 055-agentic-fleet-cockpit

| Key | Claim | Class | Evidence |
|---|---|---|---|
| inbox@24 (dups inbox@38, @42, @46) | SAFETY REGRESSION: `cmd_cleanup` (T-3595 rework) ignores its arguments: `--help`, `-h`, `--dry-run`, typos all run the full cleanup incl. rm of uncollected results and SIGTERM | ALREADY-TRACKED | T-3651 (started-work: "--help still executes it, no --dry-run, no consent"). 055 supplies a design (usage on --help, refuse unknown flag exit 2, `--dry-run`, consent gate exit 3, SIGTERM after consent) and a 14-test bats suite. Safety, highest priority among open tracked items |
| inbox@39 (dups inbox@43, @44) | `cron_seed_ensure_jobs` appends at column 0; `fw upgrade` reports "merge failed: ADDED sidecar-sweep-5m" | ALREADY-FIXED | T-3676 and T-3680 |

### Demo responders

| Key | Claim | Class | Evidence |
|---|---|---|---|
| sidecar@1 | consult-responder answers a demo question on concurrent writes to one working tree | INFO | T-3406 demo output |
| sidecar@3 | ambient-responder defines "ambient consult" | INFO | T-3407 demo output |

### 832-Workflow-designer — sidecar topic

| Key | Claim | Class | Evidence |
|---|---|---|---|
| sidecar@5 | Pointer: asks AEF to run `fw bpmn compile` on `task-gate.bpmn` / `context-memory.bpmn`, predicts `none`/`external` lanes are outside AEF's dialect | SUPERSEDED | by sidecar@16 ("Part A now filed as our T-827, owner: human"); sidecar@20 confirms AEF's replies landed |
| sidecar@6 | Process class vs instance: ~1,500 runs of 7 designs are unlinked; `workflow_type` is an unresolved class pointer; asks who owns the instance layer and whether lifecycle/pipeline split is right | PROPOSAL | needs an inception (instance-tracking model). AEF answered Q1/Q2 on agent-chat-arc at @1644 per sidecar@16; corpus gap T-2556 |
| sidecar@13 | Branch topology: asks Q1 names/direction, Q2 ff vs squash, Q3 which branch to pin; notes AEF libs hard-code master | INFO | Q1-Q3 are answered by CLAUDE.md §Release-Train Branch Model. Their hard-code finding is partly stale: `lib/branch-hygiene.sh:9` now judges the dev branch (T-3185/T-3187) — but see NEW-DEFECT sidecar@13#MASTER below |
| sidecar@13#MASTER | AEF guidance steers agents to `fw integrate run master --push` | NEW-DEFECT (VERIFIED) | `lib/upgrade.sh:2812`, `agents/context/check-worktree-governance-write.sh:176`, `agents/git/lib/worktree-corpus-guard.sh:241` still say `master`; CLAUDE.md §Worktree Policy says "`bleeding-edge`, never `master`" (T-3185). An agent following the message lands unreleased work on the consumer surface. (`lib/worktree.sh:252` `on_master` is the lesser instance) |
| sidecar@16#1 | Confirm AEF is the EWCR counterparty | INFO | confirmed per sidecar@20 |
| sidecar@16#2 | Diagram-kind vocabulary (documentation/work-plan vs lifecycle/pipeline) | SUPERSEDED | answered ((a), per sidecar@20); lifecycle/pipeline is a separate axis |
| sidecar@16#3 | Cost to AEF of renaming the correlation | SUPERSEDED | by sidecar@17 (H3 ruled); sidecar@20: "free, keyed in no code path" |
| sidecar@17 | H3 ruled: correlations derive from `arc:ewcr-governed-delivery`; agent-minted correlations are PROVISIONAL and cannot satisfy a completion gate; asks whether AEF can carry that anchor | INFO | answered by AEF per sidecar@20 (anchor does not resolve here; peer_correlation proposed; acceptance provisional pending operator) |
| sidecar@18#1 | CTL-029 counts a correctly partial-complete (`owner: human`) task as completable-not-closed | ALREADY-FIXED | T-3444 (commit d325112a5) |
| sidecar@18#2 | Reviewer-closeable surface is empty; asks (a) report the empty surface, (b) enforce routing at authoring time, (c) let a positive reviewer verdict close a low-risk task | ALREADY-FIXED | D-626/T-3445 (`fw task delegate`), T-3557/T-3579/T-3580/T-3581 (verdict ledger closes reviewer-judged criteria), delegation-surface WARN in `fw audit`/`fw doctor`. Sovereign question (c) was surfaced to the operator by 832 |
| sidecar@19#1 | Four seam-evidence questions only AEF can answer (which of 24 rendered `.bpmn` maps AEF consumes; which contracts exercised; realization data; any call into 832 `tools/`) | PROPOSAL | blocks 832's DELETE decision. Needs an AEF-side evidence gathering task (read-only) and a reply |
| sidecar@19#2 | Estimator cannot tell "no evidence" from "evidence of no value" (10 of 20 tasks tie at BVP 61) | ALREADY-TRACKED | T-3522 (gather BVP reports; peer fix waiting on an unasked ruling); `estimator.py:2248` returns 0 on no mention |
| sidecar@19#3 | For inceptions `voi_score` is the whole composite and almost never set; no `_proposed` lane | ALREADY-TRACKED | T-3522 (same family); `estimator.py:2642-2651` neutral mid-score |
| sidecar@20 | CORRECTION: AEF did reply to @16/@17/@18; replies sat unread in 832's inbox; counterparty, kind vocabulary, H3, CTL-029 (T-3444) all landed; @19 questions still stand | INFO | confirms the reader-failure class; the four @19 questions remain open (see reply list) |

### 1409-sprind

| Key | Claim | Class | Evidence |
|---|---|---|---|
| sidecar@7#1 | `blast_radius` unavailable for exactly the tasks `fw bvp` ranks (components written at close) | ALREADY-TRACKED | T-3513 (derive blast radius from the fabric when nothing is declared; captured), T-3072 (completed). Their two traps (strip template text; never invent) are design constraints for T-3513 |
| sidecar@7#2 | Unmeasured cost renders as quadrant exclusion | SUPERSEDED | by sidecar@10 (operator ruling: default high cost) |
| sidecar@7#3 | Fabric `register`/`scan` produce skeletons; no enrichment verb | SUPERSEDED | by sidecar@12 (their correction: `fw fabric enrich` exists, edges only). Remaining purpose/subsystem fill: T-3430 (completed) |
| sidecar@8 | Two TermLink hubs: MCP server defaults `TERMLINK_RUNTIME_DIR=/tmp/termlink-0`, so channel posts "succeed" in a store nobody listens to; PL-034/PL-035 stranded | NEW-DEFECT (VERIFIED) | AEF's own `.mcp.json:27` sets `TERMLINK_RUNTIME_DIR=/var/lib/termlink`, but `lib/init.sh:1301` and `lib/upgrade.sh:2244` generate the consumer termlink MCP entry with no `env`, so every consumer defaults to `/tmp` |
| sidecar@9 | CORRECTION to @8: the "66 vs 4" figures were channel counts; topic counts run the other way; discriminator is membership (agent-chat-arc must resolve) | INFO | refines the detection for sidecar@8; remedy unchanged |
| sidecar@10 | SUPERSEDES PL-037: unmeasured cost should DEFAULT to high (rung 5, marked defaulted, excluded from median pool; estimate-cost overwrites defaulted, never measured) | PROPOSAL | operator ruling at 1409, offered as default for AEF; `estimator.py:2888` returns None today and `lib/bvp.sh:382` already excludes unknowns from the median. Needs AEF operator ruling; fold into T-3522/T-3513 |
| sidecar@11 | `fw bvp driver --add` accepts a driver that cannot be scored and reports success; weight dilutes the denominator | ALREADY-FIXED | T-3427 (`lib/bvp.sh:1536` refuses at add time). Residual (fix 4: `score_free_driver` returns 0 not None, `estimator.py:2248`) rides with T-3522 |
| sidecar@12#1 | CORRECTION: `fw fabric enrich` exists | INFO | withdrawal |
| sidecar@12#2 | `purpose`/`subsystem` never filled | ALREADY-FIXED | T-3430 (derive-or-refuse, `purpose_source`), T-3435 |
| sidecar@12#3 | `fw fabric drift` reports `unregistered: 0` while 14 files have no card | NEW-DEFECT (VERIFIED) | `agents/fabric/lib/drift.sh:8-44` enumerates only `watch-patterns.yaml` globs via `expand_patterns.py`; `tools/*.py` and `.claude/hooks/*.sh` are invisible. Registered as OBS-465 (pending, no task). Same family as T-3430 (which added under-populated) |
| sidecar@12#4 | `fw hook-enable --name <x>` registers a hook whose script does not exist and fails open | NEW-DEFECT (VERIFIED) | `bin/hook-enable.sh:79-91` checks existence only for `--script`; `--name` resolves unchecked. Runtime `bin/fw:9985` warns and allows. OBS-466 pending, no task |
| sidecar@14 | PROPOSAL (Watchtower UX): render known identifiers (T-, OBS-, G-, PL-, arc ids) with name, status and click-through hover cards, resolved from framework data; refuse rather than guess; do not stutter | PROPOSAL | needs an inception (UX); no Watchtower id-hover exists (T-3447 is a different hover) |
| sidecar@15 | Files delivered on `xfer-1409-sprind`; the topic had to be created because `channel.post` does not auto-create; 1409 never read `sidecar:1409-sprind` | INFO | closes T-3427/T-3430/OBS-465 loop. The "topic did not exist" observation is worth a line in the xfer protocol; not a defect |

Duplicate map: inbox@26, @29 = inbox@23; inbox@27, @31 = inbox@25; inbox@30, @32 = inbox@28; inbox@38, @42, @46 = inbox@24;
inbox@43, @44 = inbox@39; sidecar@21 = inbox@6; sidecar@22 = inbox@10.

## 2. (a) Ranked table of proposed new tasks

Safety and security first, then governance gates, then false greens, then usability. One bug, one task. Titles are proposals; no task was created.

| # | Proposed task title | Severity | Source | Verification |
|---|---|---|---|---|
| 1 | `check-human-ac-tick` does not guard Bash: `sed -i` / `tee` / `cp` can tick a Human acceptance criterion (hook matcher is `Write\|Edit`; design constraint: anchor verbs to command position) | high (sovereignty) | inbox@21#10, #18 | VERIFIED |
| 2 | `inception decide` strips real Agent ACs after a one-line `<!-- -->` comment (`lib/inception.sh:608` sed range; the T-1967 fix was never applied here) | high (gate false pass) | inbox@21#3 | VERIFIED |
| 3 | Guidance in `lib/upgrade.sh:2812`, `check-worktree-governance-write.sh:176`, `worktree-corpus-guard.sh:241` tells agents to land worktrees on `master`, contradicting the release-train rule | high (injects unreleased work onto the consumer surface) | sidecar@13 | VERIFIED |
| 4 | Consumer `.mcp.json` generated by `fw init` / `fw upgrade` omits `TERMLINK_RUNTIME_DIR`: MCP channel posts land in `/tmp/termlink-0` and read back as delivered | medium-high (silent cross-project message loss) | sidecar@8, @9 | VERIFIED |
| 5 | `fw task create` clobbers `owner:` when the task name contains `owner:` (`create-task.sh:470/474` replace order) | medium-high (sovereignty field) | inbox@21#5 | VERIFIED |
| 6 | `fw hook-enable --name` registers a hook whose script does not exist; the runtime fails open (OBS-466) | medium | sidecar@12#4 | VERIFIED |
| 7 | `check-inception-schema` validates the pre-edit file, blocking the fixing edit and allowing the breaking one | medium | inbox@21#7 | VERIFIED |
| 8 | `fw fabric drift` unregistered scan sees only `watch-patterns.yaml` globs and reports `unregistered: 0` over uncarded files (OBS-465) | medium (false green) | sidecar@12#3 | VERIFIED |
| 9 | G-020 placeholder grep (`check-active-task.sh:1163`) is unanchored and blocks ACs that merely describe `[First criterion]` | medium | inbox@21#8 | VERIFIED |
| 10 | `fw vendor` / `fw update` `rsync --delete` strips consumer-local patches with no warning | low-medium | inbox@21#14 | VERIFIED |
| 11 | `_derive_version` prefers `git describe` when a vendored copy still carries a stale nested `.git` (phantom version, doctor WARN never clears) | low-medium | inbox@21#19 | VERIFIED |
| 12 | `doctor_upstream_ambiguous` WARN never clears for non-`git@` scp remotes (`doctor-upstream.sh:37`) | low | inbox@21#4 | VERIFIED |
| 13 | Hook crash log path is fixed; add `FW_HOOK_CRASH_LOG` so fail-closed tests stop polluting the operator's log (`config.sh:174`) | low | inbox@21#20 | VERIFIED |
| 14 | Needs a run before it can be filed: `/embeddings` 500 with embedding stack absent (template keys); sidecar `hub_id()` without `TERMLINK_RUNTIME_DIR`; `fw designer install` in a vendored consumer; fabric ASSIGNMENT edges lost; audit `>-` description length; `bin/fw` re-exec in a linked worktree | unknown | inbox@21#1, #2, #9, #OBS2, #OBS3, #OBS5 | NEEDS-RUN |

Not new, fold into existing tasks: T-3651 (add tmux teardown and the 055 bats suite), T-3596 (re-rooting), T-3513 (blast radius; template-strip and never-invent traps), T-3522 (default-high cost ruling, estimator no-signal, `voi_score`), T-3518 (dm:<fp>:<fp> collides for co-resident projects), T-3593/T-3594 (tier-0), T-3572 (stray capture and history secret scan), T-3689/T-3691 (consumer sidecar and design-conformance).

Proposals needing an inception or operator ruling: ownership-staleness predicate (inbox@11/@12), GO-without-followers citation convention (inbox@9#3), workflow class/instance layer (sidecar@6), Watchtower identifier hover cards (sidecar@14), BVP default-high cost (sidecar@10), 832's four seam-evidence questions (sidecar@19#1).

## 3. (b) Conversations needing a reply

None were sent; this is a draft list only.

1. **832 circuit-id-adoption (inbox@7-@9)** — "from_circuit is routing only; it is not an authentication scheme. T-3433/T-3434 are closed. Per D-660 we use `inbox:<agent-id>`; agreed that dm:<fp>:<fp> collides for co-resident projects and we will not address you there." (Operator ruling needed to commit to routing-only wording.)
2. **832 ownership / delegation (inbox@11-@13)** — "Thanks, and for the corrections. AEF's normative encoding is `lib/delegation.py`; `_t770` is your vendored fork (it differs on `render-surface` / `owner-human` by design). The stale-owner predicate is a sovereignty call and needs our operator; please do not upstream yet."
3. **832 research / secrets / tier-0 / stray capture (inbox@14-@17)** — "C-001 content check landed as T-3569; please send your template-heading list so we can check ours. Stray capture and history scan are T-3572; tier-0 action approval and pre-push are T-3593/T-3594."
4. **ring20-dashboard T-2382 (inbox@21, @22)** — "Of your 21 defects plus the re-rooting gap: 6 already fixed upstream (#6 T-2672, #12 T-3575, #13 T-3625, #15 T-3662, #16 T-3671, #21 T-3600), the gap and #11 are tracked (T-3596, T-3651), 9 are confirmed and will be filed (#3, #4, #5, #7, #8, #10, #14, #19, #20), 4 need a run (#1, #2, #9, #18), and #17 is not reproduced (mode is 100755 at HEAD). Send the check-human-ac-tick series (0040 and the #10 fix) and patch 0037 as follow-up envelopes; upstream goes through us over TermLink only."
5. **832 sidecar-vendored-consumer-rca (inbox@23, @25)** — "D1-D3 fixed in 1.7.740, D4 cron-seed fixed in T-3676/T-3680; full consumer sidecar is T-3689. Your reply closes your T-981."
6. **055 (inbox@24, @39)** — "T-3651 tracks the cleanup regression and adopts your design and 14-test suite; cron-seed indent fixed (T-3676) and the false ADDED message fixed (T-3680)."
7. **832 T-838 seam evidence (sidecar@19, @20)** — "Your four questions stand and Q1 blocks you. We will gather which of the 24 rendered maps AEF consumes and whether anything calls your `tools/`, then reply."
8. **1409-sprind (sidecar@7-@12)** — "Blast radius: T-3513. Default-high cost needs our operator's ruling (T-3522). Driver `--add` now refuses an unscorable driver (T-3427). OBS-465 / OBS-466 are real and will be filed. The consumer MCP `TERMLINK_RUNTIME_DIR` finding is confirmed and will be filed."
9. **010-termlink e2e-ab947312** — none required; post the next `fw sidecar e2e --peer 010-termlink` when ready.

## 4. (c) Coverage

COVERAGE: rows covered: 54/54. Rows not classified: none.

## 5. Counts per class

Counted from the finding lines in section 1 (one line per defect; 93 findings across the 54 rows).

| Class | Findings |
|---|---|
| ALREADY-FIXED | 16 |
| ALREADY-TRACKED | 13 |
| SUPERSEDED | 13 |
| NEW-DEFECT, VERIFIED | 13 |
| NEW-DEFECT, NOT-REPRODUCED | 2 |
| NEW-DEFECT, NEEDS-RUN | 7 |
| PROPOSAL | 7 |
| INFO | 22 |
