---
id: T-1623
name: "Clear stale TOFU pin for ring20-dashboard hub migration .121 → .143 (resolves G-060)"
description: >
  Clear stale TOFU pin for ring20-dashboard hub migration .121 → .143 (resolves G-060)

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [termlink, tofu, fleet, security, from-g-060]
components: []
related_tasks: [T-1051, T-1053, T-1054, T-1055, T-1326, T-1332]
created: 2026-04-30T19:53:10Z
last_update: 2026-04-30T19:53:10Z
date_finished: null
---

# T-1623: Clear stale TOFU pin for ring20-dashboard hub migration .121 → .143 (resolves G-060)

## Context

G-060 has been "watching" for 2+ days against `ring20-dashboard 192.168.10.121:9100` with class `tofu-violation`. Live `termlink fleet doctor` (run 2026-04-30T19:51) reveals the gap has *evolved*, not stalled:

- TermLink config (`/root/.termlink/hubs.toml`) now points `ring20-dashboard` at `192.168.10.143:9100` — the hub was migrated.
- `ping 192.168.10.121` → 100% loss (host gone).
- `ping 192.168.10.143` → 0.166ms (alive).
- TOFU pin on this trusted anchor still expects the OLD `.121` cert fingerprint `sha256:53de15ec...`; the new `.143` host presents `sha256:2b0946f9...` — legitimately different (different host).
- The pinned mismatch blocks every connect from this anchor to ring20-dashboard.

Per G-060's own `mitigation_candidate` and the doctor's `hint:` output, the heal path is `termlink tofu clear 192.168.10.143:9100` followed by re-running fleet doctor to confirm reauth. T-1054 + T-1055 (TermLink fleet reauth) shipped completed on TermLink side, so the heal command itself is mature.

**Why owner=human, not agent:** Clearing a TOFU pin is a Tier 2 trust decision — accepting a new cert at a new IP. In principle this could be a MITM rather than a legitimate hub migration. The agent has gathered evidence both interpretations are consistent with (config rewritten, .121 dead, .143 alive, fingerprint differs as expected for a different host) but the decision belongs to the human.

## Acceptance Criteria

### Agent
- [x] G-060 surface confirmed evolved (.121 → .143) via live `termlink fleet doctor` and `/root/.termlink/hubs.toml` inspection
- [x] Heal path identified per G-060 mitigation_candidate + doctor hint output
- [x] Build task surfaced via `fw task review T-1623` for human Tier-2 authorization
- [x] After human runs the steps, agent will update G-060 (concerns.yaml) — either resolve (if reauth succeeds) or rewrite description with new IP (if a deeper issue surfaces)

### Human
- [ ] [REVIEW] Confirm the .121 → .143 hub migration is intentional (not MITM)
  **Steps:**
  1. Recall: did you (or someone authorised) move ring20-dashboard from `.121` to `.143` recently? (Hub move, LXC migration, host re-IP.)
  2. If unsure, ssh into the LXC/VM hosting ring20-dashboard and confirm it's actually at `.143` now.
  **Expected:** "Yes, expected" or "No, suspicious — investigate first."
  **If not:** Do NOT clear TOFU. Investigate why the IP/cert changed before authorising. Capture findings in this task before proceeding.

- [ ] [RUBBER-STAMP] Clear TOFU pin and verify reauth succeeds
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && termlink tofu clear 192.168.10.143:9100 && termlink fleet doctor 2>&1 | grep -A 1 "ring20-dashboard"`
  **Expected:** `[PASS] connected in NNms (version: 0.9.0)` for ring20-dashboard. No further TOFU VIOLATION lines.
  **If not:** Capture the new error class and re-evaluate. Likely needs `termlink fleet reauth ring20-dashboard` (T-1054 surface) if secret is also stale, or escalate to G-045 cert co-rotation playbook.

- [ ] [RUBBER-STAMP] Confirm gap is closeable
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && cat .context/working/.fleet-failure-state.json | python3 -m json.tool | grep -A 5 ring20-dashboard`
  2. Wait at least one cron tick (~5-15 min) after TOFU clear, then re-check.
  **Expected:** `consecutive_failures: 0`, `last_class: null` for ring20-dashboard.
  **If not:** The fleet-doctor cron is still observing failures — root cause not actually fixed. Re-open this task body with new findings.

## Verification

# Verification gate (P-011) is informational here — the human runs the heal command,
# the agent confirms via fleet state file.
test -f /root/.termlink/hubs.toml
grep -q '192.168.10.143' /root/.termlink/hubs.toml

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

**Recommendation:** GO (conditional on human confirmation that the hub move was intentional)

**Rationale:** Evidence is consistent with a legitimate hub migration, not a MITM:
- TermLink config (`/root/.termlink/hubs.toml`) was rewritten to point at `.143` — that's an authorised-side change, not a wire-level tamper.
- `.121` is dead (`ping` 100% loss); `.143` is alive — the topology actually moved.
- Cert fingerprint differs as expected (different host, different cert) — the doctor itself flags this with the standard rotation hint.
- The framework-side mitigation candidate in G-060 names this exact heal command; T-1054 + T-1055 (TermLink reauth) shipped completed.

The agent CANNOT autonomously authorise the TOFU clear because the trust decision is Tier 2: the only way to distinguish "legitimate migration" from "MITM with bonus config-rewrite" is human recall of "did I (or someone authorised) move this hub recently?". One yes/no question gates the entire fix.

**Evidence:**
- `/root/.termlink/hubs.toml`: `address = "192.168.10.143:9100"` for `ring20-dashboard` (was .121).
- `ping 192.168.10.121`: 100% packet loss.
- `ping 192.168.10.143`: 0.166ms RTT.
- `termlink fleet doctor` (run 2026-04-30T19:51): TOFU VIOLATION reported with old fingerprint `sha256:53de15ec...`, new `sha256:2b0946f9...`; doctor's own `hint:` recommends `termlink tofu clear 192.168.10.143:9100`.
- G-060 in `concerns.yaml`: `mitigation_candidate` names the same heal path; status was "watching" because the framework correctly registered the gap but had no actor to clear it.
- TermLink: `/opt/termlink/.tasks/completed/T-1054-*` and `/opt/termlink/.tasks/completed/T-1055-*` confirm reauth tooling is mature on the upstream side.

After human confirms + clears, agent will:
1. Re-run `termlink fleet doctor` to confirm `[PASS] ring20-dashboard`.
2. Wait for one fleet-doctor cron tick (`liveness-1m`) to refresh `.fleet-failure-state.json`.
3. Update `concerns.yaml`: G-060 → resolved (with note: surface evolved .121 → .143; TOFU cleared; reauth verified).

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

### 2026-04-30T19:53:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1623-clear-stale-tofu-pin-for-ring20-dashboar.md
- **Context:** Initial task creation
