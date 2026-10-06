# T-3922 — Waiting sidecar messages, triaged (2026-10-06)

Operator (2026-10-06): "what I need to know is: it's a proposal to do something — do you
want to take it or not? … check first if that's already been done … close the done ones
… a number remains for me to judge."

129 waiting items (89 we sent, 40 we received) were assessed by three read-only TermLink
workers (per-item evidence: `T-3922-triage-ring20.md`, `-832-010.md`, `-rest.md`;
verdict map: `T-3922-verdicts.json`). Integrated here.

| Verdict | Items | What happens |
|---|---:|---|
| close — answered, done, acked, superseded or moot (evidence per item) | 118 | operator runme `drop-settled-waiting` (drop is operator-only) |
| take-on — ours to do, not yet done | 5 tasks | T-3923 … T-3927 filed |
| operator — a real judgment call | 4 decisions (9 items) | below |

## Decisions for the operator

1. **Make a post-upgrade report the standard last step of a consumer upgrade?**
   Raised independently by ring20-manager (8a2e40db), ring20-dashboard (53155c47) and
   832 (3fdccbb3). Each of their reports found real bugs (T-3906, T-3907, T-3925–T-3927).
   **Recommend: yes, optional** — a one-screen structured report the consumer may send.

2. **Build one harness-neutral continuous-run supervisor (`fw continuous run --adapter
   claude|codex|…`) and adopt ring20's `fw orchestrate` / orchestrator-session design?**
   ring20-manager 89fdfeb4 (multi-vendor review recommendation) and ff113a4b (status of
   their 2026-08 pickup). Overlaps arc-012 (T-3239, T-3895).
   **Recommend: one inception covering both — not a build, not a roadmap commitment yet.**

3. **Adopt 832's runme launcher design — the operator's yes bound to the exact bytes
   that run?** 832 8d8b2ecc (offer) + 5da1cbb2 (files, sha256 90d83b83…); already your
   inception T-3901. **Recommend: yes, evaluate the files read-only under T-3901.**

4. **A "patch-series-aware" preserve mode for `fw vendor`?** ring20-dashboard 53155c47.
   **Recommend: not now — decide after T-3850's outcome; it widens vendor semantics.**

## Taken on (tasks filed, horizon next)

- T-3923 hook arithmetic sanitising + atomic handover lock (gap left by T-3917; ring20 c939d218)
- T-3924 `fw config set` key-case mismatch — inception commit limit silently stays 2 (ring20 0edfc78d)
- T-3925 `fw upgrade` footer lists PATCH-LOST in-file patches (ring20 8a2e40db)
- T-3926 `fw git install-hooks` keeps a consumer's own pre-commit lines (832 3fdccbb3)
- T-3927 doctor says the post-upgrade sidecar-watcher FAIL is expected and how to fix it (ring20-dashboard 53155c47)

## Notes

- 31 of the 118 closes are inbound: dropping one sends its sender a DROPPED receipt
  carrying the reason (e.g. "fixed by T-3899, already answered"). Each was checked for an
  answer or fix in evidence.
- The list was this long because a sent message stays "waiting" until the peer confirms
  it was read; most closes are our own acks, release notes and answers. T-3908 (read
  messages settle the retry ladder) and a follow-up for the waiting list itself address
  the cause, not just this backlog.
