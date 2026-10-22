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
import socket
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from fnmatch import fnmatchcase
from pathlib import Path

import yaml

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
    "status:available-for-testing": ("Fix is in a pre-release for testing", "1d76db"),
    "status:released": ("Released", "0e8a16"),
}
STAGE_LABELS = {
    "received": ["status:received"], "classified": ["triaged"],
    "accepted": ["status:accepted"], "needs-info": ["status:needs-info"],
    "duplicate": ["status:duplicate"], "not-planned": ["status:not-planned"],
    "in-progress": ["status:in-progress"],
    "fixed-on-bleeding-edge": ["status:fixed-on-bleeding-edge"],
    "available-for-testing": ["status:available-for-testing"], "released": ["status:released"],
}
# T-4412: status:* labels are a state, not a history — one at a time. LEGACY_STATUS_LABELS were
# once added beside the status:* label and are removed with the other status labels.
LEGACY_STATUS_LABELS = {"fixed-on-bleeding-edge"}


def _is_status_label(name: str) -> bool:
    return name.startswith("status:") or name in LEGACY_STATUS_LABELS


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


def _label_spec(name: str) -> tuple:
    if name in LABELS:
        return LABELS[name]
    if name.startswith("area:"):  # T-4411: one per area in policy/issue-areas.yaml
        return (f"Area {name[5:]} (from the component fabric)", "c5def5")
    if name.startswith("severity:"):
        return (f"Severity {name[9:]}", {"high": "b60205", "medium": "fbca04"}.get(name[9:], "c2e0c6"))
    raise IssuesError(f"no definition for label {name!r}", 2)


def _triage_labels(area: str, severity: str) -> list:
    """area:<x> / severity:<y> (T-4411); 'unspecified' and unknown severities get no label."""
    out = [f"area:{area}"] if area and area != "unspecified" else []
    return out + ([f"severity:{severity}"] if severity in SEVERITIES else [])


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
        desc, colour = _label_spec(n)
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
        if "-be." in a.version:  # T-4500: a shallow tag clone is refused by fw upgrade
            out += ["", "Upgrade from a non-shallow clone of the tag (no `--depth`): a shallow clone "
                        "cannot see your project's recorded version_sha, so `fw upgrade` refuses it as "
                        "foreign-source. Already cloned shallow? Run `git -C <clone> fetch --unshallow`, "
                        "then re-run `fw upgrade`."]
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


def _current_labels(n: int) -> list:
    p = _gh(["issue", "view", str(n), "--repo", _repo(), "--json", "labels"])
    if p.returncode != 0:
        raise IssuesError(f"cannot read the labels of #{n}: {p.stderr.strip()[:300]}", 2)
    try:
        return [str((x or {}).get("name") or "") for x in json.loads(p.stdout or "{}").get("labels") or []]
    except (ValueError, AttributeError):
        raise IssuesError(f"gh returned unparseable labels for #{n}", 2)


def _stale_status_labels(n: int, adding: list) -> list:
    """The status labels to remove when `adding` carries a status label (T-4412). Only labels
    actually on the issue are named. Unreadable labels -> nothing removed (the add still runs)."""
    if not any(_is_status_label(x) for x in adding):
        return []
    try:
        have = _current_labels(n)
    except IssuesError as e:
        print(f"WARN: {e}; previous status labels left in place", file=sys.stderr)
        return []
    return [h for h in have if _is_status_label(h) and h not in adding]


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

    labels = list(STAGE_LABELS[st])
    if st == "classified":  # T-4411: the triage labels ride on the Classified edit
        ex = getattr(a, "extra", None) or {}
        labels += _triage_labels(str(ex.get("area", "")), str(ex.get("severity", "")))
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
    edit = ["issue", "edit", str(a.issue), "--repo", _repo()]
    drop = _stale_status_labels(a.issue, labels)
    if drop:
        edit += ["--remove-label", ",".join(drop)]
    e = _gh(edit + ["--add-label", ",".join(labels)])
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

# T-4411: the area is a functional one taken from the component fabric through ONE committed
# mapping (policy/issue-areas.yaml), not the first directory prefix in the text.
AREA_MAP_FILE = Path(__file__).resolve().parent.parent / "policy" / "issue-areas.yaml"
_PATH_RE = re.compile(r"(?<![\w/.-])((?:lib|bin|agents|web|tests|docs|policy|tools)/[\w./-]*\w)")
_FW_CMD_RE = re.compile(r"\bfw\s+([a-z][a-z0-9-]+)")
_SEVERITY_RE = re.compile(r"\bseverity:\s*(low|medium|high)\b", re.I)
SEVERITIES = ("low", "medium", "high")


