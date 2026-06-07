#!/usr/bin/env python3
"""UX-review capture engine — T-2002 (approach C of inception T-2000).

Drives a Watchtower render surface in a real headless browser, applies every
appearance preset, and produces a *visual* review artifact a human can actually
look at — the thing the text `/review/<task>` page cannot give for a redesign.

What it does per theme state:
  1. clicks the preset, waits for it to apply + persist (catches dead-JS — the
     exact T-1988 class, where every preset button was inert behind a SyntaxError)
  2. scans the browser console for errors AND uncaught page errors
  3. screenshots the whole re-themed app (a content page) + the picker page
  4. reads the *computed* --wt-* tokens and checks them against OUR design guide
     (foundations.css, parsed at runtime) for both fidelity and WCAG AA contrast

It then writes a side-by-side gallery (index.html) + a findings report with an
overall PASS / CONCERN verdict. It INFORMS the human [REVIEW]; it never replaces
the taste call (T-1811).

Cross-page theme sweep (T-2005, --sweep / --content-pages):
  verifies the arc-007 headline mechanic — pick one theme on the appearance screen,
  then re-load every page (Cockpit/Tasks/Approvals/Fabric/Arcs) and confirm it stays
  applied. Per page it captures a screenshot + the pico-bridge state (--pico-primary
  must equal --wt-accent, the T-2003 class). Tests the real persist→navigate→
  server-inject path, and prioritizes which redesign slice has the most broken theme.

Axis smoke-test (--axes, T-2004):
  clicks each Typography and Density option individually and asserts a measurable
  visible effect (distinct rendered width / body font-size) — catches inert axes that
  the preset capture masks.

Usage:
  python3 agents/ux-review/ux-review.py [--base URL] [--page /settings/appearance]
                                        [--out web/static/ux-review]
                                        [--content-page /tasks]
                                        [--sweep | --content-pages "/,/tasks,/arcs"]
                                        [--axes]

--base defaults to `bin/fw watchtower url`. Exit 0 if the engine ran end-to-end
(a CONCERN verdict is still a successful run — the findings are the product).
"""
from __future__ import annotations

import argparse
import datetime as _dt
import html
import os
import re
import subprocess
import sys

# Tokens we assess. text/muted are read against bg + surface; accent-ink against accent.
PALETTE_TOKENS = [
    "--wt-bg", "--wt-surface", "--wt-border",
    "--wt-text", "--wt-muted",
    "--wt-accent", "--wt-accent-ink",
]
AA_NORMAL = 4.5   # WCAG 2.1 AA for normal text
AA_LARGE = 3.0    # WCAG 2.1 AA for large text / UI components


# --------------------------------------------------------------------------- #
# colour + contrast (the "is it readable" half of the guide check)
# --------------------------------------------------------------------------- #
def _parse_hex(value: str):
    """Parse #rgb / #rrggbb (and rgb()/rgba()) into an (r,g,b) 0-255 tuple."""
    v = (value or "").strip()
    m = re.match(r"#([0-9a-fA-F]{3})$", v)
    if m:
        h = m.group(1)
        return tuple(int(c * 2, 16) for c in h)
    m = re.match(r"#([0-9a-fA-F]{6})$", v)
    if m:
        h = m.group(1)
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    m = re.match(r"rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)", v)
    if m:
        return tuple(int(m.group(i)) for i in (1, 2, 3))
    return None


