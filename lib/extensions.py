#!/usr/bin/env python3
"""Project extensions register (T-5259, T-4649 slice 0).

Operator principle (T-4649 GO, 2026-11-19): any modification of the framework
in a project is allowed when it is that project's operator's recorded decision,
listed by `fw audit`, and kept intact by `fw upgrade`.

The register is `.framework-extensions.yaml` at the PROJECT ROOT -- project-owned,
outside the vendored `.agentic-framework/` tree, so `fw vendor` / `fw upgrade`
never write it. Shape:

    extensions:
      - id: approvals-ui
        kind: vendored-override
        paths: ["web/blueprints/approvals.py"]
        markers: []               # vendored-override only: in-file block markers
        words: "keep our approval page, we own it"
        decided_by: operator
        date: "2026-11-19"

Kinds: vendored-override (a file, or an in-file block when markers are given,
under .agentic-framework/), and the kinds later slices use: page, nav,
csrf-exemption, event-hook, reviewer-brief, gate-check (T-5260..T-5265).

csrf-exemption (T-5262): endpoints the project authenticates itself, exempted
from Watchtower's form-safety (CSRF) check. Two extra fields, required for this
kind and refused on every other:

      - id: approvals-tap
        kind: csrf-exemption
        paths: ["approvals.tap_decide", "blueprint:vpn_proxy"]   # endpoint names,
                                  # or every endpoint of one blueprint
        auth: "bearer"            # or "header:X-Ring20-Key" -- the credential
                                  # the endpoint checks itself
        test: "tests/test_tap_auth.py"   # the project's test that proves it
        words: "tap links carry an HMAC bearer token"
        decided_by: operator
        date: "2026-11-20"

    fw extension add csrf-exemption approvals-tap --path approvals.tap_decide \
        --auth bearer --test tests/test_tap_auth.py --words "..."

Watchtower honours an entry only after a startup probe (web/project_extensions.py
`probe_csrf_exemptions`): every state-changing URL rule of each endpoint must
answer 401 or 403 both without the credential and with a wrong one. What it
applied, refused and could not find is written to the Watchtower state file
under `csrf`; `fw audit` FAILs on a refused or missing endpoint and on a missing
test file, and WARNs while Watchtower has not checked the entry yet.

Protection is NOT a second mechanism: a vendored-override entry is mirrored into
`.fwvendor-preserve.yaml` (lib/vendor_preserve.py, T-3850/T-4870) as `files:`
items (whole file) or `in_file:` items (markers), each carrying
`extension: <id>`. Removal deletes only items carrying that id, so hand-written
preserve entries are never touched.

CLI (routed by `fw extension`):
    add <kind> <id> --path P [--path P2] [--marker M] --words "..." [--by NAME]
    remove <id> --words "..."
    list [--json]
    audit                     # TSV lines LEVEL<TAB>title<TAB>evidence<TAB>mitigation
    web-status                # the page/nav part of audit alone (fw doctor, T-5260)
    kept --target DIR         # what fw vendor/upgrade prints after the copy

add/remove are the operator's: refused under $CLAUDECODE=1 unless --i-am-human,
which is logged to .context/working/.gate-bypass-log.yaml.
"""

import argparse
import datetime
import fnmatch
import glob as globmod
import hashlib
import json
import os
import re
import sys

REGISTER = ".framework-extensions.yaml"
PRESERVE = ".fwvendor-preserve.yaml"
STAMP = ".fw-vendor-stamp.json"
VENDOR_DIR = ".agentic-framework"
HISTORY = os.path.join(".context", "project", "extension-decisions.jsonl")
KINDS = ("vendored-override", "page", "nav", "csrf-exemption", "event-hook",
         "reviewer-brief", "gate-check")
