# T-2121 — T-2091 prevention follow-up: structural detection for `.tasks/` active↔completed divergence

> **Inception research artifact** (C-001). Source task: `.tasks/active/T-2121-*.md`
> (active / started-work). This is a **live inception** — the research below is
> grounded in the actual T-2091 origin and current codebase state, not extracted
> boilerplate. **Recommendation: GO (prongs 1 + 3); DEFER prong 2** — see below.
> The decision authority is the human (`fw inception decide` is agent-blocked under
> `$CLAUDECODE`); this artifact is the advisory.

## Research question

After T-2091 cleaned up an orphaned active↔completed divergence, should the
framework ship *structural prevention* for the class, or is the T-2091 manual
cleanup pattern sufficient?

## Origin (T-2091, the RCA that spawned this)

On 2026-05-22 a session finalising two inception decisions (T-1981, T-1987) wrote
the `work-completed` copy to `.tasks/completed/` **manually** — the `git mv` +
commit never happened. Result: each task file existed in **both** `.tasks/active/`
(tracked, stale `status: captured/started-work`) **and** `.tasks/completed/`
(untracked, canonical `status: work-completed`). The metadata-refresh worker kept
bumping `last_update:` on the active/ copies, masking the divergence for ~7 days.
The G-052 STRUCTURE audit eventually FAILed ("Duplicate task IDs") and **blocked
every pre-push audit** until cleared — a local-only handover commit (`e1a6fd50`)
was stranded.

## The three proposed prongs (from the task ACs)

1. **PreToolUse hook (Write|Edit)** refusing same-id duplicates between
   `.tasks/active/` and `.tasks/completed/` — *prevent the divergence at write time*.
2. **BVP-estimator / `last_update` bumper cross-check** before mutating
   `.tasks/active/` files — *stop the metadata worker from masking a divergence it
   shouldn't be touching*.
3. **`bin/fw doctor`** surfacing untracked files under `.tasks/{active,completed}/`
   — *catch the orphaned untracked copy early, before the 7-day mask*.

## Analysis (grounded in current state)

- **Detection exists; prevention does not.** The audit already has a G-052 STRUCTURE
  check ("No duplicate task IDs across active/ and completed/") — but it fires *after*
  the divergence is committed and only at audit time (which is why it surfaced 7 days
  late and at the worst moment, a pre-push gate). There is **no write-time prevention
  and no early doctor surface** (verified: no dedup hook in `agents/context/`, no
  untracked-`.tasks/` check in `audit.sh`/`bin/fw`).
- **The class recurred.** `T-100202` ("Task-ID allocator inflation + split-view
  collision RCA") is an **active** task today — direct evidence the divergence /
  collision class is not a one-off, which is the strongest argument for structural
  prevention over "cleanup when it happens."
- **Cost/blast-radius.** Prong 3 (doctor surface) is cheap and low-risk — a read-only
  `git status --porcelain .tasks/` check. Prong 1 (write hook) is moderate: it must
  **not** block the legitimate `fw task update --status work-completed` transition
  (which does `git mv`, so both copies never co-exist mid-transition) — it should
  target *manual* writes to `completed/T-X` while `active/T-X` is still present. Prong
  2 (bumper cross-check) is the most complex and lowest marginal value: once prongs 1+3
  exist, the metadata-worker masking is largely moot because the divergence is caught
  at creation or at the next `doctor` run.

## Recommendation — GO (prongs 1 + 3), DEFER prong 2

- **GO prong 3 first** (cheapest, highest early-detection value): `fw doctor` WARNs on
  any untracked file under `.tasks/{active,completed}/`. Closes the 7-day mask window.
- **GO prong 1** (write-time prevention): PreToolUse hook blocks a Write/Edit that
  would create `completed/T-X` while `active/T-X` exists (and vice-versa), with a
  bypass for the `fw task update` git-mv path. Prevents the divergence at the source.
- **DEFER prong 2** (bumper cross-check): revisit only if, after 1+3 ship, evidence
  shows the metadata worker still creates masking drift. Lower marginal value once the
  divergence can't form silently.

Each GO prong files as its **own build task** ("one bug = one task") with
`unlocks_inception_decision: [T-2121:<decision-id>]` traceability.

**Why not NO-GO:** the class recurred (T-100202) and the only current control fires
7 days late at a push gate — cleanup-when-it-happens has already cost a stranded
handover once. **Why not DEFER-all:** the evidence (recurrence + late-only detection)
is sufficient to act now; deferring the whole thing would be a confidence hedge, not
an evidence gap (per the DEFER-for-evidence-not-confidence discipline).

## Handoff

Human decision via `fw task review T-2121` → Watchtower `/inception/T-2121`.
