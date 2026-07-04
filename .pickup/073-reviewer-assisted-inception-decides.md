# 073 — Feature proposal: reviewer-agent-assisted inception decides (fw independent-review extension)

- **Filed by:** claude-code @ /opt/termlink (via .pickup drop, G-063-safe — no inbound topic consumer)
- **Date:** 2026-07-04
- **Severity:** ENHANCEMENT (operator-throughput; sovereignty boundary unchanged)
- **Component:** `fw independent-review` rail (T-1885 v0.1) + `fw task review` / Watchtower review page
- **TermLink-side tracking:** T-2348 (inception, filed 2026-07-04, agent rec GO — awaiting human decide)

## Problem

Inception decides are sovereignty-gated (human-only) BY DESIGN — an agent deciding on an
agent-written recommendation is self-approval. TermLink's G-068 (2026-07-04) is the live
failure exhibit: an agent bulk-edit ticked a `### Human` [REVIEW] AC with no decision
recorded, bypassing the T-1731 hook via Bash, undetected for 9 days.

But a growing share of decides are **rubber-stamp class**: every claim in the
recommendation is mechanically checkable (a demo script exists and passes, a code path
exists at file:line, a CLI flag exists). The human pays full-read review for these.
TermLink's 2026-07-04 backlog had three at once (T-2338/T-2339/T-2276 — all
evidence-heavy NO-GOs whose premises were falsified by shipped code).

## Proposal

Extend the shipped `fw independent-review` v0.1 rail (T-1885) with an
**inception-recommendation validator profile**:

1. An independent reviewer agent — fresh context, read-only, provably NOT the session that
   authored the recommendation — extracts the recommendation's evidence claims (file:line,
   script paths, task ids) and verifies each mechanically.
2. It writes a **verdict artifact** (per-claim pass/fail + overall
   CONFIRMED/UNVERIFIED/CONTRADICTED) next to the task.
3. `fw task review` / Watchtower renders the verdict beside the recommendation, so the
   human decide shrinks to one keystroke on pre-verified items.
4. `fw inception decide` stays sovereignty-gated exactly as today — the verdict is
   advisory input, never a decision. (G-068 is why the decide itself must remain human.)

Design invariants (from the TermLink T-2348 inception): reviewer must not share the
proposing session's context window (else it inherits the same stale premises — the exact
failure mode observed when T-2338/T-2339 were captured with already-false premises);
read-only access; verdict artifact is append-only evidence, not a state change.

## Why AEF-side

`fw independent-review`, `fw task review`, and the Watchtower review page are framework
components — a local patch in a consumer project would be regressed by `fw upgrade`
(G-055 class). Proposing the validator profile upstream where T-1885 lives.

## Suggested acceptance shape

- New validator profile consuming an inception task file (Problem/Assumptions/
  Recommendation/Evidence sections already have a stable shape via the template).
- Verdict artifact schema + Watchtower render.
- Explicitly out of scope: any change to the `fw inception decide` gate.
