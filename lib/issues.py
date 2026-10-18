#!/usr/bin/env python3
"""fw issues — GitHub issue intake (T-4039 build slice 1, T-4077).

Subcommands:
  comment <n> --stage S ...   the ONE outward verb: post a stage comment on a GitHub issue
  approve <ref> ...           record an operator approval for a decision-stage comment
  sync [--dry-run]            T-4078: ingest new/changed issues and submitter replies (cron, 2 h)

Spec: docs/reports/T-4039-inbound-github-issues.md. Rules this file enforces:
  - every comment is the stage's fixed template + the operator's verbatim footer + a stage marker;
  - idempotent per (issue, stage): the ledger OR the marker read back from the issue stops a repeat;
  - decision stages (accepted / needs-info / duplicate / not-planned) need an operator approval;
  - fixed-on-bleeding-edge needs a commit that is already on the GitHub mirror's bleeding-edge
    and a per-issue test command;
  - the ledger row (.context/issues/intake.jsonl) is written only after GitHub returns the
    comment URL; a failure after posting is reported with the URL, never swallowed;
  - GitHub issue text is untrusted data: it is only ever searched for the stage marker and is
    never executed, interpolated into a command, or obeyed.

Environment (tests): FW_ISSUES_DIR (ledger dir), FW_ISSUES_REPO (owner/name),
FW_ISSUES_GIT_REMOTE (git remote of the GitHub mirror, default "github"), FW_ISSUES_BRANCH.
"""
import argparse
import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# T-4093: arc ids are normalised by the canonical helper (T-3516), never re-derived here.
try:
    from lib.arc_membership import parse_arc_id_value
except ImportError:  # run as `python3 lib/issues.py` (lib/ is sys.path[0])
    from arc_membership import parse_arc_id_value

DEFAULT_REPO = "DimitriGeelen/agentic-engineering-framework"
FOOTER = ("*These status updates are automated, but Dimitri personally looks at every issue "
          "and decides what happens to it. Replies on this issue are read.*")
MARKER_RE = re.compile(r"<!--\s*aef-intake:stage=([a-z+-]+)\s*-->")

TEMPLATE_STAGES = ["received", "classified", "in-progress", "fixed-on-bleeding-edge",
                   "available-for-testing", "released"]
DECISION_STAGES = ["accepted", "needs-info", "duplicate", "not-planned"]
STAGES = TEMPLATE_STAGES + DECISION_STAGES

TITLES = {
    "received": "Received", "classified": "Classified", "accepted": "Accepted",
    "needs-info": "Needs info", "duplicate": "Duplicate", "not-planned": "Not planned",
    "in-progress": "In progress", "fixed-on-bleeding-edge": "Fixed on bleeding-edge",
    "available-for-testing": "Available for testing", "released": "Released",
}
NEXT = {
    "received": "classification", "classified": "the maintainer's decision",
    "accepted": "in progress", "in-progress": "fixed on bleeding-edge",
    "fixed-on-bleeding-edge": "released", "available-for-testing": "released",
}

LABELS = {  # name -> (description, colour)
    "status:received": ("Ingested by the AEF intake pipeline", "ededed"),
    "triaged": ("Classified by the AEF intake pipeline", "0e8a16"),
    "status:accepted": ("Accepted; linked to an AEF task", "1d76db"),
    "status:needs-info": ("Waiting for more information from the reporter", "fbca04"),
    "status:duplicate": ("Duplicate of another issue or task", "cfd3d7"),
    "status:not-planned": ("Not planned; reason given in the issue", "cfd3d7"),
    "status:in-progress": ("Work has started", "5319e7"),
    "status:fixed-on-bleeding-edge": ("Fixed on bleeding-edge; not yet released", "0e8a16"),
    "fixed-on-bleeding-edge": ("Fix is on the bleeding-edge branch", "0e8a16"),
    "status:available-for-testing": ("Fix is in a pre-release for testing", "1d76db"),
    "status:released": ("Released", "0e8a16"),
}
STAGE_LABELS = {
    "received": ["status:received"], "classified": ["triaged"],
    "accepted": ["status:accepted"], "needs-info": ["status:needs-info"],
    "duplicate": ["status:duplicate"], "not-planned": ["status:not-planned"],
    "in-progress": ["status:in-progress"],
    "fixed-on-bleeding-edge": ["status:fixed-on-bleeding-edge", "fixed-on-bleeding-edge"],
    "available-for-testing": ["status:available-for-testing"], "released": ["status:released"],
}


class IssuesError(Exception):
    def __init__(self, msg, code=1):
        super().__init__(msg)
        self.code = code


# ── paths and ledgers ────────────────────────────────────────────────────────

def _issues_dir() -> Path:
    d = os.environ.get("FW_ISSUES_DIR")
    if d:
        return Path(d)
    root = os.environ.get("PROJECT_ROOT") or os.getcwd()
    return Path(root) / ".context" / "issues"


def _repo() -> str:
    return os.environ.get("FW_ISSUES_REPO", DEFAULT_REPO)


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _agent_ancestry() -> bool:
    """True when a Claude process is among this process's ancestors. `env -u CLAUDECODE` clears
    the variable but not the parent chain (T-4108)."""
    pid = os.getppid()
    for _ in range(64):
        if pid <= 1:
            return False
        try:
            argv = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
            stat = Path(f"/proc/{pid}/stat").read_text()
        except OSError:
            return False
        names = {os.path.basename(x.decode(errors="replace")) for x in argv[:3] if x}
        if names & {"claude", "claude-fw", "claude-code"} or any(
                b"@anthropic-ai/claude-code" in x for x in argv[:3]):
            return True
        try:
            pid = int(stat.rsplit(")", 1)[1].split()[1])
        except (IndexError, ValueError):
            return False
    return False


def _is_agent() -> bool:
    """Agent control is not decided by CLAUDECODE alone: AI_AGENT, the Claude entrypoint variable
    and the parent process chain all count, so unsetting one variable is not an escape."""
    e = os.environ
    return (e.get("CLAUDECODE") == "1" or bool(e.get("AI_AGENT"))
            or bool(e.get("CLAUDE_CODE_ENTRYPOINT")) or _agent_ancestry())


def _read_rows(path: Path) -> list:
    rows = []
    if path.exists():
        for line in path.read_text().splitlines():
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except ValueError:
                    pass  # a torn line is not a row; audit of the ledger is not this verb's job
    return rows


