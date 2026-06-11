---
task: T-2277
kind: inception research artifact
session: S-2026-0609-1009
date: 2026-06-09
---

# T-2277 — Multi-instance Watchtower CSRF pollution

## TL;DR

Operator pressed GO on `/inception/T-2275` and got `403 Forbidden — Video
riper and translation app`. POST hit Watchtower :3101 (Video-riper),
not :3000 (AEF). Nine Watchtower instances run on `192.168.10.107` and
all use Flask's default `SESSION_COOKIE_NAME = "session"`. RFC 6265
ignores port when scoping cookies — so every Watchtower visit silently
overwrites the cookie for every other Watchtower instance. The next
form POST submits a token signed by a different instance's
`secret_key` → CSRF reject → 403. Fix is a 2-line config change.

## Symptom

Operator clicked GO on `/inception/T-2275`. Browser rendered an error
page:

```
<title>Forbidden — Video riper and translation app</title>
```

T-2275 lives in the AEF repo. The Watchtower running on `:3000`
serves AEF. The title format `<page_title> — <project_name>` is
defined in `web/templates/base.html` and `project_name` is set at
boot from `PROJECT_ROOT` (`web/app.py:128-131`). "Video riper and
translation app" can ONLY come from a Watchtower whose
`PROJECT_ROOT=/opt/100-Video-riper-and-translation-app`.

Live evidence:

```
$ ss -tlnp | grep python3.*web.app
:3000 (AEF, PID 829194)
:3001 (other, no title)
:3002 (Workflow designer)
:3025 (WorkshopDesigner)
:3100, :3101 (Video riper and translation app)
:4050, :5050 (AEF gunicorn)
```

The POST that returned 403 hit :3101.

## Root Cause — Five Whys

1. **Why 403?**
   Flask `before_request` CSRF check (`web/app.py:106-111`) compared
   form `_csrf_token` against `session.get("_csrf_token")` — they did
   not match.

2. **Why did they not match?**
   The browser's `session` cookie sent to :3101 was either empty or
   signed by a different instance's `secret_key`. `_resolve_secret_key`
   (`web/app.py:39-61`) persists each project's key to
   `.context/working/.fw-secret-key` — AEF and Video-riper have
   different keys by design. A cookie signed by AEF's key fails
   `itsdangerous` signature verification when handled by Video-riper's
   app → Flask treats the session as empty → `session.get("_csrf_token")`
   returns `None`.

3. **Why did the AEF-signed cookie reach :3101?**
   Flask defaults `SESSION_COOKIE_NAME = "session"`. RFC 6265
   ("HTTP State Management Mechanism") §4.1.2.3 explicitly excludes
   port from the cookie scope:
   > A cookie's name and domain identify the cookie uniquely.
   > The port number, if present, is NOT used to scope cookies.
   So `Cookie: session=...` sent to `192.168.10.107:3101` is the SAME
   slot as `Cookie: session=...` sent to `192.168.10.107:3000`.
   Visiting :3000 then :3101 overwrites the cookie in the browser —
   the operator's last-visited Watchtower controls what every other
   Watchtower receives.

4. **Why was the cookie name not scoped per project?**
   The Watchtower port-per-project model (T-885 / T-1287 / T-1376)
   was added to solve PORT collision. Cookie-slot collision was not
   considered because, at the time, only one Watchtower per host was
   the norm. Multi-project parallel Watchtowers are a later
   operational pattern that this design did not anticipate.

5. **Why did no detector catch this?**
   `fw doctor` does not inspect cross-process state — it checks the
   current project's invariants. No surface inspects "what other
   Watchtower instances are running on this host" or "do those
   instances share a cookie name". The class is invisible to every
   existing gate.

**Root cause:** Per-project Watchtower instances on the same host
share the browser cookie slot named `session`. Every Watchtower visit
silently invalidates every other Watchtower instance's session. The
multi-instance operational pattern violates the single-instance
implicit assumption baked into Flask's default cookie config.

## Affected Surfaces

ANY POST/PATCH/PUT/DELETE on a Watchtower instance after the operator
has visited a different Watchtower on the same host. Concretely:

- `/inception/<id>/decide` (this incident)
- `/tasks/<id>/update` (status flips, AC ticks)
- `/arcs/<slug>/close`
- `/approvals/<id>/<action>`
- `/api/*` state-mutating endpoints
- `/gaps/<id>/close` (T-2185)
- BVP forms on `/bvp`, `/arcs/<slug>`
- Every htmx swap that POSTs

The failure is silent (no warning), cryptic (bare "Forbidden"), and
intermittent (only fires after a cross-Watchtower visit). High blast
radius across operator workflows; very low discoverability.

## Candidate Fixes

### Candidate 1 — Port-scoped `SESSION_COOKIE_NAME` (RECOMMENDED)

```python
# web/app.py — right after app = Flask(...)
app.config["SESSION_COOKIE_NAME"] = f"fw_session_{Config.PORT}"
```

Each Watchtower instance writes to its own cookie slot:
`fw_session_3000`, `fw_session_3101`, …

**Pro:**
- Eliminates the class entirely. Cross-instance cookies cannot collide.
- ~2 LoC + one test pinning the cookie name.
- Zero blast radius on single-instance setups (just a renamed cookie).
- Backwards-compatible — first request to each instance regenerates
  the session in the new slot.
