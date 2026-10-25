# Field-test results — v1.8.15 (bleeding-edge broad release, be.1 … be.17)

Field evidence for the fixes that ride v1.8.15: everything committed after the v1.8.14 tag (2328ae76b, 2026-10-20)
up to HEAD eee888e61 (be.17 is 165039bb4). Under T-4146 a fix is released without asking when it has a positive field
test from another project, recorded here. Task: T-4739.

**Sources.** Peer messages stored under `.context/sidecar/receiver/messages` since 2026-10-20, read as data:
conversation `aef-v1815-be3` (be.3 … be.16 reports) plus `aef-v1814-release`, `aef-v1814-readonly-bypasses`,
`arc-009-readiness` and `sev1-tmux-env-leak-2026-10-22` (be.1 … be.3 reports). Cross-checked against
`field-test-v1.8.14-results.md` and the handovers S-2026-1020-1816, S-2026-1020-1925 and S-2026-1023-1954: nothing
there is missing here. Fixes reported in the v1.8.14 report (T-4426, T-4350, T-4453, T-4115, T-4485, T-4421,
T-4399, T-3924) shipped in v1.8.14 and are not counted again. T-4222 also shipped in v1.8.14; 050's be.3 re-test of it
is listed but not counted.

**No verdict has arrived for be.17 yet.** 010-termlink (6b3bce86) and 055 (cd0b5820) have announced be.17 upgrades.
*(Round 1, 2026-10-24. Round 2, 2026-10-25: two be.17 reports have arrived since, from ring20-mgmt (70e4bd0b) and
010-termlink (b283259c). See §be.17 and the round-2 subsections below.)*

## Summary

- 80 v1.8.15 fixes have at least one peer verdict (81 rows below, minus T-4222). 73 of them are among the 359 task ids
  whose commits since v1.8.14 touch vendored paths. The other 7 touch only paths outside that list (T-4655, T-4659,
  T-4671, T-4677, T-4686, T-4705, T-4710).
- 15 fixes drew a FAILS, PARTIAL, inconclusive or finding verdict. Each one produced a follow-up task (table below).
  Every follow-up chain ends in a WORKS, except two follow-ups with no field verdict of their own: T-4552 and T-4639.
- **286 of the 359 vendored-path task ids have no field verdict** (Appendix A).
- Suite comparison (targeted, see below): 10 files are red at HEAD and not at v1.8.14. Eight of them come from 6
  release-diff causes, each now filed as its own task (T-4743 … T-4748). Two are environmental.
- `fw release tag-and-release --dry-run`: rc 0, fast-forward available. No release decision is recorded for v1.8.15.
- **Round 2 (2026-10-25, HEAD d085cb3d4).** T-4744 … T-4748 are fixed and their reds are green at HEAD. The only
  release-diff red left is T-4743 (operator-gated), plus 2 environmental reds. be.17 brought verdicts for T-4720
  (WORKS / PARTIAL → T-4740) and T-4726 (WORKS), so 82 fixes now have a verdict. At HEAD, **302 of 377** vendored-path
  task ids have no field verdict. The dry-run is still rc 0 and would fast-forward master by 1320 commits.

| Fix | Projects | Tip(s) tested | Verdict | Msg ids | Follow-up |
|---|---|---|---|---|---|
| T-4222 | 050 | be.3 | **WORKS** | 5b5b40e9 | — |
| T-4227 | 010-termlink | be.3 | **WORKS** | 6829fbaa | T-4667 |
| T-4235 | dimitri-mint-dev | be.3 | **WORKS** | 2412ba7c | — |
| T-4479 | 010-termlink | be.3 | **WORKS** | 6829fbaa | — |
| T-4499 | dimitri-mint-dev | be.2 | **WORKS** | 5c5a8309 | — |
| T-4509 | ring20-dashboard | be.2 | **WORKS** | ca94e1b8 | — |
| T-4510 | ring20-dashboard | be.2 | **WORKS** | ca94e1b8 | — |
| T-4511 | ring20-dashboard | be.2 | **WORKS** | ca94e1b8 | — |
| T-4512 | ring20-dashboard | be.2 | **WORKS** | ca94e1b8 | — |
| T-4513 | ring20-dashboard | be.2 | **WORKS** | ca94e1b8 | — |
| T-4515 | dimitri-mint-dev, ring20-mgmt | be.2 | **WORKS** / PARTIAL | 5c5a8309, f506e892 | T-4552 |
| T-4529 | dimitri-mint-dev | be.2 | **WORKS** | 5c5a8309 | — |
| T-4554 | dimitri-mint-dev | be.3 | **WORKS** | 2412ba7c | — |
| T-4555 | dimitri-mint-dev | be.3 | **WORKS** | 2412ba7c | — |
| T-4568 | 010-termlink, dimitri-mint-dev, ring20-mgmt | be.4 | **WORKS** ×2 / PARTIAL | abd75be9, dcb718d1, 4aade009 | T-4678 |
| T-4626 | dimitri-mint-dev, ring20-dashboard | be.3 | **WORKS** / PARTIAL | 2412ba7c, 7f3be352 | T-4650 |
| T-4627 | ring20-dashboard | be.3 | **WORKS** | 7f3be352 | — |
| T-4628 | ring20-dashboard | be.3 | **WORKS** | 7f3be352 | — |
| T-4629 | ring20-dashboard | be.3 | **WORKS** | 7f3be352 | — |
| T-4630 | ring20-dashboard | be.3 | **WORKS** | 7f3be352 | — |
| T-4631 | ring20-dashboard | be.3 | PARTIAL | 7f3be352 | T-4639 |
| T-4636 | 010-termlink | be.3 | **WORKS** | 6829fbaa | — |
| T-4647 | 010-termlink, 832 | be.3 | **WORKS** ×2 | 6829fbaa, 023c051c | T-4665, T-4666 |
| T-4650 | 010-termlink, dimitri-mint-dev, ring20-mgmt | be.4 | **WORKS** ×3 | abd75be9, dcb718d1, 4aade009 | — |
| T-4652 | 010-termlink, dimitri-mint-dev, ring20-mgmt | be.4 | **WORKS** ×3 | abd75be9, dcb718d1, 4aade009 | — |
| T-4653 | ring20-mgmt | be.4 | **WORKS** | 4aade009 | — |
| T-4654 | ring20-mgmt | be.5 | **WORKS** | 42ae6cd4 | — |
| T-4655 | ring20-mgmt, 832, dimitri-mint-dev | be.5, be.9 | **WORKS** ×3 | 42ae6cd4, 5b73054a, 3294edcf | — |
| T-4656 | ring20-mgmt | be.5 | **WORKS** | 42ae6cd4 | — |
| T-4657 | ring20-mgmt | be.5 | **WORKS** | 42ae6cd4 | — |
| T-4658 | ring20-mgmt | be.5 | **WORKS** | 42ae6cd4 | — |
| T-4659 | ring20-mgmt | be.4 | **WORKS** | 4aade009 | — |
| T-4661 | ring20-mgmt | be.5 | **WORKS** | 42ae6cd4 | — |
| T-4662 | ring20-mgmt, 050 | be.5, be.6 | **WORKS** / PARTIAL | 42ae6cd4, e0b8f7ac | T-4687 |
| T-4665 | 010-termlink, ring20-mgmt | be.4 | **WORKS** ×2 | abd75be9, 4aade009 | — |
| T-4666 | 010-termlink, ring20-mgmt | be.4 | **WORKS** ×2 | abd75be9, 4aade009 | — |
| T-4667 | ring20-mgmt, 010-termlink, 050, 832 | be.5, be.6 | **WORKS** ×4 | 42ae6cd4, 4d03fd26, e0b8f7ac, 5b73054a | — |
| T-4670 | ring20-mgmt, 010-termlink, 050 | be.5, be.6 | **WORKS** ×2 / PARTIAL | 42ae6cd4, 4d03fd26, e0b8f7ac | T-4685 |
| T-4671 | ring20-mgmt | be.5 | **WORKS** | 42ae6cd4 | — |
| T-4672 | ring20-mgmt, 050, 832 | be.5, be.6 | **WORKS** ×2 / INCONCLUSIVE | 42ae6cd4, e0b8f7ac, 5b73054a | — |
| T-4673 | 010-termlink | be.5 | **WORKS** | 4d03fd26 | — |
| T-4675 | ring20-mgmt, 832 | be.5 | **WORKS** / FAILS | 742ba198, 5b73054a, 81cb0bca | T-4683, T-4684 |
| T-4677 | ring20-mgmt, 832 | be.6, be.8 | **WORKS** ×2 | 55d683dc, 5b73054a | — |
| T-4678 | ring20-mgmt, 832 | be.5 | **WORKS** ×2 | 42ae6cd4, 5b73054a | — |
| T-4679 | ring20-mgmt | be.6 | **WORKS** | 55d683dc | — |
| T-4680 | ring20-mgmt | be.6 | **WORKS** | 55d683dc | — |
| T-4681 | ring20-mgmt | be.6 | **WORKS** | 55d683dc | — |
| T-4682 | ring20-mgmt | be.6 | **WORKS** | 55d683dc | — |
| T-4683 | ring20-mgmt, 010-termlink, 832 | be.6, be.8 | **WORKS** ×3 | 55d683dc, 150d6e99, 5b73054a | — |
| T-4684 | ring20-mgmt, 050, 010-termlink, 832, dimitri-mint-dev | be.7, be.8, be.9 | **WORKS** ×5 | 2b81655f, 7aed1e10, 24f926ce, 5b73054a, 3294edcf | T-4692 |
| T-4685 | ring20-mgmt, 050, 010-termlink | be.7 | **WORKS** ×3 | 2b81655f, 7aed1e10, 24f926ce | — |
| T-4686 | ring20-mgmt | be.7 | **WORKS** | 2b81655f | — |
| T-4687 | ring20-mgmt, 050 | be.7 | **WORKS** ×2 | 2b81655f, 7aed1e10 | — |
| T-4688 | ring20-mgmt, dimitri-mint-dev, 050 | be.8, be.9 | **WORKS** ×2 / PARTIAL | 8ce4401e, 3294edcf, ac57ecb6 | T-4695 |
| T-4689 | ring20-mgmt, dimitri-mint-dev, 010-termlink | be.9, be.10 | **WORKS** ×3 | ff56edf4, 3294edcf, c896df19 | — |
| T-4690 | ring20-mgmt, dimitri-mint-dev, 010-termlink | be.9, be.10 | **WORKS** ×3 | 714c296e, 1882d747, c896df19 | T-4698 (side finding: deferral gate) |
| T-4691 | ring20-mgmt, 050, dimitri-mint-dev | be.9 | **WORKS** ×3 | ff56edf4, ac57ecb6, 3294edcf | — |
| T-4692 | ring20-mgmt, 050, dimitri-mint-dev, 010-termlink | be.9, be.10 | **WORKS** / PARTIAL ×2 / FAILS | ff56edf4, ac57ecb6, 3294edcf, c896df19 | T-4697, T-4704, T-4705 |
| T-4693 | ring20-mgmt, dimitri-mint-dev | be.9 | **WORKS** ×2 | ff56edf4, 3294edcf | — |
| T-4694 | ring20-mgmt, dimitri-mint-dev, 010-termlink | be.9, be.10 | **WORKS** ×3 | 714c296e, 1882d747, c896df19 | — |
| T-4695 | 050 | be.10 | **WORKS** | 8f195e9c | — |
| T-4697 | ring20-mgmt, 050, 010-termlink, dimitri-mint-dev | be.10 | **WORKS** ×3 / FAILS | 0fa89c60, 8f195e9c, c896df19, 6b2373ac | T-4705 |
| T-4699 | ring20-mgmt, 010-termlink | be.10 | **WORKS** ×2 | 0fa89c60, c896df19 | — |
| T-4700 | ring20-mgmt, 010-termlink | be.10 | **WORKS** ×2 | 0fa89c60, c896df19 | — |
| T-4703 | ring20-mgmt, dimitri-mint-dev | be.12, be.14 | **WORKS** ×2 | 36943a12, 6a934c08 | — |
| T-4704 | ring20-mgmt, dimitri-mint-dev, 010-termlink | be.11 | **WORKS** ×3 | 2ce6a48a, b410de74, e20d045f | — |
| T-4705 | ring20-mgmt, dimitri-mint-dev | be.11 | **WORKS** / PARTIAL | 2ce6a48a, b410de74 | T-4712 |
| T-4706 | dimitri-mint-dev, ring20-mgmt, 010-termlink, 050 | be.11, be.15 | **WORKS** ×2 / PARTIAL / FINDING | b410de74, 2ce6a48a, e20d045f, 5fdbef7c | T-4711 |
| T-4707 | ring20-mgmt, dimitri-mint-dev, 010-termlink, 050 | be.11, be.14, be.16 | **WORKS** ×4 | ab31dde8, 740b4ada, 9c448cb6, abf6d155 | T-4719, T-4738 (push clause opt-out) |
| T-4708 | ring20-mgmt, 010-termlink, 050 | be.11, be.15 | **WORKS** ×3 | 2ce6a48a, e20d045f, 5fdbef7c | — |
| T-4710 | ring20-mgmt, dimitri-mint-dev, 050 | be.12, be.14, be.16 | **WORKS** ×3 | 82ef34f0, 50f01abf, abf6d155 | — |
| T-4711 | ring20-mgmt, dimitri-mint-dev, 010-termlink | be.14 | **WORKS** ×3 | c12cbb7a, 6a934c08, 9c448cb6 | — |
| T-4712 | ring20-mgmt, dimitri-mint-dev | be.12, be.14 | **WORKS** / FAILS | 36943a12, 6a934c08 | T-4717 |
| T-4714 | ring20-mgmt | be.13 | **WORKS** | a3d7da1d | — |
| T-4716 | ring20-mgmt, dimitri-mint-dev | be.15 | **WORKS** ×2 | e9ef88ee, 9bb3a50a | — |
| T-4717 | ring20-mgmt, 050, dimitri-mint-dev | be.15 | **WORKS** ×2 / PARTIAL | e9ef88ee, 5fdbef7c, 9bb3a50a | T-4723, T-4724 |
| T-4718 | ring20-mgmt, dimitri-mint-dev | be.15 | **WORKS** ×2 | e9ef88ee, 9bb3a50a | — |
| T-4720 | 010-termlink, ring20-mgmt | be.17 | **WORKS** / PARTIAL | b283259c, 70e4bd0b | T-4740 (round 2) |
| T-4723 | dimitri-mint-dev | be.16 | **WORKS** | afb8ec6b | — |
| T-4724 | 050, ring20-mgmt, dimitri-mint-dev | be.16 | **WORKS** ×3 | 8fe2eab0, ab21bdd5, afb8ec6b | — |
| T-4726 | 010-termlink | be.17 | **WORKS** | b283259c | T-4741 (side finding, round 2) |
| T-4732 | 050, ring20-mgmt, dimitri-mint-dev, 010-termlink | be.16, be.17 | **WORKS** ×4 | 8fe2eab0, ab21bdd5, afb8ec6b, b283259c | T-4736 |
| T-4733 | 050 | be.16 | **WORKS** | 8fe2eab0 | — |

