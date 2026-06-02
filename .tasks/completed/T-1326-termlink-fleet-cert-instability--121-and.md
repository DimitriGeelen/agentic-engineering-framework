---
id: T-1326
name: "TermLink fleet cert instability — .121 and .122 hub certs rotating, secrets desynced"
description: >
  Both .121 (ring20-dashboard) and .122 (ring20-management) TermLink hubs show rotating TLS certs AND rotated shared secrets. Observed in single session on 2026-04-19: .122 fingerprint cbc43af8 -> 5198d1fb -> b90adf25 within 24h. .121 fingerprint 025f5a6a -> 7f927cc0. After TOFU clear on .121, ring20-dashboard.hex fails auth with 'invalid signature' — secret is stale too. Fleet coordination is blocked — cross-host messages are dropped because no trusted channel exists. Blocks delivery of coord answers between .107/.121/.122. Second-order finding while investigating a pickup about a lost broadcast.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-19T08:41:32Z
last_update: 2026-04-19T08:58:18Z
date_finished: 2026-04-19T08:58:18Z
---

# T-1326: TermLink fleet cert instability — .121 and .122 hub certs rotating, secrets desynced

## Problem Statement

Both .121 (ring20-dashboard) and .122 (ring20-management) TermLink hubs have rotating TLS certs AND desynced shared secrets. From .107 in this session: .122 fingerprint changed cbc43af8 → 5198d1fb → b90adf25 within 24h; .121 changed 025f5a6a → 7f927cc0. After TOFU clear on .121, `ring20-dashboard.hex` fails auth with "invalid signature" — the secret is stale too. Cross-host coordination is silently broken: the 2026-04-15 broadcast that triggered this investigation was never answered, and the answer I composed today cannot be returned on the same fabric. Full triage: `docs/reports/T-1326-fleet-cert-instability.md`.

## Assumptions

1. Rotation is genuine (not MITM) — LIKELY TRUE (same-LAN, ping OK, known rotation pattern), not directly tested
2. Cert + secret co-rotate — TESTED TRUE (.121 TOFU clear succeeded but auth then failed)
3. A single heal command (`termlink fleet reauth`) would close this class of incident — UNTESTED (T-1054 not built)

## Exploration Plan

- ICMP + TCP + TermLink ping both hubs from .107 — DONE
- Compare fingerprints to stored TOFU expectations — DONE
- Test auth after TOFU clear on .121 — DONE (fails)
- Check G-045 scope in concerns.yaml — DONE (scoped to .122 only; widening needed)

Out-of-band (requires SSH to .121/.122):
- Check hub.cert.pem mtime vs daemon restart pattern
- Look for rotation crontabs
- Identify whether `rm -rf /var/lib/termlink/` is the reset pattern

## Technical Constraints

- TOFU model: accept-on-first-use; clearing and re-accepting defeats the integrity check when done habitually
- Secret is separate from cert: auth uses shared-secret handshake AFTER TLS, so cert rotation alone doesn't break auth — secret rotation does
- No visibility into .121/.122 file state from this session (no SSH agent here)

## Scope Fence

**IN:** decide whether to ship T-1054 (`termlink fleet reauth`) + complementary `fw doctor` rotation-detection check.
**OUT:** redesigning termlink's cert lifetime policy (separate upstream conversation); mass rotation of fleet secrets (ops task); debugging the root cause of .121/.122 rotations (needs SSH access).

## Acceptance Criteria

