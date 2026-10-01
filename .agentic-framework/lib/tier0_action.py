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

A command maps to actions only when it is spelled in a small explicit grammar
(round 5, see "The grammar" below): ``cd PATH &&`` zero or more times, then one
``git`` or ``rm`` segment, plain words only. Every pattern that flags it must be
covered by an action verb it produced (a ``--no-verify`` riding on a force push
is a second decision the operator must see; it is never folded into the
force-push approval). Anything else — a quote, a variable, a pipe, ``;``, a
wrapper, an unknown cwd, an unmapped verb — makes the command *unmapped*, and
the hook falls back to the exact-text approval. The failure direction is always
"less can be approved", never "more is admitted".

── Single use, bounded time, two layers ─────────────────────────────────────
Each approval is consumed on first matching use and expires after the grant TTL
(TIER0_APPROVAL_TTL, same clock as the legacy leg). Push verbs have two
enforcement points — the text gate (check-tier0.sh) and git's pre-push hook
(T-3594) — so the text gate only *admits* a push approval (it cannot be admitted
twice) and the pre-push hook *consumes* it. A push launched from a script never
passes the text gate and consumes the approval at pre-push directly. An
admitted push approval that pre-push has not consumed within ADMIT_TTL expires.

"Once" means one TOOL CALL (round 4): a hook registered twice fires twice for
one call, and the second fire is recognised by the PreToolUse ``tool_use_id``
stamped on the records the first fire used — never by text or time.

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
# OBS-568: an ADMITTED push approval is the text gate saying "the push you just
# typed may run". Its pre-push consumption follows within seconds; left for the
# whole grant TTL it is a second use waiting for any later push (the R1 chain).
ADMIT_TTL = int(os.environ.get("TIER0_ADMIT_TTL", "60"))


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


# ── The grammar (T-3593 round 5) ─────────────────────────────────────────────
#
# Rounds 1-4 parsed shell and then denied the spellings reviewers found:
# `command export`, a quoted 'export', `git -C /tmp/a\ b`, `sudo`, brace
# expansion, $'..' quoting. Each review found one more, because a denylist over
# shell cannot be complete. Round 5 inverts it: a command maps to an ACTION only
# when it is spelled in this small grammar, and EVERYTHING else is unmapped and
# takes the exact-text approval path (the operator sees the literal command):
#
#     command  := ( "cd" PATH "&&" )*  action
#     action   := "git" [ "-C" PATH | "-P" | "--no-pager" ]* SUBCOMMAND WORD*
#               | "rm" OPTION* PATH+
#     WORD     := [A-Za-z0-9._/:=@+%,-]+
#     PATH     := a WORD with no ".." component that does not start with "-"
#
# Separators are `&&` only. Not one quote, backslash, `$`, backtick, brace,
# glob, `~`, `#`, redirection, pipe, `;`, newline, subshell or here-doc anywhere
# in the command. Nothing but `cd` may precede the action and nothing may follow
# it, so no earlier segment can change the environment, cwd resolution or the
# meaning of a word for the action (the round-4 taint class closes by
# construction, not by a list of builtins).

WORD_RE = re.compile(r"[A-Za-z0-9._/:=@+%,-]+")
_GRAMMAR_CHARS = re.compile(r"[A-Za-z0-9._/:=@+%,\- \t&]*")


class Unmappable(Exception):
    """The command is outside the grammar, or not certain — use the hash path."""


def grammar_segments(cmd: str) -> list[list[str]]:
    """Split ``cmd`` into its ``&&`` segments, each a list of plain words, or
    raise :class:`Unmappable` when any part of it is outside the grammar."""
    cmd = cmd.strip(" \t")
    if not cmd or not _GRAMMAR_CHARS.fullmatch(cmd):
        raise Unmappable("outside the grammar: a character the grammar does not allow")
    segs = []
    for part in cmd.split("&&"):
        if "&" in part:
            raise Unmappable("outside the grammar: a lone & (background job)")
        words = part.split()
        if not words:
            raise Unmappable("outside the grammar: empty segment")
        segs.append(words)
    return segs


