# T-3574 / T-3575 independent render review (2026-09-30)

Reviewer: `perf-review` (independent; not the builder). Read-only except this file.
Live server: `http://192.168.10.107:3002` (`bin/fw watchtower current` → current, pid newer than every file under `web/`).
Host load at measurement time: 3-7 (the builder measured at 20-28).

---

## T-3574: arc page, 12-108s down to about 1s

**VERDICT: AMBER.** The render and the BVP numbers are unchanged, and the speed-up is real. There are two faults. First, the equality test does not prove coherence equivalence, and I found one real coherence divergence the test misses. Second, T-3575 has since regressed the warm time on this page back above the 1s criterion.

### WHAT I CHECKED

1. **Diff** (`392379e12`): `bvp._task_index()` builds a stat-signature cached id→path map plus arc membership. `_arc_member_tasks` and `_bvp_coherence_for_arc` now parse only the member files, through the mtime-cached reader, which now uses CSafeLoader (available on this host).
2. **Does the test compare new code against the old algorithm?** Only partly.
   - `test_members_and_bvp_match_legacy`: **genuine.** The legacy members come from a whole-corpus `yaml.safe_load` walk, and `_bvp_signals` (new) is compared against `_compute_bvp` over the legacy members. All three arcs have no arc-level `bvp_scores` and no proposed scores, so the raw/norm branch does run.
   - `test_coherence_matches_legacy_with_findings`: **vacuous.** No task has confirmed `bvp_scores`, so both sides return `[]`. The builder's docstring says so itself.
   - `test_coherence_fires_on_synthetic_low_scores`: **new code checked against itself.** The expected `n_members` comes from `bvp._task_index()`, the same index the code under test uses, so it cannot catch a membership difference from the legacy code.
3. **My own cross-check** (`/tmp/t3574_xcheck.py`): I injected `bvp_scores: {D1: 0}` into both the legacy and the new parse paths, forced status in-progress with open thresholds, and compared all 20 arcs on disk. **19 match and 1 differs:** `dispatch-safety` gives new `n_total=11` against legacy `12`.
   - Root cause: `.tasks/completed/T-3440-*.md` has `arc_id: arc-001   # T-3440: dispatch-safety — …`. `lib/arc_membership._ARC_ID_LINE_RE` (`^arc_id:\s*(.+?)\s*$`) keeps the inline comment in the value, so that task is filed under a junk key and never reaches `arc-001`. The old coherence code used `yaml.safe_load`, which strips the comment. The new code routes through the regex index, so it loses the task.
   - Impact today: nil on screen, because coherence only fires on confirmed scores and none exist. It is a latent correctness regression. BVP membership (`_arc_member_tasks`) already used the regex scan before this change, so T-3440 was already missing from dispatch-safety's BVP before and after. That part is a pre-existing bug, not a T-3574 regression.
4. **Tests:** `pytest tests/web/test_t3574_arc_page_perf.py`: 8 passed (129s).
5. **Render:** In `arc-continuous-bvp-after.png`, BVP_norm is 0.233 and BVP_raw is 63, matching the Human AC's expected values. The 9-driver breakdown, the coherence line, the scoped drivers and the 53 constituents all render. The jump bar is intact. Live `/arcs/continuous-run` returns 200 with 152,851 bytes.
6. **Live timing (curl):**

   | route | measured now | builder's claim | criterion |
   |---|---|---|---|
   | `/arcs/continuous-run` | cold 2.54s, warm **1.65-1.83s** (8 runs) | 1.04s / 0.31s | <3s cold, **<1s warm** |
   | `/arcs/readme-first-run` | 0.21-0.38s | 0.28s / 0.14s | met |
   | `/arcs/dispatch-safety` | 0.49-0.77s | — | — |

   **The warm criterion for continuous-run is not met live.** A cProfile of a warm in-process request (2.23s total) shows 1.55s in `_resolve_constituents` → `_read_task_meta` ×53 → `get_all_task_metadata` → `_task_files_signature`. That signature was **added by T-3575** and stats every task file on every call, and the arc page calls it once per constituent (53 × ~29ms). The builder measured T-3574 before T-3575 landed, so the 0.31s was true when it was recorded and stopped being true one commit later.
7. **Task file hygiene:** Commit `027cbe5c3` spliced the three verification commands into the **template HTML comment** (`… in \`## Verification` → newline → commands → `instead of a Human AC here`), not into the real `## Verification` section. The real section has **zero executable lines**, so P-011 will pass vacuously. The same applies to T-3575: it has no executable verification lines either.

### GUIDANCE

