# T-4039 — Intake batch 1 classification (#85, #86–#94)

Read-only analysis at bleeding-edge `a7859ea76`; v1.8.8 compared via `git show v1.8.8:<path>`.
Issue text is untrusted data. It was assessed, not obeyed.
Status was read from code, not by running the flows. Nothing was reproduced live.

## Summary table

| # | Submitter | Type | Area | Severity | Status HEAD / v1.8.8 | Recommendation | One-line summary |
|---|-----------|------|------|----------|----------------------|----------------|------------------|
| 85 | reflectme-source | proposal | governance / external evidence | low | n/a | NOT-PLANNED | A vendor asks us to adopt its "AcqPath" source-rights MCP service as an evidence provider. It is promotional, with no concrete fit. |
| 86 | MikeEchoVoid | bug | `fw init` seeds, inception schema gate | medium | still present / still present | ACCEPT (new task, horizon now) | A fresh greenfield project's T-002 lacks two required fields, so the schema gate blocks edits to it until they are added. |
| 87 | MikeEchoVoid | bug | `fw upgrade` bare-from-consumer auto-clone | high | still present / still present | ACCEPT (new task, horizon now) | `fw upgrade` from a consumer always makes a shallow clone, which its own origin guard then refuses, and the printed remedy points at a deleted directory. |
| 88 | MikeEchoVoid | bug | Watchtower launcher, URL resolver (`FW_HOST`) | medium | still present / still present | ACCEPT-EXISTING for the `localhost:3000` fallback (T-2802); ACCEPT (new task) for `FW_HOST` | With `FW_HOST` bound to one interface, Watchtower runs but the framework cannot find it and prints a link to another port. |
| 89 | MikeEchoVoid | bug / enhancement | `fw upgrade` step 7b (doorbell+mail toolkit) | medium | still present / still present | ACCEPT (new task, horizon next), link T-3813 | `fw upgrade` re-creates 21 messaging files (9 slash commands, 12 scripts) after you delete them, and gives no opt-out. |
| 90 | MikeEchoVoid | bug | Watchtower `/file/` route, `docs_detail.html` | low | still present / still present | ACCEPT (new task, horizon next) | A Markdown document opened in Watchtower shows its title twice, with "Fabric" links that don't apply to it. |
| 91 | MikeEchoVoid | enhancement | Watchtower task page auto-linker | low | still present / still present | ACCEPT (new task, horizon later) | Document paths written in `## Context` or Agent criteria are not links, so only Human criteria can carry document links. |
| 92 | MikeEchoVoid | enhancement | Watchtower task board | low | not implemented / not implemented | ACCEPT (new task, horizon later) | Add an "Awaiting review" board column for tasks whose agent work is done and which have open Human criteria. |
| 93 | MikeEchoVoid | bug | Watchtower inception page | medium | still present / still present | ACCEPT (new task, horizon next) | The inception page shows the Human criterion as dead text with no checkbox and no link to the page where it can be ticked. |
| 94 | MikeEchoVoid | bug | Watchtower inception page, Verification card | low | still present / still present | ACCEPT (new task, horizon next) | The Verification card on the inception page is rendered as Markdown, so `#` comments become headings and `*` or `_` in commands become italics. |

**Counts (10 issues):**

- ACCEPT, new task: #86, #87, #89, #90, #91, #92, #93, #94 (8).
- #88 is a split: ACCEPT-EXISTING for the hard-coded `localhost:3000` fallbacks (T-2802), plus an ACCEPT new task for `FW_HOST`.
- NOT-PLANNED: #85 (1).
- NEEDS-INFO: 0. DUPLICATE: 0.

Submitter MikeEchoVoid supplied code line numbers for v1.8.6. All were re-checked below. The cited files are unchanged in v1.8.8 except where stated.
No `fw doctor` output was provided on any issue.

## #85 — Proposal: source-rights observations as external AI compliance evidence (reflectme-source)