def _append_row(path: Path, row: dict) -> None:
    """One locked, fsynced write: a row is either wholly there or not at all."""
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (json.dumps(row, ensure_ascii=False) + "\n").encode()
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        os.write(fd, data)
        os.fsync(fd)
    finally:
        os.close(fd)


def _ledger_has(issue: int, stage: str) -> dict | None:
    for r in _read_rows(_issues_dir() / "intake.jsonl"):
        if r.get("issue") == issue and stage in str(r.get("stage", "")).split("+"):
            return r
    return None


def _next_intake_id() -> str:
    ids = [int(m.group(1)) for r in _read_rows(_issues_dir() / "intake.jsonl")
           if (m := re.match(r"INTAKE-(\d+)$", str(r.get("intake", ""))))]
    return f"INTAKE-{(max(ids) if ids else 0) + 1:04d}"


# ── gh / git ─────────────────────────────────────────────────────────────────

def _run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def _gh(args, stdin=None):
    try:
        return _run(["gh", *args], input=stdin)
    except FileNotFoundError:
        raise IssuesError("gh CLI not found on PATH", 2)


def _maintainer_login() -> str:
    p = _gh(["api", "user", "--jq", ".login"])
    login = (p.stdout or "").strip()
    if p.returncode != 0 or not login:
        raise IssuesError("cannot determine the authenticated GitHub login (gh api user) — needed "
                          f"to know whose stage markers to trust: {p.stderr.strip()[:300]}", 2)
    return login


def _marked_on_issue(issue: int, stage: str) -> bool:
    """Read the stage marker back from the issue. Untrusted text: only the marker is looked for,
    and only in comments by the authenticated maintainer login — any other account, the reporter
    included, can write a marker and so suppress a stage (T-4108)."""
    me = _maintainer_login()
    p = _gh(["issue", "view", str(issue), "--repo", _repo(), "--json", "comments"])
    if p.returncode != 0:
        raise IssuesError(f"cannot read issue #{issue} back from GitHub (needed for the "
                          f"idempotence check): {p.stderr.strip()[:300]}", 2)
    try:
        data = json.loads(p.stdout or "{}")
    except ValueError:
        raise IssuesError(f"gh returned unparseable JSON for issue #{issue}", 2)
    for c in data.get("comments") or []:
        if (c.get("author") or {}).get("login") != me:
            continue
        body = c.get("body") or ""
        for m in MARKER_RE.finditer(body):
            if stage in m.group(1).split("+"):
                return True
    return False


def _ensure_labels(names: list) -> None:
    p = _gh(["label", "list", "--repo", _repo(), "--limit", "500", "--json", "name"])
    if p.returncode != 0:
        raise IssuesError(f"cannot list labels: {p.stderr.strip()[:300]}", 2)
    try:
        have = {x["name"] for x in json.loads(p.stdout or "[]")}
    except (ValueError, KeyError, TypeError):
        raise IssuesError("gh returned unparseable label list", 2)
    for n in names:
        if n in have:
            continue
        desc, colour = LABELS[n]
        q = _gh(["label", "create", n, "--repo", _repo(), "--description", desc, "--color", colour])
        if q.returncode != 0:
            raise IssuesError(f"cannot create label {n!r}: {q.stderr.strip()[:300]}", 2)


def _commit_on_mirror(commit: str) -> None:
    remote = os.environ.get("FW_ISSUES_GIT_REMOTE", "github")
    branch = os.environ.get("FW_ISSUES_BRANCH", "bleeding-edge")
    p = _run(["git", "ls-remote", remote, f"refs/heads/{branch}"])
    tip = p.stdout.split()[0] if p.returncode == 0 and p.stdout.strip() else ""
    if not tip:
        raise IssuesError(f"cannot read {remote}/{branch} (git ls-remote {remote} failed): "
                          f"{p.stderr.strip()[:200]} — refusing to claim a fix is on GitHub", 2)
    if _run(["git", "cat-file", "-e", f"{commit}^{{commit}}"]).returncode != 0:
        raise IssuesError(f"commit {commit} is not a commit in this repository", 2)
    if _run(["git", "cat-file", "-e", f"{tip}^{{commit}}"]).returncode != 0:
        _run(["git", "fetch", "--quiet", remote, branch])
    if _run(["git", "merge-base", "--is-ancestor", commit, tip]).returncode != 0:
        raise IssuesError(f"commit {commit} is not on {remote}/{branch} (tip {tip[:9]}). The "
                          f"submitter could not pull it. Push bleeding-edge first.", 2)


# ── operator approval ────────────────────────────────────────────────────────

def _approval_ok(ref: str, issue: int, stage: str) -> bool:
    for r in _read_rows(_issues_dir() / "approvals.jsonl"):
        if (r.get("ref") == ref and r.get("issue") == issue and r.get("stage") == stage
                and r.get("by") == "human"):
            return True
    return False


# Operator ruling 2026-10-19 (T-4347): 'you can post fully automatically no approval needed'.
# Supersedes answer 1 of 2026-10-10 for decision comments, but only while the key is on.
STANDING_PERMISSION_KEY = "ISSUES_DECISIONS_STANDING_PERMISSION"
STANDING_PERMISSION_REF = "standing-permission:operator-2026-10-19"


def _standing_permission() -> bool:
    """env FW_<KEY> > .framework.yaml > 0, resolved like fw_config. Only an explicit 1 grants it."""
    raw = os.environ.get("FW_" + STANDING_PERMISSION_KEY)
    if raw in (None, ""):
        try:
            text = (_project_root() / ".framework.yaml").read_text(encoding="utf-8")
        except OSError:
            return False
        m = re.search(rf"^{STANDING_PERMISSION_KEY}:\s*['\"]?([^'\"#\n]+?)['\"]?\s*(#.*)?$", text, re.M)
        raw = m.group(1) if m else ""
    return raw.strip() == "1"


def cmd_approve(a) -> int:
    if _is_agent():
        raise IssuesError("approving a decision comment is an operator action — refused under "
                          "agent control (CLAUDECODE/AI_AGENT set, or a Claude process is an "
                          "ancestor); --i-am-human does not lift it. Hand it to the operator "
                          "(their own terminal / runme).")
    if a.stage not in DECISION_STAGES:
        raise IssuesError(f"--stage must be a decision stage: {', '.join(DECISION_STAGES)}")
    rec = {"ref": a.ref, "issue": a.issue, "stage": a.stage, "ts": _now(), "reason": a.reason or "",
           "by": "human"}
    _append_row(_issues_dir() / "approvals.jsonl", rec)
    print(f"approval {a.ref} recorded for #{a.issue} {a.stage}")
    return 0


