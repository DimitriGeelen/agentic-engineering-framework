"""T-5293 (T-5290 GO, G-136): a mechanical check of each `verdict/1` vote against what it cites.

Slice 1 (lib/verdict_format.py) checks a vote's FORM. This module checks whether the evidence the
vote names is THERE: the quoted text is in the file at the line it names (or elsewhere in that
file, or nowhere); the line exists; the image exists and the region lies inside it (and the crop
of that region is written beside the seat's evidence so other seats and the operator can see
it); a selector is named; a rule is given; the overall vote agrees with the criterion votes; and,
for a vote citing an image, whether the seat's own run record shows it opened that image with an
image-viewing tool.

It does NOT judge whether the conclusion follows from the evidence (1409 caveat b), it runs no
command (a `command:` location is reported "not checkable"), and it never decides whether a vote
counts: `checkable(row)` (T-5294) only reads a recorded check and names why a vote fails it;
the ledger decides that such a vote counts neither green nor red. "Cannot tell" is always
reported as such, never as yes.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import struct
import subprocess
from pathlib import Path

CHECKER = "vote-check/1"
REPORT_DIR = ".context/reviews/evidence"   # same as verdict_ledger.REPORT_DIR
#: Evidence (captures, seat copies, crops) lives here, is written during the review and committed
#: with the verdict, so it is read from the working tree even when git tracks it by now.
EVIDENCE_DIRS = (REPORT_DIR + "/", ".context/working/", ".context/visual/")
IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")
GREEN = "green"

_QUOTE_RE = re.compile(r'^(?:"(.+)"|“(.+)”|„(.+)[“”"])$', re.S)
_REGION_RE = re.compile(r"region[ \t]+(\d+)[ \t]*,[ \t]*(\d+)[ \t]*,[ \t]*(\d+)[ \t]*,[ \t]*(\d+)")
_SELECTOR_RE = re.compile(r"selector[ \t]+(\S.*)$", re.S)
_IMG_EVIDENCE_RE = re.compile(r"^image:[ \t]*(\S+)[ \t]+(.+)$", re.S)
_IMG_LOC_RE = re.compile(r"^(\S+)[ \t]+((?:region|selector)[ \t].+)$", re.S)
_FILE_LINE_RE = re.compile(r"^(\S+):(\d+)(?:-(\d+))?$")
_COMMAND_RE = re.compile(r"^command:[ \t]*(\S.*)$", re.S)
_RULE_QUOTE_RE = re.compile(r'"([^"]{3,})"|“([^”]{3,})”')


def _ws(s: str) -> str:
    return re.sub(r"\s+", " ", s or "").strip()


# ── reading files at the reviewed revision ────────────────────────────────────────────────────

def _git(root: Path, *args: str) -> tuple[int, bytes]:
    try:
        p = subprocess.run(["git", *args], cwd=str(root), capture_output=True, timeout=30)
        return p.returncode, p.stdout
    except (OSError, subprocess.SubprocessError):
        return 1, b""


def _rel(root: Path, path: str, extra_roots: list[Path]) -> str:
    """A cited path as root-relative: absolute paths under root or a seat's tree are reduced."""
    p = path.strip().strip("`").removeprefix("./")
    if os.path.isabs(p):
        for base in [root, *extra_roots]:
            try:
                return str(Path(p).resolve().relative_to(Path(base).resolve()))
            except (ValueError, OSError):
                continue
        m = re.search(r"/tree/(.+)$", p)        # a seat's export tree: /tmp/tl-dispatch/<id>/tree/…
        if m:
            return m.group(1)
    return p


def read_cited(root: Path, revision: str, path: str, extra_roots: list[Path] | None = None
               ) -> tuple[bytes | None, str]:
    """(bytes, source) of a cited file: the reviewed revision's blob when git tracks it there;
    else, only for a file git does not track at that revision (a capture, a seat's copy), the
    working tree under root or a seat's tree. (None, why) when it is nowhere."""
    extra = [Path(r) for r in (extra_roots or [])]
    rel = _rel(Path(root), path, extra)
    if revision:
        rc, out = _git(Path(root), "cat-file", "-e", f"{revision}:{rel}")
        if rc == 0:
            rc, out = _git(Path(root), "show", f"{revision}:{rel}")
            if rc == 0:
                return out, f"revision {revision[:12]}"
    rc, _ = _git(Path(root), "ls-files", "--error-unmatch", "--", rel)
    if rc == 0 and revision and not rel.startswith(EVIDENCE_DIRS):
        # git tracks it now but not at the reviewed revision: the reviewed files did not have it.
        return None, f"{rel} is not in revision {revision[:12]} (tracked only later)"
    for base in [Path(root), *extra]:
        f = base / rel
        if f.is_file():
            try:
                return f.read_bytes(), ("working tree" if base == Path(root) else f"seat tree {base}")
            except OSError as e:
                return None, f"{rel} unreadable: {e}"
    where = f"revision {revision[:12]} or the working tree" if revision else "the working tree"
    return None, f"{rel} is not in {where}"


# ── quotes and file:line locations ────────────────────────────────────────────────────────────

