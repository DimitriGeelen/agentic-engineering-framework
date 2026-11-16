# T-5186 — Watchtower overview pages at volume

**Task:** T-5186 (inception) · **Trigger:** dimitri-mint-dev msg fc3a6ba2, 2026-11-16 · **Status:** exploring

## Question

Why do Watchtower overview pages (`/approvals`, `/`) slow down as a project grows? 1409-sprind (~6,150 tasks)
times out after 90 s. Is it systemic work per request, CPU starvation on a loaded host, or both? Does it need an
index layer, or is caching enough?

## Reported evidence (from the trigger)

| Project | Tasks | `/approvals` |
|---|---|---|
| dimitri-mint-dev | ~233 | 0.95 s |
| 1023 | ? | 1.25 s |
| 055 | ? | 4.3 s |
| 1409-sprind | ~6,150 | > 90 s (also `/`); `/review/T-6144` 0.03 s |

The host load average was 37. Since 2026-11-12, Watchtowers started from claude-fw sessions run at CPUWeight=20.

## Method

Profile in-process with the Flask test client on this repo (about 920 active + 4,250 completed task files, close to
1409's size). This measures CPU work with no host contention. 1409 is never touched.

## Findings

(filled in as measured)

## Dialogue Log

- 2026-11-16: the operator said "proceed as suggested" after the proposal to measure first, then recommend.