def _plain_path(p: str) -> str:
    if not WORD_RE.fullmatch(p) or p.startswith("-") or ".." in p.split("/"):
        raise Unmappable(f"outside the grammar: path {p!r}")
    return p


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
        # The key says which namespace; so does the text (T-3594 round 4).
        if t["ref"].startswith("refs/tags/"):
            return f"DELETE tag '{t['ref'][len('refs/tags/'):]}' on remote '{t['remote']}'"
        if t["ref"].startswith("refs/"):
            return f"DELETE ref '{t['ref']}' on remote '{t['remote']}'"
        return f"DELETE branch '{t['ref']}' on remote '{t['remote']}'"
    if v == "hard-reset":
        return (f"HARD-RESET branch '{t['branch']}' in {t['repo']} to commit "
                f"{t.get('target', '?')[:12]} (moves the branch there and discards "
                "uncommitted changes)")
    if v == "recursive-delete":
        return f"RECURSIVELY DELETE {t['path']}"
    return action_key(a)


_OPTS_CACHE: dict[str, dict[str, bool] | None] = {}


def _git_long_options(sub: str) -> dict[str, bool] | None:
    """Every long option ``git <sub>`` accepts, as {name: takes_required_arg},
    read from git itself (``--git-completion-helper-all`` lists hidden options
    and every ``no-`` negation). None when git cannot tell us — callers then
    treat every long option as unreadable (T-3593 round 3)."""
    if sub not in _OPTS_CACHE:
        try:
            out = subprocess.run(["git", sub, "--git-completion-helper-all"],
                                 capture_output=True, text=True, timeout=5)
            words = out.stdout.split() if out.returncode == 0 else []
        except Exception:  # pragma: no cover - environment
            words = []
        opts = {w[2:].rstrip("="): w.endswith("=")
                for w in words if w.startswith("--") and len(w) > 2}
        _OPTS_CACHE[sub] = opts or None
    return _OPTS_CACHE[sub]


def resolve_long(sub: str, arg: str) -> tuple[str, bool]:
    """Resolve ``--name[=v]`` the way git's parse-options does: an exact match
    wins, otherwise a prefix of exactly one known option is that option (git
    accepts ``--no-verif`` for ``--no-verify``, ``--force-w`` for
    ``--force-with-lease``, ``--h`` for ``reset --hard``). Unknown or ambiguous
    → :class:`Unmappable`, never a guess. Returns (name, takes_required_arg).

    The option list comes from the installed git, not a hand list: the round-2
    fix denied the exact string ``--no-verify`` and silently skipped every other
    long option, so one abbreviation reopened R1 (T-3593 round 3)."""
    opts = _git_long_options(sub)
    name = arg[2:].split("=", 1)[0]
    if not opts or not name:
        raise Unmappable(f"git {sub} {arg}: option list unavailable")
    if name in opts:
        return name, opts[name]
    hits = [o for o in opts if o.startswith(name)]
    if len(hits) != 1:
        raise Unmappable(f"git {sub} {arg}: {'ambiguous' if hits else 'unknown'} option")
    return hits[0], opts[hits[0]]


# Push options that neither change which refs move nor skip a hook. Everything
# not named here or handled explicitly (--no-verify, --repo, --receive-pack,
# --exec, --all, --no-force, ...) makes the push unmapped.
_PUSH_BENIGN = {"verbose", "quiet", "dry-run", "porcelain", "thin", "set-upstream",
                "progress", "follow-tags", "signed", "atomic", "ipv4", "ipv6",
                "verify", "recurse-submodules", "push-option", "force-if-includes"}
_PUSH_BENIGN |= {"no-" + o for o in _PUSH_BENIGN if o != "verify"}
_PUSH_SHORT = {"v", "q", "n", "u", "4", "6", "f", "d", "o"}


