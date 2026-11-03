#!/usr/bin/env python3
"""Outside-commit alarm (T-5049, requirement R-58).

Every commit on the development branch after a recorded baseline whose author is not an
internal identity (policy/internal-identities.yaml) is an OUTSIDE commit. It is accepted only
when it arrived through a GitHub pull request that the operator merged:

  - the commit's own subject ends in "(#N)" (a squash merge), or it is itself a
    "Merge pull request #N" merge, or
  - it is reachable from the second parent (and not the first) of a "Merge pull request #N"
    merge commit in the range,

and `gh api repos/<owner>/<repo>/pulls/N` reports merged_by.login == the operator's login.

  outside_commits.py audit [--json] [--branch bleeding-edge]

Exit: 0 clean, 1 only WARN (could not verify — never counted as OK), 2 any FAIL,
3 the check could not run (git error, bad policy). No policy file = not configured, exit 0.

Env: FW_INTERNAL_IDENTITIES (policy path), FW_GH_BIN (gh binary, tests stub it),
FW_GITHUB_REPO (owner/repo; default parsed from the github.com remote), PROJECT_ROOT.
Stdlib only; gh is called only when outside commits exist.
"""
from __future__ import annotations

import fnmatch
import json
import os
import re
import subprocess
import sys
from pathlib import Path

PROJECT = Path(os.environ.get("PROJECT_ROOT") or Path.cwd())
_SQUASH = re.compile(r"\(#(\d+)\)\s*$")
_MERGE_PR = re.compile(r"^Merge pull request #(\d+)\b")


class CheckError(Exception):
    pass