FIELDS = ("id", "kind", "paths", "markers", "auth", "test", "words", "decided_by", "date")
CSRF_KIND = "csrf-exemption"
AUTH_RE = re.compile(r"^(bearer|header:[A-Za-z0-9-]+)$")
ENDPOINT_RE = re.compile(r"^(blueprint:[A-Za-z0-9_.-]+|[A-Za-z0-9_][A-Za-z0-9_.-]*)$")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
HEADER = (
    "# Project extensions register (T-5259). Project-owned: fw vendor / fw upgrade\n"
    "# never write this file. Entries are the project operator's recorded decisions,\n"
    "# added and removed with `fw extension add|remove` (operator-only). Listed by\n"
    "# `fw extension list` and `fw audit`.\n")


class ExtensionError(Exception):
    pass


def _now_date():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")


def _now_ts():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def strip_vendor(p):
    p = str(p).strip()
    while p.startswith("./"):
        p = p[2:]
    if p.startswith(VENDOR_DIR + "/"):
        p = p[len(VENDOR_DIR) + 1:]
    return p.rstrip("/")


# ------------------------------------------------------------------ yaml io

def _yaml_load(text):
    try:
        import yaml  # noqa: WPS433
    except ImportError:
        return _mini_load(text)
    return yaml.safe_load(text)


def _mini_load(text):
    """Fallback for hosts without PyYAML: reads the shape `save` writes."""
    entries, cur = [], None
    for raw in text.splitlines():
        s = raw.strip()
        if not s or s.startswith("#") or s == "extensions:" or s == "extensions: []":
            continue
        if s.startswith("- "):
            cur = {}
            entries.append(cur)
            s = s[2:]
        if cur is None or ":" not in s:
            continue
        k, v = s.split(":", 1)
        v = v.strip()
        cur[k.strip()] = json.loads(v) if v[:1] in '"[{' else v
    return {"extensions": entries}


def _emit(entries):
    out = [HEADER, "extensions:" + (" []" if not entries else "")]
    for e in entries:
        first = True
        for k in FIELDS:
            if k not in e:
                continue
            if k == "markers" and not e[k]:
                continue
            line = f"{k}: {json.dumps(e[k], ensure_ascii=False)}"
            out.append(("  - " if first else "    ") + line)
            first = False
    return "\n".join(out) + "\n"


def register_path(root):
    return os.path.join(root, REGISTER)


def load(root):
    """List of validated entries, in file order. Missing register -> []."""
    path = register_path(root)
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    try:
        data = _yaml_load(text) or {}
    except Exception as exc:  # noqa: BLE001 - any parse error is a broken register
        raise ExtensionError(f"{REGISTER} does not parse: {exc}")
    if not isinstance(data, dict) or not isinstance(data.get("extensions") or [], list):
        raise ExtensionError(f"{REGISTER} must be a mapping with an `extensions:` list")
    entries = data.get("extensions") or []
    seen = set()
    for i, e in enumerate(entries):
        validate(e, where=f"{REGISTER} entry {i + 1}")
        if e["id"] in seen:
            raise ExtensionError(f"{REGISTER}: duplicate id {e['id']!r}")
        seen.add(e["id"])
    return entries


