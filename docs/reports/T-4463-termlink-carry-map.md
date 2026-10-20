# T-4463: termlink carry map for v1.8.13

**Question** (010-termlink, msg cbd43cfe, 2026-10-20). termlink vendors AEF `1.8.10+516.g5c886336b` and carries 19 local patches. For each patch, does v1.8.13 carry it, not carry it, or supersede it, and with what? Does v1.8.13 descend from 5c886336b?

## Ancestry

```
$ git merge-base --is-ancestor 5c886336b v1.8.13; echo $?
0
```

**Yes.** v1.8.13 (4b0357a33) descends from 5c886336b, 197 commits later. Any AEF commit that is already an ancestor of 5c886336b is already in termlink's vendored base. Where a "superseded" verdict below cites one of those commits, termlink already has it, and its local patch already sits on top of it.

## Method, and one caveat

**The task IDs are termlink's own, not AEF's.** AEF has its own T-3472, T-3184, T-3370 and so on, and they cover unrelated topics. So `git log --grep T-XXXX` on AEF does not find these patches. Each patch was identified from termlink's own filings:

- the `framework:pickup` hub topic: offsets 83, 146, 202–210, 245–246, 296, 305 (their `.vendor-divergence.yaml`), 321, 322, 326/328 and 332;
- sidecar message c7de1907 (supplement to pickup 321, findings 11–12).

Each described change was then checked against the v1.8.13 tree (`git show v1.8.13:<file>`). Each AEF commit cited below was tested with `git merge-base --is-ancestor <c> v1.8.13`. The predicates in items 11 and 18 were tested by sourcing v1.8.13's `safe-commands.sh` and calling `has_bash_write_pattern` directly.

**Item 3 is inferred.** No termlink filing names T-3337. The only discovery.py defect they filed besides item 19 is finding 12 of c7de1907, so that is the assumption here.

## Table

