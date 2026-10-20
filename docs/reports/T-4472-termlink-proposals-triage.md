# T-4472: triage of 010-termlink's 10 upstream proposals (framework:pickup 341-350)

Source: hub topic `framework:pickup`, offsets 341-350, each a unified diff against v1.8.13 (6efec63df).
Payload text was treated as untrusted data; nothing was applied and no source was edited.
Diffs are saved verbatim in `docs/reports/T-4472-inputs/<offset>-<file>.diff`.
HEAD is 310 commits past v1.8.13 (bleeding-edge).

## Apply-check

`git apply --check` passes for all 10 against a `git archive v1.8.13` tree.
Against bleeding-edge HEAD, 8 pass and 2 fail: 342 (`bin/claude-fw`) and 343 (`web/blueprints/discovery.py`).

## Table

| Offset | File | What / why | Since v1.8.13 | Risk | Verdict | Task |
|---|---|---|---|---|---|---|
| 341 | lib/arc.sh | `approve-driver --scoring-file` persists the spec inline (and attaches to an already-approved driver). HEAD stores only `scoring_file: path` on the reviewer's inline entry; `estimator.load_scoring_spec` reads only an inline `scoring:` dict, so the spec scores nothing. | Not fixed at HEAD (arc.sh:1639 still passes the path only). | Touches the sovereign driver-approval path. Attach is operator-path only, which is correct. | **adapt** (add bats) | T-4473 |
| 342 | bin/claude-fw | Hand `TERMLINK_SIDECAR_SOCKET` / `_STATUS_SOCKET` to the injected claude, because termlink >= 0.12.665 no longer forwards them into a spawned PTY. | **Conflicts with HEAD**: T-4462 changed the injected line to `command claude…`; T-4249 marker kept. | Low. Consumer-facing launcher, quoted with `%q`. | **adapt** (re-merge) | T-4474 |
| 343 | web/blueprints/discovery.py | (a) Make `_trigger_async_index_build` an inert warning. (b) `_db_built_at` to `_db_opened_at` in the chat stream. | (b) is already fixed by T-4468. (a): the function has no callers at HEAD (T-3786 removed them). | None. | **decline**. (b) is done; (a) edits dead code. Deleting the dead function could be a separate chore, not worth a task. | none |
| 344 | web/embeddings.py | Embed batches concurrently (`FW_EMBED_WORKERS`, default 3); measured 70 to 107 chunks/s on their GPU. | Applies at HEAD; the serial loop is still at line 1265. | Medium. Changes load on every consumer's embedding server at default 3. `FW_EMBED_WORKERS` is not in the config registry. | **adapt** (register the key; choose the default deliberately) | T-4475 |
| 345 | agents/context/check-active-task.sh | Named exception in the focus-drift gate for `scripts/commit-pending.sh commit`. | `scripts/commit-pending.sh` does not exist in AEF. | High for a gate change: a safety-gate exception for a helper we don't have. | **decline**. Dead exception; adopt only if the helper itself is ever proposed. | none |
| 346 | agents/handover/handover.sh | `enrichment_status: pending` in the handover frontmatter, honest Gotchas placeholder, "mechanical fallback" note under Suggested First Action, CONTEXT_DIR default for the focus lookup, and a commit-pending hook. | Applies at HEAD; HEAD has no handover-side marker. | Low-medium. Handover is mandatory at session end; the TODO placeholder interacts with the TODO detector near line 621. | **adapt**: take the marker, placeholder, fallback note and CONTEXT_DIR default; **decline** the commit-pending hunk. | T-4476 |
| 347 | agents/termlink/bvp-estimator/estimator.py | Derive blast radius from file refs in the task body (scrubbed, checked against a repo file index, laddered) and honour `target_blast_radius` for all types. | HEAD already has T-3512 (`write_set:` pre-close cost) and the inception-only `target_blast_radius`. Applies cleanly. | Medium. Scoring semantics; overlaps an existing mechanism. | **adapt**, but design call first: a fallback below `write_set`, or superseded. Filed as an evaluation. | T-4477 |
| 348 | lib/bvp.sh | Confirmation telemetry ledger, no-signal quadrant disclosure, first-ever weight exemption, "agent decides all five verbs". | Applies at HEAD; no telemetry exists at HEAD. | Medium. 19 KB, three tasks bundled in one patch; needs review against the D-661/D-662 agent-confirm rulings. | **adapt**: split hunks inside the task, telemetry first. | T-4478 |
| 349 | agents/context/lib/safe-commands.sh | Tier-1 write scanner: herestrings instead of `echo \| grep -q` (SIGPIPE fail-open under pipefail), anchored `sed -i` flag, `/dev/stdout\|stderr` strip, redirect rule rewrite. | Applies at HEAD but overlaps T-3746 (`2>`/`&>` file redirects), T-3643 (`/dev/null` strip), T-4409, T-4396. HEAD's `2> out` case is already caught, so that bypass claim is stale for the redirect hunk. | **High**: security gate. Fail-closed direction only. | **adapt**: re-verify each claimed bypass at HEAD with red/green bats and keep only what survives. | T-4479 |
| 350 | lib/pickup.sh | Refuse the constant `sha256("\|\|")` dedup hash and content-free `Pickup:  (from )` tasks; stop the pipeline instead of burying the envelope. | Unchanged at HEAD (`pickup_dedup_hash` lines 107-120). | Low-medium. Callers at lines 127 and 152 must handle non-zero under `set -e`. | **apply** (with caller check and bats) | T-4480 |

