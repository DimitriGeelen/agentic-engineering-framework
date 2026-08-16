---
id: T-1721
name: "Frictionless artefact links — auto-render docs/path/report references in tasks
  and approvals as clickable Watchtower URLs (dynamic port-aware)"
description: >
  Inception: Frictionless artefact links — auto-render docs/path/report references
  in tasks and approvals as clickable Watchtower URLs (dynamic port-aware)

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [ux, watchtower]
components: [web/shared.py, web/blueprints/tasks.py]
related_tasks: [T-1575, T-1257, T-885, T-1287, T-1376]
arc_id: orchestrator-rethink
created: 2026-05-04T17:15:16Z
last_update: '2026-08-16T22:24:42Z'
date_finished: 2026-05-04T17:18:22Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
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
  - ts: '2026-08-16T22:24:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1721: Frictionless artefact links — auto-render docs/path/report references in tasks and approvals as clickable Watchtower URLs (dynamic port-aware)

## Problem Statement

When the agent surfaces work for human review (task review pages, approvals queue,
Recommendation evidence bullets, AC `Steps:` blocks), references to artefacts are
emitted as bare paths: `docs/reports/T-1700-litellm-build.md`, `agents/context/check-project-boundary.sh`,
`.fabric/components/lib-resolver-sh.yaml`, `.context/audits/reviewer/2026-05-04.yaml`.

To actually read these the human must:
1. Note the path
2. Switch to a terminal or open the repo
3. `cat`/open the file, OR
4. Hand-construct the Watchtower URL (`http://<host>:<port>/docs/reports/T-1700-litellm-build`)

This is friction at exactly the moment we want zero friction — the human is
reviewing, not exploring. T-1575 already shipped the rendering contract for
bare URLs and `T-NNNN` references; this task extends the contract to
**artefact file paths** so a single click opens the right Watchtower page.

**For whom:** the human reviewer (and any future cross-project reviewer reading
remote tasks). **Why now:** observed three times this session alone (T-1700
review, T-1717 review, T-1721 itself) — the agent re-types `http://192.168.10.107:3000/...`
because the renderer doesn't.

## Assumptions

A1. Watchtower already serves the file types we want to link (verified for `/docs/reports/*`, `/tasks/T-*`, `/fabric/<id>`; need to confirm `.context/`, `.fabric/components/`, raw source files like `web/shared.py`).
A2. Port resolution at render-time is cheap enough — `bin/fw watchtower port` reads `.context/working/watchtower.port` (single file open per request is fine; or cache at app startup).
A3. The set of artefact prefixes is bounded and stable: `docs/reports/`, `.tasks/{active,completed}/T-*`, `.fabric/components/`, `.context/{audits,episodic,project,working}/`, plus root-relative source files (`web/`, `lib/`, `bin/`, `agents/`).
A4. Agents and humans both write paths in a small number of forms: bare (`docs/reports/foo.md`), backticked (`` `docs/reports/foo.md` ``), and within `[md](path)` (already handled). The renderer must treat the first two like bare URLs (T-1575 contract).
A5. False-positive risk is low: a regex anchored to known prefixes plus path-shape constraints (no spaces, ends in `.md`/`.yaml`/`.py`/`.sh` or hits a known directory) won't accidentally link arbitrary text.

Register via `fw assumption add` once the user confirms direction.

## Exploration Plan

Three short spikes (~30 min total). Time-boxed; no production code writes.

**Spike 1 — Surface inventory (10 min):**
Grep `docs/reports/`, `.fabric/components/`, `.context/`, `.tasks/active/T-*` references across `web/templates/` and `web/blueprints/` to confirm the routes that already exist. Verify `/docs/reports/<slug>`, `/fabric/<id>`, `/tasks/T-NNNN`, `/episodic/T-NNNN` resolve. Note any artefact class with NO Watchtower route — those become NO-GO sub-scope or new-route work.

**Spike 2 — Renderer hook point (10 min):**
Read `render_markdown_safe()` in `web/shared.py` and `_render_md_inline()/_render_md_block()` in `web/blueprints/tasks.py`. Identify the post-markdown step where bare URLs and `T-NNNN` are auto-linked (T-1575). Confirm an additive regex pass slots in cleanly without re-tokenizing the HTML.

**Spike 3 — Port-aware URL builder (10 min):**
Decide where the host:port comes from at render-time. Two candidates:
- Read `bin/fw watchtower url` once at app startup, cache. Fast, but stale if Watchtower restarts on different port.
- Use Flask's `request.host_url` (always current, per-request, no shell-out). Preferred — no extra IO.

Decide IN this spike, no implementation.

## Technical Constraints

