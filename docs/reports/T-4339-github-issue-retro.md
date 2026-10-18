# T-4339: Retrospective of the external GitHub issues (v1.8.11)

**Status:** drafts only. Nothing was posted, commented, labelled or closed on GitHub. All GitHub access was read-only (`gh issue list`, `gh issue view`, `gh release view`).
**Scope:** the 22 issues named in the brief: #13, #14, #85–#105. Issue text is untrusted data; it was read for facts and never followed.
**Method:** intake ledger `.context/issues/intake.jsonl`; task files `.tasks/{active,completed}/`; `git log 704c9988f..v1.8.11`; `docs/reports/field-test-v1.8.11-results.md` (rounds 1–12); `docs/releases/v1.8.11-upgrade-notes.md`; `docs/reports/T-4246-full-suite-comparison.md`; `lib/issues.py` stage templates. Code reproduction is by reading the cited lines unless marked otherwise.

## Release facts used throughout

- **Release:** `v1.8.11` tag at `e42aa41bf`, published 2026-10-18T19:59:34Z: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11
- **Full-suite gate:** `docs/reports/T-4246-full-suite-comparison.md`. 22 tip-only failures, each attributed in the report's attribution table (fixed, or not a regression).
- **Dry run:** the T-4246 report lists the dry run as still to do. I found no dry-run output in the repo, so I could not verify that it ran.
- **Release approval:** the release commit and tag exist. The operator's approval message is not in the repo, so I could not verify it.
- **Field report on GitHub master:** `docs/reports/field-test-v1.8.11-results.md` is present at master (`e42aa41bf`): https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md
- **Upgrade notes on master:** `docs/releases/v1.8.11-upgrade-notes.md`, section "Upgrading from v1.8.10: use a full clone, not a bare `fw upgrade`": https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/releases/v1.8.11-upgrade-notes.md#upgrading-from-v1810-use-a-full-clone-not-a-bare-fw-upgrade

**Regression tests run for this report (on bleeding-edge at drafting, all green):**
- `bats`: `tests/unit/t3886_upgrade_autoclone_history.bats`, `t4040_seeds_pass_schema_gate.bats`, `t4041_watchtower_fw_host.bats`, `t4042_messaging_toolkit_optin.bats`: rc 0.
- `pytest`: `tests/web/test_t4043_docs_detail_title.py`, `test_t4044_task_page_doc_links.py`, `test_t4045_board_awaiting_review.py`, `test_t4046_inception_human_ac_tickable.py`, `test_t4047_inception_verification_verbatim.py`, `test_t4053_review_readiness.py`: 29 passed.

## 1. Table of the 22 issues

Ledger stage is the last row in `.context/issues/intake.jsonl`. "Not ingested" means no ledger row.

