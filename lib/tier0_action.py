"""Tier 0 approvals keyed to the ACTION, not the command text (T-3593, T-3576 GO).

Before this module a Tier 0 approval was the sha256 of the whole (whitespace-
normalised) command. A retry that changed nothing but incidental text — ``| tail
-12`` instead of ``| tail -14``, flag order, a trailing ``2>&1`` — hashed
differently, voided the operator's approval, and taught agents to route the
operation through a script, which the text gate cannot see at all (T-2742).

An approval here names what the operator actually decided about:

    force-push        {remote, ref}          (git push --force / +ref)
    branch-delete     {remote, ref[, repo]}  (git push --delete / :ref, git branch -D)
    hard-reset        {repo, branch, target} (git reset --hard [<commit>])
    recursive-delete  {path}                 (rm -r)

A command maps to actions only when EVERY segment the Tier 0 patterns flag is
fully explained by this classifier, and every PATTERN that flags a segment is
covered by an action verb that segment produced (a ``--no-verify`` riding on a
force push is a second decision the operator must see; it is never folded into
the force-push approval). Anything it cannot read with certainty —
a ``$(...)``, a variable, ``--all``, an unknown cwd, an unmapped verb — makes the
whole command *unmapped*, and the hook falls back to the legacy command-hash path
unchanged. The failure direction is always "less can be approved", never "more
is admitted".

── Single use, bounded time, two layers ─────────────────────────────────────
Each approval is consumed on first matching use and expires after the grant TTL
(TIER0_APPROVAL_TTL, same clock as the legacy leg). Push verbs have two
enforcement points — the text gate (check-tier0.sh) and git's pre-push hook
(T-3594) — so the text gate only *admits* a push approval (it cannot be admitted
twice) and the pre-push hook *consumes* it. A push launched from a script never
passes the text gate and consumes the approval at pre-push directly.

Every state change (approve, admit, consume, expire) is appended to
``.context/working/tier0-action-events.jsonl``; admissions and consumptions also
go to ``.context/bypass-log.yaml`` with ``match_path: action``.
"""

from __future__ import annotations

import contextlib
import datetime
import fcntl
import json
import os
import re
import subprocess
import sys
import time
import uuid

VERBS = ("force-push", "branch-delete", "hard-reset", "recursive-delete")
PUSH_VERBS = ("force-push", "branch-delete")
LOCAL_REMOTE = "(local)"


# ── Paths ─────────────────────────────────────────────────────────────────────

def _working(root: str) -> str:
    return os.path.join(root, ".context", "working")


def store_path(root: str) -> str:
    return os.path.join(_working(root), "tier0-action-approvals.json")


def events_path(root: str) -> str:
    return os.path.join(_working(root), "tier0-action-events.jsonl")


def pending_path(root: str) -> str:
    return os.path.join(_working(root), ".tier0-action.pending.json")


def _now_iso(ts: float | None = None) -> str:
    return datetime.datetime.fromtimestamp(
        time.time() if ts is None else ts, datetime.timezone.utc
    ).strftime("%Y-%m-%dT%H:%M:%SZ")


# ── Shell segmentation and tokenising ────────────────────────────────────────

class Unmappable(Exception):
    """The command cannot be read with certainty — use the hash path."""


def split_segments(cmd: str) -> list[str]:
    """Split on ; && || | & and newlines that sit OUTSIDE quotes."""
    return [s for s, _ in split_segments_seps(cmd)]