def _area_map() -> dict:
    try:
        d = yaml.safe_load(AREA_MAP_FILE.read_text()) or {}
    except (OSError, yaml.YAMLError) as e:
        raise IssuesError(f"cannot read the area mapping {AREA_MAP_FILE}: {e}", 2)
    return {"paths": d.get("paths") or [], "subsystems": d.get("subsystems") or {},
            "commands": d.get("commands") or {}, "weak": set(d.get("weak") or [])}


def _fabric_cards() -> dict:
    """location -> subsystem, plus name -> location, from .fabric/components (project root)."""
    by_loc, by_name = {}, {}
    d = _project_root() / ".fabric" / "components"
    for f in sorted(d.glob("*.yaml")) if d.is_dir() else []:
        try:
            c = yaml.safe_load(f.read_text(errors="replace")) or {}
        except yaml.YAMLError:
            continue
        loc, sub = str(c.get("location") or ""), str(c.get("subsystem") or "")
        if loc and sub:
            by_loc[loc] = sub
            name = str(c.get("name") or "")
            if len(name) >= 6 and re.search(r"[-_.]", name):  # generic one-word names are noise
                by_name[name] = loc
    return {"loc": by_loc, "name": by_name}


def _path_area(path: str, amap: dict, cards: dict) -> str:
    for rule in amap["paths"]:
        if fnmatchcase(path, str(rule.get("match", ""))):
            return str(rule.get("area", ""))
    return str(amap["subsystems"].get(cards["loc"].get(path, ""), ""))


def _resolve_area(paths: list, text: str = "") -> str:
    """Most-mentioned area over the given paths and the paths, `fw <cmd>` commands and component
    names in `text`; weak areas only when nothing else resolved; else 'unspecified'."""
    amap, cards = _area_map(), _fabric_cards()
    hits = [_path_area(p, amap, cards) for p in paths]
    for m in sorted([(m.start(), "p", m.group(1)) for m in _PATH_RE.finditer(text)]
                    + [(m.start(), "c", m.group(1)) for m in _FW_CMD_RE.finditer(text)]
                    + [(m.start(), "n", nm) for nm in cards["name"]
                       for m in re.finditer(r"(?<![\w/.-])" + re.escape(nm) + r"(?![\w-])", text)]):
        _, kind, val = m
        if kind == "p":
            hits.append(_path_area(val, amap, cards))
        elif kind == "n":
            hits.append(_path_area(cards["name"][val], amap, cards))
        elif val in amap["commands"]:
            hits.append(str(amap["commands"][val]))
        else:
            for cand in (f"lib/{val}.sh", f"lib/{val}.py", f"agents/{val}/{val}.sh"):
                if cand in cards["loc"]:
                    hits.append(_path_area(cand, amap, cards))
                    break
    hits = [h for h in hits if h]
    strong = [h for h in hits if h not in amap["weak"]] or hits
    if not strong:
        return "unspecified"
    return max(dict.fromkeys(strong), key=strong.count)  # first mention breaks a tie


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
    area = _resolve_area([], f"{title}\n{body}")
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
        if internal and needs_cls:
            # T-4342: our own issues (filed via fw upstream) are class internal: a ledger row, no
            # Received/Classified comment and no label. The operator reads them directly.
            missing = [st for st in ("received", "classified") if not _has(rows, n, st)]
            if is_new:
                counts["new"] += 1
            counts["classified"] += 1
            lines.append(f"INTERNAL #{n} from {author}: ledger only, nothing posted")
            if not a.dry_run:
                _append_row(ledger, {"issue": n, "stage": "+".join(missing), "class": "internal",
                                     "type": "internal", "body_hash": h, "title": title[:120],
                                     "author": author, "ts": _now()})
            continue
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
            lines.append(f"REPLY #{n} from {author}: recorded ({classify_reply(cm.get('body') or '', author, author)})")
            if not a.dry_run:
                _append_row(ledger, {"issue": n, "stage": "reply", "reply_id": rid, "author": author,
                                     "created": cm.get("createdAt") or "", "url": cm.get("url") or "",
                                     "excerpt": (cm.get("body") or "")[:500], "answered": False,
                                     "ts": _now()})
    try:  # T-4660: act on what the submitter said; an unreadable GitHub leaves it for the next run
        lines += _settle_replies({int(i["number"]) for i in issues}, a.dry_run)
    except IssuesError as e:
        print(f"WARN: submitter replies not processed: {e}", file=sys.stderr)
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


# ── submitter replies (T-4660) ───────────────────────────────────────────────
# sync records every submitter reply as a stage=reply row. This section reads them: a conservative
# classifier decides confirmed / not-fixed / other, `confirm-close` thanks the submitter and closes
# the issue on a confirmation, and everything else gets a needs-decision row that `fw issues replies`,
# `fw operator pending` and the session-start alerts list. Reply text is untrusted: it is classified
# with fixed patterns, and only its first sentence (flattened, marker-stripped) is ever quoted back.

