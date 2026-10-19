# T-4375 — where the structure-section audit spends its time

## Method

- The timing ledger (T-3127/T-3451, `.context/audits/full-audit-timing.yaml`) records per-SECTION
  seconds only: structure = 545 s on 2026-10-19 20:44, against a 600 s scoped budget.
- Named check functions: `agents/audit/audit.sh --check <id>` (T-4209, takes no lock), timed one by one.
- Inline code: a live `--section structure` was held by other audits throughout, so the section ran on a
  `git clone --shared` of HEAD at `.context/scratch/t4375/repo` (gitignored), with xtrace on in the audit
  body only: `PS4='+${EPOCHREALTIME}|${#FUNCNAME[@]}|${LINENO}|${BASH_LINENO[*]}| '`, `BASH_XTRACEFD` to a
  file. The time between consecutive trace lines goes to the top-level statement (or the call site of
  the function) that was running. Then the same clone was run again with the changed files copied in.
- Host load 28 (before) and 38 (after) on 24 cores. Both runs are traced, so the absolute numbers are a
  little higher than an untraced run.

## Per check, before → after (same clone, same corpus)

| Check (audit.sh line) | Before | After | Change |
|---|---:|---:|---|
| `check_invariant_suite` = `bats tests/lint/` (3587) | 300 s, **truncated at its 300 s timeout: 39 of 141 tests ran** | 151 s, all 141 ran | see the two lint legs below |
| ↳ `bats-silent-skip.bats` "fw test lint actually reports a silent-skip section" | 182 s (file) | 23 s (file) | ShellCheck stubbed: the leg asserts wiring, not findings |
| ↳ `no-backticks-in-quoted-strings.bats` SC2006 over every bash source | 69 s | 70 s cold, 2 s warm | `tools/shellcheck-sc2006-cached.py`, keyed on (shellcheck version, path, bytes) |
| Human-AC ticks, `lib/human_ac_ticks.py audit` (3073) | 119 s (92 s standalone) | 9.6 s (9 s standalone) | one `diff-tree --stdin` + one `cat-file --batch` instead of ~6,500 forks |
| Stale-arc `git log --since` per in-progress arc (1756) | 61 s | 51 s | unchanged — proposed for the daily audit |
| BVP coherence python pass (~2005) | 47 s (40.7 s standalone) | 6.9 s (6.7 s standalone) | frontmatter parsed once; comment-only `arc_id` files not parsed for the index |
| `check_fabric_coverage` (2732) | 25 s | 21 s | unchanged |
| Watchtower decision revert (3103) | 16 s | 11 s | unchanged (memoizing ls-tree saved ~2 s; not kept) |
| **Section total** | **651 s** | **325 s** | load higher in the after run |

Remaining under 10 s each: register-requirements 9 s, fabric-underpopulated 5.5 s, delegation-surface
5.4 s, sidecar-ledger 3 s, and the rest ≤2 s.

Remaining slow lint files after the change: `bats-git-discovery-fence.bats` 23 s (two per-file grep
loops over every .bats file, each run twice), `bats-test-isolation.bats` 5 s.

## Verdicts

The PASS/WARN/FAIL lines of the two runs were diffed. The only differences come from copying the changed
files into the clone (one more source file, so a count is +1; the clone's vendored copy is out of sync),
plus the invariant suite now reporting 1 of **141** red where it used to report 1 of **39**, because it
used to be killed by its timeout. One new WARN ("Orphan-inbox check could not run") comes from T-4418's
check in the current audit.sh, which failed on hub reachability. It is not related to this change.

Equivalence checks, each against the unchanged code:
- `human_ac_ticks`: old and new `audit()` give identical results on the live repo. Batched diff-tree output
  matches the per-pair calls for all 1,554 (commit, parent) pairs, and 181 sampled blobs are byte-equal.
  The existing 44 tests in `t3695_human_ac_tick_bash.bats` and `t4075_*` pass (merge and rename cases included).
- BVP coherence: identical output on the live repo at four threshold settings, and identical findings on
  a fixture that produces them (quoted key, arc-NNN, comment-only arc_id, bad YAML).
- SC2006: same lines for the same files. A cache hit skips shellcheck. A changed file is a miss. A
  shellcheck exit other than 0 or 1 is never cached.

## Proposals (not done)

1. Move the stale-arc check (and draft-arc-complete, fabric coverage, and Watchtower decision revert) to
   the daily audit. They report properties of the calendar and corpus, not of the commit being pushed.
2. Per-check seconds in the T-3127 ledger, so the next slowdown can be pinned to a check without an xtrace run.
3. Batch `bats-git-discovery-fence.bats`'s per-file grep loop (23 s).
4. T-4425: `fw test lint` exits 141 (SIGPIPE) in its ShellCheck loop before the Silent-Skip step runs.