Tips: be.1 120a67833 · be.2 afe974124 · be.3 2ec39ef8e · be.4 b19757443 · be.5 fea3e4c76 · be.6 797875a32 ·
be.7 ce8075dba · be.8 04dc39868 · be.9 e9fb67bc9 · be.10 e82e3d9a7 · be.11 42086fee3 · be.12 4f906e6a3 ·
be.13 c9ec9459e · be.14 965dbcdc5 · be.15 31afaf383 · be.16 ae71b4f0c · be.17 165039bb4. "(bats)" / "(pytest)" in a section means the
peer ran our tests in their tree rather than exercising the fix live.

## FAILS, PARTIAL and ambiguous verdicts and their follow-ups

| Fix | Verdict (project, msg) | Follow-up | Follow-up field result |
|---|---|---|---|
| T-4515 | PARTIAL: G-122 counts old framework hook fragments as project lines (dimitri-mint-dev, 5c5a8309) | T-4552 | **no verdict** |
| T-4568 | PARTIAL: an old non-stock hook with a project block was refused (ring20-mgmt, 4aade009) | T-4678 | WORKS (ring20-mgmt, 832) |
| T-4626 | PARTIAL: `sed -n Np` with a glob FILE operand over-blocked (dimitri-mint-dev, 2412ba7c) | T-4650 | WORKS (010-termlink, dimitri-mint-dev, ring20-mgmt) |
| T-4631 | PARTIAL: `--ext-diff`/`--textconv` still SAFE (ring20-dashboard, 7f3be352) | T-4639 (closes the .git/config write path instead) | **no verdict** |
| T-4662 | PARTIAL: `_FW_PAYLOAD_CWD` alone still refused (050, e0b8f7ac) | T-4687 | WORKS (ring20-mgmt, 050) |
| T-4670 | PARTIAL: an inherited override without its sentinel is still honoured (010-termlink, 4d03fd26) | T-4685 | WORKS (ring20-mgmt, 050, 010-termlink) |
| T-4672 | INCONCLUSIVE: the pin did not change, so there was nothing to sync (832, 5b73054a) | — | WORKS elsewhere (ring20-mgmt, 050) |
| T-4675 | FAILS live: first harness-seat dispatch dies with "would shadow" (ring20-mgmt, 742ba198; corrects its own bats-only WORKS in 42ae6cd4) | T-4683; 832's finding → T-4684 | T-4683 WORKS (ring20-mgmt 3-vendor panel, 010-termlink, 832); T-4684 WORKS (5 projects) |
| T-4688 | PARTIAL: the dry run still dirties tracked `.verb-counter` (050, ac57ecb6) | T-4695 | WORKS (050, 8f195e9c) |
| T-4692 | PARTIAL ×2: the list includes files other processes wrote (ring20-mgmt ff56edf4, 050 ac57ecb6); FAILS: no list and a hard-coded commit id (dimitri-mint-dev, 3294edcf) | T-4697, T-4704, T-4705 | T-4704 WORKS ×3; the list chain continues below |
| T-4697 | FAILS: no list for an external-clone vendored consumer (dimitri-mint-dev, 6b2373ac) | T-4705 | → |
| T-4705 | PARTIAL: the summary prints, still no list (dimitri-mint-dev, b410de74) | T-4712 | → |
| T-4712 | FAILS: plain one-step external-clone upgrade, no list (dimitri-mint-dev, 6a934c08) | T-4717 | → |
| T-4717 | PARTIAL: the reason line works, but the snapshot hits MemoryError on a home-directory consumer and the line prints at the end (dimitri-mint-dev, 9bb3a50a) | T-4723, T-4724 | WORKS: T-4723 (dimitri-mint-dev), T-4724 (050, ring20-mgmt, dimitri-mint-dev), be.16 |
| T-4706 | PARTIAL / finding: the keep-alive is not seeded to consumers and needs a systemd opt-out (dimitri-mint-dev b410de74, ring20-mgmt 2ce6a48a) | T-4711 | WORKS (ring20-mgmt systemd path, dimitri-mint-dev, 010-termlink) |
| T-4720 | PARTIAL (round 2): a second re-vendor still rewrites the pinned designer build (bin/fw rm -f + cp, outside the --checksum path) and 4–6 unchanged vendor metadata files (ring20-mgmt 70e4bd0b; 010-termlink b283259c names the same metadata leftover) | T-4740 (completed 2026-10-24) | **no verdict** |

Side findings that came with WORKS verdicts and are still open: T-4698 (deferral gate reads another project's ids;
ring20-mgmt 714c296e, active), T-4719 (close-hint push remote; in be.17, no verdict), T-4720 (re-vendor leaves
Watchtower STALE; in be.17, no verdict), T-4736 (superseded designer builds never pruned; 050 8fe2eab0, active), T-4738
(push clause opt-out; 050 abf6d155, active), T-4726 (decide-verb hint; 010-termlink 51ce7c34; in be.17, no verdict).

Round 2 (2026-10-25): T-4720 and T-4726 now have be.17 verdicts (table above); T-4719 is installed at ring20-mgmt
and 010-termlink but not yet exercised, so it still has none. New side findings: `fw task review` counts a *quoted*
placeholder as a placeholder (010-termlink b283259c → T-4741, completed, no verdict); and check-project-boundary
refuses its own remedy, `fw config set BOUNDARY_EXTRA_READ_PATHS <outside path>` (010-termlink 9897c190,
2026-10-25 11:41Z). **No task found for the second one**: T-4361 and T-4649 mention the key but predate the report.
It is left for the parent to file.

## Per-report sections

### be.1 — dimitri-mint-dev (ae5a4e7f, 2026-10-20)
Re-test of v1.8.14 fixes only: T-4485 is still gated and T-4453 upgrades from a clone. Both are counted in the v1.8.14
report. Findings: shallow clone refused (→ T-4500 notice wording), self-vendor ran before the refusal (→ T-4498),
sidecar body tripped the tick guard (→ T-4499).

### be.2 — dimitri-mint-dev (5c5a8309, 2026-10-21)
T-4499 WORKS: a sidecar body quoting a git output option is allowed, and `sed -i` on a task file is still blocked. T-4529
WORKS on the sender side. The G-122 check (T-4515) reports old framework hook fragments as project lines (→ T-4552).

### be.2 — ring20-dashboard (ca94e1b8, 2026-10-21)
G-121 read-only bypasses all gated: awk `system`/`getline`/print-pipe (T-4509), sed `e` and `s///e` (T-4510), process
substitution (T-4511), quoted `-'exec'` and `-'o'` (T-4512), `git grep -O` (T-4513). Controls stay SAFE, and the 10
`--output` lines are still gated.

### be.2 — proxmox-ring20-management (f506e892, 2026-10-21)
G-122 holds (T-4515): commented-line counts unchanged. The upgrade was rolled back for ring20's own in-file patches,
which is not a be.2 bug. The pre-flight reported 2 false "local" files (→ T-4554), and two new WARNs needed explaining
(→ T-4555).

### be.3 — dimitri-mint-dev (2412ba7c, 2026-10-22)
T-4554/T-4235 upgrade WORKS (full clone, doctor 0 failures). T-4555 cron WORKS. The T-4626 allowlist over-blocks `sed -n` on a glob FILE operand (→ T-4650).

### be.3 — 010-termlink (6829fbaa, 2026-10-22)
Upgrade WORKS. T-4647 WORKS for the SEV-1 class, with two findings: TERMLINK_* is forwarded (→ T-4665) and PATH is
passed verbatim (→ T-4666). T-4227 WORKS, but the usage line goes to stdout (→ T-4667). T-4479 WORKS. The T-4636 doctor
check fired usefully.

### be.3 — ring20-dashboard (7f3be352, 2026-10-22)
T-4626 … T-4630 WORKS. T-4631: `git help -w` is gated, but `--ext-diff`/`--textconv` are still SAFE. AEF answered with
T-4639 (the .git/config write path). Regression lines all gated; controls SAFE.

### be.3 — 832-Workflow-designer (023c051c, 2026-10-22)
Upgrade WORKS (132 paths, doctor PASS). T-4647 WORKS: no FW_* leak to worker w-t1277. Designer 0.25.0 serves byte for
byte. After the upgrade the designer stayed NOT SYNCED until a manual install (→ T-4672). T-4454 not exercised.

### be.3 — 050-email-archive (5b5b40e9, 2026-10-22)
T-4222 WORKS (shipped in v1.8.14; not counted). Notes: a worktree of the tag pinned master (→ T-4661), and the
T-4409 refusal without a known cwd (→ T-4662).

