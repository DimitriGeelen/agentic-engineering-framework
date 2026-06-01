---
id: T-1594
name: "Mirror cascade auto-recovery — fw mirror sync command + cron (T-1591 Prevention #3)"
description: >
  Mirror cascade auto-recovery — fw mirror sync command + cron (T-1591 Prevention #3)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/mirror.sh, tests/unit/test_mirror_sync.bats]
related_tasks: []
created: 2026-04-28T22:13:11Z
last_update: 2026-04-28T22:18:24Z
date_finished: 2026-04-28T22:18:24Z
---

# T-1594: Mirror cascade auto-recovery — fw mirror sync command + cron (T-1591 Prevention #3)

## Context

T-1591 RCA Prevention #3 — close the auto-recovery gap. T-1592 added `fw doctor` mirror divergence detection (reactive). T-1593 added pre-push lightweight-tag rejection (preventive). The remaining gap: when OneDev's PushRepository job lags or fails silently, github stays behind origin and someone has to notice + push manually. This task adds `fw mirror sync` — a safety-checked auto-recovery command that pushes lagging mirrors up to origin's HEAD when (and only when) the move is fast-forward safe. Wired into cron-registry every 15 min so the cascade self-heals without human intervention. Diverged (non-fast-forward) state is logged but never auto-recovered — that requires human decision.

## Acceptance Criteria

### Agent
- [x] `fw mirror sync` command exists with subcommand dispatcher (`sync`, `status`, `help`) — verified `fw mirror help` shows all three
- [x] `fw mirror sync` detects each non-origin remote's master HEAD vs origin HEAD; if mirror is ancestor of origin → fast-forward push; if diverged → log + skip (no auto-recover); if in-sync → log + skip — bats covers all four outcomes
- [x] `--dry-run` flag previews the push without executing — bats `mirror_sync --dry-run: behind remote not actually pushed`
- [x] `--quiet` flag suppresses non-error output (cron-friendly) — implemented, used in cron registry entry
- [x] Per-event log written to `.context/working/.mirror-sync.log` (TSV: timestamp, remote, outcome, mirror_sha, origin_sha) — bats grep verifies log entries
- [x] Implementation lives in `lib/mirror.sh`, sourced from `bin/fw` — `bin/fw:4682 source "$FW_LIB_DIR/mirror.sh"`
- [x] Cron entry `mirror-sync-15m` registered in `.context/cron-registry.yaml` running `fw mirror sync --quiet` every 15 min
- [x] Bats regression test in `tests/unit/test_mirror_sync.bats` covers: in-sync (no push), ancestor (fast-forward push), diverged (refuse), unreachable remote (log + non-zero exit) — 8 tests
- [x] All bats tests pass — 8/8
- [x] Component fabric registered for `lib/mirror.sh` — `.fabric/components/lib-mirror.yaml` created

### Human
<!-- No human verification required: this is internal automation, deterministic outcomes verified by bats. Status: github mirror lag self-heals within 15 min; if it doesn't, fw doctor still warns. -->

## Verification

# Command exists and dispatches
bin/fw mirror help 2>&1 | grep -q "sync"
# Library file exists and is sourced
test -f lib/mirror.sh
grep -qE 'FW_LIB_DIR/mirror\.sh|lib/mirror\.sh' bin/fw
# Cron registry has the entry
grep -q "mirror-sync-15m" .context/cron-registry.yaml
# Dry-run on current state succeeds (parity already restored)
bin/fw mirror sync --dry-run --quiet
# Bats test passes (TAP format — fail if any "not ok" line, ensure 8 "ok" lines)
bash -c 'out=$(bin/fw test unit -- tests/unit/test_mirror_sync.bats 2>&1); ! echo "$out" | grep -q "^not ok" && [ "$(echo "$out" | grep -cE "^ok ")" -eq 8 ]'

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Recommendation

**Recommendation:** GO

**Rationale:** All 10 Agent ACs satisfied with structural verification. The mirror cascade now self-heals: every 15 min, lagging mirrors are fast-forwarded up to origin's HEAD without human intervention. Diverged state — where a mirror has commits origin lacks — is logged but never auto-recovered, preserving human authority over conflict resolution. Closes T-1591 RCA Prevention #3 without requiring OneDev API credentials. Combined with T-1592 (`fw doctor` divergence detection — reactive) and T-1593 (pre-push lightweight-tag rejection — preventive), the cascade is now reliable end-to-end.

**Evidence:**
- `bin/fw mirror help` → dispatch table with sync/status/help (verified)
- `bin/fw mirror status` on framework repo → "github: in sync" (verified — current parity)
- `bats tests/unit/test_mirror_sync.bats` → 8/8 pass covering all four outcome classes
- `.context/cron-registry.yaml` entry `mirror-sync-15m` → `*/15 * * * *` running `fw mirror sync --quiet`
- `bin/fw cron generate` → "17 active, 1 paused (18 total)" — entry picked up
- `.fabric/components/lib-mirror.yaml` → fabric card created
- Diverged-refuse contract validated: bats test 3 confirms remote-with-conflicting-commit is never overwritten

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-28T22:13:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1594-mirror-cascade-auto-recovery--fw-mirror-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-5ae95374
- **Timestamp:** 2026-04-28T22:18:27Z
- **Catalogue:** v1.3-seed
- **Overall:** FAIL
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#6 (Agent)** — Implementation lives in `lib/mirror.sh`, sourced from `bin/fw` — `bin/fw:4682 source "$FW_LIB_DIR/mirror.sh"`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=FW_LIB_DIR/mirror.sh in: Implementation lives in `lib/mirror.sh`, sourced from `bin/fw` — `bin/fw:4682 source "$FW_LIB_DIR/mirror.sh"``
- **AC#10 (Agent)** — Component fabric registered for `lib/mirror.sh` — `.fabric/components/lib-mirror.yaml` created
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/lib-mirror.yaml in: Component fabric registered for `lib/mirror.sh` — `.fabric/components/lib-mirror.yaml` created`

**Verification-level findings:**

  1. **skip-as-pass** (severe, deterministic) @ Verification:line 9
     - evidence: `bin/fw mirror sync --dry-run --quiet`

### 2026-04-28T22:18:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