def _rel_luminance(rgb):
    def chan(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (chan(x) for x in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(fg: str, bg: str):
    """WCAG contrast ratio between two colour strings; None if unparseable."""
    a, b = _parse_hex(fg), _parse_hex(bg)
    if a is None or b is None:
        return None
    la, lb = _rel_luminance(a), _rel_luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return round((hi + 0.05) / (lo + 0.05), 2)


# --------------------------------------------------------------------------- #
# design guide (foundations.css) — the "preload" that makes this specialised
# --------------------------------------------------------------------------- #
def parse_foundations(css_path: str):
    """Parse declared --wt-* palette tokens from foundations.css.

    Returns {("palette", "light"|"dark"): {token: hex}}. The dark blocks in
    foundations.css only override bg/surface/border/text/muted; the accent set
    carries over from light, so we layer dark on top of light per palette.
    """
    try:
        css = open(css_path, encoding="utf-8").read()
    except OSError:
        return {}
    # strip comments so selectors inside /* */ don't match
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    guide: dict = {}

    def _tokens(block: str):
        out = {}
        for name, val in re.findall(r"(--wt-[\w-]+)\s*:\s*([^;]+);", block):
            out[name.strip()] = val.strip()
        return out

    # light: [data-wt-palette="X"] { ... }  (also the :root,[...slate] combo)
    for sel, block in re.findall(r"([^{}]+)\{([^{}]+)\}", css):
        sels = [s.strip() for s in sel.split(",")]
        toks = _tokens(block)
        if not toks:
            continue
        for s in sels:
            m_dark = re.match(
                r'\[data-theme="dark"\]\[data-wt-palette="(\w+)"\]', s
            ) or re.match(r'\[data-wt-mode="dark"\]\[data-wt-palette="(\w+)"\]', s)
            m_light = re.fullmatch(r'\[data-wt-palette="(\w+)"\]', s)
            if m_dark:
                guide.setdefault((m_dark.group(1), "dark"), {}).update(toks)
            elif m_light:
                guide.setdefault((m_light.group(1), "light"), {}).update(toks)
            elif s in (":root", '[data-wt-palette="slate"]'):
                guide.setdefault(("slate", "light"), {}).update(toks)
    # layer: dark inherits light's accent set
    for (pal, mode) in list(guide.keys()):
        if mode == "dark":
            base = dict(guide.get((pal, "light"), {}))
            base.update(guide[(pal, "dark")])
            guide[(pal, "dark")] = base
    return guide


def _norm_hex(v: str):
    rgb = _parse_hex(v)
    return "#%02x%02x%02x" % rgb if rgb else (v or "").strip().lower()


# --------------------------------------------------------------------------- #
# per-state assessment
# --------------------------------------------------------------------------- #
def assess_state(computed: dict, guide_tokens: dict):
    """Return (findings:list[str], status:'ok'|'concern', contrasts:dict)."""
    findings, status = [], "ok"

    # 1. contrast (readability)
    contrasts = {
        "text/bg": contrast_ratio(computed.get("--wt-text"), computed.get("--wt-bg")),
        "text/surface": contrast_ratio(computed.get("--wt-text"), computed.get("--wt-surface")),
        "muted/bg": contrast_ratio(computed.get("--wt-muted"), computed.get("--wt-bg")),
        "accent-ink/accent": contrast_ratio(computed.get("--wt-accent-ink"), computed.get("--wt-accent")),
    }
    if (contrasts["text/bg"] or 99) < AA_NORMAL:
        findings.append(f"body text contrast {contrasts['text/bg']}:1 < AA {AA_NORMAL}:1")
        status = "concern"
    if (contrasts["accent-ink/accent"] or 99) < AA_NORMAL:
        findings.append(
            f"button label (accent-ink on accent) {contrasts['accent-ink/accent']}:1 < AA {AA_NORMAL}:1"
        )
        status = "concern"
    if (contrasts["muted/bg"] or 99) < AA_LARGE:
        findings.append(f"muted text contrast {contrasts['muted/bg']}:1 < {AA_LARGE}:1 (large-text floor)")
        status = "concern"

    # 2. fidelity (computed tokens == declared design tokens)
    if guide_tokens:
        for tok in PALETTE_TOKENS:
            want, got = guide_tokens.get(tok), computed.get(tok)
            if want and got and _norm_hex(want) != _norm_hex(got):
                findings.append(f"{tok} rendered {_norm_hex(got)} ≠ guide {_norm_hex(want)}")
                status = "concern"
    return findings, status, contrasts


# --------------------------------------------------------------------------- #
# capture (the browser-driving half)
# --------------------------------------------------------------------------- #
def _settle_paint(page, expected_accent=None):
    """Block until the palette CSS has actually painted, not just landed in the DOM.

    The DOM attribute (data-wt-palette) is set server-side before paint, but a
    full_page screenshot can fire before the new --wt-* values repaint — capturing
    the previous/default palette. This caused linen/bone/paper to come out as
    byte-identical default-indigo frames (nondeterministic between runs). We wait
    for the computed accent to equal the expected token, then force two animation
    frames (= a guaranteed paint) plus a short settle.
    """
    if expected_accent:
        try:
            page.wait_for_function(
                "(a) => getComputedStyle(document.documentElement)"
                ".getPropertyValue('--wt-accent').trim() === a",
                arg=expected_accent, timeout=5000,
            )
        except Exception:
            pass
    try:
        page.evaluate(
            "() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))"
        )
    except Exception:
        pass
    page.wait_for_timeout(150)


# Above this rendered height (px) a `full_page=True` screenshot can WEDGE the
# browser — Chromium cannot reliably rasterize a single image this tall, and the
# Playwright `timeout` does not cancel it cleanly (the call hangs past the
# deadline until the OS kills the process, EPIPE). One such page therefore takes
# down the ENTIRE sweep. Pages taller than this get a height-clipped capture
# instead, and the height is surfaced as a signal rather than a hard failure.
# Origin (T-2005): /approvals grew to 37,247px as the review backlog piled up
# (no pagination) and killed every sweep. Data growth, not a code regression —
# the sweep's job as a regression guard worked; the tool just wasn't antifragile
# to it. The unbounded-height page itself is filed separately as a page bug.
TALL_PAGE_CAP_PX = 8000


def _safe_shot(page, path, viewport_w=1440):
    """Capture a page without letting one pathologically tall page wedge the
    browser. Returns (mode, height_px) where mode is one of:
      'full'     — sane height, captured full_page
      'clipped'  — too tall, captured the top TALL_PAGE_CAP_PX px only
      'viewport' — full/clip failed, fell back to a viewport grab
      'failed'   — every strategy failed (row still recorded, sweep continues)
    The bridge / computed-token check is independent of the screenshot, so a
    clipped or failed capture never invalidates the headline-mechanic verdict."""
    try:
        h = int(page.evaluate("document.documentElement.scrollHeight") or 0)
    except Exception:
        h = 0
    try:
        if h and h > TALL_PAGE_CAP_PX:
            page.screenshot(
                path=path,
                clip={"x": 0, "y": 0, "width": viewport_w, "height": TALL_PAGE_CAP_PX},
                timeout=20000,
            )
            return "clipped", h
        page.screenshot(path=path, full_page=True, timeout=20000, animations="disabled")
        return "full", h
    except Exception:
        try:
            page.screenshot(path=path, full_page=False, timeout=15000)
            return "viewport", h
        except Exception:
            return "failed", h


def capture(base: str, page_path: str, content_page: str, out_dir: str, guide: dict):
    from playwright.sync_api import sync_playwright

    os.makedirs(out_dir, exist_ok=True)
    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        ctx = browser.new_context(viewport={"width": 1440, "height": 1000})
        page = ctx.new_page()
        page.set_default_timeout(15000)

        # prime CSRF/session so the page's save() POST persists the choice
        page.goto(base + "/", wait_until="domcontentloaded")

        # discover presets straight from the picker (no hard-coded list)
        page.goto(base + page_path, wait_until="domcontentloaded")
        presets = page.evaluate(
            "() => Array.from(document.querySelectorAll('#wt-presets .wt-preset'))"
            ".map(b => ({id:b.dataset.preset, label:b.querySelector('.nm')?.textContent?.trim()||b.dataset.preset,"
            " palette:b.dataset.palette, type:b.dataset.type, density:b.dataset.density, mode:b.dataset.mode}))"
        )
        if not presets:
            raise RuntimeError(
                f"No presets found at {base}{page_path} — page may be broken or selector changed"
            )

        # register error listeners ONCE; clear the shared buffer per state
        state_errors: list[str] = []
        page.on("console", lambda m: state_errors.append(f"console.{m.type}: {m.text}")
                if m.type == "error" else None)
        page.on("pageerror", lambda exc: state_errors.append(f"pageerror: {exc}"))

        for ps in presets:
            pid = ps["id"]
            state_errors.clear()
            errors = state_errors

            page.goto(base + page_path, wait_until="domcontentloaded")
            page.click(f'button[data-preset="{pid}"]')
            # if the JS is dead (T-1988), this wait times out → recorded as a finding
            applied = True
            try:
                page.wait_for_function(
                    "(p) => document.documentElement.getAttribute('data-wt-palette') === p",
                    arg=ps["palette"], timeout=6000,
                )
                page.wait_for_function(
                    "() => { const s=document.getElementById('wt-status');"
                    " return s && s.textContent.indexOf('Saved') === 0; }",
                    timeout=6000,
                )
            except Exception:
                applied = False
                errors.append("preset did NOT apply within 6s — click handler likely dead (T-1988 class)")

            computed = page.evaluate(
                "(toks) => { const s=getComputedStyle(document.documentElement); const o={};"
                " toks.forEach(t => o[t]=s.getPropertyValue(t).trim());"
                " o['font']=s.getPropertyValue('--wt-font-head').trim(); return o; }",
                PALETTE_TOKENS,
            )
            mode = ps.get("mode") or "light"
            expected_accent = guide.get((ps["palette"], mode), {}).get("--wt-accent")
            _settle_paint(page, expected_accent)
            _safe_shot(page, os.path.join(out_dir, f"picker-{pid}.png"))

            # the whole app re-themed (content-rich page). full_page so accent
            # links/badges are in frame — warm palettes (linen vs bone) differ
            # mainly in accent, which a clipped viewport can miss entirely.
            # Cache-buster query → unique URL per palette so the browser never
            # serves a stale /tasks render from a prior palette (the cause of
            # byte-identical warm-light frames; DOM tokens were always correct).
            sep = "&" if "?" in content_page else "?"
            page.goto(base + content_page + f"{sep}_uxr={pid}", wait_until="load")
            _settle_paint(page, expected_accent)
            _safe_shot(page, os.path.join(out_dir, f"app-{pid}.png"))

            # Bridge check: on a content page the chrome is Pico-styled, so the
            # palette only reaches it via the foundations.css pico-bridge
            # (--pico-primary: var(--wt-accent)). If --pico-primary on the content
            # page does NOT equal --wt-accent, the bridge is defeated and the app
            # chrome ignores the palette (CSS-specificity bug, light mode).
            bridge = page.evaluate(
                "() => { const s=getComputedStyle(document.documentElement);"
                " return {pico:s.getPropertyValue('--pico-primary').trim(),"
                " wt:s.getPropertyValue('--wt-accent').trim()}; }"
            )

            findings, status, contrasts = assess_state(computed, guide.get((ps["palette"], mode), {}))
            if bridge["pico"] and bridge["wt"] and _norm_hex(bridge["pico"]) != _norm_hex(bridge["wt"]):
                findings.append(
                    f"content-page chrome does NOT follow palette: --pico-primary "
                    f"{_norm_hex(bridge['pico'])} ≠ --wt-accent {_norm_hex(bridge['wt'])} "
                    "(pico-bridge defeated — app chrome stuck on Pico default)"
                )
                status = "concern"
            js_errors = [e for e in errors if "favicon" not in e.lower()]
            if js_errors:
                status = "concern"
            results.append({
                **ps, "applied": applied, "computed": computed,
                "errors": list(js_errors), "findings": findings, "status": status,
                "contrasts": contrasts,
            })
        browser.close()

    # integrity self-check: two distinct palettes must not produce a byte-identical
    # app frame. If they do, the capture didn't reflect the palette — flag it as a
    # CONCERN rather than presenting misleading "distinct" screenshots (antifragile:
    # the tool surfaces its own capture failure instead of lying).
    import hashlib
    by_hash: dict = {}
    for r in results:
        png = os.path.join(out_dir, f"app-{r['id']}.png")
        if os.path.exists(png):
            h = hashlib.md5(open(png, "rb").read()).hexdigest()
            by_hash.setdefault(h, []).append(r["label"])
    for h, labels in by_hash.items():
        if len(labels) > 1:
            for r in results:
                if r["label"] in labels:
                    r["findings"].append(
                        f"app screenshot byte-identical to {', '.join(l for l in labels if l != r['label'])}"
                        " — capture may not reflect this palette (review picker frame instead)"
                    )
                    r["status"] = "concern"
    return results


# --------------------------------------------------------------------------- #
# cross-page theme sweep (T-2005) — verify the arc-007 headline mechanic
# --------------------------------------------------------------------------- #
# The headline mechanic promises: pick a theme once, then re-load ANY page
# (Cockpit/Tasks/Approvals/Fabric/Arcs) and observe the same applied theme
# without manual reapply. capture() only ever checks ONE content page per preset;
# this exercises the real persist→navigate→server-inject path across every page.
DEFAULT_SWEEP_PAGES = ["/", "/tasks", "/approvals", "/fabric", "/arcs"]
SWEEP_PRESET = "bone"  # light-mode, distinctive amber accent → bridge defects most visible


def _page_slug(path: str) -> str:
    return path.strip("/").replace("/", "-") or "root"


def discover_get_routes():
    """Enumerate every parameterless GET route from the app's url_map.

    The unbounded-page class (T-2038..T-2041) slipped past the sweep because the page
    list was hard-coded to 5 routes — /inception (83k px) and /timeline (90k px) were
    never checked, so they grew unbounded undetected. Deriving the set from
    web.app.app.url_map makes the height detector exhaustive: a page can no longer be
    blind-spotted by omission (T-2042, G-019 root). Excludes rules with URL arguments
    (can't load without params), /api/* and /static (not human render surfaces), and
    non-GET endpoints. Returns a sorted list of path strings; raises on import failure
    so the caller can fall back to DEFAULT_SWEEP_PAGES.
    """
    import sys as _sys
    _root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    if _root not in _sys.path:
        _sys.path.insert(0, _root)
    from web.app import app  # imported here so a missing app never breaks plain --sweep

    paths = set()
    for rule in app.url_map.iter_rules():
        if rule.arguments:                      # parameterized — can't load blind
            continue
        if "GET" not in (rule.methods or set()):
            continue
        path = str(rule.rule)
        if path.startswith("/api/") or path.startswith("/static"):
            continue
        paths.add(path)
    return sorted(paths)


def discover_parametrized_routes(per_pattern_limit: int = 5, project_root: str | None = None):
    """Sample concrete paths for the four high-value parametrized GET patterns.

    T-2087 surfaced two over-cap `/arcs/<slug>` pages (15184px orchestrator-rethink,
    8076px arc-grooming) that `discover_get_routes()` never measured — it filters out
    parametrized rules ("can't load blind"). That blind-spot is exactly how T-2038-class
    regressions land: the parameterless guard is exhaustive, but a sibling template can
    grow unbounded silently on a parametrized route.

    Strategy: pick the top-N by source-file byte size (proxy for rendered content size,
    since larger YAML/markdown bodies = more rows/cards rendered). Same 8000px cap as
    the parameterless guard.

    Patterns sampled:
      /arcs/<slug>          — top-N from .context/arcs/*.yaml
      /tasks/<task_id>      — top-N from .tasks/{active,completed}/T-*.md
      /review/<task_id>     — top-N from .tasks/active/T-*.md (review is for in-flight)
      /inception/<task_id>  — top-N from .tasks/active/ with workflow_type: inception

    Args:
      per_pattern_limit: cap per pattern. Default 5 keeps the suite well under the 280s
        budget (4 × 5 = 20 routes ≈ 2-3s each ≈ 40-60s added).
      project_root: override PROJECT_ROOT for tests; defaults to repo root.

    Returns sorted, deduped list of concrete paths. Empty-fixture safe: missing
    .context/arcs or .tasks directories silently return zero paths for that pattern.
    """
    import glob as _glob
    root = project_root or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    def _top_n_by_size(pattern: str, n: int) -> list[str]:
        """Return the N largest matching files by byte size, ordered largest-first."""
        files = _glob.glob(pattern)
        if not files:
            return []
        with_size = []
        for f in files:
            try:
                with_size.append((os.path.getsize(f), f))
            except OSError:
                continue
        with_size.sort(key=lambda x: -x[0])
        return [f for _, f in with_size[:n]]

    paths: set[str] = set()

    # /arcs/<slug> — slug = YAML filename stem
    for f in _top_n_by_size(os.path.join(root, ".context", "arcs", "*.yaml"), per_pattern_limit):
        slug = os.path.splitext(os.path.basename(f))[0]
        paths.add(f"/arcs/{slug}")

    # /tasks/<task_id> — id = filename T-NNNN prefix
    task_glob_all = _glob.glob(os.path.join(root, ".tasks", "active", "T-*.md")) + \
                    _glob.glob(os.path.join(root, ".tasks", "completed", "T-*.md"))
    if task_glob_all:
        with_size = sorted(((os.path.getsize(f), f) for f in task_glob_all), key=lambda x: -x[0])
        for _, f in with_size[:per_pattern_limit]:
            tid = os.path.basename(f).split("-", 2)[0:2]  # ["T", "NNNN"]
            if len(tid) == 2 and tid[0] == "T":
                paths.add(f"/tasks/{tid[0]}-{tid[1]}")

    # /review/<task_id> — active only (review surface is for in-flight work)
    active_tasks = _top_n_by_size(os.path.join(root, ".tasks", "active", "T-*.md"), per_pattern_limit)
    for f in active_tasks:
        tid = os.path.basename(f).split("-", 2)[0:2]
        if len(tid) == 2 and tid[0] == "T":
            paths.add(f"/review/{tid[0]}-{tid[1]}")

    # /inception/<task_id> — workflow_type: inception, active+completed
    inception_files = []
    for tdir in ("active", "completed"):
        for f in _glob.glob(os.path.join(root, ".tasks", tdir, "T-*.md")):
            try:
                # Cheap frontmatter peek — first ~30 lines covers the header
                with open(f, "r", encoding="utf-8", errors="replace") as fh:
                    head = "".join(fh.readline() for _ in range(30))
                if "workflow_type: inception" in head:
                    inception_files.append((os.path.getsize(f), f))
            except OSError:
                continue
    inception_files.sort(key=lambda x: -x[0])
    for _, f in inception_files[:per_pattern_limit]:
        tid = os.path.basename(f).split("-", 2)[0:2]
        if len(tid) == 2 and tid[0] == "T":
            paths.add(f"/inception/{tid[0]}-{tid[1]}")

    return sorted(paths)


def sweep_pages(base: str, page_path: str, content_pages, out_dir: str, guide: dict,
                preset_id: str = SWEEP_PRESET):
    """Apply ONE non-default preset on the picker (persists to the per-user pref),
    then navigate to each page and verify the theme survived. Per page we capture a
    screenshot and the pico-bridge state (--pico-primary must equal --wt-accent — if
    not, that page's chrome ignores the palette, T-2003 class). Tests the persist→
    reload→server-inject path, not a client-side reapply.

    Returns (preset_label, palette, mode, rows) where each row is
    {page, slug, bridge_ok, pico, wt, bg, text}.
    """
    from playwright.sync_api import sync_playwright

    os.makedirs(out_dir, exist_ok=True)
    rows = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        ctx = browser.new_context(viewport={"width": 1440, "height": 1000})
        page = ctx.new_page()
        page.set_default_timeout(15000)

        # prime session cookie, then apply the preset on the picker so save() POSTs
        page.goto(base + "/", wait_until="domcontentloaded")
        page.goto(base + page_path, wait_until="domcontentloaded")
        meta = page.evaluate(
            "(pid) => { const b=document.querySelector('button[data-preset=\"'+pid+'\"]');"
            " return b ? {palette:b.dataset.palette, type:b.dataset.type,"
            " density:b.dataset.density, mode:b.dataset.mode,"
            " label:(b.querySelector('.nm')?.textContent||pid).trim()} : null; }",
            preset_id,
        )
        if not meta:
            raise RuntimeError(f"sweep preset '{preset_id}' not found on {base}{page_path}")
        page.click(f'button[data-preset="{preset_id}"]')
        page.wait_for_function(
            "(p) => document.documentElement.getAttribute('data-wt-palette') === p",
            arg=meta["palette"], timeout=6000,
        )
        page.wait_for_function(
            "() => { const s=document.getElementById('wt-status');"
            " return s && s.textContent.indexOf('Saved') === 0; }",
            timeout=6000,
        )
        mode = meta.get("mode") or "light"
        expected_accent = guide.get((meta["palette"], mode), {}).get("--wt-accent")

        for cp in content_pages:
            slug = _page_slug(cp)
            sep = "&" if "?" in cp else "?"
            page.goto(base + cp + f"{sep}_uxr=sweep", wait_until="load")
            _settle_paint(page, expected_accent)
            shot_mode, shot_h = _safe_shot(page, os.path.join(out_dir, f"sweep-{slug}.png"))
            vals = page.evaluate(
                "() => { const s=getComputedStyle(document.documentElement);"
                " return {pico:s.getPropertyValue('--pico-primary').trim(),"
                " wt:s.getPropertyValue('--wt-accent').trim(),"
                " bg:s.getPropertyValue('--wt-bg').trim(),"
                " text:s.getPropertyValue('--wt-text').trim()}; }"
            )
            bridge_ok = bool(vals["pico"] and vals["wt"]
                             and _norm_hex(vals["pico"]) == _norm_hex(vals["wt"]))
            rows.append({"page": cp, "slug": slug, "bridge_ok": bridge_ok,
                         "shot_mode": shot_mode, "shot_h": shot_h, **vals})
        browser.close()
    return meta["label"], meta["palette"], mode, rows


# --------------------------------------------------------------------------- #
# artifacts
# --------------------------------------------------------------------------- #
def _badge(ok: bool, label: str):
    color = "#10b981" if ok else "#ef4444"
    return f'<span style="background:{color};color:#fff;border-radius:6px;padding:2px 8px;font-size:.75rem">{html.escape(label)}</span>'


def _sweep_section(sweep, base):
    """HTML block for the cross-page theme sweep (T-2005 headline-mechanic check)."""
    label, palette, mode, rows = sweep
    cards = []
    for r in rows:
        ok = r["bridge_ok"]
        mode = r.get("shot_mode", "full")
        h = r.get("shot_h", 0)
        if mode == "clipped":
            shot_note = (f' · <span style="color:#b45309">⚠ clipped @{h}px '
                         f'(too tall for full-page capture)</span>')
        elif mode == "viewport":
            shot_note = ' · <span style="color:#b45309">⚠ viewport-only (full capture failed)</span>'
        elif mode == "failed":
            shot_note = ' · <span style="color:#ef4444">⚠ capture failed</span>'
        else:
            shot_note = ""
        cards.append(f"""
  <section style="border:1px solid #e5e7eb;border-radius:12px;padding:12px;margin:0 0 16px">
    <h3 style="margin:0 0 6px">{html.escape(r['page'])}
      {_badge(ok, 'theme applied' if ok else 'THEME BROKEN')}</h3>
    <a href="sweep-{html.escape(r['slug'])}.png" target="_blank">
      <img src="sweep-{html.escape(r['slug'])}.png" style="width:100%;border:1px solid #e5e7eb;border-radius:8px"></a>
    <p style="margin:8px 0 0;color:#64748b;font-size:.8rem">
      --pico-primary <code>{html.escape(r['pico'])}</code> ·
      --wt-accent <code>{html.escape(r['wt'])}</code> ·
      --wt-bg <code>{html.escape(r['bg'])}</code>{shot_note}</p>
  </section>""")
    return f"""
<h2 style="margin:28px 0 6px">Cross-page theme fidelity (T-2005)</h2>
<p style="color:#64748b;font-size:.9rem">Headline mechanic: one preset
(<b>{html.escape(label)}</b> — {html.escape(palette)}/{html.escape(mode)}) picked once on
the appearance screen, then every page re-loaded. Each frame must carry the same palette;
<code>--pico-primary</code> must equal <code>--wt-accent</code> (the pico-bridge) or that
page's chrome ignores the theme.</p>
{''.join(cards)}"""


def write_gallery(results, out_dir, base, page_path, sweep=None):
    sweep_concerns = sum(1 for r in (sweep[3] if sweep else []) if not r["bridge_ok"])
    concerns = sum(1 for r in results if r["status"] == "concern") + sweep_concerns
    verdict = "PASS" if concerns == 0 else f"CONCERN ({concerns})"
    vcolor = "#10b981" if concerns == 0 else "#f59e0b"
    cards = []
    for r in results:
        ok = r["status"] == "ok"
        con = r["contrasts"]
        con_line = " · ".join(f"{k} {v}:1" for k, v in con.items() if v is not None)
        find = "".join(f"<li>{html.escape(f)}</li>" for f in r["findings"]) or "<li>none</li>"
        cards.append(f"""
<section style="border:1px solid #e5e7eb;border-radius:12px;padding:16px;margin:0 0 20px">
  <h2 style="margin:0 0 4px">{html.escape(r['label'])}
    <span style="font-weight:400;color:#64748b;font-size:.85rem">
      {html.escape(r['palette'])} · {html.escape(r['type'])} · {html.escape(r['density'])} · {html.escape(r['mode'])}</span></h2>
  <p style="margin:0 0 10px">{_badge(ok, 'OK' if ok else 'CONCERN')}
     {_badge(not r['errors'], 'console clean' if not r['errors'] else f"{len(r['errors'])} JS error(s)")}
     {_badge(r['applied'], 'preset applied' if r['applied'] else 'PRESET DEAD')}</p>
  <div style="display:grid;grid-template-columns:2fr 1fr;gap:14px;align-items:start">
    <a href="app-{r['id']}.png" target="_blank"><img src="app-{r['id']}.png" style="width:100%;border:1px solid #e5e7eb;border-radius:8px"></a>
    <a href="picker-{r['id']}.png" target="_blank"><img src="picker-{r['id']}.png" style="width:100%;border:1px solid #e5e7eb;border-radius:8px"></a>
  </div>
  <p style="margin:10px 0 2px;color:#64748b;font-size:.8rem">contrast: {html.escape(con_line)}</p>
  <ul style="margin:4px 0 0;color:#334155;font-size:.85rem">{find}</ul>
</section>""")
    ts = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    doc = f"""<!doctype html><html><head><meta charset="utf-8">
<title>UX Review — arc-007 S0/S1</title>
<style>body{{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:1100px;margin:0 auto;padding:24px;color:#0f172a}}
img{{display:block}} a{{color:#4f46e5}}</style></head><body>
<h1>UX Review — arc-007 watchtower-redesign (S0 tokens · S1 appearance)</h1>
<p style="color:#64748b">First-pass review by the T-2002 UX-review engine (approach C of inception T-2000).
Drives a real browser, scans console + page errors, checks computed tokens against
<code>foundations.css</code> and WCAG AA contrast. <b>Informs</b> your <code>[REVIEW]</code> — it does
not replace the taste call.</p>
<p>Overall: <span style="background:{vcolor};color:#fff;border-radius:8px;padding:4px 12px;font-weight:600">{verdict}</span>
&nbsp;·&nbsp; {len(results)} presets &nbsp;·&nbsp; captured {ts}
&nbsp;·&nbsp; live page: <a href="{html.escape(base + page_path)}" target="_blank">{html.escape(page_path)}</a></p>
<p style="color:#64748b;font-size:.85rem">Left image = whole app re-themed · right image = the picker. Click to enlarge.</p>
{''.join(cards)}
{_sweep_section(sweep, base) if sweep else ''}
</body></html>"""
    path = os.path.join(out_dir, "index.html")
    open(path, "w", encoding="utf-8").write(doc)
    return path, verdict


def write_report(results, report_path, base, gallery_url, verdict, sweep=None):
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    lines = [
        "# T-2002 — UX-review first pass: arc-007 S0/S1\n",
        f"_Generated by the T-2002 UX-review engine (approach C, inception T-2000)._\n",
        f"**Overall verdict:** {verdict}\n",
        f"**Gallery:** {gallery_url}\n",
        f"**Live page:** {base}/settings/appearance\n",
        "\nThis is the executed-browser first pass the static reviewers can't do: it clicks every "
        "preset, scans console + uncaught page errors (the T-1988 dead-JS class), and checks computed "
        "tokens against `foundations.css` + WCAG AA contrast. It informs the human `[REVIEW]`; the "
        "taste call (does the redesign *feel* right) stays human (T-1811).\n",
        "\n| Preset | Palette/Mode | Applied | Console | text/bg | accent-ink/accent | Status |",
        "|--------|-------------|---------|---------|---------|-------------------|--------|",
    ]
    for r in results:
        c = r["contrasts"]
        applied_cell = "yes" if r["applied"] else "**NO**"
        console_cell = "clean" if not r["errors"] else f"**{len(r['errors'])} err**"
        status_cell = "✅ ok" if r["status"] == "ok" else "⚠️ concern"
        lines.append(
            f"| {r['label']} | {r['palette']}/{r['mode']} | {applied_cell} | "
            f"{console_cell} | {c['text/bg']} | {c['accent-ink/accent']} | {status_cell} |"
        )
    detail = [l for r in results if r["findings"] for l in
              [f"\n### {r['label']} ({r['palette']}/{r['mode']})"] + [f"- {f}" for f in r["findings"]]]
    if detail:
        lines += ["\n## Findings detail"] + detail
    else:
        lines += ["\n## Findings detail\n\nNo automated findings — every preset applied, console clean, "
                  "all checked contrasts ≥ AA, tokens match the guide."]
    if sweep:
        label, palette, mode, rows = sweep
        broken = [r["page"] for r in rows if not r["bridge_ok"]]
        lines += [
            f"\n## Cross-page theme fidelity (T-2005) — preset {label} ({palette}/{mode})\n",
            "Headline mechanic: pick the theme once, re-load every page, observe it applied. "
            "`--pico-primary` must equal `--wt-accent` (pico-bridge) or that page's chrome ignores "
            "the palette.\n",
            "| Page | Bridge | Capture | --pico-primary | --wt-accent | --wt-bg |",
            "|------|--------|---------|----------------|-------------|---------|",
        ]
        for r in rows:
            mode = r.get("shot_mode", "full")
            h = r.get("shot_h", 0)
            cap = {
                "full": "full",
                "clipped": f"⚠️ clipped @{h}px",
                "viewport": "⚠️ viewport-only",
                "failed": "⚠️ **FAILED**",
            }.get(mode, mode)
            lines.append(
                f"| `{r['page']}` | {'✅ applied' if r['bridge_ok'] else '⚠️ **BROKEN**'} | "
                f"{cap} | `{r['pico']}` | `{r['wt']}` | `{r['bg']}` |"
            )
        lines.append(
            f"\n**{len(rows) - len(broken)}/{len(rows)} pages carry the theme.**"
            + (f" Broken: {', '.join('`'+b+'`' for b in broken)} — those pages' redesign "
               "slices (S2-S6) are the priority." if broken
               else " The headline mechanic holds across all swept pages.")
        )
    open(report_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


# --------------------------------------------------------------------------- #
def check_axes(base: str, page_path: str):
    """Smoke-test the Type and Density axes INDIVIDUALLY (not via presets).

    The preset-only capture (the main mode) masked T-2004: presets that vary
    type/density also vary palette, so a type/density that did nothing was hidden
    by the palette change. This clicks each Type and each Density option on its
    own and asserts a measurable visible effect:
      - Typography: rendered width of a fixed string in var(--wt-font-head) must
        differ across options (a font that doesn't load collapses to system-ui →
        identical width). Heading font is probed so serif pairings (newsreader,
        whose body stays sans) are still distinguished.
      - Density: computed body font-size must differ across compact/cozy/comfortable.
    """
    from playwright.sync_api import sync_playwright

    findings = []
    with sync_playwright() as p:
        b = p.chromium.launch(headless=True)
        pg = b.new_context(viewport={"width": 1440, "height": 1000}).new_page()
        pg.set_default_timeout(15000)
        pg.goto(base + "/")
        pg.goto(base + page_path, wait_until="load")
        types = pg.evaluate("() => Array.from(document.querySelectorAll('#wt-type button')).map(b=>b.dataset.value)")
        densities = pg.evaluate("() => Array.from(document.querySelectorAll('#wt-density button')).map(b=>b.dataset.value)")

        type_w = {}
        for t in types:
            pg.click(f'#wt-type button[data-value="{t}"]')
            try:
                pg.wait_for_function("(t)=>document.documentElement.getAttribute('data-wt-type')===t", arg=t, timeout=5000)
            except Exception:
                findings.append(f"Typography: clicking '{t}' did not set data-wt-type (dead control)")
            type_w[t] = pg.evaluate(
                "async()=>{await document.fonts.ready;"
                " const s=document.createElement('span');"
                " s.style.cssText='position:absolute;font-size:48px;white-space:nowrap;font-family:var(--wt-font-head)';"
                " s.textContent='Watchtower Handoff 12345'; document.body.appendChild(s);"
                " const w=s.offsetWidth; s.remove(); return w;}"
            )
        distinct = len(set(type_w.values()))
        if distinct < len(types):
            dupes = [t for t in type_w if list(type_w.values()).count(type_w[t]) > 1]
            findings.append(
                f"Typography: only {distinct}/{len(types)} options render a distinct typeface "
                f"(identical width: {dupes}) {type_w} — font(s) not loading, collapsing to fallback"
            )

        dens_sz = {}
        for d in densities:
            pg.click(f'#wt-density button[data-value="{d}"]')
            try:
                pg.wait_for_function("(d)=>document.documentElement.getAttribute('data-wt-density')===d", arg=d, timeout=5000)
            except Exception:
                findings.append(f"Density: clicking '{d}' did not set data-wt-density (dead control)")
            dens_sz[d] = pg.evaluate("()=>getComputedStyle(document.body).fontSize")
        if len(set(dens_sz.values())) < len(densities):
            findings.append(
                f"Density: options do not all change body size {dens_sz} — density tokens unconsumed"
            )
        b.close()

    status = "PASS" if not findings else "CONCERN"
    return status, findings, type_w, dens_sz


def _default_base():
    try:
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        out = subprocess.run(["bin/fw", "watchtower", "url"], cwd=root,
                             capture_output=True, text=True, timeout=10)
        url = out.stdout.strip().splitlines()[-1] if out.stdout.strip() else ""
        return url or "http://localhost:3000"
    except Exception:
        return "http://localhost:3000"


def main(argv=None):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap = argparse.ArgumentParser(description="UX-review capture engine (T-2002)")
    ap.add_argument("target", nargs="?", default=None,
                    help="convenience: a /path sets --page, a full URL sets --base")
    ap.add_argument("--base", default=None, help="base URL (default: bin/fw watchtower url)")
    ap.add_argument("--page", default="/settings/appearance", help="picker page path")
    ap.add_argument("--content-page", default="/tasks", help="content page to screenshot re-themed")
    ap.add_argument("--out", default="web/static/ux-review", help="output dir (under web/static to serve)")
    ap.add_argument("--report", default="docs/reports/T-2002-ux-review-arc-007-s0-s1.md")
    ap.add_argument("--axes", action="store_true",
                    help="smoke-test the Type and Density axes individually (not via presets)")
    ap.add_argument("--content-pages", default="",
                    help="comma-separated pages for the cross-page theme sweep "
                         "(headline mechanic); implies the sweep")
    ap.add_argument("--sweep", action="store_true",
                    help=f"run the cross-page theme sweep over {','.join(DEFAULT_SWEEP_PAGES)}")
    ap.add_argument("--all-routes", action="store_true",
                    help="height-check EVERY parameterless GET route from the app url_map "
                         "(exhaustive sweep — closes the 5-page detector gap, T-2042)")
    ap.add_argument("--sweep-preset", default=SWEEP_PRESET,
                    help="preset to apply for the cross-page sweep")
    args = ap.parse_args(argv)

    if args.target:  # positional convenience
        if args.target.startswith("/"):
            args.page = args.target
        elif args.target.startswith("http"):
            args.base = args.target

    base = (args.base or _default_base()).rstrip("/")

    if args.axes:
        status, findings, type_w, dens_sz = check_axes(base, args.page)
        print(f"[ux-review --axes] base={base} page={args.page}")
        print(f"[ux-review --axes] Typography widths: {type_w}")
        print(f"[ux-review --axes] Density body sizes: {dens_sz}")
        print(f"[ux-review --axes] verdict: {status}")
        for f in findings:
            print(f"  !! {f}")
        return 0 if status == "PASS" else 1
    out_dir = args.out if os.path.isabs(args.out) else os.path.join(root, args.out)
    report = args.report if os.path.isabs(args.report) else os.path.join(root, args.report)
    css = os.path.join(root, "web/static/css/foundations.css")

    print(f"[ux-review] base={base} page={args.page} out={out_dir}")
    guide = parse_foundations(css)
    print(f"[ux-review] loaded {len(guide)} palette/mode token sets from foundations.css")
    sweep_list = None
    if args.content_pages:
        sweep_list = [s.strip() for s in args.content_pages.split(",") if s.strip()]
    elif args.all_routes:
        try:
            sweep_list = discover_get_routes()
            print(f"[ux-review] --all-routes: discovered {len(sweep_list)} GET routes from url_map")
        except Exception as e:
            sweep_list = list(DEFAULT_SWEEP_PAGES)
            print(f"[ux-review] --all-routes discovery failed ({e}); "
                  f"falling back to {len(sweep_list)} default pages", file=sys.stderr)
    elif args.sweep:
        sweep_list = list(DEFAULT_SWEEP_PAGES)

    results = capture(base, args.page, args.content_page, out_dir, guide)
    sweep_data = None
    if sweep_list:
        print(f"[ux-review] cross-page sweep: preset={args.sweep_preset} pages={sweep_list}")
        sweep_data = sweep_pages(base, args.page, sweep_list, out_dir, guide, args.sweep_preset)
    gallery_path, verdict = write_gallery(results, out_dir, base, args.page, sweep_data)
    gallery_url = f"{base}/static/{os.path.relpath(gallery_path, os.path.join(root, 'web/static'))}"
    write_report(results, report, base, gallery_url, verdict, sweep_data)

    print(f"[ux-review] verdict: {verdict}")
    for r in results:
        flag = "ok " if r["status"] == "ok" else "!! "
        print(f"  {flag}{r['label']:<10} applied={r['applied']} console={'clean' if not r['errors'] else len(r['errors'])} findings={len(r['findings'])}")
    if sweep_data:
        label, palette, mode, rows = sweep_data
        print(f"[ux-review] cross-page sweep (preset {label}, {palette}/{mode}):")
        for r in rows:
            print(f"  {'ok ' if r['bridge_ok'] else '!! '}{r['page']:<12} "
                  f"pico={r['pico']} wt={r['wt']}")
    print(f"[ux-review] gallery: {gallery_url}")
    print(f"[ux-review] report:  {report}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
