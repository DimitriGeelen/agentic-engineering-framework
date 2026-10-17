# Field evidence for v1.8.11 (bleeding-edge after v1.8.10)

Positive field tests from other agents are the release approval (T-4146). One row per fix;
a fix with no positive row blocks the no-ask release path.

| Fix | 055-agentic-fleet-cockpit (e63ffd423, vendored, 2026-10-14, msg 913410c4) | 832-Workflow-designer (1146a7450) | ring20 |
|---|---|---|---|
| fw upgrade (vendored, fresh clone, dry run first) | WORKS — doctor 0 FAIL before/after | upgraded, healthy (0 reverted) | — |
| T-4127 / T-4081 Watchtower decisions + detector (G-114) | WORKS — nothing staged; 0 reverted / 60 d; Watchtower restarted onto new code | WORKS (0 reverted) | v1.8.10 live check PASS |
| T-4166 / T-4200 index reconcile + doctor regression | WORKS — upgrade did not abort; audit "no armed stale index entries"; doctor ran to end | — | — |
| T-4149 boundary hook lexer | WORKS — 5/5 outside writes exit 2, in-project 0 | — | — |
| T-4150 budget classifier tokeniser | WORKS — ; rm, $(..), backticks, <(..) blocked; quoted ; not split | — | — |
| T-4145 sidecar PEER-DATA framing | WORKS — body framed under UNTRUSTED header | — | — |
| T-4170 claude-fw restart banner | NOT EXERCISED (session predates wrapper) | — | — |
| T-4108 / T-4125 own-launcher check | BROKEN for a consumer with a tracked bin/fw shim → T-4203 | — | — |
| T-4133 readiness memoisation | — | — | round-1 retest 96.1 s → 43.7 s; round-2 retest pending |

## Round 2 — 832-Workflow-designer on bleeding-edge 495901b5d (2026-10-16, msg 5196b215)

Upgraded from 1146a7450 via re-vendor (39 local fixes re-applied, 0 conflicts, revert scan 0).

| Fix | 832 result |
|---|---|
| T-4210 lint skips non-shell shebangs | WORKS — "2 skipped non-shell shebang", 0 ShellCheck fail |
| T-4122 lint speed | NOT MEASURED (no before timing) |
| fw test lint in a consumer | **BROKEN** — exit 1: Silent-Skip lint reads `.agentic-framework/tests/` (absent in a consumer) → **T-4219** |
| T-4132 upgrade restart notice + doctor currency | WORKS — upgrade NOTE and doctor WARN both seen |
| T-4147 CONTEXT_WINDOW default | WORKS for "explicit value kept" (1000000); 800K default NOT EXERCISED |
| T-4167 stale-index pre-commit guard | WORKS — older .tasks blob refused with remedies; FW_ALLOW_STALE_INDEX=1 passes with Tier-2 WARN |
| T-4171 budget warn/urgent | NOT EXERCISED |
| T-4196 handover --no-push | WORKS for --no-push; push announcement NOT EXERCISED |
| T-4131 truncation names --show; long-body warning | WORKS — --show prints full framed body; 4500-char warning fires, short body silent |
| T-4207 held mail via prompt hook | WORKS for the hook; doctor/audit held-hours WARN NOT EXERCISED |
| T-4211 secret scan without catalogue | NOT EXERCISED (catalogue present; 39-file commit passed, no false hit) |
| T-4203/T-4204 | NOT EXERCISED (budget never critical) |
| T-4209 fw audit --check | WORKS — fabric-coverage 5.7 s vs 54 s for the structure section |

Not yet field-tested by anyone after round 2: T-4122 (speed), T-4137, T-4152, T-4153/T-4154, T-4156,
T-4162/T-4163 (estate pilot not yet live), T-4170, T-4171, T-4191, T-4197, T-4203/T-4204, T-4208,
T-4211, T-4216; partly: T-4147 (default), T-4196 (announcement), T-4207 (WARN).

## Round 3 — 832-Workflow-designer on bleeding-edge 956f05f36 (2026-10-17, msg 26c3e3cf)

Upgraded via re-vendor (38 local fixes re-applied, 0 conflicts; their 101-script sweep green).

| Fix | 832 result |
|---|---|
| T-4219 fw test lint in a consumer | WORKS — exit 0 (211 pass, 54 warn, 0 fail; Silent-Skip NOT APPLICABLE), was exit 1 |
| T-4223 /gaps register parse once + concurrent gauges | WORKS — real register 10-11 s → 3.8-4.1 s (5 runs, load 13); remainder is 832's own slowest gauge. (A suggested follow-up, T-4247, was closed as not needed: gauges already run only for watching gaps.) |

Other field results since round 2: 1409 upgraded 1.8.3 → 1.8.10 healthy (doctor 0 FAIL) and found G-117 (upgrade
drops consumer text in CLAUDE.md governance sections, T-4232); 1023 confirmed the env-leak mechanism behind T-4222.

## Round 4 — ring20 (proxmox-ring20-management) on bleeding-edge 112c098b9 (2026-10-17, msg 0d463b3e)

Upgraded vendored ed683536a → 112c098b9 (v1.8.10+579) from a pinned clone; their commit 6aa9e807c, rollback c4dce8461.

| Fix | ring20 result |
|---|---|
| T-4250 delegate writes the project-correct fw path | WORKS — `fw task delegate T-2400` wrote `.agentic-framework/bin/fw reviewer T-2400 …` (Verification, Updates close path and dry-run hint; no `bin/fw` anywhere); reviewer PASS auto-ticked the AC; `--status work-completed` ran the delegation-written line with exit 0 and completed. Was: 9 of 11 closes refused with exit 127. |

Side findings from the same upgrade: (a) step [1/10] rewrote CLAUDE.md governance sections before the vendor step's
T-3850 refusal, leaving CLAUDE.md ahead of the installed code (filed as T-4278); (b) doctor 3 FAIL before and after
(their pre-existing settings.json hook drift); (c) 2 merge conflicts in their locally patched files, resolved locally.

## Findings

- **T-4203** (055 item 7): `_fw_is_own_launcher` / `cmd_classify._Ctx` refuse a consumer's tracked
  `bin/fw` shim, so `bin/fw git commit` and `bin/fw handover --commit` are refused at critical
  budget — the wrap-up commands CLAUDE.md prescribes. Blocks the no-ask release path until fixed
  or the release notes tell consumers what to do.
- **T-4204** (055 follow-up, pre-existing): the commit-checkpoint allowance admits an env-prefixed
  launcher (`PROJECT_ROOT=/x … fw git commit`) that the classifier refuses.
- **T-4219** (832 round 2): `fw test lint` exits 1 in every vendored consumer (Silent-Skip lint reads
  the framework's own tests/, which a consumer lacks). Must be fixed before v1.8.11.
