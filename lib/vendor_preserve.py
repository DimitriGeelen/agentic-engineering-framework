#!/usr/bin/env python3
"""Consumer-local protection for `fw vendor` (T-3850).

do_vendor mirrors every include dir with `rsync --delete --delete-excluded`
(or rm -rf + cp). Anything a consumer put under .agentic-framework/ that the
framework source does not carry was deleted, and every in-place patch was
overwritten -- silently. ring20-manager lost 7 Watchtower blueprints, 6
templates, lib/approval_channel.py and ~40 in-file patches on v1.8.0 and had
to roll back. Second incident of the class (first: ring20 T-2019).

Two halves, called from do_vendor around the copy:

  pre   Before anything is written. Reads the project's preserve manifest
        (.fwvendor-preserve.yaml at the project root), classifies every file
        under the include dirs of the existing vendored copy, snapshots what
        must survive or might be lost into a backup dir, and prints a report.
        Exit 3 = refuse: uncovered local files would be lost and
        --allow-delete-locals was not given. Nothing has been written then.

  post  After the copy. Restores `files:` entries, reports upstream changes to
        them, checks every `in_file:` marker, and writes the vendor stamp
        (.fw-vendor-stamp.json: sha256 of every file the vendor wrote) so the
        NEXT vendor can tell a local edit from an upstream one.

"Local" is decided against the stamp when there is one. Without a stamp (the
first vendor after this shipped), a file the source lacks is local only if its
path never existed in the source's git history -- an upstream-deleted file is
not a consumer's work. Local *modifications* cannot be detected without a
stamp; the first vendor writes one so the next can.

Manifest shape (paths relative to .agentic-framework/; a leading
`.agentic-framework/` is accepted and stripped; `files:` entries may be globs):

    files:
      - web/blueprints/approvals.py
      - path: web/templates/ring20_*.html
        reason: ring20 approval UI
    in_file:
      - file: web/app.py
        marker: "ring20-local: register approvals blueprint"
      - file: lib/notify.sh
        markers: ["ring20-local: ntfy topic", "ring20-local: retry"]
"""

import argparse
import datetime
import fnmatch
import hashlib
import json
import os
import shutil
import subprocess
import sys

MANIFEST = ".fwvendor-preserve.yaml"
STAMP = ".fw-vendor-stamp.json"
VENDOR_DIR = ".agentic-framework"
REFUSE = 3


# ---------------------------------------------------------------- manifest

def _strip_prefix(p):
    p = str(p).strip().strip('"').strip("'")
    while p.startswith("./"):
        p = p[2:]
    if p.startswith(VENDOR_DIR + "/"):
        p = p[len(VENDOR_DIR) + 1:]
    return p.rstrip("/")


def _mini_yaml(text):
    """Fallback for hosts without PyYAML: the manifest's two-list shape only."""
    data, section, cur, cur_indent, open_key = {}, None, None, 0, None
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        line = raw.rstrip()
        indent = len(line) - len(line.lstrip())
        s = line.strip()
        if indent == 0:
            if s.endswith(":"):
                section, cur, open_key = s[:-1], None, None
                data[section] = []
            continue
        if section is None:
            continue
        if s.startswith("- "):
            body = s[2:].strip()
            if open_key is not None and cur is not None and indent > cur_indent:
                cur[open_key].append(_scalar(body))  # item of a nested list (markers:)
                continue
            open_key = None
            if ":" in body and body[0] not in "'\"":
                k, v = body.split(":", 1)
                cur, cur_indent = {}, indent
                data[section].append(cur)
                if v.strip():
                    cur[k.strip()] = _scalar(v)
                else:
                    cur[k.strip()], open_key = [], k.strip()
            else:
                cur = None
                data[section].append(_scalar(body))
        elif cur is not None and ":" in s:
            k, v = s.split(":", 1)
            if v.strip():
                cur[k.strip()], open_key = _scalar(v), None
            else:
                cur[k.strip()], open_key = [], k.strip()
    return data


