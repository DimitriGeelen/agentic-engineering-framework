#!/usr/bin/env python3
"""Dispatch an independent reviewer on REVIEWER-JUDGES criteria (T-3580, T-3557 slice 3).

fw reviewer judge T-XXX [--criterion N] [--dry-run] [--json]

WHO WRITES WHAT (T-3581). The parent that runs `judge` NEVER writes a verdict. It builds a
brief, dispatches a review worker (`fw termlink dispatch --task-type review`, which registers
the dispatch with the ledger), and reads the ledger afterwards. The WORKER computes the
criterion digest, runs `fw reviewer verdict record --dispatch-id <its id>` and commits its own
row under its own identity. The reviewer's printed text is parsed for REPORTING only; the
authoritative record is the ledger row. A missing or malformed row is `unknown`, never green.

Hard human classes (tier0-or-bypass, act-in-the-world, sovereignty-field) are never dispatched;
they are reported as operator-only.

Rung follows IW-7 (docs/reports/T-3557-agent-reviewer-default.md): impact = max(cost_if_wrong,
value_at_stake) picks rung 1 (same-vendor independent agent) or 5 (panel of 3). A weekly spend
ceiling (config REVIEWER_JUDGE_WEEKLY_SPEND_CEILING) drops the rung one step, and the brief and
the result say so.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Callable

_HERE = Path(__file__).resolve().parent.parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import (  # noqa: E402
    OPERATOR_ONLY,
    REVIEWER_JUDGES,
    human_criteria,
)

SPEND_LOG = Path(".context/working/judge-spend.jsonl")
EVIDENCE_DIR = Path(".context/working/judge-evidence")
REPORT_DIR = ".context/reviews/evidence"
CEILING_KEY = "REVIEWER_JUDGE_WEEKLY_SPEND_CEILING"
DEFAULT_CEILING = 10000.0
#: Estimated USD per dispatched reviewer, by rung. A panel is three seats.
RUNG_COST = {1: 2.0, 2: 2.0, 5: 6.0}
PANEL_SEATS = ("claude", "codex", "opencode")
UNKNOWN = "unknown"


def _root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_task(task_id: str, root: Path) -> dict | None:
    """Load an active task file; return frontmatter + body + text or None."""
    matches = sorted(root.glob(f".tasks/active/{task_id}-*.md"))
    if not matches:
        return None
    path = matches[0]
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---"):
        return None
    lines = text.split("\n")
    end_idx = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if end_idx is None:
        return None
    try:
        import yaml

        fm = yaml.safe_load("\n".join(lines[1:end_idx]))
        return {"frontmatter": fm or {}, "body": "\n".join(lines[end_idx + 1:]),
                "path": path, "text": text}
    except Exception as e:
        print(f"Error parsing task {task_id}: {e}", file=sys.stderr)
        return None


def _partition(task_data: dict, root: Path, task_id: str,
               criterion_n: int | None = None) -> tuple[list[dict], list[dict]]:
    """Split the open Human criteria into (judged, operator_only).

    Classification is the ledger's own (`_Ctx.classify`), so a criterion `judge` dispatches is
    one `record` will accept and one it would refuse is never dispatched. `ac_index` is the
    Human criterion number that `verdict record --ac` takes.
    """
    ctx = vl._Ctx(root, task_id, task_data["path"], task_data["text"])
    judged: list[dict] = []
    operator: list[dict] = []
    for crit in human_criteria(task_data["text"]):
        if crit.ticked or (criterion_n is not None and crit.index != criterion_n):
            continue
        cl = ctx.classify(crit)
        item = {"index": len(judged) + 1, "ac_index": crit.index, "text": crit.title.strip(),
                "body": vl.criterion_body(crit), "class": cl.cls,
                "render": cl.cls == "render-surface" and bool(vl._RENDER_REVIEW_RE.search(vl.criterion_body(crit)))}
        if cl.delegation_class == REVIEWER_JUDGES:
            judged.append(item)
        elif cl.delegation_class == OPERATOR_ONLY:
            item["reason"] = cl.reason
            operator.append(item)
    return judged, operator


def _select_criteria(task_data: dict, criterion_n: int | None = None,
                     root: Path | None = None) -> list[dict]:
    root = root or _root()
    return _partition(task_data, root, task_data["frontmatter"].get("id", ""), criterion_n)[0]


# ── rung (IW-7) ──────────────────────────────────────────────────────────────

def _calculate_rung(task_data: dict) -> tuple[int, str]:
    """impact = max(cost_if_wrong, value_at_stake) -> rung 1 (low) or 5 (high). Returns (rung, reason)."""
    fm = task_data["frontmatter"]
    ce = fm.get("cost_estimate") or {}
    blast = ce.get("blast_radius")
    bvp = fm.get("bvp_scores") or {}
    voi = fm.get("voi_score")
    why = []
    if isinstance(blast, (int, float)) and blast > 5:
        why.append(f"blast_radius={blast}")
    if isinstance(voi, (int, float)) and voi >= 0.6:
        why.append(f"voi_score={voi}")
    if bvp and (bvp.get("D1", 0) > 3 or bvp.get("D2", 0) > 3):
        why.append("D1/D2 > 3")
    return (5, "; ".join(why)) if why else (1, "default")


def _config_value(root: Path, key: str, default: str) -> str:
    env = os.environ.get(f"FW_{key}")
    if env:
        return env
    try:
        import yaml

        data = yaml.safe_load((root / ".framework.yaml").read_text()) or {}
        for scope in (data, data.get("config") or {}):
            if isinstance(scope, dict) and scope.get(key) not in (None, ""):
                return str(scope[key])
    except Exception:
        pass
    return default


def _ceiling(root: Path) -> float:
    try:
        return float(_config_value(root, CEILING_KEY, str(DEFAULT_CEILING)))
    except ValueError:
        return DEFAULT_CEILING


def _weekly_spend(root: Path, now: datetime | None = None) -> float:
    now = now or datetime.now(timezone.utc)
    since = now - timedelta(days=7)
    total = 0.0
    p = root / SPEND_LOG
    if not p.exists():
        return 0.0
    for line in p.read_text().splitlines():
        try:
            r = json.loads(line)
            ts = datetime.strptime(r["ts"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            if ts >= since:
                total += float(r.get("cost", 0))
        except Exception:
            continue
    return total


def _apply_ceiling(rung: int, reason: str, spent: float, ceiling: float) -> tuple[int, str, str]:
    """Drop one rung when the due rung would take the week past the ceiling. Returns
    (rung, reason, note); note is '' when nothing was dropped."""
    if spent + RUNG_COST.get(rung, 2.0) <= ceiling:
        return rung, reason, ""
    lower = 2 if rung >= 5 else 1
    if lower == rung:
        note = (f"weekly spend ceiling reached (spent {spent:g} of {ceiling:g}); rung {rung} is "
                f"already the lowest, so it runs at rung {rung} and is not skipped")
    else:
        note = (f"reviewed at rung {lower}, weekly spend ceiling reached (spent {spent:g} of "
                f"{ceiling:g}); rung {rung} was due")
    return lower, reason, note


def _rung_label(rung: int, seat: str = "") -> str:
    base = "rung-1-same-vendor-independent" if rung <= 2 else "rung-5-panel"
    if rung == 2:
        base = "rung-2-same-vendor-independent"
    return f"{base}:{seat}" if seat else base


# ── evidence: screenshots of the pages the task touched ──────────────────────

_ROUTE_RE = re.compile(r"""@\w+\.route\(\s*["'](/[^"'<>]*)["']""")
_URL_TOKEN_RE = re.compile(r"`(/[a-z][\w/.-]*)`")


def _changed_web_files(root: Path, task_id: str, text: str) -> list[str]:
    files = set(re.findall(r"\b(web/(?:templates|blueprints|static)/[\w./-]+|web/(?:shared|app)\.py)", text))
    try:
        out = subprocess.run(["git", "log", "--all", f"--grep={task_id}[^0-9]", "--name-only",
                              "--pretty=format:"], cwd=root, capture_output=True, text=True,
                             timeout=30).stdout
        files |= {f for f in out.split() if f.startswith("web/")}
    except Exception:
        pass
    return sorted(files)


def _pages_for(root: Path, task_id: str, task_text: str, criteria: list[dict]) -> list[str]:
    """URL paths to screenshot: `/paths` quoted in the criteria, plus the routes of the
    changed blueprints and of the blueprints rendering the changed templates."""
    pages: list[str] = []
    for c in criteria:
        pages += _URL_TOKEN_RE.findall(c["body"])
    changed = _changed_web_files(root, task_id, task_text)
    bp_dir = root / "web" / "blueprints"
    if bp_dir.is_dir():
        for bp in sorted(bp_dir.glob("*.py")):
            rel = f"web/blueprints/{bp.name}"
            src = bp.read_text(errors="replace")
            hit = rel in changed or any(
                Path(f).name in src for f in changed if f.startswith("web/templates/"))
            if hit:
                pages += [r for r in _ROUTE_RE.findall(src) if "<" not in r]
    seen, out = set(), []
    for p in pages:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out[:6]


def _watchtower_url(root: Path) -> str:
    f = root / ".context/working/watchtower.url"
    return f.read_text().strip() if f.exists() else ""


def _capture_playwright(base_url: str, pages: list[str], outdir: Path) -> tuple[list[Path], str]:
    """Real capturer. Returns (paths, error); error != '' means nothing usable was captured."""
    if not base_url:
        return [], "no running Watchtower (.context/working/watchtower.url missing)"
    if not pages:
        return [], "no page could be derived from the task or criterion text"
    try:
        from playwright.sync_api import sync_playwright
    except Exception as e:  # noqa: BLE001
        return [], f"playwright unavailable: {e}"
    outdir.mkdir(parents=True, exist_ok=True)
    shots: list[Path] = []
    errs: list[str] = []
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch()
            page = browser.new_page(viewport={"width": 1280, "height": 900})
            for i, p in enumerate(pages):
                try:
                    resp = page.goto(base_url.rstrip("/") + p, timeout=30000)
                    if resp is None or resp.status >= 400:
                        errs.append(f"{p}: HTTP {getattr(resp, 'status', '?')}")
                        continue
                    f = outdir / f"{i + 1:02d}-{re.sub(r'[^a-z0-9]+', '-', p.lower()).strip('-') or 'root'}.png"
                    page.screenshot(path=str(f), full_page=True)
                    shots.append(f)
                except Exception as e:  # noqa: BLE001
                    errs.append(f"{p}: {e}")
            browser.close()
    except Exception as e:  # noqa: BLE001
        return shots, f"browser failure: {e}"
    if not shots:
        return [], "; ".join(errs) or "no screenshot captured"
    return shots, ("partial: " + "; ".join(errs)) if errs else ""


Capturer = Callable[[str, list[str], Path], "tuple[list[Path], str]"]


def _gather_evidence(root: Path, task_id: str, task_data: dict, criteria: list[dict],
                     capture: Capturer, *, dry_run: bool) -> dict:
    """{'pages': [...], 'shots': [rel paths], 'error': str, 'needed': bool}."""
    needed = any(c["render"] for c in criteria)
    ev = {"needed": needed, "pages": [], "shots": [], "error": ""}
    if not needed:
        return ev
    ev["pages"] = _pages_for(root, task_id, task_data["text"], [c for c in criteria if c["render"]])
    if dry_run:
        return ev
    try:
        shots, err = capture(_watchtower_url(root), ev["pages"], root / EVIDENCE_DIR / task_id)
    except Exception as e:  # noqa: BLE001
        shots, err = [], f"capture crashed: {e}"
    ev["shots"] = [str(Path(s).resolve().relative_to(root.resolve())) for s in shots if Path(s).exists()]
    ev["error"] = err if (err and (not ev["shots"] or not err.startswith("partial"))) else ""
    if not ev["shots"] and not ev["error"]:
        ev["error"] = "no screenshot captured"
    return ev


# ── the brief ────────────────────────────────────────────────────────────────

def _build_brief(task_id: str, criteria: list[dict], *, rung: int = 1, rung_reason: str = "",
                 ceiling_note: str = "", evidence: dict | None = None, seat: str = "",
                 operator_only: list[dict] | None = None) -> str:
    ev = evidence or {"needed": False, "shots": [], "error": "", "pages": []}
    lines = [
        "You are an INDEPENDENT REVIEWER for the Agentic Engineering Framework.",
        "You did not produce any of the work below and owe its authors nothing.",
        "You are read-only EXCEPT for your own evidence report and your verdict rows.",
        "",
        "## Your role",
        "",
        "The operator has ruled that a human is needed only for RISK:",
        "- Tier 0 / consequential actions;",
        "- irreversible actions (publishing, deploying, paying, credentials);",
        "- sovereignty and project-direction calls.",
        "",
        "Everything else goes to you. For each criterion return exactly one verdict:",
        "- **green:** verified it is met. Say how, with evidence.",
        "- **amber:** mostly met. Say exactly what is needed.",
        "- **red:** not met. Say what is needed.",
        "- **escalate:** needs the human. Say why.",
        "",
        f"## Independence: {_rung_label(rung, seat)}",
        "",
        f"Rung {rung} was chosen by the IW-7 impact-risk model ({rung_reason or 'default'}).",
    ]
    if seat:
        lines.append(f"You hold panel seat `{seat}`.")
    if ceiling_note:
        lines += ["", f"**RUNG DROPPED: {ceiling_note}.** State this in your evidence report."]
    lines += ["", "## The criteria", "", f"Task: {task_id}", ""]
    for c in criteria:
        lines += [f"### Criterion {c['index']} (Human AC#{c['ac_index']})", "", c["body"], ""]

    if ev["needed"]:
        lines += ["## Rendered pages", ""]
        if ev["shots"]:
            lines.append("Screenshots of the pages the task touched (open each with Read):")
            lines += [f"- `{s}`" for s in ev["shots"]]
            if ev["error"]:
                lines.append(f"Capture was partial: {ev['error']}. Pages you did not see are unjudged.")
        else:
            lines += [
                f"**SCREENSHOT CAPTURE FAILED: {ev['error'] or 'no screenshot captured'}.**",
                "You have NOT seen the rendered page. You MUST NOT return green on a page you "
                "did not see. Return `escalate` (or `amber` with what is missing) for every "
                "criterion that asks about rendering.",
            ]
        if ev["pages"]:
            lines.append("Pages: " + ", ".join(f"`{p}`" for p in ev["pages"]))
        lines.append("")

    lines += [
        "## How you record your verdict (you write it; nobody writes it for you)",
        "",
        "Your dispatch id is `$FW_SIDECAR_AGENT_ID`. For EACH criterion above, in this order:",
        "",
        f"1. Write your evidence report to `{REPORT_DIR}/{task_id}/AC<N>-$FW_SIDECAR_AGENT_ID.md` "
        "(what you checked and found). Copy any screenshot you cite into the same directory and "
        "cite that copy.",
        f"2. Compute the digest you read: `bin/fw reviewer verdict digest {task_id} --ac <N>`",
        "3. Record it, citing your report (and screenshots) as `--evidence`:",
        "",
        f"   `bin/fw reviewer verdict record {task_id} --ac <N> --outcome green|amber|red|escalate "
        f"--reviewer '{seat or 'reviewer'}:$FW_SIDECAR_AGENT_ID' --rung {_rung_label(rung, seat)} "
        "--dispatch-id $FW_SIDECAR_AGENT_ID --digest <digest> --evidence <report> "
        "[--evidence <png> ...] [--guidance '...']`",
        "",
        "   `--guidance` is mandatory unless green.",
        "4. Commit your own rows, staging by name, under your own identity:",
        "",
        "   `git add .context/reviews && git -c user.name=reviewer-$FW_SIDECAR_AGENT_ID "
        f"-c user.email=reviewer@aef.local commit -m '{task_id}: reviewer verdict'`",
        "",
        "Do not edit the task file, do not tick anything, do not touch any file outside "
        f"`{REPORT_DIR}/{task_id}/` and the ledger. Never use a bypass flag.",
        "",
        "## Output format (printed)",
        "",
        "After recording, print for each criterion:",
        "```",
        "N. [AC] <criterion short>",
        "VERDICT: green | amber | red | escalate",
        "WHY: <what you checked, with evidence; or why a human is needed>",
        "GUIDANCE: <what is needed next, mandatory for non-green>",
        "```",
        "End with: 'Summary: N green, M amber, K red, J escalate'. The printed text is for the "
        "operator's reading only; the ledger row is the record.",
    ]
    if operator_only:
        lines += ["", "Not yours (operator-only, never judge): " +
                  ", ".join(f"AC#{c['ac_index']}" for c in operator_only)]
    return "\n".join(lines)


# ── dispatch ─────────────────────────────────────────────────────────────────

Dispatcher = Callable[..., str]


def _dispatch_real(*, task_id: str, brief: str, root: Path, name: str, timeout: int = 900) -> str:
    """Spawn the review worker via `fw termlink dispatch --task-type review`, wait for it, and
    return its dispatch id (the wrapper appends a random suffix and registers it)."""
    fw = Path(os.environ.get("FRAMEWORK_ROOT") or root) / "bin" / "fw"
    pf = root / ".context/working" / f"judge-brief-{name}.md"
    pf.parent.mkdir(parents=True, exist_ok=True)
    pf.write_text(brief)
    r = subprocess.run([str(fw), "termlink", "dispatch", "--name", name, "--task", task_id,
                        "--task-type", "review", "--prompt-file", str(pf),
                        "--timeout", str(timeout), "--project-dir", str(root)],
                       cwd=root, capture_output=True, text=True, timeout=120)
    m = re.search(r"Worker spawned:\s*(\S+)", r.stdout)
    if r.returncode != 0 or not m:
        raise RuntimeError(f"dispatch failed (exit {r.returncode}): {(r.stderr or r.stdout)[-300:]}")
    did = m.group(1)
    subprocess.run([str(fw), "termlink", "wait", "--name", did, "--timeout", str(timeout)],
                   cwd=root, capture_output=True, text=True, timeout=timeout + 60)
    return did


def _dispatch_reviewer(task_id: str, brief: str, rung: int, dry_run: bool, root: Path,
                       dispatcher: Dispatcher | None = None, name: str | None = None) -> str | None:
    if dry_run:
        return None
    dispatcher = dispatcher or _dispatch_real
    return dispatcher(task_id=task_id, brief=brief, root=root,
                      name=name or f"judge-{task_id.lower()}-r{rung}")


# ── reading the result: the ledger is authoritative ──────────────────────────

_VERDICT_LINE = re.compile(r"^\s*(\d+)\.\s*\[[^\]]*\].*?\n\s*VERDICT:\s*(\w+)", re.M)


def _parse_printed(output: str, criteria: list[dict]) -> dict[int, str]:
    """Printed verdict per criterion `index`, for REPORTING only. Anything not exactly one
    of the four outcomes is `unknown`."""
    found = {int(n): v.lower() for n, v in _VERDICT_LINE.findall(output or "")}
    return {c["index"]: (found.get(c["index"]) if found.get(c["index"]) in vl.OUTCOMES else UNKNOWN)
            for c in criteria}


def _collect(root: Path, task_id: str, dispatch_id: str, criteria: list[dict],
             printed: dict[int, str] | None = None) -> list[dict]:
    """One result per criterion, read from the ledger. green only when the row would pass
    `apply` (`satisfying_verdict`) AND names this dispatch; a missing/malformed row is unknown."""
    printed = printed or {}
    path, _sub = vl._find_task(root, task_id)
    if path is None:
        return [{"ac": c["ac_index"], "outcome": UNKNOWN, "source": "no-task"} for c in criteria]
    ctx = vl._Ctx(root, task_id, path, path.read_text(encoding="utf-8", errors="replace"))
    crits = {c.index: c for c in human_criteria(ctx.text)}
    rows = [r for r in vl._read(vl.VERDICTS, root)
            if r.get("task") == task_id and r.get("dispatch_id") == dispatch_id]
    out = []
    for c in criteria:
        mine = [r for r in rows if r.get("ac") == c["ac_index"]]
        res = {"ac": c["ac_index"], "outcome": UNKNOWN, "source": "no-ledger-row",
               "printed": printed.get(c["index"], UNKNOWN), "verdict_id": ""}
        if mine:
            row = mine[-1]
            oc = row.get("outcome")
            res.update(source="ledger", verdict_id=row.get("id", ""), rung=row.get("rung", ""))
            if oc == vl.GREEN:
                good, why = vl.satisfying_verdict(ctx, crits[c["ac_index"]]) if c["ac_index"] in crits else (None, "gone")
                if good and good.get("id") == row.get("id"):
                    res["outcome"] = vl.GREEN
                else:
                    res.update(outcome=UNKNOWN, source="ledger-row-invalid", why=why or "")
            elif oc in vl.OUTCOMES:
                res["outcome"] = oc
            else:
                res.update(source="ledger-row-malformed")
        out.append(res)
    return out


def _flag_unseen_green(results: list[dict], criteria: list[dict], evidence: dict) -> None:
    """A green on a render criterion whose capture failed contradicts the brief: flag it."""
    if not (evidence.get("needed") and not evidence.get("shots")):
        return
    render_acs = {c["ac_index"] for c in criteria if c["render"]}
    for r in results:
        if r["ac"] in render_acs and r["outcome"] == vl.GREEN:
            r["flag"] = "green-on-unseen-page: capture failed, so this verdict is not accepted"
            r["outcome"] = UNKNOWN


def _log_spend(root: Path, task_id: str, rung: int, cost: float) -> None:
    p = root / SPEND_LOG
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a") as f:
        f.write(json.dumps({"ts": _now(), "task": task_id, "rung": rung, "cost": cost}) + "\n")


# ── orchestration ────────────────────────────────────────────────────────────

def judge(task_id: str, root: Path, *, criterion_n: int | None = None, dry_run: bool = False,
          dispatcher: Dispatcher | None = None, capture: Capturer | None = None,
          now: datetime | None = None) -> dict:
    """Run one judgement. Returns a result dict; never writes a verdict."""
    task_data = _load_task(task_id, root)
    if not task_data:
        return {"error": f"Task {task_id} not found", "code": 1}
    judged, operator = _partition(task_data, root, task_id, criterion_n)
    res: dict = {"task_id": task_id, "dry_run": dry_run, "operator_only": [
        {"ac": c["ac_index"], "class": c["class"], "reason": c["reason"]} for c in operator],
        "criteria": [{"ac": c["ac_index"], "text": c["text"][:80], "class": c["class"]} for c in judged]}
    if not judged:
        res.update(error=f"No REVIEWER_JUDGES criteria found for {task_id}", code=1)
        return res

    due, reason = _calculate_rung(task_data)
    spent, ceiling = _weekly_spend(root, now), _ceiling(root)
    rung, reason, note = _apply_ceiling(due, reason, spent, ceiling)
    res.update(rung_due=due, rung=rung, rung_reason=reason, ceiling_note=note,
               weekly_spend=spent, ceiling=ceiling)

    evidence = _gather_evidence(root, task_id, task_data, judged, capture or _capture_playwright,
                                dry_run=dry_run)
    res["evidence"] = evidence
    seats = PANEL_SEATS if rung >= 5 else ("",)
    briefs = {s: _build_brief(task_id, judged, rung=rung, rung_reason=reason, ceiling_note=note,
                              evidence=evidence, seat=s, operator_only=operator) for s in seats}
    res["brief"] = briefs[seats[0]]
    if dry_run:
        res["code"] = 0
        return res

    res["dispatches"] = []
    for seat in seats:
        try:
            did = _dispatch_reviewer(task_id, briefs[seat], rung, False, root, dispatcher,
                                     name=f"judge-{task_id.lower()}-r{rung}" + (f"-{seat}" if seat else ""))
        except Exception as e:  # noqa: BLE001
            res["dispatches"].append({"seat": seat, "error": str(e), "results": [
                {"ac": c["ac_index"], "outcome": UNKNOWN, "source": "dispatch-failed"} for c in judged]})
            break
        results = _collect(root, task_id, did, judged)
        _flag_unseen_green(results, judged, evidence)
        _log_spend(root, task_id, rung, RUNG_COST.get(rung, 2.0) / len(seats))
        res["dispatches"].append({"seat": seat, "dispatch_id": did, "results": results})
        # A panel is sequential and stops at the first seat that does not clear every criterion:
        # the ledger's LATEST row decides, so a later seat must never paper over an earlier one.
        if any(r["outcome"] != vl.GREEN for r in results):
            break
    last = res["dispatches"][-1]["results"] if res["dispatches"] else []
    res["outcomes"] = {r["ac"]: r["outcome"] for r in last}
    res["code"] = 0
    return res


def _print_result(res: dict) -> None:
    print(f"Task: {res['task_id']}")
    print(f"Criteria: {len(res['criteria'])} REVIEWER_JUDGES")
    for o in res["operator_only"]:
        print(f"  operator-only (never dispatched): AC#{o['ac']} [{o['class']}]")
    print(f"Rung: {res['rung']} ({res['rung_reason']})")
    if res.get("ceiling_note"):
        print(f"  {res['ceiling_note']}")
    ev = res.get("evidence", {})
    if ev.get("needed"):
        print(f"Screenshots: {len(ev['shots'])} (pages: {', '.join(ev['pages']) or 'none'})"
              + (f"; capture: {ev['error']}" if ev["error"] else ""))
    if res["dry_run"]:
        print("\n--- brief ---\n" + res["brief"])
        return
    for d in res.get("dispatches", []):
        print(f"Dispatch {d.get('dispatch_id', '-')}{' seat ' + d['seat'] if d.get('seat') else ''}"
              + (f" FAILED: {d['error']}" if d.get("error") else ""))
        for r in d["results"]:
            print(f"  AC#{r['ac']}: {r['outcome']} ({r['source']}){' ' + r['flag'] if r.get('flag') else ''}")


def main(argv: list[str] | None = None, *, dispatcher: Dispatcher | None = None,
         capture: Capturer | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Dispatch an independent reviewer on REVIEWER_JUDGES criteria")
    parser.add_argument("task_id", help="Task ID (T-XXXX)")
    parser.add_argument("--criterion", type=int, default=None, help="Human criterion number")
    parser.add_argument("--dry-run", action="store_true", help="print criteria, rung and brief; dispatch nothing")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)

    res = judge(args.task_id, _root(), criterion_n=args.criterion, dry_run=args.dry_run,
                dispatcher=dispatcher, capture=capture)
    if res.get("error") and "criteria" not in res:
        print(f"Error: {res['error']}", file=sys.stderr)
        return res["code"]
    if res.get("error"):
        print(res["error"], file=sys.stderr)
        for o in res["operator_only"]:
            print(f"operator-only (never dispatched): AC#{o['ac']} [{o['class']}]", file=sys.stderr)
        return res["code"]
    if args.json:
        print(json.dumps(res, indent=2, default=str))
    else:
        _print_result(res)
    return res["code"]


if __name__ == "__main__":
    sys.exit(main())
