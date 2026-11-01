#!/usr/bin/env python3
"""driver_sets.py — which value-driver set a task or arc is scored under (T-4984).

T-4961 (GO, narrow form) lets an arc name a driver set of its own:

    # .context/arcs/<slug>.yaml
    driver_set: product          # -> policy/value-drivers-product.yaml

Every BVP reader today assumes the one live `policy/value-drivers.yaml`. Before
any of them becomes set-aware (slices 2 and 3, T-4985/T-4986), there has to be
ONE resolver and ONE validator, so that no reader invents its own rule and none
silently falls back to the live set. This module is both. It changes no reader.

Design: docs/reports/T-4961-driver-sets.md §Design (T-4967) §1 and §4, with the
review fixes from the same report (codex C5, C6; opencode 1, 4, 5, 7, 8), which
override the original design where they differ (weights are integers 0-10).

Resolution (`resolve_set_name`):
  1. The task's arcs are its `arc_id:` (slug file first, then an id/slug scan,
     T-1849) plus every legacy `arc:<slug>` tag (T-3503; same tag rule as
     lib/arc_membership.py).
  2. No arc, or no `driver_set:` on it, or `driver_set: default` -> the live
     file. The name returned is None.
  3. `driver_set: <name>` -> policy/value-drivers-<name>.yaml.

Every ambiguous or broken case is a REFUSAL (DriverSetError), never a fallback
to the live file, because "no arc" and "live set" would otherwise look the
same: an `arc_id:` naming no arc; every `arc:` tag naming a missing arc; an arc
file that does not parse, or repeats a key; two arc files claiming one id or
slug; an empty or malformed `driver_set:`; arcs naming different sets; a set
file that is missing, unreadable or invalid (`validate_set`).

Set-file contract (`validate_set`): the live file's schema; D1-D4 present and
equal to the live entries except `weight` and `rubric`; ids unique across both
sections; weights are integers 0-10. `auto_promote` and
`inception_scoring_exception` are project-level, ignored in a set, and WARN.

CLI: `python3 lib/driver_sets.py audit PROJECT_ROOT` prints one tab-separated
line per arc that names a set (OK / WARN / FAIL), for agents/audit/audit.sh.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

try:  # imported as lib.driver_sets (test convention) or standalone
    from .arc_membership import _TAG_ARC_RE, parse_arc_id_value
except ImportError:  # pragma: no cover — lib/ directly on sys.path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from arc_membership import _TAG_ARC_RE, parse_arc_id_value

NAME_RE = re.compile(r"^[a-z][a-z0-9-]{0,31}$")
DEFAULT_NAME = "default"
LIVE_FILE = "value-drivers.yaml"
PROTECTED_IDS = ("D1", "D2", "D3", "D4")
SET_KEYS = ("version", "protected_drivers", "free_drivers")
PROJECT_LEVEL_KEYS = ("auto_promote", "inception_scoring_exception")
# Only these may differ between a set's D1-D4 entry and the live one.
MUTABLE_PROTECTED_FIELDS = ("weight", "rubric")
WEIGHT_MIN, WEIGHT_MAX = 0, 10


class DriverSetError(Exception):
    """A driver set could not be resolved or loaded. The message names the
    arc, the set and the path where they are known."""


# ---------------------------------------------------------------------------
# YAML: a loader that refuses repeated mapping keys (codex C5). safe_load keeps
# the last of two `driver_set:` lines, which would choose a set silently.
# ---------------------------------------------------------------------------
class _UniqueKeyLoader(yaml.SafeLoader):
    pass


def _construct_unique_mapping(loader, node, deep=False):
    seen = set()
    for key_node, _ in node.value:
        key = loader.construct_object(key_node, deep=deep)
        try:
            hashable = key in seen
        except TypeError:
            continue
        if hashable:
            raise yaml.constructor.ConstructorError(
                None, None, f"duplicate key {key!r}", key_node.start_mark)
        seen.add(key)
    return loader.construct_mapping(node, deep=deep)


_UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping)


def _load_yaml(path: Path, what: str):
    """Parse `path` with duplicate keys refused. DriverSetError on any failure."""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise DriverSetError(f"{what} {path} is unreadable: {exc}") from exc
    try:
        return yaml.load(text, Loader=_UniqueKeyLoader)  # noqa: S506 — SafeLoader subclass
    except yaml.YAMLError as exc:
        first = str(exc).strip().splitlines()[0] if str(exc).strip() else "parse error"
        raise DriverSetError(f"{what} {path} does not parse: {first}") from exc


# ---------------------------------------------------------------------------
# Arcs
# ---------------------------------------------------------------------------
_ARC_CACHE: dict = {}


class _ArcIndex:
    """Every arc file under .context/arcs/, parsed once, indexed by identity.

    An arc's identities are its file stem, its `id:` and its `slug:`. Two files
    sharing an identity is a refusal for any task that refers to it (codex C5).
    A file that does not parse is kept as an error and is a refusal for any
    reference it could match (its stem, or an id/slug line in its raw text).
    """

    def __init__(self, arcs_dir: Path):
        self.arcs_dir = arcs_dir
        self.by_identity: dict[str, list[Path]] = {}
        self.data: dict[Path, dict] = {}
        self.broken: dict[Path, tuple[str, str]] = {}  # path -> (reason, raw)
        if not arcs_dir.is_dir():
            return
        for path in sorted(arcs_dir.glob("*.yaml")):
            try:
                arc = _load_yaml(path, "arc file")
            except DriverSetError as exc:
                try:
                    raw = path.read_text(encoding="utf-8", errors="replace")
                except OSError:
                    raw = ""
                self.broken[path] = (str(exc), raw)
                continue
            if arc is None:
                arc = {}
            if not isinstance(arc, dict):
                self.broken[path] = (f"arc file {path} is not a mapping", "")
                continue
            self.data[path] = arc
            idents = {path.stem}
            for key in ("id", "slug"):
                val = arc.get(key)
                if isinstance(val, str) and val.strip():
                    idents.add(val.strip())
            for ident in idents:
                self.by_identity.setdefault(ident, []).append(path)

    def uses_sets(self) -> bool:
        """True when any arc names a driver set (a file that does not parse counts when its
        raw text mentions `driver_set`). When none does, every task resolves to the live file
        whatever its arc references say, so nothing about them can be ambiguous (T-4986: a
        stale `arc:` tag must not unrank a task in a project that uses no sets)."""
        return (any(isinstance(a, dict) and "driver_set" in a for a in self.data.values())
                or any("driver_set" in raw for _, raw in self.broken.values()))

    def _broken_candidates(self, ref: str) -> list[Path]:
        pat = re.compile(
            r"^\s*(?:id|slug)\s*:\s*['\"]?" + re.escape(ref) + r"['\"]?\s*(?:#.*)?$",
            re.MULTILINE)
        return [p for p, (_, raw) in self.broken.items()
                if p.stem == ref or pat.search(raw)]

    def find(self, ref: str) -> tuple[Path, dict] | None:
        """The one arc `ref` names, or None when no arc claims it.

        Raises DriverSetError when the reference is ambiguous (two files claim
        it) or a file it could name does not parse.
        """
        broken = self._broken_candidates(ref)
        if broken:
            raise DriverSetError(
                f"arc '{ref}': {self.broken[broken[0]][0]}")
        paths = self.by_identity.get(ref) or []
        if len(paths) > 1:
            names = ", ".join(str(p) for p in paths)
            raise DriverSetError(
                f"arc '{ref}' is claimed by more than one arc file ({names}); "
                f"arc ids and slugs must be unique")
        if not paths:
            return None
        return paths[0], self.data[paths[0]]

    def duplicates_of(self, path: Path) -> list[str]:
        """Identities of `path` that another arc file also claims."""
        return sorted(i for i, ps in self.by_identity.items()
                      if path in ps and len(ps) > 1)


def _arc_index(project_root: Path, arcs_dir=None) -> _ArcIndex:
    # `arcs_dir` overrides <root>/.context/arcs for a reader that carries its
    # own arcs seam (the estimator's ARCS_DIR, T-4985); the rule is the same.
    arcs_dir = Path(arcs_dir) if arcs_dir is not None \
        else Path(project_root) / ".context" / "arcs"
    try:
        key = tuple(sorted((p.name, p.stat().st_mtime_ns, p.stat().st_size)
                           for p in arcs_dir.glob("*.yaml")))
    except OSError:
        key = None
    hit = _ARC_CACHE.get(str(arcs_dir))
    if key is not None and hit is not None and hit[0] == key:
        return hit[1]
    idx = _ArcIndex(arcs_dir)
    _ARC_CACHE[str(arcs_dir)] = (key, idx)
    return idx


def _arc_label(arc: dict, path: Path | None) -> str:
    for key in ("slug", "id"):
        val = arc.get(key) if isinstance(arc, dict) else None
        if isinstance(val, str) and val.strip():
            return val.strip()
    return path.stem if path is not None else "<arc>"


def arc_set_name(arc: dict, label: str = "<arc>") -> str | None:
    """The set an arc names: None for the live file. Raises on a bad value.

    `driver_set:` absent -> None; `default` -> None. Present but empty or
    null is a refusal (opencode 8): it reads as a choice that was not made.
    """
    if not isinstance(arc, dict) or "driver_set" not in arc:
        return None
    raw = arc.get("driver_set")
    if raw is None or (isinstance(raw, str) and not raw.strip()):
        raise DriverSetError(
            f"arc '{label}' has an empty driver_set: value; remove the key or "
            f"name a set ('default' means the live policy/{LIVE_FILE})")
    if not isinstance(raw, str):
        raise DriverSetError(
            f"arc '{label}' has driver_set: {raw!r}, which is not a set name")
    name = raw.strip()
    _check_name(name, f"arc '{label}'")
    return None if name == DEFAULT_NAME else name


def _check_name(name: str, where: str) -> None:
    if not isinstance(name, str) or not NAME_RE.match(name):
        raise DriverSetError(
            f"{where}: driver set name {name!r} is invalid "
            f"(must match {NAME_RE.pattern})")


def _task_arc_refs(task_fm: dict) -> tuple[str | None, list[str]]:
    """(arc_id or None, [tag slugs]) from a parsed task frontmatter dict."""
    raw = task_fm.get("arc_id") if isinstance(task_fm, dict) else None
    arc_id = parse_arc_id_value(str(raw)) if raw is not None else ""
    tags = (task_fm.get("tags") or task_fm.get("_tags") or []) \
        if isinstance(task_fm, dict) else []
    if isinstance(tags, str):
        tags = [tags]
    slugs: list[str] = []
    for tag in tags:
        for slug in _TAG_ARC_RE.findall(str(tag)):
            if slug not in slugs:
                slugs.append(slug)
    return (arc_id or None), slugs


def _resolve(task_fm: dict, project_root, arcs_dir=None, idx=None
             ) -> tuple[str | None, str | None]:
    """(set name or None, label of the arc that chose it or None). `idx` lets a
    ranking pass reuse one arc snapshot instead of re-statting every arc file per
    task (T-4986: /approvals/content went past its render cap)."""
    root = Path(project_root)
    arc_id, slugs = _task_arc_refs(task_fm)
    if not arc_id and not slugs:
        return None, None
    if idx is None:
        idx = _arc_index(root, arcs_dir)
    if not idx.uses_sets():
        return None, None

    chosen: list[tuple[str, str | None, str]] = []  # (label, set, via)
    if arc_id:
        found = idx.find(arc_id)
        if found is None:
            raise DriverSetError(
                f"arc_id '{arc_id}' resolves to no arc under .context/arcs/; "
                f"the driver set cannot be chosen")
        path, arc = found
        label = _arc_label(arc, path)
        chosen.append((label, arc_set_name(arc, label), "arc_id"))

    missing: list[str] = []
    for slug in slugs:
        found = idx.find(slug)
        if found is None:
            missing.append(slug)
            continue
        path, arc = found
        label = _arc_label(arc, path)
        chosen.append((label, arc_set_name(arc, label), "tag"))
    if not arc_id and missing and len(missing) == len(slugs):
        raise DriverSetError(
            "every arc: tag names a missing arc ("
            + ", ".join(f"arc:{s}" for s in missing)
            + "); the driver set cannot be chosen")

    sets = {s for _, s, _ in chosen}
    if len(sets) > 1:
        detail = ", ".join(
            f"{label} ({via}) -> {s or DEFAULT_NAME}" for label, s, via in chosen)
        if arc_id and any(v == "tag" and s != chosen[0][1] for _, s, v in chosen):
            raise DriverSetError(
                f"arc_id and arc: tags name different driver sets: {detail}")
        raise DriverSetError(f"ambiguous driver set, arc: tags disagree: {detail}")
    name = chosen[0][1]
    label = next((lb for lb, s, _ in chosen if s == name), chosen[0][0])
    return name, label


def resolve_set_name(task_fm: dict, project_root, arcs_dir=None) -> str | None:
    """The driver set a task is scored under; None means the live file."""
    return _resolve(task_fm, project_root, arcs_dir)[0]


# ---------------------------------------------------------------------------
# Set files
# ---------------------------------------------------------------------------
_SET_CACHE: dict = {}


def set_path(name: str | None, project_root) -> Path:
    """Path of set `name`. None or 'default' is the live file.

    The name rule already keeps the path in policy/; the parent check after
    resolution is the belt-and-braces test from §1 (a symlink out also fails).
    """
    policy_dir = Path(project_root) / "policy"
    if name is None or name == DEFAULT_NAME:
        return policy_dir / LIVE_FILE
    _check_name(name, "set_path")
    path = policy_dir / f"value-drivers-{name}.yaml"
    if path.resolve().parent != policy_dir.resolve():
        raise DriverSetError(
            f"driver set '{name}' resolves to {path.resolve()}, outside {policy_dir}")
    return path


def _load_live(project_root) -> dict:
    path = set_path(None, project_root)
    if not path.is_file():
        raise DriverSetError(f"live driver file {path} is missing")
    policy = _load_yaml(path, "live driver file")
    if not isinstance(policy, dict):
        raise DriverSetError(f"live driver file {path} is not a mapping")
    return policy


def load_set(name: str | None, project_root) -> dict:
    """Parsed policy for set `name` (None/'default' = live file).

    A named set is validated against the live file and refused when invalid;
    it never falls back to the live file. The live file itself is returned as
    parsed (duplicate keys refused) — it is the reference, governed by its own
    rails. Cached per process by path, size and mtime of both files.
    """
    if name is None or name == DEFAULT_NAME:
        return _load_live(project_root)
    path = set_path(name, project_root)
    if not path.is_file():
        raise DriverSetError(f"driver set '{name}': file {path} is missing")
    live_path = set_path(None, project_root)
    try:
        key = (path.stat().st_mtime_ns, path.stat().st_size,
               live_path.stat().st_mtime_ns, live_path.stat().st_size)
    except OSError:
        key = None
    hit = _SET_CACHE.get(str(path))
    if key is not None and hit is not None and hit[0] == key:
        return hit[1]
    policy = _load_yaml(path, f"driver set '{name}': file")
    live = _load_live(project_root)
    errors, _ = validate_set(policy, live, path=path)
    if errors:
        raise DriverSetError(
            f"driver set '{name}' ({path}) is invalid: " + "; ".join(errors))
    _SET_CACHE[str(path)] = (key, policy)
    return policy


def _is_int_weight(val) -> bool:
    return isinstance(val, int) and not isinstance(val, bool)


def validate_set(policy, live_policy, path: Path | None = None
                 ) -> tuple[list[str], list[str]]:
    """Check a set file against the contract. Returns (errors, warnings).

    Errors make the set unusable; warnings are reported and do not.
    """
    errors: list[str] = []
    warnings_: list[str] = []
    if path is not None and Path(path).name == f"value-drivers-{DEFAULT_NAME}.yaml":
        warnings_.append(
            f"{Path(path).name}: 'default' is reserved for the live "
            f"policy/{LIVE_FILE}; this file is never read")
    if not isinstance(policy, dict):
        return ["the set file is not a mapping"], warnings_
    live = live_policy if isinstance(live_policy, dict) else {}

    for key in SET_KEYS:
        if key not in policy:
            errors.append(f"missing key '{key}'")
    for key in policy:
        if key in PROJECT_LEVEL_KEYS:
            warnings_.append(
                f"'{key}' is project-level and is ignored in a set file; it "
                f"applies only in policy/{LIVE_FILE}")
        elif key not in SET_KEYS:
            warnings_.append(f"unknown key '{key}' is ignored")
    if "version" in policy and "version" in live and policy["version"] != live["version"]:
        errors.append(
            f"version {policy['version']!r} differs from the live file's "
            f"{live['version']!r}")

    sections = {}
    for sec in ("protected_drivers", "free_drivers"):
        val = policy.get(sec)
        if val is None:
            val = []
        if not isinstance(val, list):
            errors.append(f"'{sec}' is not a list")
            val = []
        sections[sec] = val

    seen: dict[str, str] = {}
    by_id: dict[str, dict] = {}
    for sec, entries in sections.items():
        for i, entry in enumerate(entries):
            where = f"{sec}[{i}]"
            if not isinstance(entry, dict):
                errors.append(f"{where} is not a mapping")
                continue
            did = entry.get("id")
            if not isinstance(did, str) or not did.strip():
                errors.append(f"{where} has no id")
                continue
            if did in seen:
                if seen[did] != sec:
                    errors.append(
                        f"id '{did}' appears in both protected_drivers and free_drivers")
                else:
                    errors.append(f"id '{did}' appears more than once in {sec}")
                continue
            seen[did] = sec
            if sec == "protected_drivers":
                by_id[did] = entry
            if "weight" not in entry:
                errors.append(f"{did}: no weight")
            elif not _is_int_weight(entry["weight"]):
                errors.append(
                    f"{did}: weight {entry['weight']!r} is not an integer")
            elif not WEIGHT_MIN <= entry["weight"] <= WEIGHT_MAX:
                errors.append(
                    f"{did}: weight {entry['weight']} is outside "
                    f"{WEIGHT_MIN}-{WEIGHT_MAX}")

    live_protected = {e.get("id"): e for e in (live.get("protected_drivers") or [])
                      if isinstance(e, dict) and e.get("id")}
    for pid in PROTECTED_IDS:
        if pid not in by_id:
            if seen.get(pid) == "free_drivers":
                errors.append(f"{pid} is under free_drivers; it must be protected")
            else:
                errors.append(f"{pid} is missing from protected_drivers")
            continue
        ref = live_protected.get(pid)
        if ref is None:
            errors.append(f"{pid} is not in the live file to compare against")
            continue
        mine = by_id[pid]
        fields = (set(mine) | set(ref)) - set(MUTABLE_PROTECTED_FIELDS)
        for field in sorted(fields):
            if mine.get(field) != ref.get(field):
                errors.append(
                    f"{pid}: '{field}' differs from the live file (only "
                    f"{' and '.join(MUTABLE_PROTECTED_FIELDS)} may differ)")
    for pid in by_id:
        if pid not in PROTECTED_IDS:
            errors.append(
                f"{pid} is under protected_drivers; only D1-D4 are protected")
    return errors, warnings_


# ---------------------------------------------------------------------------
# Entry points for readers
# ---------------------------------------------------------------------------
def load_for_task(task_fm: dict, project_root, arcs_dir=None
                  ) -> tuple[str | None, dict]:
    """(set name or None, policy) for a task. Raises DriverSetError."""
    name, label = _resolve(task_fm, project_root, arcs_dir)
    try:
        return name, load_set(name, project_root)
    except DriverSetError as exc:
        if label:
            raise DriverSetError(f"arc '{label}': {exc}") from exc
        raise


def load_for_arc(arc_data: dict | None, project_root) -> tuple[str | None, dict]:
    """(set name or None, policy) for a parsed arc. Raises DriverSetError."""
    label = _arc_label(arc_data or {}, None)
    name = arc_set_name(arc_data or {}, label)
    try:
        return name, load_set(name, project_root)
    except DriverSetError as exc:
        raise DriverSetError(f"arc '{label}': {exc}") from exc


# ---------------------------------------------------------------------------
# Ranking surfaces (T-4986): per-task weights, memoised per set name
# ---------------------------------------------------------------------------
def policy_weights(policy) -> dict:
    """{driver_id: int weight} over protected + free drivers of a parsed policy.

    Same merge every ranking surface already used for the live file; an entry
    without an id or with an unparseable weight is skipped.
    """
    out: dict = {}
    if not isinstance(policy, dict):
        return out
    for section in ("protected_drivers", "free_drivers"):
        for d in (policy.get(section) or []):
            if not isinstance(d, dict) or not d.get("id"):
                continue
            try:
                out[d["id"]] = int(d.get("weight", 0))
            except (TypeError, ValueError):
                continue
    return out


def set_file_label(name: str | None, project_root) -> str:
    """'policy/value-drivers-<name>.yaml' (relative), for display."""
    try:
        return str(set_path(name, project_root).relative_to(Path(project_root)))
    except (ValueError, DriverSetError):
        return f"policy/value-drivers-{name}.yaml" if name else f"policy/{LIVE_FILE}"


class WeightResolver:
    """Per-task (or per-arc) driver weights for a ranking surface.

    One instance per ranking pass. The set name is resolved per task by the
    one rule above; each set's weights are loaded once (memoised per name,
    refusals too). `default_weights` lets a surface keep its own reading of
    the live file for default-set tasks, so the default path is unchanged;
    when None the live file is loaded through `load_set`.

    `resolve` / `resolve_arc` return (set name or None, weights) and raise
    DriverSetError with the arc label in the message. A refused task must be
    shown by the caller (T-4967 C4), never ranked under the live weights.
    """

    def __init__(self, project_root, default_weights: dict | None = None,
                 arcs_dir=None):
        self.root = Path(project_root)
        self.arcs_dir = arcs_dir
        self.default = default_weights
        self._sets: dict = {}  # name -> weights dict | DriverSetError
        self._policies: dict = {}
        # One arc snapshot per pass; when no arc names a set, every task is default.
        self._idx = _arc_index(self.root, arcs_dir)
        self._uses_sets = self._idx.uses_sets()

    def policy_for_set(self, name: str | None) -> dict:
        """Parsed policy of set `name` (None = live file). Raises DriverSetError."""
        if name in self._policies:
            hit = self._policies[name]
            if isinstance(hit, DriverSetError):
                raise hit
            return hit
        try:
            pol = load_set(name, self.root)
        except DriverSetError as exc:
            self._policies[name] = exc
            raise
        self._policies[name] = pol
        return pol

    def weights_for_set(self, name: str | None, label: str | None = None) -> dict:
        if name is None and self.default is not None:
            return self.default
        if name not in self._sets:
            try:
                self._sets[name] = policy_weights(self.policy_for_set(name))
            except DriverSetError as exc:
                self._sets[name] = exc
        hit = self._sets[name]
        if isinstance(hit, DriverSetError):
            if label:
                raise DriverSetError(f"arc '{label}': {hit}") from hit
            raise hit
        return hit

    def resolve(self, task_fm: dict) -> tuple[str | None, dict]:
        if not self._uses_sets:
            return None, self.weights_for_set(None)
        name, label = _resolve(task_fm or {}, self.root, self.arcs_dir, idx=self._idx)
        return name, self.weights_for_set(name, label)

    def resolve_arc(self, arc_data: dict | None) -> tuple[str | None, dict]:
        label = _arc_label(arc_data or {}, None)
        name = arc_set_name(arc_data or {}, label)
        return name, self.weights_for_set(name, label)


# ---------------------------------------------------------------------------
# Audit CLI
# ---------------------------------------------------------------------------
_DRIVER_SET_LINE_RE = re.compile(r"^driver_set\s*:", re.MULTILINE)


def audit_rows(project_root) -> list[tuple[str, str, str]]:
    """(level, arc file, message) for every arc that names a set.

    Silent (empty) when no arc carries `driver_set:`.
    """
    root = Path(project_root)
    idx = _ArcIndex(root / ".context" / "arcs")
    rows: list[tuple[str, str, str]] = []
    for path, (reason, raw) in sorted(idx.broken.items()):
        if _DRIVER_SET_LINE_RE.search(raw):
            rows.append(("FAIL", path.name, reason))
    for path, arc in sorted(idx.data.items()):
        if "driver_set" not in arc:
            continue
        label = _arc_label(arc, path)
        dups = idx.duplicates_of(path)
        if dups:
            rows.append(("FAIL", path.name,
                         f"arc '{label}': id/slug {', '.join(dups)} also claimed "
                         f"by another arc file"))
            continue
        try:
            name, _ = load_for_arc(arc, root)
        except DriverSetError as exc:
            rows.append(("FAIL", path.name, str(exc)))
            continue
        if name is not None:
            sp = set_path(name, root)
            try:
                _, warns = validate_set(_load_yaml(sp, "set file"),
                                        _load_live(root), path=sp)
            except DriverSetError:
                warns = []
            for w in warns:
                rows.append(("WARN", path.name, f"driver set '{name}' ({sp.name}): {w}"))
        rows.append(("OK", path.name, name or DEFAULT_NAME))
    reserved = root / "policy" / f"value-drivers-{DEFAULT_NAME}.yaml"
    if reserved.exists():
        rows.append(("WARN", reserved.name,
                     f"'default' is reserved for the live policy/{LIVE_FILE}; "
                     f"this file is never read"))
    return rows


def _main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] != "audit":
        print("usage: driver_sets.py audit PROJECT_ROOT", file=sys.stderr)
        return 2
    for level, where, msg in audit_rows(argv[2]):
        print(f"{level}\t{where}\t{msg.replace(chr(9), ' ').replace(chr(10), ' ')}")
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
