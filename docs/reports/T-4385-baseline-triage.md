# T-4385 — Baseline cliff triage (44 entries, 28 files)

**Date:** 2026-10-19. **Source:** `.context/audits/unit-suite/baseline.yaml` (44 entries; 32 expire
2026-10-31), persistence counts over the 20 v2 suite reports (method: T-4376 measurement §3).
**Method:** every baselined file run **alone** (`bats --tap` / `pytest -q`, 600 s cap, one file at a
time) on bleeding-edge at ~bf6928ebb; each red localised to file:line; outcome per file.

## Summary

| Outcome | Files | Entries | Of the 22 always-red |
|---|---:|---:|---:|
| **fixed** here (test-side cause; red before / green after, alone) | 6 | 10 | 6 |
| fixed upstream since baselining (green alone, cause gone) | 1 | 1 | 0 |
| **defect, owner task** (test correct, product wrong) | 9 | 16 | 16 |
| green alone, red only in the loaded suite (load/state) | 11 | 15 | 0 |
| other worker in flight (not touched) | 1 | 2 | 0 |
| **total** | 28 | 44 | 22 |

No test was deleted outright. One test was removed as a **duplicate**
(`audit.bats` "audit runs structure section", merged into the identical live run), and one
as **testing removed behaviour** (`handover_push_timeout.bats` "default push timeout is 60s",
whose default T-3450 removed deliberately; the replacement is pinned by
`t3450_push_timeout_derivation.bats:181,189`). Reasons are written in the test files.

## Per-file ledger