def _scalar(v):
    v = v.strip()
    if v.startswith("[") and v.endswith("]"):
        return [_scalar(x) for x in v[1:-1].split(",") if x.strip()]
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
        return v[1:-1]
    return v


def load_manifest(target):
    path = os.path.join(target, MANIFEST)
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    try:
        import yaml  # noqa: WPS433
        data = yaml.safe_load(text) or {}
    except ImportError:
        data = _mini_yaml(text)
    except Exception as exc:  # malformed manifest must not mean "protect nothing"
        raise SystemExit(f"ERROR  {MANIFEST} does not parse: {exc}")
    if not isinstance(data, dict):
        raise SystemExit(f"ERROR  {MANIFEST} must be a mapping with files:/in_file:")
    files = []
    for it in data.get("files") or []:
        p = it.get("path") if isinstance(it, dict) else it
        if p:
            files.append(_strip_prefix(p))
    in_file = {}
    for it in data.get("in_file") or []:
        if not isinstance(it, dict):
            continue
        f = it.get("file") or it.get("path")
        if not f:
            continue
        marks = it.get("markers")
        if marks is None:
            marks = [it.get("marker")] if it.get("marker") else []
        if isinstance(marks, str):
            marks = [marks]
        in_file.setdefault(_strip_prefix(f), []).extend(str(m) for m in marks if m)
    return {"files": files, "in_file": in_file}


def preserved(rel, manifest):
    return bool(manifest) and any(
        rel == pat or fnmatch.fnmatchcase(rel, pat) or rel.startswith(pat + "/")
        for pat in manifest["files"])


# ---------------------------------------------------------------- trees

def excluded(rel, excludes):
    parts = rel.split("/")
    for pat in excludes:
        if "/" not in pat:
            if any(fnmatch.fnmatchcase(p, pat) for p in parts):
                return True
            continue
        for i in range(1, len(parts) + 1):
            if fnmatch.fnmatchcase("/".join(parts[:i]), pat):
                return True
    return False


def walk(root, includes, excludes):
    """rel -> abs for every file/symlink under root's includes, minus excludes."""
    out = {}
    for inc in includes:
        base = os.path.join(root, inc)
        if os.path.islink(base) or os.path.isfile(base):
            if not excluded(inc, excludes):
                out[inc] = base
            continue
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            reldir = os.path.relpath(dirpath, root)
            keep = []
            for d in dirnames:
                full = os.path.join(dirpath, d)
                rel = os.path.normpath(os.path.join(reldir, d))
                if os.path.islink(full):
                    if not excluded(rel, excludes):
                        out[rel] = full
                elif not excluded(rel, excludes):
                    keep.append(d)
            dirnames[:] = keep
            for f in filenames:
                rel = os.path.normpath(os.path.join(reldir, f))
                if not excluded(rel, excludes):
                    out[rel] = os.path.join(dirpath, f)
    return out


def digest(path):
    if os.path.islink(path):
        return "link:" + os.readlink(path)
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def ever_in_source_history(source, includes):
    try:
        out = subprocess.run(
            ["git", "-C", source, "log", "--all", "--no-renames", "--diff-filter=A",
             "--format=", "--name-only", "--"] + list(includes),
            capture_output=True, text=True, timeout=120, check=True).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    return {l for l in out.splitlines() if l}


def read_lines(path):
    with open(path, encoding="utf-8") as fh:
        return [l.rstrip("\n") for l in fh if l.strip() and not l.lstrip().startswith("#")]


