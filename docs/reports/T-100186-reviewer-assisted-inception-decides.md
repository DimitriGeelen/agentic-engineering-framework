# T-100186 — Reviewer-assisted inception decides (validator profile)

**Origin:** pickup `.pickup/073-reviewer-assisted-inception-decides.md` (TermLink session, 2026-07-04; TermLink-side tracking T-2348).
**Task:** T-100186 (inception). **Status:** research complete, GO recommended, decide pending.

## Problem

Inception decides are sovereignty-gated (human-only) by design. But a growing share are
rubber-stamp class: every claim in the agent's recommendation is mechanically checkable
(file exists at path, code at file:line, demo script passes, task in completed/). The
operator pays full-read review cost for these. TermLink's 2026-07-04 backlog exhibit:
three evidence-heavy decides at once whose premises were falsifiable by shipped code.
AEF's own review queue routinely carries 3+ GO handoffs per session.

## Premise check (pickup claims vs AEF reality)

| Pickup claim | AEF reality | Verdict |
|---|---|---|
| "extend the shipped `fw independent-review` v0.1 rail (T-1885)" | **No `fw independent-review` verb exists in AEF.** AEF's T-1885 is an unrelated fabric-card task. The reference is TermLink's task numbering leaking cross-repo. | CONTRADICTED (reference), but a *better* rail exists |
| "an independent reviewer agent — fresh context, read-only, provably not the authoring session" | Already shipped: `fw reviewer T-XXX --dispatch` (T-1951) — isolated TermLink worker, fresh process, zero parent context | CONFIRMED — reusable as-is |
| "verdict artifact next to the task" | Already shipped: reviewer writes `## Reviewer Verdict` block into the task file (T-1443 v1.x), atomic write, Watchtower renders it | CONFIRMED — extend, don't invent |
| "`fw task review` / Watchtower renders verdict beside recommendation" | `/inception/<id>` renders Recommendation; reviewer verdict block renders on task pages. The *join* (claims-verdict beside recommendation on the inception decide page) is the missing render slice | PARTIAL |
| "decide stays sovereignty-gated" | `fw inception decide` refuses under CLAUDECODE=1 (T-1259/T-1260); unchanged | CONFIRMED — out of scope |

The pickup's mis-reference does not invalidate the proposal — it lands on an even more
established AEF rail: the T-1443 reviewer lineage (`lib/reviewer/static_scan.py`,
`fw reviewer`, dispatch mode, override system, auto-tick sovereignty rails).

## What exists to build on

1. **`fw reviewer T-XXX --dispatch`** — isolation property the pickup demands (fresh
   context, read-only scan, posts verdict via fw bus). T-1951.
2. **`static_scan.py` section parsing** — already parses `## Recommendation` on inception
   tasks (detector `defer-as-hedge`, T-2145) and disposition rationales (T-100159).
3. **`ships_in:` referent resolver** (T-1984, `check-inception-decisions` +
   `update-task.sh` close gate) — already mechanically validates five referent shapes:
   `path/file.ext`, `module.function`, `tests/…::test_fn`, `T-XXX`, `deferred:T-YYYY`.
   This IS a claims verifier for exactly the claim classes the pickup lists.
4. **Watchtower verdict render** — reviewer verdict blocks already render; `/inception/<id>`
   page exists (T-2125 class-correct URL work).

## Missing pieces (build scope if GO)

- **Claims extractor:** parse `## Recommendation` + `Evidence:` bullets for verifiable
  referents (file paths, `file:line`, `T-XXX`, fenced shell commands). Reuse the ships_in
  shape grammar; add `file:line` (existence + line-count bound) and optional
  command-execution class (opt-in, sandbox concerns → follow-up).
- **Verifier + verdict schema:** per-claim `pass/fail/unverifiable` + overall
  `CONFIRMED / UNVERIFIED / CONTRADICTED`, written as a `## Recommendation Verdict`
  sibling block (same atomic-write path as reviewer verdicts). Append-only evidence;
  never mutates Recommendation or Decision.
- **Render slice:** `/inception/<id>` shows the verdict table beside the recommendation;
  `/approvals` badge (e.g. "evidence: 7/7 confirmed").
- **Invariant:** verdict is advisory input only. No change to `fw inception decide` gate,
  no auto-decide, no auto-tick of anything on inception tasks.

## Assessment against directives

- **Reliability (D2):** recommendations with dead references (the T-2338/T-2339 class —
  and this very pickup's own T-1885 mis-reference, caught by exactly the mechanical check
  proposed) surface as CONTRADICTED before the operator invests reading time. The premise
  check above is a live demonstration: this validator, run by hand, found a false claim
  in its own origin proposal.
- **Usability (D3):** operator decide cost on rubber-stamp-class inceptions drops to
  verdict-glance + keystroke.
- **Antifragility (D1):** G-068-class silent self-approval stays impossible — the gate is
  untouched; the verdict widens the evidence surface instead.
- **Sizing:** one build slice for extractor+verifier+block-write (reviewer module),
  one for Watchtower render. Fits the one-task-one-deliverable rule as 2 slices.

## Recommendation

**GO** — scoped as: (1) build slice A `lib/reviewer/` recommendation-claims validator
(extractor + verifier + `## Recommendation Verdict` block, exposed as
`fw reviewer T-XXX --recommendation` or auto-run within the existing inception scan
path); (2) build slice B Watchtower `/inception/<id>` + `/approvals` render. Explicitly
out of scope: any change to `fw inception decide`; command-execution claim class
(defer to a follow-up with sandbox design).

## Dialogue Log

- 2026-07-04: No human dialogue this phase — pickup-driven inception filed under standing
  autonomous directive. Premise check performed against repo (grep for
  `independent-review` in lib/agents/bin; `fw help`; T-1885 task file) — pickup's rail
  reference CONTRADICTED, remapped to T-1443 reviewer lineage. Filing-time DEFER
  upgraded to GO after the spike. Operator decide pending via Watchtower.