def validate(e, where="entry"):
    if not isinstance(e, dict):
        raise ExtensionError(f"{where}: must be a mapping")
    for k in ("id", "kind", "paths", "words", "decided_by", "date"):
        if e.get(k) in (None, "", []):
            raise ExtensionError(f"{where}: missing {k}")
    if not ID_RE.match(str(e["id"])):
        raise ExtensionError(f"{where}: id {e['id']!r} must match {ID_RE.pattern}")
    if e["kind"] not in KINDS:
        raise ExtensionError(f"{where}: kind {e['kind']!r} not one of {', '.join(KINDS)}")
    if not isinstance(e["paths"], list) or not all(isinstance(p, str) and p.strip() for p in e["paths"]):
        raise ExtensionError(f"{where}: paths must be a non-empty list of strings")
    for p in e["paths"]:
        if os.path.isabs(p) or ".." in p.split("/"):
            raise ExtensionError(f"{where}: path {p!r} must be relative, without '..'")
    markers = e.get("markers") or []
    if not isinstance(markers, list) or not all(isinstance(m, str) and m for m in markers):
        raise ExtensionError(f"{where}: markers must be a list of strings")
    if markers and e["kind"] != "vendored-override":
        raise ExtensionError(f"{where}: markers apply to vendored-override only")
    if e["kind"] == CSRF_KIND:
        for k in ("auth", "test"):
            if not isinstance(e.get(k), str) or not e[k].strip():
                raise ExtensionError(f"{where}: csrf-exemption needs {k} "
                                     "(auth: bearer | header:<Name>; test: the proving test file)")
        if not AUTH_RE.match(e["auth"]):
            raise ExtensionError(f"{where}: auth {e['auth']!r} must be `bearer` or `header:<Name>` "
                                 "(Name: letters, digits, -)")
        t = e["test"]
        if os.path.isabs(t) or ".." in t.split("/"):
            raise ExtensionError(f"{where}: test {t!r} must be relative, without '..'")
        for p in e["paths"]:
            if not ENDPOINT_RE.match(p):
                raise ExtensionError(f"{where}: path {p!r} must be an endpoint name (bp.view) "
                                     "or blueprint:<name>")
    else:
        for k in ("auth", "test"):
            if k in e:
                raise ExtensionError(f"{where}: {k} applies to csrf-exemption only")
    unknown = set(e) - set(FIELDS)
    if unknown:
        raise ExtensionError(f"{where}: unknown field(s) {', '.join(sorted(unknown))}")
    return e


def save(root, entries):
    for i, e in enumerate(entries):
        validate(e, where=f"entry {i + 1}")
    path = register_path(root)
    tmp = f"{path}.tmp.{os.getpid()}-{os.urandom(4).hex()}"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(_emit(entries))
    os.replace(tmp, path)


# ------------------------------------------------------ preserve mirroring

def _mirror_items(e):
    """Preserve-manifest items (section, lines) for a vendored-override entry."""
    eid = json.dumps(e["id"])
    items = []
    for p in e["paths"]:
        rel = json.dumps(strip_vendor(p))
        if e.get("markers"):
            body = [f"- file: {rel}", f"  markers: {json.dumps(e['markers'], ensure_ascii=False)}",
                    f"  extension: {eid}"]
            items.append(("in_file", body))
        else:
            items.append(("files", [f"- path: {rel}", f"  extension: {eid}"]))
    return items


def _top_key(line):
    m = re.match(r"^([A-Za-z_][\w-]*):(.*)$", line)
    return (m.group(1), m.group(2).split(" #", 1)[0].strip()) if m else (None, None)


def _section_bounds(lines, name):
    """(header_idx, end_idx) of a top-level section, or None."""
    for i, ln in enumerate(lines):
        k, _ = _top_key(ln)
        if k == name:
            j = i + 1
            while j < len(lines):
                if lines[j].strip() and not lines[j][0].isspace() and not lines[j].startswith("-") \
                        and not lines[j].lstrip().startswith("#"):
                    break
                j += 1
            return i, j
    return None


def _items(lines, start, end):
    """Item spans [(s, e)] in a sequence section between start (exclusive) and end."""
    dash = [i for i in range(start + 1, end) if re.match(r"^\s*- ", lines[i]) or lines[i].strip() == "-"]
    if not dash:
        return [], None
    indent = len(lines[dash[0]]) - len(lines[dash[0]].lstrip())
    starts = [i for i in dash if len(lines[i]) - len(lines[i].lstrip()) == indent]
    spans = []
    for n, s in enumerate(starts):
        e = starts[n + 1] if n + 1 < len(starts) else end
        while e > s + 1 and not lines[e - 1].strip():
            e -= 1
        spans.append((s, e))
    return spans, indent


def _extension_of(lines, s, e):
    for ln in lines[s:e]:
        m = re.match(r"^\s*(?:- )?extension:\s*(.+?)\s*$", ln)
        if m:
            v = m.group(1)
            return v[1:-1] if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"" else v
    return None


