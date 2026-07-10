---
id: T-2527
name: "AEF agent identity split: heartbeat listens as per-agent key, session posts as host key → cross-agent DMs never wake the session"
description: >
  Interactive AEF claude session posts/receives under the shared HOST termlink key
  (d1993c2c) while its be-reachable heartbeat/pushwaker advertises+listens under the
  per-agent key (0e7ee6ca / dm:aef:*). Cross-agent DMs addressed to the session key are
  durably written but never observed by the waker → no ring → no wake → proposals sit
  undelivered forever. Silent Reliability-directive violation. Should we incept structural
  remediation?
status: captured
workflow_type: inception
owner: human
horizon: now
tags: [termlink, identity, reliability, delivery-gap]
components: []
related_tasks: []
created: 2026-07-10T21:40:00Z
last_update: 2026-07-10T21:40:00Z
date_finished:
---

# T-2527: AEF agent identity split — heartbeat vs interactive session

## Context

Verified 2026-07-10 during the T-2521/T-2526 designer integration. 832's 0.2.0 release
(and earlier its offset-21 decomposition proposal) were **durably written to termlink but
never delivered to AEF's listen path** — they sat until the AEF session *manually* ran
`file_receive`. Operator diagnosed the mechanism precisely; this is not the earlier
"shared fingerprint" story (T-2292 already gave each agent a distinct fp).

## The mechanism (verified)

- **T-2292** applied a per-agent key to AEF's **be-reachable heartbeat / pushwaker**
  process: it advertises + listens as `0e7ee6ca…` on `dm:aef:*`.
- AEF's **interactive `claude` session** was launched as **plain `claude`, without
  `TERMLINK_AGENT_ID`** → its `termlink channel post` falls back to the shared **HOST**
  key `d1993c2c…`. So the session posts as, and is addressed at, `d1993c2c`.
- The designer therefore DMs AEF on `dm:6a646ce8b1bc6560:d1993c2c3ec44c94`; the waker
  (watching `0e7ee6ca` / `dm:aef:*`) **never observes it** → no ring → no wake.
- The *correct* aef↔designer topic `dm:0e7ee6cad65137fc:6a646ce8b1bc6560` **does not
  exist** — no message was ever sent to AEF's real per-agent fingerprint.
- Root: **heartbeat identity and session-post identity diverged** — armed separately,
  never unified. T-2292 fixed the heartbeat leg only; the session-launch leg still
  host-falls-back.

## Why structural (not a one-off)

Every AEF interactive session launched as plain `claude` (not `claude-fw` with the agent
id exported) has this split. Cross-agent async delivery to the session identity silently
fails — a Reliability violation (no error, proposal "delivered" per sender, invisible to
receiver). Blast radius = session-wide + every peer that DMs AEF.

## Open Questions

- **IW-1: Where should the session-launch identity be unified with the heartbeat listen
  identity?** Candidates: (a) `claude-fw` wrapper exports `TERMLINK_AGENT_ID=<per-agent>`
  before launching `claude`; (b) a `SessionStart` hook sets it; (c) termlink derives a
  stable per-project agent id instead of host-fallback when none is set. Which leg owns
  the fix — AEF (session launch) vs TermLink (fallback loudness)? (Gap-homing: likely
  AEF owns the launch-sets-identity fix; TermLink owns making the silent host-fallback
  *loud*. Cross-link both.)
  - confidence: high (mechanism verified)
  - disposition: deferred
  - rationale: fix-space is a real design choice (wrapper vs hook vs termlink-side);
    needs one scoped decision before any build.

## Recommendation

**Recommendation:** GO (incept)

**Rationale:** This is a verified, structural, silently-failing delivery gap with
session-wide blast radius — squarely a Reliability-directive concern. It is NOT a
confidence hedge: the mechanism is proven (operator-verified topic inspection), the
remediation space is a genuine design choice (three candidate legs, an AEF/TermLink
homing question), and it cost real convergence delay this session. That is exactly the
"one problem, one go/no-go, real fix-space to explore" shape an inception exists for.
Scope it as one question (IW-1). Do NOT fold it into the designer arc — it is a TermLink
identity concern that happened to surface there.

**Evidence:**
- Correct topic `dm:0e7ee6cad65137fc:6a646ce8b1bc6560` does not exist (never addressed).
- Live topic `dm:…:d1993c2c3ec44c94`, sender `d1993c2c` (host key), waker on `0e7ee6ca`.
- 0.2.0 file + offset-21 proposal delivered-but-unrung; only manual `file_receive` surfaced them.
- T-2292 gave distinct per-agent fps but only wired the heartbeat leg.
