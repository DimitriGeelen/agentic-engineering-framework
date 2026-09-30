# T-3603 — OBS-587 triage A: red unit suites (approvals..lib_review)

Every file was re-run alone on `bleeding-edge` (foreground, `timeout 280–600 bats`).
All 24 were red in isolation. The task title says 25, but the list in the task and
in OBS-587 names 24 for half A.

Verdicts:
- **STALE**: the code changed on purpose and the test was not updated. The test was fixed.
- **REGRESSION**: behaviour a user or gate relies on broke. A bug task was filed; nothing was fixed here.
- **ENV**: host or worker environment, not code. The test was made hermetic.
- **TRACKED**: already owned by an existing task.

## Verdict table

| File | Failing tests (at triage) | Breaking commit | Verdict | Action |
|---|---|---|---|---|
| approvals_close_ready_arcs | 1,2,3,5,6 (`run_loader` exit 2) | 2a1689fd7 (T-3552) | REGRESSION | T-3611 |
| atomic_yaml_write_lint | 1 (`lib/govd_sandbox.py` has no atomic write) | 4d0448ec4 (T-2433) | REGRESSION | T-3612 |
| audit_arc_progress_arc_id | 8 (greps removed `re.escape(arc_slug)`) | 9e4bbebf2 (T-3507) | STALE | d24e04621 |
| audit_corpus_lint_findings | 1 (PASS wording) | 92deaef0c (T-3105) | STALE | 0e985120b |
| audit_inception_recommendation | 8, 9 (block wording); 10 (bypass) | 7a24ba133 (T-3549) | 8–9 STALE; 10 REGRESSION | 8597cc8a0; 10 → T-3609 (dup T-3613) |
| audit_seed_corpus_refs | 1, 6 (PASS wording; empty set now WARNs) | 92deaef0c (T-3105) | STALE | 0e985120b |
| audit_split_root_asset_lint | 10 (shell ratchet 12 → 20) | a998be7e4, 4d0448ec4, 26bbee259, 83dabfbb8 | REGRESSION (sites not reviewed) | T-3614 |
| audit_stale_arc_warning | 2 (PASS wording) | 92deaef0c (T-3105) | STALE | 3d201c083 |
| bvp_auto_promote | 2, 3 (live log expected empty) | c3165673a (log committed with 8 entries) | STALE (mutable-corpus anchor) | 9ea87da6e |
| context_learning | 4, 6 (allocator sourced from fake FRAMEWORK_ROOT) | 155aa703b (T-2902) | STALE | fa71fc6fc |
| costs_union_leg | 5 (rc 1 with correct output) | none: stray `/.git` | ENV | 559f48591 |
| doctor_hook_counters | 2, 3, 4 | 3dcef93a2 (T-3164) | REGRESSION | T-3615 |
| fabric_watch_pattern_fitness | 1, 4 (PASS wording) | 92deaef0c (T-3105) | STALE | f6e8ff07d |
| gaps_close | 9, 11 (CLI read the real concerns.yaml) | 67893ed78 (T-2391) | STALE | fbf56992c |
| handover_push_timeout | 3, 4, 7 | T-3063 / T-3450 wording; test 4 hides OBS-573 | TRACKED | T-3556 (+ OBS-573); not edited |
| hook_enable_absolute_path | 1, 2, 4 (absolute path expected) | 74688119d (T-2709) | STALE | 70b9bbacf |
| hook_producer_site_parity | 3, 5 (3 hooks unmirrored) | a5a827fac, bd7af23de, 6506ecd32 | REGRESSION (×3) | check-paid-backend → T-3589; check-worktree-governance-write → T-3616; sidecar-inbox → T-3617 |
| init_git_identity_blocker | 1–4 (identity "resolves") | none: stray `/.git` + worker `GIT_AUTHOR_*` env | ENV | d60b693bb |
| init_head_bootstrap | 1–6 | none: stray `/.git` | ENV | 559f48591 |
| learning_application_birth | 5 (placeholder scan hit) | 155aa703b (T-2902 comment prose) | STALE (+ ugrep `./` prefix) | 41ea121ab |
| lib_config | 17, 19 (CONTEXT_WINDOW default) | 8193dfaa8 (T-3455) and later operator rulings | STALE (live config anchor) | 894d4aa19 |
| lib_costs | 1, 2 (nonexistent projects dir) | b2ad63d4b (T-2425) | STALE | 9a38f23de |
| lib_inception | 13 (T-999 "not found" before gate) | 5777bb52d (T-2964) | STALE | 69339487f |
| lib_review | 10, 11 (`FW_ALLOW_EMPTY_RECOMMENDATION` bypass) | 7a24ba133 (T-3549) | REGRESSION | T-3609 (dup T-3613) |

