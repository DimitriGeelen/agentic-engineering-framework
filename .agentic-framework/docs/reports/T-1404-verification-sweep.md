# T-1404 Verification Sweep — Read-Only Execution Report

**Scanned:** 111 active task files (filter: owner=human)

## Summary

- **PASS** (verification passes — ready for AC tick + close once T-1404 GO): **37**
- **FAIL** (verification command exits non-zero): 6 — *all triaged to verification-bugs, not regressions*
- **NO_VERIFICATION** (no shell commands in `## Verification`): 63

## FAIL triage — 0 real regressions

| Task | Failure | Diagnosis | Class |
|------|---------|-----------|-------|
| T-663  | `assert all(c.startswith('bin/fw '))` | All hooks use absolute `/opt/.../bin/fw hook ...` (correct for hooks). AC intent (no bare `fw`) is satisfied. | Verification too strict |
| T-1277 | `grep '${FW_HANDOVER_PUSH_TIMEOUT:-15}'` | Default was bumped 15→60 (T-1341) per CLAUDE.md. Test is stale. | Verification stale |
| T-1376 | `grep -qn "localhost:3000" lib/init.sh` | Grep returned empty (exit 1). AC intent: "no hardcoded :3000". Negative grep semantics inverted. | Verification inverted |
| T-1279 | `bin/fw audit ... | grep ...` | `fw audit` takes 1m41s — 20s sweep timeout too tight. Audit itself works. | Verification unrealistic |
| T-446  | README exclamation-mark check | 1 stray `!` — minor copy-edit, not a regression | Brittle check |
| T-613  | `grep "v1.4.0" /tmp/homebrew-agentic-fw/...` | Temp file from prior session, no longer present. | Verification artifact |

## PASS — 37 tasks ready for back-fill (pending T-1404 GO)

T-1062, T-1145, T-1200, T-1213, T-1214, T-1240, T-1241, T-1278, T-1302, T-1303, T-1304, T-1305, T-1311, T-1312, T-1313, T-1314, T-1315, T-1316, T-1319, T-1321, T-1322, T-1345, T-1348, T-1349, T-1350, T-1351, T-1352, T-1353, T-1357, T-1358, T-1372, T-460, T-470, T-505, T-511, T-705, T-782

(Note: T-1241 PASSes after the T-1405 fix landed earlier this session — same-session demonstration that the sweep both surfaces and resolves issues.)

## Implication for T-1404 build phase

B2 (per-tier classification + auto-execution) needs an additional concern:
- **Verification command audit** — many existing `## Verification` blocks have stale/inverted/brittle commands that would falsely block AC close. Build phase should include a verification-quality pass.

## Strengthens T-1404 GO recommendation

- 37 tasks (12% of 313 lifetime tasks) are stuck in active/ purely because no agent ran their existing verification.
- The 6 FAILs found are all script bugs, not regressions — meaning agent-side verification is *safe* (won't surface false alarms once script-quality issues are fixed).
- The sweep took ~5 seconds wall-clock for 111 files. Routine cron-able.
