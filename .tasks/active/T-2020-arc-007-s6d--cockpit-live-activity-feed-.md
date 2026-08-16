---
id: T-2020
name: "arc-007 S6d — cockpit live activity feed (recent commits, htmx poll)"
description: >
  arc-007 S6d (last T-1993 slice) — a live "Recent activity" feed on the Cockpit that
  surfaces recent framework events (git commits, each referencing a T-XXX) and refreshes
  without a reload via htmx polling. The umbrella allows "SSE or polling"; polling
  is the
  low-cost choice (no streaming infra). Read-only fragment route, reuses existing
  git
  helpers. Contained to the Cockpit (not a shell-wide strip) to keep blast radius
  low.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:watchtower-redesign, ui, watchtower, cockpit]
components: [tests/playwright/test_cockpit_activity.py, 
      tests/unit/test_cockpit_activity.py, web/blueprints/cockpit.py, 
      web/templates/_cockpit_activity.html, web/templates/cockpit.html]
related_tasks: [T-1993, T-1987, T-2012, T-2013]
arc_id: watchtower-redesign
created: 2026-05-24T10:02:00Z
last_update: '2026-08-16T22:24:04Z'
date_finished: 2026-05-25T22:43:40Z
cost_estimate_proposed:
  - ts: '2026-05-24T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 3
      D4: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 3
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F1=0 (no-signal); F2=0
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2020: arc-007 S6d — cockpit live activity feed (recent commits, htmx poll)

## Context

arc-007 S6d — the last remaining T-1993 slice (build order S6a→S6b→S6c→**S6d**; S6a=T-2012,
S6b=T-2013, S6c shipped as S4e/T-2018). The umbrella (T-1993) defines S6d as "a live activity
ticker — recent framework events … via **SSE or polling**" (T-1993:9-10). Polling is the
low-cost choice: no streaming endpoint, no EventSource lifecycle/reconnection — just an htmx
fragment on a timer, the same pattern `/approvals/content` already uses (`hx-trigger` poll).

**Event source:** git commits are the canonical framework activity record — P-002 requires
every commit to reference a `T-XXX`, so the commit log *is* the activity feed of what agents
and the human are doing. Reuses the existing `git log` helper pattern (`web/blueprints/metrics.py:_recent_commits`).

**Placement:** a "Recent activity" card on the Cockpit (`/cockpit`), not a shell-wide strip.
Contained placement keeps the blast radius to one page and avoids an all-pages render-surface
change ahead of the T-1990 cockpit token redesign. A shell-wide strip can follow if wanted
(noted in Decisions).

**Surfaces:** new read-only fragment route `/cockpit/activity` → `_cockpit_activity.html`;
a polled card added to `cockpit.html`; a `_get_recent_commits()` helper in `cockpit.py`.

## Acceptance Criteria

### Agent
- [x] `GET /cockpit/activity` returns an HTML fragment (no page chrome) listing recent commits — each row shows the short hash, the message, and a relative timestamp; commit messages containing a `T-XXX` render it as a link to `/tasks/T-XXX` (unit: route 200 + contains a known recent hash + a `/tasks/T-` link).
- [x] The Cockpit renders a "Recent activity" card that loads the fragment and **polls** it without a reload — `hx-get="/cockpit/activity"` with `hx-trigger="load, every Ns"` and `hx-target`/`hx-swap` to replace the card body (unit asserts the poll attributes are present on `/cockpit`).
- [x] The feed is read-only — no new mutation route is added; `/cockpit/activity` is GET-only (unit: the rule exists and lists GET, not POST; no rule contains "activity" with a mutation verb).
- [x] The helper degrades gracefully — when `git log` returns nothing the fragment shows an empty-state line, not a traceback (unit: monkeypatch the git helper to return empty → 200 + empty-state text).
- [x] The activity card uses the existing cockpit design tokens (`wt-card`/`wt-section` family) so it restyles automatically when the T-1990 cockpit token redesign lands (unit asserts the fragment markup uses an existing `wt-` class).

### Human
- [ ] [REVIEW] The activity feed reads clearly and updates live
  **Steps:**
  1. Open the cockpit: `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` → open `<url>/cockpit` in a browser
  2. Find the "Recent activity" card; confirm it lists recent commits with task links and relative times
  3. Make a commit in another terminal (or wait for one) and watch the card refresh within the poll interval — no full-page reload
  **Expected:** The feed is readable at a glance (task link, message, time), visually consistent with the other cockpit cards, and refreshes on its own
  **If not:** Note whether the layout is cramped/unclear or the poll isn't refreshing; capture a screenshot and check the browser console