_AFFIRM_RE = re.compile(
    r"\b(confirm(ed|s)?\s+(the\s+)?fix(ed)?|(verified|confirmed|checked)\s+fixed|fixed\s+for\s+me|"
    r"(it\s+)?works\s+(now|for\s+me)|(is|are)\s+(now\s+)?(fixed|working)|looks\s+fixed|can\s+confirm|"
    r"now\s+works|works\s+as\s+expected)\b", re.I)
# strong negatives count anywhere in the reply; weak counter-signals only in its first paragraph, so
# "the gate still bites" or "separate, still open" further down does not veto a confirmation.
_STRONG_NEG_RE = re.compile(
    r"\b(not\s+(yet\s+)?fixed|still\s+(broken|fails?|failing|happens|occurs|reproduces?|crash\w*)|"
    r"(doesn'?t|does\s+not|did\s+not|didn'?t)\s+(work|fix)|not\s+working|regress\w*|re-?open\w*|"
    r"is\s+broken|remains\s+broken|broken\s+again|fails|failing)\b", re.I)
_WEAK_NEG_RE = re.compile(r"\b(still|however|except|unfortunately)\b|\bbut\b[^.!?]*\bnot\b", re.I)
_CAVEAT_RE = re.compile(r"\b(only|have\s+not|haven'?t|did\s+not|didn'?t|not\s+(run|clicked|tested|tried))\b", re.I)
REPLY_CLASSES = ("confirmed", "not-fixed", "other")