def _check_preserve(text):
    """The written manifest must still parse the way vendor_preserve reads it."""
    try:
        data = _yaml_load(text)
    except Exception as exc:  # noqa: BLE001
        raise ExtensionError(f"{PRESERVE} would not parse after the edit: {exc}")
    if data is not None and not isinstance(data, dict):
        raise ExtensionError(f"{PRESERVE} is not a mapping; fix it by hand first")


def mirror_add(root, e):
    if e["kind"] != "vendored-override":
        return []
    path = os.path.join(root, PRESERVE)
    text = open(path, encoding="utf-8").read() if os.path.isfile(path) else (
        "# fw vendor / fw upgrade keep what is listed here (T-3850). Items with\n"
        "# `extension:` are written by `fw extension` (T-5259): edit the register, not them.\n")
    lines = text.splitlines()
    added = []
    for section, body in _mirror_items(e):
        b = _section_bounds(lines, section)
        if b is None:
            if lines and lines[-1].strip():
                lines.append("")
            lines.append(f"{section}:")
            b = (len(lines) - 1, len(lines))
        hdr, end = b
        _, rest = _top_key(lines[hdr])
        if rest in ("[]", "~", "null"):
            lines[hdr] = f"{section}:"
        spans, indent = _items(lines, hdr, end)
        pad = " " * (2 if indent is None else indent)
        insert_at = spans[-1][1] if spans else hdr + 1
        lines[insert_at:insert_at] = [pad + ln for ln in body]
        added.append(f"{section}: {body[0][2:]}")
    new = "\n".join(lines) + "\n"
    _check_preserve(new)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new)
    return added


def mirror_remove(root, eid):
    path = os.path.join(root, PRESERVE)
    if not os.path.isfile(path):
        return 0
    lines = open(path, encoding="utf-8").read().splitlines()
    removed = 0
    for section in ("files", "in_file"):
        b = _section_bounds(lines, section)
        if b is None:
            continue
        spans, _ = _items(lines, *b)
        for s, e in reversed(spans):
            if _extension_of(lines, s, e) == eid:
                del lines[s:e]
                removed += 1
    new = "\n".join(lines) + "\n"
    _check_preserve(new)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new)
    return removed


# ---------------------------------------------------------------- logging

def _append_history(root, row):
    p = os.path.join(root, HISTORY)
    try:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    except OSError as exc:
        print(f"  WARN  could not write {HISTORY}: {exc}", file=sys.stderr)


def _log_i_am_human(root, verb, eid):
    log = os.path.join(root, ".context", "working", ".gate-bypass-log.yaml")
    q = lambda v: "'" + str(v).replace("'", "''") + "'"  # noqa: E731
    try:
        os.makedirs(os.path.dirname(log), exist_ok=True)
        with open(log, "a", encoding="utf-8") as fh:
            fh.write(f"- timestamp: {q(_now_ts())}\n  task: {q('<extension ' + eid + '>')}\n"
                     f"  flag: '--i-am-human'\n  caller: {q('fw extension ' + verb)}\n"
                     f"  reason: 'operator-only project extension decision (T-5259)'\n")
    except OSError as exc:
        print(f"  WARN  could not log --i-am-human: {exc}", file=sys.stderr)


def _operator_gate(root, verb, eid, i_am_human):
    if os.environ.get("CLAUDECODE") != "1":
        return True
    if i_am_human:
        _log_i_am_human(root, verb, eid)
        return True
    print(f"ERROR: fw extension {verb} is the project operator's decision (T-5259, T-4649).\n"
          "  You appear to be running inside Claude Code ($CLAUDECODE=1). An agent may propose\n"
          "  an extension, never switch one on or off.\n"
          "  Who can run it: the operator, in their own terminal, e.g.\n"
          f"    fw extension {verb} {'<kind> ' if verb == 'add' else ''}{eid} "
          f"{'--path <path> ' if verb == 'add' else ''}--words \"<your words>\"\n"
          "  If this is a human typing inside an agent session (rare), pass --i-am-human (logged).",
          file=sys.stderr)
    return False


