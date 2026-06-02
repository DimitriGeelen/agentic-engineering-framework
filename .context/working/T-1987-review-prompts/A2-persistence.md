# T-1987 review-A2 — persistence layer reviewer

You are an isolated TermLink-dispatched worker reviewing the persistence layer dimension of arc-007 (watchtower-redesign) inception T-1987. Parent runs from `/opt/999-Agentic-Engineering-Framework`. You produce ONE review artifact and post a fw bus summary. You do NOT transition T-1987 or any child task.

## Setup (run first, in order)

1. Confirm `pwd` is `/opt/999-Agentic-Engineering-Framework`.
2. Read inception: `.tasks/active/T-1987-watchtower-redesign--apply-claude-design.md`
3. Read research artifact: `docs/reports/T-1987-watchtower-redesign-inception.md`
4. Read mockup of the appearance screen: `docs/design/watchtower-redesign-2026-05-13/project/appearance-settings.jsx`
5. Read live-preview: `docs/design/watchtower-redesign-2026-05-13/project/live-preview.jsx`
6. Inspect current Watchtower web layer: `web/shared.py`, `web/app.py`, `web/blueprints/`, any existing `.context/user-preferences/` directory (likely absent), how `$USER` propagates to Flask (probably not at all today — basic auth?), look at `web/blueprints/core.py` for current settings/config patterns.
7. Look at other Flask apps in the repo for per-user persistence patterns (search for `user-preferences`, `user_id`, session cookies).

## Your dimension: per-user YAML persistence for appearance preferences

You are reviewing **S1 (T-1988)** scope: the persistence layer for the appearance settings screen. The human chose per-user YAML at `.context/user-preferences/<who>.yaml` over localStorage and cookie+YAML hybrid.

## Deliverable

Write to `docs/reports/T-1987-reviews/A2-persistence-layer.md` (this exact path — repo-durable).

Required sections:

1. **How is `<who>` resolved?** — Watchtower currently runs on LAN with no auth (verify by reading `web/app.py`). What identifies a user — `$USER` from server-side process? Browser fingerprint? Basic-auth header? Cookie set by /settings/appearance on first save? Propose ONE concrete scheme + fallback for first-visit anonymous.
2. **YAML schema proposal** — Concrete field structure for `.context/user-preferences/<who>.yaml`. Include: preset, typography, palette, accent_override, nav_layout, density, theme_mode, custom_overrides, last_updated, schema_version. Show an example file inline (10 lines).
3. **Concurrent-write races** — Two browser tabs change settings simultaneously, both POST to /api/appearance/save. How does the second write not stomp the first? Last-write-wins? File-lock? Optimistic ETag? Pick one and justify.
4. **Read path performance** — Every page render reads the user's preferences. Cost: filesystem stat + YAML parse on every request. Profile estimate: how many ms? Should we cache in-process? If cached, invalidation strategy on save?
5. **Anonymous-first-visit UX** — Before any save, what does the user see? Default preset? "Calm" or "Paper"? How does the save flow attach to a stable identity (`<who>`) when there was no identity before?
6. **Multi-host visibility** — Per-user YAML is host-local. Two human users sharing the same `<who>` on different hosts via the same Watchtower URL (e.g., one logs in remotely, one on the LXC console) — what happens? Is this in scope, or accepted as "single-host preference store"?
7. **`web/shared.py` API proposal** — Concrete Python function signatures: `load_user_preferences(who: str) -> dict`, `save_user_preferences(who: str, prefs: dict) -> None`, `resolve_who(request: Request) -> str`, `get_active_theme(request: Request) -> dict` (composite). Stub-level only — no implementation needed.
8. **Flask wiring** — Where does the load happen? Template context processor? `before_request` handler? Cite which approach minimises read overhead while staying correct on HTMX partial updates.
9. **Risks not yet captured** — Anything the inception misses (e.g., YAML injection from the appearance form; user-controlled paths in `<who>`; symlink escapes; reading the same file in two render workers).
10. **Recommendation** — KEEP / ADJUST / CHALLENGE the inception's persistence choice. If you think localStorage was actually correct (mockup parity), say so with rationale.

## Constraints

- **No source edits** — you produce analysis only.
- **Do not edit T-1987 or T-1988-T-1994 task bodies.**
- **Path isolation**: stay in `/opt/999-Agentic-Engineering-Framework`.
- **Banned tools**: TaskCreate/TaskUpdate/TodoWrite/TaskList/TaskGet, EnterPlanMode.

## Reporting

1. Commit: `git add docs/reports/T-1987-reviews/A2-persistence-layer.md && bin/fw git commit -m "T-1987: review-A2 persistence layer"`.
2. Post: `bin/fw bus post --task T-1987 --agent reviewer-A2-persistence --summary "..." --blob docs/reports/T-1987-reviews/A2-persistence-layer.md`
3. Final ≤ 5 lines: DONE | artifact path | KEEP/ADJUST/CHALLENGE | who-resolution scheme picked | one-line critical concern (if any)

Begin.