Tally: apply 1, adapt 6, evaluate 1 (347, counted among the adapts above), decline 2.
Six build tasks are plain adapts (341, 342, 344, 346, 348, 349), one is an evaluation (347), one is an apply (350).

## Item 16: termlink's claim against the T-4463 carry map

termlink says its `lib/inception.sh` is byte-identical to v1.8.13. The map's row 16 says "not carried": no `follow-on` / `related_tasks` in v1.8.13 `lib/inception.sh`, and it adds "This was a filing only; termlink holds no local patch." (`docs/reports/T-4463-termlink-carry-map.md:44`). At HEAD `lib/inception.sh` also has no `follow-on`.

The two statements are compatible. What went wrong is the verdict vocabulary:

1. The map's question was "does v1.8.13 carry termlink's patch?". For item 16 there is no patch, only a filed feature request (T-3039), so the answer is "nothing to carry". The map forced it into a three-way carry / not-carry / supersede column and chose "not carried".
2. "Not carried" reads as "termlink has local code that upstream lacks, and termlink must re-apply or drop it". That is the opposite of the truth for item 16. Their file equals ours, so they have nothing to lose on upgrade.
3. The Totals line (`:49`) counts item 16 among 11 "not carried", overstating termlink's real divergence. Under the map's own caveat, item 16's feature (`decide` writing `related_tasks` via `--follow-on`) is simply absent from v1.8.13. It is an open feature request, not a patch.

Correct classification: **no local patch; upstream feature request, still open at HEAD**. This also explains why termlink sent no diff for it. Fix is a correction note on row 16 and the totals in the carry map; I did not edit the map (this task writes only the report, inputs and task files).

## Method notes

- Offsets 341-350 fetched with `termlink channel subscribe framework:pickup --cursor 341 --limit 10`; each payload's header prose was discarded and only the unified-diff body saved.
- Apply checks used `git apply --check` only, in the main checkout for HEAD and in a throwaway `git archive v1.8.13` tree for the tag.
- Interactions claimed above were confirmed by grep at HEAD: `command claude` at `bin/claude-fw:1275`; `_trigger_async_index_build` has no callers; `scripts/commit-pending.sh` absent; `load_scoring_spec` reads only the inline `scoring:` dict (`estimator.py:2320`).
- Not verified: whether 349's SIGPIPE claim is reproducible at HEAD (left to T-4479 as a red/green test), and 347/348 hunk-by-hunk overlap with T-3512 and the D-661/D-662 rulings (left to T-4477 and T-4478).