Caveat on audit_corpus_lint_findings: tests 1–8 are green. Test 9 ("the audit
sees the REAL store") runs a full audit of the real repo. On two re-runs it
skipped once (`another audit holds the real repo's lock`) and was killed by the
300s timeout once, both caused by concurrent workers auditing the same checkout.
It did not fail, and my change does not touch it.

Counts: 16 files fixed and green in isolation, with 0 skips except where noted
below: 12 stale plus 4 environmental. 7 regression tasks filed (T-3611 to T-3617),
one of them a duplicate (T-3613 → T-3609). Further regressions route to existing
T-3609, T-3589 and T-3556. 0 UNCLEAR.

Files still red on purpose (regression not fixed here): approvals_close_ready_arcs,
atomic_yaml_write_lint, audit_inception_recommendation (test 10),
audit_split_root_asset_lint, doctor_hook_counters, handover_push_timeout,
hook_producer_site_parity, lib_review (tests 10–11).

## Evidence notes

**T-3105 family (4 files).** `pass_over` (agents/audit/audit.sh:777) now prints
`<msg> — examined N <set>`, and an empty set gives a `NOT EVALUATED` WARN instead
of a PASS. Tests pinned the old wording. The fixes assert the new line in full,
including the `[PASS]` tag.

**approvals (T-3611).** Traceback: approvals.py:600 → `_arc_readiness_legs`:675 →
arc_close_readiness.py:155 `bvp.load_policy()` → `SystemExit: 2`. The function's
docstring promises it degrades to None, but `except Exception` cannot catch
`SystemExit`. Any project without `policy/value-drivers.yaml` that has an
in-progress arc crashes the loader.

**split-root ratchet (T-3614).** Blame of all 20 sites. The 8 added after the
28c7a1bd3 baseline are named in the task. `$PROJECT_ROOT/lib/seeds/tasks`
(T-2980) looks like a real split-root bug, not a policy instance.

**doctor_hook_counters (T-3615).** Symlinking `agents/` into the fixture removes
the FAIL but leaves `WARN Hook path isolation: 1/31 hooks use hardcoded paths`.
The Stop hook violates doctor's own portability rule, so the test was left as it is.

**handover_push_timeout.** T-3556 already has a per-test verdict for all three
reds, and test 4 depends on the OBS-573 fix. Not edited, to avoid colliding with
that task.

## Environmental findings (for the operator)

1. **Stray git repo at the filesystem root.** `/.git` (created 2026-09-05, no
   commits, `user = T <t@t>`) sits next to `/.agentic-framework/FRAMEWORK.md`,
   `/.claude`, `/.context`, `/.tasks` and `/.mcp.json`. It looks like a `fw init`
   (or a test) once ran against `/`. Every `mktemp -d` fixture is therefore inside
   a git repo. `fw init <tmpdir>` then attaches to `/` and tries to commit into
   it (`fatal: Unable to create '/.git/index.lock'`). I did not remove it, because
   it is outside the repo and deleting it is the operator's call. The affected
   tests now set `GIT_CEILING_DIRECTORIES`, the same approach T-3604 took in
   a9bad42f1.
2. **Dispatch workers export `GIT_AUTHOR_*` / `GIT_COMMITTER_*`.** So "no git
   identity" states cannot be reproduced unless a test unsets them.
   init_git_identity_blocker and init_head_bootstrap now do that.
3. **`/usr/bin/grep` is ugrep 7.8.4.** It prints `lib/x` rather than `./lib/x`
   for `grep -r pat .`, which silently disables any `grep -v '^\./…'` exclusion.
   learning_application_birth now normalises the prefix. Other tests with the same
   pattern may exist; they were not audited.
4. **`policy/value-drivers.yaml` was found truncated in the working tree** at
   2026-09-30 23:46:50: 17148 of 24828 bytes, cut off mid-key at `retire_when`,
   uncommitted. That made `fw init` validation fail (`yaml-2bv … invalid YAML`)
   and would break every BVP reader. The cause is a torn write from a test that
   mutates the live policy. Two tests in the corpus do that:
   `bvp_auto_promote.bats` and `bvp_auto_promote_enable.bats`, which rewrite it
   in place and restore it in teardown. My only run of the first ended before
   23:37, so I could not attribute it. The truncated copy is saved at
   `/tmp/t3603/value-drivers.truncated.yaml`, and the file was restored from HEAD
   (`git checkout -- policy/value-drivers.yaml`). This task committed no change
   to it.
5. **`bvp_auto_promote_enable.bats` writes into the live
   `.context/bvp-auto-promote-log.yaml`.** Its enable/disable events were swept
   into commit c3165673a. That is the population bvp_auto_promote.bats tripped
   over. Not filed here, since that file is not in half A. Both BVP tests mutate
   live framework state and should use a sandbox copy.
6. **Latent code issue (not filed).** `fw_claude_project_dirs` (lib/paths.sh:285)
   returns the status of its last `[ -d ] && printf`, so it exits 1 whenever the
   last candidate dir is missing, even when it printed a valid dir. The only
   caller seen captures stdout, so the impact is low today.

## Files touched

Test files only, under `tests/unit/`. No source outside `tests/` was changed by
this task's commits. The only non-test write was the restore of
`policy/value-drivers.yaml` (item 4), which returns it to HEAD and is not committed.
