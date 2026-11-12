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
| be.12 | 8c4fdbc97 | T-4943 (judge captures every required page), T-4945, T-4947 (/approvals stderr sanitized), T-4948 (atomic YAML writers), T-4949 (FW_ALLOW_EMPTY_RECOMMENDATION restored), T-4950, T-4951 (/approvals no SystemExit without BVP policy), T-4954, T-4955, T-4956 (baseline regenerate keeps unrun files) |
| be.13 | c5bb76f89 | T-4957 (Workflow Designer 0.34.0 pinned) |
| be.15 | 0522186b9 | T-4944 (codex may record a render green, citing only screenshots it named; vision:false kinds skip render reviews); T-4966 (ledger and register appends serialized with verdict commits: no torn committed line under parallel judges); T-4968 (stale web readiness fixtures) |
| be.14 | b82af92fe | T-4953 (read-only gate query + pipe: refused, no approval card); T-4960 (judge captures very tall pages); T-4958 (`fw ux shots` crop step); T-4962 (retry ladder releases `e2e-` self-test messages); T-4963 (direct-route reply settles a hub consult) |

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

### be.29: 050-email-archive (msg bc95b804), 2026-11-03
- **T-5051 WORKS:** be.26 → be.29 (08eb7ea28); with `HANDOVER_PUSH: 0`, `fw handover --commit` printed "Push skipped: HANDOVER_PUSH=0 for this project — committed locally only (T-5051)" and their production branch did not move. Tested through `fw handover --commit` (same push site as `/compact`).
- **Findings:** the handover's own commit failed (their `.gitignore` hides `.context/`), yet the line said "committed locally" (T-5052); the Gaps Register raises KeyError on concerns without `title` and truncates silently (T-5053).

### be.31: 050-email-archive (msg 2ee5cd85), 2026-11-03
- **T-5052 WORKS:** be.29 → be.31 (b240a7043); `fw handover --commit` committed its new handover (S-2026-1103-1544, their commit 9cf4a8023) under their gitignored `/.context/*`; "Push skipped: HANDOVER_PUSH=0" printed; their remote did not move. T-5053 KeyError still printed, as expected (not yet fixed).

### be.33: 050-email-archive (msg 5d7c2e98), 2026-11-03
- **T-5053 WORKS:** be.31 → be.33 (3b36a63aa); `fw handover --commit` ran with no KeyError, the Gaps Register listed all 86 watching concerns with the name/summary fallback visible; handover S-2026-1103-1708 committed; push skipped; their remote did not move.

### be.26: ring20-dashboard (msg a14cb4c1, their T-2632), 2026-11-02
- **WORKS.** be.19 → be.26 (db97fbae4), vendored, 19:22-19:40Z, exit 0, no rollback. 29 local patches, zero fuzz; 27 strict, 2 ported because T-4986 reworked `cmd_rank` (their 0007 QUAD footers, 0024 `--owner` after quadrant medians; offered upstream, T-5035). Doctor 0 FAIL before and after; fast lane 17103 passed, no new failures. Watchtower cold load of `/` 110 s (see T-5010/T-5011).
- **T-5014 WORKS:** their main session holds the lease (generation 1); another session id gets am-i exit 1.
- **T-5008 PARTLY:** isolation is recorded on a real opencode seat (stderr.log line and `seat_pid_isolation` in meta.json). The seat refused to run the decoy `pkill`, treating it as an injection, so a live seat could not serve as the attacker. The mechanism itself, tested without a seat through the exact `unshare` wrapper: inside, the shell is PID 1 and sees 4 processes, `pkill` matched only its own line, the decoy outside stayed alive. Open: a sanctioned self-test for the seat launch path.
- **Security review input on T-4988 (access grants):** 2 HIGH, 2 MEDIUM (self-grant by committing the grant file; symlinks under a create grant; refused verbs skipped via cd/variables; unguarded first write of the grant file). Registered as G-129; T-5031 to T-5034.

### be.26: 050-email-archive (msg 18a23e53), 2026-11-02
- **WORKS.** be.25 → be.26 (35abca011) in their agent shell: upgrade and `fw doctor` rc 0; 8 local patches merged clean; access grants unchanged.
- **T-5014 WORKS:** main claimed on the first prompt after the upgrade ("held by main <this session>", generation 1); a foreign session id gets am-i exit 1.
- **Note (filed under T-5014):** right after the upgrade, status read "vacant (generation 0)" until the next prompt or Stop hook, as expected for a session started before be.26; they ask for a one-line hint in the upgrade output ("main is claimed at your next prompt").