### be.4 — 010-termlink (abd75be9) · dimitri-mint-dev (dcb718d1) · ring20-mgmt (4aade009), 2026-10-22
- T-4652: WORKS from all three. A python3 stub makes check-tier0 block "HOOK DEGRADED"; be.3 allowed it silently.
- T-4650: WORKS from all three. Globbed `sed -n` on T-*.md is SAFE; `*.md` is still gated; `sed -i` and `w` are refused.
- T-4665/T-4666: WORKS from 010-termlink live (env keeps only HOME, TERMLINK_RUNTIME_DIR and a built PATH) and from
  ring20-mgmt (bats).
- T-4653 and T-4659: WORKS, bats only (ring20-mgmt).
- T-4568: WORKS but weak (010-termlink, dimitri-mint-dev); PARTIAL live on ring20 (→ T-4678).
- Other findings: be.4 tag missing on GitHub (→ T-4673); preserve markers with regex escapes (→ T-4679); tag clone
  inside the tree (→ T-4680).

### be.5 — proxmox-ring20-management (42ae6cd4, 742ba198), 2026-10-23
Live WORKS: T-4678, T-4654, T-4655, T-4657, T-4672. Bats/pytest WORKS: T-4656, T-4658, T-4670, T-4661, T-4662, T-4667,
T-4671. T-4675 was first reported WORKS from bats, then corrected to **FAILS live**: the first rung-5 panel lost its
codex seat with "would shadow" (→ T-4683).

### be.5 — 010-termlink (4d03fd26, 2026-10-23)
T-4667 WORKS. T-4670 WORKS, with a residual: an inherited override without its sentinel is still honoured
(→ T-4685). Tag reached the mirror (T-4673 WORKS).

### be.5 / be.8 — 832-Workflow-designer (81cb0bca, 5b73054a), 2026-10-23
- WORKS: T-4683 and T-4684 (be.8); T-4677 (be.8); T-4675 (claude workers under `.context/dispatch`; harness seats keep
  /tmp by design); T-4678, T-4655, T-4667.
- T-4672 inconclusive: the pin was already current.
- T-4688 not exercised: they clone fresh per run.
- Finding: `.context/dispatch/` was not gitignored (→ T-4684).

### be.6 — proxmox-ring20-management (55d683dc, 2026-10-23)
- T-4683 WORKS live: a full claude-code + codex + opencode rung-5 panel closed a Human criterion. ring20 counts this as
  its arc-009 exit evidence.
- T-4679 WORKS live.
- WORKS from tests: T-4681, T-4682, T-4680 (bats); T-4677 (pytest).
- The t4217 test 2 red is host-dependent (→ T-4686).

### be.6 — 050-email-archive (e0b8f7ac) · 010-termlink (150d6e99), 2026-10-23
- 050: T-4670, T-4672 and T-4667 WORK. T-4662 is PARTIAL (→ T-4687).
- 010-termlink: T-4683 WORKS end to end; a codex review seat found a real defect in their code.
- 010-termlink finding: running an upgrade FROM a clone writes into that clone (→ T-4688).

### be.7 — ring20-mgmt (2b81655f) · 050 (7aed1e10) · 010-termlink (24f926ce), 2026-10-23
- T-4685: WORKS from all three. It closes 010-termlink's residual.
- T-4684: WORKS from all three. 010-termlink notes the new `.context/.gitignore` lands untracked (→ T-4692).
- T-4687: WORKS (ring20-mgmt bats, 050 live).
- T-4686: WORKS on ring20.
- 050 finding: the advisory doctor exits 141 (→ T-4691).

### be.8 — proxmox-ring20-management (8ce4401e, 3d9180b2), 2026-10-23
T-4688 WORKS live: the clone is clean after a dry run and a real run. Finding: `watchtower current` flaps STALE right
after a restart (→ T-4693).

### be.9 — ring20-mgmt (ff56edf4, 714c296e) · 050 (ac57ecb6) · dimitri-mint-dev (3294edcf, 1882d747), 2026-10-23
- T-4693 WORKS (ring20-mgmt, dimitri-mint-dev).
- T-4691 WORKS (all three).
- T-4689 WORKS (ring20-mgmt, dimitri-mint-dev).
- T-4690/T-4694 WORKS (ring20-mgmt, dimitri-mint-dev): no re-dirtied episodic after a close commit.
- T-4688 WORKS (dimitri-mint-dev). PARTIAL from 050: the dry run dirties the tracked `.verb-counter` (→ T-4695).
- T-4684 WORKS and T-4655 WORKS (dimitri-mint-dev).
- T-4692: PARTIAL from ring20-mgmt and 050 (over-broad list → T-4697). FAILS from dimitri-mint-dev (no list,
  hard-coded commit id → T-4704, T-4705).
- ring20-mgmt side finding: the deferral gate reads AEF ids as local ones (→ T-4698).

### be.10 — ring20-mgmt (0fa89c60) · dimitri-mint-dev (6b2373ac) · 010-termlink (c896df19) · 050 (8f195e9c), 2026-10-23
- T-4697: WORKS (ring20-mgmt, 010-termlink, 050). FAILS for dimitri-mint-dev's external-clone shape (→ T-4705).
- T-4699 and T-4700: WORKS (010-termlink live, ring20-mgmt bats).
- 010-termlink also: T-4689 WORKS and T-4690/T-4694 WORK.
- 050: T-4695 WORKS.
- 010-termlink FAILS on two older problems: the close hint was blocked once focus cleared (→ T-4707), and doctor says
  "script not found: [" (→ T-4708).

### be.11 — ring20-mgmt (2ce6a48a, ab31dde8) · dimitri-mint-dev (b410de74, 740b4ada) · 010-termlink (e20d045f, 697df617), 2026-10-23
- T-4708: WORKS (ring20-mgmt, 010-termlink).
- T-4704: WORKS (all three).
- T-4707: WORKS (ring20-mgmt, dimitri-mint-dev). 010-termlink's earlier block came from their own appended tail.
- T-4705: WORKS for ring20-mgmt; PARTIAL for dimitri-mint-dev (→ T-4712).
- T-4706: restart and own scope WORK. The keep-alive is not seeded to consumers and ring20 needs a systemd opt-out
  (→ T-4711).
- 055 finding, relayed by 010-termlink: a claude daemon is taken as a live conversation holder (→ T-4714).

### be.12 — proxmox-ring20-management (36943a12, 82ef34f0), 2026-10-23
T-4712, T-4703 and T-4710 WORK live: the close hint for a never-committed task file committed as printed.

### be.13 — proxmox-ring20-management (a3d7da1d), 2026-10-23
T-4714 WORKS, pytest 8/8. Not exercisable live: no claude daemon runs on ring20.

### be.14 — ring20-mgmt (c12cbb7a) · dimitri-mint-dev (6a934c08, 50f01abf, b2dfaeca) · 010-termlink (9c448cb6), 2026-10-23
- T-4711: WORKS on the systemd path (ring20-mgmt), the non-systemd path (dimitri-mint-dev) and unit-less (010-termlink).
- T-4703: WORKS. T-4710 WORKS for the tracked case.
- T-4707 WORKS (010-termlink). The push needs an upstream (→ T-4719).
- T-4712 FAILS on dimitri-mint-dev's plain one-step upgrade (→ T-4717).
- 010-termlink observation: a re-vendor marks Watchtower STALE (→ T-4720).

### be.15 — ring20-mgmt (e9ef88ee) · dimitri-mint-dev (9bb3a50a) · 050 (5fdbef7c), 2026-10-23
- T-4717: WORKS (ring20-mgmt, 050). PARTIAL for dimitri-mint-dev: MemoryError on a home-directory consumer, and the
  reason line prints at the end (→ T-4723, T-4724).
- T-4716/T-4718: WORKS (ring20-mgmt, dimitri-mint-dev).
- 050: T-4706 scope WORKS; T-4708 shows no WARN.

### be.16 — 050 (8fe2eab0, abf6d155) · ring20-mgmt (ab21bdd5) · dimitri-mint-dev (afb8ec6b), 2026-10-24
- T-4724: WORKS (all three).
- T-4732: WORKS (all three); designer 0.26.0 installed.
- T-4723: WORKS (dimitri-mint-dev). No MemoryError, 137 s, the list matches git status, and the printed `git add` was
  committed verbatim.
- T-4733: WORKS (050).
- T-4707/T-4710: WORKS at 050's first agent-owned close.
- Findings: superseded designer builds pile up at the root `vendor/designer/` (→ T-4736); the push clause should be
  optional (→ T-4738).

### be.17 — ring20-mgmt (70e4bd0b) · 010-termlink (b283259c, 9897c190), 2026-10-24/25 (round 2)
- Upgrade: ring20-mgmt via its upgrade script, 18 in-file patches merged clean, doctor FAIL 2 before / 2 after (no
  new), 6 pages 200. 010-termlink be.14 → be.17, rehearsal and real run rc 0, check-active-task.sh 3-way merged clean
  with T-4719, fw doctor rc 0.
- T-4720: WORKS (010-termlink: only the 4 Designer web files with new content were rewritten). PARTIAL (ring20-mgmt:
  a second run rewrote the pinned designer build `vendor/designer/aef-workflow-designer-0.26.0.html` with identical
  content, plus vendor metadata files) → T-4740.
- T-4726: WORKS (010-termlink: five real records, three NO-GO-recommended inceptions recorded GO now map to no-go,
  two DEFER to defer).
- T-4732: WORKS (010-termlink: designer 0.25.0 removed, 0.26.0 in place).
- T-4719: installed at both, not exercised yet. No verdict.
- Findings: quoted placeholder text counted by `fw task review` (→ T-4741); check-project-boundary refuses
  `fw config set BOUNDARY_EXTRA_READ_PATHS` with an outside path, the remedy its own block message names (no task yet).
- Announced, no report yet: 050 (e308e429, on be.16, next upgrade on operator GO), 055 (cd0b5820, 5de6a3e1: upgrading
  to be.17 then be.18 before merging).

### be.18 / be.19 — proxmox-ring20-management (recorded 2026-10-25, T-4755)

| Fix | Tip tested | Verdict | Msg |
|---|---|---|---|
| T-4740 | v1.8.15-be.18 (5259a14be) | **WORKS LIVE**: second identical upgrade rewrote 11 files (their 10 patched overlay files and watchtower.log). The designer build and all six vendor metadata files were left untouched. This closes the be.17 PARTIAL on T-4720 | 67962a10 |
| T-4731 | v1.8.15-be.18 | **WORKS**: a read of `~/.termlink` passes the boundary hook | 67962a10 |
| T-4701 | v1.8.15-be.19 (ec1bdf64a) | **WORKS**: "214 runtime file(s) … already tracked" with one exact `git rm --cached` command. Nothing was untracked, and deliberately tracked task evidence was not listed. A usability note (group by directory) → T-4754 | 13c2c3bf |

Both upgrades were clean: 18 in-file patches merged, preserve OK, doctor FAIL 2 before and 2 after, pages 200, `watchtower
current` green. Installed but not exercised: T-4698, T-4721, T-4722, T-4751 (be.19); T-4727, T-4734, T-4736, T-4738,
T-4741, T-4742/T-4749, T-4744 … T-4748, T-4750 (be.18). The boundary-remedy finding listed above is T-4751, fixed in be.19.

## Full-suite comparison (HEAD eee888e61 vs v1.8.14)

**Method, and what it does not cover.** T-4345 ran the whole unit corpus on two scratch trees side by side (jobs=6
each) and compared the red files. I copied that set-up: `git archive v1.8.14` and `git archive HEAD` were each extracted
under `.context/scratch/t4739/suite/{base,head}` (no worktree, no checkout). Each tree got a fresh `git init` plus one
snapshot commit, so tests that need a repository have one. Every file ran the way `agents/audit/unit-suite.sh` runs it:
`bats --tap` / `pytest -q -rf -p no:cacheprovider`, one TMPDIR per file, `timeout -k 10`, the cron PATH
(`/usr/local/bin:/usr/bin:/bin`) and `env -i`. The runs were chunked so each tool call stayed in the foreground.