def _sentences(text: str) -> list:
    flat = re.sub(r"\s+", " ", text or "").strip()
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+(?=[A-Z`(\"'])", flat) if s.strip()]


def classify_reply(text: str, author: str = "", issue_author: str = "") -> str:
    """confirmed | not-fixed | other. Pure. `confirmed` needs the issue author's own reply, an opening
    sentence that affirms the fix, and no counter-signal; anything doubtful is `other`."""
    text = text or ""
    if author and issue_author and author.lower() != issue_author.lower():
        return "other"
    first_para = re.split(r"\n\s*\n", text.strip(), maxsplit=1)[0] if text.strip() else ""
    if _STRONG_NEG_RE.search(text):
        return "not-fixed"
    sents = _sentences(text)
    if not sents or not _AFFIRM_RE.search(sents[0]):
        return "other"
    if _WEAK_NEG_RE.search(first_para):
        return "other"
    return "confirmed"


def _quote(text: str, limit: int = 220) -> str:
    s = (_sentences(text) or [""])[0]
    s = re.sub(r"<!--.*?-->", "", s)
    s = s.replace("`", "'").replace("\r", " ")
    return (s[:limit] + "…") if len(s) > limit else s


def _caveats(text: str) -> list:
    """Sentences after the first that say what the submitter did not or only partly checked."""
    return [_quote(s) for s in _sentences(text)[1:] if _CAVEAT_RE.search(s)][:2]


_SETTLED_STAGES = ("closed", "closed-released", "closed-fixed", "closed-duplicate", "reply-settled")


def _ledger_stage(rows: list, n: int) -> str:
    last = ""
    for r in rows:
        if r.get("issue") != n:
            continue
        toks = [t for t in str(r.get("stage", "")).split("+") if t in STAGES]
        if toks:
            last = toks[-1]
    return last


def _undecided_replies(include_all: bool = False) -> list:
    """Submitter reply rows that nobody acted on. A reply is settled once a closed row names it, its
    issue is closed in the ledger, or sync found the issue closed; needs-decision rows stay listed."""
    rows = _read_rows(_issues_dir() / "intake.jsonl")
    closed_issues = {r.get("issue") for r in rows if r.get("stage") in _SETTLED_STAGES}
    closed_replies = {str(r.get("reply_id")) for r in rows if r.get("reply_id") and r.get("stage") == "closed"}
    decisions = {str(r.get("reply_id")): r for r in rows if r.get("stage") == "needs-decision"}
    out = []
    for r in rows:
        if r.get("stage") != "reply":
            continue
        n, rid = r.get("issue"), str(r.get("reply_id") or "")
        settled = rid in closed_replies or n in closed_issues
        if settled and not include_all:
            continue
        cls = classify_reply(r.get("excerpt") or "", r.get("author") or "", r.get("author") or "")
        out.append({"issue": n, "stage": _ledger_stage(rows, n), "class": cls, "reply_id": rid,
                    "created": r.get("created") or "", "author": r.get("author") or "",
                    "excerpt": re.sub(r"\s+", " ", r.get("excerpt") or "").strip()[:160],
                    "settled": settled, "needs_decision": rid in decisions})
    return sorted(out, key=lambda x: (x["issue"], x["created"]))


def cmd_replies(a) -> int:
    items = _undecided_replies(a.all)
    if a.json:
        print(json.dumps(items, indent=2, ensure_ascii=False))
        return 0
    if not items:
        print("replies: none waiting for a decision")
        return 0
    for i in items:
        print(f"#{i['issue']} [{i['stage'] or '-'}] {i['class']}{' (settled)' if i['settled'] else ''} "
              f"{i['reply_id']} {i['created']}  {i['excerpt']}")
    print(f"replies: {len(items)} — confirm with `fw issues confirm-close <N> --reply-id <ID>`")
    return 0


def _confirm_body(date: str, quote: str, reply_url: str, caveats: list, tasks: list, fixed: dict) -> str:
    out = ["<!-- aef-intake:stage=closed -->", f"**[AEF intake] Closed: confirmed fixed** — {date}", "",
           "Thank you for testing the fix and for taking the time to confirm it. You wrote:", "",
           f"> {quote}", ""]
    if reply_url:
        out += [f"([your reply]({reply_url}))", ""]
    if caveats:
        out += ["You also noted what you did not check, and that is kept on record: "
                + " ".join(f"“{c}”" for c in caveats), ""]
    where = []
    if tasks:
        where.append("tracked in " + ", ".join(f"**{t}**" for t in tasks))
    if fixed.get("release"):
        where.append(f"released in **{fixed['release']}**")
    if fixed.get("commit"):
        where.append(f"commit {fixed['commit']}")
    out += [("The fix is " + ", ".join(where) + ". ") if where else "",
            "Closing this issue as completed; it can be reopened if the problem comes back.", "", FOOTER]
    return "\n".join(out) + "\n"


def _fix_facts(rows: list, n: int) -> dict | None:
    """Tasks, release and commit from the issue's fixed-on-bleeding-edge / released ledger rows."""
    tasks, release, commit, found = [], "", "", False
    for r in rows:
        if r.get("issue") != n:
            continue
        toks = str(r.get("stage", "")).split("+")
        if "fixed-on-bleeding-edge" in toks or "released" in toks:
            found = True
            tasks += [t for t in (r.get("tasks") or []) if t not in tasks]
            release = r.get("version") or release
            commit = r.get("commit") or commit
    return {"tasks": tasks, "release": release, "commit": commit} if found else None


def confirm_close(n: int, reply_id: str, dry_run: bool = False) -> str:
    """Thank the submitter and close #n on their confirmation. Returns closed | already | would-close.
    Raises IssuesError when any precondition fails. The comment is logged (closed-note) before the
    close, and the closed row is written only after GitHub accepted the close."""
    ledger = _issues_dir() / "intake.jsonl"
    rows = _read_rows(ledger)
    if _ledger_has(n, "closed"):
        return "already"
    reply = next((r for r in rows if r.get("issue") == n and r.get("stage") == "reply"
                  and str(r.get("reply_id")) == reply_id), None)
    if reply is None:
        raise IssuesError(f"no reply {reply_id!r} for #{n} in the ledger", 2)
    fixed = _fix_facts(rows, n)
    if fixed is None:
        raise IssuesError(f"#{n} has no fixed-on-bleeding-edge or released stage in the ledger: "
                          f"nothing says the fix exists yet", 2)
    info = _issue_view(n)
    if str(info.get("state", "")).upper() != "OPEN":
        raise IssuesError(f"#{n} is not open", 2)
    issue_author = _login(info.get("author"))
    if not issue_author or (reply.get("author") or "").lower() != issue_author.lower():
        raise IssuesError(f"reply {reply_id} is by {reply.get('author') or '?'}, not the issue author "
                          f"{issue_author or '?'}", 2)
    live = next((c for c in info.get("comments") or [] if str(c.get("id")) == reply_id), None)
    if live is not None and _login(live.get("author")).lower() != issue_author.lower():
        raise IssuesError(f"reply {reply_id} on GitHub is not by the issue author", 2)
    text = (live or {}).get("body") or reply.get("excerpt") or ""
    if classify_reply(text, issue_author, issue_author) != "confirmed":
        raise IssuesError(f"reply {reply_id} does not classify as confirmed; decide it by hand", 2)
    body = _confirm_body(_now()[:10], _quote(text), (live or {}).get("url") or reply.get("url") or "",
                         _caveats(text), fixed["tasks"], fixed)
    if dry_run:
        print(body, end="")
        return "would-close"
    note = _ledger_has(n, "closed-note")
    if note is None and not _marked_on_issue(n, "closed"):
        p = _gh(["issue", "comment", str(n), "--repo", _repo(), "--body-file", "-"], stdin=body)
        url = next((w for w in p.stdout.split() if w.startswith("https://")), "") if p.returncode == 0 else ""
        if not url:
            raise IssuesError(f"GitHub did not return a comment URL for #{n}: "
                              f"{(p.stderr or p.stdout).strip()[:300]}", 3)
        note = {"issue": n, "stage": "closed-note", "reply_id": reply_id, "comment": url,
                "by": "confirm-close", "ts": _now()}
        _append_row(ledger, note)
    q = _gh(["issue", "close", str(n), "--repo", _repo(), "--reason", "completed"])
    if q.returncode != 0:
        raise IssuesError(f"#{n} is commented but closing failed: {q.stderr.strip()[:300]}. "
                          f"Re-run to retry the close only.", 3)
    row = {"issue": n, "stage": "closed", "reply_id": reply_id, "by": "confirm-close",
           "comment": (note or {}).get("comment", ""), "ts": _now()}
    if fixed["tasks"]:
        row["tasks"] = fixed["tasks"]
    _append_row(ledger, row)
    return "closed"


def cmd_confirm_close(a) -> int:
    out = confirm_close(a.issue, a.reply_id, a.dry_run)
    if out == "already":
        print(f"#{a.issue} already closed by confirm-close — nothing to do")
    elif out == "closed":
        print(f"closed #{a.issue} on the submitter's confirmation (reply {a.reply_id})")
    return 0


def _settle_replies(open_numbers: set, dry_run: bool) -> list:
    """Sync leg: close confirmed replies on eligible issues, mark the rest needs-decision, and settle
    replies whose issue is no longer open. A gh failure leaves the ledger as it was for the next run."""
    ledger = _issues_dir() / "intake.jsonl"
    lines = []
    for it in _undecided_replies():
        n, rid = it["issue"], it["reply_id"]
        if n not in open_numbers:
            if not dry_run:
                _append_row(ledger, {"issue": n, "stage": "reply-settled", "reply_id": rid,
                                     "note": "issue no longer open", "ts": _now()})
            continue
        if it["class"] == "confirmed":
            try:
                out = confirm_close(n, rid, dry_run=True) if dry_run else confirm_close(n, rid)
                lines.append(f"CONFIRMED #{n}: {'would close' if dry_run else 'closed'} on the "
                             f"submitter's reply ({out})")
                continue
            except IssuesError as e:
                if e.code == 3:
                    lines.append(f"WARN #{n}: confirm-close not completed ({e}); retried next sync")
                    continue
                reason = f"confirmed but not closed: {e}"
        else:
            reason = it["class"]
        if not it["needs_decision"]:
            lines.append(f"DECIDE #{n}: reply {rid} is {reason} — see `fw issues replies`")
            if not dry_run:
                _append_row(ledger, {"issue": n, "stage": "needs-decision", "reply_id": rid,
                                     "class": it["class"], "reason": str(reason)[:200], "ts": _now()})
    return lines


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
            "tests": _verification_tests(text),
            "name": _frontmatter_name(fm)}


def _frontmatter_name(fm: str) -> str:
    """The task's `name:` (a quoted scalar that may wrap onto continuation lines)."""
    try:
        name = (yaml.safe_load(fm) or {}).get("name")
    except (yaml.YAMLError, AttributeError):
        return ""
    return str(name or "")


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


_LOCAL_HOST_RE = re.compile(
    r"\b[\w-]+(?:\.[\w-]+)*\.(?:local|lan|internal|localdomain|corp)\b"  # local-only names
    r"|\b(?:\d{1,3}\.){3}\d{1,3}\b"                                     # IPv4
    r"|\b(?:[0-9a-fA-F]{1,4}:){3,7}:?[0-9a-fA-F]{0,4}\b")               # IPv6 (3+ colons: not a clock time)


def _scrub(text: str) -> str:
    """No hostname or IP address in posted text (T-4346). The field report and task names are free
    text and the release comment goes to a public issue, so local names, addresses and this machine's
    own hostname are replaced before posting. Names the scrub cannot recognise are not caught."""
    text = _LOCAL_HOST_RE.sub("[host]", text)
    for h in {socket.gethostname(), socket.getfqdn()} - {"", "localhost"}:
        text = re.sub(r"(?<![\w.-])" + re.escape(h) + r"(?![\w-])", "[host]", text, flags=re.I)
    return text


def _summary(name: str) -> str:
    """One plain-words line from the task name: the parenthetical (GitHub #86, the submitter) is dropped."""
    s = re.sub(r"\s+", " ", re.sub(r"\([^()]*\)", "", name or "")).strip(" .;,:")
    if len(s) > 220:
        return s[:220].rsplit(" ", 1)[0] + "…"
    return (s[:1].upper() + s[1:] + ".") if s else ""


def _comparison_report(root: Path, version: str) -> str:
    """File name of the release's full-suite comparison: a docs/reports file whose first lines name
    both this version and a full-suite comparison (T-4246 for v1.8.11). Empty when none does."""
    for p in sorted((root / "docs" / "reports").glob("*.md")):
        head = "\n".join(p.read_text(errors="replace").splitlines()[:6]).lower()
        if "full-suite" in head and re.search(re.escape(version.lower()) + r"(?![\w]|\.\d)", head):
            return p.name
    return ""


def _release_decision(root: Path, version: str) -> dict | None:
    """The last row for this version in .context/releases/decisions.jsonl (bin/fw release decide)."""
    found = None
    for r in _read_rows(root / ".context" / "releases" / "decisions.jsonl"):
        if r.get("version") == version:
            found = r
    return found


def _why_line(version: str, decision: dict | None, all_positive: bool) -> str:
    """Why it was released: the T-4146 field-test rule when every fix has a positive field test and
    the recorded decision says so, else the operator's recorded decision, else an honest no-record."""
    by = (decision or {}).get("decided_by")
    if by == "field-evidence" and all_positive:
        return (f"**Why it was released:** the T-4146 rule: every fix in {version} has a positive field "
                f"test from another agent, and the release gates are green.")
    if by == "operator":
        when = str((decision or {}).get("ts") or "")[:10]
        return (f"**Why it was released:** the operator's release decision for {version}"
                + (f" ({when})" if when else "") + ", with the release gates green.")
    return (f"**Why it was released:** {version} passed the release gates; no release decision is "
            f"recorded for it in .context/releases/decisions.jsonl.")


def _evidence_block(version: str, g: dict, root: Path) -> str:
    repo = _repo()
    tag = f"https://github.com/{repo}/blob/{version}"
    report = root / "docs" / "reports" / f"field-test-{version}-results.md"
    comparison = _comparison_report(root, version)
    tests = g["tests"]
    tested = ", ".join(f"`{t}`" for t in tests) if tests else \
        "see the task's Verification block (no test file is named there)."
    if comparison:
        tested += "; the release's full-suite comparison is linked below"
    summary = " ".join(s for s in g.get("summaries", []) if s)
    lines = [f"**What was fixed:** {summary}"] if summary else []
    lines.append("**How it was tested:** " + tested)
    if g["evidence"]:
        lines.append("**Field evidence:**")
        lines += [f"- {e}" for e in g["evidence"][:6]]
    else:
        lines.append("**Field evidence:** none recorded for this fix.")
    all_positive = all(v == "works" for v in g["verdicts"])
    lines.append(_why_line(version, _release_decision(root, version), all_positive))
    links = [f"release notes https://github.com/{repo}/releases/tag/{version}"]
    if report.exists():
        links.append(f"field-evidence report {tag}/docs/reports/field-test-{version}-results.md")
    if comparison:
        links.append(f"full-suite comparison {tag}/docs/reports/{comparison}")
    lines.append("**Links:** " + " · ".join(links))
    return _scrub("\n".join(lines))


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
            print(f"keep   #{n}: the submitter replied after the Released comment; see `fw issues replies`")
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
                                           "summaries": [], "held": None})
        f = field.get(tid, {"verdict": None, "evidence": []})
        g["tasks"].append(tid)
        g["summaries"].append(_summary(t["name"]))
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