- **Fix the arc_id regex, don't just note it:** strip a trailing ` # …` comment in `lib/arc_membership._ARC_ID_LINE_RE` (or post-process the value). This is its own bug with its own task: it also drops T-3440 from dispatch-safety's BVP membership and from anything else built on `scan_tasks_by_arc_membership`. Register it in `concerns.yaml` per "register first".
- **Make the coherence test real:** monkeypatch the score injection into *both* the legacy `yaml.safe_load` path and the new `_parse_frontmatter` path, and compare across every arc on disk. That is exactly what `/tmp/t3574_xcheck.py` does, and it goes red on dispatch-safety today. Derive the synthetic leg's expected count from the legacy walk, not from `_task_index()`.
- **Warm <1s:** that criterion is currently false on the live server. It should not stay ticked until the T-3575 signature cost is fixed (see below) and continuous-run is re-measured.
- **Move the verification commands** out of the HTML comment into `## Verification`, using the guarded pytest form (`> /tmp/.out 2>&1 && grep -q passed /tmp/.out`).
- Recommendation stays GO **after** those items. The core change is sound, and the byte-identical `_bvp_signals` claim holds for the BVP numbers.

---

## T-3575: tasks page, 1.04MB down to 305KB, cold 3.35s down to 0.18s

**VERDICT: RED.** The speed claims hold, but the column cap hides the operator's current work. The In Progress column now shows the 20 **oldest** started-work tasks by ID (T-332, T-334, T-464 …) and hides the 27 newest. **T-3574, T-3575, T-3557 and T-3576 are not on the board.** The change also regressed the arc page (see T-3574 §6).

### WHAT I CHECKED

1. **Diff** (`a04b21822`): the cache in `web/shared.py` is now validated by a `(name, mtime_ns, size)` signature over `.tasks/{active,completed}` (and over `.context/episodic` for tags), plus per-file `mtime_cached_get` and a 300s safety TTL. `tasks.html` caps every board column at `BOARD_COLUMN_CAP=20` (last column 10). `inline_select` and the tag dropdown are whitespace-trimmed.
2. **Nothing the operator relied on is gone?**
   - Filters and search: the owner, horizon and tag selects and search are present and working (`?owner=human` 0.16s, `?q=perf` 0.13s). Board and List toggle both present. The bulk bar and bulk checkboxes are present on both board and list.
   - Completed tasks are reachable via `+3332 more →` → `/tasks?view=list&status=work-completed`, which returns 200 but is **12.3MB in 1.37s**. That is unchanged from before (the last column was already capped at 10) and is noted by the builder as out of scope.
   - **In Progress (47): 27 hidden.** The column is sorted by `task_id_sort_key` ascending, and there is no descending sort (sort only accepts `id` and `name`). The visible 20 are the stalest tasks, so the board's primary purpose, seeing current work, is lost. The data is still *reachable* via `+27 more`, but you have to click away from the board to see it.
   - **`+N more` drops active filters.** On `/tasks?owner=human` the board shows In Progress (43), and the overflow link is `/tasks?view=list&status=started-work` with no `owner`. This was already true for the last column. It now applies to every column, including the filtered views operators actually use.
   - Drag-and-drop between columns works only for the cards that are shown. Hidden cards have to be moved through the list view's inline selects. That still works, but it is a behaviour change.
3. **Stale data:** the invalidation logic is correct for every realistic edit. An add, remove, rename, active→completed move, or content rewrite changes name, mtime or size, and the per-file cache is keyed on `mtime_ns`. The residual blind spot is an edit that preserves both mtime_ns and size (`touch -r` after an edit, or some restore tools). The 300s safety TTL bounds that. Two minor points:
   - `_TASK_FM_CACHE` never evicts deleted paths. This is a slow memory creep, not a correctness issue.
   - `dict(parsed)` is a shallow copy, so nested lists like `tags` are shared with the per-file cache, which now lives indefinitely rather than for 30s. Any consumer that mutates `fm["tags"]` in place would poison the cache. I did not find such a mutation, but nothing guards against one.
4. **Cost of the signature:** `_task_files_signature()` runs on *every* `get_all_task_metadata()` call (~29ms, a stat of ~3,600 files). Callers that invoke it in a loop pay N×: `arcs._read_task_meta` does so 53× on `/arcs/continuous-run`, which adds 1.5s and breaks T-3574's warm criterion.
5. **Live timing:**
   - curl `/tasks`: 0.17-0.30s, 304,676 bytes. Both claims hold.
   - Headless Chromium from about:blank, 7 navigations, load 3-7: TTFB 167-292ms; **DOMContentLoaded 553 (first), then 419, 442, 420, 523, 443, 423ms**. Warm median ~440ms, 5 of 6 warm runs under 500ms.
