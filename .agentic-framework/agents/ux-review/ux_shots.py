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
    fw ux shots T-XXX checked=@steps.yaml              (an interaction state, T-4391)

A steps file is a YAML list of single-op steps, executed here in order, nothing else:
    - goto: http://127.0.0.1:3000/map       # http, https or file; the list starts with one
    - click: "#check"
    - fill: {selector: "#q", text: "hello"}
    - press: Enter
    - hover: ".row"
    - wait-for: "#result"                   # a selector, or {text: "Done"}
      timeout: 5000                         # optional on any step, milliseconds
No other op and no other key is accepted, so a steps file can never carry code. Every
capture writes `.context/visual/<task>/<state>.capture.json` beside its PNGs: the source,
the steps file's sha256 and each shot's sha256, so a reviewer sees what produced each image.

Exit codes: 0 all shots written; 2 usage/config error; 3 NOT CHECKED
(Playwright or its browser unavailable — nothing was captured, nothing passed).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

DEFAULT_WIDTHS = (1024, 1440, 1920)
MIN_WIDTHS = 3
MIN_WIDTH_PX = 320
MAX_WIDTH_PX = 7680
VIEWPORT_HEIGHT = 1000

STEP_OPS = ("goto", "click", "fill", "press", "hover", "wait-for")
DEFAULT_STEP_TIMEOUT_MS = 10000
MAX_STEP_TIMEOUT_MS = 120000
MAX_STEPS = 100

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
    steps: tuple | None = None       # T-4391: validated steps for an interaction state
    steps_file: str = ""
    steps_sha256: str = ""


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


def _check_url(url: str) -> str:
    if urlparse(url).scheme not in ("http", "https", "file"):
        raise PlanError(f"URL {url!r} must be http, https or file")
    return url


def _text(op: str, i: int, v) -> str:
    if not isinstance(v, str) or not v.strip():
        raise PlanError(f"step {i} ({op}) needs a non-empty string, got {v!r}")
    return v


def _step(i: int, raw) -> dict:
    """One validated step: {'op', <args>, 'timeout'}. Anything outside STEP_OPS is refused."""
    if not isinstance(raw, dict):
        raise PlanError(f"step {i} must be a mapping like `- click: \"#id\"`, got {raw!r}")
    ops = [k for k in raw if k in STEP_OPS]
    unknown = [k for k in raw if k not in STEP_OPS and k != "timeout"]
    if unknown and not ops:
        raise PlanError(f"step {i}: {unknown[0]!r} is not an allowed step ({', '.join(STEP_OPS)})")
    if unknown:
        raise PlanError(f"step {i}: unknown key {unknown[0]!r} (only the op and `timeout`)")
    if len(ops) != 1:
        raise PlanError(f"step {i} must name exactly one op, got {ops or 'none'}")
    op, v = ops[0], raw[ops[0]]
    st: dict = {"op": op}
    if op == "goto":
        st["url"] = _check_url(_text(op, i, v))
    elif op in ("click", "hover"):
        st["selector"] = _text(op, i, v)
    elif op == "press":
        st["key"] = _text(op, i, v)
    elif op == "fill":
        if not isinstance(v, dict) or set(v) != {"selector", "text"} or not isinstance(v["text"], str):
            raise PlanError(f"step {i} (fill) needs {{selector: ..., text: ...}}, got {v!r}")
        st["selector"], st["text"] = _text(op, i, v["selector"]), v["text"]
    else:  # wait-for: a selector, or {selector: ...} / {text: ...}
        if isinstance(v, dict):
            if len(v) != 1 or next(iter(v)) not in ("selector", "text"):
                raise PlanError(f"step {i} (wait-for) takes a selector or exactly one of "
                                f"{{selector: ...}} / {{text: ...}}, got {v!r}")
            k = next(iter(v))
            st[k] = _text(op, i, v[k])
        else:
            st["selector"] = _text(op, i, v)
    if "timeout" in raw:
        t = raw["timeout"]
        if isinstance(t, bool) or not isinstance(t, int) or not 0 < t <= MAX_STEP_TIMEOUT_MS:
            raise PlanError(f"step {i} timeout {t!r} must be an integer 1..{MAX_STEP_TIMEOUT_MS} ms")
        st["timeout"] = t
    return st


def load_steps(path: Path) -> list[dict]:
    """Parse and validate a steps file (YAML or JSON). A bad file is a PlanError, never run."""
    try:
        import yaml
        doc = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    except OSError as exc:
        raise PlanError(f"steps file {str(path)!r} cannot be read ({exc.strerror or exc})") from exc
    except Exception as exc:  # noqa: BLE001 - yaml.YAMLError and friends
        raise PlanError(f"steps file {str(path)!r} is not valid YAML ({exc})") from exc
    if not isinstance(doc, list):
        raise PlanError(f"steps file {str(path)!r} must be a list of steps")
    if not doc:
        raise PlanError(f"steps file {str(path)!r} has no steps")
    if len(doc) > MAX_STEPS:
        raise PlanError(f"steps file {str(path)!r} has {len(doc)} steps (max {MAX_STEPS})")
    steps = [_step(i, raw) for i, raw in enumerate(doc, 1)]
    if steps[0]["op"] != "goto":
        raise PlanError(f"steps file {str(path)!r} must start with goto (the page the state is on)")
    return steps