# ── task lifecycle leg (T-4341, lifecycle stages 6-7) ────────────────────────
# update-task.sh calls `lifecycle` after a transition: started-work posts in-progress, work-completed
# (partial-complete included: the fix is on bleeding-edge even while Human ACs await review) posts
# fixed-on-bleeding-edge. Both go through cmd_comment, so the mirror check and idempotence apply. A
# GitHub failure never fails the transition: it is recorded in lifecycle-pending.jsonl and this verb
# exits 0. FW_ISSUES_LIFECYCLE=0 disables it.

LIFECYCLE_STAGES = {"started": "in-progress", "closed": "fixed-on-bleeding-edge"}
_TEST_RUNNER_RE = re.compile(r"\b(bats|pytest|python3?\s+-m\s+pytest|bash\s+tests/\S+)\b")
LIFECYCLE_FALLBACK_TEST = "bin/fw doctor"


def _first_test_command(text: str) -> str:
    m = re.search(r"^## Verification\s*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    for line in (m.group(1).splitlines() if m else []):
        line = line.strip()
        if line and not line.startswith("#") and _TEST_RUNNER_RE.search(line) and "`" not in line:
            return line
    return LIFECYCLE_FALLBACK_TEST


def _task_last_commit(root: Path, tid: str) -> str:
    p = _run(["git", "-C", str(root), "log", "-1", "--format=%H", "-E", f"--grep=^{tid}([^0-9]|$)"])
    return p.stdout.strip() if p.returncode == 0 else ""


# ── area/severity labels (T-4411) ────────────────────────────────────────────
# On a linked task's close (and via `fw issues labels` for backfill) the area is recomputed from
# the files the task changed: its `components:` when resolved, else the files of its commits —
# lifecycle runs before update-task.sh fills components:, from the same commits. Labels only:
# nothing is posted. The old area:* label is removed in the same edit that adds the new one.

def _task_paths(root: Path, tid: str) -> list:
    hits = sorted(root.glob(f".tasks/*/{tid}-*.md"))
    if hits:
        text = hits[0].read_text(errors="replace")
        fm = text.split("---", 2)[1] if text.startswith("---") and text.count("---") >= 2 else ""
        try:
            comps = (yaml.safe_load(fm) or {}).get("components") or []
        except (yaml.YAMLError, AttributeError):
            comps = []
        if isinstance(comps, list) and comps:
            return [str(c) for c in comps]
    p = _run(["git", "-C", str(root), "log", "--format=", "--name-only", "-E",
              f"--grep=^{tid}([^0-9]|$)"])
    out = p.stdout.splitlines() if p.returncode == 0 else []
    return [x for x in dict.fromkeys(out) if x and not x.startswith(".")]


def _refine_labels(n: int, tasks: list, root: Path, dry_run: bool) -> str:
    p = _gh(["issue", "view", str(n), "--repo", _repo(), "--json", "title,body,labels,comments"])
    if p.returncode != 0:
        raise IssuesError(f"cannot read issue #{n}: {p.stderr.strip()[:300]}", 2)
    try:
        info = json.loads(p.stdout or "{}")
    except ValueError:
        raise IssuesError(f"gh returned unparseable JSON for issue #{n}", 2)
    have = [str((x or {}).get("name") or "") for x in info.get("labels") or []]
    me = _maintainer_login()
    cls_text = "\n".join(c.get("body") or "" for c in info.get("comments") or []
                         if _login(c.get("author")) == me and any(
                             "classified" in m.group(1).split("+") for m in MARKER_RE.finditer(c.get("body") or "")))
    paths = [x for t in tasks for x in _task_paths(root, t)]
    area = _resolve_area(paths) if paths else "unspecified"
    if area == "unspecified":
        area = _resolve_area([], f"{cls_text}\n{info.get('title') or ''}\n{info.get('body') or ''}")
    m = _SEVERITY_RE.search(cls_text)
    sev = m.group(1).lower() if m else next(
        (str(r["severity"]) for r in reversed(_read_rows(_issues_dir() / "intake.jsonl"))
         if r.get("issue") == n and r.get("severity") in SEVERITIES),
        next((h[9:] for h in have if h.startswith("severity:")), ""))
    want = _triage_labels(area, sev)
    add = [x for x in want if x not in have]
    drop = [h for h in have if (h.startswith("area:") and any(w.startswith("area:") for w in add))
            or (h.startswith("severity:") and any(w.startswith("severity:") for w in add))]
    if not add:
        return f"#{n}: labels unchanged ({', '.join(want) or 'nothing resolved'})"
    what = f"#{n}: +{','.join(add)}" + (f" -{','.join(drop)}" if drop else "")
    if dry_run:
        return what + " (dry-run: nothing changed)"
    _ensure_labels(add)
    args = ["issue", "edit", str(n), "--repo", _repo()]
    if drop:
        args += ["--remove-label", ",".join(drop)]
    e = _gh(args + ["--add-label", ",".join(add)])
    if e.returncode != 0:
        raise IssuesError(f"cannot edit labels on #{n}: {e.stderr.strip()[:300]}", 2)
    return what


def cmd_labels(a) -> int:
    root = Path(a.root or os.environ.get("PROJECT_ROOT") or os.getcwd())
    tasks = a.task or list(dict.fromkeys(
        t for r in _read_rows(_issues_dir() / "intake.jsonl") if r.get("issue") == a.issue
        for t in r.get("tasks") or []))
    for t in tasks:
        if not _TASK_RE.match(t):
            raise IssuesError(f"--task must be T-NNN, got {t!r}")
    print(_refine_labels(a.issue, tasks, root, a.dry_run))
    return 0


def cmd_status_labels(a) -> int:
    """T-4412: set the one status label from the issue's latest ledger stage. Labels only."""
    want = ""
    for r in _read_rows(_issues_dir() / "intake.jsonl"):
        if r.get("issue") != a.issue:
            continue
        for tok in str(r.get("stage", "")).split("+"):
            want = next((x for x in STAGE_LABELS.get(tok, []) if _is_status_label(x)), want)
    if not want:
        raise IssuesError(f"#{a.issue}: no ledger stage with a status label")
    have = _current_labels(a.issue)
    drop = [h for h in have if _is_status_label(h) and h != want]
    add = [] if want in have else [want]
    if not drop and not add:
        print(f"#{a.issue}: status label unchanged ({want})")
        return 0
    what = f"#{a.issue}: {want}" + (f" (remove {','.join(drop)})" if drop else "")
    if a.dry_run:
        print(what + " (dry-run: nothing changed)")
        return 0
    edit = ["issue", "edit", str(a.issue), "--repo", _repo()]
    if drop:
        edit += ["--remove-label", ",".join(drop)]
    if add:
        _ensure_labels(add)
        edit += ["--add-label", ",".join(add)]
    e = _gh(edit)
    if e.returncode != 0:
        raise IssuesError(f"cannot edit labels on #{a.issue}: {e.stderr.strip()[:300]}", 2)
    print(what)
    return 0


def cmd_lifecycle(a) -> int:
    if os.environ.get("FW_ISSUES_LIFECYCLE", "1") == "0":
        return 0
    root = Path(a.root or os.environ.get("PROJECT_ROOT") or os.getcwd())
    stage = LIFECYCLE_STAGES[a.event]
    facts = _task_facts(root, a.task_id)
    if not facts or not facts["issue"]:
        return 0
    n = facts["issue"]
    if a.event == "closed":  # T-4411: refine the area label from what the task changed
        try:
            print(_refine_labels(n, [a.task_id], root, False))
        except (IssuesError, OSError) as e:
            print(f"WARN: GitHub #{n} area label not refined ({str(e)[:160]}); re-run "
                  f"`fw issues labels {n} --task {a.task_id}`", file=sys.stderr)
    try:
        if _ledger_has(n, stage):
            return 0
        ns = argparse.Namespace(issue=n, stage=stage, task=[a.task_id], commit=None, test_cmd=None,
                                version=None, text=None, approved_by_operator=None, dry_run=False)
        if stage == "fixed-on-bleeding-edge":
            ns.commit = _task_last_commit(root, a.task_id)
            if not ns.commit:
                raise IssuesError(f"no commit referencing {a.task_id} found")
            text = sorted(root.glob(f".tasks/*/{a.task_id}-*.md"))[0].read_text(errors="replace")
            ns.test_cmd = _first_test_command(text)
        rc = cmd_comment(ns)
        if rc:
            raise IssuesError(f"cmd_comment returned {rc}")
    except (IssuesError, OSError) as e:
        try:
            _append_row(_issues_dir() / "lifecycle-pending.jsonl",
                        {"issue": n, "stage": stage, "task": a.task_id, "error": str(e)[:300], "ts": _now()})
        except OSError:
            pass
        print(f"WARN: GitHub #{n} {stage} not posted ({str(e)[:160]}); recorded in lifecycle-pending.jsonl, "
              f"re-run `fw issues lifecycle {a.task_id} --event {a.event}` to retry", file=sys.stderr)
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
    lc = sub.add_parser("lifecycle", help="post in-progress / fixed-on-bleeding-edge for a task's linked issue (T-4341)")
    lc.add_argument("task_id")
    lc.add_argument("--event", required=True, choices=sorted(LIFECYCLE_STAGES))
    lc.add_argument("--root", help="project root (default PROJECT_ROOT or cwd)")
    lc.set_defaults(fn=cmd_lifecycle)
    lb = sub.add_parser("labels", help="set area:/severity: labels from the fabric; labels only, no comment (T-4411)")
    lb.add_argument("issue", type=int)
    lb.add_argument("--task", action="append", help="linked task (default: the ledger's tasks for the issue)")
    lb.add_argument("--root", help="project root (default PROJECT_ROOT or cwd)")
    lb.add_argument("--dry-run", action="store_true", help="print the label change, change nothing")
    lb.set_defaults(fn=cmd_labels)
    sl = sub.add_parser("status-labels", help="set the one status:* label from the latest ledger stage; labels only (T-4412)")
    sl.add_argument("issue", type=int)
    sl.add_argument("--dry-run", action="store_true", help="print the label change, change nothing")
    sl.set_defaults(fn=cmd_status_labels)
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
    rp = sub.add_parser("replies", help="list submitter replies nobody has acted on (T-4660)")
    rp.add_argument("--json", action="store_true")
    rp.add_argument("--all", action="store_true", help="include settled replies")
    rp.set_defaults(fn=cmd_replies)
    cc = sub.add_parser("confirm-close", help="thank the submitter and close an issue on their confirming reply (T-4660)")
    cc.add_argument("issue", type=int)
    cc.add_argument("--reply-id", required=True)
    cc.add_argument("--dry-run", action="store_true", help="print the comment, post and close nothing")
    cc.set_defaults(fn=cmd_confirm_close)
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