def split_segments_seps(cmd: str) -> list[tuple[str, str]]:
    """Like :func:`split_segments`, keeping the separator that FOLLOWS each
    segment (``""`` for the last). ``cd`` only carries across ``&&`` (T-3593 R3),
    so the classifier needs to know which separator it was."""
    segs, cur, i, n = [], [], 0, len(cmd)
    sq = dq = False
    while i < n:
        c = cmd[i]
        if sq:
            cur.append(c)
            if c == "'":
                sq = False
        elif dq:
            cur.append(c)
            if c == "\\" and i + 1 < n:
                cur.append(cmd[i + 1])
                i += 1
            elif c == '"':
                dq = False
        elif c == "\\" and i + 1 < n:
            cur.append(c)
            cur.append(cmd[i + 1])
            i += 1
        elif c == "'":
            sq = True
            cur.append(c)
        elif c == '"':
            dq = True
            cur.append(c)
        elif c == "#" and (not cur or cur[-1].isspace()):
            while i + 1 < n and cmd[i + 1] != "\n":
                i += 1                      # comment: drop to end of line
        elif c in ";\n" or c in "|&":
            # `>&` / `&>` / `2>&1` are redirections, not separators.
            prev = cur[-1] if cur else ""
            if c == "&" and (prev in "<>" or (i + 1 < n and cmd[i + 1] == ">")):
                cur.append(c)
            else:
                sep = c
                if i + 1 < n and cmd[i + 1] == c and c in "|&":
                    sep = c + c
                    i += 1
                segs.append(("".join(cur), "\n" if c == "\n" else sep))
                cur = []
        else:
            cur.append(c)
        i += 1
    if sq or dq:
        raise Unmappable("unbalanced quotes")
    segs.append(("".join(cur), ""))
    # An empty segment still owns its separator (`a ; ; b`); keep the weakest.
    out: list[tuple[str, str]] = []
    for s, sep in segs:
        if s.strip():
            out.append((s.strip(), sep))
        elif out and sep != "&&":
            out[-1] = (out[-1][0], sep or out[-1][1])
    return out


def tokenize(seg: str) -> list[str]:
    """POSIX-ish word split. Drops redirections; refuses anything dynamic.

    Unquoted ``$``, backticks, parentheses and braces raise :class:`Unmappable`:
    their value is not knowable from the text, so no action can be claimed.
    """
    words: list[str] = []
    cur: list[str] = []
    have = False          # a word is in progress (possibly empty "")
    quoted_any = False
    i, n = 0, len(seg)
    skip_next_word = False

    def flush():
        nonlocal cur, have, quoted_any, skip_next_word
        if have:
            w = "".join(cur)
            if skip_next_word:
                skip_next_word = False
            else:
                words.append(w)
        cur, have, quoted_any = [], False, False

    while i < n:
        c = seg[i]
        if c.isspace():
            flush()
        elif c == "'":
            j = seg.find("'", i + 1)
            if j < 0:
                raise Unmappable("unbalanced quote")
            cur.append(seg[i + 1:j])
            have = quoted_any = True
            i = j
        elif c == '"':
            j = i + 1
            while j < n and seg[j] != '"':
                if seg[j] == "\\" and j + 1 < n:
                    cur.append(seg[j + 1])
                    j += 2
                    continue
                if seg[j] in "$`":
                    raise Unmappable("expansion inside double quotes")
                cur.append(seg[j])
                j += 1
            if j >= n:
                raise Unmappable("unbalanced quote")
            have = quoted_any = True
            i = j
        elif c == "\\" and i + 1 < n:
            cur.append(seg[i + 1])
            have = True
            i += 1
        elif c == "#" and not have:
            break                           # comment to end of segment
        elif c == "&" and i + 1 < n and seg[i + 1] == ">":
            flush()
            i += 1
            continue                        # `&>file` — handled as a redirect next
        elif c in "$`(){}":
            raise Unmappable(f"dynamic shell construct {c!r}")
        elif c in "<>":
            # Redirection. Leading all-digit unquoted word is its fd.
            if have and not quoted_any and "".join(cur).isdigit():
                cur, have = [], False
            else:
                flush()
            j = i + 1
            while j < n and seg[j] in "<>&-":
                j += 1
            k = j
            while k < n and seg[k].isdigit():
                k += 1
            if k > j and (k >= n or seg[k].isspace()):
                j = k                       # >&1 style: fd target, nothing to skip
            elif j < n and not seg[j].isspace():
                pass                        # >file — the rest of this word is the target
            else:
                skip_next_word = True       # > file
            # Consume an attached target word.
            if j < n and not seg[j].isspace() and not skip_next_word:
                while j < n and not seg[j].isspace():
                    if seg[j] in "$`(){}'\"":
                        raise Unmappable("dynamic redirect target")
                    j += 1
            i = j
            continue
        else:
            cur.append(c)
            have = True
        i += 1
    flush()
    if skip_next_word:
        raise Unmappable("dangling redirect")
    return words


