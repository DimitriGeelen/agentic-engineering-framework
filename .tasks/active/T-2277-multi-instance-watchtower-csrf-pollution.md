---
id: T-2277
name: "Multi-instance Watchtower CSRF pollution — per-project session cookies overwrite
  each other across ports on same host"
description: >
  Inception: Multi-instance Watchtower CSRF pollution — per-project session cookies
  overwrite each other across ports on same host

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-09T08:26:10Z
last_update: '2026-06-09T08:30:03Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-09T08:27:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-09T08:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2277: Multi-instance Watchtower CSRF pollution — per-project session cookies overwrite each other across ports on same host

## Problem Statement

**Symptom:** Operator pressed GO on `/inception/T-2275` and got a 403
error page rendered with title `Forbidden — Video riper and translation app`.
The POST landed on Watchtower port :3101 (the Video-riper instance),
not :3000 (AEF), even though T-2275 lives only in the AEF repo.

**Why now:** Nine Watchtower instances run concurrently on
`192.168.10.107` (verified via `ss -tlnp`). Flask defaults
`SESSION_COOKIE_NAME = "session"`. RFC 6265 cookie-scoping ignores
port, so all nine instances share one browser cookie slot named
`session`. Visiting any Watchtower silently overwrites the session
cookie for every other Watchtower on the same host. The next form POST
sends a cookie signed by a different instance's `secret_key` →
`itsdangerous` rejects → empty session → CSRF token mismatch → 403.

**Who is affected:** Every operator running ≥2 Watchtower instances
on the same host. The framework's BVP/AEF/Video-riper/Workflow-designer
multi-project pattern hits this on a routine basis.

**Affected surfaces:** every state-changing POST/PATCH/PUT/DELETE on
Watchtower — `/inception/<id>/decide`, `/tasks/<id>/update`, `/arcs/<slug>/close`,
`/gaps/<id>/close`, BVP forms, htmx swaps. Silent, intermittent, cryptic.

## Assumptions

- **A1:** RFC 6265 cookie-scoping ignores port (well-documented standard).
- **A2:** Each Watchtower instance persists its own `secret_key` to
  `.context/working/.fw-secret-key` (verified in `web/app.py:39-61`).
- **A3:** Renaming `SESSION_COOKIE_NAME` to include port forces the
  browser to allocate distinct cookie slots per port (standard browser
  behaviour; verified by spec).
- **A4:** No production Watchtower fronts multiple instances at a
  shared port via reverse-proxy + path-prefix routing (single-port
  multi-app deployment is out of current scope).

## Open Questions

- **IW-1: Should the cookie name be scoped by port, project slug, or composite?**
  confidence: 2
  disposition: answered
  rationale: Candidate 1 (port-scoped) is minimal sufficient — port is
  already the unique key for Watchtower instances on a host. Candidate
  2 (project-slug) leaks basename in headers; Candidate 3 (composite)
  is belt-and-braces but verbose. Defer 2/3 unless a future deployment
  fronts multiple apps on one port.

- **IW-2: Should diagnostic enrichment (Leg B) ship in the same build as the fix (Leg A)?**
  confidence: 1
  disposition: deferred
  rationale: Leg A alone eliminates the failure class; Leg B is
  operator-experience polish (silent 403 → actionable recovery hint).
  Operator preference on bundle vs sequential. Recommend single build
  task with sequential commits; alt is two build tasks.

- **IW-3: Should `fw doctor` gain a cross-instance scan (Leg C)?**
  confidence: 1
  disposition: deferred
  rationale: After Leg A ships, the failure class is gone — Leg C is
  redundant for THIS bug. Useful as a general "this host has N
  Watchtowers" observability. Could file as a separate captured/later
  task.

## Exploration Plan

RCA is complete — Five-Whys traced to `web/app.py:106-111` (CSRF check)
+ Flask default `SESSION_COOKIE_NAME = "session"` + RFC 6265 port-blind
cookie scoping. See `docs/reports/T-2277-watchtower-csrf-pollution.md`
for the full trace, candidate comparison, test surface, and affected
files.

Steps already completed:

1. Reproduced operator's symptom by checking that title format
   `Forbidden — <project_name>` matches `web/templates/base.html` +
   `web/app.py:128-131`.
2. Enumerated running Watchtower instances (`ss -tlnp` shows 9 on host).
3. Verified Video-riper (:3101) returns 404 on `GET /inception/T-2275`,
   confirming POST was the source of 403 not GET.
4. Confirmed Flask CSRF check at `web/app.py:106-111` and 403 handler
   at `web/app.py:359-370`.
5. Confirmed RFC 6265 explicitly ignores port for cookie scoping.

No further spikes needed before GO decision.

## Technical Constraints

- Browser cookie scoping per RFC 6265 (port-blind).
- `itsdangerous` signature verification (Flask's session signing).
- Each Watchtower binds one port; `Config.PORT` is the canonical
  port reference at app boot.
- Per-project `.context/working/.fw-secret-key` MUST remain unique per
  project — this is correct design (T-1306). Changes to that file
  would break sessions on every restart; keep untouched.
- No HTTPS in dev (cookies are not `Secure`-flagged). HTTPS doesn't
  fix cookie-name collision regardless.

## Scope Fence

**IN scope:**
- Setting `SESSION_COOKIE_NAME` per-instance (port-scoped — Candidate 1).
- One test pinning the cookie-name contract.
- Optional Leg B: CSRF-403 recovery template + handler branch.
- Optional Leg C: `fw doctor` cross-instance WARN.

**OUT of scope:**
- Cross-host federation (different problem class).
- Replacing Flask sessions with JWT or header tokens.
- Changing per-project `secret_key` model.
- Browser-level cross-tab detection (e.g. BroadcastChannel).
- Migrating existing operator cookies (they re-mint on first request
  after deploy — invisible).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

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

Three-leg bundle: (A) port-scoped SESSION_COOKIE_NAME (~2 LoC eliminates the class) + (B) CSRF-403 diagnostic enrichment (silent 403 → actionable recovery hint) + (C) fw doctor multi-instance WARN. Observed in production 2026-06-09 blocking T-2275 GO decision via Watchtower (POST hit :3101 Video-riper instead of :3000 AEF; session cookie shared cookie slot 'session' across all 9 running Watchtower instances on 192.168.10.107).

**Evidence:**

- `web/app.py:106-111` — CSRF check at `before_request`; rejects when
  form `_csrf_token` ≠ `session.get("_csrf_token")`.
- `web/app.py:39-61` — `_resolve_secret_key` persists per-project
  signing key (different keys → cookies from one instance can't be
  decoded by another).
- `web/app.py:128-131` — `project_name` Jinja global derived from
  PROJECT_ROOT basename; surfaces in `<title>` on every page including
  403 error pages.
- `web/app.py:359-370` — 403 handler renders generic `_error.html`,
  no CSRF-specific recovery hint.
- Live `ss -tlnp` output (2026-06-09): 9 Watchtower instances on
  `192.168.10.107` ports 3000, 3001, 3002, 3025, 3100, 3101, 4050, 5050.
- `curl -s :3000/inception/T-2275` → 200, title "Inception T-2275 —
  Agentic Engineering Framework" (AEF, correct).
- `curl -s :3101/inception/T-2275` → 404 (Video-riper has no T-2275).
- Per RFC 6265 §4.1.2.3: cookies are scoped by (domain, path), NOT
  by port. Browser sends the same `session` cookie to :3000 and :3101
  on `192.168.10.107`.
- Research artifact: `docs/reports/T-2277-watchtower-csrf-pollution.md`.

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-09T08:27:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