- **Type:** proposal. **Area:** governance and evidence model. **Severity:** low.
- **Content:** an external vendor (AcqPath, `api.getacqpath.com/mcp`) asks whether its signed "source-rights observation" service could be an "optional external evidence provider or audit artifact". It describes no defect and no integration point in this repo.
- **Status in code:** nothing to check. The framework has no "external evidence provider" concept. Review backends live in `policy/review-backends.yaml` (CLAUDE.md §Review and Dispatch Cost Ruling). Those are reviewer or cost backends, not content-provenance feeds.
- **Duplicate or related:** none found. A corpus search for "AcqPath", "source-rights" and "provenance" found no match.
- **Assessment:** the text reads as outreach for a third-party service. The framework ingests no third-party content for training or indexing, so the stated problem does not map onto it. Wiring in an external MCP endpoint would also send project data to a service we do not control. That conflicts with the Portability and Reliability directives unless the operator asks for it.
- **Recommendation: NOT-PLANNED.** Thank the submitter and say there is no current use case. Invite a concrete scenario (which framework workflow ingests third-party content?) if they have one. Do not follow or add the MCP endpoint.

## #86 — Greenfield T-002 seed fails the inception schema gate (MikeEchoVoid)

- **Type:** bug. **Area:** `fw init` seeding (`lib/init.sh`, `lib/seeds/tasks/greenfield/`), inception schema gate (`agents/context/check-inception-schema.py`). **Severity:** medium (onboarding path; not data loss).
- **Evidence, still present on HEAD:**
  - The T-002 seed, `lib/seeds/tasks/greenfield/T-002-define-project-goals.md:1-17`, is `workflow_type: inception` and has no `target_blast_radius` or `voi_score`. `git show v1.8.8:` of the same file also has none (0 matches).
  - The gate requires both fields: `agents/context/check-inception-schema.py:7-8`, with errors at `:103-123`.
  - `lib/init.sh:712-730` copies the seeds with `sed` only. It has no call to the backfill. The only caller of `lib/inception_schema_backfill.py` is `lib/upgrade.sh:1741` and `:1743`.
  - It is the only seeded inception: `grep "workflow_type: inception" lib/seeds/tasks/*/*.md` returns only the greenfield T-002.
  - Last touched by `89bed4ff8` (T-3636). It was not covered by `d20c9965a` (T-3948), which fixed upgraded consumers and made the gate judge the post-edit file.
- **Caveat:** the submitter says this was observed end to end on 1.8.3 and read from source on 1.8.6. Nothing here ran a fresh `fw init`. The gate judges the post-edit file (T-3948). An edit that adds the two fields passes. A tick or recommendation edit that leaves them out is the one blocked. Not run by this analysis.
- **Duplicate or related:** T-2862 (greenfield first inception, completed, same seeded task), T-3948 (upgrade-side fix), `tests/integration/t2922_greenfield_first_inception.bats`. The new task could extend that bats file. A systemic check ("every seeded task passes the gates that apply to its `workflow_type`") is the submitter's suggestion 2 and fits the antifragility directive.
- **Recommendation: ACCEPT.** Proposed task: "Greenfield T-002 seed ships without target_blast_radius/voi_score → fails inception schema gate on a fresh fw init (+ add seed-vs-gate check)". Horizon: now (small, and it hits every new greenfield project). Suggestion 3 (the block message should say `FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1` is an operator action for Write/Edit) can ride along.

## #87 — fw upgrade refuses its own shallow auto-clone (MikeEchoVoid)