# ---------------------------------------------------------------- verbs

def cmd_add(a):
    root = a.project
    if not _operator_gate(root, "add", a.id, a.i_am_human):
        return 1
    entries = load(root)
    if any(e["id"] == a.id for e in entries):
        raise ExtensionError(f"extension {a.id!r} is already registered (remove it first)")
    paths = [strip_vendor(p) if a.kind == "vendored-override" else p.strip().rstrip("/")
             for p in a.path]
    by = a.by or "operator"
    if os.environ.get("CLAUDECODE") == "1":
        by += " (--i-am-human in an agent session)"
    e = {"id": a.id, "kind": a.kind, "paths": paths, "markers": list(a.marker or []),
         "words": a.words, "decided_by": by, "date": _now_date()}
    if a.auth is not None:
        e["auth"] = a.auth
    if a.test is not None:
        e["test"] = a.test
    validate(e)
    mirrored = mirror_add(root, e)
    try:
        save(root, entries + [e])
    except Exception:
        mirror_remove(root, a.id)
        raise
    _append_history(root, {"ts": _now_ts(), "action": "add", "id": a.id, "kind": a.kind,
                           "paths": paths, "words": a.words, "decided_by": by})
    print(f"Registered extension {a.id} ({a.kind}) in {REGISTER}")
    for m in mirrored:
        print(f"  mirrored into {PRESERVE}  {m}")
    return 0


def cmd_remove(a):
    root = a.project
    if not _operator_gate(root, "remove", a.id, a.i_am_human):
        return 1
    entries = load(root)
    keep = [e for e in entries if e["id"] != a.id]
    if len(keep) == len(entries):
        raise ExtensionError(f"no extension {a.id!r} in {REGISTER}")
    n = mirror_remove(root, a.id)
    save(root, keep)
    _append_history(root, {"ts": _now_ts(), "action": "remove", "id": a.id, "words": a.words,
                           "decided_by": a.by or "operator"})
    print(f"Removed extension {a.id} from {REGISTER}" + (f"; {n} {PRESERVE} item(s) removed" if n else ""))
    return 0


def cmd_list(a):
    entries = load(a.project)
    if a.json:
        print(json.dumps(entries, indent=2, ensure_ascii=False))
        return 0
    if not entries:
        print(f"No project extensions registered ({REGISTER} absent or empty).")
        return 0
    print(f"{len(entries)} project extension(s) in {REGISTER}:")
    for e in entries:
        mk = f"  markers: {', '.join(e['markers'])}" if e.get("markers") else ""
        print(f"  {e['id']}  [{e['kind']}]  {', '.join(e['paths'])}{mk}")
        print(f"      decided by {e['decided_by']} on {e['date']}: \"{e['words']}\"")
    return 0


# ---------------------------------------------------------------- audit

def _covered(rel, entries):
    for e in entries:
        if e["kind"] != "vendored-override":
            continue
        for p in e["paths"]:
            if rel == p or fnmatch.fnmatchcase(rel, p) or rel.startswith(p + "/") \
                    or fnmatch.fnmatchcase(p, rel):
                return True
    return False


def _exists(root, e, p):
    base = os.path.join(root, VENDOR_DIR) if e["kind"] == "vendored-override" else root
    full = os.path.join(base, p)
    if any(c in p for c in "*?["):
        return bool(globmod.glob(full))
    return os.path.lexists(full)


def _preserve_paths(root):
    """[(section, rel)] from the preserve manifest, read the way vendor_preserve reads it."""
    path = os.path.join(root, PRESERVE)
    if not os.path.isfile(path):
        return []
    data = _yaml_load(open(path, encoding="utf-8").read()) or {}
    out = []
    for it in data.get("files") or []:
        p = it.get("path") if isinstance(it, dict) else it
        if p:
            out.append(("files", strip_vendor(p)))
    for it in data.get("in_file") or []:
        if isinstance(it, dict) and (it.get("file") or it.get("path")):
            out.append(("in_file", strip_vendor(it.get("file") or it.get("path"))))
    return out


