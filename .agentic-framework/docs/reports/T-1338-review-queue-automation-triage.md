# T-1338: Review Queue Automation Triage

**Task:** T-1338 (inception) — classify 43 unchecked Human ACs by automation tier
**Date:** 2026-04-19
**Status:** Research complete, recommendation pending Watchtower review

## Source data

`fw verify-acs -v` output: 43 Human ACs across 41 tasks. 11 `[RUBBER-STAMP]`, 32 `[REVIEW]`.

## Classification

### Tier 1 — Programmatic (shell / curl / grep can fully verify)

| Task | AC | Evidence path |
|------|----|----|
| T-880 | Installer on test dir → `fw doctor` shows no WARN | `mkdir /tmp/test-install && bin/fw init /tmp/test-install && cd /tmp/test-install && bin/fw doctor \| grep -vq WARN` |

**1 AC. Low effort (one bats test).** Candidate for immediate auto-check via `fw verify-acs --execute`.

### Tier 2 — TermLink E2E (spawn session, inject commands, verify outputs)

| Task | AC | Approach |
|------|----|----|
| T-594 | Loop detection fires after 5th identical failing call | Spawn TermLink claude session, inject 6 failing reads, grep stderr for loop warning, check `.context/working/.loop-detect.json` |
| T-612 | Agent blocked → Watchtower approve → agent retries succeeds | Spawn claude-fw session, trigger Tier 0 command, curl POST `/approvals/<id>/approve`, inject retry, verify success |
| T-663 | Fresh Claude Code session hooks fire | Spawn fresh session via `termlink dispatch`, verify `.context/working/.tool-counter` increments |
| T-1277 | Auto-handover at critical does not stall push | Spawn session, force context to 285K (prompt-stuff), watch PostToolUse timing in `.context/working/.compact-log` |
| T-481 | `install.sh` twice on macOS | Via TermLink to ring20-management (.122 — macOS) or 050 Mac: `./install.sh && ./install.sh` |
| T-518 | macOS bash 3.2 compat | Same Mac host: `/bin/bash --version && bin/fw doctor` |
| T-613 | `brew upgrade` on macOS | Same Mac host: `brew upgrade DimitriGeelen/termlink/fw && fw version` |
| T-530 | `claude-fw --termlink` remote-attach works | Spawn local claude-fw --termlink, from sibling session `termlink attach <session>`, inject input, verify bidirectional |

**8 ACs. Medium effort (one bats/TermLink harness per family — Linux set: 4 ACs share infra, macOS set: 3 ACs share infra, edge case: 1).**

### Tier 3 — Playwright (browser automation)

| Task | AC | Locator / assertion |
|------|----|----|
| T-1240 | Tasks page shows T-1000+ at bottom when sorted by ID | `page.goto("/tasks?view=list&sort=id")` + assert element with `data-task-id="T-1239"` appears after `data-task-id="T-999"` in DOM order |
| T-1241 | /cron page shows last-run data for 10/11 jobs | `page.goto("/cron")` + count rows with timestamp vs "no data"; allow ≤1 "no data" |
| T-1214 | Inception cards on /approvals show recommendation OR fallback | `page.goto("/approvals")` + for each `.inception-card`, assert `.recommendation` or `.gonogo-criteria` visible |
| T-448.1 | Cron controls (pause/resume/run) work | `page.goto("/cron")` + click `[data-action="pause"]`, confirm dialog, assert row has `.paused` class, reload, still paused |

**4 ACs. Medium effort.** T-448.1 overlaps with T-971 playwright rule — this is the canonical example.

### Tier H — Genuine human (cannot automate; keep as-is)

#### Strategic go/no-go decisions (21 ACs)

T-1123, T-1200, T-1213, T-1251, T-1252, T-1253, T-1255, T-1260, T-1261, T-1302, T-1303, T-1304, T-1305, T-1311, T-1314, T-1316, T-1319, T-1321, T-1322, T-837, and T-1277 (separate GO/NO-GO on the fix direction). All `[REVIEW] Review exploration findings and approve go/no-go decision`. Framework authority model forbids automating these — "Agent proposes, human decides."

