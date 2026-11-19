"""Project Watchtower pages (T-5260, T-4649 slice 1).

A project's own pages live in the PROJECT, not in the vendored framework copy,
so `fw upgrade` never overwrites them. A page is loaded only when the project's
operator registered it (`.framework-extensions.yaml`, kind `page`, T-5259):

    fw extension add page hosts --path web_ext/hosts.py --words "our hosts page"

Every `.py` path of a `page` entry is a module that exposes a Flask blueprint
as `bp`. Other paths of the entry (a templates folder, a helper) are listed and
audited, never imported. Beside the module:

    web_ext/hosts.py            the blueprint (`bp`)
    web_ext/templates/...       its templates, searched AFTER the framework's own
    web_ext/static/...          its static files (see below)
    web_ext/<helper>.py         helper modules, importable as `import <helper>`

Order is the rule everywhere: the framework first, the project after. A project
template cannot shadow a framework template, a project helper cannot shadow a
framework or installed module, and a project route that collides with an
existing route is skipped. A page that fails to import, has no `bp`, or
collides is skipped with ONE logged line; Watchtower starts and serves every
other page. What was loaded and what was skipped is written to
`.context/working/watchtower-extensions.json`, which `fw doctor` and `fw audit`
read (lib/extensions.py `web_status_findings`).

Static files: a blueprint that sets its own `static_folder` is used as written.
One that sets none, with a `static/` folder beside its module, gets that folder
at `/ext/<blueprint name>/static/`, so `url_for('<name>.static', filename=...)`
works without a `url_prefix`.
"""

import datetime
import importlib.util
import json
import logging
import os
import re
import sys

logger = logging.getLogger(__name__)

STATE_REL = os.path.join(".context", "working", "watchtower-extensions.json")
APP_KEY = "fw_project_extensions"


def _register_module(framework_root):
    """lib/extensions.py — the one reader of the register (T-5259)."""
    lib = os.path.join(str(framework_root), "lib")
    if lib not in sys.path:
        sys.path.append(lib)
    import extensions  # noqa: WPS433
    return extensions


def load_register(project_root, framework_root):
    """(entries, error). A register that does not load yields no extensions."""
    try:
        ext = _register_module(framework_root)
        return ext.load(str(project_root)), None
    except Exception as exc:  # noqa: BLE001 - a broken register never stops Watchtower
        return [], str(exc)


def _module_name(ext_id, path):
    stem = os.path.splitext(os.path.basename(path))[0]
    return "fw_project_page_" + re.sub(r"\W", "_", f"{ext_id}_{stem}")


def _import_isolated(name, full):
    spec = importlib.util.spec_from_file_location(name, full)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {full}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    try:
        spec.loader.exec_module(mod)
    except BaseException:
        sys.modules.pop(name, None)
        raise
    return mod


def _rules_of(bp):
    """[(rule, methods)] the blueprint would add, found on a scratch app so the
    real app is untouched when the page turns out to collide."""
    from flask import Flask
    scratch = Flask("fw_project_page_probe", static_folder=None)
    scratch.register_blueprint(bp)
    return [(r.rule, frozenset(r.methods or ())) for r in scratch.url_map.iter_rules()]


def _collision(app, bp, rules):
    if bp.name in app.blueprints:
        return f"blueprint name {bp.name!r} is already taken"
    existing = {}
    for r in app.url_map.iter_rules():
        existing.setdefault(r.rule, set()).update(r.methods or ())
    for rule, methods in rules:
        if rule in existing and (methods & existing[rule] or not methods):
            return f"route {rule} already exists"
    return None


def _write_state(project_root, state, force=False):
    """Write the load report. Nothing is written for a project that has no page
    or nav extension and never had a report (keeps such trees clean)."""
    path = os.path.join(str(project_root), STATE_REL)
    if not force and not os.path.isfile(path):
        return
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = f"{path}.tmp.{os.getpid()}"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(state, fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.replace(tmp, path)
    except OSError as exc:
        logger.warning("project extensions: could not write %s: %s", STATE_REL, exc)


def _state(app):
    return app.extensions.setdefault(APP_KEY, {
        "pages": {"loaded": [], "skipped": []},
        "nav": {"added": [], "dropped": []},
        "register_error": None,
    })


def save_state(app, project_root, entries):
    st = dict(_state(app))
    st["ts"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    st["pid"] = os.getpid()
    has = any(e.get("kind") in ("page", "nav") for e in entries) or bool(st.get("register_error"))
    _write_state(project_root, st, force=has)


def load_project_pages(app, project_root, framework_root, entries=None):
    """Register every `page` extension's blueprint on `app`, after the
    framework's own. Returns the state dict ({loaded: [...], skipped: [...]})."""
    project_root = str(project_root)
    st = _state(app)
    if entries is None:
        entries, err = load_register(project_root, framework_root)
        if err:
            st["register_error"] = err
            logger.warning("project extensions: register not loaded, no project pages: %s", err)
    pages = st["pages"]
    template_dirs = []
    for e in entries:
        if e.get("kind") != "page":
            continue
        for rel in e["paths"]:
            if not rel.endswith(".py"):
                continue
            full = os.path.join(project_root, rel)
            reason = None
            bp = None
            try:
                if not os.path.isfile(full):
                    raise ImportError("file not found")
                folder = os.path.dirname(full)
                if folder not in sys.path:
                    sys.path.append(folder)  # after everything: helpers never shadow
                mod = _import_isolated(_module_name(e["id"], rel), full)
                bp = getattr(mod, "bp", None)
                from flask import Blueprint
                if not isinstance(bp, Blueprint):
                    raise ImportError("module exposes no Flask blueprint named `bp`")
                static_dir = os.path.join(folder, "static")
                if bp.static_folder is None and os.path.isdir(static_dir):
                    bp.static_folder = static_dir
                    bp.static_url_path = f"/ext/{bp.name}/static"
                rules = _rules_of(bp)
                reason = _collision(app, bp, rules)
                if reason is None:
                    app.register_blueprint(bp)
            except Exception as exc:  # noqa: BLE001 - one broken page never stops the rest
                reason = f"{type(exc).__name__}: {exc}"
            if reason is not None:
                logger.warning("project page %s (%s) skipped: %s", e["id"], rel, reason)
                pages["skipped"].append({"id": e["id"], "path": rel, "reason": reason})
                continue
            tdir = os.path.join(os.path.dirname(full), "templates")
            if os.path.isdir(tdir) and tdir not in template_dirs:
                template_dirs.append(tdir)
            pages["loaded"].append({
                "id": e["id"], "path": rel, "blueprint": bp.name,
                "routes": sorted({r for r, _ in rules}),
            })
    if template_dirs:
        from jinja2 import ChoiceLoader, FileSystemLoader
        # Framework loader FIRST: a project template never shadows a framework one.
        app.jinja_loader = ChoiceLoader([app.jinja_loader, FileSystemLoader(template_dirs)])
    return pages