# ── templates ────────────────────────────────────────────────────────────────

def _need(a, *fields):
    missing = [f"--{f.replace('_', '-')}" for f in fields if not getattr(a, f)]
    if missing:
        raise IssuesError(f"stage {a.stage} needs {', '.join(missing)}")


def render(a, date: str, intake: str = "") -> str:
    st = a.stage
    tasks = [t for t in (a.task or [])]
    t_md = ", ".join(f"**{t}**" for t in tasks)
    text = (a.text or "").strip()
    out = [f"<!-- aef-intake:stage={st} -->", f"**[AEF intake] {TITLES[st]}** — {date}", ""]
    if st == "received":
        out.append(f"Thank you. This issue has been ingested into the Agentic Engineering "
                   f"Framework's intake as **{intake}**. Next step: classification (type, "
                   f"affected area, severity, whether it reproduces on the current release and "
                   f"on bleeding-edge). You will get a comment here at each step: classified → "
                   f"decision → in progress → fixed on bleeding-edge → available for testing → "
                   f"released.")
    elif st == "classified":
        _need(a, "text")
        out += [text, "", "Awaiting the maintainer's decision."]
    elif st == "accepted":
        _need(a, "task")
        out.append(f"Tracked as {t_md}, prioritised (horizon: now). Next update here: in progress.")
        if text:
            out += ["", text]
    elif st == "needs-info":
        _need(a, "text")
        out += ["More information is needed before this can be decided:", "", text]
    elif st == "duplicate":
        _need(a, "text")
        out += ["This duplicates an existing report or task:", "", text]
    elif st == "not-planned":
        _need(a, "text")
        out += ["This is not planned. Reason:", "", text]
    elif st == "in-progress":
        _need(a, "task")
        out.append(f"Work has started under {t_md}." + (f" {text}" if text else "")
                   + " Next update here: fixed on bleeding-edge.")
    elif st == "fixed-on-bleeding-edge":
        _need(a, "task", "commit", "test_cmd")
        out.append(f"Fixed under {t_md} in commit {a.commit} (on the `bleeding-edge` branch; "
                   f"not yet in a release).")
        if text:
            out += ["", text]
        out += ["", f"**To test it before the release:** `{a.test_cmd}` Feedback here is "
                    f"welcome. Next update here: released."]
    elif st == "available-for-testing":
        _need(a, "task", "version")
        out.append(f"{t_md} is available for testing in **{a.version}**." + (f" {text}" if text else ""))
        if a.test_cmd:
            out += ["", f"**To try it:** `{a.test_cmd}`"]
        out += ["", "Does this fix it for you? Your confirmation here is the strongest evidence "
                    "we can get. Next update here: released."]
    elif st == "released":
        _need(a, "task", "version")
        out.append(f"{t_md} is released in **{a.version}**." + (f" {text}" if text else ""))
        if getattr(a, "closing", False):
            out += ["", "This issue is closed with this release: the fix is in it and the field evidence "
                        "below confirms it."]
        elif getattr(a, "please_confirm", False):
            out += ["", "Please confirm it fixes this for you. Reply here if it does not. With no reply in "
                        f"{RELEASE_DUE_DAYS} days this issue is closed with a note, and you can reopen it."]
        evidence = (getattr(a, "evidence", "") or "").strip()
        if evidence:
            out += ["", evidence]
    out += ["", FOOTER]
    return "\n".join(out) + "\n"


# ── comment ──────────────────────────────────────────────────────────────────

_TASK_RE = re.compile(r"^T-\d+$")
_COMMIT_RE = re.compile(r"^[0-9a-f]{7,40}$")
_VERSION_RE = re.compile(r"^v?\d+\.\d+\.\d+([-.][0-9A-Za-z.]+)?$")


def cmd_comment(a) -> int:
    st = a.stage
    for t in a.task or []:
        if not _TASK_RE.match(t):
            raise IssuesError(f"--task must be T-NNN, got {t!r}")
    if a.commit and not _COMMIT_RE.match(a.commit):
        raise IssuesError(f"--commit must be a hex sha, got {a.commit!r}")
    if a.version and not _VERSION_RE.match(a.version):
        raise IssuesError(f"--version must look like vX.Y.Z[-be.N], got {a.version!r}")
    if a.test_cmd and ("`" in a.test_cmd or "\n" in a.test_cmd):
        raise IssuesError("--test-cmd must be one line without backticks")

    standing = ""
    if st in DECISION_STAGES and not a.approved_by_operator and _standing_permission():
        standing = STANDING_PERMISSION_REF
    elif st in DECISION_STAGES:
        if not a.approved_by_operator:
            raise IssuesError(f"stage {st} is a decision: it needs --approved-by-operator <ref>")
        if _is_agent() and not _approval_ok(a.approved_by_operator, a.issue, st):
            raise IssuesError(f"stage {st}: under CLAUDECODE=1 the ref "
                              f"{a.approved_by_operator!r} must be an operator approval record "
                              f"for #{a.issue} {st} (`fw issues approve` run by the operator)")

    prior = _ledger_has(a.issue, st)
    if prior:
        print(f"#{a.issue} stage {st} already posted ({prior.get('comment', 'no url')}) — not posting again")
        return 0
    if st == "fixed-on-bleeding-edge":
        _need(a, "commit", "test_cmd")
        _commit_on_mirror(a.commit)
    if not a.dry_run and _marked_on_issue(a.issue, st):
        print(f"#{a.issue} stage {st} already marked on the issue — not posting again")
        return 0

    date = _now()[:10]
    intake = _next_intake_id() if st == "received" else ""
    body = render(a, date, intake)
    if a.dry_run:
        print(body, end="")
        return 0

    labels = STAGE_LABELS[st]
    _ensure_labels(labels)
    p = _gh(["issue", "comment", str(a.issue), "--repo", _repo(), "--body-file", "-"], stdin=body)
    url = next((w for w in p.stdout.split() if w.startswith("https://")), "") if p.returncode == 0 else ""
    if not url:
        raise IssuesError(f"GitHub did not return a comment URL (rc={p.returncode}): "
                          f"{(p.stderr or p.stdout).strip()[:300]}. Nothing was logged; check the "
                          f"issue before retrying.", 3)
    row = {"issue": a.issue, "stage": st}
    if intake:
        row["intake"] = intake
    if a.task:
        row["tasks"] = a.task
    if a.commit:
        row["commit"] = a.commit
    if a.version:
        row["version"] = a.version
    if standing:
        row["approved_by"] = standing
    row.update(getattr(a, "extra", None) or {})  # sync's classification fields ride on the row
    if st == "released" and getattr(a, "please_confirm", False):
        row["due"] = (datetime.now(timezone.utc) + timedelta(days=RELEASE_DUE_DAYS)).strftime("%Y-%m-%d")
    row.update(comment=url, ts=_now())
    try:
        _append_row(_issues_dir() / "intake.jsonl", row)
    except OSError as e:
        print(f"LOUD: comment POSTED at {url} but the ledger write failed ({e}). Reconcile by "
              f"appending this row to intake.jsonl:\n{json.dumps(row)}", file=sys.stderr)
        return 4
    e = _gh(["issue", "edit", str(a.issue), "--repo", _repo(), "--add-label", ",".join(labels)])
    if e.returncode != 0:
        print(f"WARN: comment posted and logged ({url}) but adding labels failed: "
              f"{e.stderr.strip()[:200]}", file=sys.stderr)
    print(f"posted {st} on #{a.issue}: {url}")
    return 0


