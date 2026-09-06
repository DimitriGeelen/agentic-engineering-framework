# T-3289 Observation Triage — Worker w4

Scope: OBS-359 OBS-360 OBS-361 OBS-362 OBS-363 OBS-364 OBS-365 OBS-366 OBS-371 OBS-372.
All verifications performed live on 2026-09-06 against the working tree (branch `bleeding-edge`).
Disposition counts: **7 PROMOTE / 3 DISMISS / 0 DEFER**.

---

## OBS-359 — exact-count assertion in ac_counter suite is a false red

**Verdict: PROMOTE** — task: "ac_counter tolerant-regex assertion: exact count → floor" (`workflow_type: test`). AC: `bats tests/unit/ac_counter_sed_range_one_line_comment.bats` is green with ≥2 tolerant-form sites present and zero occurrences of the broken `<!--[^>]*-->` form asserted as the real invariant.

- Confirmed still red by running the test today: `not ok 1 ... line 34` — `grep -c ... -eq 2` failed.
- The tolerant regex now appears at **3** sites in `agents/task-create/update-task.sh` (lines 144, 169, 1544), all correct uses; the broken form appears 0 times (both greps re-run today).
- The assertion at `tests/unit/ac_counter_sed_range_one_line_comment.bats:34` still reads `-eq 2`; the file has not been touched since the observation.
- Fix shape as filed: `-eq 2` → `-ge 2`; keep line 35's zero-broken-form assertion (already present) as the invariant that matters.

## OBS-360 — inception_decide_emit_review_post_move test 1 red

**Verdict: PROMOTE** — task: "do_inception_decide non-zero exit on stale task_file post-move path" (`workflow_type: build`, bug). AC: `bats tests/unit/inception_decide_emit_review_post_move.bats` passes 3/3.

- Re-ran the suite today: `not ok 1 post-move: do_inception_decide exits 0 when emit_review sees stale task_file` (`tests/unit/inception_decide_emit_review_post_move.bats:107`, `[ "$status" -eq 0 ]` failed); tests 2 and 3 pass. Identical failure to the filing.
- Last commit touching the suite is `4ef72961e` (T-1509) — old; no fix has landed since capture.
- Likely related family: OBS-367 (out of my scope, pending) reports `audit_inception_recommendation.bats` test 5 red in the same `emit_review` code path — the promoted task should check both before closing (may be one root cause; if so, one-bug-one-task still holds — diagnose first).

## OBS-361 — nothing runs tests/unit on a schedule; audit green line over-claims

**Verdict: PROMOTE** — task: "scheduled tests/unit run + audit line names its corpus" (`workflow_type: build`). AC: a scheduled (cron-registry) tests/unit run exists whose result surfaces like the invariant suite, and the audit output states which test corpus it examined (checked completion `1..N` vs N results, not just absence of `not ok` — per OBS-365).

- Confirmed: `.context/cron-registry.yaml` has zero `tests/unit`/`bats` entries (grep today).
- Confirmed: `agents/audit/audit.sh:2771` runs `bats tests/lint/` only; the pass line at `audit.sh:2780` reads "Invariant suite green" — the narrow-answer-to-a-wide-question shape the OBS names.
- No active task covers this (grepped `.tasks/active/` for tests/unit-scheduling work; none found).
- Sequencing constraint for the promoted task: tests/unit currently **cannot** complete (OBS-365 hang, re-confirmed today), so the OBS-365 fix is a prerequisite or the schedule must handle per-suite timeouts.

## OBS-362 — "a bats suite clobbered the live session focus"

**Verdict: DISMISS** — root cause corrected by OBS-364 (same incident, same author, same session): the writer was an orphaned background bats tree that outlived its supervisor, not the suites the OBS names.