## Verification

# cockpit.py still parses
python3 -c "import ast; ast.parse(open('web/blueprints/cockpit.py').read())"
# unit guards for the slice
python3 -m pytest tests/unit/test_cockpit_activity.py -q
# reviewer static scan passes
out=$(bin/fw reviewer T-2020 2>&1); echo "$out" | grep -q "Overall:.*PASS"

## RCA

<!-- Not a bug-class task — no RCA required. -->

## Evolution

### 2026-05-24 — SSE → polling, ticker → contained cockpit card
- **What changed:** The umbrella AC says "via SSE"; the umbrella *body* allows "SSE or polling". On survey, an htmx poll fragment (the existing `/approvals/content` pattern) delivers the "updates without reload" requirement at a fraction of the cost of an SSE endpoint + EventSource lifecycle. Git commits (P-002 task-referenced) are an already-available, meaningful event source — no new event bus needed.
- **Plan impact:** S6d ships as a polled Cockpit card, not an SSE shell-wide strip. The "ticker/strip" framing becomes a contained card (lower blast radius; defers the all-pages render-surface change to the T-1990 cockpit redesign).
- **Triggered:** Decisions below; shell-wide strip + SSE upgrade left as optional follow-ons (not filed — re-propose if real-time sub-second latency or cross-page ambient awareness is wanted).

## Decisions

### 2026-05-24 — polling over SSE
- **Chose:** htmx polling (`hx-trigger="every Ns"`) over a Server-Sent-Events stream.
- **Why:** The AC is "updates without reload" — polling satisfies it with zero new streaming infrastructure (no SSE route, no EventSource reconnection/backoff, no long-lived connection). The umbrella explicitly permits "SSE or polling". For a single-operator governance dashboard, a 15s refresh is ample; sub-second latency carries no value here.
- **Rejected:** SSE — higher cost (streaming endpoint + client lifecycle) for latency the use case doesn't need.

### 2026-05-24 — contained cockpit card over shell-wide strip
- **Chose:** Render the feed as a "Recent activity" card on the Cockpit, not a strip injected into the base shell on every page.
- **Why:** A shell-wide strip is an all-pages render-surface change (high review burden + risk of clutter) and would collide with the pending T-1990 cockpit/foundation-token redesign. A contained card keeps blast radius to one page and reuses existing cockpit tokens.
- **Rejected:** Shell-wide ticker in `base.html` — higher blast radius; better revisited as part of (or after) the T-1990 redesign with a human design decision.

## Recommendation

**Recommendation:** GO (pending the one [REVIEW] Human AC)

**Rationale:** S6d ships the umbrella's "live activity, no reload" requirement at the lowest
sensible cost (htmx poll, read-only fragment, existing git helper, existing cockpit tokens),
contained to one page. Commits are a genuine, already-captured event source. All Agent ACs are
deterministic/unit-covered; the single Human AC is a real taste check on the feed's readability
and live-refresh feel.

**Evidence:**
- Unit `tests/unit/test_cockpit_activity.py` — **6 passed** (fragment 200 + `/tasks/T-` links; cockpit card has `hx-get`+`hx-trigger every`; route GET-only/no POST; empty-git → "No recent activity"; reuses `wt-queue-item`; helper parses hash/when/message + extracts T-XXX).
- Playwright `tests/playwright/test_cockpit_activity.py` — **3 passed** (card loads entries with task links on page load; card is wired to poll; review screenshot).
- Eyes-on screenshot `web/static/ux-review/T-2020-cockpit-activity.png` — feed lists recent commits (T-2019/T-2018/T-2017/… linked) with right-aligned relative times, visually consistent with the other cockpit cards.
- Read-only / net-zero: `/cockpit/activity` is GET-only, no mutation; reuses `run_git_command` (`git log`).
- Reviewer `fw reviewer T-2020` — **Overall: PASS**, no findings, needs_human=no.

## Updates

### 2026-05-24T10:02:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d2099a3d
- **Timestamp:** 2026-05-25T22:44:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:43:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