**The full corpus did not finish within 2 h.** The host load average was 30–47 on 24 cores (ollama, other projects'
sessions), and files ran 3–10× slower than their nightly durations. The two full runs reached about 120 of 1193 files
(base) and 122 of 1498 files (HEAD) in 19 minutes. I stopped them and ran a **targeted** comparison of 42 files on both
trees:
- every red or undetermined file in the latest HEAD-side nightly reports (fast tier 2026-10-24 at ae71b4f0c = be.16;
  slow and perf tiers 2026-10-24 at bfd18d6bd);
- every test file changed since those runs (t2266, t2267, t3241, t4692, t4705, t4719, t4720, t4726);
- the 4 files whose head and base results differed in the partial full run.

A file red at HEAD that was green in both nightlies and is not among those 42 would be missed. The nightlies are at
most 9 h behind HEAD, and the test files changed since then are included.

**Red at HEAD, not red at v1.8.14 (10 files):**

| File | Failing test(s) | Cause | Owner |
|---|---|---|---|
| episodic_frontmatter_extraction.bats | T-2731 whole episodic corpus parses | Release diff (corpus): `.context/episodic/T-4679.yaml` raises ScannerError (an invalid escape in a double-quoted scalar) | **T-4743** (new) |
| episodic_yaml_timeline_escape.bats | T-2729 every episodic parses | Same T-4679 episodic | **T-4743** |
| test_task_create_description_yaml.py | test_corpus_frontmatter_is_intact | Same defect in `.tasks/completed/T-4679-*.md` frontmatter | **T-4743** |
| t3221_commit_exemption_clause.bats | 17: both exemption branches call the same predicate | Release diff (stale pin): b84ec0b72 (T-4182) added a 3rd `is_commit_checkpoint_command "$BASH_CMD"` site in check-active-task.sh (818, 988, 1181); the test counts exactly 2. Red in every slow nightly since 2026-10-22 | **T-4744** (new) |
| hermetic.py | collected no tests (pytest exit 5) | Release diff (test infra): T-4378's helper module is discovered as a test file | **T-4745** (new) |
| t4431_be_tags.bats | 11: every describe --tags excludes -be tags | Release diff (code): bin/fw:1538 `_t4680_at=$(git … describe --tags --always)` from 0cd8587bc (T-4680) has no -be exclusion | **T-4746** (new) |
| t4689_working_ignore_rail.bats | 4: rail is clean on the framework tree | Release diff (code): `watchtower-outages.jsonl` (T-4706, 4e3ba1199, bin/fw:3160) is not in fw_working_ignore_rules | **T-4747** (new) |
| greenfield_seed_audit_prototype.bats | T-2703, T-2740 | Release diff (code): since T-4259 (d8c12bde8) init generates a crontab, and a fresh seed's audit FAILs "Cron drift: generated but not installed" (audit.sh:3135). Base timed out at 540 s here (undetermined); green in slow nightlies before 2026-10-22, red since | **T-4748** (new) |
| t4705_upgrade_commit_list_vendored_external.bats | 3, 4 | Environmental: the archive snapshot has no history or tags (`fatal: not a valid object name: HEAD~300` / `v1.8.15-be.11`). Green in the live repo's nightlies | — |
| bvp_auto_promote_enable.bats | 7: cron registry in sync (fw doctor) | Environmental: the test reads the real host's `/etc/cron.d`. Doctor in the scratch tree says "Cron generated but not installed at /etc/cron.d/agentic-audit-head"; green in the live repo (fast nightly 2026-10-24) | — |

Also red at HEAD with **more failing tests than at v1.8.14**: `create_task.bats` (12 extra). Environmental. The scratch
TMPDIR sat inside the live project, so HEAD's T-4670/T-4685 foreign-dir rule re-derived the test's TASKS_DIR into the
scratch tree: the "Unit test task creation" tasks were found in `suite/head/.tasks/active/`, and none in the live repo.
Re-run at HEAD with TMPDIR under /tmp: rc 0, all tests pass.

**Red on both sides, same tests** (not attributed to the diff): approvals_close_ready_arcs, atomic_yaml_write_lint,
audit_split_root_asset_lint, review_pipefail, test_operator_facing_stderr.py, audit_inception_recommendation,
doctor_hook_counters, lib_review, t3636_objectives_seed, test_doctor_scope_tags, git_identity_check (base killed at 256 s).
**Green on both:** the 6 fast-tier undetermined bats files (lib_upstream, note_capture_guard, note_exit_status,
revisit_undated_signal, t2924, t3045), the 3 undetermined pytest files, tier0_grant_ttl, t4108_issues_security_test.py,
t3580_judge_cli_test.py, t3580_round2_test.py, t2266, t2267, t3241. **New at HEAD and green:** t4692, t4719, t4720, t4726.

**Failures attributed to the release diff: 8 files from 6 causes** (T-4743 … T-4748). Three causes are test or
corpus only (T-4743, T-4744, T-4745). Three touch shipped code (T-4746: a label can name a -be tag; T-4747: a runtime
file a consumer could commit; T-4748: a fresh greenfield project fails its own audit until `fw cron install`). None of
the six has a field report against it.

### Round 2 — 2026-10-25 (HEAD 5259a14be, plus the 4 test files new in d085cb3d4)

**Method.** Same per-file runner as round 1 (`agents/audit/unit-suite.sh` invocation, `env -i`, cron PATH, one TMPDIR
per file, `timeout -k 10`), in the foreground in chunks of at most 10 min, both trees at once with 8 jobs each. One
change: the `git archive v1.8.14` and `git archive HEAD` trees, each with a fresh `git init` and one snapshot commit,
sat in a `mktemp -d` under `/tmp`, **outside the live repo**. That removes round 1's create_task.bats noise. The
targets were round 1's 42 files plus every test file changed since 42e87308b: 14 files, 12 of them new to the list
(stop_driver, t2964, t4680, t4728, t4729, t4730, t4731, t4734, t4736, test_audit_cron_drift, test_hermetic_fixture.py,
test_t4745_*). t3221 and t4689 were already in it, and support files (`_hermetic.py`, conftest.py, helpers/) are not
test files. That makes 54. The per-file cap was 480 s; the three files that
hit it were re-run at 575 s. HEAD moved to d085cb3d4 while this ran. Its 4 new test files (t4698, t4701, t4721, t4722)
were run on a third `git archive d085cb3d4` tree: all 4 are green (28 ok, 0 not ok). Host load was 22–33 on 24 cores.

**Round 1's release-diff reds, per task:**

| Task | Round-1 red | Round 2 at HEAD | Status |
|---|---|---|---|
| T-4744 | t3221_commit_exemption_clause.bats test 17 | rc 0, all ok | **green** |
| T-4745 | hermetic.py: collected no tests (exit 5) | renamed `_hermetic.py`, so it is no longer a test file; test_t4745_discovered_modules_define_tests.py and test_hermetic_fixture.py are green | **green** |
| T-4746 | t4431_be_tags.bats test 11 | rc 0, all ok | **green** |
| T-4747 | t4689_working_ignore_rail.bats test 4 | rc 0, all ok | **green** |
| T-4748 | greenfield_seed_audit_prototype.bats T-2703, T-2740 | rc 0, 3/3 ok in 345 s (v1.8.14: rc 0 in 496 s at the 575 s cap, so it is no longer undetermined) | **green** |
| T-4743 | episodic_frontmatter_extraction (10), episodic_yaml_timeline_escape (6), test_task_create_description_yaml.py::test_corpus_frontmatter_is_intact | still red; the only unparseable files in the HEAD tree are `.context/episodic/T-4679.yaml` and `.tasks/completed/T-4679-*.md` (ScannerError) | **open, operator-gated** |

**Red at HEAD, not red at v1.8.14 (round 2): 5 files from 2 causes.**

| File | Failing test(s) | Cause | Owner |
|---|---|---|---|
| episodic_frontmatter_extraction.bats | 10: the whole episodic corpus parses | Release diff (corpus): T-4679 episodic | **T-4743** (open, operator-gated) |
| episodic_yaml_timeline_escape.bats | 6: every episodic in the corpus parses | Same | **T-4743** |
| test_task_create_description_yaml.py | test_corpus_frontmatter_is_intact | Same defect in the T-4679 task file | **T-4743** |
| t4705_upgrade_commit_list_vendored_external.bats | 3, 4 (7 of 9 ok) | Environmental, as in round 1: the archive snapshot has no history or tags (`fatal: not a valid object name: HEAD~300`, `… v1.8.15-be.11`) | — |
| bvp_auto_promote_enable.bats | 7: cron registry in sync (fw doctor) | Environmental, as in round 1: the test reads the real repo's doctor, which in the scratch tree says "cron not installed yet … /etc/cron.d/agentic-audit-head is missing" plus "registry edited but not generated" (archive mtimes). The test is absent from the last three live-repo nightly failure lists (2026-10-24) | — |

**Red on both sides, same tests (not attributed):** round 1's 11 files are unchanged (approvals_close_ready_arcs,
atomic_yaml_write_lint, audit_split_root_asset_lint, review_pipefail, test_operator_facing_stderr.py,
audit_inception_recommendation, doctor_hook_counters, lib_review, t3636_objectives_seed, test_doctor_scope_tags,
git_identity_check). One file is new to the list: **test_audit_cron_drift.bats** test 1. It fails identically on both
trees because `fw cron generate` refuses an fw path "under a temp dir outside the project". That is a placement
artefact of this round's `/tmp` trees, and the file is not in the last three live nightly failure lists.
**create_task.bats is green on both sides** (rc 0), which confirms that round 1's extra failures came from the
scratch dir sitting inside the repo. Every other target is green on both sides or new and green at HEAD. Six fast-tier
bats files each report one `# skip`, as in round 1.

**Failures attributed to the release diff, round 2: 3 files from 1 cause, T-4743**, which is operator-gated. T-4744 …
T-4748 are confirmed green. No new release-diff cause was found.

## Release dry-run (`bin/fw release tag-and-release --dry-run`, 2026-10-24, HEAD eee888e61)

Verbatim; ANSI colour codes stripped.

```
No recorded release decision for v1.8.15 (an unattended run would refuse)
Remote 'github/master' is an ancestor of HEAD — fast-forward available.
Remote 'origin/master' is an ancestor of HEAD — fast-forward available.
Remote 'github/bleeding-edge' is an ancestor of HEAD — fast-forward available.
Remote 'origin/bleeding-edge' is an ancestor of HEAD — fast-forward available.
would tag v1.8.15 (1263 commits since v1.8.14, bump=patch)
would reconcile VERSION 1.8.14 → 1.8.15 (tag-as-canonical, T-3242)
would fast-forward master by 1271 commit(s) to v1.8.15
would push bleeding-edge in the same atomic push (T-3848)
GitHub issues (stages 8-9)...
would post released on #99 (T-4356): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-24

**T-4356** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #99: Vector-index health reports `index-reindex-hourly scheduled` when no cron entry is installed.
**How it was tested:** `tests/unit/t3783_vector_index_health.bats`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
hold   #104 (T-4361): T-4361 is still active (awaiting review); not posted. Re-run after it completes
hold   #102 (T-4359): T-4359 is still active (awaiting review); not posted. Re-run after it completes
hold   #98 (T-4355): T-4355 is still active (awaiting review); not posted. Re-run after it completes
would post released on #100 (T-4357): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-24

**T-4357** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #100: fw doctor says `resolver-loop.timer is installed but inactive` on hosts where it is not installed.
**How it was tested:** `tests/unit/t4357_doctor_resolver_timer_presence.bats`, `tests/unit/test_t4386_doctor_perf.py`, `test_t4386_doctor_perf`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #101 (T-4358): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-24

**T-4358** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #101: fw doctor warns `TURN DRIVER is not armed` for every interactive claude-fw session that never used continuous mode.
**How it was tested:** `tests/unit/t4358_doctor_turn_driver_interactive.bats`, `tests/unit/test_t4386_doctor_perf.py`, `test_t4386_doctor_perf`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #97 (T-4354): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-24

**T-4354** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #97: fw doctor Watchtower smoke test probes localhost, so all endpoints fail when Watchtower is bound to FW_HOST.
**How it was tested:** `tests/unit/test_t4354_smoke_test_base_url.py`, `tests/unit/test_t4363_startup_warmup.py`, `tests/unit/test_t4386_doctor_perf.py`, `tests/unit/t3453_doctor_smoke_inverted_alarm.bats`, `tests/unit/t3933_doctor_smoke_skip.bats`, `test_t4354_smoke_test_base_url`, `test_t4363_startup_warmup`, `test_t4386_doctor_perf`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #105 (T-4362): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-24

**T-4362** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #105: A clone's bin/fw called by full path from inside a consumer project runs the project's vendored copy instead.
**How it was tested:** `tests/unit/t4362_clone_fw_full_path_from_consumer.bats`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #96 (T-4353): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-24

**T-4353** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #96: After a fresh auto-restart the new session is told "Post-Compaction Context Recovery" — the agent then reports a compaction that never happened.
**How it was tested:** `tests/unit/t4353_resume_header_by_source.bats`, `tests/unit/restart_sentinel_ttl.bats`, `tests/unit/session_start_hook_warning.bats`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #95 (T-4352): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-24

**T-4352** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #95: Auto-restart is documented as `claude -c` but the default is a fresh session.
**How it was tested:** `tests/unit/t4352_restart_mode_docs.bats`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
release v1.8.15: 0 posted, 0 closed, 3 held, 0 failed (dry-run: nothing posted or closed)
would prune release work dir .context/scratch/hf1814 (release already shipped)
would prune release work dir .context/scratch/v1811 (release already shipped)
would prune release work dir .context/scratch/v1812 (release already shipped)
would prune release work dir .context/scratch/v1813 (release already shipped)
rc=0
```