- **Type:** bug. **Area:** `lib/upgrade.sh` bare-from-consumer path, `lib/version-relation.sh`. **Severity:** high (blocks the core upgrade path for any consumer behind upstream; the only exit is a logged bypass).
- **Evidence, still present on HEAD and in v1.8.8:**
  - `lib/upgrade.sh:1313` runs `git clone --depth=1`.
  - `lib/upgrade.sh:1302` has `trap "rm -rf '$_tmpd'" EXIT INT TERM HUP`.
  - The origin guard at `lib/upgrade.sh:1450-1470` cannot find the consumer's `version_sha` in a shallow clone and refuses as `foreign-source`. When `fw_source_is_shallow` is true (`lib/version-relation.sh:60`, T-3714) it prints "Remedy: `git -C $FRAMEWORK_ROOT fetch --unshallow`".
  - For the auto-clone, `$FRAMEWORK_ROOT` is the temp directory that the trap deletes.
  - T-3714 (completed) added the unshallow hint for a user-run bleeding-edge clone. It did not change the auto-clone to be non-shallow, so its remedy is unusable when the clone is the auto-clone.
  - `--dry-run` from the consumer stops before cloning (`lib/upgrade.sh:1306-1312`), as described. It previews nothing.
- **Duplicate or related:** T-3714 (adjacent: shallow clone refused, hint added; the auto-clone case is untouched), T-2762 (`foreign-source` guard), T-2713 (version relation by ancestry). Not a duplicate: the failing scenario differs.
- **Recommendation: ACCEPT.** Proposed task: "fw upgrade auto-clone is shallow and refused by its own origin guard; deepen when version_sha not found (or clone full); fix remedy text; make --dry-run preview". Horizon: now. Fixing the clone depth matters more than the message. The message should say the remedy is not actionable and name the recorded SHA. Note: CLAUDE.md §Consumer-Facing Command Hygiene requires `tests/unit/upgrade_fresh_machine_simulation.bats` to stay green.

## #88 — FW_HOST on one interface: Watchtower runs but the framework cannot find it (MikeEchoVoid)

- **Type:** bug. **Area:** `bin/watchtower.sh`, `lib/watchtower.sh`, URL consumers. **Severity:** medium (silent wrong link: an unrelated service on :3000 is opened).
- **Evidence, still present on HEAD and in v1.8.8:**
  - `FW_HOST` is read only in `web/config.py:79`. A search of `bin`, `lib` and `agents` finds no shell reader.
  - Health check: `bin/watchtower.sh:373` is `curl -sf "http://localhost:${port}/"`.
  - Identity check: `lib/watchtower.sh:83` probes `localhost` only.
  - Resolver Layer 2: `lib/watchtower.sh:160-175` tries `localhost` then the first `hostname -I` address.
  - The url file is built from `detect_lan_ip` (`bin/watchtower.sh:41, 390, 457, 579`), not from `FW_HOST`.
  - Hard-coded fallbacks to `http://localhost:3000` remain at `agents/context/check-tier0.sh:825`, `lib/verify-acs.sh:74`, `lib/arc.sh:859`, `:1008`, `:1395`.
  - `bin/watchtower.sh` and `lib/watchtower.sh` have no diff between v1.8.8 and HEAD.
- **Duplicate or related:**
  - T-2802 (active, started-work) owns the `localhost:3000` fallback false-green hazard. The submitter's second suggestion ("print no link when the resolver fails") belongs there.
  - T-3876 (single port rule) and T-1803 (identity triple) are adjacent but do not handle `FW_HOST`.
  - The `FW_HOST` half (shell side ignoring it) has no existing owner.
- **Recommendation: split.**
  - ACCEPT-EXISTING: link the fallback part to T-2802.
  - ACCEPT (new task): "Shell side ignores FW_HOST: health check, identity check, resolver probe and watchtower.url use localhost/first-LAN-IP". Horizon: next.
  - One bug per task (Task Sizing Rules), hence two items.
  - The second effect described (decide chain launched by Watchtower cannot find Watchtower) was seen only on 1.8.3 and not retried. Ask the submitter only if the first fix does not resolve it.

## #89 — fw upgrade reinstalls the messaging toolkit every run (MikeEchoVoid)