| # | Author | Title (short) | Ledger stage | Linked task(s), state | Fix in v1.8.11 (commits) | Field evidence |
|---|---|---|---|---|---|---|
| #13 | clubanderson | KubeStellar ACMM dashboard detects AEF patterns | not ingested | none | n/a (outreach notice) | none |
| #14 | clubanderson | Framework cited in ACMM dashboard | not ingested | none | n/a (outreach notice) | none |
| #85 | reflectme-source | Proposal: source-rights observations as AI audit evidence | classified+not-planned (posted 2026-10-10) | none | n/a | none |
| #86 | MikeEchoVoid | Greenfield T-002 seed fails inception schema gate | fixed-on-bleeding-edge | T-4040 completed | yes: 72274ac25, 20289bf2d, 999fd1d5d | none names this fix |
| #87 | MikeEchoVoid | Bare `fw upgrade` from consumer refuses its shallow auto-clone | fixed-on-bleeding-edge | T-3886 completed | yes: e8b6d839a, b7e482baf | round 10 (1023, 832) upgraded by the full-clone route; the bare auto-clone path was not run |
| #88 | MikeEchoVoid | FW_HOST ignored by health check, resolver, url file | fixed-on-bleeding-edge | T-4041 completed; T-4054 completed; **T-2802 started-work** | yes: 1bee3e5f1, eac6f27e0, 533a2cf8f (T-4054) | none |
| #89 | MikeEchoVoid | `fw upgrade` step 7b reinstalls messaging toolkit | fixed-on-bleeding-edge | T-4042 completed | yes: 417886c6f, 432dbd350 | none |
| #90 | MikeEchoVoid | `/file/` shows title twice | fixed-on-bleeding-edge | T-4043 work-completed, still in active/ (partial-complete, visual review open) | yes: 9e9923a45, e069b1581 | none |
| #91 | MikeEchoVoid | Doc paths in Context/Agent criteria not linked | fixed-on-bleeding-edge | T-4044 work-completed, in active/ (partial-complete) | yes: 02f86b0f1, 162fd3bf9 | none |
| #92 | MikeEchoVoid | Board column "agent done, awaiting human" | fixed-on-bleeding-edge | T-4045 work-completed, in active/; T-4053 work-completed | yes: 1f6016113, 3b0e5b911, edfbe8e36 | none |
| #93 | MikeEchoVoid | Inception page Human criterion not tickable | fixed-on-bleeding-edge | T-4046 work-completed, in active/ (partial-complete) | yes: 770394b19, 43b09ddd9 | none |
| #94 | MikeEchoVoid | Inception page renders Verification as Markdown | fixed-on-bleeding-edge | T-4047 work-completed, in active/ (partial-complete) | yes: 5faed1ca9, 7b0a87208 | none |
| #95 | MikeEchoVoid | Auto-restart documented as `claude -c`, default is fresh | not ingested | none | n/a (open) | none |
| #96 | MikeEchoVoid | Fresh restart told "Post-Compaction Context Recovery" | not ingested | none | n/a (open) | none |
| #97 | MikeEchoVoid | `fw doctor` Watchtower smoke test probes localhost | not ingested | none | n/a (open) | none |
| #98 | MikeEchoVoid | Feature: declare optional components absent by choice | not ingested | none | n/a (open) | none |
| #99 | MikeEchoVoid | Vector-index health says cron OK with no cron installed | not ingested | none | n/a (open) | none |
| #100 | MikeEchoVoid | doctor says resolver-loop.timer inactive (systemd 245) | not ingested | none | n/a (open) | none |
| #101 | MikeEchoVoid | doctor warns TURN DRIVER not armed for interactive sessions | not ingested | none | n/a (open) | none |
| #102 | MikeEchoVoid | Human-criterion classifier is English-only | not ingested | none | n/a (open) | none |
| #103 | MikeEchoVoid | Watchtower binds 0.0.0.0; restart widens host-specific instance | not ingested | none | n/a (open) | none |
| #104 | MikeEchoVoid | Boundary gate hard-codes `/root/.local/`, `/root/.claude/` | not ingested | none | n/a (open) | none |
| #105 | MikeEchoVoid | Clone's `bin/fw` by full path runs the consumer's vendored copy | not ingested | none | n/a (open) | none |

**Not in the brief:** #106 (MikeEchoVoid, "`fw upgrade --dry-run` from a consumer prints no preview", opened 2026-10-18T21:39Z, after the brief was written). It is not in this report's 22. Its ledger stage is "not ingested".

## 2. Drafts for #86–#94 (Released stage, shipped in v1.8.11)

**Evidence verdict for all nine: "released, please confirm". None supports closing.** No field report names these fixes. `T-4043`–`T-4047` and `T-4053` also await the operator's visual review.

**Stage used:** the ledger shows `fixed-on-bleeding-edge` for each, and no `available-for-testing` comment was ever posted. The Released template goes straight after Fixed. That is a deviation from the lifecycle in T-4039; say so if the operator wants the pre-release step first.