# ── sync (T-4078) ────────────────────────────────────────────────────────────
# Reads the repo's open issues and records what is new to the ledger. Posting goes through
# cmd_comment (the one outward verb) so the idempotence and template rules apply here too.
# Everything read from GitHub is untrusted: it is hashed, compared, searched for ids and
# quoted into the ledger; the only text posted publicly is built from this file's own vocabulary.

ROUTES = {  # operator ruling 2026-10-10: every issue by this submitter goes to arc-021, horizon now
    "mikeechovoid": {"arc_id": "mikeechovoid-requests", "horizon": "now"},
}
DUP_THRESHOLD = 0.6   # Jaccard over title words; a hint only, never a decision
AREAS = {"lib", "bin", "agents", "web", "tests", "docs", "policy"}


def _project_root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def _login(obj) -> str:
    return (obj or {}).get("login") or ""


def _body_hash(issue: dict) -> str:
    return hashlib.sha256(f"{issue.get('title') or ''}\0{issue.get('body') or ''}".encode()).hexdigest()[:16]


def _has(rows: list, n: int, stage: str) -> bool:
    return any(r.get("issue") == n and stage in str(r.get("stage", "")).split("+") for r in rows)


def _list_open_issues() -> list:
    p = _gh(["issue", "list", "--repo", _repo(), "--state", "open", "--limit", "500",
             "--json", "number,title,body,author,labels,comments"])
    if p.returncode != 0:
        raise IssuesError(f"cannot list issues: {p.stderr.strip()[:300]}", 2)
    try:
        return json.loads(p.stdout or "[]")
    except ValueError:
        raise IssuesError("gh returned unparseable issue list", 2)


def _task_slugs() -> list:
    out = []
    for sub in ("active", "completed"):
        d = _project_root() / ".tasks" / sub
        if d.is_dir():
            for f in d.glob("T-*.md"):
                m = re.match(r"(T-\d+)-(.*)\.md$", f.name)
                if m:
                    out.append((m.group(1), m.group(2).replace("-", " ")))
    return out


def _words(s: str) -> set:
    return {w for w in re.findall(r"[a-z0-9]+", (s or "").lower()) if len(w) >= 4}


def _similar(a: str, b: str) -> float:
    wa, wb = _words(a), _words(b)
    return len(wa & wb) / len(wa | wb) if wa and wb else 0.0


def _classify(issue: dict, others: list, tasks: list, owner: str) -> dict:
    title = issue.get("title") or ""
    body = issue.get("body") or ""
    author = _login(issue.get("author"))
    labels = {(x.get("name") or "").lower() for x in issue.get("labels") or []}
    lt = title.strip().lower()
    if author.lower() == owner.lower():
        typ = "internal"
    elif "bug" in labels or re.match(r"(bug|fix|error|crash)\b", lt):
        typ = "bug"
    elif "proposal" in labels or lt.startswith("proposal"):
        typ = "proposal"
    elif "question" in labels or lt.endswith("?"):
        typ = "question"
    elif labels & {"enhancement", "feature"} or re.match(r"(enhancement|feature|add)\b", lt):
        typ = "enhancement"
    else:
        typ = "question"  # unclear from the title: parked for the maintainer to read
    m = re.search(r"\b(lib|bin|agents|web|tests|docs|policy)/", f"{title} {body}")
    area = m.group(1) if m and m.group(1) in AREAS else "unspecified"
    if typ in ("enhancement", "question", "proposal"):
        sev = "low"
    elif re.search(r"data loss|corrupt|crash|security|cannot|fails? on every", f"{title} {body}".lower()):
        sev = "high"
    else:
        sev = "medium"
    best, hint = 0.0, ""
    for n2, t2 in others:
        s = _similar(title, t2)
        if s > best:
            best, hint = s, f"#{n2}"
    for tid, slug in tasks:
        s = _similar(title, slug)
        if s > best:
            best, hint = s, tid
    route = ROUTES.get(author.lower(), {})
    return {"class": "internal" if typ == "internal" else "external", "type": typ, "area": area,
            "severity": sev, "duplicate_hint": hint if best >= DUP_THRESHOLD else "",
            "arc_id": parse_arc_id_value(route.get("arc_id", "")), "horizon": route.get("horizon", "")}


def _classified_text(c: dict) -> str:
    lines = [f"Type: {c['type']}; area: {c['area']}; severity: {c['severity']}."]
    if c["duplicate_hint"]:
        lines.append(f"Possible duplicate of {c['duplicate_hint']} (title similarity; not confirmed).")
    return "\n".join(lines)


def _stage_comment(n: int, stage: str, text, extra: dict) -> None:
    cmd_comment(argparse.Namespace(issue=n, stage=stage, task=None, commit=None, test_cmd=None,
                                   version=None, text=text, approved_by_operator=None,
                                   dry_run=False, extra=extra))