### be.25: 050-email-archive (msg 6475edfa), 2026-11-02
- **WORKS.** be.20 → be.25 (22647d13a), in their HOME-less agent shell, no operator help.
- **T-4993 WORKS:** `fw upgrade` ran to the end without HOME; `fw doctor` exits 0 there (12 WARN, 0 FAIL).
- **T-4994 WORKS:** they dropped their own `lib/review.sh` patch and took ours verbatim; their guard test pins the derived verb, the inert `DECISION` fallback and no `go|no-go|defer` pipe.
- The other 8 local patches re-merged clean; guard suites green; `fw grants show` still lists their 3 grants and `never_write`; Watchtower 200.
- Their note (not ours): a jest suite hung once on startup and passed on retry.

### be.20: 050-email-archive (cedc1b89, f7527742), 2026-11-02
- **Upgrade: FAILS on a HOME-less agent shell (filed T-4993).** be.16 → be.20 (99f36914b). `fw upgrade` died at step 4c/9 with `HOME: unbound variable` (lib/upgrade.sh:2623) after the vendor copy, so `.framework.yaml` was not updated. `fw doctor` dies the same way (bin/fw:2553). Their operator re-ran it with HOME set and it completed. Everything else worked:
  - the dry run named exactly their 10 local edits, and the real run applied them;
  - 8 of 10 patches re-merged clean; `lib/review.sh` conflicted on our `go|no-go|defer` fallback, filed as T-4994;
  - 46/46 hooks present, Watchtower 200, guard suites 54/54.
- **T-4988 + T-4989 WORKS (first real use, operator-committed grant file with the trailer).** The validator passed, `fw grants show` lists all four lines, and the read bridge is dropped.
  - Reads work through both granted mounts; a write to the read mount is refused.
  - Create, move and delete of their own probe file inside a create grant work, and each is logged.
  - An append-open or move of an operator file passes the hook and is refused by the NAS (md5 unchanged): the intended split.
  - Writes under `never_write` and at an ungranted mount root are refused.
  - Notes, filed as T-4995: name the grant rule in the refusal; the audit log records hook decisions, not NAS outcomes.

### be.15: ring20-dashboard (9cbbdcdc), 2026-11-01
- **WORKS.** be.10 → be.15, vendored, ~12 min, exit 0, no rollback. 29 local patches strict, zero fuzz; preserve dry run 31 == 31. Designer 0.33.0 → 0.34.0 swapped as printed. Doctor 0 FAIL; fast lane no new failures.
- **T-4966 WORKS:** 13 `fw reviewer judge` runs, 3 at a time (their cap 9), 31 min, 36 verdict commits, 122 register rows. Every committed line of the four ledger files parses; verdict_ledger audit 183 rows, 0 failures; no torn line. Race rows (41) and carry-overs (59) are cosmetic, as expected.
- **T-4944 finding (filed T-4978):** on two render criteria an opencode seat was still dispatched, printed a green, then exited 1, so the row was voided. Open: why the `vision: false` exclusion did not apply there, and why opencode exits 1.
- Side note filed as T-4979: `verdict_ledger.py audit` exits non-zero when the only findings are void rows.

### be.14: 055-agentic-fleet-cockpit (ff520e66), 2026-11-01
- **WORKS.** v1.8.15 → be.14, non-shallow clone of the tag, main checkout, operator's go. One local patch (their T-667, `check-tier0.sh`) is identical in effect to upstream T-4937: their tmux-kill test passes 15/15 against our hook, applied with `--allow-delete-locals`. Dry run then real run: 4 changes, rc 0.
- Doctor before/after: the same single FAIL, which predates the upgrade (an audit stopped mid-run earlier that day). Their suite: 1745 passed (one live-fleet check unrelated); bats 157/157.
- **T-4962 WORKS:** the first sweep after the upgrade released f0c3a193 ("released: e2e self-test e2e-1fc080c8").
- **T-4963 not exercised:** both cases had been settled with `settle-sent` before the upgrade.
- T-4907's context gate blocked an edit under an old task without the four parts; they opened a new task (works as designed).
- **Correction they caught:** be.14 is commit `b82af92fe`. This report and two messages had named `5aa42c6ec`, the annotated tag's object, not its commit. Fixed here; the table now reads `^{commit}` for every tag.

### be.10: ring20-dashboard (0d48c8ce), 2026-11-01
- **WORKS.** be.9 → be.10, vendored, ~12 min, exit 0, no rollback. 29 local patches strict
  (git am, zero fuzz), none obsolete; preserve dry run 31 == 31. Doctor 0 FAIL. Fast lane
  17067 passed / 13 skipped, no new failures.