def _classify_push(args: list[str], cwd: str | None, root: str | None = None) -> list[dict]:
    force = delete = False
    positional: list[str] = []
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("--", "--end-of-options"):
            positional.extend(args[i + 1:])
            break
        if a.startswith("--"):
            name, takes_arg = resolve_long("push", a)
            if name in ("force", "force-with-lease"):
                force = True
            elif name == "delete":
                delete = True
            elif name == "no-verify":
                # A second Tier 0 decision (HOOK BYPASS) — and it would skip the
                # pre-push hook that consumes this approval (T-3593 R1).
                raise Unmappable("push --no-verify")
            elif name in ("all", "mirror", "tags", "prune", "branches"):
                raise Unmappable(f"push --{name} targets are not enumerable from the text")
            elif name in _PUSH_BENIGN:
                if takes_arg and "=" not in a:
                    i += 1
            else:
                raise Unmappable(f"push --{name}")
        elif a.startswith("-") and len(a) > 1:
            flags = a[1:]
            for j, f in enumerate(flags):
                if f not in _PUSH_SHORT:
                    raise Unmappable(f"push -{f}")
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
    if cwd is None:
        raise Unmappable("push with unknown cwd")
    if root is not None and _toplevel(cwd) != _toplevel(root):
        # The approval store and the pre-push hook that consumes it belong to
        # the PROJECT repo; a push from another repo (git -C, cd elsewhere,
        # GIT_DIR) would be admitted here and checked (or not) there.
        raise Unmappable("push from a repository other than the project")
    out: list[dict] = []
    for spec in specs:
        plus = spec.startswith("+")
        body = spec[1:] if plus else spec
        if any(ch in body for ch in "*?["):
            raise Unmappable("wildcard refspec")
        if delete:
            if ":" in body:
                raise Unmappable("--delete with a src:dst refspec")
            out.append(action("branch-delete", remote=remote,
                              ref=_remote_ref_key(remote, body, "", cwd, deleting=True)))
            continue
        if body.startswith(":"):
            out.append(action("branch-delete", remote=remote,
                              ref=_remote_ref_key(remote, body[1:], "", cwd, deleting=True)))
            continue
        src, _, dst = body.partition(":")
        dst = dst or src
        if dst in ("HEAD", "@") or dst == "":
            dst = _current_branch(cwd)
        if force or plus:
            out.append(action("force-push", remote=remote, ref=_remote_ref_key(remote, dst, src, cwd)))
    return out


def _ref_exists(cwd: str, ref: str) -> bool | None:
    """True/False for a local ref, None when cwd is not a readable repo."""
    try:
        out = subprocess.run(["git", "-C", cwd, "show-ref", "--verify", "--quiet", ref],
                             capture_output=True, timeout=5)
    except Exception:  # pragma: no cover - environment
        return None
    return {0: True, 1: False}.get(out.returncode)


def _remote_ref_key(remote: str, dst: str, src: str, cwd: str, deleting: bool = False) -> str:
    """The ref key pre-push will see, for a force-push OR a delete — one
    function for both, so the two layers cannot drift (T-3594 round 4).

    Pre-push reports full names and strips only ``refs/heads/``: a branch keys
    by its short name, a tag as ``refs/tags/<t>``, anything else in full. A
    short name typed at the text gate is resolved from LOCAL evidence only:
    ``refs/tags/<n>`` → tag; ``refs/heads/<n>`` or ``refs/remotes/<remote>/<n>``
    → branch. Both, or neither, is unmapped rather than guessed, so a tag-delete
    approval can never be keyed as (and later authorize) a branch delete. When
    local evidence is wrong about the remote the keys differ and pre-push
    refuses: the failure direction is closed."""
    if dst.startswith("refs/"):
        return normalize_ref(dst)
    tag = _ref_exists(cwd, "refs/tags/" + dst)
    branch_l = _ref_exists(cwd, "refs/heads/" + dst)
    branch_r = _ref_exists(cwd, f"refs/remotes/{remote}/{dst}")
    if tag is None or branch_l is None or branch_r is None:
        raise Unmappable(f"cannot read refs in {cwd}")
    branch = branch_l or branch_r
    if tag and branch:
        raise Unmappable(f"'{dst}' is both a branch and a tag")
    if not tag and not branch:
        raise Unmappable(f"no local evidence whether '{dst}' is a branch or a tag")
    if tag:
        return "refs/tags/" + dst
    if not deleting and src and src != dst and not src.startswith("refs/heads/") \
            and _ref_exists(cwd, "refs/tags/" + src):
        raise Unmappable(f"tag {src} pushed to branch name {dst}")
    return normalize_ref(dst)


