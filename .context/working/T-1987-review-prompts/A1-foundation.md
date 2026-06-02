# T-1987 review-A1 — foundation/CSS-architecture reviewer

You are an isolated TermLink-dispatched worker reviewing the foundation/CSS architecture dimension of arc-007 (watchtower-redesign) inception T-1987. Parent runs from `/opt/999-Agentic-Engineering-Framework`. Framework governance applies. You do NOT transition T-1987 (owner: human, sovereignty gate). You produce ONE review artifact and post a fw bus summary.

## Setup (run first, in order)

1. Confirm you are at `/opt/999-Agentic-Engineering-Framework` (`pwd`). If not, refuse — do not edit outside the framework repo.
2. Read the inception body: `.tasks/active/T-1987-watchtower-redesign--apply-claude-design.md`
3. Read the research artifact: `docs/reports/T-1987-watchtower-redesign-inception.md`
4. Read the foundation source: `docs/design/watchtower-redesign-2026-05-13/project/foundations.jsx`
5. Read the current Watchtower style baseline: `web/static/css/`, `web/shared.py`, and `web/templates/base.html`
6. Grep `web/templates/` for PicoCSS usage patterns (class names, `--pico-*` vars)

## Your dimension: foundation tokens + CSS architecture

You are reviewing **S0 (T-1991)** scope: the foundation token layer (6 palettes × light+dark + 6 type pairings + 3 density tiers). You enhance the inception's plan with concrete architecture.

## Deliverable

Write to `docs/reports/T-1987-reviews/A1-foundation-architecture.md` (this exact path — repo-durable, NOT /tmp/).

Required sections:

1. **Verdict on A3** — Can CSS custom properties on `:root` swap a full palette without visible flash? Cite evidence (current Watchtower CSS architecture, Pico's repaint behaviour, what `--wt-*` swap would actually trigger).
2. **Verdict on A6** — Will Cytoscape (in `/fabric`) read CSS custom properties for node/edge colors? Read the current fabric template/JS to find concrete answer. If it can't, propose a fallback (computed style read + cytoscape.style().update()).
3. **Verdict on A7** — Can PicoCSS coexist with `--wt-*` tokens during migration? Concrete: which Pico vars collide with proposed `--wt-*` vars? Which Pico classes need overrides? List 3-5 specific collision cases or confirm clean coexistence.
4. **Concrete `--wt-*` token scheme** — Propose the full naming and structure. Should it be `--wt-color-bg` or `--wt-bg`? Should density be tokens or a class? Should type pairings be CSS-only or include a JS init? Specify cascade order against PicoCSS.
5. **Font loading strategy** — Current design loads 5 web fonts via Google Fonts. Concrete proposal: vendor as WOFF2 in `web/static/fonts/`? Subset? FOUT vs FOIT?
6. **S0 spike test list** — Convert A3/A6/A7 into specific shell/python commands or Playwright snippets that produce binary pass/fail. These go into T-1991's `## Verification` block when S0 starts.
7. **Risks not yet captured** — Anything the inception's risk table misses (e.g., HTMX swap respects CSS vars, but what about inline-styled fragments?).
8. **Recommendation** — KEEP / ADJUST / CHALLENGE the inception's S0 scope. If ADJUST, propose specific changes. If CHALLENGE, explain.

## Constraints

- **No source edits** (no `web/static/`, `web/templates/`, `bin/fw`, etc.) — you produce analysis only.
- **Do not edit T-1987** — the inception body belongs to the human + parent agent.
- **Do not edit S0-S6 child tasks** (T-1988..T-1994) — their bodies fill in when work starts.
- **Path isolation**: stay in `/opt/999-Agentic-Engineering-Framework`.
- **Banned tools**: TaskCreate/TaskUpdate/TodoWrite/TaskList/TaskGet (T-1115), EnterPlanMode (use /plan if needed).
- **Quote brevity**: cite design bundle file paths and line numbers, don't paste large code blocks.

## Reporting

When done:
1. Commit your artifact: `git add docs/reports/T-1987-reviews/A1-foundation-architecture.md && bin/fw git commit -m "T-1987: review-A1 foundation/CSS architecture"` (focus is T-1987, no FW_SWITCH_FOCUS needed).
2. Post completion to fw bus:
   ```
   bin/fw bus post --task T-1987 --agent reviewer-A1-foundation \
     --summary "Foundation review: <one-liner verdict>" \
     --blob docs/reports/T-1987-reviews/A1-foundation-architecture.md
   ```
3. Final response ≤ 5 lines:
   - Line 1: DONE or BLOCKED
   - Line 2: artifact path
   - Line 3: one-sentence verdict (KEEP/ADJUST/CHALLENGE)
   - Line 4: A3/A6/A7 verdicts in one line (e.g., "A3:PASS A6:PASS A7:CONCERN")

Begin.