_ENV_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
_PREFIX_WORDS = {"sudo", "command", "nohup", "time", "exec"}


def _strip_prefix(words: list[str]) -> list[str]:
    while words and (_ENV_ASSIGN.match(words[0]) or words[0] in _PREFIX_WORDS):
        if words[0] in _PREFIX_WORDS and len(words) > 1 and words[1].startswith("-"):
            raise Unmappable(f"{words[0]} with options")
        words = words[1:]
    return words


# ── Git helpers ───────────────────────────────────────────────────────────────

def _git(cwd: str, *args: str) -> str:
    try:
        out = subprocess.run(
            ["git", "-C", cwd, *args], capture_output=True, text=True, timeout=5
        )
    except Exception as exc:  # pragma: no cover - environment
        raise Unmappable(f"git failed: {exc}")
    if out.returncode != 0:
        raise Unmappable(f"git {' '.join(args)} failed in {cwd}")
    return out.stdout.strip()


def normalize_ref(ref: str) -> str:
    ref = ref.lstrip("+")
    if ref.startswith("refs/heads/"):
        ref = ref[len("refs/heads/"):]
    return ref


def _current_branch(cwd: str) -> str:
    return _git(cwd, "symbolic-ref", "--short", "HEAD")


def _toplevel(cwd: str) -> str:
    return os.path.realpath(_git(cwd, "rev-parse", "--show-toplevel"))


# ── Action classification ────────────────────────────────────────────────────

def action(verb: str, **targets: str) -> dict:
    assert verb in VERBS, verb
    return {"verb": verb, "targets": dict(sorted(targets.items()))}


def action_key(a: dict) -> str:
    t = a["targets"]
    return a["verb"] + "|" + "|".join(f"{k}={t[k]}" for k in sorted(t))


def describe(a: dict) -> str:
    """The action in plain words, as shown to the operator."""
    t, v = a["targets"], a["verb"]
    if v == "force-push":
        return (f"FORCE-PUSH ref '{t['ref']}' to remote '{t['remote']}' "
                "(may overwrite remote history)")
    if v == "branch-delete":
        if t["remote"] == LOCAL_REMOTE:
            return f"DELETE local branch '{t['ref']}' in {t.get('repo', '?')} (even if unmerged)"
        return f"DELETE ref '{t['ref']}' on remote '{t['remote']}'"
    if v == "hard-reset":
        return (f"HARD-RESET branch '{t['branch']}' in {t['repo']} to commit "
                f"{t.get('target', '?')[:12]} (moves the branch there and discards "
                "uncommitted changes)")
    if v == "recursive-delete":
        return f"RECURSIVELY DELETE {t['path']}"
    return action_key(a)


def _classify_push(args: list[str], cwd: str | None) -> list[dict]:
    force = delete = False
    positional: list[str] = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--":
            positional.extend(args[i + 1:])
            break
        if a.startswith("--"):
            name = a.split("=", 1)[0]
            if name in ("--force", "--force-with-lease"):
                force = True
            elif name == "--delete":
                delete = True
            elif name == "--no-verify":
                # A second Tier 0 decision (HOOK BYPASS) — and it would skip the
                # pre-push hook that consumes this approval (T-3593 R1).
                raise Unmappable("push --no-verify")
            elif name in ("--all", "--mirror", "--tags", "--prune", "--branches"):
                raise Unmappable(f"push {name} targets are not enumerable from the text")
            elif name in ("--repo", "--receive-pack", "--exec", "--push-option") and "=" not in a:
                if name == "--repo":
                    raise Unmappable("push --repo")
                i += 1
            elif name == "--repo":
                raise Unmappable("push --repo")
        elif a.startswith("-") and len(a) > 1:
            flags = a[1:]
            for j, f in enumerate(flags):
                if f == "f":
                    force = True
                elif f == "d":
                    delete = True
                elif f == "o":
                    if j == len(flags) - 1:
                        i += 1
                    break
        else:
            positional.append(a)
        i += 1
    if len(positional) < 2:
        raise Unmappable("push without an explicit remote and refspec")
    remote, specs = positional[0], positional[1:]
    out: list[dict] = []
    for spec in specs:
        plus = spec.startswith("+")
        body = spec[1:] if plus else spec
        if delete:
            if ":" in body:
                raise Unmappable("--delete with a src:dst refspec")
            out.append(action("branch-delete", remote=remote, ref=normalize_ref(body)))
            continue
        if body.startswith(":"):
            out.append(action("branch-delete", remote=remote, ref=normalize_ref(body[1:])))
            continue
        src, _, dst = body.partition(":")
        dst = dst or src
        if dst in ("HEAD", "@") or dst == "":
            if cwd is None:
                raise Unmappable("HEAD refspec with unknown cwd")
            dst = _current_branch(cwd)
        if any(ch in dst for ch in "*?["):
            raise Unmappable("wildcard refspec")
        if force or plus:
            out.append(action("force-push", remote=remote, ref=normalize_ref(dst)))
    return out


