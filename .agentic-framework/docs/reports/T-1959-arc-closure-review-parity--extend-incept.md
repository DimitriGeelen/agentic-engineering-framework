# T-1959 — Arc closure review parity — extend inception-decide approval pattern to fw

> **Inception research artifact** (backfilled by T-2515 from the `T-1959` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1959-arc-closure-review-parity--extend-incept.md`. **Decision recorded: GO.**

## Problem Statement

**For whom:** the human (decision-maker) and the agent (advisory). **Why now:** arc-005 itself is at 0.92 completion and gated on a closure decision. We just shipped 5 arc-005 slices and noticed the asymmetry.

Inception-decide and arc-close are structurally the same human-sovereign decision: agent prepares, human approves. But only inception-decide has the *cognitive-work-on-agent / decision-on-human* split fully wired. Arc-close (T-1911) shipped a Watchtower form but it is **blank** — the human has to recall the demo path, write the decision narrative, answer §ACD from scratch. The agent's recommendation (which exists for arcs in the form of an anchor-task `## Recommendation` block AND the arc's `headline_mechanic` + completion stats) does not surface anywhere near the decision point.

Three concrete symptoms:

1. **No /approvals queue entry for ready-to-close arcs.** Today `/approvals` and `fw review-queue` list inception decisions pending GO/NO-GO and tasks pending Human-AC verification. They do *not* list arcs that have crossed the audit's 0.80 completion threshold (a structural "ready to consider closing" signal). The human discovers a close-ready arc only by visiting `/arcs` and noticing the column-density.
2. **No agent Recommendation rendered on `/arcs/<slug>/close`.** The page lists arc metadata (headline_mechanic, anchor task, completion stats) but the agent has nowhere to write "**Recommendation: CLOSE** because A, B, C; demo lives at X; §ACD answers Y" and the human has nowhere to read it.
3. **No `fw arc review` CLI parity with `fw task review`.** The arc-close AC in T-1911 mentioned this verb but it never landed. The agent has no "open this decision in Watchtower" verb for arcs.

The pattern to extend already exists end-to-end for inceptions (`/approvals` ingestion → `review.html` template → `--from-watchtower` shell exemption → audit capture). The substrate is reusable; what's missing is the wiring.

## Assumptions

A1 (load-bearing). `## Recommendation` on the arc anchor-task is the right home for the agent's close-or-keep-open advisory. The anchor task already participates in `fw task review`; adding an arc-scoped section there avoids a duplicate "arc YAML carries recommendation" schema and keeps the agent's writing surface familiar.

A2. `/approvals` can ingest arcs alongside tasks with a thin adapter — same template (`_approvals_content.html`), additional row source. The 0.80-completion threshold (G-062) is the trigger.

A3. The shell contract `fw arc close --from-watchtower` (T-1671 exemption + T-1911 wiring) is sufficient — the Watchtower handler shells with the agent's pre-filled fields from the Recommendation block, the human reviews + clicks Approve.

A4. Headline-mechanic and §ACD prompt should appear on the review page (already on `/close`); the new page is closer to "review and approve" than "fill in".

## Exploration Plan

This inception is design-clear (the comparison surface exists and the seams are visible). No spikes needed. Validate by:

1. **Source-read** `web/blueprints/core.py:approvals` (or equivalent) to confirm a 2nd row-source plugin point exists for `/approvals` — *or* identify the smallest refactor that creates one. Time-box 15min.
2. **Source-read** `web/templates/review.html` to confirm it's task-shaped vs whether it can re-render an arc with a small partial change. Time-box 10min.
3. **Confirm** anchor-task `## Recommendation` is already auto-tracked by `fw arc review` candidate ingestion (i.e. the existing T-679 review mechanic), so we are *not* inventing a new place for the agent to write. Time-box 5min.

If any of these reveal that the existing substrate is *not* plugin-pointed cleanly, the build slices grow; that's a re-scope signal, not a NO-GO signal.

## Technical Constraints

- Sovereignty: `fw arc close` must remain refused under `$CLAUDECODE=1` (T-1671). Bypass remains `--from-watchtower` exemption, triggered by the human's click — not by a new agent flag.
- §ACD (G-062): demo evidence requirement does not change. The agent recommendation surfaces *suggests* a demo artefact (path or URL); the human still validates it. The structural gate (path exists, ≥256 bytes, allowlist extension, references arc-id or constituent task) stays unchanged.
- Render-surface gate (P-013): touching `web/templates/` requires `[REVIEW]` Human AC on each build slice.
- Default-to-OPEN (G-062): if ≥2 human pushbacks on an arc remain unresolved, the arc is OPEN regardless of evidence. The recommendation block needs an explicit "Has every prior pushback been answered with a captured headline_mechanic instance?" question that the agent fills.
- Idempotency: `/approvals` re-rendering an arc that's already closed must be a no-op (redirect to `/arcs/<slug>`, same pattern as `/arcs/<slug>/close` already does).

## Scope Fence

**IN scope (4 build slices, recommended on GO):**

- **T-NEW-A: arc Recommendation schema + auto-render on `/arcs/<slug>/close`.** Agent writes `## Recommendation` (CLOSE / KEEP-OPEN / DEFER) on the arc's *anchor task* with rationale/evidence/headline-mechanic-check. The close page reads it and pre-fills the demo path field, surfaces rationale and evidence inline, leaves the human only the Approve/override action.
- **T-NEW-B: `/approvals` ingestion of close-ready arcs.** Add an "ARC CLOSURE — ready for review (N)" section. Source: arcs in-progress with ≥0.80 completion AND a recommendation block on the anchor task. Click-through navigates to `/arcs/<slug>/close`.
- **T-NEW-C: `fw arc review <slug>` CLI verb.** Mirrors `fw task review T-XXX` — emits Watchtower URL + QR code for the close-review page. Under `$CLAUDECODE=1` the agent runs this instead of pasting raw CLI close commands.
- **T-NEW-D: `/arcs/<slug>/review` route (the read-only review surface), separate from `/close` (the action surface).** Same template as `review.html`. Linked from `/approvals` and from `fw arc review`. `/close` becomes the submit handler; `/review` is the consume-the-recommendation surface.

**OUT of scope:**

- Auto-generating the arc recommendation from heuristics. Agent writes it explicitly; we do not silent-promote completion-percentage into "CLOSE recommended".
- Per-slice arc Recommendation. The recommendation lives on the *anchor task* (one per arc), not on each constituent task. Constituent tasks already have their own `## Recommendation` for their own decisions.
- Changing `fw arc close` shell-contract. We are wiring the input surface, not the gate.
- Replacing `/arcs/<slug>/close` form. We add `/arcs/<slug>/review` as the read-first surface; `/close` stays as the submit handler/fallback.
- Auto-closing arcs. Sovereignty stays human-only (T-1671 unchanged).

## Go/No-Go Criteria

**GO if:**
- The asymmetry is real (confirmed: `/approvals` lists inceptions but not close-ready arcs; `/arcs/<slug>/close` is a blank form, not a recommendation review).
- The 4-slice scope is bounded (each touches ≤2 surfaces; total ≤4 new routes/templates + 1 CLI verb).
- Sovereignty stays intact (no new agent path to close an arc; recommendation is *advisory*, human still clicks Approve).
- The closure of arc-005 itself is materially helped by this work (the meta-test: closing arc-005 *via the new surface* would demo the headline_mechanic).

**NO-GO if:**
- The substrate isn't plugin-pointed cleanly and refactoring `/approvals` ingestion would touch more than 2 files. (Re-scope, not abandon.)
- A simpler alternative emerges (e.g. just adding a "Recommendation" panel to the existing `/arcs/<slug>/close` page without splitting review vs close — single-slice path).
- The human prefers the current blank-form discipline ("the cognitive work *should* be on me at the close moment, agent recommendations are tempting biases"). This is a legitimate sovereignty stance; not for the agent to overrule.

**DEFER if:**
- arc-005 closes first using the current blank-form path. The asymmetry remains but becomes lower-priority; revisit after the next arc reaches 0.80 completion (arc-003 already does).

## Recommendation

**Recommendation:** GO

**Rationale:**

Inception-decide and arc-close are structurally the same human-sovereign decision (agent prepares, human approves), but only one half has the cognitive-work-on-agent / decision-on-human split wired. /arcs/<slug>/close (T-1911) is a blank form the human fills from scratch; no agent Recommendation surfaces, no entry on /approvals, no fw arc review parity. The substrate to extend exists (review.html template, review-queue ingestion, --from-watchtower exemption pattern, §ACD gate already shared). Cost is bounded (4 surfaces: arc Recommendation schema, /approvals ingestion, /arcs/<slug>/review render, fw arc review CLI). Closing arc-005 itself is gated on this work — meta-relevant. GO to scope the inception; defer decide-go to human via Watchtower.

**Evidence:**

- `web/templates/arc_close.html` (T-1911) — blank form, no agent-recommendation surface. Confirmed by reading the file: only metadata + human-fills-from-scratch fields. The §ACD prompt is text-only; no rationale slot.
- `web/templates/review.html` + `web/templates/_approvals_content.html` — the inception-side surface. Renders task `## Recommendation` block, ingests from review-queue. Re-usable shape.
- `bin/fw review-queue` output (just ran): lists DECISIONS for inception GO/NO-GO and VERDICTS for Human-AC verification. **Zero entries for close-ready arcs** — confirms ingestion gap.
- `bin/fw arc list`: arc-003 at 0.90, arc-004 at 0.83, arc-005 at 0.92 — three in-progress arcs above G-062's 0.80 closure-pressure threshold. None surface on `/approvals`.
- `bin/fw arc 2>&1 | grep review`: returns nothing. `fw arc review` is not implemented (was an AC on T-1911 but never landed).
- Closing arc-005 is the meta-demo: the headline_mechanic includes "lifecycle has draft/in-progress/closed/abandoned tabs in Watchtower" — closing via a `/arcs/<slug>/review` page would be the cleanest wire-evidence of that mechanic firing, satisfying G-062.
- Cost: 4 build slices, all small (template + thin handler + one CLI verb). Comparable to T-1909/T-1910 individually (each ~2-3 file edits + Playwright tests).

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale:

Inception-decide and arc-close are structurally the same human-sovereign decision (agent prepares, human approves), but only one half has the cognitive-work-on-agent / decision-on-human split wired. /arcs/<slug>/close (T-1911) is a blank form the human fills from scratch; no agent Recommendation surfaces, no entry on /approvals, no fw arc review parity. The substrate to extend exists (review.html template, review-queue ingestion, --from-watchtower exemption pattern, §ACD gate already shared). Cost is bounded (4 surfaces: arc Recommendation schema, /approvals ingestion, /arcs/<slug>/review render, fw arc review CLI). Closing arc-005 itself is gated on this work — meta-relevant. GO to scope the inception; defer decide-go to human via Watchtower.

Evidence:

- `web/templates/arc_close.html` (T-1911) — blank form, no agent-recommendation surface. Confirmed by reading the file: only metadata + human-fills-from-scratch fields. The §ACD prompt is text-only; no rationale slot.
- `web/templates/review.html` + `web/templates/_approvals_content.html` — the inception-side surface. Renders task `## Recommendation` block, ingests from review-queue. Re-usable shape.
- `bin/fw review-queue` output (just ran): lists DECISIONS for inception GO/NO-GO and VERDICTS for Human-AC verification. Zero entries for close-ready arcs — confirms ingestion gap.
- `bin/fw arc list`: arc-003 at 0.90, arc-004 at 0.83, arc-005 at 0.92 — three in-progress arcs above G-062's 0.80 closure-pressure threshold. None surface on `/approvals`.
- `bin/fw arc 2>&1 | grep review`: returns nothing. `fw arc review` is not implemented (was an AC on T-1911 but never landed).
- Closing arc-005 is the meta-demo: the headline_mechanic includes "lifecycle has draft/in-progress/closed/abandoned tabs in Watchtower" — closing via a `/arcs/<slug>/review` page would be the cleanest wire-evidence of that mechanic firing, satisfying G-062.
- Cost: 4 build slices, all small (template + thin handler + one CLI verb). Comparable to T-1909/T-1910 individually (each ~2-3 file edits + Playwright tests).

**Date**: 2026-05-20T17:54:51Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ed9e1598
- **Timestamp:** 2026-06-02T15:00:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-20T17:54:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