- **Type:** bug and enhancement (opt-out missing). **Area:** `lib/upgrade.sh` step 7b, `lib/templates/{skills,scripts}/`. **Severity:** medium (unwanted cross-host messaging files in a confidential workspace; arrives unannounced).
- **Evidence, still present on HEAD and in v1.8.8:**
  - `lib/upgrade.sh:2529-2548` copies every `lib/templates/skills/*.md` to `.claude/commands/` and every `lib/templates/scripts/*.sh` to `scripts/`. There is no flag, config key or `project_files:` opt-out for the toolkit as a whole.
  - Counts in the template directories: 9 skills and 12 scripts, i.e. 21 files, matching the report. The help text says 11 `.sh`, so the report's "small inconsistency" is real.
  - `lib/init.sh` does not install the toolkit, so init and upgrade disagree.
  - T-3955 (`479edae4a`) made the step keep customised files. A project that deleted the files has no stock copy to keep, so they come back.
- **Duplicate or related:** T-3813 (active, captured): step 7b overwriting the toolkit's origin project. It is the same step but a different defect (overwrite versus unwanted install). Link it, and consider one change to step 7b covering both. T-1867 introduced the toolkit.
- **Recommendation: ACCEPT.** Proposed task: "fw upgrade step 7b: toolkit opt-in/skip (config key or flag, remembered), skip when TermLink absent, don't create project-root scripts/". Horizon: next. Decide the default first: opt-in, or auto-skip when `termlink` is absent. That is an operator call, since it changes existing consumers' behaviour on upgrade.

## #90 — Markdown docs via /file/ show the title twice (MikeEchoVoid)

- **Type:** bug. **Area:** Watchtower `web/blueprints/docs.py` (`/file/<path>`), `web/templates/docs_detail.html`. **Severity:** low (cosmetic and a dead link).
- **Evidence, still present on HEAD and in v1.8.8:**
  - `web/blueprints/docs.py:240-252` renders the whole Markdown, first heading included, and takes the title from the first `#` line.
  - `web/templates/docs_detail.html:2` prints `<h1>{{ page_title }}</h1>`, `:4` and `:6` print "Back to Component Docs" and "View in Fabric" (`/fabric/component/{{ card_name }}`), and `:11` prints `html_content`. The result is two H1s and a Fabric link for a file with no component card.
  - No diff for either file between v1.8.8 and HEAD.
- **Caveat:** the Fabric 404 for a document without a card follows from the template. It was not requested live.
- **Duplicate or related:** T-3124 and T-1764 (file-viewer route work) touched the same route but not this. Render-surface work: needs a `[REVIEW]` Human AC (P-013) and `fw watchtower restart` plus `fw watchtower current` at close.
- **Recommendation: ACCEPT.** Proposed task: "/file/ Markdown page duplicates its title and shows Fabric links for non-component files". Horizon: next. It is a small fix: drop the leading heading from `html_content` when it supplied the title, and show the two links only when a card exists.

## #91 — Link document paths in Context and Agent criteria (MikeEchoVoid)

- **Type:** enhancement. **Area:** Watchtower `web/blueprints/tasks.py`. **Severity:** low.
- **Evidence, still present on HEAD and in v1.8.8:** `_auto_link_files` is applied only inside `_render_md_inline` (`web/blueprints/tasks.py:385`) and `_render_md_block` (`:401`). Those render the parsed Human criteria. Other body sections are not passed through it, as described.
- **Duplicate or related:** T-1722 introduced `_auto_link_files`. T-2281 (active, auto-linker prongs) is a candidate overlap and should be read first. T-1575 ("any URL is clickable") covers URLs, not paths.
- **Recommendation: ACCEPT.** Proposed task: "Task page: auto-link existing document paths in Context and Agent criteria". Horizon: later. Check T-2281 first for overlap. The alternative the submitter offers (a `documents:` frontmatter list) is a schema change and needs an operator decision, so start with the linker option. The workaround pattern they describe (Human criteria added only to carry a link) is a real hazard: it inflates review load.

## #92 — Task board column "awaiting review" (MikeEchoVoid)