### Agent
- [x] Problem statement validated (two hubs confirmed desynced; secret staleness confirmed via auth-fail on .121)
- [x] Assumptions tested (2 true, 1 untested because T-1054 doesn't exist yet)
- [x] Recommendation written with rationale (GO — build T-1054 + doctor check)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Two hubs now in the same broken state (G-045 was filed for .122 alone a week ago; .121 has now joined). The fleet is operating as isolated islands with silent message loss. Doing nothing trains operators to blind-clear TOFU, which destroys the integrity check the fleet relies on. Ship T-1054 (`termlink fleet reauth` single-command heal) + add a `fw doctor` rotation-detection check. Both are bounded work; the first is upstream-termlink, the second is framework-local.

**Evidence:**
- Live confirmation from .107 this session: .121 and .122 both fail TermLink handshake; .121 fails with "invalid signature" after TOFU clear (cert AND secret rotated)
- G-045 (concerns.yaml) scope is too narrow — needs widening to full-fleet
- 2026-04-15 coord broadcast from .121 went unanswered for 4 days because of this exact class of failure
- This session's answer (`/tmp/coord-reply/coord-answer-to-121.yaml`) cannot be delivered on-fabric — must go out-of-band
- Risk of not fixing: next cross-host coordination attempt silently fails, same way

**Build plan (separate task, to be created post-decide):**
1. Upstream termlink: implement `termlink fleet reauth <hub>` command (Rust)
2. Framework: add `fw doctor` check that diffs current hub fingerprints vs last-known-good and flags unexplained rotation
3. Update G-045 in concerns.yaml to widen scope beyond .122
4. Bats coverage for the doctor check
5. Docs: operator playbook for "fleet trust reset"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Two hubs now in the same broken state (G-045 was filed for .122 alone a week ago; .121 has now joined). The fleet is operating as isolated islands with silent message loss. Doing nothing trains operators to blind-clear TOFU, which destroys the integrity check the fleet relies on. Ship T-1054 (`termlink fleet reauth` single-command heal) + add a `fw doctor` rotation-detection check. Both are bounded work; the first is upstream-termlink, the second is framework-local.

Evidence:
- Live confirmation from .107 this session: .121 and .122 both fail TermLink handshake; .121 fails with "invalid signature" after TOFU clear (cert AND secret rotated)
- G-045 (concerns.yaml) scope is too narrow — needs widening to full-fleet
- 2026-04-15 coord broadcast from .121 went unanswered for 4 days because of this exact class of failure
- This session's answer (`/tmp/coord-reply/coord-answer-to-121.yaml`) cannot be delivered on-fabric — must go out-of-band
- Risk of not fixing: next cross-host coordination attempt silently fails, same way

Build plan (separate task, to be created post-decide):
1. Upstream termlink: implement `termlink fleet reauth <hub>` command (Rust)
2. Framework: add `fw doctor` check that diffs current hub fingerprints vs last-known-good and flags unexplained rotation
3. Update G-045 in concerns.yaml to widen scope beyond .122
4. Bats coverage for the doctor check
5. Docs: operator playbook for "fleet trust reset"

**Date**: 2026-04-19T08:58:17Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-19T08:58:17Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Two hubs now in the same broken state (G-045 was filed for .122 alone a week ago; .121 has now joined). The fleet is operating as isolated islands with silent message loss. Doing nothing trains operators to blind-clear TOFU, which destroys the integrity check the fleet relies on. Ship T-1054 (`termlink fleet reauth` single-command heal) + add a `fw doctor` rotation-detection check. Both are bounded work; the first is upstream-termlink, the second is framework-local.

Evidence:
- Live confirmation from .107 this session: .121 and .122 both fail TermLink handshake; .121 fails with "invalid signature" after TOFU clear (cert AND secret rotated)
- G-045 (concerns.yaml) scope is too narrow — needs widening to full-fleet
- 2026-04-15 coord broadcast from .121 went unanswered for 4 days because of this exact class of failure
- This session's answer (`/tmp/coord-reply/coord-answer-to-121.yaml`) cannot be delivered on-fabric — must go out-of-band
- Risk of not fixing: next cross-host coordination attempt silently fails, same way

Build plan (separate task, to be created post-decide):
1. Upstream termlink: implement `termlink fleet reauth <hub>` command (Rust)
2. Framework: add `fw doctor` check that diffs current hub fingerprints vs last-known-good and flags unexplained rotation
3. Update G-045 in concerns.yaml to widen scope beyond .122
4. Bats coverage for the doctor check
5. Docs: operator playbook for "fleet trust reset"

### 2026-04-19T08:58:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1dc702b8
- **Timestamp:** 2026-06-02T14:56:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
