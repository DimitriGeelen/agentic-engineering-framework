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


class EnvChange(Unmappable):
    """The segment may change the shell's environment, cwd resolution or the
    meaning of a command name for every LATER segment (an assignment, export,
    source, eval, alias, a function definition, ...). After one, no later
    flagged segment can be mapped (T-3593 round 4)."""


_ENV_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\[[^\]]*\])?\+?=")
# Words that only wrap the command without changing its environment. `sudo`,
# `env`, `doas` DO change it (HOME, a cleared or edited environment) and are
# therefore not here: they make the segment unmapped (T-3593 round 4).
_PREFIX_WORDS = {"command", "nohup", "time", "exec"}
# Shell builtins/keywords whose effect outlives their own segment.
_ENV_BUILTINS = {"export", "unset", "set", "declare", "typeset", "local", "readonly",
                 "source", ".", "eval", "alias", "unalias", "shopt", "enable",
                 "builtin", "hash", "trap", "function", "{", "exec"}


def _strip_prefix(words: list[str]) -> list[str]:
    """Drop wrapper words that leave the environment alone. ANY variable
    assignment in front of the command is refused, not stripped — one rule, not
    a denylist: GIT_CONFIG_GLOBAL=, HOME=, XDG_CONFIG_HOME=, GIT_DIR=, CDPATH=,
    GIT_CONFIG_PARAMETERS= all change what git reads or where it runs, and a
    list of the dangerous ones is exactly what round 3 got wrong (N1). The
    command then takes the exact-text approval path."""
    while words and (_ENV_ASSIGN.match(words[0]) or words[0] in _PREFIX_WORDS):
        if _ENV_ASSIGN.match(words[0]):
            raise Unmappable(f"environment assignment {words[0].split('=', 1)[0]}= before the command")
        if len(words) > 1 and words[1].startswith("-"):
            raise Unmappable(f"{words[0]} with options")
        words = words[1:]
    return words


def env_effect(seg: str) -> bool:
    """True when ``seg`` may change the environment of LATER segments. Read from
    the raw first word, because the segments that do this are often the ones
    :func:`tokenize` refuses (``export X=$(...)``, ``f() { ...; }``)."""
    m = re.match(r"\s*(\S+)", seg)
    if not m:
        return False
    w = m.group(1)
    return bool(_ENV_ASSIGN.match(w) or w in _ENV_BUILTINS or w.startswith("{")
                or "()" in w or w in ("env", "sudo", "doas"))


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
                  root: str | None = None) -> tuple[list[dict], str | None]:
    # Global options: an ALLOWLIST, default unmapped (T-3593 round 4). Kept:
    #   -C <dir>      moves the command, nothing else; for a push the repo must
    #                 still be the project's (checked in _classify_push)
    #   -P, --no-pager  pager only
    # Everything else is unmapped: -c / --config-env (any config, incl.
    # core.hooksPath and include.path), --git-dir / --work-tree / --bare
    # (another repo's hooks and config), --namespace (different ref names),
    # --exec-path, --no-replace-objects (rev resolution differs from ours),
    # -p / --paginate and anything git adds later.
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
        elif opt in ("-P", "--no-pager"):
            i += 1
        else:
            raise Unmappable(f"git global option {opt}")
    if i >= len(words):
        raise Unmappable("bare git")
    sub, args = words[i], words[i + 1:]
    if "--no-verify" in args:
        raise Unmappable("--no-verify is its own Tier 0 decision")
    if sub == "push":
        return _classify_push(args, cwd, root), cwd
    if sub == "reset":
        # Long options resolve as git resolves them: `--har` and `--h` are --hard.
        longs = {a: resolve_long("reset", a)[0] for a in args if a.startswith("--") and a != "--"}
        if "hard" not in longs.values():
            return [], cwd
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
                       target=target)], cwd
    if sub == "branch":
        longs = {a: resolve_long("branch", a)[0] for a in args if a.startswith("--") and a != "--"}
        shorts = "".join(a[1:] for a in args if a.startswith("-") and not a.startswith("--"))
        force_del = "D" in shorts or (("d" in shorts or "delete" in longs.values())
                                      and ("f" in shorts or "force" in longs.values()))
        if not force_del:
            return [], cwd
        if "remotes" in longs.values() or "r" in shorts:
            raise Unmappable("branch delete of remote-tracking refs")
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