def _classify_git(words: list[str], cwd: str | None) -> tuple[list[dict], str | None]:
    i = 1
    while i < len(words) and words[i].startswith("-"):
        opt = words[i]
        if opt == "-C" and i + 1 < len(words):
            target = words[i + 1]
            if cwd is None and not os.path.isabs(target):
                cwd = None
            else:
                cwd = os.path.normpath(os.path.join(cwd or "/", target))
            i += 2
        elif opt == "-c" or opt.startswith("--config-env") or opt == "--exec-path":
            # Any config (core.hooksPath, alias.*, ...) can change what runs or
            # skip the hook that consumes the approval (T-3593 R1, T-3594 A2).
            raise Unmappable(f"git {opt}")
        elif opt in ("--no-pager", "--no-replace-objects", "-P"):
            i += 1
        else:
            raise Unmappable(f"git global option {opt}")
    if i >= len(words):
        raise Unmappable("bare git")
    sub, args = words[i], words[i + 1:]
    if "--no-verify" in args:
        raise Unmappable("--no-verify is its own Tier 0 decision")
    if sub == "push":
        return _classify_push(args, cwd), cwd
    if sub == "reset":
        if "--hard" not in args:
            return [], cwd
        if cwd is None:
            raise Unmappable("reset with unknown cwd")
        revs = []
        for a in args:
            if a in ("--hard", "-q", "--quiet"):
                continue
            if a.startswith("-"):
                raise Unmappable(f"reset option {a}")
            revs.append(a)
        if len(revs) > 1:
            raise Unmappable("reset with more than one revision")
        rev = revs[0] if revs else "HEAD"
        # T-3593 R4: the approval names WHERE the branch moves to, resolved now.
        target = _git(cwd, "rev-parse", "--verify", "-q", rev + "^{commit}")
        return [action("hard-reset", repo=_toplevel(cwd), branch=_current_branch(cwd),
                       target=target)], cwd
    if sub == "branch":
        force_del = any(a == "-D" or (a.startswith("-") and not a.startswith("--") and "D" in a)
                        for a in args)
        force_del = force_del or (("-d" in args or "--delete" in args)
                                  and ("-f" in args or "--force" in args))
        if not force_del:
            return [], cwd
        names = [a for a in args if not a.startswith("-")]
        if not names:
            raise Unmappable("branch -D without a name")
        if cwd is None:
            raise Unmappable("branch -D with unknown cwd")
        repo = _toplevel(cwd)
        return [action("branch-delete", remote=LOCAL_REMOTE, ref=normalize_ref(n), repo=repo)
                for n in names], cwd
    raise Unmappable(f"git {sub} is not an action verb")


def _classify_rm(args: list[str], cwd: str | None) -> list[dict]:
    recursive, paths, opts_done = False, [], False
    for a in args:
        if not opts_done and a == "--":
            opts_done = True
        elif not opts_done and a.startswith("--"):
            if a == "--recursive":
                recursive = True
        elif not opts_done and a.startswith("-") and len(a) > 1:
            if "r" in a[1:] or "R" in a[1:]:
                recursive = True
        else:
            paths.append(a)
    if not recursive:
        return []
    if not paths:
        raise Unmappable("rm -r without a path")
    out = []
    for p in paths:
        if p.startswith("~"):
            p = os.path.expanduser(p)
        if not os.path.isabs(p):
            if cwd is None:
                raise Unmappable("relative rm path with unknown cwd")
            p = os.path.join(cwd, p)
        norm = os.path.normpath(p)          # trailing slash is not a different target
        out.append(action("recursive-delete", path=norm))
    return out


