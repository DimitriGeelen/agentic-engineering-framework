# T-3604 — OBS-587 triage B: red unit-test files

Half B of OBS-587: 22 bats files and 6 pytest files that T-3601 found red on HEAD.
Every file was re-run on its own. Every verdict names the commit that broke it.

Verdicts:
- **STALE**: the code changed on purpose and the test was not updated. Only the test was fixed.
- **REGRESSION**: behaviour that a user or a gate relies on broke. A bug task was filed and nothing was fixed here.
- **ENVIRONMENT**: the test depends on host state that is currently broken (see below). Where the test could be made hermetic without weakening it, it was hardened (test-only change).

## Host environment finding (read first)

The filesystem root is polluted. It holds an empty git repo `/.git` (created 2026-09-30 22:30 +0200, no commits), plus `/.tasks` (T-9999-test.md, T-994/T-995/T-996 fixtures), `/.context`, `/.agentic-framework`, `/.claude` and `/.mcp.json`.

The consequences:
- **Every temp dir is inside a git repo.** `git -C /tmp/<anything> rev-parse` resolves to `/`, so any test that assumes a temp dir is not a git repo goes red.
- **`/` resolves as a project root**, so foreign `.tasks/` get unioned in.

This is already tracked by **T-2787** (the guard) and **T-2750** (find the leaking test). The `/.git` itself is new since T-2787 was filed.

Nothing at `/` was deleted: it is outside the repo, and removing it is the operator's call. Once it is cleaned, `no_root_framework_markers.bats` should go green with no change.

## Results

