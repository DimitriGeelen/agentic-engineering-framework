# T-1326 — TermLink fleet cert instability (.121 and .122)

**Status:** Triaged 2026-04-19 — GO (bounded: ship T-1054 `fleet reauth` + stabilise rotation schedule)
**Surfaced by:** Investigation of a lost 2026-04-15 broadcast from ring20-dashboard@.121 (this session)
**Related:** G-045 (already watching .122 hub) — now upgraded in scope

## The finding

In the course of answering a pickup question routed via .107, I checked reachability of `.121` and `.122` TermLink hubs and found both are un-reachable to this client:

| Host | ICMP | TCP :9100 | TLS cert | Shared secret |
|------|------|-----------|----------|---------------|
| .121 (ring20-dashboard) | ✓ | ✓ | **rotated** (025f5a6a → 7f927cc0) | **invalid** after TOFU clear ("invalid signature") |
| .122 (ring20-management) | ✓ | ✓ | **rotated twice in 24h** (cbc43af8 → 5198d1fb → b90adf25) | not retested (TOFU-blocked first) |

In other words, **both the TLS fingerprint AND the shared secret have changed** on at least .121. Clearing TOFU re-accepts the cert but the hub then refuses our authentication. This is fleet-wide: every client with stale secrets is dark to these hubs.

## Why this matters

- **G-045 was scoped to .122 only** and recommended mitigation was T-1054 (`termlink fleet reauth`). The same pattern now affects .121 — scope widens.
- **Cross-host coordination is silently broken.** The 2026-04-15 coord.question from .121 never reached a respondent, and the 2026-04-19 answer I composed cannot be delivered back on the same fabric. The fleet is operating as a set of islands.
- **Repeated TOFU acceptance becomes a habit**, which defeats the purpose of TOFU. If operators train themselves to run `termlink tofu clear` on every reconnect, a real MITM is indistinguishable from routine rotation.

## Hypotheses (to test)

1. **Silent daemon restarts regenerate cert+secret by default.** The hubs may be using ephemeral certs per-run rather than persistent ones. *Test:* check `/var/lib/termlink/hub.cert.pem` mtime vs service restart time on .121 and .122.
2. **Human is doing `rm -rf /var/lib/termlink/ && termlink hub start`** as a reset pattern, which regenerates everything. *Test:* ask.
3. **A scheduled job rotates certs on a cron.** *Test:* check crontabs on .121 and .122 for termlink-related entries.

All three require SSH access to .121/.122 — out of scope for this .107 session.

## Options

| Option | Cost | Benefit |
|--------|------|---------|
| A. Ship T-1054 `termlink fleet reauth` one-command heal | 1 PR on termlink (Rust) + integration tests | Turns "can't connect" into a single recovery action |
| B. Pin hubs to long-lived certs (>=90d) and require explicit rotation ceremony | Medium — config + docs | Stops the default-regenerate footgun |
| C. Add cert-change telemetry to `fw doctor` + auto-open G-NNN gap on unexpected rotation | Small | Visibility — can't hide the footgun, operator has to act |
| D. Do nothing — re-learn TOFU per incident | 0 | Habit of blind `tofu clear` defeats the whole mechanism |

## Recommendation: GO (build T-1054 + ship C as a complementary doctor check)

**Rationale:**

- D (do nothing) is an active risk — trains operators to bypass the integrity check
- A has been pending since G-045 was filed; this session is the second reproduction in a week, with .121 now joining .122
- C is cheap and pairs naturally with A (heal command + health check that surfaces when heal is needed)
- B requires changes to the termlink upstream and has organisational friction — worth a separate conversation

**Scope fence for the build task:**
- In scope: implement `termlink fleet reauth <hub>` in the termlink Rust client; add `fw doctor` check that flags cert rotations since last audit
- Out of scope: upstream termlink's cert lifetime policy (B); mass rotation of shared secrets across the whole fleet (ops task)

## Immediate follow-ups

1. **Deliver the original coord answer to .121 out-of-band.** Artifact at `/tmp/coord-reply/coord-answer-to-121.yaml`. Channel options: SSH scp, manual paste into whatever chat the human is using, or a fresh `ring20-dashboard.hex` secret from .121 and replay the broadcast.
2. **Update G-045 concerns entry** — scope has grown beyond .122.
3. **Test TOFU on .122** only after .122 is known-stabilised; further TOFU clears without a parallel secret refresh just burn trust without restoring connectivity.

## Decision trail

- Source: this session's investigation of the 2026-04-15 pickup
- Artifact: this file
- Related: G-045 (.122 hub failing), T-1054 (fleet reauth — not yet built)
- Recommendation: GO — build sibling would target termlink repo, coordinate with framework's `fw doctor`