def classify_segment(seg: str, cwd: str | None) -> tuple[list[dict], str | None]:
    """Return (actions, new_cwd). Raises Unmappable when not certain."""
    words = _strip_prefix(tokenize(seg))
    if not words:
        return [], cwd
    head = words[0]
    if head == "cd":
        if len(words) != 2 or words[1] == "-":
            return [], None
        target = os.path.expanduser(words[1])
        if os.path.isabs(target):
            return [], os.path.normpath(target)
        return [], (os.path.normpath(os.path.join(cwd, target)) if cwd else None)
    if head in ("pushd", "popd"):
        return [], None
    if head == "git":
        # `git -C dir` scopes to this one command; the shell cwd is unchanged.
        acts, _ = _classify_git(words, cwd)
        return acts, cwd
    if head == "rm":
        return _classify_rm(words[1:], cwd), cwd
    raise Unmappable(f"{head} is not an action verb")


# Which verb explains which Tier 0 pattern (by its description prefix, from
# check-tier0.sh PATTERNS). A flagged segment whose patterns are not ALL covered
# by the verbs it produced is unmapped (T-3593 R1).
PATTERN_COVERAGE = {
    "FORCE PUSH": ("force-push",),
    "REMOTE REF DELETE": ("branch-delete",),
    "HARD RESET": ("hard-reset",),
    "FORCE DELETE BRANCH": ("branch-delete",),
    "RECURSIVE DELETE": ("recursive-delete",),
}


def _covered(descriptions, acts: list[dict]) -> bool:
    verbs = {a["verb"] for a in acts}
    for d in descriptions:
        prefix = str(d).split(":", 1)[0].strip()
        if not verbs.intersection(PATTERN_COVERAGE.get(prefix, ())):
            return False
    return True


def classify(command: str, is_flagged, cwd: str | None) -> list[dict] | None:
    """Map a blocked command to actions, or None when it is unmapped.

    ``is_flagged(segment_text)`` is the hook's own Tier 0 pattern test, passed in
    so the pattern list stays single-sourced in check-tier0.sh. It returns the
    list of matching pattern descriptions (a bare bool is accepted for older
    callers, but then pattern coverage cannot be checked). Every flagged segment
    must classify to at least one action, and every pattern flagging it must be
    covered by those actions' verbs; otherwise the WHOLE command is unmapped.

    cwd tracking (T-3593 R3): a segment's cwd change carries to the next segment
    only across ``&&`` and only when the segment is not in a pipeline. After
    ``;``, ``||``, ``|``, ``&`` or a newline — where a failed ``cd`` leaves the
    old cwd in place — and after any segment this module cannot read, the cwd
    becomes unknown, so a relative target is unmapped.
    """
    try:
        segs = split_segments_seps(command)
    except Unmappable:
        return None
    actions: list[dict] = []
    saw_flagged = False
    prev_sep = ""
    for seg, sep in segs:
        flagged = is_flagged(seg)
        try:
            acts, new_cwd = classify_segment(seg, cwd)
        except Unmappable:
            if flagged:
                return None
            # An unreadable segment (`source x`, `{ cd x; }`, `eval ...`) may
            # change the cwd in ways the text does not show.
            cwd, prev_sep = None, sep
            continue
        if flagged:
            saw_flagged = True
            if not acts:
                return None
            if not isinstance(flagged, bool) and not _covered(flagged, acts):
                return None
            actions.extend(acts)
        if new_cwd != cwd:
            carries = sep == "&&" and prev_sep != "|"
            cwd = new_cwd if carries else None
        prev_sep = sep
    if not saw_flagged or not actions:
        return None
    # De-duplicate, stable.
    seen, uniq = set(), []
    for a in actions:
        k = action_key(a)
        if k not in seen:
            seen.add(k)
            uniq.append(a)
    return uniq


# ── Store ─────────────────────────────────────────────────────────────────────

@contextlib.contextmanager
def _locked(root: str):
    os.makedirs(_working(root), exist_ok=True)
    lock = store_path(root) + ".lock"
    with open(lock, "a") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)


