#!/usr/bin/env python3
"""fw ux shots — capture every named state at every configured width (T-4212).

T-4202 GO convention: a render-surface change is screenshotted at >=3 widths
per touched state, into `.context/visual/<task>/<state>@<width>.png`. The
checklist in `## Visual Verification` then reads each shot control by control.

Why a separate verb and not a flag on `ux-review`: ux-review is a palette and
theme engine (picker pages, guide coherence, report/gallery writers under
web/static). This verb only answers "what did every width look like", and
its planning half is pure so it is tested without a browser.

Usage:
    fw ux shots T-XXX toolbar=http://127.0.0.1:3000/tasks/T-1 [more state=URL ...]
    fw ux shots T-XXX file:///abs/page.html            (state name from the file stem)

Exit codes: 0 all shots written; 2 usage/config error; 3 NOT CHECKED
(Playwright or its browser unavailable — nothing was captured, nothing passed).
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

DEFAULT_WIDTHS = (1024, 1440, 1920)
MIN_WIDTHS = 3
MIN_WIDTH_PX = 320
MAX_WIDTH_PX = 7680
VIEWPORT_HEIGHT = 1000

TASK_RE = re.compile(r"^T-\d+$")
STATE_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")

EXIT_OK = 0
EXIT_USAGE = 2
EXIT_NOT_CHECKED = 3


class PlanError(ValueError):
    """Bad widths, task id, state name or URL. Message is shown to the operator."""


class NotChecked(RuntimeError):
    """Capture could not run here. The shot is NOT CHECKED, not passed."""


@dataclass(frozen=True)
class Shot:
    state: str
    url: str
    width: int
    path: Path


def parse_widths(raw: str | None) -> list[int]:
    """Parse a comma-separated width list. Empty/None falls back to the default.

    Validation: integers only, each within [MIN_WIDTH_PX, MAX_WIDTH_PX], no
    duplicates, and at least MIN_WIDTHS entries (T-4202: >=3 widths per state).
    """
    if raw is None or not str(raw).strip():
        return list(DEFAULT_WIDTHS)
    parts = [p.strip() for p in str(raw).split(",")]
    widths: list[int] = []
    for p in parts:
        if not p.isdigit():
            raise PlanError(f"UX_SHOT_WIDTHS entry {p!r} is not an integer width (value: {raw!r})")
        w = int(p)
        if not MIN_WIDTH_PX <= w <= MAX_WIDTH_PX:
            raise PlanError(f"UX_SHOT_WIDTHS entry {w} outside {MIN_WIDTH_PX}..{MAX_WIDTH_PX}")
        if w in widths:
            raise PlanError(f"UX_SHOT_WIDTHS repeats width {w} (value: {raw!r})")
        widths.append(w)
    if len(widths) < MIN_WIDTHS:
        raise PlanError(
            f"UX_SHOT_WIDTHS has {len(widths)} width(s); T-4202 requires at least {MIN_WIDTHS} "
            f"(value: {raw!r}, default {','.join(map(str, DEFAULT_WIDTHS))})"
        )
    return widths


def validate_task(task: str) -> str:
    if not TASK_RE.match(task or ""):
        raise PlanError(f"task id {task!r} must look like T-NNNN")
    return task


def validate_state(state: str) -> str:
    if not STATE_RE.match(state or ""):
        raise PlanError(
            f"state name {state!r} must be lowercase letters, digits, '-' or '_' "
            "(it becomes the file name)"
        )
    return state


def shot_path(root: Path, task: str, state: str, width: int) -> Path:
    """Convention path: <root>/.context/visual/<task>/<state>@<width>.png"""
    return Path(root) / ".context" / "visual" / validate_task(task) / f"{validate_state(state)}@{width}.png"


def parse_target(arg: str) -> tuple[str, str]:
    """`state=URL` or a bare URL (state taken from the file stem or host+path slug)."""
    # `state=` only when the text before the first '=' is not part of a URL scheme/host.
    if "=" in arg and "://" not in arg.split("=", 1)[0]:
        state, url = arg.split("=", 1)
    else:
        url = arg
        state = _state_from_url(url)
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https", "file"):
        raise PlanError(f"URL {url!r} must be http, https or file")
    return validate_state(state), url


def _state_from_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme == "file":
        stem = Path(parsed.path).stem
    else:
        stem = (parsed.path.rstrip("/").split("/")[-1] or parsed.hostname or "page")
    slug = re.sub(r"[^a-z0-9_-]+", "-", stem.lower()).strip("-_")
    return slug or "page"


def plan(targets: list[str], widths: list[int], root: Path, task: str) -> list[Shot]:
    """Every (state, width) pair gets exactly one planned shot, in target order."""
    validate_task(task)
    if not targets:
        raise PlanError("no targets: give at least one state=URL or URL")
    shots: list[Shot] = []
    seen: set[str] = set()
    for t in targets:
        state, url = parse_target(t)
        if state in seen:
            raise PlanError(f"state {state!r} given twice; state names must be unique per task")
        seen.add(state)
        for w in widths:
            shots.append(Shot(state, url, w, shot_path(root, task, state, w)))
    return shots


def _require_playwright():
    try:
        from playwright.sync_api import sync_playwright  # noqa: F401
    except ImportError as exc:
        raise NotChecked(
            "Playwright is not installed in this interpreter "
            f"({exc}). Install it (pip install playwright && playwright install chromium) "
            "or capture on a host that has it."
        ) from exc
    return sync_playwright


def capture(shots: list[Shot]) -> list[Path]:
    """Screenshot each planned shot with a fresh viewport per width. Returns written paths."""
    sync_playwright = _require_playwright()
    written: list[Path] = []
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch()
        except Exception as exc:  # missing browser binary, sandbox refusal, ...
            raise NotChecked(f"Chromium could not launch ({exc}). Run `playwright install chromium`.") from exc
        try:
            for shot in shots:
                ctx = browser.new_context(viewport={"width": shot.width, "height": VIEWPORT_HEIGHT})
                try:
                    page = ctx.new_page()
                    page.goto(shot.url, wait_until="load")
                    shot.path.parent.mkdir(parents=True, exist_ok=True)
                    page.screenshot(path=str(shot.path), full_page=True)
                    written.append(shot.path)
                finally:
                    ctx.close()
        finally:
            browser.close()
    return written


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="fw ux shots",
        description="Screenshot each state at every configured width into .context/visual/<task>/ (T-4212)",
    )
    ap.add_argument("task", help="task id, e.g. T-4212 (names the .context/visual/<task>/ folder)")
    ap.add_argument("targets", nargs="+", help="state=URL or URL (state from file stem / last path segment)")
    ap.add_argument("--widths", default=os.environ.get("FW_UX_SHOT_WIDTHS"),
                    help="comma-separated widths; default UX_SHOT_WIDTHS config, else 1024,1440,1920")
    ap.add_argument("--root", default=os.environ.get("PROJECT_ROOT") or os.getcwd(),
                    help="project root that receives .context/visual/ (default PROJECT_ROOT)")
    ap.add_argument("--plan-only", action="store_true",
                    help="print the planned paths and exit without launching a browser")
    args = ap.parse_args(argv)

    try:
        widths = parse_widths(args.widths)
        shots = plan(args.targets, widths, Path(args.root), args.task)
    except PlanError as exc:
        print(f"fw ux shots: {exc}", file=sys.stderr)
        return EXIT_USAGE

    if args.plan_only:
        for s in shots:
            print(s.path)
        return EXIT_OK

    try:
        written = capture(shots)
    except NotChecked as exc:
        print(f"fw ux shots: NOT CHECKED — {exc}", file=sys.stderr)
        print("fw ux shots: no screenshot was written; a reviewer must not read this as a pass.", file=sys.stderr)
        return EXIT_NOT_CHECKED

    for path in written:
        print(path)
    print(f"fw ux shots: {len(written)} shot(s) — {len(args.targets)} state(s) x {len(widths)} width(s)")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