def _unescape(s: str) -> str:
    """Undo the escapes a reviewer uses inside a double-quoted Evidence: \\" -> ", \\\\ -> \\."""
    out, i = [], 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s) and s[i + 1] in ('"', "\\"):
            out.append(s[i + 1])
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def check_quote(quote: str, location: str, root: Path, revision: str,
                extra_roots: list[Path] | None = None) -> dict:
    """A quoted Evidence paired with its Location. `quote`: found-at-location / found-elsewhere /
    not-found (verbatim), and separately the same with whitespace normalised; `location`: exists
    (file present and the line range inside it) or not."""
    res: dict = {"kind": "quote", "quote": quote[:200], "location": location}
    cm = _COMMAND_RE.match(location.strip())
    if cm:
        res.update(result="not-checkable", location_exists=None,
                   why="command output: the checker runs no command")
        return res
    fm = _FILE_LINE_RE.match(location.strip())
    if not fm:
        res.update(result="location-mismatch", location_exists=None,
                   why="a quote needs a `<path>:<line>` or `command:` location")
        return res
    path, a = fm.group(1), int(fm.group(2))
    b = int(fm.group(3)) if fm.group(3) else a
    data, src = read_cited(root, revision, path, extra_roots)
    res["path"], res["lines"], res["source"] = path, [a, b], src
    if data is None:
        res.update(location_exists=False, result="not-found", why=src)
        return res
    text = data.decode("utf-8", errors="replace")
    lines = text.split("\n")
    if text.endswith("\n"):
        lines = lines[:-1]
    res["location_exists"] = 1 <= a <= b <= len(lines)
    if not res["location_exists"]:
        res["why"] = f"{path} has {len(lines)} line(s); {a}-{b} is outside it"
    at = "\n".join(lines[a - 1:b]) if res["location_exists"] else ""
    # T-5308: a reviewer quoting text that contains double quotes writes them as \" inside the
    # quoted Evidence (T-5303's review: web/app.py:252). When the quote as written is not in
    # the file but its unescaped form is, match the unescaped form and say so.
    unesc = _unescape(quote)
    if unesc != quote and quote not in text and unesc in text:
        res["unescaped"] = True
        quote = unesc
    if res["location_exists"] and quote in at:
        res["result"] = "found-at-location"
    elif quote in text:
        res["result"] = "found-elsewhere"
        pos = text.index(quote)
        res["found_at_line"] = text.count("\n", 0, pos) + 1
    else:
        res["result"] = "not-found"
    nq = _ws(quote)
    if nq and res["location_exists"] and nq in _ws(at):
        res["normalised"] = "found-at-location"
    elif nq and nq in _ws(text):
        res["normalised"] = "found-elsewhere"
    else:
        res["normalised"] = "not-found"
    return res


# ── images ────────────────────────────────────────────────────────────────────────────────────

def image_size(data: bytes) -> tuple[int, int] | None:
    """(width, height) of an image: PIL when available, else the PNG header."""
    try:
        from io import BytesIO

        from PIL import Image
        with Image.open(BytesIO(data)) as im:
            return int(im.size[0]), int(im.size[1])
    except Exception:  # noqa: BLE001 — fall back to the header, else unknown
        pass
    if data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR":
        w, h = struct.unpack(">II", data[16:24])
        return int(w), int(h)
    return None


def _write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = f"{path}.tmp.{os.getpid()}-{os.urandom(4).hex()}"
    try:
        with open(tmp, "wb") as fh:
            fh.write(data)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def write_crop(data: bytes, region: tuple[int, int, int, int], image_name: str, out_dir: Path,
               root: Path) -> tuple[str, str]:
    """Crop `region` (x, y, w, h) of the image and write it as PNG into `out_dir` as
    `<stem>-<x>_<y>_<w>_<h>-crop.png`. An existing crop with other bytes is never overwritten:
    the new one gets a content hash in its name. Returns (root-relative path, '') or ('', why)."""
    try:
        from io import BytesIO

        from PIL import Image
    except ImportError:
        return "", "PIL is not available: no crop written"
    x, y, w, h = region
    try:
        with Image.open(BytesIO(data)) as im:
            crop = im.crop((x, y, x + w, y + h))
            buf = BytesIO()
            crop.save(buf, format="PNG")
    except Exception as e:  # noqa: BLE001
        return "", f"crop failed: {e}"
    png = buf.getvalue()
    stem = Path(image_name).stem
    dst = out_dir / f"{stem}-{x}_{y}_{w}_{h}-crop.png"
    if dst.exists() and dst.read_bytes() != png:
        dst = out_dir / f"{stem}-{x}_{y}_{w}_{h}-{hashlib.sha256(png).hexdigest()[:8]}-crop.png"
    if not (dst.exists() and dst.read_bytes() == png):
        _write_atomic(dst, png)
    try:
        return str(dst.resolve().relative_to(Path(root).resolve())), ""
    except ValueError:
        return str(dst), ""


def _location_agrees(img: str, spec: str, lm) -> bool:
    return bool(lm and Path(lm.group(1)).name == Path(img).name and _ws(lm.group(2)) == _ws(spec))


_TASK_ID_RE = re.compile(r"T-\d+")


def seat_copy_path(name: str, task: str, root, dispatch_id: str | None = None) -> str | None:
    """T-5375: `.context/reviews/evidence/<task>/<name>` for a BARE image name that is a seat's
    per-seat screenshot copy the judge placed there (`<stem>-<dispatch id>.<ext>`; with the
    seat's dispatch id known, exactly that id) and that exists inside that directory. None for
    anything else: a name with a directory part or `..`, a non-image, another task's directory,
    a missing file, or a symlink leading out of the directory."""
    if (not root or not name or "/" in name or "\\" in name or name in (".", "..")
            or not _TASK_ID_RE.fullmatch(str(task or "")) or not _is_image(name)):
        return None
    stem = Path(name).stem.lower()
    if dispatch_id:
        if not stem.endswith("-" + dispatch_id.lower()) or len(stem) <= len(dispatch_id) + 1:
            return None
    elif not any(DISPATCH_ID_RE.fullmatch(stem[i + 1:]) for i, ch in enumerate(stem) if ch == "-"):
        return None
    base = Path(root) / REPORT_DIR / task
    f = base / name
    try:
        if not f.is_file() or f.resolve().parent != base.resolve():
            return None
    except OSError:
        return None
    return f"{REPORT_DIR}/{task}/{name}"


def _resolve_image(img: str, spec: str, lm, *, task: str = "", root=None,
                   dispatch_id: str | None = None) -> str:
    """T-5357: the path an Evidence image is read from — a bare file name resolves through an
    agreeing Location's path; T-5375: a bare name whose Location is bare too (or absent) resolves
    to the seat's copy in the task's evidence directory when it is there (seat_copy_path);
    anything else is itself."""
    if "/" in img:
        return img
    if _location_agrees(img, spec, lm) and Path(lm.group(1)).name == img and lm.group(1) != img:
        return lm.group(1)
    return seat_copy_path(img, task, root, dispatch_id) or img