def cmd_sync(a) -> int:
    issues = _list_open_issues()
    ledger = _issues_dir() / "intake.jsonl"
    rows = _read_rows(ledger)
    owner = _repo().split("/")[0]
    tasks = _task_slugs()
    counts = {"new": 0, "classified": 0, "edited": 0, "reply": 0}
    lines = []
    for it in sorted(issues, key=lambda i: int(i.get("number", 0))):
        n = int(it["number"])
        title = it.get("title") or ""
        author = _login(it.get("author"))
        internal = author.lower() == owner.lower()
        h = _body_hash(it)
        is_new = not _has(rows, n, "received")
        needs_cls = is_new or not _has(rows, n, "classified")
        c: dict = {}
        if needs_cls:
            others = [(int(i["number"]), i.get("title") or "") for i in issues if int(i["number"]) != n]
            c = _classify(it, others, tasks, owner)
        if is_new:
            counts["new"] += 1
            lines.append(f"NEW #{n} from {author or '?'}: {c['type']}/{c['area']}/{c['severity']}"
                         + (f", arc {c['arc_id']}" if c["arc_id"] else ""))
            if not a.dry_run:
                _stage_comment(n, "received", None, {"body_hash": h, "title": title[:120],
                                                     "author": author})
        if needs_cls and not _has(rows, n, "classified"):
            counts["classified"] += 1
            if not a.dry_run:
                _stage_comment(n, "classified", _classified_text(c),
                               {k: v for k, v in c.items() if v})
        if not is_new:
            prior = [r["body_hash"] for r in rows if r.get("issue") == n and r.get("body_hash")]
            if not prior:
                if not a.dry_run:
                    _append_row(ledger, {"issue": n, "stage": "baseline", "body_hash": h, "ts": _now()})
            elif prior[-1] != h:
                counts["edited"] += 1
                lines.append(f"EDITED #{n}: title or body changed; recorded, not re-classified")
                if not a.dry_run:
                    _append_row(ledger, {"issue": n, "stage": "edited", "body_hash": h,
                                         "prev_body_hash": prior[-1], "ts": _now()})
        if internal:
            continue  # the operator reads their own comments directly; nothing to surface
        seen = {str(r.get("reply_id")) for r in rows if r.get("issue") == n and r.get("stage") == "reply"}
        for cm in it.get("comments") or []:
            rid = str(cm.get("id") or "")
            if not rid or rid in seen or _login(cm.get("author")).lower() != author.lower():
                continue
            seen.add(rid)
            counts["reply"] += 1
            lines.append(f"REPLY #{n} from {author}: recorded, NOT answered (read it on the issue)")
            if not a.dry_run:
                _append_row(ledger, {"issue": n, "stage": "reply", "reply_id": rid, "author": author,
                                     "created": cm.get("createdAt") or "",
                                     "excerpt": (cm.get("body") or "")[:500], "answered": False,
                                     "ts": _now()})
    for ln in lines:
        print(ln)
    tag = " (dry-run: nothing posted or written)" if a.dry_run else ""
    print(f"sync: {counts['new']} new, {counts['classified']} classified, {counts['edited']} edited, "
          f"{counts['reply']} submitter replies{tag}")
    try:  # T-4340: the scheduled step that closes overdue please-confirm issues rides on sync
        _sweep(_now()[:10], a.dry_run)
    except IssuesError as e:
        print(f"WARN: overdue sweep not run: {e}", file=sys.stderr)
    return 0


# ── close (T-4088) ───────────────────────────────────────────────────────────
# Operator standing instruction 2026-10-12: INTERNAL issues (authored by the repo owner, i.e. the
# framework's own `fw upstream` identity) that are fixed or duplicated are closed with ONE comment
# and no per-issue approval. External issues are never touched: the author check is the gate.

CLOSE_STAGES = {"fixed": "closed-fixed", "duplicate": "closed-duplicate"}


def _close_render(a, date: str) -> str:
    st = CLOSE_STAGES[a.reason]
    t_md = ", ".join(f"**{t}**" for t in (a.task or []))
    out = [f"<!-- aef-intake:stage={st} -->", f"**[AEF intake] Closed: {a.reason}** — {date}", ""]
    if a.reason == "fixed":
        where = f"released in **{a.release}**" if a.release else (
            "on the `bleeding-edge` branch; it ships in the next release")
        out.append(f"Fixed under {t_md} in commit {a.commit} ({where}).")
    else:
        out.append(f"Duplicate of #{a.of}." if a.of else f"Covered by {t_md}.")
    if (a.text or "").strip():
        out += ["", a.text.strip()]
    out += ["", FOOTER]
    return "\n".join(out) + "\n"