- Renderer runs server-side (Python/Flask), no browser-side JS post-processing.
- Output must remain XSS-safe (T-1575 used a controlled allowlist of HTML; new linkifier must not bypass).
- Pure additive: existing tests `tests/unit/test_extract_recommendation.py::test_render_markdown_safe_makes_backticked_urls_clickable` must still pass; new tests for path-link cases.
- Cross-project safe: a remote project's review page must produce links rooted at its OWN Watchtower port (per-project resolution, see Watchtower Port section in CLAUDE.md). `request.host_url` solves this naturally.
- Read-only artefact assumption: link target must be a Watchtower-served route, never a `file://` link (won't work for remote reviewers).

## Scope Fence

**IN scope:**
- Bare and backticked references to known-prefix paths in rendered Markdown become anchor tags.
- Path classes: `docs/reports/*.md`, `.tasks/active/T-*.md`, `.tasks/completed/T-*.md`, `.fabric/components/*.yaml`, `.context/{audits,episodic,project,working}/**`.
- Source files served by `/source/<path>` route IF such a route exists or is added — confirmed in Spike 1.
- Verification across `web/blueprints/{tasks,approvals,inception,arcs}.py` rendering paths.

**OUT of scope:**
- Adding new Watchtower routes to serve previously-unserved file classes (separate build task if needed).
- Cross-project link rewriting (links to OTHER projects' artefacts) — explicitly NO; agent shouldn't be rendering remote-project paths anyway.
- Markdown-source-side rewriting (the agent keeps writing bare paths; the renderer does the work).
- Editor integration / `vscode://` deep links.

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
- Spike 1 confirms ≥4 of the 5 path classes already have Watchtower routes (so this is renderer work, not router work).
- Spike 2 confirms a single regex-pass extension to `render_markdown_safe` covers ≥80% of observed reference patterns without re-tokenizing.
- Spike 3 picks a port resolution (`request.host_url` strongly preferred) with no shell-out at render time.
- Build task scope fits in one session (≤4h, target: bounded edit to `web/shared.py` + `web/blueprints/tasks.py` + new test file).

**NO-GO if:**
- Multiple path classes need new Watchtower routes (turns this into a multi-task arc, defer).
- Renderer hook is non-trivial (T-1575 contract turns out to be HTML-post-process and adding another pass risks XSS regressions).
- Path-shape disambiguation produces unacceptable false-positive rate (linking arbitrary words).

**DEFER if:** GO criteria mostly met but priority is dwarfed by an active arc (e.g. orchestrator-rethink Slice 1 still owed). Re-promote when arc clears.

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

**Recommendation:** GO

**Rationale:**

Recurring friction observed this session and prior: agent has to manually translate 'docs/reports/T-1700-litellm-build.md' into 'http://192.168.10.107:3000/docs/reports/T-1700-litellm-build' for every human-review handoff. Watchtower already renders bare T-NNNN as clickable (per T-1575 rendering contract); extending the same to file paths (.md, /docs/reports/, .tasks/, .context/, .fabric/) is a low-risk renderer-side enhancement that eliminates a class of friction. Port already resolved per-project via watchtower.url triple-file (T-885/T-1287/T-1376) so dynamic generation is essentially free. Scope: extend web/shared.py:render_markdown_safe and the inline renderers in web/blueprints/tasks.py. Risk: low — additive regex matcher with whitelist of known artefact-path prefixes; no behaviour change for non-matching content. Fits naturally with existing rendering-guarantee tests at tests/unit/test_extract_recommendation.py.

**Evidence:**

- This session: agent re-typed `http://192.168.10.107:3000/...` URLs at least 3 times when handing artefacts to human review (T-1700 reading list, T-1717 review pointer, T-1721 spike list).
- T-1575 already shipped the rendering contract: bare URLs and `T-NNNN` references auto-link, including those wrapped in backticks. This task extends the same contract to artefact paths — same surface area, same idiom.
- Watchtower routes already exist for at least: `/tasks/T-NNNN`, `/episodic/T-NNNN`, `/docs/reports/<slug>`, `/fabric/<id>`, `/inception/T-NNNN`, `/review/T-NNNN`. (Confirmed via the URLs the agent has been hand-constructing this session.)
- Port already resolved per-project per CLAUDE.md §Watchtower Port (`bin/fw watchtower url`, triple-file source of truth). Or, simpler: Flask's `request.host_url` gives the correct base URL for whichever port the request arrived on, which matches the user's mental model exactly.
- Risk floor: the change is purely additive HTML post-processing. If the regex matches nothing, output is unchanged. Existing T-1575 tests pin the contract.

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

**Rationale**: Recurring friction observed this session and prior: agent has to manually translate 'docs/reports/T-1700-litellm-build.md' into 'http://192.168.10.107:3000/docs/reports/T-1700-litellm-build' for every human-review handoff. Watchtower already renders bare T-NNNN as clickable (per T-1575 rendering contract); extending the same to file paths (.md, /docs/reports/, .tasks/, .context/, .fabric/) is a low-risk renderer-side enhancement that eliminates a class of friction. Port already resolved per-project via watchtower.url triple-file (T-885/T-1287/T-1376) so dynamic generation is essentially free. Scope: extend web/shared.py:render_markdown_safe and the inline renderers in web/blueprints/tasks.py. Risk: low — additive regex matcher with whitelist of known artefact-path prefixes; no behaviour change for non-matching content. Fits naturally with existing rendering-guarantee tests at tests/unit/test_extract_recommendation.py.

**Date**: 2026-05-04T17:18:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-04T17:18:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recurring friction observed this session and prior: agent has to manually translate 'docs/reports/T-1700-litellm-build.md' into 'http://192.168.10.107:3000/docs/reports/T-1700-litellm-build' for every human-review handoff. Watchtower already renders bare T-NNNN as clickable (per T-1575 rendering contract); extending the same to file paths (.md, /docs/reports/, .tasks/, .context/, .fabric/) is a low-risk renderer-side enhancement that eliminates a class of friction. Port already resolved per-project via watchtower.url triple-file (T-885/T-1287/T-1376) so dynamic generation is essentially free. Scope: extend web/shared.py:render_markdown_safe and the inline renderers in web/blueprints/tasks.py. Risk: low — additive regex matcher with whitelist of known artefact-path prefixes; no behaviour change for non-matching content. Fits naturally with existing rendering-guarantee tests at tests/unit/test_extract_recommendation.py.

### 2026-05-04T17:18:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-287bbe69
- **Timestamp:** 2026-06-02T14:59:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-04T17:18:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
