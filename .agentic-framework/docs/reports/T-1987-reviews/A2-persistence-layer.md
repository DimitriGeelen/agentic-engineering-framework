# T-1987 review-A2 — Persistence layer for the Appearance settings screen (S1 / T-1988)

**Reviewer dimension:** per-user YAML persistence at `.context/user-preferences/<who>.yaml`
**Scope reviewed:** A2 assumption + Q2 persistence decision + S1 (T-1988) persistence layer
**Verdict:** **ADJUST** — keep server-side YAML, but correct the `<who>` story and the cross-machine claim, which are factually wrong as written.

---

## 0. Ground truth (verified against the live web layer)

Before any proposal, here is what the codebase actually provides today — several inception statements do not survive contact with it:

| Claim in inception / mockup | Reality in `web/` | Source |
|---|---|---|
| `$USER` from session or basic-auth header keys the file (T-1987 line 85) | **There is no auth.** `HOST=0.0.0.0` (`web/config.py:54`), no login, no basic-auth, no `$USER` propagation. Flask `session` is used **only** for the CSRF token (`web/app.py:86-113`). | `web/app.py`, `web/config.py` |
| "Saved to your profile and **synced across devices**" | Mockup copy (`appearance-settings.jsx:106`). Per-user host-local YAML **cannot** sync across devices. This is a lie the UI would tell. | `appearance-settings.jsx:106` |
| localStorage is "per-browser-profile" and inferior (research artifact line 98) | **localStorage is already in production** — `base.html:9` applies `wt-theme` (light/dark) pre-paint to avoid FOUC. The redesign is *adding* a second persistence mechanism alongside one that already works. | `web/templates/base.html:9` |
| Concurrent writes "resolved by per-user keying" (T-1987 line 85) | Per-user keying does **not** resolve concurrent writes — two tabs of the *same* user race on the *same* file. Existing `settings.py` already does naive read-modify-write with no atomicity (`web/blueprints/settings.py:31-34`). | `web/blueprints/settings.py` |
| (unstated) single Flask process | **Prod runs gunicorn `-w 2`** (`web/wsgi.py:4`) — two worker processes. Any naive in-process cache is incoherent across workers. Dev is single-process socketio threading. | `web/wsgi.py:4`, `web/app.py:160` |

These corrections drive the whole review. The persistence *tier* (server-side file) is defensible; the *identity model* and *durability claims* attached to it in the inception are not.

---

## 1. How is `<who>` resolved?

**There is no user identity in Watchtower today.** The only candidates, ranked:

| Candidate | Stable? | Server-readable? | Multi-user? | Verdict |
|---|---|---|---|---|
| `$USER` of the server process | yes | yes | **NO** — one systemd account (`watchtower`) for everyone | Useless; rejects T-1987 line 85 |
| `request.remote_addr` | **NO** (DHCP/NAT, shared LAN) | yes | weak | Reject |
| Basic-auth header | n/a | yes | yes | **Does not exist** — would require building auth (explicitly OUT of scope, T-1987 line 102) |
| localStorage value | yes | **NO** (invisible to server/agents) | per-browser | Already used; client-only |
| **Flask signed-cookie UID** | yes (secret key persisted, T-1306) | **yes** | per-browser | **Recommended** |

### Recommended scheme: minted signed-cookie UID

`<who>` = a random hex token (`wt_uid`) minted server-side and stored in the **existing** Flask signed session cookie (the same cookie that already carries `_csrf_token`). Filename: `.context/user-preferences/<wt_uid>.yaml`.

```python
def resolve_who(request) -> str:
    uid = session.get("wt_uid")
    if not uid:
        uid = secrets.token_hex(16)   # server-minted → safe by construction
        session["wt_uid"] = uid
        session.permanent = True       # survive browser restart
    return uid
```

**Why this and not the others:** it is the *only* identity that is both stable and server-readable without building authentication. Because the token is server-minted hex, it is **immune to path traversal by construction** (see §9) — never derive `<who>` from a user-supplied header or form field.

**Honest caveat the inception must absorb:** a cookie-keyed UID is *browser-scoped*, exactly like localStorage. It survives restart (so does localStorage). It does **not** identify "Julian" across his laptop and the LXC console — those are two browsers, two cookies, two files. See §6.

### Fallback for first-visit anonymous

No cookie → no file → render the default preset (§5). Mint the cookie **lazily on first save**, not on first GET, to avoid littering `.context/user-preferences/` with a YAML file for every drive-by request, crawler, and health check.

---

## 2. YAML schema proposal