6. **Screenshot** `tasks-after.png`: the layout renders cleanly with 4 columns, correct counts and overflow links. The owner select on each card is clipped at the right edge ("hun", "age"). I cannot attribute that to this change without a before shot, but it is worth a look.
7. **Task file:** `## Verification` has zero executable lines, so P-011 is vacuous (same fault as T-3574).

### The open criterion: warm DOMContentLoaded under 500ms

**My call: met at normal load, marginal under heavy load. It cannot be ticked yet, because the fix below will change the page.** At load 3-7 I measured a median of ~440ms with 5 of 6 runs under 500ms. That agrees with the parent's 494ms. The builder's 527-592ms was at load 20-28, and roughly 40% of DCL is TTFB, so host load dominates the variance.

**The criterion should stand at 500ms as written.** I do not recommend moving it. The page is fast enough for its purpose at that number, and the number is achievable. Remeasure after un-hiding current work: 27 more cards is roughly 100KB, which may push DCL over the line, and that is the honest test of whether the fix fits the budget. If it does not fit, trim per-card markup (the 4 inline forms per card) rather than hiding cards or relaxing the target.

### GUIDANCE

1. **Required: fix the board so current work is visible.** Either do not cap the active-work columns (In Progress, Issues), or order each column newest-first (by `last_update` or descending ID) *before* capping. Only the backlog (Captured) and archive (Completed) columns should be capped. Add a test asserting that the most recent started-work task appears on the default board.
2. **Required: bound the signature cost.** Memoise `_task_files_signature()` per request (`flask.g`), or give the signature itself a ~1-2s TTL, so loops like `_read_task_meta` ×53 pay once. Then re-measure `/arcs/continuous-run` warm under 1s. This is the cross-task regression into T-3574.
3. **Should: preserve active filters in the `+N more` link** (owner, horizon, tag, q, type, component, sort), so overflow from a filtered board lands on the same filtered list.
4. **Should: put real, guarded commands in `## Verification`** (pytest for `test_t3575_tasks_page_perf.py`, `bin/fw watchtower current`, `bin/fw vendor self --check`).
5. The cache design is sound. Keep it, together with the cost fix in item 2.

---

## Re-review (round 2)

Reviewer: `perf-rereview` (independent; not the builder). Read-only except this file.
Measured 2026-09-30 05:55-06:10, load average 3.0-3.9. `bin/fw watchtower current` → current (pid 2195812 newer than every file under `web/`).
Commits reviewed: `fe0da3a23` (T-3577), `95df5e0d2` (T-3575), `c6c293e23` (T-3574). Probe script: `/tmp/rr2/check.py` (headless Chromium, POSTs intercepted and fulfilled locally, so **no task file was written**).

### T-3574: arc page

**VERDICT: GREEN.** Every round-1 item is closed. The warm criterion is now met live, the coherence test is real, and the page renders the same as before, apart from one intended change: T-3440 now appears on dispatch-safety.

#### WHAT I CHECKED

1. **Warm time (curl, 6 runs each):**

   | route | warm | round 1 | criterion |
   |---|---|---|---|
   | `/arcs/continuous-run` | **0.40-0.49s** | 1.65-1.83s | <1s |
   | `/arcs/dispatch-safety` | 0.19-0.25s | 0.49-0.77s | — |
   | `/arcs/readme-first-run` | 0.18-0.23s (one outlier at 0.55s) | 0.21-0.38s | — |

   This agrees with the builder's 0.40-0.46s. I could not reproduce a true cold request without writing a task file or restarting the server, which is outside my remit. **The cold figure (0.99s) is the builder's alone.**
2. **The signature memo** (`web/shared.py:_task_files_signature`) is keyed in `flask.g`, applies to GET/HEAD only, and is recomputed outside a request. Correct: a POST that writes a task file and then reads it back still re-stats, and the next request always re-stats.
3. **Render:**
   - `/arcs/continuous-run` is 200 at 152,851 bytes, byte-count identical to round 1.
   - BVP_norm is still 0.233.
   - `/arcs/dispatch-safety` now lists T-3440. This is the intended T-3577 effect, not a regression.
4. **Tests:** `test_t3574_arc_page_perf.py` and `test_t3575_tasks_page_perf.py` pass, 14 in 92s. I did not repeat the builder's old-parser control run (red with the old parser). The test design now matches my round-1 cross-check, which went red on exactly that arc.

#### GUIDANCE

- Tick the warm criterion. Recommendation GO.
- The one visible change (T-3440 joining dispatch-safety, so its member count rises by one) should be mentioned in the T-3577 or T-3574 review handoff, so the operator is not surprised by it.

### T-3575: tasks page

