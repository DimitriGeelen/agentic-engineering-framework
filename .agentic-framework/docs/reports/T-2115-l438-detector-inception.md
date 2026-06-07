# T-2115: L-438 detector inception — htmx hx-target inheritance bounce-back

**Status:** Inception / scoping phase
**Arc:** arc-007 (watchtower-redesign)
**Filed:** 2026-05-30
**Trigger:** Three independent instances of the same bug class shipped in one day (T-2112, T-2113, T-2114), all sourced to the same htmx hx-target inheritance gap documented in L-438 (T-2060).

## Problem

`hx-target` on an htmx element propagates to ALL descendants unless they override. Polling containers that need `hx-target="this"` for their own polling cycle therefore poison every clickable descendant `<a>` (and form submission) with the polling target — so cross-page navigation from inside the polling div swaps the destination INTO the polling div instead of the page shell. After the next polling cycle the swap is overwritten → "bounce back" user complaint.

L-438 (T-2060) documented the **descending** case (body-level `hx-target="#content"` overwritten descendant-side polling). The **ascending** case (descendant boost-anchor cross-targeted by polling-container's `hx-target="this"`) is what the three recent fixes addressed:

| Task | Surface | Fix shape |
|------|---------|-----------|
| T-2112 | `/approvals` arc-closure cards | Per-anchor triplet on 4 anchors (Review, Approve, arc-name, anchor-task) |
| T-2113 | `/cockpit` Recent Activity card | Per-anchor triplet on the task-link anchor |
| T-2114 | `/review/T-XXX` AC fragment | Wrapper-reset div (cleaner — markdown-rendered URLs covered automatically) |

## Why a detector is justified

- 3 instances of the same root cause in one day → not noise.
- Two distinct fix shapes already (per-anchor + wrapper-reset). A future template author has to guess which is appropriate.
- The bug is **silently** broken: the click "works" (destination renders briefly), then bounces. No exception, no error log, no test trip in the absence of an explicit Playwright click-wait-recheck.
- All three surfaces shipped through `fw test playwright` clean before the user-reported regression on T-2112.

## Candidate prevention approaches

### Option A — Jinja-level static scan

Walk all templates under `web/templates/`. For each `<*** id="..." hx-target="this" hx-trigger="...">` container, parse the body (or any `{% include %}` referenced) and flag any descendant `<a href=...>` without an `hx-target` override.

**Pros:** runs at lint time (build the framework's own pre-commit/audit cron). No browser required. Catches **defined** templates including their includes.

**Cons:** Jinja templates are not pure HTML; conditional `{% if %}` / `{% for %}` may produce variable HTML at render time. A purely-static scan can false-positive on conditional anchors that only render in branches we don't care about. Markdown-rendered URLs (T-2114's headache) are invisible to a Jinja-level scan because the URLs come from user-supplied AC text at render time.

**Scope:** ~2-3 hours of work. Pyparser-light: read templates, find polling-container blocks (regex sufficient), scan body for ungated anchors.

### Option B — Playwright class-wide test (run-time scan)

Add a new test that:
1. Discovers all routes from the Flask `app.url_map`.
2. For each route, navigates to it.
3. Walks the rendered DOM for elements matching `[hx-target="this"]` with `[hx-trigger*="every "]`.
4. For each such polling container, walks descendant `<a>` elements and asserts each has its own `hx-target` (or is wrapped in an inheritance-reset div).
5. Reports findings as test failures.

**Pros:** browser-level — sees the actual rendered DOM including markdown-rendered URLs and template conditionals. Reuses existing Playwright infra (`tests/playwright/`). Covers both the "explicit anchor" and "markdown-rendered anchor" sub-classes.

**Cons:** test-time only. Slower than static scan (Playwright spin + per-route navigation). Routes with required state (data, login, query params) need test fixtures.

**Scope:** ~3-5 hours of work. Pattern already established by T-2042's `test_all_routes_height.py` (route discovery via `app.url_map`, per-route Playwright sweep). Same shape, different assertion.

### Option C — CSP / htmx-strict-mode signal

Configure htmx to refuse to swap into a target whose `id` matches a polling container, OR enable a config flag that requires explicit `hx-target` on every boosted anchor. Inspect whether htmx 2.x offers such a config.

**Pros:** runtime guard — fires the moment a developer pushes a template that has the bug.

**Cons:** unknown if htmx exposes such a knob. May be overly restrictive (breaks legitimate uses of inheritance). Doesn't catch the bug before deploy.

**Scope:** ~1 hour to research the knob, then variable depending on what's available.

### Option D — Defer

Accept the per-instance fix cost. Three instances in a day is rare; the L-438 doc + the forensic inline comments naming T-2112/T-2113/T-2114 + the existing Playwright tests for the three surfaces are sufficient prevention for the most-trafficked pages.

**Pros:** zero new work.

**Cons:** any new polling surface will rediscover the bug. We have ~3 polling surfaces today; if arc-007 adds another, we'll hit it again. The user just spent 5 min reporting "larger screen disappears" — that's user-attention cost the detector would have prevented.

## Recommendation

**GO on Option B (Playwright class-wide test).** Reasons:

1. The bug surfaces in **rendered DOM**, not in template source. A run-time scan catches both static and dynamic anchors (the markdown-rendered URLs T-2114 had to handle).
2. The infrastructure pattern is established (T-2042's all-routes height check). Adding a hx-target-inheritance check next to it is incremental, not net-new test scaffolding.
3. Cost is bounded (3-5h); upside is class closure.
4. Static scan (A) would close ~70% of the class but miss the markdown-rendered URL class — the third-instance bug — which is the exact instance that motivated the detector. False sense of closure.
5. Option C is unbounded research; defer until B is in place.

**Go decision** would file a build task (T-2116 candidate): `tests/playwright/test_all_polling_containers_inheritance.py` mirroring `test_all_routes_height.py`'s shape.

**Defer condition:** if budget for arc-007 closure is a hard constraint and the human prefers to ship arc-007 first, defer this and revisit when arc-007 demo evidence is captured. The class is bounded; per-instance fix continues to work until then.

## Dialogue Log

### 2026-05-30 — agent autonomous research, no human dialogue

Agent surfaced the inception after shipping the third instance (T-2114) within the same session pair. RCA on T-2114 committed the agent to "filed as a separate inception following arc-007's one-bug-one-task cadence". This artefact + the inception task body are that filing.

No human dialogue in this scoping phase. Awaiting human GO/NO-GO via `fw task review T-2115` → Watchtower decision form.
