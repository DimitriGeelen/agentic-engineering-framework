# T-1126 — TermLink Communication Protocol: inject vs push

## The Discovery

Session S-2026-0412-0935 tried to communicate with ring20-manager (.109)
about TermLink issues U-001/U-002. Two approaches, two outcomes:

### Attempt 1: push (failed)
```
termlink remote push 192.168.10.109:9100 --secret ... --message "..."
```
Result: 1920 bytes delivered to `/tmp/termlink-inbox/push-message.txt`.
**Zero response.** Agent didn't process the inbox.

### Attempt 2: inject (succeeded)
```
termlink remote inject 192.168.10.109:9100 ring20-manager --secret ... --enter "..."
```
Result: 821 bytes injected directly into ring20-manager's PTY.
**Immediate response.** Agent processed the message, resent G-005 and
U-001/U-002/U-003 files within seconds.

## The Protocol

| Communication type | TermLink tool | Why |
|-------------------|--------------|-----|
| File delivery (async, no response needed) | `remote push` | Inbox, processed on schedule |
| Questions needing answers | `remote inject --enter` | Direct PTY input |
| Command execution with output | `remote exec` | Structured, synchronous |
| Keystroke simulation | `remote inject` (no --enter) | Raw input |

## Why Agents Default Wrong

Agents default to `push` because:
1. It feels safer (non-intrusive, like email)
2. The name suggests "send a message"
3. inject feels aggressive (typing into someone's terminal)

But push is **fire-and-forget** — the receiving agent has no trigger to
process inbox files. inject is **immediate** — it appears as user input
in the receiving agent's conversation.

## Proposed Codification

1. **CLAUDE.md rule** in §TermLink Integration:
   "For interactive cross-agent communication (questions, requests, feedback),
   use `termlink remote inject --enter`. For async file delivery, use push."

2. **fw termlink wrapper**: Add `fw termlink message` subcommand that
   defaults to inject for text, push for files.

3. **Level D improvement**: Record as ways-of-working change per Error
   Escalation Ladder.
