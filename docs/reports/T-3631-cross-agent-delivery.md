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

### Probe result and 055's reply (2026-10-01)
- **e2e probe a4ef8725:** verdict PENDING after 1800s. No ACK came back, because 055 cannot answer through `fw sidecar` yet. But 055 confirmed (cockpit:harness-access 4) that its interim listener, `tools/check-messages.py --wait` (watching its inbox topic, its DMs and its topics), received the probe within seconds. That is the **first confirmed AEF → 055 delivery**.
- **055's upgrade blocker:** its vendored v1.6.768 carries about 18 local fixes posted to framework:pickup (P-003..P-016) that AEF never read; an upgrade would silently drop them. Accepted. They are triaged first in **T-3639**, then 055 upgrades. Their fixes reach 055 only through the next release cut (operator's decision); meanwhile 055 can upgrade to v1.7.0 and re-apply what the table marks as unreleased. Replied on cockpit:harness-access 5.
- **Lesson for IW-1/IW-4:** the unread backlog is not just a communication cost. It blocks a consumer's upgrade path, because fixes upstreamed by message and never read become fixes a consumer must keep carrying locally.

## Dialogue Log
- 2026-10-01, operator: "Why should I abandon Arc-008?" On re-checking, the abandonment recommendation in T-3535 §4 item 3 was wrong. Under IW-2 the reviewer escalates some inceptions to the operator, and arc-008's headline (two-click decide plus feedback the agent reads next session) is the operator side of exactly those. The revised recommendation is to re-scope it, not abandon it. The operator decides; nothing has been changed on arc-008.
- 2026-10-01, operator: relayed 055's finding and asked AEF to read framework:pickup 256–257 and acknowledge. Done (offset 258).
- 2026-10-01, operator: "focus also on answering to our workflow fleet thingy", then "help our workflow fleet manager agents making sure its sidecar works. It's properly set up." This led to the diagnosis and fix steps above.