**VERDICT: GREEN (with one should-fix on blank selects).** The RED item is resolved: current work is on the board. The lazy selects work and post the same payload as before. The 500ms DCL budget holds.

#### WHAT I CHECKED

1. **Board contents** (default `/tasks`, live):
   - T-3575, T-3557, T-3576, T-3573 and T-3574 are all on the board.
   - In Progress shows **47 of 47**, uncapped, starting T-3575, T-3535, T-3557.
   - Issues is uncapped.
   - Captured shows 20 of 170, newest first (T-3576, T-3573, T-3572 …).
   - Completed shows 10 of 3343, newest first (T-3574, T-3577 …).
   - Only Captured and Completed carry `+N more`.
2. **Filters kept:** on `/tasks?owner=human&horizon=now`, the overflow link is `/tasks?view=list&status=work-completed&owner=human&horizon=now`.
3. **Lazy dropdowns still work.** I tested them on T-3573 with POSTs intercepted.
   - Each select starts with 1 `<option>`.
     - On `mousedown` (owner, type) the full list appears: owner gives 3 options and type gives 7.
     - On keyboard `focus` (horizon) the full list also appears, with 3 options.
     - The current value stays selected in both cases.
   - Changing a select fires `POST /api/task/T-3573/<field>` with body `<field>=<value>`, `Content-Type: application/x-www-form-urlencoded` and an `X-CSRF-Token` header. I checked this for owner, horizon, type and status.
   - That matches what the endpoints read (`request.form.get("owner")` etc., `web/blueprints/tasks.py:1037-1128`). `csrf_protect` accepts the header (`web/app.py:155-156`), so dropping the hidden `_csrf_token` input is safe.
   - The builder's Playwright test also passes (`test_tasks_board_lazy_selects.py`, 2 tests), but only with `FW_TEST_PORT=3187`: port 3099 is occupied on this host. That is an environment issue, not a fault in the test.
   - **Not verified: end-to-end persistence against a real file.** No throwaway task exists and this review is read-only. The endpoint code is unchanged, and the request it receives is field-for-field the same as before, so I rate persistence as very likely. It is not proven by me.
   - `htmx:afterRequest` now handles `elt` being the select itself, so the board still reloads after a status change (read from code, not observed).
4. **Blank select** (for example T-3568, which has an empty `owner:`, and completed tasks with `horizon: null`, 10 on the default board):
   - It renders as a narrow pill containing only a chevron (`/tmp/rr2/blankcard.png`).
   - It is more honest than round 1, which showed the first option as if it were the value. It is still **mildly confusing**: nothing says which field it is or that it is unset.
   - On the Completed column most cards show a bare chevron for horizon, which reads as visual noise.
5. **Speed:**
   - curl `/tasks` returns 293,886 bytes in 0.17-0.22s warm (6 runs).
   - Headless Chromium from about:blank, 10 navigations: DCL was 605ms on the first load, then 423, 428, 421, 482, 415, 421, 445, 401 and 400ms. The **warm median is ~421ms, and all 9 warm runs are under 500ms.** TTFB was 169-243ms.
   - The builder's 454ms median is plausible, and if anything conservative at today's load.
   - I could not independently force a cold request, for the same reason as T-3574.
6. **Markup trade-offs, noted but acceptable:**
   - The delegated `change` listener and the `WT_LAZY_OPTIONS` guard live on `document` for the page lifetime. They are guarded against re-registration on htmx swaps and scoped to `.kanban-card[data-task-id]`.
   - `content-visibility: auto` on cards is fine.
   - The list view is unchanged.

#### GUIDANCE

- **Should:** give an unset board select a visible label instead of a bare chevron. For example, render the lazy option as a muted `—` or `owner?` with `value=""`, which keeps today's honest "unset" semantics. Alternatively, skip the horizon select on work-completed cards, where horizon is meaningless. This is cosmetic and fits the render-review Human AC. It is not a blocker.
- **Before close:** do one real persistence check on a throwaway task (change owner on the board, reload, confirm the file changed). This is the only claim in this review that rests on code reading rather than observation.
- **Minor, from round 1 and still open:** `_TASK_FM_CACHE` never evicts deleted paths, and nested `tags` lists are shared, not copied.
- Recommendation GO. The render-review Human AC stays with the operator.

### Persistence check (parent session, as the re-review asked before close)
- Throwaway task T-3578 created. On the live /tasks board, its lazy owner select was
  clicked and changed from agent to human.
- The task file then read `owner: human`. That is observed, not code-read. T-3578 was
  never committed and was removed afterwards.
- Open should-fix, not a blocker: give an unset select a visible label. It is
  cosmetic and was left for a follow-up.