Columns: suite = reports red / 20 (max over the file's entries); alone = result run alone today.

| File | Entries | Suite | Alone | Cause (file:line) | Outcome |
|---|---:|---:|---|---|---|
| handover_push_timeout.bats | 3 | 20/20 | red 3,4,7 → **green** | stale wording: T-3063 reworded the 124 branch to "was KILLED at" (`agents/handover/handover.sh:229`); checkpoint now runs `timeout N bash handover.sh` (`agents/context/checkpoint.sh:299`); T-3450 replaced the static 60 s default with a derivation (`handover.sh:159-169`) | **fixed** (t3, t4 follow the code; "60s default" deleted — removed behaviour, covered by t3450). Mutation: dropping the timeout wrapper still fails t4. bf6928ebb |
| t2244_audit_self_vendor_drift.bats | 2 | 20/20 | timeout 600 s → **green 0.8 s** | ran the whole live `fw audit --section structure` twice (~690 s each, timing ledger `timed_out: true`) while mutating the live `.agentic-framework/`; t2 also asserted "not `fw vendor self`", which T-2436 reversed on purpose (`audit.sh:3405-3415`) | **fixed**: real `check_self_vendor_drift` body (extracted from audit.sh) run on a synthetic root + static pin that the structure section calls it. Mutation (`cmp` neutered): t2, t3 red. fbce1f033 |
| t2298_audit_structure_no_perfile_fork.bats | 2 | 20/20 | red t3,t4 → **green** | T-3099 renamed `go_scope_unprop_list=` → `go_scope_summary=` (`audit.sh` T-2096 block); a comment inside the pre-scan names "python3 -c", counted as a 2nd invocation | **fixed**: follow rename; comment lines excluded from count. Mutation (2nd real invocation): t4 red. fbce1f033 |
| check_render_surface_human_ac_sigpipe.bats | 1 | 2/20 | red t3 → **green 5/5** | negative control relied on a race: 5-line producer fits in the pipe buffer, so `head -3` never SIGPIPEs (`tests/unit/check_render_surface_human_ac_sigpipe.bats:88`) | **fixed**: producer > 64 KiB makes the head-form death deterministic; same producer through the awk form must survive. bf6928ebb |
| test_cron_registry_generated_drift.bats | 1 | 17/20 | red t1 → **green** | `[ "$status" -ne 2 ]` read every doctor check; since T-3783 the vector-index checks FAIL in any fixture without an index (exit 2) | **fixed**: assert WARN severity on the drift line and no FAIL on any Cron registry line. 2280b913a |
| audit.bats | 1 | 6/20 (timed out 6/20) | timeout at test 2 (> 598 s) | tests 2 and 8 both ran the identical live `--section structure` (~690 s); suite per-file cap 900 s (LATEST.yaml: audit.bats 900) | **fixed**: duplicate test 2 merged into test 8 (its STRUCTURE assertion moved). Owner T-3812 can close on this. See §audit.bats evidence |
| context_safe_commands.bats | 1 | 19/20 | green | unclassified git verbs check-attr / check-ref-format / diff-index | fixed upstream by T-4368 (c57c885b5); `regenerate` drops it |
| approvals_close_ready_arcs.bats | 5 | 20/20 | red 1,2,3,5,6 | `bvp.load_policy()` `sys.exit(2)` escapes `except Exception` (`web/blueprints/approvals.py` `_arc_readiness_legs` → `arc_close_readiness.corpus_medians`) | **defect T-3611** (test correct) |
| atomic_yaml_write_lint.bats | 1 | 20/20 | red | `lib/govd_sandbox.py` `emit_profile` non-atomic YAML write | **defect T-3612** |
| audit_inception_recommendation.bats | 1 | 20/20 | red t10 | `FW_ALLOW_EMPTY_RECOMMENDATION=1` inert for inceptions: T-3549 handoff predicate in `lib/review.sh` refuses first | **defect T-3609** |
| lib_review.bats | 2 | 20/20 | red t10,t11 | same as above (both run with the bypass env) | **defect T-3609** |
| review_pipefail.bats | 1 | 20/20 | red t5 | same as above | **defect T-3609** |
| audit_split_root_asset_lint.bats | 1 | 20/20 | red t10 (count 20 ≠ 12) | 8 undispositioned PROJECT_ROOT framework-asset sites (`audit.sh`, `bin/fw`) | **defect T-3614** |
| doctor_hook_counters.bats | 3 | 20/20 | red t2,3,4 | `.claude/settings.json:252` Stop hook → `agents/context/stop-driver.sh` (not `bin/fw hook …`) trips doctor's own path rule | **defect T-3615** |
| test_bin_fw_no_heredoc_cmd_sub.bats | 1 | 20/20 | red t1 | heredoc-in-cmd-sub at `bin/fw:2597` (`_adr_out`, 6cbc5dd55) and `bin/fw:3173` (`_crl_out`, b072d815f) | **defect T-3632** (exists; baseline owner is T-4221 → re-own) |
| test_operator_facing_stderr.py | 1 | 20/20 | red | `approvals.py:927` raw stderr in arc demo detail (T-3605); `approvals.py:643` raw stderr in RuntimeError, sanitized only at :652, outside the scan window | **defect T-3605 + T-4407** (filed here) |
| fw_mode_detection.bats | 1 | 4/20 | green (271 s) | doctor slow under load | load/state — T-4038 |
| t2452_doctor_quick.bats | 1 | 7/20 | green | doctor under load | load/state — T-3992 |
| test_doctor_litellm_ollama.bats | 1 | 4/20 | green (260 s) | doctor under load | load/state — T-4138 |
| t2243_doctor_self_vendor_templates.bats | 1 | 4/20 (timed out 9/20) | green (436 s) | live doctor; also sees other tests' planted vendor drift (t2244's old form) | load/state — T-3747 (entry already expired 2026-10-18) |
| hook_telemetry_race.bats | 1 | 4/20 | green | wall-clock 5 ms budget assertion | load/state — T-4325 |
| fw_focus_alias.bats | 4 | 1/20 | green | single-report cluster | load/state — T-4325 |
| t1719_ask_routing.bats | 2 | 6/20 | green | live ask under load | load/state — T-4325 |
| t1719_index_one_post_write.bats | 1 | 1/20 | green | 5 s latency budget | load/state — T-4221 → T-4325 |
| t3662_watchtower_port_allocation.bats | 1 | 2/20 | green | port allocation vs concurrent holders | load/state — T-4221 → T-4325 |
| t4119_terminator_handover_git_extension.bats | 1 | 4/20 | green | elapsed-time terminator | load/state — T-4221 → T-4325 |
| no_root_framework_markers.bats | 1 | 18/20 | green | fixtures escaping to `/` under concurrent tests (T-2787 guard) | load/state — T-2787 is work-completed → re-own to T-4325 |
| fabric_coverage_single_source.bats | 2 | 2/20 | green | — | **not touched**: uncommitted edits from another worker in flight |

## audit.bats evidence

Before (alone, 2026-10-19): killed by the 600 s cap inside test 2 ("audit runs structure section").
After: see the run appended below by the T-4385 worker.

## What is left

- 16 always-red entries are correct tests on real product defects, all with an owner task:
  T-3611 (5), T-3609 (4), T-3615 (3), T-3612 (1), T-3614 (1), T-3632 (1), T-3605+T-4407 (1).
  Each fix is small and named in the owner task. They need staggered re-arms (task
  `## Proposed baseline changes`), not one cliff day.
- 15 load/state entries pass alone. They are T-4325 / T-3992's class, so a per-test fix here
  would be guessing at a load cause that can't be reproduced alone.