#### Subjective quality / voice / tone (7 ACs)

- T-446: Positioning reads as "governance layer" not "assistant runtime"
- T-470: Voice and tone match Dimitri's writing style
- T-505: Voice/tone matches writing style
- T-706: Voice and tone match writing style
- T-782: Voice and tone match writing style
- T-448.2: LLM-generated descriptions are accurate and useful
- T-460: Onboarding task content is useful for new framework users
- T-511: Operation classes accurately reflect governance model

These depend on subjective judgment. An LLM reviewer could offer a *confidence score* (e.g., "voice-classifier says 0.82 match with historical samples"), but the authority to approve cannot shift — this would be a Tier-H-assisted-by-AI pattern, not automation.

#### Physical device (2 ACs)

- T-708: Receive test notification on phone
- T-710: Receive test notification on phone

Server-side verification (ntfy publish returned 200) is partial evidence but does not cover delivery to the actual device. Could be reclassified to Tier 1 if the AC were rewritten as "ntfy topic accepts publish", but the current AC explicitly asks for phone-side receipt.

## Summary table

| Tier | Count | % of 43 | Action |
|------|-------|---------|--------|
| 1 (Programmatic) | 1 | 2% | Wire up via `fw verify-acs --execute` |
| 2 (TermLink E2E) | 8 | 19% | Add TermLink harness per family |
| 3 (Playwright) | 4 | 9% | Add `tests/playwright/` tests |
| H (Genuine human) | 30 | 70% | Keep as human; no change |

**Automatable total: 13 of 43 (30%).**

## Recommendation

**GO** — build three bounded tasks:

### B1 — Tier 1 extension (1 AC + framework capability)
Rewrite T-880's AC with a verification command and wire it to `fw verify-acs --execute`. Small, sets the pattern.

### B2 — Playwright regression bundle (4 ACs, 1 new test file)
Add `tests/playwright/test_review_queue_acs.py` covering T-1240, T-1241, T-1214, T-448.1. Run via `fw test playwright`. Each passing test can auto-tick the corresponding Human AC.

### B3 — TermLink E2E harness (8 ACs, 2 harness files)
- `tests/termlink/test_linux_session_acs.py`: T-594, T-612, T-663, T-1277 (local Linux, share `termlink dispatch` infra)
- `tests/termlink/test_macos_session_acs.py`: T-481, T-518, T-613 (remote via `termlink remote exec ring20-management`)
- `tests/termlink/test_pty_attach.py`: T-530 (standalone)

**Staging:** B1 first (establishes pattern). B2 second (highest coverage-per-effort — 4 ACs for ~1 test file). B3 last (most complex, needs remote hosts reachable).

### Structural upgrade (separate, optional)

Today's `[REVIEW]` vs `[RUBBER-STAMP]` tags are convention-only. Propose a new tag `[AUTO]` that signals: "an automation tier can cover this — filling in the verification commands here should auto-tick the checkbox." The AC writer decides the tier; the verification command encodes the check. Would unify the current split.

## Go/No-Go criteria

**GO if:**
- Classification is defensible (each Tier 1/2/3 assignment has a concrete command or locator) ✓
- Build tasks are bounded (one file or one harness per task) ✓
- Authority model preserved (genuine human ACs stay human) ✓

**NO-GO if:**
- Automation would shift decision authority away from human on strategic tasks ✗ (it does not — Tier H preserved)
- Effort exceeds 1 build session per stage ✓ (B1 small, B2/B3 medium but bounded)

Both met. Recommendation: **GO**, order B1 → B2 → B3.

## Dialogue Log

**Session 2026-04-19:** User asked: "evaluate where review can be automated by providing evidence via: programmatic testing / validation, end-to-end TermLink testing, Playwright testing/validation". Agent read 43 unchecked Human ACs, sampled representative task files, classified each by tier, recommended three bounded build tasks. Decision pending human review.
