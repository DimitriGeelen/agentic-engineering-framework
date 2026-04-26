# T-1499 — Ring20 Hosting Mediation Report

**Task:** T-1499 — Pickup: Advies gevraagd: Ring20 hosting pattern voor Novis simulator + REST proxy (from 003-NTB-ATC-Plugin)
**Workflow:** inception (mediation, not authoring)
**Status:** mediated end-to-end — question received, relayed, answered, and delivered back to the consumer
**Source:** P-004 pickup envelope (003-NTB-ATC-Plugin / T-045, 2026-04-19)

## Summary

The framework received a pickup envelope (P-004) from 003-NTB-ATC-Plugin asking five questions about hosting two .NET Core 10 services on Ring20. The questions were not answerable from the framework — they belong to ring20-management's authority — so the framework mediated rather than authored: relayed the questions to ring20-management's TermLink session, captured the evidence-cited response, and delivered it back to the consumer.

The full 9332-byte reply from ring20-management lives verbatim in the T-1499 task body under `## Response from ring20-management`. This artifact records the **mediation flow**, not the answer itself; the answer's canonical home is the task file (and now the consumer's inbox).

## Why a research artifact for a mediation task

C-001 / G-009 require a `docs/reports/T-XXX-*.md` artifact for inception tasks before research-style work. This task is unusual — there was no exploration spike, just a routing decision and a TermLink relay. But the mediation pattern itself is novel enough to capture:

- A pickup envelope arriving misrouted (framework ≠ correct authority).
- The framework using its TermLink fleet topology to dispatch a Claude worker on the correct authority's machine.
- Capturing the response verbatim into the task body and pushing it back to the consumer.

If this pattern recurs (cross-fleet question relays via TermLink dispatch), there is a generalizable primitive worth lifting into `agents/dispatch/` or a new `fw mediate` subcommand. For now, this artifact documents the bespoke flow.

## Mediation flow (audit trail)

1. **2026-04-26T11:13** — pickup envelope P-004 ingested by router; auto-created T-1499 (`workflow_type: inception, owner: agent`).
2. **2026-04-26T13:30** — first attempt at recommendation: NO-GO (decline as misrouted).
3. **2026-04-26T14:46** — auto-closed as GO via Watchtower (during this conversation, before user pushback).
4. **2026-04-26T14:50** — reopened on user direction; recommendation revised to DEFER + relay via TermLink.
5. **2026-04-26T15:24** — discovered `tl-chh52mlp` on ring20-management hub (192.168.10.122:9100) is a bare bash shell, not an attended agent. Switched from inject-keystrokes to remote-dispatch model.
6. **2026-04-26T15:25** — wrote `/tmp/T-1499-relay-prompt.md` (5 questions + framing) and base64-piped it via `termlink remote exec` to `/tmp/T-1499-relay-prompt.md` on .122.
7. **2026-04-26T15:25** — launched `claude -p` from `/opt/proxmox-ring20-management` on .122 against the prompt. PID 95577. (First background-launched run produced 0 bytes output for unknown reason; second synchronous-pipe run via `cat … | claude -p` succeeded.)
8. **2026-04-26T15:31** — captured 9332-byte response: evidence-cited, three-reasons defer to YellowTwig Azure for production, Ring20 OK for dev/test.
9. **2026-04-26T17:00** — pushed response back to consumer's session `tl-bubfbc3w` (host=dev-box, project=ntb-atc) via `termlink remote push local-test`. Both the markdown reply and a wrapping pickup envelope (P-040) landed in the local hub inbox at `/tmp/termlink-inbox/`.

## Open items / handover

- **Read receipt:** the consumer's TermLink session has a stale 8-day heartbeat. Cannot confirm the consumer has actually pulled the files from `/tmp/termlink-inbox/`. The relay-back is fire-and-forget.
- **No SSH path:** `~/.ssh/config` is not configured on this machine; `fw dispatch` cross-machine SSH is unavailable. If the TermLink push doesn't land, the only fallback is manual delivery (someone copies the files to dev-box).
- **dev-box hub profile:** none exists. If future relays to ntb-atc become routine, add a hub profile or set up SSH config.
- **The actual hosting decision:** lives in 003-NTB-ATC-Plugin / T-045, not here. The framework's job is done; the consumer reads ring20-management's evidence and decides between Ring20 dev/test and YellowTwig Azure production.

## Lessons

- **Mediation is a first-class outcome.** When a pickup envelope arrives at the wrong addressee, the framework can mediate (relay → capture → deliver) instead of declining. NO-GO was the wrong default; user pushback corrected it.
- **TermLink remote exec + claude -p is a viable cross-machine answering primitive.** ~7 minutes wall-clock for a thoughtful 5-question evidence-cited response from .122.
- **Inject-keystrokes assumes an attended agent on the other end.** When the target is a bare shell, dispatch a fresh Claude worker against a prompt file instead — much more reliable than synthesizing keypress sequences.
- **`termlink remote send-file` writes to the TermLink bus, not the filesystem.** Use base64-piped `remote exec` for direct filesystem placement.