def copy_into(src, dst_root, rel):
    dst = os.path.join(dst_root, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.islink(src):
        if os.path.lexists(dst):
            os.unlink(dst)
        os.symlink(os.readlink(src), dst)
    else:
        shutil.copy2(src, dst)


def log_bypass(target, detail):
    logdir = os.path.join(target, ".context", "working")
    try:
        os.makedirs(logdir, exist_ok=True)
        ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with open(os.path.join(logdir, ".gate-bypass-log.yaml"), "a", encoding="utf-8") as fh:
            fh.write(f"- ts: '{ts}'\n  gate: vendor-delete-locals\n  tier: 2\n"
                     f"  mechanism: --allow-delete-locals\n"
                     f"  detail: '{detail.replace(chr(39), chr(39) * 2)}'\n")
    except OSError as exc:
        print(f"  WARN  could not write bypass log: {exc}", file=sys.stderr)


# ---------------------------------------------------------------- pre

def cmd_pre(a):
    includes = read_lines(a.includes)
    excludes = read_lines(a.excludes)
    dest = os.path.join(a.target, VENDOR_DIR)
    manifest = load_manifest(a.target)
    plan = {"backup": None, "restore": [], "in_file": {}, "manifest": bool(manifest)}

    if not os.path.isdir(dest):
        json.dump(plan, open(a.plan, "w"))
        return 0

    stamp = None
    sp = os.path.join(dest, STAMP)
    if os.path.isfile(sp):
        try:
            stamp = json.load(open(sp)).get("files") or {}
        except (OSError, ValueError):
            print(f"  WARN  {VENDOR_DIR}/{STAMP} unreadable — treating as absent")
    src = walk(a.source, includes, excludes)
    dst = walk(dest, includes, excludes)
    history = None

    keep, at_risk, in_file_hits = [], [], []
    for rel in sorted(dst):
        if manifest and rel in manifest["in_file"] and rel in src:
            in_file_hits.append(rel)
            continue
        if preserved(rel, manifest) or (manifest and rel in manifest["in_file"]):
            keep.append(rel)
            continue
        dhash = None
        if rel not in src:
            if stamp is not None:
                if rel not in stamp:
                    at_risk.append((rel, "local-only — would be DELETED"))
                elif digest(dst[rel]) != stamp[rel]:
                    at_risk.append((rel, "removed upstream, but edited locally — would be DELETED"))
            else:
                if history is None:
                    history = ever_in_source_history(a.source, includes)
                    if history is None:
                        history = set()
                if rel not in history:
                    at_risk.append((rel, "local-only — would be DELETED"))
            continue
        if stamp is not None and rel in stamp:
            dhash = digest(dst[rel])
            if dhash != stamp[rel] and dhash != digest(src[rel]):
                at_risk.append((rel, "edited locally — would be OVERWRITTEN"))

    if stamp is None:
        print(f"  NOTE  no vendor stamp yet ({VENDOR_DIR}/{STAMP}) — local EDITS to framework "
              "files cannot be detected this run; this vendor writes one so the next run can.")

    for rel in keep:
        tag = "local-only" if rel not in src else "kept local over upstream"
        print(f"  PRESERVE  {rel}  ({tag}; {MANIFEST})")
    for rel in in_file_hits:
        print(f"  IN-FILE   {rel}  (takes upstream; {len((manifest or {}).get('in_file', {}).get(rel, []))} marker(s) "
              "checked after the copy)")
    if at_risk:
        print(f"  {len(at_risk)} file(s) under {VENDOR_DIR}/ are not the framework's and are "
              f"not covered by {MANIFEST}:")
        for rel, why in at_risk:
            print(f"    LOCAL  {rel}  — {why}")

    if a.dry_run:
        return 0

    if at_risk and not a.allow:
        print("", file=sys.stderr)
        print("  REFUSED  fw vendor would lose the local file(s) listed above. Nothing was "
              "written.", file=sys.stderr)
        print(f"    Keep them:  list them in {MANIFEST} at the project root "
              "(files: for whole files, in_file: + marker for patches), then re-run.",
              file=sys.stderr)
        print("    Lose them:  re-run with --allow-delete-locals (logged Tier-2; a copy is kept "
              "in .context/working/vendor-backup/).", file=sys.stderr)
        return REFUSE

    to_backup = keep + in_file_hits + [r for r, _ in at_risk]
    if to_backup:
        ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        backup = os.path.join(a.target, ".context", "working", "vendor-backup", ts)
        for rel in to_backup:
            copy_into(dst[rel], backup, rel)
        plan["backup"] = backup
    plan["restore"] = [{"rel": r, "local": digest(dst[r]),
                        "upstream": digest(src[r]) if r in src else None,
                        "stamp": (stamp or {}).get(r)} for r in keep]
    plan["in_file"] = {r: manifest["in_file"][r] for r in in_file_hits} if manifest else {}
    if at_risk:
        log_bypass(a.target, f"{len(at_risk)} local file(s) lost: "
                   + ", ".join(r for r, _ in at_risk[:20]))
        print(f"  BYPASS  --allow-delete-locals: {len(at_risk)} local file(s) will be lost "
              f"(logged Tier-2; copies in {os.path.relpath(plan['backup'], a.target)}/)")
    json.dump(plan, open(a.plan, "w"))
    return 0


# ---------------------------------------------------------------- post

def cmd_post(a):
    includes = read_lines(a.includes)
    excludes = read_lines(a.excludes)
    plan = json.load(open(a.plan))
    dest = os.path.join(a.target, VENDOR_DIR)
    backup = plan.get("backup")
    rc = 0

    for ent in plan.get("restore", []):
        rel = ent["rel"]
        copy_into(os.path.join(backup, rel), dest, rel)
        up = ent.get("upstream")
        if up and up != ent["local"]:
            changed = ent.get("stamp") is None or up != ent.get("stamp")
            what = "UPSTREAM CHANGED it" if changed else "differs from upstream"
            print(f"  KEPT-LOCAL  {rel}  — {what}; local copy kept. Compare: "
                  f"diff {os.path.relpath(os.path.join(backup, rel), a.target)} "
                  f"<framework>/{rel}")
        else:
            print(f"  KEPT-LOCAL  {rel}")

    missing = 0
    for rel, marks in sorted(plan.get("in_file", {}).items()):
        path = os.path.join(dest, rel)
        try:
            body = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            body = None
        for m in marks:
            if body is None or m not in body:
                missing += 1
                print(f"  MARKER MISSING  {rel}: \"{m}\"  — local patch not in the new upstream "
                      f"file; pre-vendor copy: "
                      f"{os.path.relpath(os.path.join(backup, rel), a.target)}")
    if plan.get("in_file"):
        total = sum(len(v) for v in plan["in_file"].values())
        print(f"  IN-FILE   {total - missing}/{total} marker(s) present after vendor")
        if missing:
            print(f"  WARN  {missing} in-file patch(es) must be re-applied — see MARKER MISSING "
                  "above.")
            rc = 4

    src = walk(a.source, includes, excludes)
    files = {rel: digest(p) for rel, p in sorted(src.items())}
    for extra in read_lines(a.written) if a.written else []:
        p = os.path.join(dest, extra)
        if os.path.isfile(p) and extra not in files:
            files[extra] = digest(p)
    with open(os.path.join(dest, STAMP), "w", encoding="utf-8") as fh:
        json.dump({"schema": 1, "source": "fw vendor (T-3850)",
                   "written_at": datetime.datetime.now(datetime.timezone.utc)
                   .strftime("%Y-%m-%dT%H:%M:%SZ"),
                   "files": files}, fh, indent=0, sort_keys=True)
        fh.write("\n")
    print(f"  ✓ {STAMP} ({len(files)} files)")
    return rc


def main(argv=None):
    ap = argparse.ArgumentParser(description="fw vendor consumer-local protection (T-3850)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("pre", "post"):
        p = sub.add_parser(name)
        p.add_argument("--source", required=True)
        p.add_argument("--target", required=True)
        p.add_argument("--includes", required=True)
        p.add_argument("--excludes", required=True)
        p.add_argument("--plan", required=True)
        p.add_argument("--allow", action="store_true")  # pre only; post accepts the shared argv
        if name == "pre":
            p.add_argument("--dry-run", action="store_true")
        else:
            p.add_argument("--written")
    a = ap.parse_args(argv)
    return cmd_pre(a) if a.cmd == "pre" else cmd_post(a)


if __name__ == "__main__":
    sys.exit(main())