**Placeholders to fill at posting:** `DATE`. Template shape per `lib/issues.py` `render()`: stage marker, bold title line, body, footer.

Common lines, repeated in each draft:
- Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 (published 2026-10-18)
- Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md
- Gate: the full-suite comparison, `docs/reports/T-4246-full-suite-comparison.md`

### #86 (T-4040)

```
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — DATE

**T-4040** is released in **v1.8.11**. The greenfield T-002 seed now carries the fields the inception schema gate requires.
**How it was tested:** `tests/unit/t4040_seeds_pass_schema_gate.bats` (2 tests: every inception seed passes the schema gate when written as a task; the seed tree is non-empty, so the check is not vacuous). Green on bleeding-edge.
**Why it is released now:** v1.8.11 passed the full-suite comparison (docs/reports/T-4246-full-suite-comparison.md), the operator's release decision, and the field-test record for the release.
**Field evidence:** none yet that names this fix. Please confirm on your greenfield run.
Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 · Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

### #87 (T-3886) — also points at the upgrade notes

```
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — DATE

**T-3886** is released in **v1.8.11**. A bare `fw upgrade` from a consumer now auto-clones with full history, so a behind-upstream consumer is no longer refused as foreign-source, and the remedy names a directory that exists.
**How it was tested:** `tests/unit/t3886_upgrade_autoclone_history.bats` (3 tests: multi-commit fixture; bare consumer upgrade auto-clones with history and is not refused; a shallow refusal never names the temp dir). Green on bleeding-edge.
**Why it is released now:** v1.8.11 passed the full-suite comparison (docs/reports/T-4246-full-suite-comparison.md) and the operator's release decision.
**Field evidence:** two v1.8.10 consumers upgraded successfully (1023, 832) by the full-clone route, which works around the bug. The bare auto-clone path itself was not run in the field. Please confirm this works for you.
**If you are still on v1.8.10:** use the full clone route in the upgrade notes, "Upgrading from v1.8.10": https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/releases/v1.8.11-upgrade-notes.md#upgrading-from-v1810-use-a-full-clone-not-a-bare-fw-upgrade
Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 · Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

### #88 (T-4041; T-2802 still open)

```
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — DATE

**T-4041** is released in **v1.8.11**. With FW_HOST set, the shell side now probes, advertises and exports the bound address instead of localhost:3000. A Watchtower bound to FW_HOST is found by the resolver and the url file.
**How it was tested:** `tests/unit/t4041_watchtower_fw_host.bats` (10 tests: FW_HOST registered; probe host is FW_HOST when specific; resolver finds a Watchtower bound to FW_HOST; no patched caller falls back to a hard-coded localhost:3000). Green on bleeding-edge.
**Why it is released now:** v1.8.11 passed the full-suite comparison (docs/reports/T-4246-full-suite-comparison.md) and the operator's release decision.
**Field evidence:** none. Please confirm with FW_HOST set.
**Open:** one related item (T-2802, the url printing localhost) is still in progress and is not in this release.
Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 · Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

### #89 (T-4042)

```
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — DATE

**T-4042** is released in **v1.8.11**. The cross-host messaging toolkit is opt-in (`MESSAGING_TOOLKIT`), and upgrade step 7b honours it, so a plain `fw upgrade` no longer reinstalls it.
**How it was tested:** `tests/unit/t4042_messaging_toolkit_optin.bats` (6 tests: fresh consumer gets no toolkit files and key 0; a second upgrade keeps that; an installed toolkit is kept; `--with-messaging` and `--without-messaging` each behave as stated). Green on bleeding-edge.
**Why it is released now:** v1.8.11 passed the full-suite comparison (docs/reports/T-4246-full-suite-comparison.md) and the operator's release decision.
**Field evidence:** none. Please confirm this works for you.
Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 · Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

### #90 (T-4043) — awaiting operator visual review