def _digest(path):
    if os.path.islink(path):
        return "link:" + os.readlink(path)
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def _is_framework_repo(root):
    return os.path.isfile(os.path.join(root, "FRAMEWORK.md")) and \
        os.path.isfile(os.path.join(root, "bin", "fw"))


def audit_findings(root):
    """[(level, title, evidence, mitigation)]. Levels: INFO, WARN, FAIL (csrf, T-5262)."""
    out = []
    try:
        entries = load(root)
    except ExtensionError as exc:
        return [("WARN", f"Project extensions register does not load: {exc}",
                 f"{REGISTER} at the project root",
                 f"Fix {REGISTER} by hand (shape: lib/extensions.py docstring)")]
    if entries:
        ids = ", ".join(f"{e['id']} [{e['kind']}]" for e in entries)
        out.append(("INFO", f"Project extensions ({len(entries)}): {ids}", "", ""))
    for e in entries:
        if e["kind"] == CSRF_KIND:
            continue  # endpoint names, checked by Watchtower's probe (csrf_findings)
        for p in e["paths"]:
            if not _exists(root, e, p):
                where = f"{VENDOR_DIR}/{p}" if e["kind"] == "vendored-override" else p
                out.append(("WARN", f"Extension {e['id']}: registered path {where} does not exist",
                            f"{REGISTER} entry {e['id']} ({e['kind']})",
                            f"Restore the file, or the operator removes it: fw extension remove {e['id']} --words \"...\""))
    try:
        pres = _preserve_paths(root)
    except Exception as exc:  # noqa: BLE001
        pres = []
        out.append(("WARN", f"{PRESERVE} does not parse: {exc}", PRESERVE, f"Fix {PRESERVE}"))
    for section, rel in pres:
        if not _covered(rel, entries):
            out.append(("WARN", f"Preserve entry {section}: {rel} has no operator decision in {REGISTER}",
                        f"{PRESERVE} keeps {VENDOR_DIR}/{rel} through upgrade, but nobody recorded deciding it",
                        f"Operator: fw extension add vendored-override <id> --path {rel} --words \"...\" "
                        f"(then drop the hand-written {PRESERVE} item)"))
    out.extend(web_status_findings(root, entries))
    out.extend(csrf_findings(root, entries))
    if _is_framework_repo(root):
        return out
    sp = os.path.join(root, VENDOR_DIR, STAMP)
    try:
        stamp = json.load(open(sp, encoding="utf-8")).get("files") or {}
    except (OSError, ValueError, AttributeError):
        stamp = {}
    pres_rels = {r for _, r in pres}
    for rel, want in sorted(stamp.items()):
        full = os.path.join(root, VENDOR_DIR, rel)
        if not os.path.lexists(full):
            continue
        try:
            if _digest(full) == want:
                continue
        except OSError:
            continue
        if _covered(rel, entries):
            continue
        hint = " (kept by a hand-written preserve entry)" if rel in pres_rels else ""
        out.append(("WARN", f"Vendored file {VENDOR_DIR}/{rel} is locally modified with no operator decision{hint}",
                    f"differs from the vendor stamp {VENDOR_DIR}/{STAMP}; fw upgrade will overwrite it unless kept",
                    f"Operator decides: keep it (fw extension add vendored-override <id> --path {rel} --words \"...\") "
                    f"or restore it (fw upgrade)"))
    return out


WEB_STATE = os.path.join(".context", "working", "watchtower-extensions.json")