def _classify_git(words: list[str], cwd: str | None,
                  root: str | None = None) -> list[dict]:
    # Global options (the grammar): -C <PATH>, -P, --no-pager. Anything else is
    # unmapped: -c / --config-env (any config, incl. core.hooksPath and
    # include.path), --git-dir / --work-tree / --bare (another repo's hooks and
    # config), --namespace, --exec-path, -p, and anything git adds later.
    # For a push, the -C repo must still be the project's (_classify_push).
    i = 1
    while i < len(words) and words[i].startswith("-"):
        opt = words[i]
        if opt == "-C" and i + 1 < len(words):
            target = _plain_path(words[i + 1])
            if os.path.isabs(target):
                cwd = os.path.normpath(target)
            elif cwd is not None:
                cwd = os.path.normpath(os.path.join(cwd, target))
            i += 2
        elif opt in ("-P", "--no-pager"):
            i += 1
        else:
            raise Unmappable(f"git global option {opt}")
    if i >= len(words):
        raise Unmappable("bare git")
    sub, args = words[i], words[i + 1:]
    if sub == "push":
        return _classify_push(args, cwd, root)
    if sub == "reset":
        # Long options resolve as git resolves them: `--har` and `--h` are --hard.
        longs = {a: resolve_long("reset", a)[0] for a in args if a.startswith("--") and a != "--"}
        if "hard" not in longs.values():
            return []
        if cwd is None:
            raise Unmappable("reset with unknown cwd")
        revs = []
        for a in args:
            if a == "-q" or longs.get(a) in ("hard", "quiet"):
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
                       target=target)]
    if sub == "branch":
        longs = {a: resolve_long("branch", a)[0] for a in args if a.startswith("--") and a != "--"}
        shorts = "".join(a[1:] for a in args if a.startswith("-") and not a.startswith("--"))
        force_del = "D" in shorts or (("d" in shorts or "delete" in longs.values())
                                      and ("f" in shorts or "force" in longs.values()))
        if not force_del:
            return []
        if "remotes" in longs.values() or "r" in shorts:
            raise Unmappable("branch delete of remote-tracking refs")
        names = [a for a in args if not a.startswith("-")]
        if not names:
            raise Unmappable("branch -D without a name")
        if cwd is None:
            raise Unmappable("branch -D with unknown cwd")
        repo = _toplevel(cwd)
        return [action("branch-delete", remote=LOCAL_REMOTE, ref=normalize_ref(n), repo=repo)
                for n in names]
    raise Unmappable(f"git {sub} is not an action verb")


_RM_SHORT = set("rRfv")
_RM_LONG = {"--recursive", "--force", "--verbose"}


def _classify_rm(args: list[str], cwd: str | None) -> list[dict]:
    # Options are an allowlist too: --no-preserve-root, --one-file-system, -i,
    # -d ... are a different decision, or none the operator can read here.
    recursive, paths, opts_done = False, [], False
    for a in args:
        if not opts_done and a == "--":
            opts_done = True
        elif not opts_done and a.startswith("--"):
            if a not in _RM_LONG:
                raise Unmappable(f"rm option {a}")
            recursive = recursive or a == "--recursive"
        elif not opts_done and a.startswith("-") and len(a) > 1:
            if not set(a[1:]) <= _RM_SHORT:
                raise Unmappable(f"rm option {a}")
            recursive = recursive or bool(set(a[1:]) & {"r", "R"})
        else:
            paths.append(_plain_path(a))
    if not recursive:
        return []
    if not paths:
        raise Unmappable("rm -r without a path")
    out = []
    for p in paths:
        if not os.path.isabs(p):
            if cwd is None:
                raise Unmappable("relative rm path with unknown cwd")
            p = os.path.join(cwd, p)
        norm = os.path.normpath(p)          # trailing slash is not a different target
        out.append(action("recursive-delete", path=norm))
    return out


# Which verb explains which Tier 0 pattern (by its description prefix, from
# check-tier0.sh PATTERNS). A command flagged by any pattern its action does not
# cover is unmapped (T-3593 R1): a --no-verify or a hooksPath override riding on
# a force push is a second decision the operator must see as text.
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