- OBS-364 explicitly opens: "CORRECTION to OBS-362 and OBS-363 — root cause found, and it is neither suite."
- Counter-evidence gathered today: I ran `tests/unit/update_task.bats` both filtered and in full (timed out at 240s) with `.context/working/focus.yaml` md5-checked before/after — **identical both times** (`0fe76edf…`). No live-focus write from the suite on a clean run.
- The guard work the OBS asks for (focus-unchanged assertion across suite runs) is carried by OBS-364's promotion; a separate 2026-09-05 focus stomp is already tracked as OBS-369 (different fingerprint, out of my scope).

## OBS-363 — update_task.bats does not complete (first measurement)

**Verdict: DISMISS** — superseded by OBS-365, which is the quiet-host re-measurement of the same defect. OBS-364 flagged this measurement as contaminated (orphan running the same suite concurrently); OBS-365 re-measured cleanly and is the authoritative record. Promoting both would violate one-bug-one-task; the promote rides on OBS-365.

## OBS-364 — orphaned bats trees outlive their killed supervisor

**Verdict: PROMOTE** — task: "guard against concurrent/orphaned bats runs (T-577 shape for bats)" (`workflow_type: build`). AC: starting a framework bats run refuses (or warns) when a bats tree is already running, and an orphan-bats detection/cleanup verb exists analogous to `fw termlink cleanup`, pinned by test.

- The class is real and unguarded: grepped `bin/fw` and `lib/` — no concurrent-bats assertion and no orphan-bats detector exists. `lib/cron-orphans.sh` (T-3281) is a different class (deployed cron entries with vanished PROJECT_ROOT), though it proves the detect-only pattern the fix can copy.
- Confirmed environmental plausibility today: a separate live bats tree (`timeout 300 bats tests/lint/`, PID 3823378 + exec-suite children) was running on this host during my triage — concurrent trees against the live tree are a normal occurrence here, exactly the condition the OBS describes.
- The named analogue is apt: T-577 (`fw termlink cleanup` kill-watchdog for orphaned dispatches) is documented in CLAUDE.md §Timeout Orphan Warning; nothing equivalent covers bats.

## OBS-365 — update_task.bats hangs entering test 14; a third of the suite never runs

**Verdict: PROMOTE** — task: "update_task.bats hangs mid-suite — 6 of 19 tests never run" (`workflow_type: build`, bug). AC: `timeout 120 bats tests/unit/update_task.bats` completes 19/19 with a completion check (`1..19` and 19 results), pinned so a partial run cannot read as green.

- Re-confirmed today: full-suite run killed by `timeout` at 240s (exit 143), while other update-task-driving suites finish in seconds. File unchanged since observation (`git log`: last touch `de5a1662e`, T-3138).
- **New data point for the fix**: test 14 ("T-1589: started-work + shipping evidence preserved on horizon later", `tests/unit/update_task.bats:160`) **passes in seconds when run in isolation** (`bats -f "shipping evidence preserved"` → 2/2 ok). The hang is sequence-dependent (state accumulated by tests 1–13, or a different blocking test in full-run ordering), not intrinsic to test 14 — the promoted task should bisect the run order, not stare at test 14's body.
- Suite setup (`update_task.bats:19-22`) redirects `TASKS_DIR` and `CONTEXT_DIR` into the fixture but exports `PROJECT_ROOT=$FRAMEWORK_ROOT` (live repo) — a candidate for the blocking interaction (e.g. a hook/lib path resolving against live state).
- The "13 ok, zero not-ok reads as healthy" observation feeds OBS-361's audit-line AC (completion check, not failure-absence check).

## OBS-366 — T-3179 commit allowance doesn't recognise `bin/fw git commit`

**Verdict: PROMOTE** — task: "commit-checkpoint allowance must match fw-prefixed spelling" (`workflow_type: build`). AC: under a work-completed (partial-complete) focus, both `git commit -m "T-X: …"` and `bin/fw git commit -m "T-X: …"` pass the gate, pinned by a test exercising both spellings.

