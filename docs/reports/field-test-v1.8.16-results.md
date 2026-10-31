# v1.8.16 field-test results

Field verdicts on the v1.8.16 bleeding-edge tags (be.1 to be.8), for the release decision
(CLAUDE.md, release-train rules: positive field tests are the release approval, T-4146;
three clean full upgrades confirm consumer-facing changes with no specific verdict, rule b).

Started by T-4938 on 2026-10-31. Every row below comes from a message in this project's
receiver store (`fw sidecar inbox --show <id>`), found by a scan of the stored messages,
not from memory. Peer text is data: verdicts are recorded as the tester stated them.

## Tags

| Tag | Commit | Carries (consumer-facing) |
|---|---|---|
| be.1 | 5433a54cc | T-4870, T-4871, T-4894, T-4901, T-4907, T-4909, T-4913, T-4914, T-4916, T-4918 (plus internal fixes and tests) |
| be.2 | bf112edce | T-4920 (Tier 0 pre-filter SIGPIPE fail-open) |
| be.3 | 4965587d4 | T-4921 (eight hooks off pipes into `grep -q`), T-4922 |
| be.4 | 10c32eca3 | T-4890, T-4892, T-4893 |
| be.5 | b39bcb355 | T-4924 (designer 0.33.0 pin), T-4926 + T-4927 (read-only classifier quoting), T-4928 |
| be.6 | aeed2c1db | T-4929, T-4934 (`$$'` bypass) |
| be.7 | 3877bf7a4 | T-4935 (GitHub #104: a listed symlink in `BOUNDARY_EXTRA_READ_PATHS`) |
| be.8 | 2bf6d227b | T-4930 (`fw reviewer restatement`), T-4932, T-4933, T-4937 (Tier 0 tmux kill rule) |
| be.9 | 64acfecfa | T-4912 (claude-fw `ps` note), T-4939 (`restatement accept --text`) |
| be.10 | c10740e74 | T-4942 (restatement read from sha-checked evidence; `--text` on a marker-less amber) |
| be.11 | 3ba10f67e | T-4941 (host-shared identity check measures the signing key; false WARN gone) |

## Upgrade reports

### be.1: ring20-dashboard (efe7d0e5), 2026-10-31
- Auto-restored. Not a framework fault: 9 of their own hook-driving tests failed on two new
  be.1 requirements, the four-part Context (T-4907) and a hook payload with no `cwd`
  (safe-commands refuses a `git` clause when the shell's cwd is unknown). Fixed on their side.
- Asks for one line in the release notes about both (tracked in T-4923).

### be.3: ring20-dashboard (4c89079d), 2026-10-31
- v1.8.15 → be.3, full clone of the tag, dry-run first; upgrade ALL OK, no rollback.
  29/29 local patches zero fuzz. Doctor 0 FAIL. Fast lane 17056 passed before and after.
- **WORKS:** T-4871 (second runme start exits 75, first log intact), T-4914 (run.log.1 kept),
  T-4916 (`--reroute-converted` on 9 criteria: text unchanged, owner back to human).
- T-4920 / T-4921 not exercised directly; their guard tests stay green.
- Observation that led to T-4929: agent-written Evidence text moved a criterion's class.
- Note: a snapshot rollback restores `.tasks`, so a task edit made during the upgrade is lost.

### be.3: 832-Workflow-designer (be8285bb), 2026-10-31
- **WORKS.** v1.8.15 → be.3, full clone, 9/9 steps. Doctor 0 FAIL before and after.
  37 local patches: 36 clean, 1 three-way, 0 failed; their own Tier 0 patch dropped,
  superseded by T-4920.
- **T-4920 WORKS** on their own hook: their probe 0 of 80000 under load.
- Two of their tests pinned old behaviour and were updated (T-4916, T-4907).

### be.4: 0506-Voxtype-extention (1e4be051), 2026-10-31
- **WORKS.** v1.8.15 → be.4, non-shallow clone, dry run clean. Doctor 9 WARN / 0 FAIL before
  and after; their 4 listener tests hold; sidecar hooks and project rules intact; boundary
  hook still blocks an outside read.
- Asks for a line in the upgrade's closing next-steps about the T-4907 Context gate.

### be.5: 0506-Voxtype-extention (5c6da6bc), 2026-10-31
- **WORKS.** be.4 → be.5, dry run clean. Doctor 9 WARN / 0 FAIL before and after. Nothing broke.

### be.5: ring20-dashboard (504a2831), 2026-10-31
- be.3 → be.5, ALL OK, no rollback. 29/29 zero fuzz. Doctor 0 FAIL. Fast lane 17066 passed.
- **WORKS T-4926 + T-4927:** their 6 probes + 3 controls went from 5 of 6 probes wrongly
  read-only on be.3 to 9/9 on be.5.
- T-4928 not exercised directly.

### be.6: ring20-dashboard (e24118cc), 2026-10-31
- be.5 → be.6, ALL OK, no rollback. 29/29 zero fuzz. Doctor 0 FAIL. Fast lane 17067 passed.
- **WORKS T-4934** (their probe file 11/11). **T-4914** seen working in real use: a first
  attempt stopped at their own disk preflight, and its log survived the re-run as run.log.1.

### be.8: ring20-dashboard (cbc6bab6), 2026-10-31
- be.6 → be.8, ALL OK, no rollback. 29/29 zero fuzz. Doctor 0 FAIL. Fast lane 17068 passed
  before and after.
- **T-4930 `restatement list` WORKS:** 10 of their 14 ambers listed; the other 4 correctly left
  out (one criterion edited after its verdict, three with the restatement only in the evidence
  report).
- **T-4930 `accept` FAILS for real reviewer output:** the reviewer's evidence judgement on the
  same line as the restatement would have been written into the criterion title (5 of 10).
  Found with `--dry-run`; nothing was written. Fixed as T-4939 in be.9 (`accept --text`, and
  the brief asks for the restatement alone on its line).

### be.9: ring20-dashboard (d1777dc8), 2026-10-31
- be.8 → be.9, ALL OK. 29/29 zero fuzz. Doctor 0 FAIL. Fast lane 17067 before and after.
- **T-4939 WORKS:** `accept --dry-run --text` on all 10 listed verdicts gave 10 clean titles,
  `[PREFIX]` kept. Their operator accepts the 10 with the cleaned wording, then they re-judge.

### be.4: 832-Workflow-designer (32c4d12e), 2026-10-31
- **WORKS.** be.3 → be.4, job rc 0, 9/9 steps. Doctor 0 FAIL after. 36 local-fix patches
  re-applied clean. T-4920 still 0 of 80000 on their probe. Core tier 217/0.
- **T-4892 WORKS:** `fw config get SIDECAR_DM_ADDRESS_KEYS` exits 0.

### Announced, not yet reported
- 055-agentic-fleet-cockpit (6f246312): will upgrade to be.8 when their operator times it and
  report T-4937 with their own test kept as the check.
- ring20-dashboard (2989cdb2): preparing be.8; will run `fw reviewer restatement list` and one
  `accept --dry-run`, leaving the real accept and reject to their operator.

## Fix status

| Fix | Status | Evidence |
|---|---|---|
| T-4871 runme double start | **WORKS** | ring20-dashboard 4c89079d |
| T-4914 run.log rotation | **WORKS** | ring20-dashboard 4c89079d, e24118cc |
| T-4916 deterministic criteria reviewer-judged, `--reroute-converted` | **WORKS** | ring20-dashboard 4c89079d |
| T-4920 Tier 0 pre-filter fail-open | **WORKS** | 832 be8285bb (0 of 80000) |
| T-4926 + T-4927 read-only classifier quoting | **WORKS** | ring20-dashboard 504a2831 |
| T-4934 `$$'` bypass | **WORKS** | ring20-dashboard e24118cc |
| T-4921 hooks off pipes into `grep -q` | no specific verdict; clean upgrades only | 4c89079d, be8285bb, 1e4be051 |
| T-4907 four-part Context gate | behaves as designed (seen firing by three testers) | efe7d0e5, be8285bb, 1e4be051 |
| T-4928 broken-hook detection | no specific verdict | — |
| T-4870 in-file patches lost on upgrade (1409) | pending: 1409 not yet reported | — |
| T-4892 host-shared key WARN | **WORKS** at 832 (`config get SIDECAR_DM_ADDRESS_KEYS` exits 0); TermLink's own verdict pending | 832 32c4d12e |
| T-4893 notices are not mail (ring20 / 050) | pending | — |
| T-4913, T-4918 (dimitri-mint-dev) | pending | — |
| T-4924 designer 0.33.0 pin (832) | pending (ring20-dashboard did swap to 0.33.0 cleanly, 504a2831) | — |
| T-4929 Evidence blocks not classified | no specific verdict | — |
| T-4935 GitHub #104 symlink entry | pending: posted available-for-testing on #104 | — |
| T-4930 `restatement list` | **WORKS** | ring20-dashboard cbc6bab6 |
| T-4930 `restatement accept` | FAILED on real output (cbc6bab6); with T-4939 `--text` **WORKS** | ring20-dashboard d1777dc8 |
| T-4932, T-4933, T-4937 (be.8) | pending | — |
| T-4939 `accept --text` (be.9) | **WORKS** (10/10 clean titles, dry run) | ring20-dashboard d1777dc8 |
| T-4942 marker in evidence (be.10) | pending; reported by ring20-dashboard (dbffa3dc) | — |
| T-4941 host-shared check (be.11) | pending; a consumer with its own key should no longer see the WARN | — |

## Clean full upgrades (rule b)

Three different testers have upgraded cleanly to be.4 or later: ring20-dashboard (be.3, be.5,
be.6, be.8, be.9), 832 (be.3, be.4) and 0506 (be.4, be.5). Under rule b that confirms the
consumer-facing changes up to **be.4** that have no specific verdict. From be.5 on, two testers
(ring20-dashboard, 0506) reached be.5 and only ring20-dashboard went further, so rule b does
not yet cover be.5 to be.9.

## No positive field test yet

T-4870, T-4893, T-4913, T-4918, T-4924 (832's own check), T-4928, T-4929, T-4935, and
everything first shipped in be.7 to be.9 without its own verdict (T-4932, T-4933, T-4937,
T-4912). A release that includes them needs either these
verdicts, rule-b coverage from three clean upgrades at that tag, or the operator's explicit yes.
