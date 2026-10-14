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

Not yet field-tested by anyone: T-4122, T-4131, T-4132, T-4137, T-4147, T-4152, T-4153/T-4154,
T-4156, T-4162/T-4163 (estate pilot not yet live), T-4167, T-4171, T-4191, T-4196, T-4197.

## Findings

- **T-4203** (055 item 7): `_fw_is_own_launcher` / `cmd_classify._Ctx` refuse a consumer's tracked
  `bin/fw` shim, so `bin/fw git commit` and `bin/fw handover --commit` are refused at critical
  budget — the wrap-up commands CLAUDE.md prescribes. Blocks the no-ask release path until fixed
  or the release notes tell consumers what to do.
- **T-4204** (055 follow-up, pre-existing): the commit-checkpoint allowance admits an env-prefixed
  launcher (`PROJECT_ROOT=/x … fw git commit`) that the classifier refuses.