def classify(command: str, is_flagged, cwd: str | None,
             root: str | None = None) -> list[dict] | None:
    """Map a blocked command to actions, or None when it is unmapped.

    The command maps only when it is spelled in the grammar above: zero or more
    ``cd PATH &&`` and then ONE ``git`` or ``rm`` action segment, plain words
    only. Anything else returns None, and the hook falls back to the exact-text
    approval. The direction is always "less can be approved", never "more is
    admitted".

    ``is_flagged(text)`` is the hook's own Tier 0 pattern test (the pattern list
    stays single-sourced in check-tier0.sh). It returns the matching pattern
    descriptions. The WHOLE command must be flagged, and every pattern that
    flags it must be covered by the action's verb.

    cwd: a ``cd`` carries to the next segment because the separator is always
    ``&&`` (the action runs only when every cd succeeded). A relative target
    with an unknown cwd is unmapped, and so is a bare relative ``cd`` (not
    ``./``-anchored) while CDPATH is set in this process's environment: bash
    would consult it (N2). ``root`` is the project root: a push from any other
    repository is unmapped.
    """
    try:
        segs = grammar_segments(command)
        *cds, act = segs
        cdpath = bool(os.environ.get("CDPATH"))
        for words in cds:
            if words[0] != "cd" or len(words) != 2:
                raise Unmappable("outside the grammar: only `cd PATH` may precede the action")
            target = _plain_path(words[1])
            if os.path.isabs(target):
                cwd = os.path.normpath(target)
            elif cdpath and not (target == "." or target.startswith("./")):
                cwd = None
            else:
                cwd = os.path.normpath(os.path.join(cwd, target)) if cwd else None
        if act[0] == "git":
            acts = _classify_git(act, cwd, root)
        elif act[0] == "rm":
            acts = _classify_rm(act[1:], cwd)
        else:
            raise Unmappable(f"outside the grammar: {act[0]} is not an action verb")
    except Unmappable:
        return None
    flagged = is_flagged(command)
    if not acts or not flagged:
        return None
    if not isinstance(flagged, bool) and not _covered(flagged, acts):
        return None
    seen, uniq = set(), []
    for a in acts:
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
        admit_over = (r.get("state") == "admitted"
                      and now >= r.get("admitted_at", now) + ADMIT_TTL)
        if r.get("state") in ("approved", "admitted") and (now >= r.get("expires", 0) or admit_over):
            r["state"] = "expired"
            changed = True
            log_event(root, "expired", id=r["id"], action_key=r["key"])
    return changed


def approve(root: str, actions: list[dict], ttl: int, approved_by: str = "unknown",
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
        now: float | None = None, call_id: str = "") -> bool:
    """All-or-nothing: every action needs a live approval, else nothing changes.

    layer='text-gate': push verbs are ADMITTED (pre-push consumes them later);
    other verbs are consumed. layer='pre-push': consumes approved or admitted.

    ``call_id`` (round 4, replaces the T-1508 5 s same-text window): the
    PreToolUse ``tool_use_id``. A hook registered twice fires twice for ONE tool
    call; the second fire finds the records the first one used, stamped with the
    same call id, and is allowed without using anything. A different call — or
    no call id at all — gets no such grace, so an approved reset or rm runs
    once. Checked under the store lock, so concurrent sibling fires are safe.
    """
    now = time.time() if now is None else now
    with _locked(root):
        recs = _load(root)
        if call_id and layer == "text-gate":
            dup, seen = True, set()
            for a in actions:
                key = action_key(a)
                hit = next((r for r in recs if r["key"] == key and r.get("call_id") == call_id
                            and r["state"] in ("admitted", "consumed") and r["id"] not in seen), None)
                if hit is None:
                    dup = False
                    break
                seen.add(hit["id"])
            if dup:
                log_event(root, "duplicate-fire", call_id=call_id,
                          action_keys=[action_key(a) for a in actions])
                return True
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
            if call_id and layer == "text-gate":
                r["call_id"] = call_id
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
        # use <layer> <actions-json> [preview] [call-id]
        acts = json.loads(argv[2])
        return 0 if use(root, acts, argv[1], argv[3] if len(argv) > 3 else "",
                        call_id=argv[4] if len(argv) > 4 else "") else 1
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