- Verified unfixed in the current tree: the allowance routes through `is_commit_checkpoint_command` (`agents/context/check-active-task.sh:829-834`), whose clause matcher `_fw_is_git_commit_clause` (`agents/context/lib/safe-commands.sh`) anchors on `^git[[:space:]]+commit` only — `bin/fw git commit` / `fw git commit` can never set `found=1`, so the predicate returns 1 and the block fires.
- T-3221 (partial-complete, in `active/`) hardened the predicate to mention-vs-command matching and T-3245 (completed) made it quote-strip-aware — neither adds the fw-prefixed spelling (grepped T-3221's file: no "fw git" anywhere).
- The block message at `check-active-task.sh:872-875` still says "'git commit' IS allowed here" — the misleading-advice half of the OBS is also intact.

## OBS-371 — Ollama embed outage + false-green embed verification line in T-1719

**Verdict: DISMISS** — the actionable half (the false-green Verification line) is already fixed inside T-1719; the outage half was environmental and transient.

- T-1719 (`.tasks/active/T-1719-embeddings-strategy-v1--slice-1-post-wri.md`, still active as partial-complete) now carries a Verification line that POSTs a real input to `/api/embed` with a 30s timeout and asserts a non-empty embedding vector — the exact fix shape the OBS prescribes, and the line's own comment cites "OBS-371" as its origin.
- The old `/api/tags` substring check is gone from the Verification block (read in full today).
- Commit `88d3e1b62` records 7/7 verification green after the amendment, so the new probe has executed and passed — the server outage itself resolved.

## OBS-372 — close-gate self-reentry deadlock (P-011 verification mutates the task under close)

**Verdict: PROMOTE** — task: "close gate must fail fast on self-referential verification (keylock reentry)" (`workflow_type: build`). AC: a `fw task update T-X --status work-completed` whose Verification invokes `fw task update T-X` refuses or fails fast with a named error instead of deadlocking, pinned by test.

- The **instance** is fixed: commit `9e206889d` (2026-09-06) rewrote `tests/unit/t1719_happiness_signal.bats` to mutate a throwaway fixture task instead of T-1719 itself, and `88d3e1b62` confirms the close subsequently went through ("deadlock cleared").
- The **class** is not: `agents/task-create/update-task.sh:1511-1513` calls `keylock_acquire "$TASK_ID"` with no timeout argument — `lib/keylock.sh:63` documents that the no-timeout form blocks forever. Any future task whose Verification (or any child process) calls `fw task update <same-id>` reproduces the 3h+ silent hang; nothing detects reentry or scans verification lines for self-reference.
- `keylock_acquire` already supports a timeout parameter (`lib/keylock.sh:64`, T-1366), so one cheap fix leg exists in-tree; the OBS's other candidates (reentry env guard, self-reference scan of verification lines) are alternatives for the task to weigh.
- Per-suite fixes don't close this — 9e206889d protected exactly one suite.

---

## Summary table

| OBS | Verdict | One-liner |
|---|---|---|
| OBS-359 | PROMOTE | exact-count `-eq 2` still red at 3 correct sites; flip to `-ge` floor |
| OBS-360 | PROMOTE | post-move stale-task_file test still red, re-verified today |
| OBS-361 | PROMOTE | no scheduled tests/unit run; audit line names bare "suite" (audit.sh:2780) |
| OBS-362 | DISMISS | corrected by OBS-364 (orphan tree, not the suite); focus.yaml md5 stable across today's re-runs |
| OBS-363 | DISMISS | superseded by OBS-365's clean re-measurement of the same hang |
| OBS-364 | PROMOTE | no concurrent/orphan-bats guard exists; T-577 shape, unbuilt |
| OBS-365 | PROMOTE | full suite still times out (240s today); test 14 passes in isolation — sequence-dependent |
| OBS-366 | PROMOTE | `_fw_is_git_commit_clause` anchors `^git commit` only; fw spelling still blocked |
| OBS-371 | DISMISS | T-1719 Verification already probes /api/embed with real input (cites OBS-371 in-file) |
| OBS-372 | PROMOTE | instance fixed (9e206889d); keylock reentry class unguarded (update-task.sh:1512, blocking acquire) |
