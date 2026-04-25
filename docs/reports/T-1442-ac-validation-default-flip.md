# T-1442: AC Validation Default-Flip — Mechanical Verification with Persisted Evidence

## Status
**Phase:** Exploration / Dialogue (in progress)
**Linked:** T-1443 (I-B reviewer agent — depends on this inception's GO)

## Problem

Human ACs are accumulating as approval-queue noise. Many describe checks that don't require human judgment — they're mechanically evidenceable but currently default to Human review. This adds friction without proportional risk-management value.

Pattern observed across multiple consumer projects.

## Framing North Star

| Axis | Value |
|---|---|
| **Goal** | Frictionless development |
| **Constraint** | Preserve antifragility + reliability + auditability (4 directives) |
| **Pain** | Human-AC backlog = friction without proportional risk management |
| **Solution shape** | Mechanical verification + reviewer agent = remove friction *without* removing rigor |

## Proposal

Flip the default for AC validation from "Human" toward one of three mechanical tiers, with **persisted evidence** (not just exit-code pass/fail). Human AC is reserved for genuine judgment (tone, UX feel, strategic go/no-go).

| Tier | Method | Existing? |
|---|---|---|
| A | Programmatic (shell, curl, grep) | Yes — Tier 1 / P-011 |
| B | E2E via TermLink (spawn, inject, output) | Yes — Tier 2 |
| C | Browser automation via Playwright | Yes — Tier 3 (`fw test playwright`) |

Infrastructure exists. What is **new**:
1. Default-flip in AC classification guidance (T-954 extension)
2. **Evidence persistence** — verification runs must capture artifacts (stdout, screenshots, structured records), not just exit codes
3. Hand-off contract to I-B (reviewer agent) for evidence assessment

## Open Questions (in scope for this inception)

- **Q1 — Evidence persistence shape**: append to task file? `fw bus post`? `docs/reports/T-XXX-evidence.md`? combination?
- **Q3 — Trigger model**: runs on `--status work-completed`? hard pre-req gate before `work-completed` is even allowed? Watchtower button? combination?
- **Q5a — Relationship to existing controls**: is this an *extension* of T-954 (AC classification) + P-011 (verification gate) + `fw verify-acs`, or a *replacement*?
- **Q (emergent) — Migration**: how do we treat the existing backlog of Human ACs that are mechanically evidenceable in retrospect? Bulk re-classify? Leave alone? Reclassify only on next touch?

## Confirmed-yes (locked, not in dialogue)

- **Q2** (was open, now confirmed): Reviewer agent (I-B) **may auto-tick Agent ACs** and only escalate Human ACs when reviewer says "needs human." Reviewer authority is **mechanical-tick only** — sovereignty over Human ACs preserved.
- Two linked inceptions, sequenced I-A → I-B.

## Out of Scope

- Reviewer agent design (I-B / T-1443).
- Re-classifying every existing Human AC in the backlog — out per "incremental, not bulk."

## Dialogue Log

### 2026-04-25 — Genesis (user-initiated)

**User observation:** Human ACs becoming noise. Three validation methods already exist (programmatic / TermLink E2E / Playwright). Pattern emerges across multiple projects. Two proposals:
1. Default-flip toward mechanical verification with evidence recording
2. Independent reviewer agent (own profile) dispatched via TermLink to assess evidence and ACs

User directive: "playback this to verify we have a common understanding" before incepting.

**Agent playback (this file's framing + 5 open questions).**

**User answers:**
1. ✅ Capture correct
2. ✅ Reviewer auto-ticks Agent ACs; escalates to human only when "needs human"
3. ❓ "`work-completed` trigger or pre-req for work-completed?" — explore in I-A
4. ❓ "incept that" → reviewer scope (generic vs per-tier) → folded into I-B
5. ❓ "incept that, think about goals + risks + frictionless development" → framing absorbed, relationship-to-existing-controls explored in both

### Next dialogue turn

Awaiting alignment on the four Open Questions above. Recommend tackling Q3 (trigger model) first — it shapes Q1 (where evidence lands) and Q5a (extension vs replacement).

## Anchor files

| Artifact | Path |
|---|---|
| Inception task body | `.tasks/active/T-1442-ac-validation-default-flip--mechanical-v.md` |
| Linked sister inception | `.tasks/active/T-1443-independent-reviewer-agent--termlink-dis.md` |
| Existing AC guidance | `CLAUDE.md` § AC Classification Guidance (T-954) |
| Existing verification gate | `CLAUDE.md` § Verification Gate (P-011) |
| Existing CLI | `bin/fw verify-acs` |