### Round 2 — 2026-10-25, HEAD d085cb3d4

Verbatim; ANSI colour codes stripped. Changes from round 1: 1312 commits since v1.8.14 (master fast-forward by 1320),
the same 7 GitHub issues would get "released" and the same 3 are held (#104 T-4361, #102 T-4359, #98 T-4355).
No release decision is recorded.

```
No recorded release decision for v1.8.15 (an unattended run would refuse)
Remote 'github/master' is an ancestor of HEAD — fast-forward available.
Remote 'origin/master' is an ancestor of HEAD — fast-forward available.
Remote 'github/bleeding-edge' is an ancestor of HEAD — fast-forward available.
Remote 'origin/bleeding-edge' is an ancestor of HEAD — fast-forward available.
would tag v1.8.15 (1312 commits since v1.8.14, bump=patch)
would reconcile VERSION 1.8.14 → 1.8.15 (tag-as-canonical, T-3242)
would fast-forward master by 1320 commit(s) to v1.8.15
would push bleeding-edge in the same atomic push (T-3848)
GitHub issues (stages 8-9)...
would post released on #99 (T-4356): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-25

**T-4356** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #99: Vector-index health reports `index-reindex-hourly scheduled` when no cron entry is installed.
**How it was tested:** `tests/unit/t3783_vector_index_health.bats`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15 · field-evidence report https://github.com/DimitriGeelen/agentic-engineering-framework/blob/v1.8.15/docs/reports/field-test-v1.8.15-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
hold   #104 (T-4361): T-4361 is still active (awaiting review); not posted. Re-run after it completes
hold   #102 (T-4359): T-4359 is still active (awaiting review); not posted. Re-run after it completes
hold   #98 (T-4355): T-4355 is still active (awaiting review); not posted. Re-run after it completes
would post released on #100 (T-4357): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-25

**T-4357** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #100: fw doctor says `resolver-loop.timer is installed but inactive` on hosts where it is not installed.
**How it was tested:** `tests/unit/t4357_doctor_resolver_timer_presence.bats`, `tests/unit/test_t4386_doctor_perf.py`, `test_t4386_doctor_perf`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15 · field-evidence report https://github.com/DimitriGeelen/agentic-engineering-framework/blob/v1.8.15/docs/reports/field-test-v1.8.15-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #101 (T-4358): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-25

**T-4358** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #101: fw doctor warns `TURN DRIVER is not armed` for every interactive claude-fw session that never used continuous mode.
**How it was tested:** `tests/unit/t4358_doctor_turn_driver_interactive.bats`, `tests/unit/test_t4386_doctor_perf.py`, `test_t4386_doctor_perf`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15 · field-evidence report https://github.com/DimitriGeelen/agentic-engineering-framework/blob/v1.8.15/docs/reports/field-test-v1.8.15-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #97 (T-4354): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-25

**T-4354** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #97: fw doctor Watchtower smoke test probes localhost, so all endpoints fail when Watchtower is bound to FW_HOST.
**How it was tested:** `tests/unit/test_t4354_smoke_test_base_url.py`, `tests/unit/test_t4363_startup_warmup.py`, `tests/unit/test_t4386_doctor_perf.py`, `tests/unit/t3453_doctor_smoke_inverted_alarm.bats`, `tests/unit/t3933_doctor_smoke_skip.bats`, `test_t4354_smoke_test_base_url`, `test_t4363_startup_warmup`, `test_t4386_doctor_perf`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15 · field-evidence report https://github.com/DimitriGeelen/agentic-engineering-framework/blob/v1.8.15/docs/reports/field-test-v1.8.15-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #105 (T-4362): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-25

**T-4362** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #105: A clone's bin/fw called by full path from inside a consumer project runs the project's vendored copy instead.
**How it was tested:** `tests/unit/t4362_clone_fw_full_path_from_consumer.bats`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15 · field-evidence report https://github.com/DimitriGeelen/agentic-engineering-framework/blob/v1.8.15/docs/reports/field-test-v1.8.15-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #96 (T-4353): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-25

**T-4353** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #96: After a fresh auto-restart the new session is told "Post-Compaction Context Recovery" — the agent then reports a compaction that never happened.
**How it was tested:** `tests/unit/t4353_resume_header_by_source.bats`, `tests/unit/restart_sentinel_ttl.bats`, `tests/unit/session_start_hook_warning.bats`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15 · field-evidence report https://github.com/DimitriGeelen/agentic-engineering-framework/blob/v1.8.15/docs/reports/field-test-v1.8.15-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
would post released on #95 (T-4352): please-confirm
<!-- aef-intake:stage=released -->
**[AEF intake] Released** — 2026-10-25

**T-4352** is released in **v1.8.15**.

Please confirm it fixes this for you. Reply here if it does not. With no reply in 14 days this issue is closed with a note, and you can reopen it.

**What was fixed:** GH #95: Auto-restart is documented as `claude -c` but the default is a fresh session.
**How it was tested:** `tests/unit/t4352_restart_mode_docs.bats`
**Field evidence:** none recorded for this fix.
**Why it was released:** v1.8.15 passed the release gates; no release decision is recorded for it in .context/releases/decisions.jsonl.
**Links:** release notes https://github.com/DimitriGeelen/agentic-engineering-framework/releases/tag/v1.8.15 · field-evidence report https://github.com/DimitriGeelen/agentic-engineering-framework/blob/v1.8.15/docs/reports/field-test-v1.8.15-results.md

*These status updates are automated, but Dimitri personally looks at every issue and decides what happens to it. Replies on this issue are read.*
release v1.8.15: 0 posted, 0 closed, 3 held, 0 failed (dry-run: nothing posted or closed)
would prune release work dir .context/scratch/hf1814 (release already shipped)
would prune release work dir .context/scratch/v1811 (release already shipped)
would prune release work dir .context/scratch/v1812 (release already shipped)
would prune release work dir .context/scratch/v1813 (release already shipped)
rc=0
```

## Release readiness

**The field-evidence path of T-4146 does not apply. v1.8.15 goes to the operator as an explicit yes/no, with the
dry-run above.**

- T-4146 releases without asking only when **every** fix has a positive field test. Of the 359 task ids with
  vendored-path commits since v1.8.14, **73 have a field verdict and 286 have none** (Appendix A). In the consumer-facing
  areas alone, 103 upgrade/vendor ids and 43 hooks/gates ids are untested.
- Of the 80 fixes with a verdict, every FAILS/PARTIAL chain ends in a WORKS, except T-4552 (G-122 fragment false
  positive) and T-4639 (.git/config gate). Neither has a field verdict of its own.
- The suite comparison found 6 release-diff causes (8 red files), filed as T-4743 … T-4748. The T-4146 gate wants no
  failure attributed to the release diff, so this is red until those are fixed or the operator accepts them. Three
  touch shipped behaviour (T-4746, T-4747, T-4748).
- The comparison is targeted (42 files), not the full corpus: the host was too loaded to finish in 2 h.
- No be.17 field report has arrived. be.17's own fixes (T-4719, T-4720, T-4726) are untested.
- The dry-run is clean: rc 0, fast-forward of master by 1271 commits, no release decision recorded. It would post
  "released" on 7 GitHub issues and hold 3 that are still in review.

The question for the operator: release v1.8.15 to master now, with 286 untested task ids and T-4743 … T-4748 open,
yes or no? Or fix T-4746 … T-4748 first and ask again?

### Round 2 — 2026-10-25, HEAD d085cb3d4

**Still the T-4146 fallback: the operator gets an explicit yes/no with the round-2 dry-run above.**

- **Suite:** T-4744 … T-4748 are fixed and green at HEAD. The only failure still attributed to the release diff is
  **T-4743** (the T-4679 task file and episodic do not parse: 3 red files), which is operator-gated. The other 2 new
  reds are environmental (no history or tags in the archive; the scratch tree's cron is not installed), as in round 1.
  No new release-diff cause turned up. On that basis Agent AC4 of T-4739 is ticked, with T-4743 named as the one
  exception. The comparison is still targeted (54 files, plus 4 at d085cb3d4), not the full corpus.
- **Field evidence:** be.17 brought WORKS for T-4720 (010-termlink) and T-4726 (010-termlink), and a PARTIAL for T-4720
  (ring20-mgmt; the designer-build rewrite → T-4740, which has no verdict). T-4719 is installed but not yet exercised.
  At HEAD, **75 of 377** vendored-path task ids have a field verdict and **302 have none**. The 18 ids added since
  round 1, including the T-4744 … T-4748 fixes, T-4740 and T-4741, are all untested.
- **Open finding without a task:** check-project-boundary refuses its own remedy, `fw config set
  BOUNDARY_EXTRA_READ_PATHS` (010-termlink 9897c190).
- **Dry-run:** rc 0. It would fast-forward master by 1320 commits, push bleeding-edge in the same atomic push, post
  "released" on 7 GitHub issues and hold 3. No release decision is recorded.

The question for the operator: release v1.8.15 to master now, with 302 untested task ids and T-4743 open (corpus
only; it ships no code), yes or no?

<details>
<summary>Appendix A — 286 vendored-path task ids since v1.8.14 with no field verdict, by area</summary>

Task ids come from `git log --format=%s v1.8.14..HEAD -- bin/fw lib agents policy web tools`. No housekeeping subject
(bvp sweep, docs-daily, escalation-drift, handover, vendor-sync-only) touches those paths, so none was excluded. Areas
are assigned by keywords in each task's main commit subject and its paths, so they are approximate. Each line shows the
task's main commit subject.

**upgrade/vendor (103)**

- T-2657 — fw update vendors with the fetched upstream's own bin/fw vendor (new includes list), not the running old do_vendor; WARN
- T-2661 — self-vendor root data class — _self_vendor_root_data syncs .secret-scan-patterns/.secret-scan-allowlist/status-transitio
- T-2680 — silent-zero store-grep detector — lib/silent_zero_scan.py (fixed-indent YAML-key greps on stores + zero-fallback counts 
- T-2698 — add APPROVAL_PENDING_WARN_HOURS row to Watchtower /config SETTINGS — T-3079 added the key to lib/config.sh only, parity 
- T-2756 — auto-clone handoff refuses ahead/diverged consumer pin against the clone before the clone's fw runs (--force-downgrade b
- T-2861 — fw init/upgrade emit worktree.bgIsolation=none for consumers — template key in generate_claude_code_config, step-5 top-u
- T-2906 — context status no longer exits 141 — Recent listing used sort|head -3, sort took SIGPIPE under context.sh pipefail once 
- T-2961 — pre-push VERSION stamp keeps the tag's patch — X.Y.Z+N.gSHA (T-4055 grammar), not <major.minor>.<distance>; regression b
- T-3135 — fw update orders versions (semver) instead of string inequality — a newer vendored copy is no longer downgraded; --allow
- T-3136 — vendor stamp records source_commit (vendored base) and fw update shows it; bin/fw local-patch refusal (T-3850) pinned; 6
- T-3698 — fw init / fw upgrade pin the live hub dir as env.TERMLINK_RUNTIME_DIR in the consumer .mcp.json termlink server (add-onl
- T-3715 — fw upgrade pre-approves the framework's MCP servers (enabledMcpjsonServers in .claude/settings.local.json) so a restarte
- T-3735 — fw config set dumps .framework.yaml at width 4096 (ruamel + PyYAML) so long values like upstream_repo stay on their key 
- T-3762 — fw sidecar send reports a no-receiver hub fallback — receiver: line + json receiver=none-registered (null when --hub ski
- T-3763 — fw pickup send --remote delivers via fw sidecar send (the one channel, T-3631) instead of deprecated termlink remote pus
- T-3777 — sidecar supervisor/watcher exit when PROJECT_ROOT is gone and never recreate it — watcher.project_gone() checked at entr
- T-3778 — doctor-calling bats files run doctor at most once — designer-pin and vendored-source drift checks moved verbatim into li
- T-3798 — handover.sh skips auto-commit and push when HANDOVER_DIR is outside PROJECT_ROOT's repo (fixture override pushed the rea
- T-3801 — t2290 and t3119 stop paying a whole doctor per test — MCP manifest and designer-currency checks moved verbatim into lib/
- T-3811 — _quality_scores skips a task file that vanishes between glob and read (task closed mid-scan raised FileNotFoundError — t
- T-3838 — shell_write_scan default mode treats truncate operands as write targets (-s/-r/--size/--reference values skipped, cluste
- T-3848 — fw release pushes the checked-out dev branch in the same atomic push as master + tag, and pre-flights it on every remote
- T-3853 — delegation classifier reads producer text only — framework-written reviewer verdict/escalation lines (one shared GENERAT
- T-3861 — vector index + build/reindex scratch gitignored in consumers — lib/vec-index-gitignore.sh holds one rule list (fw-vec-in
- T-3862 — SEMANTIC_RECALL opt-out — vector-index health reports SKIP 'not configured on this host' instead of 7 FAILs, fw index re
- T-3863 — verdict commit failures journalled to commit-errors.jsonl and named in the uncommitted fault (judge + audit); operator-o
- T-3866 — fw notify runs the skills-manager dispatcher as a package module via lib/notify_dispatch.py (dispatch_alert API; script 
- T-4033 — verdict commit waits on a held index.lock against a bounded 60 s deadline (was 5 tries, ~5 s); fw reviewer judge names e
- T-4048 — claude-fw never starts claude with an empty argv (bare first launch named -n fw-<dir>) and refuses --resume of a live Cl
- T-4115 — classify 'fw task stale' as read-only in the task-gate allowlist (doctor advises it at null focus); regression bats; ven
- T-4159 — shell_write_scan: a T-NNNN-*.md name is a guarded mention only when bare or ./.. anchored, not under docs/reports/ or em
- T-4160 — fabric enrich finds three missed edge classes — python3/node/perl/ruby run a script by path like bash does (python3 -m /
- T-4164 — estate read side — fw recall / fw ask --scope own|estate|both with provenance on every hit (R-12/R-33), cross-project la
- T-4165 — standing operator delegation as a Human-tick provenance kind — operator-only grant/revoke/list (lib/human_ac_ticks.py de
- T-4169 — handover splits captured on horizon — captured+now goes to new tasks_ready: (parked = next/later only); digest WIP ranks
- T-4172 — resume hook labels a continue-mode budget restart (source resume + fresh .auto-restart-pending) as a budget auto-restart
- T-4173 — post-compact-resume.sh header no longer says the budget auto-restart is claude -c — fresh session by default (T-3166), -
- T-4174 — budget gauge reads a young session (first call after a restart, <2 usage entries) as ok + real low tokens + provisional:
- T-4175 — fw pickup send requires a target — no --remote/--local exits non-zero; --local saves to undelivered/; outgoing envelopes
- T-4182 — drift gate allows the closure commit of a just-completed task — plain commit checkpoint (is_commit_checkpoint_command) w
- T-4183 — audit warn/fail/info rewrite a standalone bin/fw in finding text to the resolved framework command (.agentic-framework/b
- T-4185 — bvp estimator scores only authored text — strip HTML comments and prior estimator rationale for every scorer, and templa
- T-4189 — generate_id takes the max with a persisted high-water mark (.tasks/.id-highwater, read from every task view, ignored pas
- T-4192 — fw task update --related / --unlocks append to related_tasks / unlocks_inception_decision, refusing ids that do not reso
- T-4193 — episodic joins decisions.yaml by task id — register-only decisions are emitted with source: register under a comment say
- T-4195 — reviewer Layer 1 escalation ignores description — Verification #-comment lines and HTML comments, AC backticked/double-q
- T-4198 — Watchtower settings offers a Mistral (La Plateforme) API key — key_name option + ENV_OVERRIDES mistral → MISTRAL_API_KEY
- T-4199 — R-033 sovereignty gate names the working route for a human-owned task with no Human criteria (fw task delegate -> fw rev
- T-4221 — triage of all 28 baselined unit-red files; fix watchtower port_in_use/_watchtower_port_listening reading ss SIGPIPE (141
- T-4231 — fw init/upgrade gitignore runtime state under .context/working (counters, locks, pid/url, cursors, logs, telemetry) from
- T-4234 — consumer fw upgrade --dry-run fetches upstream into its temp dir and hands off to the clone's --dry-run, so the per-file
- T-4240 — one restart notice per init/install — install.sh runs fw init with FW_INIT_NO_RESTART_NOTICE=1 and its banner carries th
- T-4244 — consumer CLAUDE.md and /resume templates name .agentic-framework/bin/fw (the launcher a vendored consumer has), not bin/
- T-4254 — fw init census treats .context/ and .tasks/ as framework scaffolding, so a target holding only them is greenfield; regre
- T-4266 — fw init bootstrap recovery advice names the session's focused task (fw_init_bootstrap_task_ref, reads $CLAUDE_PROJECT_DI
- T-4268 — install-hooks reports absent hooks as installing, not 'content differs', and lists only hooks written
- T-4269 — /approvals brake card has three states — 'No continuous run armed' when .continuous-mode.yaml is absent or not enabled: 
- T-4272 — C-001 and the T-2194 Open Questions gate name one order — IW-1 first, docs/reports/ artifact second; CLAUDE.md item 6 + 
- T-4290 — backticked-URL linkifier no longer lifts quotes into href (tasks.py _CODE_URL_HTML_RE + shared.py twin) — Human AC Steps
- T-4316 — secret-scan allowlist is the union of project-root and vendored files; block/audit remedy names the project-root file
- T-4324 — fw inception correct re-records a mistaken GO/NO-GO in place (active or completed), operator-only, --reason required, lo
- T-4326 — fw rail status resolves the host fingerprint with TERMLINK_IDENTITY_FILE/AGENT_ID/IDENTITY_DIR unset (inside the $() sub
- T-4334 — G-020 block title and Policy label name one rule (Build readiness gate) from a shared G020_RULE; origin kept as a traili
- T-4335 — G-118 degraded-hook repair line names the real unparseable file (.agentic-framework/bin/fw in a consumer, bin/fw in the 
- T-4392 — fw vendor self syncs and checks tools/ (new _self_vendor_tools class, audit scan covers it); vendored tools/ refreshed
- T-4400 — secret scan-staged 198 s -> 3.3 s on fw init's bootstrap commit, same coverage — diff streamed via temp file (no 57 MB b
- T-4403 — install-hooks owns only a marked block per hook — consumer lines outside it survive install-hooks/fw upgrade; unmarked h
- T-4405 — bare-from-consumer upgrade handoff replays the caller's argv exactly (minus target and --from-upstream) instead of re-de
- T-4406 — root-joining writers refuse an empty or / root — fw bvp driver --init, fw init, fw upgrade, context.sh ensure_context_di
- T-4424 — upgrade flag grammar declared once (_FW_UPGRADE_VALUE_FLAGS/_SWITCH_FLAGS); handoff replay keeps a value flag with its v
- T-4427 — fw init prints 'secret scan: N file(s) in S.s s' for the bootstrap commit's pre-commit scan — scan-staged records its ow
- T-4449 — pre-commit leg refuses a commit staging .tasks/templates/*.md while the staged lib/upgrade_template_shipped.py differs f
- T-4453 — fw upgrade run from a framework checkout vendors that checkout, prints Commit: <sha> (<tag>)
- T-4455 — reviewer judge derives pages from backticked path+query and own-Watchtower full URLs (never foreign origins); regression
- T-4490 — green-degraded panel closes — a rung-5 panel whose only missing seats are provably UNAVAILABLE (signed start + completio
- T-4494 — a sidecar restarted with a clean env (cron/supervisor after fw upgrade) signs with the project key — termlink_env select
- T-4498 — refused fw upgrade no longer self-vendors first — sync moved below every pre-write refusal
- T-4500 — pre-release notices say upgrade from a non-shallow clone
- T-4503 — fw upgrade creates the directory skeleton only after step 1's CLAUDE.md refusals, so a refused upgrade leaves the consum
- T-4504 — fw upgrade's Commit: line excludes -be tags in git describe, turning t4431_be_tags test 11 green
- T-4519 — verdict ledger — a runtime-attested green whose worker was killed after committing (signed exit != 0) is VOID: audit gra
- T-4522 — docgen memoises episodic/learnings loads per run (fw docs --all ~40 min -> 32 s) + DOCGEN_OUTPUT_DIR override; fw_docs/d
- T-4523 — unit-suite tree guard — runner snapshots the checkout before/after each tier (unit_tree_guard.py) and a run that changes
- T-4524 — unit-suite runner unsets agent-session variables (CLAUDECODE, CLAUDE_*, TERMLINK_SESSION_ID, FW_DISPATCHED_WORKER, FW_SI
- T-4526 — temp creators clean up on every exit path — reviewer/bvp-judge dispatch scripts self-remove (and on failed dispatch) and
- T-4528 — commit-msg foreign-delete guard — refuse a staged deletion of a file whose last commit names another task unless the mes
- T-4530 — a draining inbox.pending steps over a shown post only when the receiver store holds it (peeked/alert-marked posts were s
- T-4531 — fw sidecar inbox drains only dm rails on this project's own key; host-keyed rails kept in view by the T-4311 transition 
- T-4539 — runme_queue docstring example no longer teaches a cwd-relative bin/fw job argv (T-3952 lint red since 7c43266c2); vendor
- T-4563 — foreign-delete guard exempts pure re-vendor commits (every staged path under .agentic-framework/); refusal names the san
- T-4566 — fw upgrade Commit: line labels the vendored revision via git tag --points-at (release tag preferred, -be tag as fallback
- T-4571 — /file/ serves top-level docs/*.md — is_viewable_path admitted only listed docs/<subdir>/ prefixes, so docs/style-guide.m
- T-4572 — fw build installs lib/ts declared deps (npm ci from lockfile) when node_modules lacks any — clean machines had no js-yam
- T-4581 — hoist the two doctor heredocs out of $( ) — arc-driver-reviewer and continuous-run checks read their python into a var (
- T-4584 — stale-index guard refuses a staged .tasks/completed/ blob with a non-null horizon (the R100 git-mv of an unclosed task i
- T-4597 — create-task falls back to framework templates when the project has none; inception start surfaces create-task refusals i
- T-4602 — validate-init no longer aborts silently under set -euo pipefail — provider grep (no provider: line), __PROJECT_NAME__ gr
- T-4608 — comment_strip.py decodes stdin as strict UTF-8 bytes, not via the locale — under C/POSIX/unset (PEP 540 UTF-8 mode) and 
- T-4609 — unit-suite pytest leg runs with PYTHONDONTWRITEBYTECODE=1 so importing a test file no longer writes __pycache__ into the
- T-4618 — fw_costs.bats and fw_plugin_audit.bats build their own ~/.claude fixture under a temp HOME (transcript JSONL; enabledPlu
- T-4622 — resume hook's helper-path override renamed FW_DOCTOR_HOOK_EXERCISE -> FW_RESUME_HOOK_EXERCISE_HELPER — T-4523 made FW_DO
- T-4623 — pre-push structure audit drops ~110s of repeated work — arc staleness walks the 30-day window once (was one git log per 
- T-4720 — fw vendor writes only changed files (rsync -rlpgoD --checksum; cp fallback stages + cmp) so a no-op re-vendor leaves web
**hooks/gates (43)**

- T-2772 — port-3000 gate sees env-var assignments (FW_TEST_PORT=3000 etc.), not only URLs; 6 regression tests; sweep names live ca
- T-2958 — P-011 refuses Verification lines whose backticks bash would command-substitute ("``" collapsed to "" and passed emptily)
- T-2998 — CTL-008/CTL-010 count with --no-merges — git-default merge subjects (admitted by the commit-msg hook's MERGE_HEAD exempt
- T-3079 — fw doctor + fw audit WARN on pending Tier 0 approval cards older than APPROVAL_PENDING_WARN_HOURS (24) — shared predicat
- T-3924 — fw config set/get resolve keys against the registry case-insensitively (inception_commit_limit -> INCEPTION_COMMIT_LIMIT
- T-4190 — decide failure names the filtered-refusal shape (gate refused with an agent-only message) instead of 'Unknown error'; tr
- T-4258 — doctor/audit report INFO, not the R14 WARN, for an absent sidecar watcher on a fresh init whose SessionStart sidecar-aut
- T-4285 — task gate judges a Write/Edit into .tasks/completed/ by the record's own (closed) task, not focus; sanctioned routes: Up
- T-4317 — in fw hook context a valid CLAUDE_PROJECT_DIR wins over the cwd's project (T-2446 kept for non-hook calls)
- T-4327 — unconfigured rail from_project label is the verbatim project dir name (the sidecar/pickup fleet id), not a lower-cased s
- T-4336 — human-AC tick guard — Bash write to a .tasks path provably outside PROJECT_ROOT is allowed
- T-4343 — git -C / --git-dir / --work-tree SAFE only inside PROJECT_ROOT (realpath, cumulative, cd-tracked)
- T-4344 — boundary read scanner keys free-text options per command, not one global set
- T-4353 — resume hook header names the real SessionStart source — auto-restart/resume no longer told 'Post-Compaction' (GH #96); r
- T-4354 — Watchtower smoke test takes --url and fw doctor passes the URL its /health gate resolved (FW_HOST-aware), instead of pro
- T-4361 — boundary gate follows the running account's $HOME for .claude/.local zones; BOUNDARY_EXTRA_READ_PATHS adds read-only pat
- T-4367 — git diff/log/show/diff-tree/diff-index/whatchanged --output is a write, not a read (allowlist + write scanner)
- T-4368 — classify git check-attr, check-ref-format, diff-index as read-only (diff-index --output stays refused)
- T-4379 — test-isolation lint (live-audit / repo-state / fw-no-temp-root) as a WARN in fw test lint with a per-file count baseline
- T-4386 — fw doctor 199 s -> ~60 s — costs current parses only the newest transcript (usage lines only), resolver stalled caches a
- T-4395 — boundary read check judges >=2-slash paths under an existing top-level dir outside KNOWN_TOPS (NAS mounts, /work, /data)
- T-4396 — safe-commands accepts read-only for/while/until loops (body + word list judged per command, fail-closed otherwise)
- T-4408 — GIT_DIR/GIT_WORK_TREE/GIT_COMMON_DIR/GIT_INDEX_FILE/GIT_OBJECT_DIRECTORY prefixes admitted only inside PROJECT_ROOT; den
- T-4409 — git judged from its effective cwd (tracked cd, payload cwd, PWD only when it is PROJECT_ROOT), fail closed when unknown;
- T-4422 — classify 'git version' as read-only (T-2888 guard; used by T-4417's test stub)
- T-4431 — -be pre-release tags never count as the latest release — shared lib/release-tags.sh (release_tags_latest/describe with -
- T-4461 — doctor hook exercise reports a timed-out probe as 'not determined (timed out)' (WARN), not a failed resolve; header gain
- T-4469 — inception commit gates skip reviewer verdict-only commits (.context/reviews/); refused verdict commit unstages its rows
- T-4485 — git --output check judges the words bash hands git (shared shell_write_scan.git_output_risk: dequoted, brace-expanded; $
- T-4487 — boundary scanner refuses a git diff-family word that may expand to --output when the command names an outside path
- T-4491 — runme job queue slice 1 — fw runme job new|dry-run|list|retire + fw runme queue; jobs are job.json data run out-of-proce
- T-4492 — runme queue slice 2 — per-step sha manifest over job.json and every file a step reaches (args, sh/helper words, resolved
- T-4501 — corpus_spec round-trips bpmn:boundaryEvent (attachedToRef, cancelActivity, event definitions verbatim); host must be an 
- T-4516 — stop shipping LAN addresses — placeholders/runtime OLLAMA_HOST in shipped code, docs, policy, web; tools/lan-address-lin
- T-4535 — inception sweep closes GO/NO-GO inceptions through update-task's gates (no sed status edit), reports+exits 1 when a gate
- T-4536 — curl/wget option check honours an expansion of a literal the same line assigned (WURL=x; curl "$WURL/") — T-4512 over-bl
- T-4542 — pre-push names the audit-lock holder (pid, job, age) at once and while waiting; cron audits yield to a waiting push via 
- T-4552 — G-122 doctor check ignores old framework hook lines (VERSION markers, comments, any line of a shipped hook template via 
- T-4562 — /resume step 5 uses new read-only 'fw watchtower reachable' (resolves URL, checks identity) instead of WURL=$(cat …); cu
- T-4624 — review links reach the operator as full URLs — Watchtower resolves $(…fw watchtower url)/path and backticked route paths
- T-4634 — gate tests/integration — nightly integration-suite job, own report, graded by fw audit; 7 reds filed (T-4640..T-4646)
- T-4639 — Write/Edit gate no longer exempts .git/config, info/attributes, hooks/ — no task = refused; with a task a newly set exec
- T-4719 — close hint pushes to a named remote — git push <upstream|only|origin|first> HEAD, omitted with no remote; paths %q-quote
**watchtower/web (27)**

- T-2768 — designer not-synced guidance names all three sources (install / sync --from-tag / sync --from) and the LAN precondition 
- T-4238 — install.sh and fw doctor check PyYAML (hard) and the Watchtower Python stack (soft) with a PEP 668-safe hint (apt names 
- T-4311 — sidecar termlink calls sign with RAIL_IDENTITY_FILE behind SIDECAR_RAIL_IDENTITY (one helper, applied at every entry poi
- T-4320 — arc close accepts only CLOSE/KEEP-OPEN as the close verdict
- T-4323 — Watchtower stop removes the UFW rule start added (recorded in .context/working/watchtower.firewall, only recorded rules 
- T-4337 — watchtower status survives missing ss (|| true on port pipeline); lib/watchtower.sh + watchtower-staleness.sh use shared
- T-4347 — standing permission for GitHub decision comments (ISSUES_DECISIONS_STANDING_PERMISSION, default 0)
- T-4350 — incremental reindex updates small deltas in place (no full-size scratch copy)
- T-4351 — fw cron generate staggers index-reindex-hourly per project (hashed minute unless pinned) + INDEX_REINDEX_INTERVAL_HOURS 
- T-4363 — warm Watchtower corpus caches on a startup thread; smoke probe waits for warm-up
- T-4394 — key /approvals readiness cache on the commits that concern each task (mention, task file, task-independent validator inp
- T-4402 — lens placement follows INSTRUCTIONS §2.2 / 832 T-281 (contextReads/artifactsWrites/scopeOf, ids, authority marker -> tec
- T-4407 — sidecar waiting card sanitizes stderr at the raise site, before the 300-char tail, so a reason followed by bypass lines 
- T-4432 — Watchtower cron pause/resume renders the crontab via lib/cron_dry_run.render_crontab (same as fw cron generate, keeps T-
- T-4458 — /search never 500s — keyword index built per-dir under a lock, served stale while rebuilding; vector leg under a 10 s de
- T-4459 — untrack watchtower.log (git merges replaced its inode under the live server) + doctor WARN when Watchtower's stdout/stde
- T-4460 — watchtower start polls /api/_identity (not GET /) for WATCHTOWER_START_TIMEOUT (60 s); on expiry it stops its server and
- T-4467 — add WATCHTOWER_START_TIMEOUT to the /config registry (web/blueprints/config.py) — parity with lib/config.sh after T-4460
- T-4468 — /search/ask stream imports _db_opened_at (renamed in 0ed2f00f2); regression test iterates the SSE body
- T-4475 — reindex embeds batches through FW_EMBED_WORKERS threads (order preserved; default 1, serial), key registered in lib/conf
- T-4547 — basename/tree caches age from walk end; T-3736 tests use a fake clock and empty walk
- T-4590 — Watchtower decision commit carries the Human-tick ledger (decide's provenance row was left uncommitted and lost to a git
- T-4607 — designer map thumbnails rendered server-side — web/designer_thumb.py drives the pinned designer's own captureThumbnail()
- T-4617 — detached-HEAD-safe fixtures — t3698 _overlay pushes an explicit branch; cockpit git-info test expects the checkout's rea
- T-4663 — board 'Awaiting review' column also admits partial-complete (agent done) tasks without a reviewer verdict; one predicate
- T-4713 — SCRATCH_WARN_GB in web/blueprints/config.py (config registry parity invariant was red, blocked every push)
- T-4715 — designer gallery cards show their latest diagram picture (/api/thumb); the page never rendered it
**other (113)**

- T-2749 — doctor's stray-root-marker check covers /.tasks as well as /.framework.yaml (the full resolver marker set); test seam FW
- T-2859 — fw work-on usage example carries --type (create-task.sh requires it off-tty); regression test runs every printed example
- T-2913 — commit the rail-identity labelling for in-repo scripts that its worker left uncommitted (task closed against the working
- T-3143 — audit C-001 PASS requires no unreferenced-artefact WARN either (c001_unreferenced counter); regression bats t3143 (2 tes
- T-3154 — doctor's agent-executable check enumerates entry scripts from disk and states its count (was a hardcoded 7-item list pri
- T-3160 — fw cron install --dry-run renders into a scratch file (FW_CRON_GENERATE_OUT) instead of rewriting the tracked crontab so
- T-3162 — generated cron lines end '; exit ${PIPESTATUS[0]}' so cron sees each job's own exit status through the logger pipe — lib
- T-3709 — build-class dispatches no longer take their model from the route cache (config, then opus); dispatch prints the resolved
- T-3720 — fw termlink dispatch refuses an empty or whitespace-only prompt before spawning; regression bats
- T-4094 — close stages the completed task file and its episodic, hint names the exact pathspec (never-committed tasks no longer le
- T-4180 — archive-eligible sweep also closes started-work tasks with every AC ticked (CTL-029 class); CTL-029 names the sweep; swe
- T-4215 — unit-suite runner gives each test file its own TMPDIR under the run's results dir and removes it when the file ends, kil
- T-4228 — verify-queue --task keeps the rotation ts of a still-red task (CTL-013b)
- T-4230 — handover commit label no longer borrows any task whose slug mentions handover; reuse only the active session-handover-ma
- T-4241 — fw work-on --help/-h print usage + flag list and exit 0 instead of falling into the create path as a task named --help; 
- T-4256 — vector-index check reports a never-built index inside its init grace window as SKIP (overall OK), not WARN; cron FAIL an
- T-4259 — doctor/audit cron dry-runs render with the fw path generate writes — cron_fw_path in lib/cron-registry.sh is the one rul
- T-4260 — untracked-task doctor check lists every file project-relative (ls-files --others, not porcelain -unormal) and never offe
- T-4292 — pid_alive reads a zombie as dead — a receiver started and stopped in one process (Popen child, unreaped) stayed 'alive',
- T-4315 — test_t4283 cleanup stopped the REAL sidecar; stop requests now record their caller
- T-4330 — firewall advisory when ufw is absent — LAN bind prints one 'ufw not installed' line, loopback stays silent; no-ufw PATH 
- T-4333 — fw onboarding skip shelves unfinished onboarding tasks (horizon: later, started-work -> captured) instead of leaving the
- T-4340 — release posts stage 9 on linked GitHub issues per the close rule
- T-4341 — task lifecycle posts in-progress / fixed-on-bleeding-edge on the linked GitHub issue (fw issues lifecycle; never blocks 
- T-4342 — issues sync treats owner-authored issues as internal (ledger row, no post); unpause issues-sync-2h
- T-4346 — fw issues release — Released block carries summary, tests, full-suite comparison, decision and tag links, with hosts scr
- T-4348 — fw sidecar send --notice — delivered and labelled 'notice — no reply expected', never chased (hub: closed at delivery, o
- T-4349 — log_bypass keeps the log parseable (indent matches existing sequence; failed post-append parse returns 1)
- T-4352 — auto-restart docs state the real default — fresh session (FW_RESTART_MODE=fresh, T-3166), continue = --resume opt-in; GH
- T-4357 — fw doctor decides resolver-loop.timer presence from the unit listing, not list-unit-files' exit code (systemd 245 exits 
- T-4358 — fw doctor WARNs on an unarmed turn driver only when continuous mode was armed (enabled: true) and stopped; never-armed/d
- T-4364 — fw release refuses unattended runs without a recorded per-version release decision; fw release decide
- T-4369 — framework repo ignores an inherited FRAMEWORK_ROOT naming its own vendored copy; claude-fw pins the repo first
- T-4370 — fw audit WARN for issue-ledger lag (G-119 detection)
- T-4373 — log_bypass emits action/reason as YAML single-quoted scalars
- T-4374 — corpus_spec accepts bpmn:callActivity — calledElement, aef:ioMapping v1 (in/out source+target) and sibling aef:callRef r
- T-4375 — structure audit 651 s -> 325 s — SC2006 cache, stub shellcheck in silent-skip wiring leg, batched git reads in human_ac_
- T-4377 — an unassigned test file runs in slow with a WARN instead of refusing the whole suite run (8 new test files would have st
- T-4381 — unit-suite runner — exit 5 without skips is red, discover every pytest file (348 vs 316), per-file timeouts keep a run o
- T-4387 — corpus_spec keys extension children by namespace AND local name; foreign children pass through ext_raw (nodes and flows)
- T-4388 — corpus_spec preserves unmodelled node children (loop characteristics etc.) verbatim, re-emitted in BPMN schema order
- T-4389 — corpus_spec carries qualified node attributes + their xmlns, and keeps source prefixes on verbatim parts (no ns0:)
- T-4390 — recall health and fw cron status require the job to be deployed, not just in the registry
- T-4391 — fw ux shots state=@steps.yaml — declarative interaction states, steps sha256 in capture manifest and signed review run
- T-4397 — audit lock held by a holder that launches the body with the lock fd closed (orphan children no longer keep the lock); bo
- T-4399 — corpus_spec keeps BPMN default="<flow>" on gateways/activities through parse/emit; hard error unless it names a sequence
- T-4401 — audit-lock lottery — audit.bats live calls run on a fixture project, t3443 control uses lockless --check, lint + test re
- T-4410 — audit --help names deployment as the opt-in exception to the --section default; pin with synthetic-project bats test
- T-4411 — issue area from the component fabric via policy/issue-areas.yaml; area:/severity: labels at Classified and refined on ta
- T-4412 — status:* labels are mutually exclusive — a stage's edit removes the other status labels (and the legacy unprefixed fixed
- T-4413 — recall-health cron check WARNs (not installed yet) when no crontab is deployed; FAIL kept for a deployed file lacking th
- T-4416 — a dispatched worker no longer restarts the project sidecar under its identity — autostart + ensure skip workers / foreig
- T-4417 — bound every git/python3/fw read in the audit body — file-backed when stdout is a pipe (an orphan holding it no longer bl
- T-4418 — a send to an explicit circuit nothing reads is refused (--force to override) naming the known candidates; peer-directory
- T-4419 — vendor self --check --task T-XXXX / --paths scope the check to a task's own files
- T-4421 — fabric describe reads .mjs/.cjs/.mts/.cts headers and skips a leading shebang (832)
- T-4423 — enabled.json can no longer persist a worker's agent id — start/receiver start refuse a non-project agent (--force/--i-am
- T-4425 — fw test lint no longer dies rc=141 — ShellCheck findings printed/classified via here-strings instead of echo|head and ec
- T-4430 — task_debt.py parses last_update as a YAML scalar (quoted/unquoted, date-only, Z/offset); missing or unparseable values c
- T-4433 — fw doctor shows task_debt.py's 'unparsed: N (files)' stderr as a WARN detail (bin/fw no longer discards it); regression 
- T-4436 — fw doctor no longer exits at the task-debt check when nothing is unparsed (grep|head under set -euo pipefail, from T-443
- T-4437 — fw review isolated-run — external review seats run outside the repo, tools off, bundle only, one at a time
- T-4441 — regenerate shipped task-template hash list (--gen-known) for T-4419's default.md edit; vendored copy synced
- T-4445 — lane-overflow NODE_OCCUPANCY gains 'call' (64, activity box) — T-4374 added callActivity without it, so its lanes would 
- T-4448 — re-pin designer 0.23.0 -> 0.24.0 (832 announce c859278f; one-way exclusive-gateway finding E->W, exit 2->1), sha256 veri
- T-4450 — unit-suite.sh _run_one strips the runner's own FW_UNIT_SUITE_* control env from bats/pytest children (nested runners inh
- T-4452 — sidecar inbox read that times out/fails is NOT CHECKED, never an empty inbox
- T-4456 — a harness seat whose verdict the ledger refused is reported verdict-refused with the reason, not unavailable: exit 0; op
- T-4457 — name the provider error in an unavailable seat's reason (opencode 'Unexpected server error'); model pin + closed stdin p
- T-4464 — fw runme watch --until start|exit — return at the START marker so an agent can report the run began, then re-arm for exi
- T-4465 — partial-complete re-close applies reviewer verdicts like the first close
- T-4473 — approve-driver --scoring-file stores the spec inline as scoring: (validated before append, round-tripped through the est
- T-4476 — handover marks itself enrichment_status: pending, honest Gotchas placeholder, mechanical-fallback disclosure under Sugge
- T-4478 — fw bvp confirm appends a confirmation telemetry row (proposed vs confirmed, delta, no-signal count) to .context/telemetr
- T-4480 — lib/pickup.sh refuses constant sha256('||') dedup hash and content-free pickup tasks; refused envelope stays in inbox (t
- T-4481 — sidecar injector targets an untagged TermLink session named by a live session record (WARNs, no silent tmux fallback)
- T-4482 — sidecar resolves TermLink runtime dir like the hub (env, else /var/lib/termlink), logs it, warns on empty discover with 
- T-4486 — fw bvp rank excludes all-no-signal proposals from medians and quadrants, lists them in a NOTE
- T-4488 — corpus_spec accepts plain bpmn:task (TYPE_TO_TAG 'task', DEFAULT_FLOW_TAGS) and lane-overflow occupancy 64; regression t
- T-4493 — runme queue slice 3 — ordered batches (typed order or x), refused up front if any job not ready, stopped at first failur
- T-4495 — corpus_spec accepts bpmn:businessRuleTask (TYPE_TO_TAG 'business-rule', DEFAULT_FLOW_TAGS) and lane-overflow occupancy 6
- T-4496 — corpus_spec generate refuses a spec with no id (null/missing/blank/non-string) naming top-level id:, instead of Attribut
- T-4497 — claude-fw resolves -c/--continue to --resume <this session's conversation>, never a claude -p worker's
- T-4502 — corpus_spec parse refuses a document whose extra bpmn:process has content (names each, with child count) instead of sile
- T-4505 — corpus_spec round-trips every remaining BPMN 2.0 process flow node (send/receive/manual task, inclusive/complex/eventBas
- T-4506 — re-pin opencode seat to zai-coding-plan/glm-5.3 (glm-5.2 retired; operator "1 yes"); pinned-model preflight (lib/review_
- T-4507 — green-degraded — a seat whose verdict the ledger refused is not unavailable; regression test
- T-4514 — recorded review evidence is immutable — _commit_rows restores committed evidence a later run moved/deleted/changed; judg
- T-4518 — corpus_spec carries unknown aef: extension content verbatim or refuses naming it — unmodelled attrs on structured elemen
- T-4521 — bats <1.11 counted heredoc fixture @test lines as real tests (duplicate-name abort on Ubuntu 24.04's bats 1.10); 10 file
- T-4534 — inception decide on a captured inception no longer loses the started-work write — update-task runs the BVP estimator in 
- T-4545 — t3298 watchdog-leak test tracks its own run via env marker, not host-wide sleep-1 orphans; watchdog trap kills $! (no fo
- T-4548 — mapping standard v1.1 normative text for structured aef:io (fields, expectations, prefix map)
- T-4549 — corpus_spec models v1.1 aef:io (attributes, aef:field/when, aef:expect/value, aef:example) and process aef:meta (mapping
- T-4550 — corpus lint rules for mapping v1.1 aef:io (keyed op needs match field, undetermined key, expect vs type, prefix unknown/
- T-4551 — forward compile reads aef:io (v1.1) — io list + AC seeds, §1.5 version refusal, §4.3/§4.4 warnings; options+recommendati
- T-4558 — fw termlink cleanup — project-scoped, live regex from DISPATCH_WORKER_KINDS, uncollected results kept
- T-4560 — receiver accepts a token rewritten while it runs (rotation + T-4208 refused restart made every send 401); pin send exit 
- T-4561 — dispatch into a reused worker dir refuses a live/uncollected previous run, else moves its files to prev-<ts>/
- T-4577 — checkpoint.sh directive fold — fix IndentationError in embedded python so the auto-handover restart signal carries .next
- T-4578 — sandbox stale check is path-independent — stale_status re-renders at the root recorded in the emitted manifest, so a clo
- T-4582 — fw termlink wait checks exit_code before the event wait and waits in 5 s slices under one deadline — a worker.done emitt
- T-4591 — verdict commits now also stage the dispatch registry, runs and completions their rows are verified against (_ledger_path
- T-4594 — find_task_file returns 0 on not-found; inception-decide unknown task no longer exits silently
- T-4612 — audit frontmatter check WARNs instead of skipping silently when web.shared cannot be imported; test runs audit with its 
- T-4633 — re-pin designer 0.24.0 -> 0.25.0 (832 announce a061bcad, src 2b6bd876; aef:io v1.1 read-only + lossless save, lens switc
- T-4637 — drop duplicated placement block in audit.sh (hunk landed twice: T-4634's commit carried it from the shared tree, then 18
- T-4660 — act on submitter replies — classifier, fw issues replies/confirm-close, sync auto-close, operator-pending + session aler
- T-4664 — confirm-close records a submitter's confirmed fix as a WORKS row in docs/reports/field-test-submitter-confirmations.md; 
- T-4668 — issue replies gain a close-ok class (submitter OKs closing); confirm-close takes close-ok and --note; sync auto-closes c
- T-4669 — fw issues reply-ack settles one no-action submitter reply with a reply-acked ledger row (nothing posted); _undecided_rep
- T-4676 — cron estimator sweeps commit their own writes (one commit per sweep, only files they wrote, skip files already dirty)
- T-4726 — inception review hint derives the decide verb from the parsed Recommendation (GO/NO-GO/DEFER); unparseable prints go|no-

</details>
