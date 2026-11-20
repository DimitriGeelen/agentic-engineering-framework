"""Project Watchtower pages (T-5260), menu entries (T-5261) and CSRF exemptions
(T-5262) — T-4649 slices 1, 2, 3.

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
        tmp = f"{path}.tmp.{os.getpid()}-{os.urandom(4).hex()}"
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
        "csrf": {"entries": []},
        "register_error": None,
    })


def save_state(app, project_root, entries):
    st = {k: v for k, v in _state(app).items() if k != "nav_groups"}
    st["ts"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    st["pid"] = os.getpid()
    has = any(e.get("kind") in ("page", "nav", "csrf-exemption") for e in entries) \
        or bool(st.get("register_error"))
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


# ---------------------------------------------------------------- menu (T-5261)
#
# A `nav` extension names a YAML file in the project:
#
#     fw extension add nav ring20-menu --path web_ext/nav.yaml --words "our menu"
#
#     group: "Ring20"              # a new group, or the name of a framework group
#     section: "Project"           # optional: sub-heading when the group has sub-headings
#     items:
#       - label: "Hosts"
#         endpoint: "hosts_ext.hosts"     # a Flask endpoint that takes no arguments
#       - label: "Runbook"
#         path: "/hosts/runbook"          # or a path on this Watchtower
#
# Merging only adds. web.shared.NAV_GROUPS stays the framework's list, in its
# order; a new group goes after the framework's groups and appended items go
# after the framework's own items of that group. An item whose endpoint does not
# exist is dropped with one logged line and shows as a `fw doctor` WARN.

def _nav_copy(items):
    return [(it[0], _nav_copy(it[1])) if len(it) == 2 and isinstance(it[1], list) else tuple(it)
            for it in items]


def _nav_item(app, raw):
    """(leaf, None) or (None, reason) for one declared item."""
    if not isinstance(raw, dict):
        return None, "item is not a mapping"
    label = raw.get("label")
    if not isinstance(label, str) or not label.strip():
        return None, "item has no label"
    endpoint, path = raw.get("endpoint"), raw.get("path")
    if bool(endpoint) == bool(path):
        return None, "item needs exactly one of endpoint or path"
    if path:
        if not isinstance(path, str) or not path.startswith("/") or path.startswith("//"):
            return None, f"path {path!r} must start with a single /"
        return (label.strip(), path, None), None
    if not isinstance(endpoint, str) or endpoint not in app.view_functions:
        return None, f"endpoint {endpoint!r} does not exist"
    if not any(not r.arguments for r in app.url_map.iter_rules(endpoint)):
        return None, f"endpoint {endpoint!r} needs arguments, a menu link cannot supply them"
    return (label.strip(), endpoint, None), None


def build_project_nav(app, project_root, framework_root, base_groups, entries=None):
    """The menu to draw: the framework's groups plus the project's `nav` entries.
    Returns the SAME object as `base_groups` when the project adds nothing."""
    project_root = str(project_root)
    st = _state(app)
    nav = st["nav"]
    if entries is None:
        entries, _err = load_register(project_root, framework_root)
    wanted = [e for e in entries if e.get("kind") == "nav"]
    if not wanted:
        st["nav_groups"] = base_groups
        return base_groups
    ext = _register_module(framework_root)
    groups = [(name, _nav_copy(items)) for name, items in base_groups]

    def drop(e, rel, label, reason):
        logger.warning("project menu entry %s (%s%s) dropped: %s", e["id"], rel,
                       f": {label}" if label else "", reason)
        nav["dropped"].append({"id": e["id"], "path": rel, "label": label, "reason": reason})

    for e in wanted:
        for rel in e["paths"]:
            try:
                with open(os.path.join(project_root, rel), encoding="utf-8") as fh:
                    data = ext._yaml_load(fh.read())
            except Exception as exc:  # noqa: BLE001 - a broken menu file never stops Watchtower
                drop(e, rel, None, f"{type(exc).__name__}: {exc}")
                continue
            group = data.get("group") if isinstance(data, dict) else None
            items = data.get("items") if isinstance(data, dict) else None
            if not isinstance(group, str) or not group.strip() or not isinstance(items, list):
                drop(e, rel, None, "file needs `group:` (a name) and `items:` (a list)")
                continue
            group = group.strip()
            leaves = []
            for raw in items:
                leaf, reason = _nav_item(app, raw)
                if leaf is None:
                    drop(e, rel, raw.get("label") if isinstance(raw, dict) else None, reason)
                else:
                    leaves.append(leaf)
            if not leaves:
                continue
            target = next((g for g in groups if g[0] == group), None)
            if target is None:
                target = (group, [])
                groups.append(target)
            subsectioned = any(len(it) == 2 and isinstance(it[1], list) for it in target[1])
            if subsectioned:
                section = data.get("section") if isinstance(data.get("section"), str) else "Project"
                sub = next((it for it in target[1] if len(it) == 2 and isinstance(it[1], list)
                            and it[0] == section), None)
                if sub is None:
                    sub = (section, [])
                    target[1].append(sub)
                sub[1].extend(leaves)
            else:
                target[1].extend(leaves)
            nav["added"].extend({"id": e["id"], "group": group, "label": leaf[0], "target": leaf[1]}
                                for leaf in leaves)
    st["nav_groups"] = groups if nav["added"] else base_groups
    return st["nav_groups"]


def nav_groups(base_groups, app=None):
    """The merged menu for the current app, at render time. Falls back to the
    framework's own list outside an app or before the merge ran."""
    if app is None:
        try:
            from flask import current_app
            app = current_app._get_current_object()
        except Exception:  # noqa: BLE001 - no app context
            return base_groups
    return (app.extensions.get(APP_KEY) or {}).get("nav_groups") or base_groups


