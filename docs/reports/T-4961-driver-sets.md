# T-4961 — per-arc value-driver sets (`driver_set:`)

**Status:** inception, recommendation GO (narrow form); the decision is still to be recorded by the operator in Watchtower.
**Requested by:** 010-termlink (msg c39df4cd, their T-3638; their operator's ruling 2026-11-01).

## The ask

010-termlink adopts two value-driver sets:
- a DEVELOPMENT set, the live `policy/value-drivers.yaml`;
- a PRODUCT set, `policy/value-drivers-product.yaml`, with weights D1 6, D2 9, D3 7, D4 3 and free drivers F-TRUST 7, F-SURFACE 5 and F-CONV-RECALL 5.

They ask that an arc (and a task without one) can name a set, for example `driver_set: product`, resolving to `policy/value-drivers-<set>.yaml`. That set would be used by both `bvp.sh` ranking and the estimator. The protected D1-D4 keep their meaning; only the weights differ per set. Until then they score product decisions by hand, labelled "product set".

## The four blocking points they named

1. The estimator lets the live file win on collisions (`agents/termlink/bvp-estimator/estimator.py:2727-2736`).
2. D1-D4 cannot be scoped (`lib/arc-driver-review.sh` check_b).
3. Scoped weights are capped at 6, and at 3 drivers per arc (`lib/arc.sh:1567,1624`).
4. `bvp rank`, `arcs` and `detail` read only the live file (`lib/bvp.sh:285-364`).

## Dialogue log

- **2026-11-01, agent → operator:** three options were put to the operator.
  1. GO narrow: only the loading path, no new gates; design read and short review first.
  2. A design read before deciding.
  3. NO-GO: one set per project stays; the peer keeps hand-scoring.
- **Operator:** chose **"GO, narrow (Recommended)"**.
- **2026-11-01, 010-termlink (msg c7c90927):** the arc-level form covers them; their product work sits in product arcs, so **task-level naming is not needed**. They will read the design and re-vendor at the named be-tag.

## Scope of the narrow form (to be refined by the design read)

- `driver_set: <name>` on an arc YAML. A task inherits its arc's set; a task with no arc uses the live file. A task does not name a set directly (not needed by the requester, c7c90927; it stays out of the narrow form).
- The name resolves to `policy/value-drivers-<name>.yaml`. A missing file is a refusal, not a silent fall back to the live set.
- Ranking (`bvp.sh`) and the estimator read the arc's set. Weights and caps come from that set.
- D1-D4 are the same four directives in every set; only their weights change.
- No new gates, no new approval path.

## Next

1. Design read of the four points: what changes in each, and what each change touches (fabric blast radius).
2. A short independent review of the design (two internal seats, like T-4953).
3. Build slices as separate tasks; tell 010-termlink the form and the be-tag.

## Design (T-4967)

Design read, 2026-11-01. Read-only. Line numbers were checked against `bleeding-edge` today; two of the four cited ranges have moved.

### 1. Resolution rule

**Inputs.** The arc YAML may carry one new top-level key, `driver_set: <name>`. Nothing else in the arc changes.

**Rule, in order:**

1. Find the task's arc.
   - `arc_id:` first, resolved the way the estimator already does it (`_resolve_arc_data`, `estimator.py:138-175`): slug file `.context/arcs/<arc_id>.yaml`, then a scan matching `id:` or `slug:` (the `arc-NNN` form, T-1849).
   - If `arc_id:` is empty, the legacy `arc:<slug>` tag is honoured. The canonical membership helper is `lib/arc_membership.py` (`task_dict_in_arc`, line 254; `_TAG_ARC_RE`, line 65). `fw bvp arcs` already unions tags (`lib/bvp.sh:728`, T-3503), so the set must too, or `fw bvp arcs` would roll a tag-only member up under one set while the estimator scores it under another. Today 90 tasks bind to an arc by tag only.
   - Two or more different `arc:` tags whose arcs name **different** sets is a refusal ("ambiguous driver set"). If they all name the same set, or none, there is no ambiguity.
2. No arc, or the arc has no `driver_set:` → the live `policy/value-drivers.yaml`. Name returned: `None` (the default set).
3. `driver_set: <name>` → `policy/value-drivers-<name>.yaml`.
   - The name must match `^[a-z][a-z0-9-]{0,31}$`. No dots, no slashes, no `..`, so the path cannot leave `policy/`. A bad name is a refusal.
   - The resolved path must also sit directly in `policy/` (`path.parent == PROJECT_ROOT / "policy"`), checked after resolution as a belt-and-braces test.
   - `driver_set: default` is reserved and means the live file, so an arc can state the default explicitly.
4. A named set whose file is missing, unreadable or invalid (§4) is a **refusal**: an error naming the arc, the set and the expected path. It never falls back to the live file.
5. An arc YAML that fails to parse: today the estimator treats that as "no arc" (`estimator.py:155-158`). For the set, a parse error is also a refusal, because "no arc" would silently mean "live set". Scoped drivers keep their current behaviour.

**Where it lives.** One new module, `lib/driver_sets.py`, with:

- `resolve_set_name(task_fm, project_root) -> str | None` (raises `DriverSetError`)
- `set_path(name, project_root) -> Path` (raises on a bad name)
- `load_set(name, project_root) -> dict` (parsed and validated; cached per process by path + mtime)
- `load_for_task(task_fm, project_root) -> (name, policy_dict)`
- `load_for_arc(arc_data, project_root) -> (name, policy_dict)`

It imports `lib/arc_membership.py` for the tag rule. The estimator's `_resolve_arc_data` moves into this module (or the module calls it); one arc lookup, not two.

**Callers.** The estimator (§2, point 1), `lib/bvp.sh`'s Python engine (point 4), `lib/arc-driver-review.sh` (point 2), `lib/resolver.py`, `web/blueprints/bvp.py` and `lib/arc_close_readiness.py` (§3). All of them load it the way `bvp_py.py` is loaded today, from `lib/`.

**Refusal surface.** Commands that score or rank one task (`fw bvp estimate T-X`, `fw bvp detail T-X`) exit 2 with the message. Commands that sweep the corpus (`rank`, `arcs`, estimator sweep, resolver picker, `/bvp`) do **not** abort the whole run: they skip the affected tasks and print one `WARNING: driver set refused for N task(s): <arc> → <reason>` line, so one bad arc cannot blank the ranking. A skipped task is never scored against the live file instead.

### 2. The four blocking points

**Point 1 — estimator: live file wins collisions.**
- *Now:* `estimate_task` (`estimator.py:2709`) merges arc `scoped_drivers` under the passed-in drivers, passed-in winning (`:2729-2736`). The passed-in drivers come from `_load_drivers()` (`:124`), which reads only `POLICY_PATH` (`:79`). Two more readers use the same path: `_load_driver_aliases()` (`:216`) and `_load_driver_specs()` (`:2567`). Six callers call `_load_drivers()` once per run, not per task (`:3251, 3272, 3479, 3546, 3584, 3600`).
- *Change:* the base driver map, the aliases and the specs all come from the task's set, inside `estimate_task`: `name, policy = driver_sets.load_for_task(fm, PROJECT_ROOT)`. The three loaders take a `policy` argument instead of reading the path. The `drivers` parameter stays for the callers but means "default set"; when the task's set is not the default, the set's drivers replace it. Collision precedence does **not** change: the set (in the place of the live file) still wins over arc-scoped drivers. That is the requester's problem solved without a new precedence rule — the product weights now come from the product file, so they win.
- The proposal written to the task (`write_proposed`) records the set name (`driver_set: product` in the `bvp_scores_proposed` entry), so a later reader knows which weights it was scored for. Absent means default.
- `has_scorer()` (`:2650`) and `bvp-scorability` must see set-only free drivers (F-TRUST etc.); handled in §3.
- *Blast radius:* fabric `depended by: resume, update-task` (the close-time estimate). `fw fabric impact` printed no chain. Grep callers: `lib/bvp.sh` (`_load_estimator`, `:1316`), `lib/arc-driver-review.sh` (imports it for check_a), `lib/bvp-scorability.sh`, `agents/termlink/bvp-estimator/bvp-estimator.sh`. Tests: `test_bvp_estimator.py`, `test_bvp_estimator_v_alias.py`, `t4534_estimator_lost_write.bats`.

**Point 2 — `lib/arc-driver-review.sh` check_b: D1-D4 cannot be scoped.**
- *Now:* `check_b` (`:160-187`) refuses a proposed scoped driver whose id or name matches a protected driver or a free driver of the live file (`:113`).
- *Does the narrow form need check_b changed?* Its rule, no: a set re-weights D1-D4 in its own file; nothing scopes D1-D4 on an arc, so the "D1-D4 cannot be scoped" refusal stays as it is. Its **input**, yes: it must compare against the arc's set, not the live file. Otherwise a product arc could approve a scoped `F-TRUST` that check_b calls distinct, and the estimator would then silently drop it because the set's `F-TRUST` wins the collision. One-line change: `policy = driver_sets.load_for_arc(arc, root)[1]`; on refusal, check_b fails with the reason. No new gate.
- check_a needs no change for scoped drivers. check_c's directive tokens (`:66`) are the same in every set (§4).
- *Blast radius:* fabric card has no edges ("may need card enrichment"). Grep callers: `lib/arc.sh` approve-driver / review-driver paths, `lib/arc_driver_judge.py:267-272` (shells out to it), audit rail `check_arc_driver_reviewer_record`. Tests: `t3429_arc_driver_review.bats`, `t3429_arc_driver_reviewer_record_rail.bats`, `test_arc_driver_judge.py`.

**Point 3 — `lib/arc.sh`: scoped weight ≤6, ≤3 scoped drivers per arc.**
- *Now:* `arc_approve_driver` refuses weight outside 0-6 (`:1568`) and a fourth entry (`:1624`); the same caps at `:1930` (set-scoped-weight) and `:2423` (`--all-reviewed`).
- *Does the narrow form need it changed?* **No.** The caps apply to `scoped_drivers:` in the arc YAML only. A set's weights live in a policy file and are bounded by the policy schema (0-10, as in the live file), not by M2. The product set's D2 9 and F-TRUST 7 are set weights, not scoped weights, so they never pass through these lines. The requester hit the cap only because, without sets, scoping was the only way to change a weight.
- *Blast radius:* none (no change). Recorded so a reviewer can check the claim.

**Point 4 — `lib/bvp.sh`: `rank`, `arcs`, `detail` read only the live file.**
- *Now:* `load_policy()` (`:214`) reads the live file; `driver_weights()` (`:224`). Callers: `cmd_rank` (`:405-406`), `cmd_detail` (`:566-567`), `cmd_arcs` (`:784-785`, `global_weights` used for every arc's roll-up), `_find_driver_entry` (`:1415`), auto-promote (`:2058, 2070`). The cited range 285-364 now holds `compute_bvp` and `compute_cost`, which need no change.
- *Change:*
  - `cmd_rank`: per task, `weights = weights_for(fm)` (memoised per set name). `compute_bvp` is unchanged; `bvp_norm` stays a per-task ratio. Add a `SET` column (blank for default) so mixed rows are visible.
  - `cmd_detail`: weights and driver names from the task's set; print `Driver set: product (policy/value-drivers-product.yaml)` under `File:`.
  - `cmd_arcs`: each arc's roll-up uses that arc's set. Add the set to the row.
  - `_find_driver_entry`: search the task's set, then the arc. Its source string names the set file.
  - `load_policy()` stays the live-file loader for project-level keys (`auto_promote`, `inception_scoring_exception`, `version`). Auto-promote **keeps** the live file for thresholds; its `max_possible` (`:2074`) is computed from live weights and must become per-task (from the task's set) or it compares norms on different scales.
  - `cmd_confirm` does not validate driver ids against the policy today; no change.
- *Blast radius:* fabric `depended by: audit, resume, update-task, bvp-estimator, estimator, audit-yaml-validator, fw`. Grep: `bin/fw` (`fw bvp …`), `lib/bvp_py.py` (loader used by `arc_close_readiness.py`), `web/blueprints/bvp.py` duplicates the math (§3). Tests: `test_bvp_cli_rank_proposed.py`, `test_bvp_cli_arcs_rollup.py`, `test_bvp_arc_membership_union.py`, `bvp_auto_promote*.bats`, `t2497_resolver_bvp_rank.bats` (parity with resolver).

### 3. Other consumers of `policy/value-drivers.yaml`

| Reader | Set-aware in the narrow form? | Why |
|---|---|---|
| `lib/resolver.py:1361,1378` (`_bvp_driver_weights`, picker rank) | **Yes** | It ranks tasks for dispatch; it must agree with `fw bvp rank` (parity test t2497). Per-task weights via `driver_sets`. |
| `web/blueprints/bvp.py:44,111-131` (`/bvp` scatter, rubrics) | **Yes** | It duplicates `bvp.sh` math (module docstring). Task and arc points use their set's weights; rubric tooltips for a set-only driver come from that set. A set badge per point. Restart + `fw watchtower current` (web rule). |
| `lib/arc_close_readiness.py:156-163` (`/approvals` medians) | **Yes** | Uses `bvp.driver_weights(load_policy())` for every open task's norm; must use each task's set or medians mix scales silently. |
| `lib/bvp-scorability.sh:45,92` (audit + doctor rail) | **Yes** | It lists unscorable free drivers. Set-only free drivers (F-TRUST) must be scanned too: iterate the live file plus every `policy/value-drivers-*.yaml`. |
| `agents/audit/audit.sh:2049-2068` (`retire_when` advisory) | **Yes, small** | Same iteration over all set files, so a set's `retire_when` is not invisible. |
| New audit check (in slice 1) | **Yes** | Every `driver_set:` named in an arc resolves to a valid file; FAIL otherwise. This is a validator, not a gate: it blocks nothing new. |
| `lib/bvp_judge.py:74,201` (D1-D4 notes for the judge) | No | Reads the directive *notes*, which are the same in every set (§4). Weights are not used. |
| `lib/arc_driver_judge.py:145,316` | No | Same: D1-D4 notes only. |
| `lib/bvp.sh` `_load_policy_preserving`, `cmd_weight`, `cmd_driver` (`:864-980`), `_auto_promote_set_enabled` (`:1940`) | No | They edit the live file. Editing a set file is a hand edit in the narrow form; a `--set` flag is a later slice if wanted. |
| `lib/bvp.sh` `cmd_driver --init` (`:981-1003`), `lib/init.sh:567`, `lib/upgrade.sh:381-439` | No | They bootstrap/sync the live file and the vendored copy. Set files are consumer-owned; upgrade must not touch them (it copies a fixed list, so it does not). |
| `agents/git/lib/hooks.sh:1418` | No | Path allowlist for the live file. Set files are under `policy/` and ordinary tracked files. Check during the build that no hook refuses an unknown `policy/value-drivers-*.yaml`. |
| `lib/bvp_outcomes.py`, `lib/verification-port.sh`, `tools/prompt-sequence/*`, `web/templates/bvp.html`, `bin/fw:2849` | No | Comments, docs or a path in a prompt; `bin/fw:2849` only guards the scorability call. |

### 4. Set-file contract

- **Same schema as the live file.** `version`, `protected_drivers`, `free_drivers`. `auto_promote` and `inception_scoring_exception` are project-level and are **ignored** in a set file (a set that carries them gets an audit WARN, so nobody thinks they apply).
- **D1-D4 must be present in every set**, with the same `id` and `name` as the live file. Only `weight` (and optionally rubric wording) may differ. A set missing one, or naming one differently, is invalid. This keeps "D1-D4 keep their meaning" a checked fact, not a promise.
- Free drivers in a set follow the live rules: an id, a weight in the live file's range, and a mechanism (handler or `scoring:`/`scoring_file:` spec, T-3428). A set may define free drivers the live file does not have (F-TRUST, F-SURFACE, F-CONV-RECALL).
- **Validation:** one function, `driver_sets.validate_set(policy, live_policy) -> list[str]`, called by `load_set` (so every consumer refuses an invalid set the same way) and by the new audit check. Scorability of set free drivers is checked by the existing `bvp-scorability.sh` rail once it iterates set files (§3). No new gate at Write/Edit time.

### 5. Build slices

1. **Resolver and contract.** `lib/driver_sets.py` (resolve, name check, load, validate, tag rule, ambiguity refusal), its fabric card, and the audit check "every named `driver_set:` resolves to a valid file". Tests: `tests/unit/test_driver_sets.py` — default, named, missing file, bad name (`../x`, `a/b`, `A`), tag-only member, two tags with different sets, set missing D2, renamed D1. `bin/fw vendor self --check`.
2. **Estimator and arc review.** Points 1 and 2: per-task set in `estimate_task`, the three loaders take a policy, `driver_set` recorded in the proposal, `check_b` reads the arc's set. Tests: extend `test_bvp_estimator.py` (product arc task gets product weights and F-TRUST; live wins nothing it should not), `t3429_arc_driver_review.bats` (scoped F-TRUST on a product arc refused as a duplicate). Fabric: enrich the `arc-driver-review` card.
3. **Ranking surfaces.** Point 4 plus resolver, `arc_close_readiness`, auto-promote `max_possible`: per-task weights, `SET` column, `detail` banner, `arcs` per-arc set, sweep WARNING line. Tests: `test_bvp_cli_rank_proposed.py`, `test_bvp_cli_arcs_rollup.py`, `t2497_resolver_bvp_rank.bats` parity with a mixed corpus.
4. **Watchtower and rails.** `web/blueprints/bvp.py` set-aware with a set badge; `bvp-scorability.sh` and the `retire_when` advisory iterate set files. Tests: `test_bvp_blueprint_cost.py` plus one Playwright check on `/bvp`; `bin/fw watchtower restart` and `bin/fw watchtower current`. Render surface, so it needs a `[REVIEW]` Human criterion (P-013).

Slices 1 → 2 → 3 are serial (2 and 3 both import slice 1). Slice 4 can follow 3. Tell 010-termlink the be-tag after slice 3: ranking and estimation are what they asked for; slice 4 is display and rails.

### 6. Risks and open questions

1. **Mixed scales in one ranking.** `bvp_norm` is a ratio against each task's own weights, so a development task and a product task land on the same 0-1 axis but answer different questions. Proposal: rank them together and show the `SET` column. Alternative: `fw bvp rank --set <name>` to filter. Operator call: is one mixed list acceptable?
2. **Legacy `arc:` tags.** The design honours them (90 tasks are tag-only) because `fw bvp arcs` already does. The estimator's scoped-driver path does not today. Do you want sets to follow the tag rule, or `arc_id:` only (simpler, and a reason to finish the T-1850 migration)?
3. **Already-confirmed scores.** `bvp_scores:` on a task in an arc that later gains `driver_set:` were confirmed under the live weights. The scores (0-5 per driver) stay valid; only the weights change, so ranking moves. Set-only drivers (F-TRUST) will be unscored on those tasks until re-estimated. Proposal: no migration; the next estimator sweep proposes the missing drivers.
4. **Who may write `driver_set:` on an arc.** The narrow form adds no gate. But choosing a set changes every member task's weights at once, which is close to a weight change (`fw bvp weight` is §ACD-gated). Is an arc-YAML edit by an agent acceptable, or should it be operator-only?
5. **Fabric impact output was empty** for all six files (`fw fabric impact` printed only its header). Blast radius above relies on `fw fabric deps` and grep. Worth a separate look; not blocking.

## Review (T-4967, 2026-11-01)

Seat 1, opencode: **sound with fixes** (full text: `docs/reports/T-4967-review-opencode.md`). It confirmed the point-3 claim, the point-4 citations, the auto-promote `max_possible` catch and the hooks allowlist. Seat 2, codex: **sound with fixes** (full text: `docs/reports/T-4967-review-codex.md`). It confirmed the point-2 collision rule and the point-3 caps, and found no unlisted reader of the file.

Codex findings, and what the design now says:

- **C1. Old scores can change meaning.** A set may reuse a free-driver id (F1) for a different driver, and `_latest_proposed_scores` drops the proposal's metadata (`lib/bvp.sh:651-662`). **Accepted:**
  - each score carries the set it was scored under;
  - a score counts under another set only if that set's entry for the id has the same `name` and `scoring` spec (pure re-weighting);
  - otherwise the score shows as unscored (unknown, never 0) until re-estimated.
- **C2. The promised backfill does not happen.** The sweep skips confirmed tasks (`estimator.py:3496-3497`), and delta suppression looks only at confirmed keys (`:2796-2809`). **Accepted:** a missing driver or a score from another set triggers re-estimation of those drivers only, bypasses delta suppression for them, and never overwrites a confirmation. A test switches a confirmed task to a set with an extra driver.
- **C3. Auto-promote and readiness need more than the change I named.** Auto-promote scores with the global `weights` (`lib/bvp.sh:2070,2102`), so the `max_possible` change alone does nothing. Readiness reuses one weight map for member values (`lib/arc_close_readiness.py:181,237-246`). **Accepted:** weights are resolved at every scoring call; readiness's shared-weight interface is replaced. Tests compare mixed-set promotion and readiness with the CLI.
- **C4. A warning is not visible enough.** `/bvp` never shows a terminal warning, and `collect_arcs` already swallows YAML errors (`lib/bvp.sh:264-270`). **Accepted, widening opencode's finding 3:** refused tasks and arcs travel in the returned data and appear as rows (with the reason) in the CLI, `/bvp`, readiness and picker output. Collection errors are passed on, not swallowed.
- **C5. Identity and parsing rules.** Duplicate arc ids or slugs, a filename/slug conflict, or a repeated `driver_set:` key (which `yaml.safe_load` accepts) choose a set silently. **Accepted:** conflicting identities and duplicate keys are refusals. Malformed files met during an id scan are refusals for any task that could resolve to them. Tests cover each case.
- **C6. The set contract.** Weight loaders overwrite repeated ids (`estimator.py:129-134`, `web/blueprints/bvp.py:122-127`) and cast weights with `int`. **Accepted:** ids are unique across both sections; protected and free ids may not collide; weights are finite integers from 0 to 10 (this replaces "numbers"). Tests cover booleans, fractions, non-finite values and duplicates.
- **C7. Release boundary.** `/bvp` is a ranking surface of its own. **Accepted:** all scoring surfaces (CLI, estimator, resolver, readiness, auto-promote, `/bvp`) ship under one be-tag. Slice 4 keeps only the rails (scorability, `retire_when`), and the `/bvp` work moves into slice 3.

**Revised slices:**
1. Resolver and contract: `lib/driver_sets.py`, the validation from C5/C6/opencode 7, and the split-root lint exemption.
2. Estimator and arc review: points 1 and 2, check_a, score provenance (C1) and the backfill (C2).
3. Every scoring and ranking surface, together: rank, detail, arcs, resolver, readiness, auto-promote and `/bvp`, with visible refusals (C3, C4, C7).
4. The rails.

2 and 3 ship under one be-tag; tell 010-termlink then.

**Filed (2026-11-01):** slice 1 T-4984, slice 2 T-4985, slice 3 T-4986, slice 4 T-4987.

Findings, and what the design now says:

1. **An unresolvable arc reference falls back to the live set.** Accepted. If `arc_id:` names no arc, or every `arc:` tag names a missing arc, that is a refusal, the same as a parse error. Rule 5 is widened to "any arc reference that does not resolve".
2. **check_a and the scorability rail still use the live-file alias table.** Accepted. Once the loaders take a `policy` argument (point 1), check_a and `bvp-scorability.sh classify` pass the arc's set. Moved into slice 2.
3. **A refused task can drop out of the resolver picker with only a WARNING on the terminal.** Accepted. `fw bvp rank` prints a `refused` row per skipped task and exits 3 when any were skipped. The picker writes the refusal to its decision log, and `fw doctor` shows the count.
4. **The T-2648 split-root lint would flag the new set paths.** Accepted. Slice 1 extends the lint's exemption to `value-drivers*.yaml`, with a reason: set files are per project, so FRAMEWORK_ROOT would be wrong for them.
5. **`arc_id:` and the tags can disagree, and multi-arc roll-ups can mix sets.** Accepted. It is a refusal when `arc_id:` and the tags resolve to different sets. For `fw bvp arcs`, each arc rolls up its members under that arc's set; a member whose own set differs is listed under a `mixed set` count, not silently re-weighted.
6. **Between slices 2 and 3, set-only drivers are scored but not ranked.** Accepted. Slices 2 and 3 land together, under one be-tag.
7. **`validate_set` checks too little.** Accepted. It compares the whole D1-D4 entries: only `weight` and `rubric` may differ (so the judges' `note:` reads stay valid). Weights must be numbers from 0 to 10.
8. **Minor points:**
   - an empty `driver_set:` is a refusal;
   - a file `policy/value-drivers-default.yaml` gets a WARN (reserved name);
   - the estimator's `AGENT.md` is updated in slice 2.