def _load(root: str) -> list[dict]:
    try:
        with open(store_path(root)) as fh:
            data = json.load(fh)
        return data.get("approvals", []) if isinstance(data, dict) else []
    except (FileNotFoundError, ValueError):
        return []


def _save(root: str, recs: list[dict]) -> None:
    path = store_path(root)
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump({"approvals": recs}, fh, indent=2, sort_keys=True)
    os.replace(tmp, path)


def log_event(root: str, event: str, **fields) -> None:
    rec = {"ts": _now_iso(), "event": event, **fields}
    try:
        os.makedirs(_working(root), exist_ok=True)
        with open(events_path(root), "a") as fh:
            fh.write(json.dumps(rec, sort_keys=True) + "\n")
    except OSError:
        pass


def _bypass_log(root: str, a: dict, layer: str, preview: str = "",
                approved_by: str = "unknown") -> None:
    try:
        import yaml
    except Exception:
        return
    log_file = os.path.join(root, ".context", "bypass-log.yaml")
    entry = {
        "timestamp": _now_iso(),
        "tier": 0,
        "risk": describe(a),
        "action_key": action_key(a),
        "command_preview": preview[:120],
        # Carried from the approval record, never asserted here (T-3593 R2).
        "authorized_by": approved_by,
        "mechanism": "fw tier0 approve (action)",
        "match_path": "action",
        "layer": layer,
    }
    try:
        data = {}
        if os.path.exists(log_file):
            with open(log_file) as fh:
                data = yaml.safe_load(fh) or {}
        data.setdefault("bypasses", []).append(entry)
        tmp = log_file + ".tmp"
        with open(tmp, "w") as fh:
            yaml.dump(data, fh, default_flow_style=False, sort_keys=False)
        os.replace(tmp, log_file)
    except Exception:
        pass


def _expire(root: str, recs: list[dict], now: float) -> bool:
    changed = False
    for r in recs:
        if r.get("state") in ("approved", "admitted") and now >= r.get("expires", 0):
            r["state"] = "expired"
            changed = True
            log_event(root, "expired", id=r["id"], action_key=r["key"])
    return changed


def approve(root: str, actions: list[dict], ttl: int, approved_by: str = "human",
            now: float | None = None) -> list[dict]:
    now = time.time() if now is None else now
    new = []
    with _locked(root):
        recs = _load(root)
        _expire(root, recs, now)
        for a in actions:
            rec = {
                "id": "T0A-" + uuid.uuid4().hex[:10],
                "verb": a["verb"],
                "targets": a["targets"],
                "key": action_key(a),
                "scope": "single-use",
                "approved_by": approved_by,
                "ts": now,
                "expires": now + ttl,
                "state": "approved",
            }
            recs.append(rec)
            new.append(rec)
            log_event(root, "approved", id=rec["id"], action_key=rec["key"],
                      approved_by=approved_by, expires=_now_iso(rec["expires"]))
        _save(root, recs)
    return new


def use(root: str, actions: list[dict], layer: str, preview: str = "",
        now: float | None = None) -> bool:
    """All-or-nothing: every action needs a live approval, else nothing changes.

    layer='text-gate': push verbs are ADMITTED (pre-push consumes them later);
    other verbs are consumed. layer='pre-push': consumes approved or admitted.
    """
    now = time.time() if now is None else now
    with _locked(root):
        recs = _load(root)
        changed = _expire(root, recs, now)
        picks = []
        taken = set()
        for a in actions:
            key = action_key(a)
            ok_states = ("approved",) if layer == "text-gate" else ("approved", "admitted")
            hit = next((r for r in recs if r["key"] == key and r["state"] in ok_states
                        and r["id"] not in taken), None)
            if hit is None:
                if changed:
                    _save(root, recs)
                return False
            picks.append((a, hit))
            taken.add(hit["id"])
        for a, r in picks:
            if layer == "text-gate" and a["verb"] in PUSH_VERBS:
                r["state"], r["admitted_at"] = "admitted", now
                log_event(root, "admitted", id=r["id"], action_key=r["key"], layer=layer)
            else:
                r["state"], r["consumed_at"], r["consumed_by"] = "consumed", now, layer
                log_event(root, "consumed", id=r["id"], action_key=r["key"], layer=layer)
            _bypass_log(root, a, layer, preview, r.get("approved_by", "unknown"))
        _save(root, recs)
    return True