def _git(*args: str, check: bool = True) -> str:
    try:
        p = subprocess.run(["git", "-C", str(PROJECT), *args], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as e:
        raise CheckError(f"git {' '.join(args[:2])} could not run: {e}")
    if check and p.returncode != 0:
        raise CheckError(f"git {' '.join(args[:3])} failed: {p.stderr.strip()[:200]}")
    return p.stdout if p.returncode == 0 else ""


def policy_path() -> Path:
    env = os.environ.get("FW_INTERNAL_IDENTITIES")
    return Path(env) if env else PROJECT / "policy" / "internal-identities.yaml"


def load_policy(path: Path) -> dict:
    """Minimal parser for the flat policy shape: `key: value` scalars and `key:` + `- item` lists."""
    out: dict = {"internal_authors": []}
    key = None
    for raw in path.read_text().splitlines():
        line = raw.split(" #", 1)[0].rstrip() if not raw.lstrip().startswith("#") else ""
        if not line.strip():
            continue
        m = re.match(r"^([a-z_]+):\s*(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2).strip().strip('"\'')
            if val:
                out[key] = val
                key = None
            else:
                out.setdefault(key, [])
            continue
        m = re.match(r"^\s+-\s+(.*)$", line)
        if m and key and isinstance(out.get(key), list):
            out[key].append(m.group(1).strip().strip('"\''))
            continue
        raise CheckError(f"{path}: cannot parse line: {raw!r}")
    for req in ("baseline_commit", "operator_github_login"):
        if not out.get(req):
            raise CheckError(f"{path}: missing {req}")
    return out


def is_internal(email: str, globs: list[str]) -> bool:
    e = email.lower()
    return any(fnmatch.fnmatchcase(e, g.lower()) for g in globs)


def github_repo() -> str:
    if os.environ.get("FW_GITHUB_REPO"):
        return os.environ["FW_GITHUB_REPO"]
    for line in _git("remote", "-v", check=False).splitlines():
        m = re.search(r"github\.com[:/]([^/\s]+)/([^/\s]+?)(?:\.git)?\s", line + " ")
        if m:
            return f"{m.group(1)}/{m.group(2)}"
    return ""


def pr_merged_by(repo: str, n: int, cache: dict) -> tuple[str | None, str]:
    """(login, "") when gh answered (login may be "" = not merged), (None, reason) when unverified."""
    if n in cache:
        return cache[n]
    if not repo:
        res: tuple = (None, "no github.com remote to ask")
    else:
        gh = os.environ.get("FW_GH_BIN", "gh")
        try:
            p = subprocess.run([gh, "api", f"repos/{repo}/pulls/{n}", "--jq", ".merged_by.login // \"\""],
                               capture_output=True, text=True, timeout=30)
            if p.returncode == 0:
                login = p.stdout.strip()
                res = ("" if login in ("null", "") else login, "")
            else:
                res = (None, f"gh api failed: {(p.stderr or p.stdout).strip()[:120]}")
        except (OSError, subprocess.SubprocessError) as e:
            res = (None, f"gh unavailable: {e}")
    cache[n] = res
    return res


def check(branch: str = "bleeding-edge") -> dict:
    """The full verdict. Raises CheckError when the check cannot run."""
    pol_path = policy_path()
    if not pol_path.is_file():
        return {"result": "not-configured", "summary": f"not configured (no {pol_path.name})", "alarms": []}
    pol = load_policy(pol_path)
    if not _git("rev-parse", "--verify", "-q", f"refs/heads/{branch}", check=False).strip():
        return {"result": "no-branch", "summary": f"branch {branch} not present", "alarms": []}
    base = pol["baseline_commit"]
    if not _git("rev-parse", "--verify", "-q", f"{base}^{{commit}}", check=False).strip():
        raise CheckError(f"baseline_commit {base} is not a commit in this repository")
    raw = _git("log", "--format=%H%x1f%P%x1f%ae%x1f%an%x1f%s%x1e", f"{base}..refs/heads/{branch}")
    commits = []
    for rec in raw.split("\x1e"):
        rec = rec.strip("\n")
        if not rec:
            continue
        sha, parents, email, name, subj = rec.split("\x1f", 4)
        commits.append({"sha": sha, "parents": parents.split(), "email": email, "name": name, "subject": subj})
    globs = pol["internal_authors"]
    outside = [c for c in commits if not is_internal(c["email"], globs)]
    if not outside:
        return {"result": "ok", "alarms": [],
                "summary": f"no outside commits since baseline {base[:9]} ({len(commits)} commit(s) checked)"}

    # PR attribution through "Merge pull request #N" merges in range (second-parent side only).
    via_merge: dict[str, int] = {}
    for c in commits:
        m = _MERGE_PR.match(c["subject"])
        if m and len(c["parents"]) >= 2:
            for s in _git("rev-list", f"{c['parents'][0]}..{c['parents'][1]}").split():
                via_merge.setdefault(s, int(m.group(1)))

    repo, cache, alarms = github_repo(), {}, []
    login = pol["operator_github_login"]
    for c in outside:
        own = _SQUASH.search(c["subject"]) or (_MERGE_PR.match(c["subject"]) if len(c["parents"]) >= 2 else None)
        pr = int(own.group(1)) if own else via_merge.get(c["sha"])
        a = {"sha": c["sha"], "short": c["sha"][:9], "author": f"{c['name']} <{c['email']}>",
             "subject": c["subject"], "pr": pr}
        if pr is None:
            a.update(level="FAIL", reason="pushed directly, not through a PR")
        else:
            who, why = pr_merged_by(repo, pr, cache)
            if who is None:
                a.update(level="WARN", reason=f"PR #{pr} unverified ({why})")
            elif who == login:
                continue
            elif not who:
                a.update(level="FAIL", reason=f"PR #{pr} is not recorded as merged")
            else:
                a.update(level="FAIL", reason=f"PR #{pr} merged by {who}, not the operator")
        alarms.append(a)
    nf = sum(1 for a in alarms if a["level"] == "FAIL")
    nw = len(alarms) - nf
    result = "fail" if nf else ("warn" if nw else "ok")
    summary = (f"{len(outside)} outside commit(s) since baseline {base[:9]}: "
               f"{nf} FAIL, {nw} unverified, {len(outside) - len(alarms)} operator-merged")
    return {"result": result, "alarms": alarms, "summary": summary}


def open_alarms(branch: str = "bleeding-edge") -> list[dict]:
    """FAIL alarms only, for `fw operator pending`. Never raises."""
    try:
        return [a for a in check(branch)["alarms"] if a["level"] == "FAIL"]
    except Exception:
        return []


def main(argv: list[str]) -> int:
    if not argv or argv[0] != "audit":
        print("usage: outside_commits.py audit [--json] [--branch NAME]", file=sys.stderr)
        return 3
    branch = "bleeding-edge"
    if "--branch" in argv:
        i = argv.index("--branch")
        if i + 1 >= len(argv):
            print("--branch needs a value", file=sys.stderr)
            return 3
        branch = argv[i + 1]
    try:
        data = check(branch)
    except CheckError as e:
        if "--json" in argv:
            print(json.dumps({"result": "error", "error": str(e)}))
        else:
            print(f"ERROR outside-commit check could not run: {e}")
        return 3
    if "--json" in argv:
        print(json.dumps(data, indent=2))
    else:
        for a in data["alarms"]:
            pr = f" PR #{a['pr']}" if a["pr"] is not None else ""
            print(f"{a['level']} outside commit {a['short']} by {a['author']} \"{a['subject']}\"{pr}: {a['reason']}")
        print(f"Outside commits: {data['summary']}")
    return {"fail": 2, "warn": 1}.get(data["result"], 0)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