def web_status_findings(root, entries=None):
    """What Watchtower did with the `page` and `nav` extensions at its last start
    (T-5260, T-5261): read from the report web/project_extensions.py writes."""
    if entries is None:
        try:
            entries = load(root)
        except ExtensionError:
            return []
    wanted = [e for e in entries if e["kind"] in ("page", "nav")]
    path = os.path.join(root, WEB_STATE)
    try:
        st = json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError):
        if not wanted:
            return []
        return [("INFO", f"Project pages/menu entries registered ({len(wanted)}) but not loaded yet: "
                         "Watchtower has not started since", "", "")]
    out = []
    restart = "Fix the page, then: fw watchtower restart"
    if st.get("register_error"):
        out.append(("WARN", f"Watchtower could not read {REGISTER}: no project pages or menu entries loaded",
                    str(st["register_error"]), f"Fix {REGISTER}, then: fw watchtower restart"))
    pages = st.get("pages") or {}
    loaded = pages.get("loaded") or []
    if loaded:
        names = ", ".join(f"{p.get('id')} ({p.get('path')}: {' '.join(p.get('routes') or [])})" for p in loaded)
        out.append(("INFO", f"Project pages loaded by Watchtower ({len(loaded)}): {names}", "", ""))
    for p in pages.get("skipped") or []:
        out.append(("WARN", f"Project page {p.get('id')} ({p.get('path')}) was skipped by Watchtower",
                    str(p.get("reason")), restart))
    nav = st.get("nav") or {}
    added = nav.get("added") or []
    if added:
        names = ", ".join(f"{n.get('group')} > {n.get('label')}" for n in added)
        out.append(("INFO", f"Project menu entries shown by Watchtower ({len(added)}): {names}", "", ""))
    for n in nav.get("dropped") or []:
        out.append(("WARN", f"Project menu entry {n.get('id')}: {n.get('label') or n.get('path')} was dropped by Watchtower",
                    str(n.get("reason")), "Fix the entry, then: fw watchtower restart"))
    loaded_ids = {p.get("id") for p in loaded} | {p.get("id") for p in pages.get("skipped") or []} \
        | {n.get("id") for n in added} | {n.get("id") for n in nav.get("dropped") or []}
    pending = [e["id"] for e in wanted if e["id"] not in loaded_ids]
    if pending:
        out.append(("INFO", f"Registered since Watchtower last started, not loaded yet: {', '.join(pending)}",
                    "", "fw watchtower restart"))
    return out


def _csrf_sig(e):
    """What the probe verified for an entry; a register edit since makes it stale."""
    return {"paths": list(e["paths"]), "auth": e.get("auth")}


def csrf_findings(root, entries=None):
    """csrf-exemption entries (T-5262): the proving test file, and what Watchtower's
    startup probe did with each entry (state file, `csrf` key)."""
    if entries is None:
        try:
            entries = load(root)
        except ExtensionError:
            return []
    wanted = [e for e in entries if e["kind"] == CSRF_KIND]
    if not wanted:
        return []
    try:
        st = json.load(open(os.path.join(root, WEB_STATE), encoding="utf-8"))
    except (OSError, ValueError):
        st = {}
    records = {r.get("id"): r for r in ((st.get("csrf") or {}).get("entries") or [])
               if isinstance(r, dict)}
    out = []
    remove = "the operator removes it: fw extension remove {id} --words \"...\""
    for e in wanted:
        eid = e["id"]
        where = f"{REGISTER} entry {eid} (csrf-exemption, auth {e['auth']})"
        if not os.path.isfile(os.path.join(root, e["test"])):
            out.append(("FAIL", f"CSRF exemption {eid}: proving test {e['test']} does not exist",
                        where, f"Add the test that proves the {e['auth']} check, or "
                        + remove.format(id=eid)))
        rec = records.get(eid)
        if rec is None or rec.get("sig") != _csrf_sig(e):
            why = "not checked yet" if rec is None else "changed since it was checked"
            out.append(("WARN", f"CSRF exemption {eid}: {why} -- Watchtower has not started since, "
                                "so it is not applied", where, "fw watchtower restart"))
            continue
        applied = rec.get("applied") or []
        if applied:
            out.append(("INFO", f"CSRF exemption {eid} applied (auth {e['auth']}, decided by "
                                f"{e['decided_by']} on {e['date']}): {', '.join(applied)}", "", ""))
        for r in rec.get("refused") or []:
            out.append(("FAIL", f"CSRF exemption {eid}: endpoint {r.get('endpoint')} refused at "
                                "Watchtower startup, still CSRF-protected",
                        str(r.get("reason")),
                        f"Make the endpoint reject requests without a valid {e['auth']} credential "
                        "(401/403), then: fw watchtower restart; or " + remove.format(id=eid)))
        for m in rec.get("missing") or []:
            out.append(("FAIL", f"CSRF exemption {eid}: {m} does not exist in Watchtower",
                        where, "Fix the endpoint name, or " + remove.format(id=eid)))
    return out