def cmd_close(a) -> int:
    if a.reason == "fixed":
        if not a.task or not a.commit:
            raise IssuesError("--as fixed needs --task and --commit")
    elif not (a.of or a.task):
        raise IssuesError("--as duplicate needs --of <issue> or --task")
    for t in a.task or []:
        if not _TASK_RE.match(t):
            raise IssuesError(f"--task must be T-NNN, got {t!r}")
    if a.commit and not _COMMIT_RE.match(a.commit):
        raise IssuesError(f"--commit must be a hex sha, got {a.commit!r}")
    if a.release and not _VERSION_RE.match(a.release):
        raise IssuesError(f"--release must look like vX.Y.Z, got {a.release!r}")
    st = CLOSE_STAGES[a.reason]
    owner = _repo().split("/")[0]
    p = _gh(["issue", "view", str(a.issue), "--repo", _repo(), "--json", "state,author"])
    if p.returncode != 0:
        raise IssuesError(f"cannot read issue #{a.issue}: {p.stderr.strip()[:300]}", 2)
    try:
        info = json.loads(p.stdout or "{}")
    except ValueError:
        raise IssuesError(f"gh returned unparseable JSON for issue #{a.issue}", 2)
    author = _login(info.get("author"))
    if author.lower() != owner.lower():
        raise IssuesError(f"#{a.issue} is by {author or '?'}, not {owner}: not an internal issue, "
                          f"refusing to comment or close", 2)
    if str(info.get("state", "")).upper() != "OPEN":
        print(f"#{a.issue} is already {info.get('state')} — skipped")
        return 0
    if a.reason == "fixed":
        _commit_on_mirror(a.commit)
    prior = _ledger_has(a.issue, st)
    url = (prior or {}).get("comment", "")
    if not prior:
        if _marked_on_issue(a.issue, st):
            print(f"#{a.issue} already carries the {st} comment — not posting again")
        else:
            body = _close_render(a, _now()[:10])
            if a.dry_run:
                print(body, end="")
                return 0
            c = _gh(["issue", "comment", str(a.issue), "--repo", _repo(), "--body-file", "-"], stdin=body)
            url = next((w for w in c.stdout.split() if w.startswith("https://")), "") if c.returncode == 0 else ""
            if not url:
                raise IssuesError(f"GitHub did not return a comment URL (rc={c.returncode}): "
                                  f"{(c.stderr or c.stdout).strip()[:300]}. Nothing was logged; check "
                                  f"the issue before retrying.", 3)
            row = {"issue": a.issue, "stage": st}
            for k, v in (("tasks", a.task), ("commit", a.commit), ("release", a.release), ("of", a.of)):
                if v:
                    row[k] = v
            row.update(comment=url, ts=_now())
            try:
                _append_row(_issues_dir() / "intake.jsonl", row)
            except OSError as e:
                print(f"LOUD: comment POSTED at {url} but the ledger write failed ({e}). Reconcile by "
                      f"appending this row to intake.jsonl:\n{json.dumps(row)}", file=sys.stderr)
                return 4
    elif a.dry_run:
        print(f"#{a.issue} {st} already logged ({url}); would only close")
        return 0
    gh_reason = "completed" if a.reason == "fixed" else "not planned"
    q = _gh(["issue", "close", str(a.issue), "--repo", _repo(), "--reason", gh_reason])
    if q.returncode != 0:
        raise IssuesError(f"comment is on #{a.issue} ({url}) but closing failed: "
                          f"{q.stderr.strip()[:300]}. Re-run to retry the close only.", 3)
    print(f"closed #{a.issue} ({a.reason}): {url}")
    return 0


# ── release leg (T-4340, lifecycle stages 8-9) ──────────────────────────────
# lib/release.sh calls `release` after the tag is published. For each task in the commit range that
# carries github_issue:, the Released stage goes through cmd_comment (the one outward verb) with an
# evidence block. Close rule (operator 2026-10-18): close when the task is completed AND the field
# report has a WORKS row for it; otherwise post "please confirm" with a due date, and `sweep` (run
# from sync) closes it after RELEASE_DUE_DAYS unless the submitter has replied since. A task still in
# active/ (awaiting review) and a field verdict of FAILS are held: nothing posted, issue stays open.
# A GitHub failure is recorded in release-pending.jsonl and never fails the release.

RELEASE_DUE_DAYS = 14
_FIELD_VERDICT_RE = re.compile(r"\b(WORKS|BROKEN|FAILS?)\b")


def _range_task_ids(root: Path, rng: str) -> list:
    p = _run(["git", "-C", str(root), "log", "--format=%s", rng])
    if p.returncode != 0:
        raise IssuesError(f"cannot read git log {rng}: {p.stderr.strip()[:200]}", 2)
    out: list = []
    for subject in reversed(p.stdout.splitlines()):  # oldest first
        m = re.match(r"(T-\d+)\b", subject)
        if m and m.group(1) not in out:
            out.append(m.group(1))
    return out


def _task_facts(root: Path, tid: str) -> dict | None:
    hits = sorted(root.glob(f".tasks/*/{tid}-*.md"))
    if not hits:
        return None
    path = hits[0]
    text = path.read_text(errors="replace")
    fm = text.split("---", 2)[1] if text.startswith("---") and text.count("---") >= 2 else ""
    m = re.search(r"^github_issue:\s*\"?(\d+)\"?\s*$", fm, re.M)
    return {"issue": int(m.group(1)) if m else None,
            "state": "completed" if path.parent.name == "completed" else "active",
            "tests": _verification_tests(text)}