def parse_target(arg: str) -> tuple[str, str]:
    """`state=URL`, `state=@steps.yaml`, or a bare URL / `@steps.yaml` (state from the stem)."""
    # `state=` only when the text before the first '=' is not part of a URL scheme/host.
    if "=" in arg and "://" not in arg.split("=", 1)[0] and not arg.startswith("@"):
        state, url = arg.split("=", 1)
    else:
        url = arg
        state = Path(url[1:]).stem if url.startswith("@") else _state_from_url(url)
    if not url.startswith("@"):
        _check_url(url)
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
        steps, steps_file, digest = None, "", ""
        if url.startswith("@"):
            f = Path(url[1:])
            steps = tuple(load_steps(f))
            digest = hashlib.sha256(f.read_bytes()).hexdigest()
            steps_file, url = _rel(f, root), steps[0]["url"]
        for w in widths:
            shots.append(Shot(state, url, w, shot_path(root, task, state, w), steps, steps_file, digest))
    return shots


def _rel(path: Path, root: Path) -> str:
    try:
        return str(Path(path).resolve().relative_to(Path(root).resolve()))
    except ValueError:
        return str(Path(path).resolve())


def manifest_path(root: Path, task: str, state: str) -> Path:
    """Per-state capture record beside the PNGs: <root>/.context/visual/<task>/<state>.capture.json"""
    return Path(root) / ".context" / "visual" / validate_task(task) / f"{validate_state(state)}.capture.json"


def write_manifests(shots: list[Shot], root: Path, task: str) -> list[Path]:
    """One manifest per state: what produced its images (URL or hashed steps) and each shot's hash."""
    by_state: dict[str, list[Shot]] = {}
    for s in shots:
        by_state.setdefault(s.state, []).append(s)
    out = []
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for state, group in by_state.items():
        first = group[0]
        rec = {"task": task, "state": state, "source": "steps" if first.steps else "url",
               "url": first.url, "widths": [s.width for s in group],
               "shots": [{"width": s.width, "path": _rel(s.path, root),
                          "sha256": hashlib.sha256(s.path.read_bytes()).hexdigest()} for s in group],
               "ts": ts}
        if first.steps:
            rec.update(steps_file=first.steps_file, steps_sha256=first.steps_sha256,
                       steps=list(first.steps))
        m = manifest_path(root, task, state)
        m.write_text(json.dumps(rec, indent=2) + "\n", encoding="utf-8")
        out.append(m)
    return out


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


def run_steps(page, steps) -> None:
    """Drive `page` through validated steps. A failing step is NotChecked, naming the step."""
    for i, st in enumerate(steps, 1):
        op, t = st["op"], st.get("timeout", DEFAULT_STEP_TIMEOUT_MS)
        arg = st.get("url") or st.get("selector") or st.get("key") or st.get("text")
        try:
            if op == "goto":
                page.goto(st["url"], wait_until="load", timeout=t)
            elif op == "click":
                page.click(st["selector"], timeout=t)
            elif op == "fill":
                page.fill(st["selector"], st["text"], timeout=t)
            elif op == "press":
                page.keyboard.press(st["key"])
            elif op == "hover":
                page.hover(st["selector"], timeout=t)
            elif "text" in st:
                page.get_by_text(st["text"]).first.wait_for(state="visible", timeout=t)
            else:
                page.wait_for_selector(st["selector"], state="visible", timeout=t)
        except Exception as exc:  # noqa: BLE001 - timeout, missing element, navigation error
            raise NotChecked(f"step {i} ({op} {arg!r}) failed: {str(exc).splitlines()[0][:200]}") from exc


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
                    if shot.steps:
                        run_steps(page, shot.steps)
                    else:
                        page.goto(shot.url, wait_until="load")
                    shot.path.parent.mkdir(parents=True, exist_ok=True)
                    page.screenshot(path=str(shot.path), full_page=True)
                    written.append(shot.path)
                finally:
                    ctx.close()
        except NotChecked:
            for f in written:          # a state that failed part-way leaves none of this run's shots
                f.unlink(missing_ok=True)
            raise
        finally:
            browser.close()
    return written


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="fw ux shots",
        description="Screenshot each state at every configured width into .context/visual/<task>/ (T-4212)",
    )
    ap.add_argument("task", help="task id, e.g. T-4212 (names the .context/visual/<task>/ folder)")
    ap.add_argument("targets", nargs="+",
                    help="state=URL, state=@steps.yaml, URL or @steps.yaml (state from file stem / last path segment)")
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
        write_manifests(shots, Path(args.root), args.task)
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
