# T-3083 — `fw doctor` profile (2026-10-17/18)

Method: `bin/fw doctor 2>&1 | while read l; do printf '%s %s\n' "$(date +%s.%N)" "$l"; done`
(per-line timestamps; `bash -x` is useless because `bin/fw` re-execs). The gap before
each output line is the cost of the check that printed it. Doctor's own T-3452 phase
summary is quoted where it adds detail. Host: load average ~18-24 during every run
(other workers active). There was no idle window, so the numbers below are loaded numbers.

## The August profile no longer describes the bottleneck

The task was filed on a 2026-08-18 profile: large-file gate 96.6 s, test-infra 75 s,
TermLink 74 s. In the meantime:

| August offender | Status before this task | Evidence |
|---|---|---|
| Test infrastructure (bats `--count` over 4174 tests) | already fixed by T-3324 (counts files, <1 s) | `bin/fw` Check 9 comment; not in today's slow list |
| Large-file gate (per-path `stat` fork) | already batched (`git ls-files \| xargs stat`) | `agents/git/lib/large-file-scan.sh:168-181`; not above 3 s today |
| TermLink 74 s ("a timeout being hit") | `termlink --version` now 0.015 s, `channel list` 0.10 s | no longer reproduces; that day's hub timeout is gone. Today's 45 s TermLink phase is a different cost (below) |

## Run 1 — before (2026-10-17 ~23:58, load 18.8)

Killed at the 600 s harness limit. Doctor did not finish. Gaps above 3 s up to the kill:

| Gap | Check |
|---:|---|
| **425.8 s** | **port3000 hygiene ratchet** → `WARN … 7454 carriers (3159 citations), 6642 new since baseline` |
| 11.7 s | vector index opens |
| 7.2 s | hook exercise from /tmp |
| 6.5 s | plugin task-awareness |
| 4.5 s | design-conformance register |
| 3.9 s | fabric under-populated cards |

Isolated measurements of the remaining offenders:

| Check | Cost | Cause |
|---|---:|---|
| `fw_sidecar_held_unsurfaced_facts` (TermLink phase) | 30.7 s (48 s under cProfile) | N+1: one full receipts-ledger parse per held message — 90 msgs × ~36k rows = 3.24M `json.loads` |
| port3000 walk alone | 23 s, 159,954 files | 140,853 of them in gitignored `.context/scratch/` (7.5 GB) |

## Fixes

1. `tools/port3000_hygiene.py` — enumerate with `git ls-files -co --exclude-standard`
   (tracked plus untracked-not-ignored; os.walk fallback outside a git work tree; the vendored
   mirror and worktree exclusions still apply). Add a `":3000"` substring precheck before every
   regex search (exact: every HIT_RE match contains it), and skip tokenizing `.py` files
   that have no hit. **425.8 s → 9.7 s.** The verdict stays WARN but is now true: 774
   carriers / 16 new vs. baseline. Before, 6642 of the "new" carriers were gitignored
   scratch copies the 812-entry baseline never contained.
2. `lib/sidecar/inject.py:held_unsurfaced` — one `seen.withheld(all_ids)` and one
   `seen.shown()` for the whole set instead of per message. **30.7 s → 0.73 s**, same rows
   (old per-id loop vs. new: identical set on live data).

## Run 2 — after both fixes (2026-10-18, load 19.6 / 23.7 / 22.4)

**Total 247 s** (run 1 did not finish in 600 s). This run measured the port3000 fix only;
the held-unsurfaced fix landed after it. Doctor's phase summary:

| Phase | s | Note |
|---|---:|---|
| Watchtower smoke test | 89 | 53 endpoints probed **sequentially**, 5 s urlopen timeout each (`web/smoke_test.py:122`); 11 endpoints timed out (`/`, `/approvals`, …). The cost is the verdict: those pages really are over 5 s on this server. Not changed here — see Open |
| TermLink checks | 45 | held-unsurfaced 30.7 s of it → fixed after this run |
| port3000 hygiene ratchet (phase incl. MCP/index checks) | 33 | ratchet itself 9.1 s |

## Run 3 — after all fixes

**Total 190 s, exit 0** (load 13.9 / 19.9 / 22.0). Slowest phases: Watchtower smoke 89 s,
port3000 phase 33 s (ratchet ~9 s of it; the rest is the MCP / vector-index checks in the same
phase), plugin task-awareness 20 s. The TermLink phase dropped out of the top three
(under 20 s, was 45 s). Every check still printed its line. The port3000 ratchet still WARNs
(775 carriers, 17 new, 54 stale — real figures now).

Progression: did not finish in 600 s → 247 s → 190 s. Without the smoke sweep (`FW_DOCTOR_SMOKE=0`)
it is roughly 100 s at this load. The < 60 s idle target was **not met and could not be
measured idle** (the host never dropped below load ~14).

## Doctor bats

`tests/unit/*doctor*.bats`, 32 files, run sequentially after the port3000 fix:
**185 ok, 4 not ok.**

- `doctor_designer_pin_drift.bats`: **591 s, 5/5 ok.** It hit the 900 s per-file cap in the
  2026-10-17 nightly run (T-3778/T-3801 class); it now finishes under the cap.
- The other nightly-capped files now finish: `t2243_doctor_self_vendor_templates` 377 s,
  `t2290_doctor_mcp_content_check` 278 s (3/3), `test_doctor_scope_tags` 449 s (14/14).
- `doctor_hook_counters.bats` — not ok 2, 3, 4 (T-2714 hook-counter wording). The same
  three already failed in the nightly baseline (`.context/audits/unit-suite/LATEST.yaml`).
  Not caused by this change.
- `t2243 t1` — asserts real-repo doctor exits 0|1. During that run doctor exited 2 on the live
  `FAIL Sidecar watcher NOT live: receiver not running` (host state). The receiver came back
  before run 3, which exits 0. Not caused by this change. This test file had no
  result in the nightly run (it timed out).

## Open (not done here)

- **Watchtower smoke (89 s).** It is bounded by `53 × 5 s` serial probes. The 11 timeouts are
  real slow pages (a Watchtower performance matter, not a doctor one). Making the probes
  parallel would cut wall time, but it changes the load the smoke test puts on the server,
  and with it the verdict (more timeouts under concurrency), so it needs its own task.
  `FW_DOCTOR_SMOKE=0` already exists for test callers (T-3933).
- The < 60 s target is not reachable on this host while load average sits at ~20 and the
  smoke sweep alone is ~89 s. Idle numbers could not be taken: there was no idle window.