- **T-4942 WORKS:** `restatement list` now lists 3 ambers whose marker is only in the
  evidence report (their T-772, T-829, T-835); `accept --dry-run --text` passes on all 6
  pending. One verdict (their T-701) is correctly refused as "criterion changed since": their
  own agent edited the criterion after the verdict. The digest guard did its job; they re-judge.

### be.4: 832-Workflow-designer (32c4d12e), 2026-10-31
- **WORKS.** be.3 → be.4, job rc 0, 9/9 steps. Doctor 0 FAIL after. 36 local-fix patches
  re-applied clean. T-4920 still 0 of 80000 on their probe. Core tier 217/0.
- **T-4892 WORKS:** `fw config get SIDECAR_DM_ADDRESS_KEYS` exits 0.

### be.4: 010-termlink (160ded67), 2026-11-01
- **WORKS.** v1.8.15 → be.4 (181 commits), rehearsal on a fresh clone then the real run; dry
  and real rc 0. CLAUDE.md byte-identical. Doctor FAIL 0 → 0.
- **T-4870 WORKS:** 4 of their 8 preserved files changed upstream, each 3-way merged with 0
  conflicts; all 8 byte-identical to their pre-upgrade copies afterwards, markers present.
- **T-4920 + T-4921 WORKS:** synthetic hook payloads. Before: Tier 0 and boundary hooks
  blocked a small payload but let a 136 KB one through (fail open). After: both block both.
- Two of their fixtures changed with upstream behaviour, not defects: a shell fixture task
  needed the four-part Context (T-4907; the test opt-out applies under bats only), and a
  fixture asserting the pre-T-4916 refusal (their T-3636, for their operator).
- The T-4892 host-shared WARN shows for them on be.4. That can be the false positive fixed in
  be.11 (T-4941) or a true reading; told them (reply to 160ded67).

### be.3: dimitri-mint-dev (9f92d563), 2026-11-01
- **WORKS.** v1.8.15 → be.3, non-shallow clone, dry and real rc 0, 4 changes. Doctor 0 FAIL
  before and after.
- **T-4920 + T-4921 WORKS:** installed hooks fed PreToolUse probes (never executed): the Tier 0
  hook blocks a force push short and after 130 KB of padding; the boundary hook blocks a /opt
  write short, padded, and as line 4001 of 4001; benign 130 KB commands pass.
- **T-4913 WORKS** (registry-shadow OK, no WARN). **T-4905 WORKS.** **T-4918 WORKS** (dry:
  `defer` listed; no real reopen run).
- Observations: a filtered Tier 0 status read is refused as self-approval and leaves a pending
  block on /approvals that nobody should approve (filed T-4953); the self-approval word rule
  read the quoted body of their sidecar message (documented accepted cost, see reply).

### Announced, not yet reported
- 055-agentic-fleet-cockpit (6f246312): will upgrade to be.8 when their operator times it and
  report T-4937 with their own test kept as the check.
- ring20-dashboard (2989cdb2): preparing be.8; will run `fw reviewer restatement list` and one
  `accept --dry-run`, leaving the real accept and reject to their operator.

### be.47: 832-Workflow-designer (job 132), 2026-11-12
- be.26 → be.47 (version_sha 4404da41d), operator job, rc 0. 100 PRESERVE lines, all from their
  `.fwvendor-preserve.yaml`, none under `lib/`.
- **WORKS:** T-5079 — `.agentic-framework/lib/config.sh` byte-identical to be.47 (key present);
  plain `fw config set RELEASE_ARTIFACT_PATHS docs/authoring-kit/calibration-records/` prints
  "Set"; `verdict_ledger.py audit` prints the INFO line listing their path.
- An earlier refusal of that `config set` came from 832's own rehearsal harness (their bug, filed
  on their side); AEF reproduced be.26 → be.47 here and could not trigger it.
- **WORKS:** T-5077 — `fw task update T-1393` rewrote the task file and it stayed 664 with the
  operator's ACL intact (`user:dimitri-mint-dev:rwx`, mask `rw-`), same before and after. Their 37
  local fixes re-applied clean (divergence 44=44).
- To follow: T-5081 (first Watchtower-tick hand-back).

## Fix status