def cited_image_path(evidence: str, location: str, *, task: str = "", root=None,
                     dispatch_id: str | None = None) -> str | None:
    """T-5360: the resolved path an `image:` Evidence (with its Location) cites; None if malformed."""
    em = _IMG_EVIDENCE_RE.match(str(evidence).strip())
    if not em:
        return None
    return _resolve_image(em.group(1), em.group(2).strip(), _IMG_LOC_RE.match(str(location).strip()),
                          task=task, root=root, dispatch_id=dispatch_id)


def check_image(evidence: str, location: str, root: Path, revision: str, *, task: str,
                extra_roots: list[Path] | None = None, views: dict | None = None,
                views_known: bool = False, write_crops: bool = True,
                cited: list[str] | None = None, dispatch_id: str | None = None) -> dict:
    """An `image:` Evidence paired with its Location: image exists; region inside it (and crop
    written) or selector named; location names the same image and region; seat viewed it."""
    em = _IMG_EVIDENCE_RE.match(evidence.strip())
    res: dict = {"kind": "image", "evidence": evidence, "location": location}
    if not em:
        res.update(result="malformed")
        return res
    img, spec = em.group(1), em.group(2).strip()
    res["image"] = img
    lm = _IMG_LOC_RE.match(location.strip())
    res["location_agrees"] = _location_agrees(img, spec, lm)
    resolved = _resolve_image(img, spec, lm, task=task, root=root, dispatch_id=dispatch_id)
    if resolved != img:
        # T-5357: a bare file name in Evidence is read through the agreeing Location's path
        # (same file name, same region/selector); reads, crops and the seat-viewed check use it.
        # T-5375: or, with a bare Location, from the seat's copy in the task's evidence dir.
        res["cited_name"] = img
        res["resolved_via"] = ("seat-copy" if resolved == seat_copy_path(img, task, root, dispatch_id)
                               else "location")
        img = resolved
        res["image"] = img
    data, src = read_cited(root, revision, img, extra_roots)
    res["image_exists"], res["source"] = data is not None, src
    rm, sm = _REGION_RE.search(spec), _SELECTOR_RE.search(spec)
    if rm:
        x, y, w, h = (int(v) for v in rm.groups())
        res["region"] = [x, y, w, h]
        size = image_size(data) if data is not None else None
        res["size"] = list(size) if size else None
        if data is None:
            res["region_inside"] = None
        elif size is None:
            res["region_inside"] = None
            res["why"] = "image size could not be read"
        else:
            res["region_inside"] = w > 0 and h > 0 and x + w <= size[0] and y + h <= size[1]
            if res["region_inside"] and write_crops:
                out_dir = Path(root) / REPORT_DIR / (task or "_unknown")
                crop, why = write_crop(data, (x, y, w, h), img, out_dir, Path(root))
                res["crop"] = crop or None
                if why:
                    res["crop_why"] = why
    elif sm:
        res["selector"] = sm.group(1).strip()
        res["selector_named"] = bool(res["selector"])
    sha = hashlib.sha256(data).hexdigest() if data is not None else None
    _bytes: dict = {}

    def read(p):                             # T-5358: a logged view's file, as read for this check
        if p not in _bytes:
            _bytes[p] = read_cited(root, revision, p, extra_roots)[0]
        return _bytes[p]

    res["seat_viewed"] = image_viewed(views, img, sha, cited, read=read) if views_known else None
    if views_known and views and sha and sha in (views.get("__attached_sha256__") or ()):
        res["seat_viewed_how"] = "attached at launch (T-5309)"
    if res["seat_viewed"] is True:
        # T-5327: which proof shows the view — a logged view event (Read / read_file / codex's
        # image tool) or only the attached-images.json manifest (in the prompt, not proof the
        # model looked).
        logged = logged_views(views)
        res["view_proof"] = "logged" if image_viewed(logged, img, sha, cited, read=read) else "attached"
        if res["view_proof"] == "logged" and image_viewed(logged, img, None, cited) is not True:
            res["viewed_same_bytes_as"] = _content_view(logged, sha, read)
    if views_known and views is None:
        res["seat_viewed_why"] = "the seat's run record cannot tell"
    elif not views_known:
        res["seat_viewed_why"] = "no seat run record given"
    res["result"] = "ok" if (res["image_exists"] and res.get("region_inside", True) is not False
                             and res["location_agrees"]) else "problem"
    return res


# ── what the seat's run record shows it opened ────────────────────────────────────────────────

#: codex `exec --json` item types that carry no image view.
_CODEX_PLAIN = {"command_execution", "agent_message", "reasoning", "file_change", "todo_list",
                "web_search", "error"}
#: codex item types that are an image view (codex's own image tool).
_CODEX_VIEW = {"view_image", "image_view", "view_image_tool_call", "image"}
#: opencode tools that do not show the model an image (`read` does, for an image file).
_OPENCODE_PLAIN = {"bash", "glob", "grep", "list", "ls", "write", "edit", "patch", "todowrite",
                   "todoread", "webfetch", "task", "multiedit"}
#: claude tools that do not show the model a file's image (`Read` does, for an image file).
_CLAUDE_PLAIN = {"Bash", "Glob", "Grep", "LS", "Write", "Edit", "MultiEdit", "NotebookEdit",
                 "TodoWrite", "WebFetch", "WebSearch", "Task", "Agent", "ToolSearch", "Skill"}

#: antigravity (`--output-format stream-json`, T-5309) tools that open a file for the model;
#: for an image file that is the image (T-4944: its read_file opens images).
_AGY_VIEW = {"read_file", "view_file"}
#: antigravity tools that show the model no image.
_AGY_PLAIN = {"run_command", "list_dir", "find_by_name", "grep_search", "command_status",
              "send_command_input", "write_to_file", "replace_file_content",
              "multi_replace_file_content", "sed_file", "finish", "wait", "wait_5_seconds",
              "ask_question", "ask_permission", "ask_custom_permission", "list_permissions",
              "search_web", "read_url_content", "manage_task", "manage_inbox", "notebook_edit"}
