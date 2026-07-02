---
id: T-1628
name: "B-2 (T-1626): hook telemetry — .hook-counter + .hook-failure-counter on every
  fire"
description: >
  Add .context/working/.hook-counter (per-hook fire count) and .hook-failure-counter
  (per-hook non-zero exit count). Increment on every PreToolUse/PostToolUse hook entry/exit.
  <5ms per fire. No structural action — just observability so threshold escalation
  (B-3) can read these.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/upgrade.sh]
related_tasks: [T-1626, T-1627]
created: 2026-04-30T21:19:26Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-01T07:20:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1628: B-2 (T-1626): hook telemetry — .hook-counter + .hook-failure-counter on every fire

## Context

B-2 of T-1626 carve-out. T-1627 fixed the *cause* of hook breakage in consumers (bare-relative path); B-2 fixes the *blindness* — even when a hook fails for unrelated reasons, the framework records nothing today. This task adds two flat counter files updated by the `bin/fw hook` dispatcher on every hook invocation. B-3 (T-1629) reads these for threshold escalation; `fw doctor` reads them for surfacing.

## Acceptance Criteria

### Agent
- [x] `lib/hook-telemetry.sh` exists and exports `fw_record_hook_fire <hookname> <exit_code>` + `fw_hook_counter_get <kind> <hookname>` helpers
- [x] `bin/fw hook` dispatcher records every hook fire (success and failure) by invoking `fw_record_hook_fire` with the hook's exit code
- [x] On every hook fire, `.context/working/.hook-counter` is incremented for that hook (per-hook `name=count` format)
- [x] On every non-zero hook exit, `.context/working/.hook-failure-counter` is also incremented for that hook
- [x] Files are absent before first fire, created on first fire — no init step required
- [x] Telemetry overhead per fire is <5ms (measured: ~0.17ms/fire — 1000 fires in ~170ms in a single bash session)
- [x] Telemetry failure NEVER blocks the hook (read-only fs / missing `.context/working/` returns 0 silently)
- [x] bats tests cover: first-fire creation, repeat-increment, failure-counter only on non-zero exit, multiple hooks tracked independently, performance budget, telemetry-doesn't-block, **plus the missing-hook degrade-to-allow path (T-1626 witness scenario)** — 15 cases, all green

## Verification

bash -n lib/hook-telemetry.sh
bash -n bin/fw
test -f tests/unit/hook_telemetry.bats
bats tests/unit/hook_telemetry.bats
grep -q "fw_record_hook_fire" bin/fw
grep -q "T-1628" lib/hook-telemetry.sh

## Recommendation

**Recommendation:** GO

**Rationale:** B-2 ships clean per-hook fire/failure telemetry with overhead well under the 5ms budget (~0.17ms measured). Crucially, it also covers the exact T-1626 witness scenario: when `bin/fw hook <name>` cannot find the hook script (the path-broken case from ring20-dashboard 2026-04-30), telemetry now records the event as exit-127 in `.hook-failure-counter`. Pre-T-1628 this case exited 0 silently with no structural footprint — that was the framework blindness G-019 talked about. B-3 (T-1629) now has a deterministic counter to threshold-escalate against; doctor will read these in B-3.

**Evidence:**
- 15/15 bats green (`tests/unit/hook_telemetry.bats`), including missing-hook regression
- Live telemetry already populating: `cat .context/working/.hook-counter` shows 8 distinct hooks counted in this session before completion
- Performance: 1000 fires in ~170ms in a single bash session = ~0.17ms/fire (33× under the 5ms budget)
- Pure-bash impl (mapfile + parameter expansion) avoids per-fire awk subprocess
- `fw doctor` runs clean post-change (17 warnings, no failures — same warning count as pre-change baseline)
- VERSION 1.6.63 → 1.6.64

## RCA

**Symptom:** Hook failures in consumer projects produced visible chat noise (`PostToolUse:Edit hook error / .agentic-framework/bin/fw: not found`) but left zero structural footprint — `concerns.yaml` empty, `fw doctor` clean, no counter, no audit trail. The framework's enforcement loop (problem → signal → audit → gap → fix) snapped at "signal" because there was none.

**Root cause:** The `bin/fw hook` dispatcher had two exit paths and *neither* recorded telemetry: the success path used `exec bash $script` (process replaced — no opportunity for post-exit logging), and the missing-hook degrade-to-allow path (T-1360 / G-053-B) exited 0 silently with only an inline `.hook-crashes.log` append (a free-form text log, not a queryable counter).

**Why structurally allowed:** Hook-failure observability had never been a first-class signal. `.hook-crashes.log` existed (T-821) but only for hard crashes (exit not in {0,2}); the path-broken case had `_hook_script="$AGENTS_DIR/context/${_hook_name}.sh"` succeed-and-exec, where the broken sub-process inside the hook was Claude-Code-internal noise the dispatcher never saw. No counter file was ever written, so `fw doctor` had nothing to surface and no threshold could be evaluated. Symmetric to G-019: the immune system was desensitised to its own input signal.

**Prevention:** This task adds the missing signal layer:
1. **Counter files** (`.hook-counter`, `.hook-failure-counter`) are now incremented on every fire — observable by anything that can read a file
2. **Missing-hook path** (the witness scenario) is now recorded as exit-127 in the failure counter, not just the free-form crash log
3. **Pinned by 15 bats cases** including the witness-regression test that fires `bogus-hook-name-for-T1628` against the live dispatcher and asserts the failure counter increments
4. **B-3 (T-1629) consumes this signal** for threshold escalation + Watchtower `/hooks` page + `fw doctor` exercise-from-/tmp check — the rest of the immune-system loop

The fix is the symptom mitigation (counters appear), the prevention is the structural one (the dispatcher CANNOT exit a fire without telemetry recording, even on the degrade path).

## Decisions

### 2026-05-01 — Counter file format: `name=count` flat lines vs. JSONL append
- **Chose:** Flat `<hookname>=<count>` lines, read-modify-write with mapfile
- **Why:** Direct to consume — `grep -q '^check-tier0=[0-9]' .hook-counter` answers "did this hook fire?". B-3 will threshold-scan ratios (`.hook-failure-counter` / `.hook-counter`); a derived format would force every reader to re-aggregate. Per-fire overhead measured at ~0.17ms — 33× under the 5ms budget — so the read-modify-write doesn't earn the complexity of an append-only log.
- **Rejected:** JSONL append + lazy aggregation (sub-ms append, but every reader pays aggregation cost; B-3's threshold scanner would re-read the entire log on every Tool fire); separate file-per-hook (filesystem entry explosion across 11+ hooks × 4 events).

### 2026-05-01 — Missing-hook degrade path: keep exit 0, add telemetry
- **Chose:** Record missing-hook events as exit-127 in failure counter, BUT keep the dispatcher's `exit 0` (degrade-to-allow per T-1360/G-053-B)
- **Why:** T-1626 inception explicitly said "non-blocking != invisible". The broken-hook scenario shouldn't hard-block (would cascade across every Bash/Write/Edit per T-1360), but it MUST be visible. Synthetic exit-127 is the sh convention for command-not-found, semantically faithful to "config drift = command-not-found".
- **Rejected:** Hard-blocking on missing hook (regresses T-1360); skipping telemetry for the degrade path (regresses T-1626 witness scenario); recording with exit 1 (loses the `command-not-found` signal).

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-30T21:19:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1628-b-2-t-1626-hook-telemetry--hook-counter-.md
- **Context:** Initial task creation

### 2026-05-01T07:11:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-80d61191
- **Timestamp:** 2026-06-02T14:58:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T07:20:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