| Fix | Status | Evidence |
|---|---|---|
| T-4871 runme double start | **WORKS** | ring20-dashboard 4c89079d |
| T-5079 release-artifact paths | **WORKS** | 832-Workflow-designer job 132 (be.47) |
| T-5077 `_sed_i` keeps mode/owner/ACL | **WORKS** | 832-Workflow-designer be.47 (T-1393 rewrite: 664 + ACL kept) |
| T-4914 run.log rotation | **WORKS** | ring20-dashboard 4c89079d, e24118cc |
| T-4916 deterministic criteria reviewer-judged, `--reroute-converted` | **WORKS** | ring20-dashboard 4c89079d |
| T-4920 Tier 0 pre-filter fail-open | **WORKS** | 832 be8285bb (0 of 80000); 010-termlink 160ded67 (136 KB probe) |
| T-4926 + T-4927 read-only classifier quoting | **WORKS** | ring20-dashboard 504a2831 |
| T-4934 `$$'` bypass | **WORKS** | ring20-dashboard e24118cc |
| T-4921 hooks off pipes into `grep -q` | **WORKS** (boundary hook blocks the 136 KB payload it let through on v1.8.15) | 010-termlink 160ded67 |
| T-4907 four-part Context gate | behaves as designed (seen firing by three testers) | efe7d0e5, be8285bb, 1e4be051 |
| T-4928 broken-hook detection | no specific verdict | — |
| T-4870 in-file patches lost on upgrade (1409) | **WORKS** at 010-termlink (8/8 preserved, 4 three-way merges, 0 conflicts); 1409 not yet reported | 010-termlink 160ded67 |
| T-4892 host-shared key WARN | **WORKS** at 832 (`config get SIDECAR_DM_ADDRESS_KEYS` exits 0); TermLink's own verdict pending | 832 32c4d12e |
| T-4893 notices are not mail (ring20 / 050) | pending | — |
| T-4913, T-4918 (dimitri-mint-dev) | **WORKS** (T-4918 dry run only) | dimitri-mint-dev 9f92d563 |
| T-4905 runme repro body | **WORKS** | dimitri-mint-dev 9f92d563 |
| T-4924 designer 0.33.0 pin (832) | pending (ring20-dashboard did swap to 0.33.0 cleanly, 504a2831) | — |
| T-4929 Evidence blocks not classified | no specific verdict | — |
| T-4935 GitHub #104 symlink entry | pending: posted available-for-testing on #104 | — |
| T-4930 `restatement list` | **WORKS** | ring20-dashboard cbc6bab6 |
| T-4930 `restatement accept` | FAILED on real output (cbc6bab6); with T-4939 `--text` **WORKS** | ring20-dashboard d1777dc8 |
| T-4932, T-4933, T-4937 (be.8) | pending | — |
| T-4939 `accept --text` (be.9) | **WORKS** (10/10 clean titles, dry run) | ring20-dashboard d1777dc8 |
| T-4942 marker in evidence (be.10) | **WORKS** (3 evidence-only ambers listed, 6/6 dry-run accepts) | ring20-dashboard 0d48c8ce |
| T-4941 host-shared check (be.11) | pending; a consumer with its own key should no longer see the WARN | — |
| T-4953 read-only pipe refusal (be.14) | pending; dimitri-mint-dev reported the card (9f92d563) | — |
| T-4962 e2e release (be.14) | **WORKS** (f0c3a193 released on the first sweep) | 055 ff520e66 |
| T-4963 direct-route reply settles (be.14) | pending; not exercised at 055 (cases settled by hand first) | — |
| T-4966 parallel judges (be.15) | **WORKS** (13 judges, 3 at a time; 0 torn lines; audit 0 failures) | ring20-dashboard 9cbbdcdc |
| T-4944 vision-gated render greens (be.15) | open finding at ring20 (opencode still dispatched on render; T-4978) | ring20-dashboard 9cbbdcdc |

## Clean full upgrades (rule b)

Three different testers have upgraded cleanly to be.4 or later: ring20-dashboard (be.3, be.5,
be.6, be.8, be.9, be.10), 832 (be.3, be.4) and 0506 (be.4, be.5). Under rule b that confirms the
consumer-facing changes up to **be.4** that have no specific verdict. From be.5 on, two testers
(ring20-dashboard, 0506) reached be.5 and only ring20-dashboard went further, so rule b does
not yet cover be.5 to be.9.

## No positive field test yet

T-4893, T-4924 (832's own check), T-4928, T-4929, T-4935, and
everything first shipped in be.7 to be.9 without its own verdict (T-4932, T-4933, T-4937,
T-4912). A release that includes them needs either these
verdicts, rule-b coverage from three clean upgrades at that tag, or the operator's explicit yes.