| File | Failing tests | Breaking commit | Verdict | Action |
|---|---|---|---|---|
| no_root_framework_markers.bats | t4 filesystem root carries no markers | none (host state) | ENVIRONMENT | None. This test is the detector and is correctly red. Tracked by T-2787/T-2750. |
| rail_identity_guard.bats | t2, t4, t6 | 4b319161a (T-3010 set `RAIL_IDENTITY_FILE` in the repo's `.framework.yaml`; reshaped by 81f740ddd T-3534) | STALE | a462e5276. The unconfigured case now runs in a scratch project, and t6 no longer writes the live bypass log. |
| recommendation_gate_build_partial.bats | t7 | 7a24ba133 (T-3549 handoff-ready predicate refuses first) | STALE | 29e9b9ef4 |
| resume.bats | t7–t10 (all `resume status`) | 3541d8c03 (T-3090 created T-3324, whose name contains `\|`), which triggers a latent bug from e7af0f87f (T-373) | REGRESSION | **T-3607**. `fw resume status` exits 1 in this repo. |
| review_pipefail.bats | t1, t2, t5 | 7a24ba133 (T-3549) | t1–t2 STALE, t5 REGRESSION | t1–t2 fixed in 29e9b9ef4. t5 → **T-3609** (`FW_ALLOW_EMPTY_RECOMMENDATION` is inert for inceptions). The same bug is behind T-3603's audit_inception_recommendation t10. |
| sessions_claude_code_adapter.bats | t1–t10 | bde6bf284 (T-2417 committed the adapter as mode 100644) | REGRESSION | **T-3606**. `fw sessions` fails for everyone with "adapter not executable". |
| t100144_handover_divergence.bats | t6 | b4304ab0a (T-3194 nudge names the measured dev branch) | STALE | ed8fdeb33. It now also asserts that master is not hard-coded. |
| t100202_id_quarantine.bats | t1–t6, t8, t10 | none (host state) | ENVIRONMENT | a9bad42f1. The allocator unioned `/.tasks` (T-996 → minted T-997). Fixed by fencing git discovery above `BATS_TMPDIR`. |
| t2094_upgrade_preflight_doctor_advisory.bats | t7 | e81997f03 / 5aecd951c (T-2845: doctor runs the consumer's own `fw`) | STALE | dfd48e19b |
| t2228_audit_sentinel_skip.bats | t7 | 503058289 (T-2298 moved the sentinel skip into the Python arc map) | STALE | 8b2015fb3. Test-only change; audit.sh was not touched. |
| t2230_bvp_driver_init.bats | t1–t5, t10–t15 | 67893ed78 (T-2391: a PROJECT_ROOT with no marker is re-resolved) | STALE | 94e612aad. The fixture needs a `.tasks` marker. Before the fix, `--init --force` ran against the live repo. |
| t2244_audit_self_vendor_drift.bats | t2, t3 (solo run: 710s, over the 600s budget) | t2: b80676112 (T-2436: the libs remedy is now `fw vendor self`). t3: not found | t2 STALE, t3 UNCLEAR | Not fixed: covers agents/audit (another worker's file). See note. |
| t2267_self_vendor_web.bats | t3, t4 | b79a058cc (T-2412: self-vendor syncs the full render surface, including html) | STALE | 0371e14ad |
| t2298_audit_structure_no_perfile_fork.bats | t3, t4 | t3: 0f5093468 (T-3099 renamed `go_scope_unprop_list` → `go_scope_summary`). t4: b16bd0e71 (T-3469 comment text contains "python3 -c"; still exactly one invocation) | STALE | Not fixed: covers agents/audit (another worker's file). |
| t2331_driver_propose.bats | t1, t2, t4, t8 | 67893ed78 (T-2391) | STALE | 94e612aad. The test had appended 20 proposal rows to the live `.context/bvp-driver-proposals.jsonl`; they were all test signatures and were restored to HEAD. |
| t2380_transcript_dir_encoding.bats | t2 | b2ad63d4b (T-2425: `fw_claude_project_dirs` emits only dirs that exist) | STALE | 93b79df78 |
| t2392_worktree_transcript_resolution.bats | t4 | none (host state) | ENVIRONMENT | 2a4eb51c9. `GIT_CEILING_DIRECTORIES` added. |
| t2466_worktree_status.bats | t7 "outside a git repository" | none (host state) | ENVIRONMENT | 2a4eb51c9. `GIT_CEILING_DIRECTORIES` added. |
| t2862_greenfield_first_inception_e2e.bats | t4 | c03759959 (T-2921 fixed the P-011 extractor that this test pinned as broken) | STALE | aa0d72c58. The test now pins the fix: the line runs through the gate verbatim. |
| t2912_upgrade_hook_regen_convergence.bats | t1, t2, t3, t5 | none (host state) | ENVIRONMENT | 85f005cac. The consumer's "git" was `/.git`, which failed the vendor-visibility check. Git discovery is now fenced in `fresh_run`. |
| t3039_write_set_implicit.bats | t7 | 971e94f66 (T-3046 added an implicit entry that cites its task, not the inventory) | STALE | 5642d889f. Provenance now accepts either the inventory or a task id. |
| t3056_recall_open_tasks.bats | t10 (live corpus hit rate) | none. The recall code is unchanged since 6fa7c7544; the live corpus drifted from 22% to 38% (T-3326 class) | STALE | fbd34c13a. The bound is now the hazard T-3056 documents (under 50%). The drift is worth a tuning look. |
| tests/playwright/test_arcs_pages_tokens.py | both tests, at setup | none (host state) | ENVIRONMENT | None. Port 3099 is held by 832-Workflow-designer's `gallery-serve.py`. With `FW_TEST_PORT=3187` both tests pass. The hex values in `arc_detail.html` are `var(--pico-…, #hex)` fallbacks and don't trip the test, so the template was not changed. |
| test_bvp_estimator_v_alias.py | test_dispatch_unknown_driver_falls_back_to_score_free_driver | 491733d90 (T-3427: a driver with no scorer is UNSCORED) | STALE | 13780e4f0 |
| test_corpus_lint.py | test_live_corpus_all_versions_census | a4f13ccc1 (T-3159 added draft-continuous-run-loop v1–v5) | STALE | 7a067b6ce. Re-pinned 42 → 47 versions. Flagged stays at 14. Additions-only was proven: six ADDs, corpus_lint untouched, no new version flagged. |
| test_inception_decide_warning_widen.py | 3 side-effect-warning tests | 122655001 / 7ef84ca56 (T-3280/T-3284 reworded the htmx warning, so the locator hit the redirect block) | STALE | 93793ab99. The locator is re-anchored; `[:1500]`, escape and pre-wrap all still hold. |
| test_operator_facing_stderr.py | test_every_stderr_render_site_is_sanitized | 348ff8bbe (T-3553: `_arc_demo_state` renders raw demo-check stderr) | REGRESSION | **T-3605** |
| test_t3066_approve_route.py | 3 tests | 491733d90 (T-3427: `--add` refuses a driver with no scorer before the drop-identity guard) | STALE | 13780e4f0. The fixtures now propose drivers that have scorers. |

**Counts:** 17 files STALE and fixed (review_pipefail counted here for t1–t2); 6 files ENVIRONMENT, 4 of them hardened; 4 REGRESSIONS filed (T-3605, T-3606, T-3607, T-3609); 2 files classified but left unfixed because they cover agents/audit (t2298 STALE; t2244 t2 STALE); 1 test UNCLEAR (t2244 t3). Two files have mixed verdicts: review_pipefail (stale + regression) and t2244.

## Side effects found and cleaned

- **t2331** had leaked into the live `.context/bvp-driver-proposals.jsonl`: 20 rows across four runs today. Every added row carried a test signature (V_TEST_DRIVER, V_AGENT_PROPOSED, V_RACEY, V_TASK_REF), so the file was restored to HEAD. The fixture fix stops the leak.
- **bvp_auto_promote.bats** (T-3603's file) mutates the live `policy/value-drivers.yaml` (`auto_promote.enabled: true`, `max_concurrent: 999`) and relies on teardown to restore it. It was seen mid-run and was clean again later. A timeout-killed run would leave the live policy auto-promoting. That is worth making hermetic.
- **t2244** also mutates the live vendored tree (`.agentic-framework/lib/upgrade.sh`, templates) and relies on teardown. After the timeout-killed run, no sentinel was left.

## Note: t2244

- **Runtime.** The file hit the 600s ceiling under 22-way parallel load. Run solo, it took 710s for two tests, because each test runs a full `fw audit --section structure`. It exceeds a 600s per-file budget by itself, which matters for the nightly runner (T-3602).
- **t2 (STALE).** Since b80676112 (T-2436), the libs-class FAIL recommends `fw vendor self` on purpose. The test still asserts the pre-T-2436 `fw vendor ` (full) remedy.
- **t3 (UNCLEAR after the time-box).** With only `.agentic-framework/.tasks/templates/default.md` mutated, the audit printed no `Self-vendor drift: templates class` line. It did print a libs-class drift for one file, from the concurrent worker's in-flight `agents/audit` edits (worktree-scoped). What was ruled out:
  - `check_self_vendor_drift` is byte-identical in HEAD and the working tree.
  - The source `.tasks/templates/default.md` exists.
  - The vendored templates are real files, not symlinks.
  - After the run, the two files are identical again (teardown restored them).

  Not yet explained: why the templates leg did not count the mutated pair. The next step is to run `check_self_vendor_drift` directly (outside the 700s audit) with the sentinel in place. That was not done here, because the file writes the live vendored tree while other workers are active.