def live(root: str, now: float | None = None) -> list[dict]:
    now = time.time() if now is None else now
    with _locked(root):
        recs = _load(root)
        if _expire(root, recs, now):
            _save(root, recs)
    return [r for r in recs if r["state"] in ("approved", "admitted")]


def write_pending(root: str, actions: list[dict], source: str, preview: str = "",
                  command_hash: str = "") -> None:
    os.makedirs(_working(root), exist_ok=True)
    data = {"ts": time.time(), "source": source, "command_preview": preview[:200],
            "command_hash": command_hash, "actions": actions}
    tmp = pending_path(root) + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(data, fh, indent=2)
    os.replace(tmp, pending_path(root))


def read_pending(root: str) -> dict | None:
    try:
        with open(pending_path(root)) as fh:
            return json.load(fh)
    except (FileNotFoundError, ValueError):
        return None


# ── CLI (used by check-tier0.sh, bin/fw tier0, and the pre-push hook) ────────

def _main(argv: list[str]) -> int:
    root = os.environ.get("PROJECT_ROOT") or os.getcwd()
    if not argv:
        print("usage: tier0_action.py {pending-show|approve-pending|use|status|prepush}", file=sys.stderr)
        return 2
    cmd = argv[0]
    if cmd == "pending-show":
        p = read_pending(root)
        if not p or not p.get("actions"):
            return 1
        for a in p["actions"]:
            print(describe(a))
        return 0
    if cmd == "approve-pending":
        # approve-pending [ttl] [--i-am-human]. The human check lives HERE, not
        # only in bin/fw, so the direct module path cannot skip it (T-3593 R2).
        rest = [a for a in argv[1:] if a != "--i-am-human"]
        override = "--i-am-human" in argv[1:]
        ttl = int(rest[0]) if rest else 300
        if os.environ.get("CLAUDECODE") == "1":
            if not override:
                print("Refused: Tier 0 approval is human-only (CLAUDECODE=1). An agent "
                      "may not approve its own Tier 0 action.", file=sys.stderr)
                return 3
            approved_by = "agent-override"
        else:
            approved_by = "human"
        p = read_pending(root)
        if not p or not p.get("actions"):
            return 1
        for rec in approve(root, p["actions"], ttl, approved_by=approved_by):
            print(f"{rec['id']}  {describe(rec)}")
        os.remove(pending_path(root))
        print(p.get("command_hash", ""), file=sys.stderr)
        return 0
    if cmd == "use":
        # use <layer> <actions-json> [preview]
        acts = json.loads(argv[2])
        return 0 if use(root, acts, argv[1], argv[3] if len(argv) > 3 else "") else 1
    if cmd == "write-pending":
        # write-pending <source> <actions-json> [preview] [hash]
        write_pending(root, json.loads(argv[2]), argv[1],
                      argv[3] if len(argv) > 3 else "", argv[4] if len(argv) > 4 else "")
        return 0
    if cmd == "describe":
        for a in json.loads(argv[1]):
            print(describe(a))
        return 0
    if cmd == "status":
        recs = live(root)
        for r in recs:
            left = int(r["expires"] - time.time())
            print(f"{r['id']}  {r['state']:<8}  {left:>4}s left  {describe(r)}")
        return 0
    if cmd == "prepush":
        # prepush <remote> <verb> <ref> [<verb> <ref> ...] (T-3594). All-or-
        # nothing: consume one approval per ref update, or consume none, write
        # the whole set as a pending request and fail.
        remote, rest = argv[1], argv[2:]
        if not rest or len(rest) % 2:
            print("usage: prepush <remote> <verb> <ref> [<verb> <ref> ...]", file=sys.stderr)
            return 2
        acts = [action(rest[i], remote=remote, ref=normalize_ref(rest[i + 1]))
                for i in range(0, len(rest), 2)]
        preview = f"git push {remote} " + " ".join(rest[i + 1] for i in range(0, len(rest), 2))
        if use(root, acts, "pre-push", preview):
            for a in acts:
                print(describe(a))
            return 0
        write_pending(root, acts, "pre-push", preview)
        return 1
    print(f"unknown subcommand {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