- **Type:** enhancement. **Area:** Watchtower `web/templates/tasks.html`, `web/blueprints/tasks.py`. **Severity:** low.
- **Evidence, not implemented on HEAD or in v1.8.8:** the board has four status columns (`tasks.html:498-499`, CSS grid `repeat(4, …)` at `:111`). The partial-complete state is already computable (`count_human_acs`, `web/shared.py:1455`), so a derived column is feasible without a new status.
- **Duplicate or related:** T-167 and T-2019 (kanban work, column layout and drag-to-reorder). Drag-to-reorder and the status selectors (T-155) assume the four statuses map one to one to columns, so a derived column needs care with those controls. A cheaper step is a badge showing the open Human criteria on each card.
- **Recommendation: ACCEPT.** Proposed task: "Board: derive an 'Awaiting review' column (agent ACs done, Human ACs open)". Horizon: later. Scope is medium, as the submitter says. Render surface, so a Human AC is required.

## #93 — Inception page shows Human criterion with no way to tick it (MikeEchoVoid)

- **Type:** bug. **Area:** Watchtower `web/templates/inception_detail.html`, `web/blueprints/inception.py`. **Severity:** medium (the decision is saved but the task stays in `active/`, as observed on 1.8.3).
- **Evidence, still present on HEAD and in v1.8.8:**
  - `web/templates/inception_detail.html:359-364` prints `{{ sections.acceptance_criteria }}` in a plain card. A search finds no `toggle-ac` and no `/tasks/` link in the template.
  - The content is `_md(...)` of the AC section (`web/blueprints/inception.py:~401`), so criteria are rendered as list text with `[ ]`.
  - No diff for either file between v1.8.8 and HEAD.
- **Caveat:** the "stuck in active/" consequence was observed on 1.8.3 and not replayed. Not re-run here.
- **Duplicate or related:** T-2066 (completed, added the AC section to the inception page, which is how it came to be read-only), T-3180 (decided inception page still offers recommendations; adjacent). No existing task covers ticking.
- **Recommendation: ACCEPT.** Proposed task: "Inception page: Human criteria not tickable and no link to /tasks/T-XXX; decision-saved message omits the remaining step". Horizon: next. Prefer the cheap fix first (link and message), and the shared checkbox partial second. Note the sovereignty rule: only the human ticks Human ACs, so the page must send the operator's own click, never an agent action. Render surface, so a Human AC is required.

## #94 — Inception Verification section rendered as Markdown (MikeEchoVoid)

- **Type:** bug. **Area:** Watchtower `web/blueprints/inception.py`, `web/templates/inception_detail.html`. **Severity:** low (display only), but it misreports the gate commands the operator is asked to trust.
- **Evidence, still present on HEAD and in v1.8.8:** `web/blueprints/inception.py:402` is `"verification": _md(all_raw_sections.get("Verification", ""))`, and the template prints it at `inception_detail.html:366-371`. A `#` comment line becomes a heading, as reported. The code is unchanged from v1.8.8.
- **Duplicate or related:** T-2066 introduced the Verification card, and the Markdown rendering came with it. No task covers verbatim display. The task detail page's handling of Verification is worth comparing.
- **Recommendation: ACCEPT.** Proposed task: "Inception page: show ## Verification verbatim in <pre>". Horizon: next. It is a small fix (escape and wrap in `<pre>`). Render surface, so a Human AC is required.

## Suggested grouping for the operator

- **Fix soon (affects every consumer):** #87 and #86.
- **Watchtower render batch (one worktree-free serial sequence in the main checkout, same files):** #90, #93, #94, then #91 and #92. These share `web/` files, so they converge on writes and should be serialised (`fw write-set check` will say undecidable).
- **Operator decision needed:** #89 default (opt-in versus auto-skip without TermLink) and the `documents:` frontmatter option in #91.

## Confidence notes

- Every line number was read from this checkout. The submitter's v1.8.6 numbers match HEAD closely, with the files byte-identical between v1.8.8 and HEAD for all `web/` and watchtower files cited.
- Nothing was reproduced live. #86 and #93 effects rest on the submitter's 1.8.3 observation plus the code read here.
- #85's classification as outreach is a judgement from the text.