def cmd_web_status(a):
    rows = web_status_findings(a.project)
    # fw doctor reads INFO/WARN only; a csrf FAIL shows there as WARN (fw audit keeps FAIL).
    rows += [("WARN" if r[0] == "FAIL" else r[0],) + tuple(r[1:]) for r in csrf_findings(a.project)]
    for row in rows:
        print("\t".join(x.replace("\t", " ").replace("\n", " ") for x in row))
    return 0


def cmd_audit(a):
    for level, title, ev, mit in audit_findings(a.project):
        print("\t".join(x.replace("\t", " ").replace("\n", " ") for x in (level, title, ev, mit)))
    return 0


def cmd_kept(a):
    """Called by fw vendor / fw upgrade after the copy: name the registered extensions kept."""
    try:
        entries = load(a.target)
    except ExtensionError as exc:
        print(f"  WARN  {exc}")
        return 0
    if not entries:
        return 0
    print(f"  EXTENSIONS  {len(entries)} registered in {REGISTER} (project-owned, not touched by vendor):")
    for e in entries:
        state = ""
        if e["kind"] == "vendored-override":
            missing = [p for p in e["paths"] if not _exists(a.target, e, p)]
            state = "  — kept" if not missing else f"  — MISSING: {', '.join(missing)}"
        print(f"    {e['id']} [{e['kind']}] {', '.join(e['paths'])}{state}")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(prog="fw extension", description="Project extensions register (T-5259)")
    ap.add_argument("--project", default=os.environ.get("PROJECT_ROOT") or os.getcwd())
    sub = ap.add_subparsers(dest="verb", required=True)
    p = sub.add_parser("add", help="register an extension (operator only)")
    p.add_argument("kind", choices=KINDS)
    p.add_argument("id")
    p.add_argument("--path", action="append", required=True)
    p.add_argument("--marker", action="append", help="vendored-override: in-file block marker")
    p.add_argument("--auth", help="csrf-exemption: bearer | header:<Name>")
    p.add_argument("--test", help="csrf-exemption: the project's test file proving the auth check")
    p.add_argument("--words", required=True, help="the operator's own words for the decision")
    p.add_argument("--by", help="who decided (default: operator)")
    p.add_argument("--i-am-human", action="store_true")
    p.set_defaults(fn=cmd_add)
    p = sub.add_parser("remove", help="remove an extension (operator only)")
    p.add_argument("id")
    p.add_argument("--words", required=True)
    p.add_argument("--by")
    p.add_argument("--i-am-human", action="store_true")
    p.set_defaults(fn=cmd_remove)
    p = sub.add_parser("list", help="list registered extensions")
    p.add_argument("--json", action="store_true")
    p.set_defaults(fn=cmd_list)
    p = sub.add_parser("audit", help="audit findings as TSV (used by fw audit)")
    p.set_defaults(fn=cmd_audit)
    p = sub.add_parser("web-status", help="what Watchtower loaded and skipped, as TSV (used by fw doctor)")
    p.set_defaults(fn=cmd_web_status)
    p = sub.add_parser("kept", help="report registered extensions after a vendor")
    p.add_argument("--target", required=True)
    p.set_defaults(fn=cmd_kept)
    a = ap.parse_args(argv)
    try:
        return a.fn(a)
    except ExtensionError as exc:
        print(f"ERROR  {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