# ------------------------------------------------------- CSRF exemptions (T-5262)
#
# A `csrf-exemption` entry names endpoints (`bp.view`) or a whole blueprint
# (`blueprint:<name>`) that authenticate themselves, the credential they check
# (`auth: bearer` or `auth: header:<Name>`) and the project's proving test. The
# exemption is applied to an endpoint only when, at startup, every one of its
# state-changing URL rules answers 401 or 403 to two requests: one with no
# credential and one with a wrong random credential. An endpoint that answers
# anything else (e.g. 200: it checks only that the header is present) is refused
# and stays CSRF-protected.
#
# How the probe gets past csrf_protect without weakening it: each probe request
# carries a WSGI environ key (PROBE_ENVIRON_KEY) holding a random per-app secret.
# Only app.test_client() can set a non-HTTP_ environ key; a real client's headers
# arrive as HTTP_* keys and can never produce it. csrf_protect skips the check
# for a request carrying the matching secret (probe_request()). The probe runs
# once, from create_app(); the probe requests never trigger probing themselves.
# NOTE: a probe request executes the endpoint. An endpoint that does not check
# its credential acts on that request; that is how it is caught.

PROBE_ENVIRON_KEY = "fw.csrf_probe"
EXEMPT_KEY = "fw_csrf_exempt"
_SECRET_KEY = "fw_csrf_probe_secret"
STATE_METHODS = ("POST", "PUT", "PATCH", "DELETE")


def probe_request(app, environ):
    """True when this request is one of the startup probe's own requests."""
    secret = app.extensions.get(_SECRET_KEY)
    got = environ.get(PROBE_ENVIRON_KEY)
    import hmac
    return bool(secret) and isinstance(got, str) and hmac.compare_digest(got, secret)


def exempt_endpoints(app):
    return app.extensions.get(EXEMPT_KEY) or frozenset()


def _dummy(conv):
    """A value a URL converter accepts, for building a probe URL."""
    name = type(conv).__name__
    if name == "IntegerConverter":
        return max(1, int(getattr(conv, "min", None) or 1))
    if name == "FloatConverter":
        return 1.0
    if name == "UUIDConverter":
        import uuid
        return uuid.UUID(int=0)
    if name == "AnyConverter":
        return sorted(conv.items)[0]
    return "x"