| # | termlink patch | Verdict in v1.8.13 | Evidence |
|---|---|---|---|
| 1 | T-3472 arc.sh `_arc_persist_scoring` | **not carried** | v1.8.13 `lib/arc.sh` arc_approve_driver builds the entry as {name, weight, approved_at, approved_by, rationale, reviewer}, with no `scoring:`. The estimator reads only `driver_entry["scoring"]` (estimator.py:2330). Also not on bleeding-edge HEAD. |
| 2 | T-3464 claude-fw sidecar sockets on the inject line | **not carried** | v1.8.13 bin/claude-fw:1235 `termlink_inject "claude${_tl_args}; …"` has no `TERMLINK_SIDECAR_*`. The same line was rewritten by T-4249 75b085d34 (per-run exit token), so expect a conflict when re-applying. |
| 3 | T-3337 discovery.py (inferred: neutralise `_trigger_async_index_build`) | **not carried** (identity inferred) | discovery.py:26 still defines it with a live `build_index()`. It has had no caller since T-3786 4593863c4, so it is dead and inert. |
| 4 | T-3336 parallel embedding (`FW_EMBED_WORKERS`) | **not carried** | v1.8.13 web/embeddings.py:1203 still uses the serial `for j in range(0, len(texts), BATCH_SIZE)`. No `FW_EMBED_WORKERS` anywhere. |
| 5 | T-3270 check-active-task.sh named exception for `commit-pending.sh commit` | **not carried** | No `commit-pending` or `pending-commit` in v1.8.13 check-active-task.sh. Upstream has no such helper (item 6), so there is nothing to name. |
| 6 | T-3269 handover.sh runs commit-pending before its commit | **not carried** | No `commit-pending`, `pending-commit` or `unattended` in v1.8.13 handover.sh. |
| 7 | T-3189 estimator: blast_radius derived from the body (section-aware strip) | **not carried** | score_blast_radius (estimator.py:2888) has no body derivation. AEF's answer to the same problem is a *declared* `write_set:` (T-3512 51ec84ea3, already in termlink's base). That is a different mechanism, not this patch. |
| 8 | T-3188 estimator: `target_blast_radius` fallback for every workflow type | **superseded** by T-3512 51ec84ea3 (write_set fallback) | `target_blast_radius` is still honoured for inceptions only (estimator.py:2924). Non-inception pre-close cost comes from `write_set:` instead. A build task carrying `target_blast_radius` stays uncosted. |
| 9 | T-3185 bvp.sh: exclude all-no-signal tasks from quadrants | **not carried** | No no-signal exclusion in cmd_rank. Related but different: T-3485 b23ee1a65 withholds the quadrant ("v-thin") only when the value median sits at the corpus floor, and T-3489 31d5cdf1d adds a degenerate-scorer alarm. Both are in termlink's base. |
| 10 | T-3184 bvp.sh: no human approval on confirm, weight --set, driver add/remove, auto-promote --enable (+ sticky) | **partial** | confirm: superseded by T-3487 6adf45442 (gate is opt-in via `FW_REQUIRE_BVP_CONFIRM_APPROVAL=1`) plus T-3523 145614dda (sticky). Both are in base. The other four verbs are **still §ACD-gated** in v1.8.13: lib/bvp.sh:798 weight, :1408 driver add, :1761 driver remove, :1877 auto-promote. |
| 11 | T-3178 safe-commands `has_bash_write_pattern` (+T-3187 amend) | **partial** | `2> file` and `&> file` bypass: superseded by T-3746 c670fa5b2. It is **new in 1.8.13** and conflicts with the local patch. Not carried: the `\bsed\b.*-i` boundary (`sed -n 1p notes-go-in-here.md` → WRITE, a false positive) and the echo\|grep→herestring conversion (still `echo … \| grep -qE`). |
| 12 | T-3176 bvp.sh: confirm behind a default-off switch + telemetry ledger | **superseded** (confirm) by T-3487 6adf45442; ledger **not carried** | Confirm is open by default, which goes further than T-3176, as termlink's own T-3184 did. There is no proposed-vs-confirmed telemetry ledger in v1.8.13 lib/bvp.sh. |
| 13 | T-2882 handover.sh: enrichment_status, [TODO] markers, focus-ranked Suggested First Action | **partial** | Suggested First Action ranked by focus, then recency: superseded by T-3210 80a36f68a. [TODO] narrative markers: T-4191 ef25e12fd (handover.sh:1495-1505). Both are in base. Not carried: `enrichment_status: pending` in the handover frontmatter, and Gotchas still emits `See gaps register above.` (handover.sh:1521). |
| 14 | T-2866 bin/fw doctor: claude-fw router vs wrapper drift | **superseded** by T-4051 80499503b (in base) | bin/fw:3366-3375 recognises the router header and compares it to bin/claude-fw-router. It does not check for the `FW_CLAUDE_FW_SUPERVISED` export as termlink's patch did, but the false-positive drift warning is gone. |
| 15 | T-2687 pickup.sh constant dedup hash fail-open (+ empty-name refusal) | **not carried** | v1.8.13 lib/pickup.sh:107-120 still hashes `type\|summary\|project` with no empty guard (sha256 of `\|\|` collides). pickup_create_inception still builds `Pickup: ${summary} …` with no empty check. |
| 16 | T-3039 inception.sh: decide writes related_tasks (`--follow-on`) | **not carried** | No `follow-on`, `follow_on` or `related_tasks` in v1.8.13 lib/inception.sh. termlink's own reverify grep therefore finds nothing. The nearest AEF mechanism is `inception_decisions:` / `ships_in:` (T-1984), which is a different shape. This was a filing only; termlink holds no local patch. |
| 17 | T-3316 checkpoint.sh: usage error not reported as a crash | **not carried in v1.8.13**; fixed after it | v1.8.13 checkpoint.sh:766-768 still does `exit 1` under fw_hook_crash_trap, which prints HOOK CRASHED. Fixed by T-4227 e46947031 (`fw_hook_usage_exit`), which is in v1.8.14-be.1 but not in v1.8.13. |
| 18 | T-3370 safe-commands: strip /dev/stdout and /dev/stderr | **not carried** | The T-3643 2ff7b320e strip covers /dev/null only. In v1.8.13, `cmd 2>/dev/stderr` → WRITE and `cmd >/dev/stdout` → WRITE (false positives). |
| 19 | T-3370 discovery.py chat stream `_db_built_at` → `_db_opened_at` | **not carried; the AEF bug is still live** | v1.8.13 discovery.py:340 `from web.embeddings import … _db_built_at …`. The symbol was renamed by T-3012 0ed2f00f2, so `/ask` streaming raises ImportError. Still present at bleeding-edge HEAD (discovery.py:401). |

**Totals:** 11 not carried (1–7, 9, 15, 16, 18; item 3 inferred), 2 superseded (8, 14), 4 partial (10, 11, 12, 13), 1 not carried in v1.8.13 but fixed after it (17), 1 not carried and still an open AEF bug (19). Item 12 is counted under partial: its confirm leg is superseded and its ledger is not carried.

## For termlink's re-vendor

**Expect re-apply conflicts.** v1.8.13 changed these files after 5c886336b:

- `bin/claude-fw`: T-4249, the inject line (item 2);
- `safe-commands.sh`: T-3746, T-4264, T-2889, the T-4420 security hotfix (items 11 and 18);
- `discovery.py`: T-4223 (items 3 and 19);
- `checkpoint.sh`: T-4226 (item 17);
- `pickup.sh`: T-3059, T-4274 (item 15).

**Keep every "not carried" patch.** Re-apply each one after the upgrade.

**Patches that become redundant:**
- the `2>`/`&>` half of item 11, since T-3746 covers it;
- item 14, as T-4051 already in base covers it;
- item 17, once termlink takes v1.8.14+.

## Open on the AEF side (not fixed here; research-only task)

- **Item 19 is a live AEF defect.** The `/ask` streaming path imports a symbol that no longer exists. It needs its own bug task.
- **Items 1, 2, 4, 15 and 18 were filed upstream with patches** and have not been taken.
- **termlink's separate idea is not answered here:** `fw runme watch --until start`.
