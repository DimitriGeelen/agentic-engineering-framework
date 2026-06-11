---
id: T-2030
name: "review hand-offs must always emit concrete verified clickable links"
description: >
  Structural fix so review/Human-AC hand-offs always carry concrete resolved clickable
  links + screenshot links, not agent-authored commands or vague navigation

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-05-24T14:27:04Z
last_update: '2026-06-11T22:24:05Z'
date_finished: 2026-05-25T19:43:46Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-24T14:27:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-24T14:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-25T19:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-2030: review hand-offs must always emit concrete verified clickable links

## Problem Statement

Review hand-offs repeatedly ship links the human cannot act on. Across 3+ sessions the
agent has pasted: routes that 404 (`/appearance` when the real route is
`/settings/appearance`), vague "base from `bin/fw watchtower url`" instead of a resolved
URL, references to UI states that may not exist (e.g. "open an arc with a NO-GO"), and
screenshot paths never verified to serve. The reviewer (the human) opens the link, hits a
404 or a dead end, and the hand-off is wasted. User verbatim: *"useless for me i need
concrete links."* Why now: the failure recurred despite an advisory CLAUDE.md rule — pure
guidance has not prevented it (see [[feedback_review_concrete_links]]).

## Assumptions

- **A1:** The majority of bad links are *paths that don't exist in Flask's route table*
  (guessed or typo'd), not transient server errors. → testable by sampling past bad links.
- **A2:** The agent *can* verify a link (curl / url_map lookup) at hand-off time but does
  not do so reliably when it's only an advisory rule.
- **A3:** A mechanical check at the hand-off chokepoint (`fw task review`) would catch the
  bulk of these before the human ever sees them.

## Exploration Plan

Three candidate fixes, evaluated against the recurrence evidence:

- **Candidate A — doc/checklist ("curl every link before pasting").** Already exists as
  guidance in the feedback memory. *Rejected as sole fix:* advisory-only; it is precisely
  what failed 3×. Keep as backstop, not primary.
- **Candidate B — render-time link helper.** A helper the agent calls to resolve + verify
  a URL while writing it. *Weakness:* opt-in; bypassed whenever the agent forgets to call
  it — same failure mode as A.
- **Candidate C — `app.url_map` validation at hand-off (PREFERRED).** At `fw task review`
  time, scan the task's `## Recommendation` Evidence and Human-AC `**Steps:**` for
  Watchtower URLs, extract each path, and validate it against `web.app.app.url_map`
  (parameterless routes resolved directly; parameterised routes HTTP-probed). Emit
  WARN/block on any unresolvable path. Self-maintaining — routes derive from the live app,
  reusing the exact mechanism T-2042 already shipped (`discover_get_routes()` over
  `app.url_map`). Mechanically catches `/appearance`→404.

## Technical Constraints

- Validation runs where the app is importable (or where Watchtower is reachable for HTTP
  probes) — `fw task review` already runs in that context.
- Parameterised routes (`/review/<id>`, `/arcs/<slug>`) can't be url_map-matched by string
  equality; resolve the rule pattern or HTTP-probe the concrete URL instead.
- Scope to Watchtower URLs (host == resolved `bin/fw watchtower url`); external URLs are
  out of validation scope.

## Scope Fence

- **IN:** mechanical validation of Watchtower links appearing in `## Recommendation`
  Evidence and Human-AC `**Steps:**`, at `fw task review` time.
- **OUT:** external (non-Watchtower) URLs; screenshot-file existence (a separate probe);
  prose/wording quality of the surrounding text; auto-rewriting bad links (flag, don't
  silently mutate).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Root cause is "no mechanical link validation at the hand-off chokepoint" (confirmed) and
  the fix reuses existing route-derivation (T-2042 `discover_get_routes()`) — bounded.
- A bad path (`/appearance`) fails the check and a good one (`/settings/appearance`) passes
  — testable with a unit test.
- The check is WARN-first (doesn't hard-block legitimate edge cases) — reversible.

**NO-GO if:**
- Link validation can't be made reliable without a full headless browser per review (cost
  exceeds benefit), or
- Parameterised-route probing proves too flaky to gate on.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO — implement Candidate C (`app.url_map` validation at hand-off), with
Candidate A's "curl/verify before paste" retained as the advisory backstop.

**Rationale:** The root cause is structural, not behavioural: there is no mechanical check
of review links at the hand-off chokepoint, so guessed/typo'd routes reach the human. The
advisory rule already failed 3× — only a mechanical gate at `fw task review` prevents
recurrence. The fix is bounded and low-risk because the route-derivation machinery already
exists (T-2042 `discover_get_routes()` over `web.app.app.url_map`); this task reuses it
rather than building new infrastructure. WARN-first keeps it reversible.

**Evidence:**
- Recurrence record: [[feedback_review_concrete_links]] — `/appearance` (404) vs real
  `/settings/appearance`, "base from `bin/fw watchtower url`", reference to a possibly
  non-existent NO-GO arc, unverified screenshots. User: "useless for me i need concrete links."
- Proven mechanism: T-2042 already derives all parameterless GET routes from
  `app.url_map` (`agents/ux-review/ux-review.py:discover_get_routes`) — the validator can
  reuse this exact approach.
- Bounded fix path: extract Watchtower paths from `## Recommendation` Evidence + Human-AC
  `**Steps:**` → validate against url_map (parameterless) or HTTP-probe (parameterised) →
  WARN/block in `lib/review.sh` at `fw task review` time.

**Scope of the follow-on build (if GO):** one build task — add link-validation to
`fw task review` (extract → validate → WARN), reusing `discover_get_routes()`; unit test
pinning bad-path-fails / good-path-passes; keep screenshot-existence and external-URL
checks out of scope (separate tasks if wanted).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: The root cause is structural, not behavioural: there is no mechanical check
of review links at the hand-off chokepoint, so guessed/typo'd routes reach the human. The
advisory rule already failed 3× — only a mechanical gate at `fw task review` prevents
recurrence. The fix is bounded and low-risk because the route-derivation machinery already
exists (T-2042 `discover_get_routes()` over `web.app.app.url_map`); this task reuses it
rather than building new infrastructure. WARN-first keeps it reversible.

**Date**: 2026-05-25T19:43:46Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-24T14:27:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-25T19:43:46Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The root cause is structural, not behavioural: there is no mechanical check
of review links at the hand-off chokepoint, so guessed/typo'd routes reach the human. The
advisory rule already failed 3× — only a mechanical gate at `fw task review` prevents
recurrence. The fix is bounded and low-risk because the route-derivation machinery already
exists (T-2042 `discover_get_routes()` over `web.app.app.url_map`); this task reuses it
rather than building new infrastructure. WARN-first keeps it reversible.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-73971b40
- **Timestamp:** 2026-06-02T15:00:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-25T19:43:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