#: T-5309: written beside the run record by the review runtime when it attached images at launch.
ATTACHED_MANIFEST = "attached-images.json"

_IMG_NAME_RE = re.compile(r"[\w@.\-]+\.(?:png|jpe?g|gif|webp|bmp)", re.I)


def _is_image(p: str) -> bool:
    return str(p).lower().endswith(IMAGE_EXTS)


def _record_file(path) -> Path | None:
    p = Path(path)
    if p.is_dir():
        p = p / "result.jsonl"
    return p if p.is_file() else None


def attached_images(record) -> list[dict] | None:
    """T-5309: the images the runtime attached to the seat at launch (`codex exec -i`), from
    `attached-images.json` in the dispatch dir; None when there is no such manifest."""
    if not record:
        return None
    p = Path(record)
    d = p if p.is_dir() else p.parent
    try:
        m = json.loads((d / ATTACHED_MANIFEST).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if not isinstance(m, dict) or not isinstance(m.get("attached"), list):
        return None
    # T-5324: an image the manifest lists as not attached (over the cap, comma in path) is never
    # counted attached, even when a malformed manifest also lists it under `attached`.
    na = [a for a in (m.get("not_attached") or []) if isinstance(a, dict)]
    na_paths = {str(a.get("path")) for a in na if a.get("path")}
    na_shas = {str(a.get("sha256")) for a in na if a.get("sha256")}
    return [a for a in m["attached"] if isinstance(a, dict)
            and str(a.get("path")) not in na_paths and str(a.get("sha256")) not in na_shas]


def seat_viewed_images(record) -> dict | None:
    """Images a seat's run record shows it opened with an image-viewing tool.

    `record`: a result.jsonl, or a dispatch dir holding one. Returns {image path: True}
    for an image viewed; {path: None} for an image named by an event the reader does not
    understand (cannot tell); an image absent from the dict was not viewed. T-5333 (G-137): keys
    are the path as the record gives it (attached images: the evidence-relative manifest path;
    logged views: the path the tool was given), never reduced to the basename, so a view of
    `a/screen.png` is not a view of `b/screen.png`. Every image path the manifest names
    (attached or not) is listed under '__cited_paths__' so image_viewed can tell when a
    basename-only view is ambiguous. Returns None when
    the record is missing or in no known shape (cannot tell at all — e.g. antigravity, which
    left only its final text before T-5309). T-5309: images the runtime attached at launch
    (`attached-images.json` beside the record) count as viewed, by name and by content hash
    (key '__attached_sha256__'); antigravity's stream-json read_file/view_file steps count. Shell commands that touch an image (`cp`, `ls`, a python one-
    liner) are not image views: they show the model no pixels. Their names are listed under the
    key '__named_in_commands__' (informative only)."""
    f = _record_file(record) if record else None
    attached = attached_images(record)
    if f is None and attached is None:
        return None
    raw: list[str] = []
    if f is not None:
        try:
            raw = f.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            if attached is None:
                return None
    out: dict = {}
    did = dispatch_id_of(record)
    if did:
        out["__dispatch_id__"] = did
    named: set[str] = set()
    known = attached is not None
    if attached is not None:                 # T-5309: in the initial prompt by construction
        shas = sorted({str(a.get("sha256")) for a in attached if a.get("sha256")})
        for a in attached:
            if a.get("path") and _is_image(str(a["path"])):
                out[_norm_path(a["path"])] = True
        out["__attached_sha256__"] = shas
    cited = _manifest_paths(record)
    if cited:
        out["__cited_paths__"] = cited

    logged: set[str] = set()

    def mark(paths, val):
        for p in paths:
            if p and _is_image(str(p)):
                n = _norm_path(p)
                if val is True:
                    logged.add(n)            # T-5327: a view event in the log itself
                if out.get(n) is not True:
                    out[n] = val

    for line in raw:
        try:
            e = json.loads(line)
        except (ValueError, TypeError):
            continue
        if not isinstance(e, dict):
            continue
        item = e.get("item")
        part = e.get("part")
        msg = e.get("message")
        if "event" in e and isinstance(e.get("event"), str):               # antigravity stream-json
            known = True
            su = e.get("step_update") if e.get("event") == "step_update" else None
            if not isinstance(su, dict) or su.get("step_type") != "tool":
                continue
            tool = str(su.get("tool_name") or (su.get("tool_info") or {}).get("name") or "")
            params = ((su.get("tool_info") or {}).get("parameters")) or {}
            if not isinstance(params, dict):
                params = {}
            if tool in _AGY_VIEW:
                for k in ("Path", "AbsolutePath", "path", "file_path", "FilePath"):
                    if params.get(k) and _is_image(str(params[k])):
                        mark([str(params[k])], True)
            elif tool == "run_command":
                named.update(_IMG_NAME_RE.findall(json.dumps(params)))
            elif tool not in _AGY_PLAIN:
                mark(_IMG_NAME_RE.findall(json.dumps(params)), None)
        elif isinstance(item, dict) and "type" in item:                     # codex
            known = True
            t = str(item.get("type"))
            blob = json.dumps(item)
            if t in _CODEX_VIEW or (t == "mcp_tool_call" and "image" in str(item.get("tool", "")).lower()):
                mark([item.get("path"), item.get("image_path"), *(_IMG_NAME_RE.findall(blob))], True)
            elif t == "command_execution":
                named.update(_IMG_NAME_RE.findall(str(item.get("command", ""))))
            elif t not in _CODEX_PLAIN:
                mark(_IMG_NAME_RE.findall(blob), None)
        elif isinstance(part, dict) and part.get("type") == "tool":          # opencode
            known = True
            tool = str(part.get("tool", ""))
            inp = ((part.get("state") or {}).get("input")) or {}
            if tool == "read":
                fp = str(inp.get("filePath") or inp.get("path") or "")
                if _is_image(fp):
                    mark([fp], True)
            elif tool == "bash":
                named.update(_IMG_NAME_RE.findall(str(inp.get("command", ""))))
            elif tool not in _OPENCODE_PLAIN:
                mark(_IMG_NAME_RE.findall(json.dumps(inp)), None)
        elif isinstance(part, dict) and "type" in part:
            known = True                                                     # opencode text/step
        elif isinstance(msg, dict) and e.get("type") in ("assistant", "user"):  # claude stream-json
            known = True
            if e.get("type") != "assistant":
                continue
            for c in msg.get("content") or []:
                if not isinstance(c, dict) or c.get("type") != "tool_use":
                    continue
                name, inp = str(c.get("name", "")), c.get("input") or {}
                if name == "Read":
                    fp = str(inp.get("file_path") or "")
                    if _is_image(fp):
                        mark([fp], True)
                elif name == "Bash":
                    named.update(_IMG_NAME_RE.findall(str(inp.get("command", ""))))
                elif name not in _CLAUDE_PLAIN:
                    mark(_IMG_NAME_RE.findall(json.dumps(inp)), None)
        elif e.get("type") in ("system", "result", "thread.started", "turn.started",
                               "turn.completed", "turn.failed", "error", "rate_limit_event"):
            known = True
    if not known:
        return None
    if named:
        out["__named_in_commands__"] = sorted(named)
    out["__logged__"] = sorted(logged)
    return out


def logged_views(views: dict | None) -> dict | None:
    """T-5327: `views` (seat_viewed_images) reduced to the images a logged view event shows the
    seat opened — the attached-at-launch entries and content hashes dropped. A views dict from
    before T-5327 (no '__logged__' key) is taken as all-logged only when it has no attached
    hashes; otherwise nothing in it is known to be logged."""
    if views is None:
        return None
    if "__logged__" in views:
        keep = set(views.get("__logged__") or ())
    elif views.get("__attached_sha256__"):
        keep = set()
    else:
        keep = {k for k in views if not k.startswith("__")}
    out = {k: v for k, v in views.items()
           if k.startswith("__") and k not in ("__attached_sha256__", "__logged__")}
    out.update({k: True for k in keep})
    return out


#: T-5324: a review dispatch id. `fw termlink dispatch --task-type review` appends 12 lowercase hex
#: (`od -An -N6 -tx1 /dev/urandom`, agents/termlink/termlink.sh) to the caller's name, e.g.
#: `judge-t-5316-r3-5d23083a1e03`. A seat's copy of a cited screenshot is `<stem>-<dispatch id>`
#: (judge brief: `<name>-$FW_SIDECAR_AGENT_ID.png`; verdict_ledger._freeze_seat_evidence).
DISPATCH_ID_RE = re.compile(r"[a-z0-9][a-z0-9._-]*-[0-9a-f]{12}")


def dispatch_id_of(record) -> str | None:
    """The dispatch id a seat record belongs to: its dispatch dir's name, when it has the shape."""
    if not record:
        return None
    p = Path(record)
    d = p if p.is_dir() else p.parent
    n = d.name.lower()
    return n if DISPATCH_ID_RE.fullmatch(n) else None


def _stem_match(a: str, b: str, dispatch_id: str | None = None) -> bool:
    """Same image: equal stems, or one is the other plus `-<dispatch id>` (a seat's copy), in
    either direction. T-5324 (G-137): any other suffix is a different image — `01-x-listeners`
    is not `01-x`. With the seat's own dispatch id known, the suffix must be exactly that id;
    otherwise it must have the dispatch-id shape (DISPATCH_ID_RE)."""
    a, b = Path(a).stem.lower(), Path(b).stem.lower()
    if a == b:
        return True
    long, short = (a, b) if len(a) > len(b) else (b, a)
    if not long.startswith(short + "-"):
        return False
    suffix = long[len(short) + 1:]
    if dispatch_id:
        return suffix == dispatch_id.lower()
    return bool(DISPATCH_ID_RE.fullmatch(suffix))


def _norm_path(p) -> str:
    """A path as a comparable string: forward slashes, no leading `./`, no repeated slashes."""
    s = str(p).replace("\\", "/")
    while s.startswith("./"):
        s = s[2:]
    return re.sub(r"/{2,}", "/", s)


def _parts(p) -> list[str]:
    return [x for x in _norm_path(p).lower().split("/") if x and x != "."]


def _evidence_rel(p) -> str | None:
    """The evidence-relative path a recorded view identifies, or None when it identifies only a
    basename. A relative path with a directory is taken as given (manifest paths are
    evidence-relative); an absolute path is identified from its last `.context` component on
    (`/x/wdir/tree/.context/working/…` → `.context/working/…`). A bare name, or an absolute path
    outside `.context`, identifies no evidence path."""
    s = _norm_path(p)
    parts = _parts(s)
    if not s.startswith("/"):
        return "/".join(parts) if len(parts) > 1 else None
    if ".context" in parts:
        i = len(parts) - 1 - parts[::-1].index(".context")
        return "/".join(parts[i:])
    return None


def _ends_with(p, q) -> bool:
    a, b = _parts(p), _parts(q)
    return bool(b) and a[-len(b):] == b


def _manifest_paths(record) -> list[str]:
    """Every image path the seat's attached-images.json names, attached or not (T-5333)."""
    if not record:
        return []
    p = Path(record)
    d = p if p.is_dir() else p.parent
    try:
        m = json.loads((d / ATTACHED_MANIFEST).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    if not isinstance(m, dict):
        return []
    got = []
    for key in ("attached", "not_attached"):
        for a in m.get(key) or []:
            if isinstance(a, dict) and a.get("path") and _is_image(str(a["path"])):
                got.append(_norm_path(a["path"]))
    return list(dict.fromkeys(got))


def _view_hit(key: str, image: str, cited: list[str], did: str | None):
    """Does a recorded view `key` show `image`? Returns (matched, by_path).

    By path (T-5333, G-137): the view names the cited path itself (equal evidence-relative path,
    or a path ending with it). A view that names a DIFFERENT cited path with the same basename
    is not a view of this one. Otherwise, basename-only: same name, or the seat's copy
    `<stem>-<dispatch id>` (a copy's name carries no source directory)."""
    kn, iname = Path(key).name.lower(), Path(image).name.lower()
    same = kn == iname
    copy = not same and _stem_match(key, image, did)
    if not (same or copy):
        return False, False
    if same:
        rel = _evidence_rel(key)
        img_parts = _parts(image)
        if len(img_parts) <= 1:                       # cited by bare name: the name is all we have
            return True, True
        if rel is not None:
            return _ends_with(rel, image) or _ends_with(image, rel), True
        if _ends_with(key, image):
            return True, True
        if any(_ends_with(key, c) for c in cited if _norm_path(c).lower() != _norm_path(image).lower()):
            return False, True                        # it is another cited image of that name
    return True, False


def _content_view(views: dict | None, sha256: str | None, read) -> str | None:
    """T-5358: the first LOGGED view (views['__logged__'], via logged_views) whose file, as
    `read(path)` returns it for this check, has sha256 `sha256`; None when there is none. Only
    logged view events count: attached-at-launch entries are never hashed here (T-5327), and no
    hash the seat itself wrote is trusted."""
    if not sha256 or read is None:
        return None
    for k, v in (logged_views(views) or {}).items():
        if k.startswith("__") or v is not True:
            continue
        try:
            data = read(k)
        except Exception:  # noqa: BLE001 — an unreadable view is simply no match
            data = None
        if data is not None and hashlib.sha256(data).hexdigest() == sha256:
            return k
    return None


def image_viewed(views: dict | None, image: str, sha256: str | None = None,
                 cited: list[str] | None = None, read=None) -> bool | None:
    """True / False / None (cannot tell) for one cited image.

    T-5309: True when the cited image's content hash is one the runtime attached at launch (a
    copy has a new name but the same bytes). T-5333 (G-137): otherwise a view counts only when
    it names this image's path, or the seat's own copy `<stem>-<dispatch id>` of it (T-5324: no
    other suffix; the seat's own id when the record names it, key '__dispatch_id__'). The same
    basename in another directory never counts. A view that gives only a basename (a bare name,
    a copy, a path outside `.context`) counts when that basename is unique among the cited
    images (`cited`, plus the manifest's '__cited_paths__'); when two cited images share it,
    the answer is None (cannot tell which), never True. T-5358: with `read` (path -> bytes, the
    file as read for the check), a LOGGED view of any file whose sha256 equals the cited
    image's (`sha256`) is a view of it — same bytes, same pixels — whatever the names say."""
    if views is None:
        return None
    if sha256 and sha256 in (views.get("__attached_sha256__") or ()):
        return True
    did = views.get("__dispatch_id__")
    all_cited = list(dict.fromkeys(
        [_norm_path(c) for c in (cited or [])] + list(views.get("__cited_paths__") or [])
        + [_norm_path(image)]))
    hits = []
    for k, v in views.items():
        if k.startswith("__"):
            continue
        matched, by_path = _view_hit(k, image, all_cited, did)
        if not matched:
            continue
        if by_path:
            hits.append(v)
            continue
        # basename-only: which cited images could this view be?
        could = {c.lower() for c in all_cited if _view_hit(k, c, all_cited, did)[0]}
        hits.append(v if len(could) <= 1 else (None if v is not False else v))
    if True in hits:
        return True
    if _content_view(views, sha256, read) is not None:
        return True
    if None in hits:
        return None
    return False


# ── the whole vote ────────────────────────────────────────────────────────────────────────────

def _criteria(vote: dict) -> tuple[dict, dict]:
    """(header, {ac: criterion}) from a full parse_vote result or a one-criterion structure."""
    if "criteria" in vote:
        return vote.get("header") or {}, {int(k): v for k, v in (vote.get("criteria") or {}).items()}
    if "criterion" in vote:
        return vote.get("header") or {}, {int(vote.get("ac") or 0): vote.get("criterion") or {}}
    return {}, {}


def _rule_check(rule: str, criterion_text: str | None) -> dict:
    r: dict = {"present": bool((rule or "").strip())}
    q = [a or b for a, b in _RULE_QUOTE_RE.findall(rule or "")]
    if q:
        r["quoted"] = q[0][:200]
        r["quote_in_criterion"] = (None if criterion_text is None
                                   else _ws(q[0]).lower() in _ws(criterion_text).lower())
    return r


def _image_location(quote: str, location: str, ev: list, loc: list, root: Path, revision: str, *,
                    task: str, extra_roots: list[Path], dispatch_id: str | None) -> dict | None:
    """T-5375: a quote whose Location is `<image> region|selector …` — text read off a screenshot.
    Counted as an image location only when the same criterion also cites that image with the same
    region/selector as an `image:` Evidence (so the image, its region and the seat's view are
    checked there) and the image is there; the text itself is not checkable (no OCR). None when the
    Location is not of that shape or no `image:` Evidence agrees: check_quote then refuses it as
    today."""
    lm = _IMG_LOC_RE.match(location.strip())
    if not lm or not _is_image(lm.group(1)) or _FILE_LINE_RE.match(location.strip()):
        return None
    agreeing = None
    for i, e in enumerate(ev):
        em = _IMG_EVIDENCE_RE.match(str(e).strip())
        if em and _location_agrees(em.group(1), em.group(2).strip(), lm):
            agreeing = cited_image_path(e, str(loc[i]) if i < len(loc) else "", task=task,
                                        root=root, dispatch_id=dispatch_id)
            break
    if agreeing is None:
        return None
    data, src = read_cited(root, revision, agreeing, extra_roots)
    res: dict = {"kind": "quote", "quote": quote[:200], "location": location, "path": agreeing,
                 "source": src, "image_location": True, "location_exists": data is not None,
                 "result": "not-checkable",
                 "why": "text read from an image region: the checker reads no text from pixels; "
                        "the image, region and seat view are checked by its image: evidence"}
    if data is None:
        res["why"] = src
    return res


def check_vote(parsed_vote: dict, root, revision: str, seat_record=None, *, task: str = "",
               criterion_text: str | None = None, extra_roots: list | None = None,
               write_crops: bool = True) -> dict:
    """Check a parsed `verdict/1` vote (verdict_format.parse_vote's result, or one criterion's
    `structure`) against the reviewed revision's files. Returns per-item results; never raises
    for a fault in what the vote cites. `seat_record`: the seat's result.jsonl or dispatch dir
    (None: seat-viewed is not checked and says so)."""
    root = Path(root)
    header, crits = _criteria(parsed_vote)
    task = task or str(header.get("task") or "")
    extra = [Path(r) for r in (extra_roots or [])]
    if seat_record:
        sr = Path(seat_record)
        d = sr if sr.is_dir() else sr.parent
        if (d / "tree").is_dir():
            extra.append(d / "tree")
    views = seat_viewed_images(seat_record) if seat_record else None
    did = dispatch_id_of(seat_record)
    out: dict = {"checker": CHECKER, "revision": revision, "criteria": {}}
    if seat_record:
        out["seat_record"] = str(seat_record)
        out["seat_record_readable"] = views is not None
        if views and views.get("__named_in_commands__"):
            out["images_named_in_commands"] = views["__named_in_commands__"]

    # complete: every criterion has the required labels (slice 1 refuses otherwise; re-stated).
    missing = {ac: [lab for lab in ("vote", "evidence", "location", "rule", "conclusion")
                    if not c.get(lab)] for ac, c in crits.items()}
    for ac, c in crits.items():
        if c.get("vote") and c.get("vote") != GREEN and not c.get("guidance"):
            missing[ac].append("guidance")
    out["complete"] = bool(crits) and not any(missing.values())
    if any(missing.values()):
        out["incomplete"] = {str(a): m for a, m in missing.items() if m}

    # consistent: overall vote vs criterion votes vs failed (as far as this vote shows them).
    overall = str(header.get("vote") or "")
    failed = sorted(int(x) for x in header.get("failed") or [])
    nongreen = sorted(ac for ac, c in crits.items() if c.get("vote") != GREEN)
    why = []
    if "criteria" in parsed_vote:
        if (overall == GREEN) != (not nongreen):
            why.append(f"overall {overall} vs non-green criteria {nongreen}")
        if failed != nongreen:
            why.append(f"failed {failed} vs non-green criteria {nongreen}")
    else:                                    # one criterion of a vote: check what it can show
        for ac, c in crits.items():
            v = c.get("vote")
            if v == GREEN and ac in failed:
                why.append(f"AC{ac} green but listed in failed {failed}")
            if v != GREEN and ac not in failed:
                why.append(f"AC{ac} {v} but not listed in failed {failed}")
            if v != GREEN and overall == GREEN:
                why.append(f"overall green while AC{ac} is {v}")
    out["consistent"] = not why
    if why:
        out["inconsistent"] = why

    any_image = False
    cited_images = []                         # T-5333: every image the vote cites
    for c in crits.values():                  # T-5360: once each, by its resolved path
        ev, loc = list(c.get("evidence") or []), list(c.get("location") or [])
        for i, e in enumerate(ev):
            p = cited_image_path(e, str(loc[i]) if i < len(loc) else "", task=task, root=root,
                                 dispatch_id=did)
            if p is not None and _norm_path(p) not in {_norm_path(x) for x in cited_images}:
                cited_images.append(p)
    for ac, c in crits.items():
        items = []
        ev, loc = list(c.get("evidence") or []), list(c.get("location") or [])
        for i, e in enumerate(ev):
            e = str(e).strip()
            l_ = str(loc[i]).strip() if i < len(loc) else ""
            try:
                qm = _QUOTE_RE.match(e)
                if qm:
                    q = next(g for g in qm.groups() if g is not None)
                    img_loc = _image_location(q, l_, ev, loc, root, revision, task=task,
                                              extra_roots=extra, dispatch_id=did)
                    items.append(img_loc or check_quote(q, l_, root, revision, extra))
                elif e.startswith("image:"):
                    any_image = True
                    items.append(check_image(e, l_, root, revision, task=task, extra_roots=extra,
                                             views=views, views_known=bool(seat_record),
                                             write_crops=write_crops, cited=cited_images,
                                             dispatch_id=did))
                else:
                    items.append({"kind": "unknown", "evidence": e[:200], "result": "malformed"})
            except Exception as exc:  # noqa: BLE001 — one item's fault never sinks the check
                items.append({"kind": "error", "evidence": e[:200], "error": f"{type(exc).__name__}: {exc}"})
        out["criteria"][str(ac)] = {"vote": c.get("vote"), "items": items,
                                    "rule": _rule_check(str(c.get("rule") or ""), criterion_text)}
    out["cites_image"] = any_image
    return out


def crops(check: dict | None) -> list[str]:
    """The crop files a check result names (root-relative), for committing with the row."""
    got = []
    for c in ((check or {}).get("criteria") or {}).values():
        for it in c.get("items") or []:
            if it.get("crop"):
                got.append(it["crop"])
    return list(dict.fromkeys(got))


def safe_check(*args, **kw) -> dict:
    """check_vote that never raises: an internal failure is recorded as {'error': …}."""
    try:
        return check_vote(*args, **kw)
    except Exception as exc:  # noqa: BLE001
        return {"checker": CHECKER, "error": f"{type(exc).__name__}: {exc}"}


# ── T-5294: does a recorded vote hold up to its own check? ────────────────────────────────────

FORMAT = "verdict/1"   # verdict_format.FORMAT (not imported: this module stays import-light)


def _found(item: dict) -> bool:
    """A quote is found when it is in the cited file, verbatim or with whitespace normalised."""
    return (item.get("result") in ("found-at-location", "found-elsewhere")
            or item.get("normalised") in ("found-at-location", "found-elsewhere"))


#: T-5327 (R-040): the reason a render vote in a single-seat run is not checkable.
ATTACHED_ONLY = ("attached-only proof: a render vote in a single-seat run needs a seat that "
                 "logged a view (T-5327)")


def view_proof(item: dict) -> str | None:
    """T-5327: 'logged' / 'attached' for an image item the seat viewed, None otherwise. A check
    recorded before T-5327 has no `view_proof`: a view shown by the attached manifest is then
    'attached' (whether a log also showed it was not recorded), any other view 'logged'."""
    if not isinstance(item, dict) or item.get("seat_viewed") is not True:
        return None
    if item.get("view_proof") in ("logged", "attached"):
        return item["view_proof"]
    return "attached" if item.get("seat_viewed_how") else "logged"


def attached_only_reasons(check, *, render: bool = False, panel: bool = False) -> list[str]:
    """T-5327: [reason] per criterion of `check` whose cited images are ALL viewed and every one
    proven only by the attached manifest — when the criterion is a render criterion (`render`)
    and the vote is not a rung-5 panel seat (`panel`). [] otherwise: a panel is unchanged, a
    non-render criterion is unaffected, and one logged view is enough."""
    if not render or panel or not isinstance(check, dict):
        return []
    out = []
    crits = check.get("criteria")
    for ac, c in sorted((crits if isinstance(crits, dict) else {}).items(), key=lambda kv: str(kv[0])):
        imgs = [it for it in ((c if isinstance(c, dict) else {}).get("items") or [])
                if isinstance(it, dict) and it.get("kind") == "image"]
        proofs = [view_proof(it) for it in imgs]
        if imgs and all(p == "attached" for p in proofs):
            out.append(f"AC{ac}: {ATTACHED_ONLY}")
    return out


def check_reasons(check, *, render: bool = False, panel: bool = False) -> list[str]:
    """Every reason the recorded `check` of a verdict/1 vote shows it is NOT checkable ([] when it
    is). Not checkable: the check is missing or errored; a cited quote is not in the file; a cited
    location does not exist; an image is missing, its region is outside it (or its size cannot be
    read), or the location names another image or region; an evidence line is malformed; for a
    vote citing an image, the seat's run record does not show it opened that image ("cannot tell"
    is not "opened"); the rule is missing; the vote is incomplete or inconsistent. A `command:`
    location is never run and is not a reason by itself (the checker cannot tell either way)."""
    if not isinstance(check, dict) or not check:
        return ["no check recorded"]
    if check.get("error"):
        return [f"the check errored: {check['error']}"]
    out: list[str] = []
    if check.get("complete") is False:
        inc = check.get("incomplete") or {}
        out.append("incomplete vote" + (f" ({'; '.join(f'AC{a}: ' + ', '.join(m) for a, m in inc.items())})"
                                         if inc else ""))
    if check.get("consistent") is False:
        out.append("inconsistent vote: " + "; ".join(check.get("inconsistent") or ["?"]))
    crits = check.get("criteria")
    if not isinstance(crits, dict) or not crits:
        out.append("the check names no criterion")
        return out
    for ac, c in sorted(crits.items(), key=lambda kv: str(kv[0])):
        c = c if isinstance(c, dict) else {}
        if not (c.get("rule") or {}).get("present"):
            out.append(f"AC{ac}: rule missing")
        for it in c.get("items") or []:
            it = it if isinstance(it, dict) else {}
            kind = it.get("kind")
            if kind == "quote":
                where = it.get("location") or "?"
                if it.get("result") == "location-mismatch":
                    out.append(f"AC{ac}: location {where!r} is neither path:line nor command:")
                    continue
                if it.get("location_exists") is False:
                    out.append(f"AC{ac}: location {where} does not exist"
                               + (f" ({it['why']})" if it.get("why") else ""))
                if it.get("result") != "not-checkable" and not _found(it):
                    out.append(f"AC{ac}: quote {str(it.get('quote', ''))[:60]!r} not found in "
                               f"{it.get('path') or where}")
            elif kind == "image":
                img = it.get("image") or it.get("evidence") or "?"
                if it.get("result") == "malformed":
                    out.append(f"AC{ac}: malformed image evidence {str(it.get('evidence', ''))[:60]!r}")
                    continue
                if not it.get("image_exists"):
                    out.append(f"AC{ac}: image {img} missing")
                elif it.get("region") is not None and it.get("region_inside") is not True:
                    out.append(f"AC{ac}: region {','.join(map(str, it['region']))} "
                               + ("outside" if it.get("region_inside") is False
                                  else "cannot be placed in") + f" image {img}")
                if it.get("location_agrees") is False:
                    out.append(f"AC{ac}: location {it.get('location')!r} does not name image {img} "
                               f"and the same region")
                seen = it.get("seat_viewed")
                if seen is not True:
                    out.append(f"AC{ac}: seat did not open image {img}" if seen is False else
                               f"AC{ac}: cannot tell whether the seat opened image {img}"
                               + (f" ({it['seat_viewed_why']})" if it.get("seat_viewed_why") else ""))
            elif kind == "error":
                out.append(f"AC{ac}: the check errored on an evidence item: {it.get('error', '?')}")
            else:
                out.append(f"AC{ac}: malformed evidence {str(it.get('evidence', ''))[:60]!r}")
    return out + attached_only_reasons(check, render=render, panel=panel)


def is_panel_row(row) -> bool:
    """T-5327: is this row a seat of a rung-5 panel (its recorded rung)?"""
    return isinstance(row, dict) and str(row.get("rung") or "").startswith("rung-5")


def checkable(row, *, render: bool = False) -> tuple[bool, list[str]]:
    """(True, []) when a recorded ledger row's vote holds up to its own mechanical check, else
    (False, reasons). Rows without `format: verdict/1` (old free-text rows) are always (True, [])
    — they are counted exactly as before. A not-evaluated row has no vote to check.
    `render` (T-5327): the row's criterion needs a proven view of screenshots; then, unless the
    row is a rung-5 panel seat, a vote whose every cited image is proven only by "attached at
    launch" is not checkable (ATTACHED_ONLY). T-5353: callers pass `lib/evidence_need.py`'s test
    (render, or names a page), the one the judge uses, via `verdict_ledger._needs_view`."""
    if not isinstance(row, dict) or row.get("format") != FORMAT:
        return True, []
    if row.get("outcome") == "not-evaluated":
        return True, []
    why = check_reasons(row.get("check"), render=render, panel=is_panel_row(row))
    return (not why), why