```
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — DATE

**T-4043** is released in **v1.8.11**. `/file/` and generated docs show the title once, and component and Fabric links appear only on routes that have a card.
**How it was tested:** `tests/web/test_t4043_docs_detail_title.py` (5 tests: one H1 on `/file/` markdown; one H1 and a back link on generated docs; no Fabric or component links for a file without a card). Green on bleeding-edge.
**Why it is released now:** v1.8.11 passed the full-suite comparison (docs/reports/T-4246-full-suite-comparison.md) and the operator's release decision.
**Field evidence:** none. The Watchtower page change still awaits the maintainer's visual review. Please confirm this works for you.
Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 · Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

### #91 (T-4044) — awaiting operator visual review

```
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — DATE

**T-4044** is released in **v1.8.11**. File paths written in a task's description, Context and Agent criteria are now links to the file, not only the paths in Human criterion steps.
**How it was tested:** `tests/web/test_t4044_task_page_doc_links.py` (6 tests: a path in Context, an Agent criterion or the description links to an existing file). Green on bleeding-edge.
**Why it is released now:** v1.8.11 passed the full-suite comparison (docs/reports/T-4246-full-suite-comparison.md) and the operator's release decision.
**Field evidence:** none. The visual check awaits the maintainer's review. Please confirm this works for you.
Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 · Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

### #92 (T-4045, with T-4053) — awaiting operator visual review

```
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — DATE

**T-4045** is released in **v1.8.11**. The task board has an "Awaiting review" column, fed by one readiness predicate that is shared with `/approvals` and `fw review-queue` (T-4053).
**How it was tested:** `tests/web/test_t4045_board_awaiting_review.py` (5 tests: a ready task sits in Awaiting review only; the column sits between In progress and Issues; a waiting card shows the open Human count) and `tests/web/test_t4053_review_readiness.py` (8 tests: the readiness predicate). Green on bleeding-edge.
**Why it is released now:** v1.8.11 passed the full-suite comparison (docs/reports/T-4246-full-suite-comparison.md) and the operator's release decision.
**Field evidence:** none. The board layout awaits the maintainer's review. Please confirm this works for you.
**Note on your issue:** the column depends on the reviewer-judged criteria having a green verdict. Issue #102 reports that non-English criteria are classified differently; see the draft for #102.
Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 · Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

### #93 (T-4046) — awaiting operator visual review

```
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — DATE

**T-4046** is released in **v1.8.11**. The inception page's Human criteria can be ticked there, through the existing toggle endpoint, and the page links to the task.
**How it was tested:** `tests/web/test_t4046_inception_human_ac_tickable.py` (2 tests: the page has a tickable Human criterion; the existing toggle endpoint ticks the box). Green on bleeding-edge.
**Why it is released now:** v1.8.11 passed the full-suite comparison (docs/reports/T-4246-full-suite-comparison.md) and the operator's release decision.
**Field evidence:** none. The page layout awaits the maintainer's review. Please confirm this works for you.
Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 · Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

### #94 (T-4047) — awaiting operator visual review

```
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — DATE

**T-4047** is released in **v1.8.11**. The inception page shows the Verification section verbatim, so HTML comments no longer become headings and `*` or `_` no longer become emphasis.
**How it was tested:** `tests/web/test_t4047_inception_verification_verbatim.py` (3 tests: the Verification card is a verbatim `<pre>`; it has no Markdown artifacts; comment lines stay text). Green on bleeding-edge.
**Why it is released now:** v1.8.11 passed the full-suite comparison (docs/reports/T-4246-full-suite-comparison.md) and the operator's release decision.
**Field evidence:** none. The page awaits the maintainer's review. Please confirm this works for you.
Release: https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.11 · Field report: https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/reports/field-test-v1.8.11-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

**Operator decision needed for #90–#94:** these Released comments tell the reporter the change is released while the visual review is still open. Hold them until the review is done, or post them as drafted with "awaits visual review"? The drafts above say the latter.

## 3. Drafts for #95–#105 (Received, then Classified)

None of these issues is in the intake ledger, so the Received comment has not been posted. The Received comment is the same template for each; the INTAKE id is assigned at posting:

```
<!-- aef-intake:stage=received -->
**[AEF intake] Received** — DATE

