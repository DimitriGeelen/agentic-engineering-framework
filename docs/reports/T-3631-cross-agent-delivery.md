# T-3631: Cross-agent delivery (inception research artifact)

**Origin:** a structural finding from 055-agentic-fleet-cockpit (framework:pickup offset 257, their T-406), relayed by the operator on 2026-10-01. The operator asked to "help our workflow fleet manager agents making sure its sidecar works. It's properly set up."

## Findings (2026-10-01)

### Verified 055 claims
- `fw pickup send` without `--remote` writes only to the sender's own inbox and prints "Created", with no not-delivered notice (lib/pickup.sh:617, :681). Filed as T-3628.
- `pickup_next_id` scans inbox, processed, rejected and auto-deferred, but no sent store (lib/pickup.sh:337). Also T-3628.
- framework:pickup has 258 posts and one consumer receipt, which stops at offset 81 (`termlink channel info`).

### Sidecar diagnosis on host .107
- The hub is running (/var/lib/termlink/hub.sock).
- TermLink `notify-sidecar.sh` listeners run only for claude-termlink (fp d1993c2c…), claude-termlink-alt and framework-agent-systemd. There is none for 055, and none for the interactive 999 session. 999's consults arrive through the framework's UserPromptSubmit consult hook instead: 63 injected, 0 pending, 0 dead letters.
- `termlink whoami` is ambiguous on this host: it finds three candidate sessions and refuses to pick. So `fw sidecar whoami` reports the identity fingerprint as "termlink unreachable".
- **055's root cause:** its vendored framework is v1.6.768, which has no `fw sidecar` ("Unknown command: sidecar"), and its .claude/settings.json has no consult hook. Consults addressed to 055 reach the hub, and nothing in 055 reads them. The current release, v1.7.0 (2026-09-24), contains the full sidecar.

### Actions taken
- **framework:pickup 258:** an acknowledgement of 255–257, deliberately without a receipt for the unread range 82–254.
- **cockpit:harness-access 1:** the harness answer, with no secrets.
- **cockpit:harness-access 3:** the sidecar diagnosis and fix steps for 055's own session: `fw upgrade`, `whoami`, restart, `inbox`, then `fw sidecar e2e --peer 999-Agentic-Engineering-Framework`.
- **Probe:** `fw sidecar e2e --peer 055-agentic-fleet-cockpit`, sent 12:37Z. It is expected to time out until 055 upgrades. Its result is evidence for IW-1/IW-2.
- **Not done:** upgrading 055 from here. 055 has its own live agent working in that repo; running an upgrade into its checkout from this session risks colliding with that session, and the repo is 055's to change.

## Dialogue Log
- 2026-10-01, operator: relayed 055's finding and asked AEF to read framework:pickup 256–257 and acknowledge. Done (offset 258).
- 2026-10-01, operator: "focus also on answering to our workflow fleet thingy", then "help our workflow fleet manager agents making sure its sidecar works. It's properly set up." This led to the diagnosis and fix steps above.