def _build_url(rule):
    values = {arg: _dummy(conv) for arg, conv in rule._converters.items()}
    try:
        built = rule.build(values, append_unknown=False)
    except Exception as exc:  # noqa: BLE001
        return None, f"cannot build a probe URL for {rule.rule}: {type(exc).__name__}: {exc}"
    if not built:
        return None, f"cannot build a probe URL for {rule.rule}"
    return built[1], None


def _credential_header(auth, value):
    if auth == "bearer":
        return {"Authorization": f"Bearer {value}"}
    return {auth.split(":", 1)[1]: value}


def _probe_endpoint(app, client, secret, endpoint, auth):
    """None when the endpoint enforces its credential, else the reason it does not."""
    rules = [r for r in app.url_map.iter_rules(endpoint) if set(r.methods or ()) & set(STATE_METHODS)]
    if not rules:
        return "accepts no POST/PUT/PATCH/DELETE, so there is nothing to exempt"
    for rule in rules:
        url, err = _build_url(rule)
        if err:
            return err
        for method in sorted(set(rule.methods) & set(STATE_METHODS)):
            for label, headers in (("no credential", {}),
                                   ("a wrong credential",
                                    _credential_header(auth, os.urandom(16).hex()))):
                try:
                    resp = client.open(url, method=method, headers=headers,
                                       environ_base={PROBE_ENVIRON_KEY: secret})
                    code = resp.status_code
                    resp.close()
                except Exception as exc:  # noqa: BLE001
                    return f"{method} {url} with {label} raised {type(exc).__name__}: {exc}"
                if code not in (401, 403):
                    hint = " -- it checks header presence only" if label == "a wrong credential" else ""
                    return f"{method} {url} answered {code} to a request with {label}{hint}"
    return None


def probe_csrf_exemptions(app, entries):
    """Probe every csrf-exemption entry; store the applied endpoint set on the app
    (exempt_endpoints) and the per-entry result in the state (`csrf`)."""
    st = _state(app)
    records, applied_all = [], set()
    wanted = [e for e in entries if e.get("kind") == "csrf-exemption"]
    if wanted:
        secret = os.urandom(24).hex()
        app.extensions[_SECRET_KEY] = secret
        client = app.test_client()
        # The probe's requests are not the app's "first request": Flask would
        # otherwise refuse any later setup call (a route, a hook) on this app.
        was_first = getattr(app, "_got_first_request", False)
        try:
            for e in wanted:
                rec = {"id": e["id"], "auth": e.get("auth"), "decided_by": e.get("decided_by"),
                       "sig": {"paths": list(e["paths"]), "auth": e.get("auth")},
                       "applied": [], "refused": [], "missing": []}
                for p in e["paths"]:
                    if p.startswith("blueprint:"):
                        name = p.split(":", 1)[1]
                        if name not in app.blueprints:
                            rec["missing"].append(p)
                            continue
                        eps = sorted({r.endpoint for r in app.url_map.iter_rules()
                                      if r.endpoint.startswith(name + ".")
                                      and set(r.methods or ()) & set(STATE_METHODS)})
                        if not eps:
                            rec["refused"].append({"endpoint": p, "reason":
                                                   "blueprint has no POST/PUT/PATCH/DELETE endpoint"})
                            continue
                    elif p not in app.view_functions:
                        rec["missing"].append(p)
                        continue
                    else:
                        eps = [p]
                    for ep in eps:
                        reason = _probe_endpoint(app, client, secret, ep, e.get("auth") or "bearer")
                        if reason is None:
                            rec["applied"].append(ep)
                            applied_all.add(ep)
                        else:
                            logger.warning("CSRF exemption %s: %s refused: %s", e["id"], ep, reason)
                            rec["refused"].append({"endpoint": ep, "reason": reason})
                records.append(rec)
        finally:
            app.extensions.pop(_SECRET_KEY, None)  # no probe request is accepted after startup
            app._got_first_request = was_first
    app.extensions[EXEMPT_KEY] = frozenset(applied_all)
    st["csrf"] = {"entries": records}
    return st["csrf"]