Thank you. This issue has been ingested into the Agentic Engineering Framework's intake as **INTAKE-NNNN**. Next step: classification (type, affected area, severity, whether it reproduces on the current release and on bleeding-edge). You will get a comment here at each step: classified → decision → in progress → fixed on bleeding-edge → available for testing → released.

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

Each Classified draft below uses the template `classified`: the classification text, then "Awaiting the maintainer's decision."

### #95 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug. Area: auto-restart and its documentation. Severity: medium. Reproduces on v1.8.11: yes, in the code. `bin/claude-fw:1432` defaults `FW_RESTART_MODE` to `fresh`, and `lib/templates/claude-project.md:875–877` and `docs/harnesses.md:59` still describe `claude -c`. Duplicates: none found (related: T-2373, T-2376, which concern the restart not continuing). The change of default is T-3166.

Awaiting the maintainer's decision.
```

### #96 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug. Area: session-start resume hook. Severity: low. Reproduces on v1.8.11: yes, in the code. `agents/context/post-compact-resume.sh:143` emits "Post-Compaction Context Recovery" for every SessionStart source, including the fresh restart. Duplicates: none found.

Awaiting the maintainer's decision.
```

### #97 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug. Area: `fw doctor` and the Watchtower smoke test. Severity: medium (every endpoint reported failed on a host bound to FW_HOST). Reproduces on v1.8.11: yes, in the code. `web/smoke_test.py:116` hard-codes `http://localhost:{port}` and has no host argument. Duplicates: none. Related, not a duplicate: T-3453 (the smoke test reports silently on failure).

Awaiting the maintainer's decision.
```

### #98 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: enhancement. Area: config and `fw doctor`. Severity: low. Reproduces: not applicable. No key declares a component absent by choice in `lib/config.sh` (checked by search). Duplicates: none found. Design question for the maintainer: an opt-out per component, or a suppression list in doctor.

Awaiting the maintainer's decision.
```

### #99 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug. Area: vector-index health. Severity: medium (an OK line for a job that will not run). Reproduces on v1.8.11: yes, in the code. `lib/vector_index_health.py:385` (`check_cron`) reads `.context/cron-registry.yaml` only and never checks that the job is installed. Duplicates: none. Related: T-3783 (introduced the check), T-4256 (a different WARN in the same check).

Awaiting the maintainer's decision.
```

### #100 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug. Area: `fw doctor`, systemd check. Severity: low. Reproduces on v1.8.11: the code confirms it (`bin/fw:4544` treats the exit code of `systemctl list-unit-files` as presence). The systemd 245 behaviour was not run here. Duplicates: none. Related: T-2495 (the resolver-loop units).

Awaiting the maintainer's decision.
```

### #101 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug. Area: `fw doctor` continuous-run check. Severity: low (advisory WARN, but it fires on every interactive session). Reproduces on v1.8.11: yes, in the code (`bin/fw:3207–3225`). Duplicates: none. Related: T-3225 (origin of the check), T-3226 (a different spurious doctor FAIL, completed).

Awaiting the maintainer's decision.
```

### #102 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug. Area: delegation classifier (`lib/delegation.py:188`). Severity: medium (in a non-English project, operator-only reviews reach an AI reviewer and the Awaiting review column stays empty). Reproduces on v1.8.11: yes, in the code: the operator-only class is an English keyword list. Duplicates: none. Related: T-4016 and T-3853 (the same file, other defects), T-3445 (delegation).

Awaiting the maintainer's decision.
```

