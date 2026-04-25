# T-1125: TermLink send-file — Hub Acceptance vs Delivery

**Status:** GO (documentation + upstream pickup)
**Date:** 2026-04-12

## Problem Statement

`termlink remote send-file` returns `ok:true` based on hub acceptance,
not end-to-end delivery. ring20-manager sent 3 files to framework session —
all reported success, zero were delivered (event-only sessions silently drop files).

## Findings

- Confirmed: `ok:true` = hub accepted the file, NOT = receiver got it
- Event-only sessions (non-PTY) cannot receive files via send-file
- No delivery confirmation mechanism exists in TermLink protocol
- Documented caveat in CLAUDE.md (T-1128)

## Decision

**GO** — Document the caveat, create upstream pickup for TermLink repo.
The fix (delivery confirmation or inbox store-and-forward) is TermLink's
responsibility, tracked via pickup T-1127.