- Discoverable in DevTools: an operator inspecting cookies sees
  per-port slots, immediately understanding the model.

**Con:**
- If a future deployment ever fronts multiple Watchtowers behind a
  reverse proxy on the SAME port at different paths, port-scoping
  wouldn't help. Mitigated by Candidate 2 / 3 below.

### Candidate 2 — Project-scoped cookie name

```python
project_slug = os.path.basename(os.path.normpath(str(PROJECT_ROOT)))
app.config["SESSION_COOKIE_NAME"] = f"fw_session_{project_slug}"
```

Same effect, scoped by directory basename instead of port. Survives
port reassignment.

**Pro:** Survives port changes. More semantically meaningful.
**Con:** Cookie name leaks project path basename in HTTP headers.
Slightly larger attack surface if basenames are sensitive.

### Candidate 3 — Composite scope (port + project slug)

```python
project_slug = os.path.basename(os.path.normpath(str(PROJECT_ROOT)))
app.config["SESSION_COOKIE_NAME"] = f"fw_session_{project_slug}_{Config.PORT}"
```

Belt-and-braces. Largest cookie name but uniqueness is absolute.

**Pro:** Cannot collide under any reachable reconfiguration.
**Con:** Verbose cookie name. Cookie inspection less readable.

### Recommendation

**Candidate 1** for the primary fix. Port-scoping is the minimal
sufficient change. Defer Candidate 2 / 3 to a follow-up if
single-port multi-app deployment ever appears.

## Diagnostic enrichment (Leg B)

The current 403 handler renders "Forbidden" with no recovery hint
(`web/app.py:359-370`). Operators see a dead-end page. Two
improvements:

1. **CSRF-fail detection in 403 handler:** if
   `str(e.description).startswith("CSRF token missing or invalid")`,
   render the specific recovery template instead of generic
   `_error.html`.

2. **Recovery template** (`_error_csrf.html` or extension to
   `_error.html`) — explicit message:

```
This Watchtower (port {{port}}, {{project_name}}) does not
recognise your form's session token. This usually means you have
another Watchtower instance open on the same host that overwrote
your session cookie.

Recovery:
  1. Reload this page (Ctrl+Shift+R) to mint a fresh token for
     {{project_name}}.
  2. Retry your action.

If the problem persists, close all other Watchtower tabs and try
again.

After T-2277 Candidate 1 ships, this cross-instance collision
cannot happen.
```

Turns a silent dead-end into a 30-second recovery.

## Observability (Leg C)

`fw doctor` gains one cross-host check:

```bash
# In agents/audit or fw doctor
INSTANCES=$(ss -tlnp 2>/dev/null | grep -c "python3.*web.app")
if [ "$INSTANCES" -gt 1 ]; then
  # ... check if SESSION_COOKIE_NAME is set on this instance ...
  echo "WARN: $INSTANCES Watchtower instances on this host. Cookie scoping check: ..."
fi
```

Pinpoints the operational risk before the operator hits the 403.

## Test Surface

`tests/unit/test_csrf_cookie_scoping.py` (new) — 4-5 tests:

1. `SESSION_COOKIE_NAME` matches `fw_session_<port>` after `create_app()`.
2. Two `create_app()` calls with different `Config.PORT` produce
   distinct cookie names.
3. A session created on instance A cannot be decoded by instance B
   (via simulated cross-instance cookie injection).
4. CSRF 403 handler renders recovery hint when description starts
   with "CSRF token missing or invalid".
5. Idempotency: re-creating the app uses the same cookie name for
   the same port (no random suffix).

Plus one bats test extending `fw doctor` cross-instance scan
(if Leg C is in scope).

## Affected Files

| File | Change |
|------|--------|
| `web/app.py` | +2 lines `SESSION_COOKIE_NAME` config (Leg A) |
| `web/app.py` | ~10-line CSRF-aware 403 branch (Leg B) |
| `web/templates/_error_csrf.html` | New ~30-line recovery template (Leg B) |
| `tests/unit/test_csrf_cookie_scoping.py` | New ~40-line test (Leg A+B) |
| `agents/audit/audit.sh` or `fw doctor` | ~15 lines multi-instance scan (Leg C, optional) |

## Out of Scope

- Cross-host Watchtower federation — different problem class.
- Replacing Flask sessions with JWT or token-header auth.
- Changing the per-project `secret_key` model (which is correct).
- Auto-detecting cross-host Watchtower tabs in the browser.
- Migrating existing operator session cookies (they'll re-mint on
  first request after deploy — invisible to the operator).

## Recommendation

**GO** — implement Candidate 1 (Leg A) as a single build task. Surface
estimate: ~2-line config change in `web/app.py` + ~40-line test file.
Effort: small (≤1 hour bounded build). Blast radius: zero on
single-instance hosts (cookie just renamed); on multi-instance hosts
the failure class is eliminated.

Optional Legs B + C ship as separate build slices if operator wants
them now. Recommend filing the bundle as one build task with three
sequential commits, but stand by either decomposition.

The operator's reported symptom maps one-to-one to this fix. No
further research needed before the GO decision.