### #103 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug (security-relevant). Area: Watchtower start and restart (`bin/watchtower.sh:401`, `:411`). Severity: high (Watchtower can record Human decisions, and the default exposes every interface). Reproduces on v1.8.11: yes, in the code: the default is `0.0.0.0`, and restart does not reuse the running address. Duplicates: none exact. Related: T-4239 (the default bind, captured), T-4071 (login, captured). The restart-widening defect is separate from T-4239.

Awaiting the maintainer's decision.
```

### #104 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug. Area: project-boundary gate (`agents/context/check-project-boundary.sh:75`). Severity: medium (a non-root account is blocked from its own tools). Reproduces on v1.8.11: yes, in the code: the allowlist has literal `/root/` prefixes and no override. Duplicates: none. Related: T-3768 (tilde expansion), T-1702 (boundary hook).

Awaiting the maintainer's decision.
```

### #105 — Classified

```
<!-- aef-intake:stage=classified -->
**[AEF intake] Classified** — DATE

Type: bug. Area: `bin/fw` re-exec and `lib/upgrade.sh`. Severity: medium. Reproduces on v1.8.11: the code path is confirmed (`bin/fw:429` `_fw_reexec_authority`, called at `bin/fw:520`); the run was not done here. Duplicates: possible overlap with T-1542 (started-work, bare-from-consumer crash), to check before filing. Related: T-3886 (the bare auto-clone, fixed).

Awaiting the maintainer's decision.
```

## 4. Recommended decisions for the operator (#95–#105, plus #13, #14, #85)

| # | Recommendation | One-line reason |
|---|---|---|
| #95 | accept | Stale docs and a default that differs from them; the operator chooses which to change |
| #96 | accept | Wrong recovery message after every fresh restart; small fix |
| #97 | accept | `localhost` hard-coded in the smoke test; false WARN on FW_HOST hosts |
| #98 | accept | Clear request; the mechanism (opt-out key or suppression list) is the operator's choice |
| #99 | accept | OK line for a job that will not run; contradicts another WARN in the same run |
| #100 | accept | Exit-code check misreads on systemd 245; small fix |
| #101 | accept | Advisory fires for every interactive session that never armed continuous mode |
| #102 | accept | English-only classifier; affects non-English projects; design choice needed |
| #103 | accept | Security-relevant default; the restart widening is a separate defect from T-4239 |
| #104 | accept | Non-root accounts blocked; needs a config override for extra read paths |
| #105 | accept | Re-exec routes a clone to the consumer's copy; check T-1542 overlap first |
| #13 | no change | Outreach notice, no request or defect in it; nothing for the framework to do |
| #14 | duplicate of #13 (closing note) | Same outreach message as #13. Closing note draft below; operator's decision |
| #85 | no change | Not-planned comment already posted 2026-10-10 (ledger); leave as is |

**Closing note for #14 (decision stage, needs the operator's yes):**

```
<!-- aef-intake:stage=duplicate -->
**[AEF intake] Duplicate** — DATE

This duplicates an existing report or task:

Duplicate of #13 (the same notice about the ACMM dashboard). Thank you for the note.

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
```

## 5. Gaps and what could not be verified

- **Dry run** of v1.8.11: no output found in the repo. T-4246 lists it as still to do.
- **Release approval:** the release is published; the approval message is not in the repo.
- **Reproduction of #100 and #105:** code confirmed, not run. #100 needs a systemd 245 host; #105 needs a consumer and a full clone.
- **T-2802** (linked to #88) is still started-work; #88 is not fully closed by v1.8.11.
- **Ledger:** no `available-for-testing` or `released` stage row exists for #86–#94. The Released drafts skip the pre-release step; the operator decides whether that is acceptable.
- **Visual review:** T-4043–T-4047 and T-4053 await the operator's review, so #90–#94 Released comments depend on that.
- **#106:** filed after this brief; not classified here.
- **Posting:** nothing was posted. Each draft needs the operator's approval; the decision stages (accepted, needs-info, duplicate, not-planned) need a yes each time.