`.context/user-preferences/<wt_uid>.yaml`:

```yaml
schema_version: 1
preset: console            # one of the 6 preset ids, or "custom"
typography: plex           # TYPE_PAIRS id
palette: console           # PALETTES id
accent_override: null      # null or validated #hex (see §9)
nav_layout: sidebar        # topbar | sidebar | rail
density: compact           # compact | cozy | spacious
theme_mode: dark           # light | dark | system
custom_overrides:          # the four CheckRow toggles (appearance-settings.jsx:210-215)
  reduce_motion: false
  high_contrast: true
  mono_numerals: true
  breadcrumb_in_title: false
last_updated: 2026-05-22T11:04:00Z
```

Field names align with the mockup's state vars (`appearance-settings.jsx:8-14`). `schema_version: 1` is mandatory from day one — migrations are cheaper than guessing intent later. `preset: custom` is the honest value once any axis diverges from a named preset (the mockup already tracks this divergence at `appearance-settings.jsx:113-115`).

---

## 3. Concurrent-write races

Scenario: two tabs of the same user, both POST `/api/appearance/save`.

**Recommendation: last-write-wins with atomic replace. Reject locking and ETags.**

- **Atomicity (required):** write to a temp file in the same dir, then `os.replace(tmp, target)` — POSIX-atomic rename. A reader never sees a half-written file. The existing `settings.py:31-34` lacks this and *should* be fixed in the same pass (it's the same class of bug).
- **Lost update (accepted):** the save POSTs the *entire* current form state (the form holds all fields — `appearance-settings.jsx` has every value in component state). So "stomp" just means the most recent complete save wins — which is exactly the UX a user expects from their own preference panel.
- **Why not file-lock / optimistic ETag:** the stakes are cosmetic, single-user, self-correcting (re-pick takes 2 seconds). A lock introduces stale-lock cleanup (cf. `KEYLOCK_TIMEOUT` config that exists *because* locks are painful). An ETag introduces a 409 conflict UX for a problem no user will ever notice. This is textbook over-engineering for the blast radius.

```python
def save_user_preferences(who: str, prefs: dict) -> None:
    target = _prefs_path(who)                 # containment-checked, §9
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(f".{os.getpid()}.tmp")
    tmp.write_text(yaml.safe_dump(prefs, default_flow_style=False))
    os.replace(tmp, target)                   # atomic
```

---

## 4. Read-path performance

Cost per page render: one `stat()` (~microseconds) + one `yaml.safe_load` of a ~12-line file (~0.1–0.3 ms). In isolation this is **negligible** next to what already happens per request — `get_all_task_metadata()` reads 1200+ task files (cached 30 s, `web/shared.py:601-634`). The preference read is < 1 % of that even uncached.

**Still, cache it — but mtime-keyed, not TTL-keyed**, because of the gunicorn `-w 2` reality:

```python
_prefs_cache = {}   # who -> (mtime_ns, parsed_dict)

def load_user_preferences(who: str) -> dict:
    path = _prefs_path(who)
    try:
        mtime = path.stat().st_mtime_ns
    except FileNotFoundError:
        return DEFAULT_PREFS.copy()
    hit = _prefs_cache.get(who)
    if hit and hit[0] == mtime:
        return hit[1]
    data = {**DEFAULT_PREFS, **(load_yaml(path) or {})}
    _prefs_cache[who] = (mtime, data)
    return data
```

**Why mtime, not the existing 30 s TTL pattern:** worker A handles the save (bumps mtime), worker B handles the next render. A TTL cache in worker B would serve stale prefs for up to 30 s — the user saves, reloads, sees the old theme, files a bug. mtime-keyed caching re-stats every request (cheap) and re-parses only on change, giving **instant cross-worker coherence with zero IPC**. Invalidation is implicit: the save bumps mtime; every worker notices on its next read.

---

## 5. Anonymous-first-visit UX

Before any save: no cookie, no file → render the **default preset**.

**Recommend `Calm`** — it is the mockup's explicit default (`activePreset='calm'`, `appearance-settings.jsx:14`): Inter / stone / topbar / light / compact. It matches today's `data-theme="light"` default (`base.html:2`), so first paint is visually continuous with the current Watchtower rather than a jarring re-skin. (`Paper` is the runner-up — also light/crisp — but `Calm` is what the designer wired as the start state, so honor that.)

Attach-to-identity flow: first GET renders default, no cookie minted. First **Save preferences** POST calls `resolve_who()`, which mints `wt_uid` into the signed cookie and writes the file. From then on the user is identified. This keeps the preferences directory clean (one file per *saver*, not per *visitor*).

---

## 6. Multi-host visibility

Per-user YAML is **host-local and browser-local**. Concretely, with the deployment in memory (prod :5050 on LXC 170, dev :5051):

- The YAML lives on one host's disk. A second Watchtower host has none of the files.
- The cookie is FQDN-scoped. `watchtower.docker.ring20...` and `watchtower-dev.docker...` get **different** cookies → different `wt_uid` → different files even on the same machine.
- So the *same human* on laptop-vs-console, or prod-vs-dev, sees **different** preferences. There is no shared identity to join them.

**This must be accepted explicitly as a "single-host, single-browser preference store"** and the mockup copy **"synced across devices" (`appearance-settings.jsx:106`) must be deleted in S1** — shipping it is a direct falsehood to the user. The research artifact's Q2 rationale ("for a tool used across machines via Watchtower's HTTP surface, per-user filesystem persistence is the right durability tier", line 98) is **the inverted conclusion**: filesystem persistence is *worse* at cross-machine than a cookie, and *no better* than localStorage at it. Both lose. The honest framing is below.

---

## 7. `web/shared.py` API proposal (stubs)

```python
DEFAULT_PREFS = {
    "schema_version": 1, "preset": "calm", "typography": "inter",
    "palette": "stone", "accent_override": None, "nav_layout": "topbar",
    "density": "compact", "theme_mode": "light",
    "custom_overrides": {"reduce_motion": False, "high_contrast": True,
                         "mono_numerals": True, "breadcrumb_in_title": False},
}

def resolve_who(request) -> str:
    """Return a stable per-browser UID, minting + persisting in the signed
    session cookie on first call. Server-minted hex — never user-supplied."""

def load_user_preferences(who: str) -> dict:
    """Return merged DEFAULT_PREFS + on-disk prefs. mtime-cached (§4).
    Returns a copy of DEFAULT_PREFS when no file exists. Never raises."""

def save_user_preferences(who: str, prefs: dict) -> None:
    """Validate against allowlists (§9), then atomically write
    .context/user-preferences/<who>.yaml via temp + os.replace (§3)."""

def get_active_theme(request) -> dict:
    """Composite: resolve_who -> load_user_preferences -> resolve preset/palette/
    type into the concrete --wt-* token dict the template injects. The Python
    analogue of live-preview.jsx buildTheme()."""

def _prefs_path(who: str) -> Path:
    """Containment-checked path. realpath(result) MUST be inside
    .context/user-preferences/ or raise (§9)."""
```

`get_active_theme` is the load-bearing one — it is the server-side port of `buildTheme(pair, palette, mode)` from `live-preview.jsx:10-33`. **Flag for S0/S1 coordination:** the foundation token math (light/dark selection, `accentSoft` alpha, `mix()`, `hexA()`) currently lives only in JS (`live-preview.jsx:35-52`). If S0 puts the canonical tokens in `foundations.css` as `:root` variables, `get_active_theme` should select a *palette id + mode* and let CSS do the rest — do **not** re-port the hex math into Python (two sources of truth for color = drift). Resolve this seam in the S0↔S1 handoff.

---

## 8. Flask wiring

**`before_request` + context processor**, not `render_page()` plumbing:

```python
@app.before_request
def _load_theme():
    g.theme = get_active_theme(request)   # one resolve per request

@app.context_processor
def _inject_theme():
    return {"theme": g.get("theme", DEFAULT_PREFS)}
```

`render_page()` (`web/shared.py:774`) is the wrong layer — it is only hit by full-page and HTMX-fragment renders that go through that helper, but error handlers (`web/app.py:359-392`) render `_wrapper.html` directly and would miss the theme. `before_request` covers **every** route uniformly.

**HTMX correctness:** the theme lives on the root `<html data-theme>` + a `<style>` block of `--wt-*` vars in `<head>` (`base.html`). HTMX swaps *body fragments*, never `<html>`/`<head>`, so partial updates inherit the already-applied `:root` tokens for free — no per-fragment work (the inception's own constraint at T-1987 line 83 is correct here). The **one** exception is the live re-theme on the Appearance screen itself: the save response should hand back the new token set and a tiny JS handler applies it to `:root` live (matching the mockup's instant preview), while the server-rendered HTML stays correct on the next full load.

**FOUC note:** server-side rendering the tokens into `<head>` at first byte is *strictly better* than the current inline-localStorage-script dance (`base.html:9`) — no flash, no JS required, correct on the first paint for an identified user. This is the genuine, defensible advantage of server-side YAML over localStorage. (It does **not** require dropping the localStorage line for anonymous/error-page robustness — keep it as a belt-and-suspenders client cache.)

---

## 9. Risks not yet captured by the inception

1. **CSS injection via `accent_override` (high).** The mockup feeds a color straight into a style value (`appearance-settings.jsx:167-178`). If that string is written to YAML and later interpolated into `--wt-accent: <value>`, a value like `red;} body{display:none}` is a CSS-injection / defacement vector. **Validate `^#[0-9a-fA-F]{3,8}$` server-side before persist, and reject otherwise.** This is the appearance-form analogue of the YAML/CSS injection class.
2. **Path traversal via `<who>` (high if mis-implemented).** Mitigated *by construction* if `<who>` is server-minted hex (§1). If anyone later wires `<who>` from a header/form (e.g. when auth lands), `_prefs_path` MUST `realpath`-contain the result inside `.context/user-preferences/` and reject `..`, `/`, NUL. Borrow the guard philosophy already in `is_viewable_path` (`web/shared.py:321-340`).
3. **Allowlist enforcement on every enum field (medium).** `preset`/`palette`/`typography`/`nav_layout`/`density`/`theme_mode` must be checked against the known id sets before write. Unvalidated values become broken renders or class-name injection downstream.
4. **Unbounded directory growth (medium).** Cookie-per-browser means one YAML per browser that ever *saved*. Crawlers, CI, every colleague's one-time visit → file accrual forever. Lazy-mint-on-save (§5) bounds it to actual savers; still, a `last_updated`-based prune (e.g. a cron drop after 180 d untouched) belongs in scope or the DEFERRED list.
5. **Two render workers reading the same file (low).** Reads need no lock; concurrent reads of a file mid-`os.replace` are safe because replace is atomic (§3). Already handled — noted for completeness.
6. **Signed-cookie size + secret rotation (low).** Adding `wt_uid` to the cookie is ~40 bytes — fine. But if `FW_SECRET_KEY` ever rotates, every `wt_uid` is invalidated and all users silently revert to default (their files orphan). Acceptable for cosmetics; document it so it isn't mistaken for data loss.

---

## 10. Recommendation

**ADJUST.** Keep server-side per-user YAML — it is the right call *for reasons the inception did not state*, and wrong for the reasons it *did* state.

**Keep, because (the real justification):**
- **Server-side render kills FOUC** and removes the need for client JS to apply theme — strictly better first paint than localStorage (§8).
- **Agent/CLI visibility** — a YAML file is readable by agents, auditable, and a future `fw appearance` verb is trivial. localStorage is a black box to the framework. For a "file-everything, agents-can-read-it" framework, this is the philosophically consistent tier. *This* is the argument the inception should have made.

**Adjust, because (factual corrections required before S1):**
1. **Fix the `<who>` story.** T-1987 line 85 ("`$USER` from session or basic-auth header") is unbuildable — neither exists. Replace with the minted signed-cookie UID scheme (§1).
2. **Delete the cross-machine claim.** Correct A2's evidence and the research-artifact Q2 rationale (line 98): per-user YAML is **single-host, single-browser**, *not* cross-machine. Remove "synced across devices" from the mockup (`appearance-settings.jsx:106`) — it is false.
3. **Add the security ACs** §9 items 1–3 (CSS-injection allowlist, path-containment, enum allowlist) as Agent ACs on T-1988 — they are deterministic and testable, not review-judgment.
4. **Specify atomic write + mtime cache** (§3, §4) so the multi-worker prod reality is handled from the start, and retrofit `settings.py`'s non-atomic write while there.

**On "was localStorage actually correct?"** For the *narrow goal the human cited* (survive restart, work across machines), localStorage ties on restart and **beats** YAML's actual cross-machine behavior (cookie+YAML doesn't sync either). So if those were the only goals, the human's rationale doesn't support YAML over localStorage. **But** the unstated goals — FOUC-free server render + agent visibility — *do* justify YAML, and they are the better fit for this framework. Net: the decision is right, the reasoning needs replacing. Surface this to the human so the choice rests on the true tradeoff, not the false one. The genuinely strongest design is the **hybrid the human rejected** (option 3): YAML as system-of-record for server render + agent reads, localStorage as a client mirror for instant pre-paint and error-page robustness — worth re-offering with the corrected framing.

---

*Reviewer: reviewer-A2-persistence (isolated TermLink worker). No source files edited; analysis only.*