def classify_segment(seg: str, cwd: str | None, cdpath: bool = False,
                     root: str | None = None) -> tuple[list[dict], str | None]:
    """Return (actions, new_cwd). Raises Unmappable when not certain, and
    :class:`EnvChange` when the segment may alter the environment of later ones."""
    if env_effect(seg):
        raise EnvChange(f"segment may change the environment: {seg[:40]!r}")
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
        # N2 (round 4): bash consults CDPATH for a relative target that does not
        # start with ./ or ../ (or is not . / ..). With CDPATH anywhere in play,
        # where such a cd lands is not knowable from the text.
        anchored = target in (".", "..") or target.startswith(("./", "../"))
        if cdpath and not anchored:
            return [], None
        return [], (os.path.normpath(os.path.join(cwd, target)) if cwd else None)
    if head in ("pushd", "popd"):
        return [], None
    if head == "git":
        # `git -C dir` scopes to this one command; the shell cwd is unchanged.
        acts, _ = _classify_git(words, cwd, root)
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


def classify(command: str, is_flagged, cwd: str | None,
             root: str | None = None) -> list[dict] | None:
    """Map a blocked command to actions, or None when it is unmapped.

    ``is_flagged(segment_text)`` is the hook's own Tier 0 pattern test, passed in
    so the pattern list stays single-sourced in check-tier0.sh. It returns the
    list of matching pattern descriptions (a bare bool is accepted for older
    callers, but then pattern coverage cannot be checked). Every flagged segment
    must classify to at least one action, and every pattern flagging it must be
    covered by those actions' verbs; otherwise the WHOLE command is unmapped.

    cwd tracking (T-3593 R3): a segment's cwd change carries to the next segment
    only across ``&&``, only when the segment is not in a pipeline, and only
    when the separator BEFORE it is not ``||`` (``true || cd x && rm -rf .``
    skips the cd and runs the rm in the old cwd — round 3). And a cwd changed
    inside an and-chain does not survive the chain's end: at ``;``, ``||``,
    ``&`` or a newline a failed ``cd`` (or a short-circuit) may have left the
    old cwd in place, so it becomes unknown (``cd x && true ; rm -rf .``).
    After any segment this module cannot read, the cwd becomes unknown too.
    Unknown means a relative target is unmapped.

    Environment (round 4): a flagged segment with ANY assignment or env/sudo
    wrapper in front is unmapped, and once any segment may have changed the
    environment (export, unset, source, eval, alias, a function definition, a
    bare assignment) no later flagged segment is mapped either. CDPATH anywhere
    in the command, or in this process's environment, makes a bare relative
    ``cd`` land somewhere unknown (N2). ``root`` is the project root: a push
    from any other repository is unmapped.
    """
    try:
        segs = split_segments_seps(command)
    except Unmappable:
        return None
    cdpath = bool(re.search(r"\bCDPATH\b", command) or os.environ.get("CDPATH"))
    actions: list[dict] = []
    saw_flagged = False
    env_tainted = False
    prev_sep = ""
    chain_cwd = cwd          # the cwd at the start of the current and-chain
    for seg, sep in segs:
        flagged = is_flagged(seg)
        if flagged and env_tainted:
            return None
        try:
            acts, new_cwd = classify_segment(seg, cwd, cdpath, root)
        except Unmappable as exc:
            if flagged:
                return None
            if isinstance(exc, EnvChange):
                env_tainted = True
            # An unreadable segment (`source x`, `{ cd x; }`, `eval ...`) may
            # change the cwd in ways the text does not show.
            cwd = chain_cwd = None
            prev_sep = sep
            continue
        if flagged:
            saw_flagged = True
            if not acts:
                return None
            if not isinstance(flagged, bool) and not _covered(flagged, acts):
                return None
            actions.extend(acts)
        if new_cwd != cwd:
            carries = sep == "&&" and prev_sep not in ("|", "||")
            cwd = new_cwd if carries else None
        if sep not in ("&&", "|"):
            # End of an and-chain: a cd inside it may not have run.
            if cwd != chain_cwd:
                cwd = None
            if sep != "||":
                chain_cwd = cwd
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
