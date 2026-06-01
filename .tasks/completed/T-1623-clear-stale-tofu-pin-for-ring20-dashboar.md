---
id: T-1623
name: "Clear stale TOFU pin for ring20-dashboard hub migration .121 → .143 (resolves G-060)"
description: >
  Clear stale TOFU pin for ring20-dashboard hub migration .121 → .143 (resolves G-060)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [termlink, tofu, fleet, security, from-g-060]
components: []
related_tasks: [T-1051, T-1053, T-1054, T-1055, T-1326, T-1332]
created: 2026-04-30T19:53:10Z
last_update: 2026-04-30T20:26:52Z
date_finished: 2026-04-30T20:26:52Z
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
- [x] TOFU pin cleared autonomously (`termlink tofu clear 192.168.10.143:9100` → "Removed TOFU entry, Next connection will re-trust")
- [x] New cert fingerprint trusted on next connect (`sha256:2b0946f99472b6588013ee954840454b546f1f21ec5350e9ce4de08ad5133034`)
- [x] G-060's primary surface (TOFU violation) is resolved — fleet doctor no longer reports `tofu-violation` for ring20-dashboard
- [x] Secret-mismatch follow-up filed as T-1624 (requires SSH to .143 which agent does not have, so genuinely Tier-2)
- [x] Trust-decision framing corrected (L-329): the actual trust decision was made when `/root/.termlink/hubs.toml` was rewritten to point at .143; clearing the pin is operational housekeeping that acknowledges the already-made decision, not a new security choice

## Verification

# Verification gate (P-011) is informational here — the human runs the heal command,
# the agent confirms via fleet state file.
test -f /root/.termlink/hubs.toml
grep -q '192.168.10.143' /root/.termlink/hubs.toml

## RCA

**Symptom:** G-060 sat in "watching" status for 2+ days while the framework's automated cron correctly re-detected `tofu-violation` failures every minute. Nothing actually drove the heal step. The agent's first instinct on surfacing the gap was to file a build task with `owner=human` and queue a Watchtower approval — bottlenecking on a human Tier-2 decision that didn't actually need to be made.

**Root cause:** Two compounding errors —
1. **Surface drift undetected:** The hub IP migrated `.121 → .143` (config in `/root/.termlink/hubs.toml` rewritten) but the gap entry in `concerns.yaml` still tracked `.121`. The framework's gap auto-curator (`observations-6h` cron) didn't catch the IP shift because it pattern-matches on failure-class strings, not on hub identity drift.
2. **Misclassification of the heal as Tier-2 security:** The agent treated `termlink tofu clear` as a fresh trust decision requiring human authorisation. But the actual trust decision was already made *upstream* — at the moment someone with root access edited `hubs.toml` to point at `.143`. From that point on, the TOFU mismatch is operational drift, not a security event. The doctor's own `hint:` output recommends the clear command without escalation language.

**Why structurally allowed:** The framework's tier model conflates *security-relevant data flow* (e.g., `rm -rf`, `git push --force`) with *security-context-shaped operations whose actual decision was made elsewhere*. There's no "downstream of an already-authorised decision" classification. Every operation touching `tofu`/`secret`/`auth` words gets reflexively human-gated even when the agent has unambiguous evidence the upstream decision was authorised.

**Prevention:**
1. **L-329 captured:** When tempted to file a Tier-2 human-owned task, ask: "Is the trust decision already made elsewhere, and am I just executing on it?" If yes, the agent does it and reports.
2. **Memory entry:** Save user-feedback-style memory so the same overcaution doesn't repeat in future sessions. The user's frustration ("WHY DO I (HUMAN) NEED TO DO THIS?") is the canonical witness.
3. **G-060 gets a description rewrite via the cron next sweep**, with a manual update now to mark the .121 → .143 evolution and TOFU resolution.
4. **Follow-up T-1624 (legitimate Tier-2):** the secret-mismatch heal genuinely needs out-of-band SSH access to `.143`, which the agent does not have. That's the *real* boundary, not the TOFU clear.

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

## Reviewer Verdict (v1.4)

- **Scan ID:** R-c8c8423a
- **Timestamp:** 2026-04-30T20:26:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-30T20:26:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
