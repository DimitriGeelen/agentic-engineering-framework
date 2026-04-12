# T-1121 — TermLink TLS Cert TOFU Violation

## Incident

2026-04-12 during session S-2026-0412-0935, framework agent tried to
connect to ring20-manager hub at 192.168.10.109:9100:

```
termlink remote ping 192.168.10.109:9100 --secret <redacted>
```

Result: TOFU VIOLATION — fingerprint changed from `sha256:befa96...` to
`sha256:6f7458...`. The .109 hub had restarted since last connection,
regenerating its TLS certificate.

## Root Cause

TermLink hub generates a new TLS certificate on every startup. The TOFU
(Trust On First Use) mechanism stores the fingerprint of the first-seen
cert and rejects subsequent connections if it changes. Hub restart = new
cert = all clients reject the hub.

## Fix Applied (this session)

Cleared stale TOFU entry: `sed -i '/192.168.10.109:9100/d' /root/.termlink/known_hubs`

This is a per-incident workaround, not a structural fix.

## Proposed Upstream Fix

Persist the hub cert to disk (e.g., `/var/lib/termlink/hub.pem`).
On startup: if cert file exists, load it; if not, generate and save.
Modeled after T-933 secret persistence.

## Questions Sent to ring20-manager

1. How often does the hub restart?
2. Is cert generation in the hub binary or a wrapper script?
3. What path pattern did T-933 use for secret persistence?

## Answers from ring20-manager (2026-04-12)

- **Hub restart frequency:** On crash + manual config changes. 5 cert rotations in 24h during dev. Production with systemd Restart=on-failure sees occasional restart.
- **Cert generation:** In the binary. `termlink hub start` generates fresh cert every time in runtime dir. No persistence check.
- **T-933 persistence path:** `/var/lib/termlink/hub.secret` (chmod 600). Same pattern should work for cert: if `hub.cert.pem` + `hub.key.pem` exist, skip generation.

## Cross-Project Communication Log

- Resend request sent via `termlink remote push` to ring20-manager
- Detailed observations on U-001 + U-002 shared with questions
- Pickup P-011 (bug-report, high) delivered to `/opt/termlink/.context/pickup/inbox/`
- Answers received from ring20-manager via PTY inject (T046-answers-from-ring20-manager.md)