def _verification_tests(text: str) -> list:
    """Test files and test_ names named in the task's ## Verification command lines."""
    m = re.search(r"^## Verification\s*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not m:
        return []
    body = "\n".join(x for x in m.group(1).splitlines() if x.strip() and not x.lstrip().startswith("#"))
    files = re.findall(r"tests/[\w./-]+\.(?:py|bats)", body)
    names = re.findall(r"\btest_\w+", body)
    return list(dict.fromkeys(files + names))


def _field_verdicts(path: Path) -> dict:
    """Per task id, the verdict in a release's field-evidence report. Only table rows count: a row
    whose first cell names T-NNNN is a verdict for those tasks when a later cell says WORKS or
    BROKEN/FAILS. Prose that mentions a task is not evidence.
    Returns {tid: {"verdict": "works" | "fails" | None, "evidence": [str, ...]}}."""
    out: dict = {}
    if not path.exists():
        return out
    header: list = []
    section = ""
    for line in path.read_text(errors="replace").splitlines():
        s = line.strip()
        if s.startswith("#"):
            section = s.lstrip("#").strip()
        if not s.startswith("|"):
            header = []
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if all(set(c) <= set("-: ") for c in cells):
            continue  # the |---|---| separator
        if not header:
            header = cells
            continue
        for tid in set(re.findall(r"\bT-\d+\b", cells[0])):
            rec = out.setdefault(tid, {"fails": False, "evidence": []})
            for i, cell in enumerate(cells[1:], start=1):
                words = set(_FIELD_VERDICT_RE.findall(cell))
                if words & {"BROKEN", "FAIL", "FAILS"}:
                    rec["fails"] = True
                if "WORKS" in words:
                    col = header[i] if i < len(header) else "field"
                    rec["evidence"].append(f"{section or 'field report'}, {col}: {cell[:200]}")
    for rec in out.values():
        rec["verdict"] = "fails" if rec.pop("fails") else ("works" if rec["evidence"] else None)
    return out


def _evidence_block(version: str, g: dict, root: Path) -> str:
    repo = _repo()
    report = root / "docs" / "reports" / f"field-test-{version}-results.md"
    tests = g["tests"]
    lines = ["**How it was tested:** " + (", ".join(tests) if tests else
                                          "see the task's Verification block (no test file is named there).")]
    if g["evidence"]:
        lines.append("**Field evidence:**")
        lines += [f"- {e}" for e in g["evidence"][:6]]
    else:
        lines.append(f"**Field evidence:** none recorded for this fix in docs/reports/field-test-{version}-results.md yet.")
    lines.append(f"**Why it was released:** the release gates passed (remote fast-forward check, atomic publish "
                 f"to every push remote, tag {version}); the fix is on master in {version}.")
    links = [f"release notes https://github.com/{repo}/releases/tag/{version}"]
    if report.exists():
        links.append(f"field-evidence report https://github.com/{repo}/blob/master/docs/reports/"
                     f"field-test-{version}-results.md")
    lines.append("**Links:** " + " · ".join(links))
    return "\n".join(lines)


def _record_pending(issue: int, stage: str, version: str, err) -> None:
    try:
        _append_row(_issues_dir() / "release-pending.jsonl",
                    {"issue": issue, "stage": stage, "version": version, "error": str(err)[:300], "ts": _now()})
    except OSError as e:
        print(f"WARN: could not record #{issue} for retry ({e})", file=sys.stderr)


def _issue_view(n: int) -> dict:
    p = _gh(["issue", "view", str(n), "--repo", _repo(), "--json", "state,author,comments"])
    if p.returncode != 0:
        raise IssuesError(f"cannot read issue #{n}: {p.stderr.strip()[:300]}", 2)
    try:
        return json.loads(p.stdout or "{}")
    except ValueError:
        raise IssuesError(f"gh returned unparseable JSON for issue #{n}", 2)


def _ts(s: str) -> datetime | None:
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (TypeError, ValueError):
        return None


def _replies_since(n: int, info: dict, since: str) -> list:
    """Anything from someone other than the maintainer after `since`: a GitHub comment, or a reply
    the sync verb ingested. An unreadable time counts as a reply: when in doubt the issue stays open."""
    maint = _maintainer_login().lower()
    cut = _ts(since)
    found = []
    for c in info.get("comments") or []:
        who = _login(c.get("author"))
        if who.lower() == maint:
            continue
        t = _ts(c.get("createdAt") or "")
        if cut is None or t is None or t > cut:
            found.append(f"comment by {who or '?'} at {c.get('createdAt') or '?'}")
    for r in _read_rows(_issues_dir() / "intake.jsonl"):
        if r.get("issue") == n and r.get("stage") == "reply":
            t = _ts(r.get("ts") or "")
            if cut is None or t is None or t > cut:
                found.append(f"reply ingested by sync at {r.get('ts') or '?'}")
    return found


def _closed_note(version: str, date: str) -> str:
    out = ["<!-- aef-intake:stage=closed-released -->", f"**[AEF intake] Closed: released** — {date}", "",
           f"Released in **{version}**. No reply in {RELEASE_DUE_DAYS} days, so this issue is closed. "
           "It can be reopened if the fix does not work for you.", "", FOOTER]
    return "\n".join(out) + "\n"


def _close_issue(n: int, since: str, version: str, comment_url: str, note: str = "",
                 dry_run: bool = False) -> str:
    """Close #n unless the submitter has replied since `since`. Returns closed | kept | already |
    would-close. The closed row is written only after GitHub accepted the close, so a failed close
    is retried by the next run."""
    info = _issue_view(n)
    if str(info.get("state", "")).upper() != "OPEN":
        if not dry_run:
            _append_row(_issues_dir() / "intake.jsonl", {"issue": n, "stage": "closed-released",
                                                          "release": version, "comment": comment_url,
                                                          "note": "already closed", "ts": _now()})
        return "already"
    if _replies_since(n, info, since):
        return "kept"
    if dry_run:
        return "would-close"
    if note and not _marked_on_issue(n, "closed-released"):
        p = _gh(["issue", "comment", str(n), "--repo", _repo(), "--body-file", "-"], stdin=note)
        url = next((w for w in p.stdout.split() if w.startswith("https://")), "") if p.returncode == 0 else ""
        if not url:
            raise IssuesError(f"GitHub did not return a comment URL for the close note on #{n}: "
                              f"{(p.stderr or p.stdout).strip()[:300]}", 3)
        _append_row(_issues_dir() / "intake.jsonl", {"issue": n, "stage": "closed-note", "comment": url,
                                                      "release": version, "ts": _now()})
    q = _gh(["issue", "close", str(n), "--repo", _repo(), "--reason", "completed"])
    if q.returncode != 0:
        raise IssuesError(f"#{n} is commented but closing failed: {q.stderr.strip()[:300]}. "
                          f"Re-run to retry the close only.", 3)
    _append_row(_issues_dir() / "intake.jsonl", {"issue": n, "stage": "closed-released", "release": version,
                                                  "comment": comment_url, "ts": _now()})
    return "closed"


def _sweep(today: str, dry_run: bool) -> None:
    """Close please-confirm issues whose due date has passed and that drew no reply."""
    done = 0
    for r in _read_rows(_issues_dir() / "intake.jsonl"):
        if r.get("stage") != "released" or not r.get("due") or str(r["due"]) > today:
            continue
        n = int(r["issue"])
        if _ledger_has(n, "closed-released"):
            continue
        version = r.get("version") or ""
        try:
            outcome = _close_issue(n, r.get("ts") or "", version, r.get("comment") or "",
                                   note=_closed_note(version, today), dry_run=dry_run)
        except IssuesError as e:
            _record_pending(n, "closed-released", version, e)
            print(f"WARN  #{n}: close not done ({e}); recorded in release-pending.jsonl", file=sys.stderr)
            continue
        if outcome == "kept":
            print(f"keep   #{n}: the submitter replied after the Released comment; left open for the operator")
        else:
            done += outcome in ("closed", "would-close", "already")
            print(f"{outcome:9} #{n}: please-confirm was due {r['due']}")
    tag = " (dry-run)" if dry_run else ""
    print(f"sweep: {done} overdue please-confirm issue(s) handled{tag}")


def cmd_sweep(a) -> int:
    if a.today and not re.match(r"^\d{4}-\d{2}-\d{2}$", a.today):
        raise IssuesError("--today must be YYYY-MM-DD")
    _sweep(a.today or _now()[:10], a.dry_run)
    return 0


def cmd_release(a) -> int:
    if not _VERSION_RE.match(a.version or ""):
        raise IssuesError(f"version must look like vX.Y.Z, got {a.version!r}", 2)
    if not re.match(r"^\S+\.\.\S+$", a.rng or ""):
        raise IssuesError(f"--range must be A..B, got {a.rng!r}", 2)
    root = Path(a.root) if a.root else _project_root()
    field = _field_verdicts(root / "docs" / "reports" / f"field-test-{a.version}-results.md")
    groups: dict = {}
    for tid in _range_task_ids(root, a.rng):
        t = _task_facts(root, tid)
        if t is None or t["issue"] is None:
            continue  # no task file, or no github_issue: nothing to post
        g = groups.setdefault(t["issue"], {"tasks": [], "tests": [], "verdicts": [], "evidence": [],
                                           "held": None})
        f = field.get(tid, {"verdict": None, "evidence": []})
        g["tasks"].append(tid)
        g["tests"] += [x for x in t["tests"] if x not in g["tests"]]
        g["verdicts"].append(f["verdict"] or "none")
        g["evidence"] += f["evidence"]
        if t["state"] != "completed":
            g["held"] = f"{tid} is still active (awaiting review); not posted. Re-run after it completes"
        elif f["verdict"] == "fails":
            g["held"] = f"field report says FAILS for {tid}; keep the issue open and file a new task"
    posted = closed = held = failed = 0
    for n, g in groups.items():
        tasks = ", ".join(g["tasks"])
        if g["held"]:
            print(f"hold   #{n} ({tasks}): {g['held']}")
            held += 1
            continue
        close = all(v == "works" for v in g["verdicts"])
        prior = _ledger_has(n, "released")
        if prior is None:
            ns = argparse.Namespace(issue=n, stage="released", task=g["tasks"], commit=None, test_cmd=None,
                                    version=a.version, text=None, approved_by_operator=None,
                                    dry_run=a.dry_run, evidence=_evidence_block(a.version, g, root),
                                    please_confirm=not close, closing=close)
            if a.dry_run:
                print(f"would post released on #{n} ({tasks}): {'close' if close else 'please-confirm'}")
                cmd_comment(ns)
            else:
                try:
                    rc = cmd_comment(ns)
                except IssuesError as e:
                    _record_pending(n, "released", a.version, e)
                    print(f"WARN   #{n}: released comment not posted ({e}); recorded in "
                          f"release-pending.jsonl, re-run to retry", file=sys.stderr)
                    failed += 1
                    continue
                if rc:
                    _record_pending(n, "released", a.version, f"cmd_comment returned {rc}")
                    failed += 1
                    continue
                prior = _ledger_has(n, "released")
                posted += 1
        else:
            print(f"have   #{n}: released already logged ({prior.get('comment', 'no url')})")
        if not close or _ledger_has(n, "closed-released"):
            continue
        if a.dry_run:
            print(f"would close #{n} (completed, WORKS in the field report)")
            continue
        try:
            outcome = _close_issue(n, (prior or {}).get("ts") or "", a.version, (prior or {}).get("comment") or "")
        except IssuesError as e:
            _record_pending(n, "closed-released", a.version, e)
            print(f"WARN   #{n}: close not done ({e}); recorded in release-pending.jsonl", file=sys.stderr)
            failed += 1
            continue
        if outcome == "closed":
            closed += 1
        print(f"{outcome:9} #{n} ({tasks})")
    print(f"release {a.version}: {posted} posted, {closed} closed, {held} held, {failed} failed"
          + (" (dry-run: nothing posted or closed)" if a.dry_run else ""))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="fw issues")
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("comment", help="post a stage comment on a GitHub issue")
    c.add_argument("issue", type=int)
    c.add_argument("--stage", required=True, choices=STAGES)
    c.add_argument("--task", action="append")
    c.add_argument("--commit")
    c.add_argument("--test-cmd")
    c.add_argument("--version")
    c.add_argument("--text")
    c.add_argument("--approved-by-operator", metavar="REF")
    c.add_argument("--evidence", help="released: the evidence block (how tested, field, why released)")
    c.add_argument("--please-confirm", action="store_true",
                   help="released: ask the reporter to confirm; records a due date for the sweep (T-4340)")
    c.add_argument("--dry-run", action="store_true", help="print the comment, post nothing")
    c.set_defaults(fn=cmd_comment)
    rl = sub.add_parser("release", help="post the Released stage for a release's tasks, apply the close rule (T-4340)")
    rl.add_argument("version", help="the release tag, vX.Y.Z")
    rl.add_argument("--range", dest="rng", required=True, help="commit range, e.g. v1.8.10..HEAD")
    rl.add_argument("--root", help="project root (default PROJECT_ROOT or cwd)")
    rl.add_argument("--dry-run", action="store_true", help="list what would be posted and closed; post nothing")
    rl.set_defaults(fn=cmd_release)
    sw = sub.add_parser("sweep", help="close overdue please-confirm issues with a note (T-4340; also runs in sync)")
    sw.add_argument("--dry-run", action="store_true")
    sw.add_argument("--today", help="YYYY-MM-DD (default: today, UTC)")
    sw.set_defaults(fn=cmd_sweep)
    ap_ = sub.add_parser("approve", help="operator: record approval of a decision comment")
    ap_.add_argument("ref")
    ap_.add_argument("--issue", type=int, required=True)
    ap_.add_argument("--stage", required=True)
    ap_.add_argument("--reason")
    ap_.add_argument("--i-am-human", action="store_true")
    ap_.set_defaults(fn=cmd_approve)
    cl = sub.add_parser("close", help="close an INTERNAL issue as fixed/duplicate with one comment (T-4088)")
    cl.add_argument("issue", type=int)
    cl.add_argument("--as", dest="reason", required=True, choices=sorted(CLOSE_STAGES))
    cl.add_argument("--task", action="append")
    cl.add_argument("--commit")
    cl.add_argument("--release")
    cl.add_argument("--of", type=int, help="duplicate: the original issue number")
    cl.add_argument("--text")
    cl.add_argument("--dry-run", action="store_true", help="print the comment, post and close nothing")
    cl.set_defaults(fn=cmd_close)
    s = sub.add_parser("sync", help="ingest new/changed issues and submitter replies (cron)")
    s.add_argument("--dry-run", action="store_true", help="list what would change; post and write nothing")
    s.set_defaults(fn=cmd_sync)
    a = ap.parse_args(argv)
    try:
        return a.fn(a)
    except IssuesError as e:
        print(f"fw issues: {e}", file=sys.stderr)
        return e.code


if __name__ == "__main__":
    sys.exit(main())
