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
value_at_stake) over reversibility, blast radius, audience, value and uncertainty picks rung 1
(low: same-vendor independent agent), 3 (medium: one TermLink-dispatched reviewer) or 5 (high:
panel of 3 vendors). A weekly spend ceiling (config REVIEWER_JUDGE_WEEKLY_SPEND_CEILING) drops the
rung one step, and the brief and the result say so.

THE LEDGER ENFORCES, NOT THIS CLI (T-3580 round 2). Anything promised here is refused by
lib/verdict_ledger.py's shared validator or it does not exist: the worker's signed completion
(session, revision, digest, evidence hashes, verdict hash, introducing commit), the pages a render
criterion needs with the capture result of each, and a panel's required seats are all registered
in a signed review run BEFORE dispatch, and `apply` / `check-render` / `audit` read them.

BACKENDS COME FROM THE REGISTRY (T-3583, round 3). No vendor is named here. The seats are the
backends in policy/review-backends.yaml (read through lib/review_cost.py, the registry's only
parser) that declare a `--worker-kind` match; the ones `fw termlink worker-kinds` can actually
dispatch run. Every dispatched seat logs one cost record (`fw review cost log`). A seat that no
internal backend can fill is offered to a PAID backend by `fw review propose` — and then waits for
the operator: the judge never dispatches a paid backend.

SINGLE-VENDOR HONESTY. Until T-3582 builds codex/opencode worker kinds only claude dispatches. A
rung-5 run registers all three seats as required, dispatches the one it can, proposes the paid
alternative for the others, and is reported "degraded: single-vendor panel"; the ledger refuses to
let it satisfy the criterion. We chose "leave the criterion open" over "downgrade the requirement":
a high-impact criterion is not quietly closed on a weaker review than the impact model asked for.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import uuid
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
RUNG_COST = {1: 2.0, 2: 2.0, 3: 3.0, 5: 6.0}
#: IW-7: a rung-5 panel is three reviewers from three different vendors. WHICH vendors is the
#: registry's business (policy/review-backends.yaml), not this module's.
PANEL_SIZE = 3
#: Screenshots taken per run. Pages beyond the cap are still REQUIRED: they are registered as
#: not captured, so the ledger refuses a render green (round 3: no silent truncation).
MAX_CAPTURE_PAGES = 6
DEGRADED_SINGLE_VENDOR = "degraded: single-vendor panel"
UNKNOWN = "unknown"
COST_PURPOSE = "reviewer-judge"


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


# ── backends: the registry decides, the dispatcher says what can run ──────────────

_WORKER_KIND_RE = re.compile(r"--worker-kind\[= \]([A-Za-z0-9_-]+)")


class _Env:
    """Run lib/review_cost.py (the registry's only parser, and the cost/proposal helper) against
    `root`: it reads PROJECT_ROOT / FRAMEWORK_ROOT from the environment."""

    def __init__(self, root: Path):
        self.vals = {"PROJECT_ROOT": str(root), "FRAMEWORK_ROOT": str(_HERE.parent)}
        self.old: dict = {}

    def __enter__(self):
        self.old = {k: os.environ.get(k) for k in self.vals}
        os.environ.update(self.vals)
        from lib import review_cost
        return review_cost

    def __exit__(self, *exc):
        for k, v in self.old.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def _backends(root: Path) -> tuple[list[dict], list[dict]]:
    """(seat backends, paid backends) from the registry, in registry order.

    A seat backend is internal and declares the worker kind that runs it in its `match:` list
    (`--worker-kind[= ]<kind>`); it carries `kind`. A paid backend needs an approved proposal."""
    with _Env(root) as rc:
        reg = rc.load_registry()
    seats, paid = [], []
    for b in reg:
        if b.get("cost_class") == "paid" or b.get("approval_required"):
            paid.append(dict(b))
            continue
        kind = next((m.group(1) for pat in b.get("match") or [] for m in [_WORKER_KIND_RE.search(pat)] if m), "")
        if kind:
            seats.append({**b, "kind": kind})
    return seats, paid


def _dispatchable_kinds(root: Path) -> set[str]:
    """The worker kinds `fw termlink dispatch` accepts (`fw termlink worker-kinds`)."""
    sh = _HERE.parent / "agents" / "termlink" / "termlink.sh"
    try:
        out = subprocess.run(["bash", str(sh), "worker-kinds"], capture_output=True, text=True,
                             timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return set()
    return {w for w in out.split() if w}


def _kind_vendors(root: Path) -> dict[str, str]:
    """{worker kind: vendor} from the dispatcher's own table (`fw termlink worker-kinds
    --vendors`, T-3580 round 4). The same table registers each review dispatch's vendor, which is
    what the ledger counts; a kind the table does not know has no vendor."""
    sh = _HERE.parent / "agents" / "termlink" / "termlink.sh"
    try:
        out = subprocess.run(["bash", str(sh), "worker-kinds", "--vendors"], capture_output=True,
                             text=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    pairs = (ln.split() for ln in out.splitlines())
    return {p[0]: p[1] for p in pairs if len(p) == 2}


def _log_seat_cost(root: Path, task_id: str, backend: str, purpose: str, evidence: str) -> str:
    """One cost record per dispatched seat via the helper. '' on success, else the refusal."""
    try:
        with _Env(root) as rc:
            rc.log_cost(task=task_id, backend=backend, purpose=purpose, tokens=None, cost=None,
                        proposal_id=None, evidence=evidence)
        return ""
    except Exception as e:  # noqa: BLE001 - reported, never swallowed
        return str(e)


def _propose_paid(root: Path, task_id: str, backend: str, why: str, estimate: float) -> dict:
    """Propose a paid seat (`fw review propose`), or reuse this run-seat's open proposal. Returns
    the proposal; the judge only ever waits on it."""
    with _Env(root) as rc:
        used = rc._consumed()
        for p in rc.proposals().values():
            if (p.get("task") == task_id and p.get("backend") == backend and p["id"] not in used
                    and p.get("why") == why):
                return p
        return rc.propose(task=task_id, backend=backend, why=why, est_cost=estimate, est_tokens=None)


# ── rung (IW-7) ──────────────────────────────────────────────────────────────

_IRREVERSIBLE_RE = re.compile(
    r"\b(publish(?:es|ed|ing)?|deploy(?:s|ed|ing)?|production|credential[s]?|secret[s]?|payment|"
    r"drop\s+table|force[- ]push|delete[sd]?\s+(?:data|branch))\b", re.I)
_CONSUMER_PATH_RE = re.compile(r"(?:^|[\s`'\"(])((?:lib|agents|policy|web|seeds)/[\w./-]+|bin/fw)\b")
_CROSS_PROJECT_RE = re.compile(r"\b(cross[- ]project|peer projects?|consumer projects?|other projects?|external users?)\b", re.I)
_CONSUMER_RE = re.compile(r"\b(consumers?|fw upgrade|vendored|install surface)\b", re.I)
_SECURITY_RE = re.compile(r"\b(security|vulnerab\w*|auth(?:entication|orization)?|sandbox)\b", re.I)
_OBJECTIVE_RE = re.compile(r"\bproject[- ]objectives?\b", re.I)


def _impact(task_data: dict, criteria: list[dict] | None = None) -> dict:
    """IW-7 impact = max(cost_if_wrong, value_at_stake). Returns {'tier', 'inputs', 'reasons'}
    where inputs records what each axis saw, so the selection is auditable."""
    fm = task_data["frontmatter"]
    crit_text = "\n".join(c.get("body", "") for c in (criteria or []))
    # What the change is ABOUT (title, description, the criteria under review) - not the whole
    # task body, which mentions "consumers" and "security" in passing on almost every task.
    scan = f"{fm.get('name', '')}\n{fm.get('description', '')}\n{crit_text}"
    ce = fm.get("cost_estimate") or {}
    blast = ce.get("blast_radius")
    comps = fm.get("components") or []
    comps = comps if isinstance(comps, list) else [comps]
    paths = sorted({m for m in _CONSUMER_PATH_RE.findall(scan)} | {str(c) for c in comps
                    if re.match(r"(lib|agents|policy|web|seeds)/|bin/fw", str(c))})
    bvp = fm.get("bvp_scores") or {}
    voi = fm.get("voi_score")
    conf = fm.get("iw_confidence", fm.get("confidence"))
    tags = [str(t).lower() for t in (fm.get("tags") or [])] if isinstance(fm.get("tags"), list) else []
    inputs = {
        "reversibility": "leaves-repo" if _IRREVERSIBLE_RE.search(scan) else "git-only",
        "blast_radius": blast, "components": len(comps), "consumer_paths": paths[:6],
        "audience": ("cross-project" if _CROSS_PROJECT_RE.search(scan)
                     else "consumers" if (paths or _CONSUMER_RE.search(scan)) else "internal"),
        "value": {"bvp": {k: bvp.get(k) for k in ("D1", "D2") if k in bvp}, "voi_score": voi,
                  "project_objective": bool(_OBJECTIVE_RE.search(scan) or "objective" in tags)},
        "uncertainty": {"confidence": conf,
                        "inception": str(fm.get("workflow_type")) == "inception"},
        "security": bool(_SECURITY_RE.search(scan) or "security" in tags),
    }
    high, medium = [], []
    if isinstance(blast, (int, float)) and blast > 5:
        high.append(f"blast_radius={blast}")
    elif isinstance(blast, (int, float)) and blast >= 3:
        medium.append(f"blast_radius={blast}")
    if len(comps) >= 5:
        high.append(f"components={len(comps)}")
    if isinstance(voi, (int, float)) and voi >= 0.6:
        high.append(f"voi_score={voi}")
    if bvp and (bvp.get("D1", 0) > 3 or bvp.get("D2", 0) > 3):
        high.append("D1/D2 > 3")
    if inputs["value"]["project_objective"]:
        high.append("project objective")
    if inputs["security"]:
        high.append("security")
    if inputs["audience"] == "cross-project":
        high.append("cross-project audience")
    if inputs["reversibility"] == "leaves-repo":
        high.append("not undone by git revert")
    if isinstance(conf, (int, float)) and conf <= 1:
        high.append(f"confidence={conf}")
    if inputs["audience"] == "consumers":
        medium.append("consumer-facing code (" + (paths[0] if paths else "consumer text") + ")"
                      " [held at medium: IW-7's blast-radius row would count the install surface "
                      "high; see T-3580 Decisions]")
    if inputs["uncertainty"]["inception"]:
        medium.append("inception GO")
    if len(comps) >= 3:
        medium.append(f"components={len(comps)}")
    tier = "high" if high else "medium" if medium else "low"
    return {"tier": tier, "inputs": inputs, "reasons": high if high else medium}


def _calculate_rung(task_data: dict, criteria: list[dict] | None = None) -> tuple[int, str]:
    """IW-7: low -> rung 1, medium -> rung 3, high -> rung 5. Returns (rung, reason)."""
    imp = _impact(task_data, criteria)
    rung = {"low": 1, "medium": 3, "high": 5}[imp["tier"]]
    return rung, "; ".join(imp["reasons"]) if imp["reasons"] else "default"


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
    """Drop one rung (5 -> 3 -> 1) when the due rung would take the week past the ceiling.
    Returns (rung, reason, note); note is '' when nothing was dropped."""
    if spent + RUNG_COST.get(rung, 2.0) <= ceiling:
        return rung, reason, ""
    lower = 3 if rung >= 5 else 1
    if lower == rung or rung <= 1:
        note = (f"weekly spend ceiling reached (spent {spent:g} of {ceiling:g}); rung {rung} is "
                f"already the lowest, so it runs at rung {rung} and is not skipped")
        return rung, reason, note
    note = (f"reviewed at rung {lower}, weekly spend ceiling reached (spent {spent:g} of "
            f"{ceiling:g}); rung {rung} was due")
    return lower, reason, note


def _rung_label(rung: int, seat: str = "") -> str:
    base = ("rung-1-same-vendor-independent" if rung <= 1 else
            "rung-2-same-vendor-independent" if rung == 2 else
            "rung-3-termlink-single-reviewer" if rung <= 4 else "rung-5-panel")
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
    return out          # every required page; capture is capped separately (MAX_CAPTURE_PAGES)


def _watchtower_url(root: Path) -> str:
    f = root / ".context/working/watchtower.url"
    return f.read_text().strip() if f.exists() else ""


def _shot_name(i: int, page: str) -> str:
    return f"{i + 1:02d}-{re.sub(r'[^a-z0-9]+', '-', page.lower()).strip('-') or 'root'}.png"


def _capture_playwright(base_url: str, pages: list[str], outdir: Path) -> tuple[list[Path], str]:
    """Real capturer. Returns (paths, error); shots are named `_shot_name(i, page)` so each page's
    result can be told apart, and a partial failure comes back as 'partial: <page>: <why>; ...'."""
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
                    f = outdir / _shot_name(i, p)
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
    """{'needed', 'pages', 'shots', 'error', 'captures', 'partial'}.

    `captures` is the per-page result the ledger will be given: {'page', 'ok', 'sha256', 'path',
    'error'}. A page with no verified screenshot is `ok: False` whatever else was captured, so a
    partial capture is preserved rather than collapsed into a single pass/fail."""
    needed = any(c["render"] for c in criteria)
    ev = {"needed": needed, "pages": [], "shots": [], "error": "", "captures": [], "partial": []}
    if not needed:
        return ev
    ev["pages"] = _pages_for(root, task_id, task_data["text"], [c for c in criteria if c["render"]])
    if dry_run:
        return ev
    shoot = ev["pages"][:MAX_CAPTURE_PAGES]
    try:
        shots, err = capture(_watchtower_url(root), shoot, root / EVIDENCE_DIR / task_id)
    except Exception as e:  # noqa: BLE001
        shots, err = [], f"capture crashed: {e}"
    by_name = {Path(x).name: Path(x) for x in shots if Path(x).exists()}
    errs = err[len("partial: "):].split("; ") if err.startswith("partial: ") else []
    for i, pg in enumerate(ev["pages"]):
        f = by_name.get(_shot_name(i, pg)) if i < MAX_CAPTURE_PAGES else None
        if i >= MAX_CAPTURE_PAGES:
            ev["captures"].append({"page": pg, "ok": False, "sha256": "", "path": "",
                                   "error": f"not captured: capture is capped at "
                                            f"{MAX_CAPTURE_PAGES} pages"})
        elif f is not None:
            ev["captures"].append({"page": pg, "ok": True, "sha256": vl._hash_path(f),
                                   "path": str(f.resolve().relative_to(root.resolve())), "error": ""})
        else:
            why = next((e for e in errs if e.startswith(f"{pg}:")), err or "not captured")
            ev["captures"].append({"page": pg, "ok": False, "sha256": "", "path": "", "error": why})
    ev["shots"] = [c["path"] for c in ev["captures"] if c["ok"]]
    ev["partial"] = [c["page"] for c in ev["captures"] if not c["ok"]]
    ev["error"] = err if (err and not ev["shots"]) else ""
    if not ev["shots"] and not ev["error"]:
        ev["error"] = "no screenshot captured"
    return ev


# ── the brief ────────────────────────────────────────────────────────────────

def record_command(task_id: str, seat: str, rung: int, run_id: str) -> str:
    """The exact `verdict record` line a worker runs. Every `$FW_SIDECAR_AGENT_ID` sits in double
    quotes or bare, never single quotes, so the shell expands it (round 3: a single-quoted
    reviewer string was submitted literally and refused)."""
    run = f" --run-id {run_id}" if run_id else ""
    return (f'bin/fw reviewer verdict record {task_id} --ac <N> --outcome <OUTCOME> '
            f'--reviewer "reviewer-$FW_SIDECAR_AGENT_ID:{seat or "reviewer"}" '
            f'--rung {_rung_label(rung, seat)} --dispatch-id "$FW_SIDECAR_AGENT_ID"{run} '
            f'--digest <DIGEST> --evidence <REPORT>')


def commit_command(task_id: str) -> str:
    return ('git add .context/reviews && GIT_AUTHOR_NAME="reviewer-$FW_SIDECAR_AGENT_ID" '
            'GIT_COMMITTER_NAME="reviewer-$FW_SIDECAR_AGENT_ID" GIT_AUTHOR_EMAIL=reviewer@aef.local '
            f'GIT_COMMITTER_EMAIL=reviewer@aef.local git commit -m "{task_id}: reviewer verdict"')


def _build_brief(task_id: str, criteria: list[dict], *, rung: int = 1, rung_reason: str = "",
                 ceiling_note: str = "", evidence: dict | None = None, seat: str = "",
                 operator_only: list[dict] | None = None, run_id: str = "",
                 degraded: str = "", revision: str = "") -> str:
    ev = {"needed": False, "shots": [], "error": "", "pages": [], "partial": [],
          **(evidence or {})}
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
    if degraded:
        lines.append(f"**{degraded}.** Fewer vendors can be dispatched than the panel requires, so "
                     "this run cannot satisfy a multi-vendor requirement: your verdict is recorded "
                     "and reported, and the criterion stays open. Say so in your evidence report.")
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
            if ev["partial"]:
                lines.append("**Capture was PARTIAL. You did NOT see: " +
                             ", ".join(f"`{p}`" for p in ev["partial"]) +
                             ".** You MUST NOT return green for a criterion that depends on a "
                             "page you did not see; the ledger refuses such a green.")
            lines.append("Cite EVERY screenshot above as `--evidence` (the copy in your report "
                         "directory); the ledger checks each required page's screenshot hash.")
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
        f"You review revision `{revision or '$FW_REVIEW_REVISION'}` (registered with your dispatch; "
        "your verdict is bound to it, not to whatever HEAD is when you record). Your dispatch id "
        "is `$FW_SIDECAR_AGENT_ID`. For EACH criterion above, in this order:",
        "",
        f"1. Write your evidence report to `{REPORT_DIR}/{task_id}/AC<N>-$FW_SIDECAR_AGENT_ID.md` "
        "(what you checked and found). Copy any screenshot you cite into the same directory and "
        "cite that copy.",
        f"2. Compute the digest you read: `bin/fw reviewer verdict digest {task_id} --ac <N>`",
        "3. Record it (replace <N>, <OUTCOME>, <DIGEST>, <REPORT>; run it exactly as written, so "
        "the shell expands `$FW_SIDECAR_AGENT_ID`):",
        "",
        "   " + record_command(task_id, seat, rung, run_id),
        "",
        "   Add `--evidence <png>` once per screenshot you cite, and `--guidance \"...\"` "
        "(mandatory unless green).",
        "",
        "   `record` does NOT sign anything. When you exit, the dispatch runtime signs your "
        "completion (your session, exit state, result stream and the exact rows you left). A row "
        "you did not leave by then never counts, and neither does a green if you exit non-zero.",
        "",
        "4. Commit your own rows, staging by name, under your own identity:",
        "",
        "   " + commit_command(task_id),
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


def _dispatch_argv(fw: Path, *, task_id: str, name: str, prompt_file: Path, root: Path,
                   vendor: str, timeout: int, revision: str = "") -> list[str]:
    """The exact `fw termlink dispatch` argv: the wrapper takes --project (not --project-dir) and
    --worker-kind for the vendor. A vendor with no worker kind yet (codex/opencode, T-3582) makes
    the wrapper refuse loudly rather than silently run another vendor's worker."""
    argv = [str(fw), "termlink", "dispatch", "--name", name, "--task", task_id,
            "--task-type", "review", "--worker-kind", vendor, "--prompt-file", str(prompt_file),
            "--timeout", str(timeout), "--project", str(root)]
    if revision:
        argv += ["--review-revision", revision]
    return argv


def _await_worker(fw: Path, did: str, root: Path, timeout: int) -> int:
    """Wait through `fw termlink wait`, which for a review dispatch returns only once the runtime
    has FINALISED it (completion signed or refused), not merely exited (round 4)."""
    r = subprocess.run([str(fw), "termlink", "wait", "--name", did, "--timeout", str(timeout)],
                       cwd=root, capture_output=True, text=True, timeout=timeout + 60)
    return r.returncode


def _dispatch_real(*, task_id: str, brief: str, root: Path, name: str, vendor: str,
                   timeout: int = 900, revision: str = "") -> str:
    """Spawn the review worker via `fw termlink dispatch --task-type review`, wait for it, and
    return its dispatch id (the wrapper appends a random suffix and registers it)."""
    fw = Path(os.environ.get("FRAMEWORK_ROOT") or root) / "bin" / "fw"
    pf = root / ".context/working" / f"judge-brief-{name}.md"
    pf.parent.mkdir(parents=True, exist_ok=True)
    pf.write_text(brief)
    r = subprocess.run(_dispatch_argv(fw, task_id=task_id, name=name, prompt_file=pf, root=root,
                                      vendor=vendor, timeout=timeout, revision=revision),
                       cwd=root, capture_output=True, text=True, timeout=120)
    m = re.search(r"Worker spawned:\s*(\S+)", r.stdout)
    if r.returncode != 0 or not m:
        raise RuntimeError(f"dispatch failed (exit {r.returncode}): {(r.stderr or r.stdout)[-300:]}")
    did = m.group(1)
    _await_worker(fw, did, root, timeout)
    return did


def _dispatch_reviewer(task_id: str, brief: str, rung: int, dry_run: bool, root: Path,
                       dispatcher: Dispatcher | None = None, name: str | None = None,
                       vendor: str = "", revision: str = "") -> str | None:
    if dry_run:
        return None
    if not vendor:
        raise ValueError("no worker kind: the registry's seat backend names none")
    dispatcher = dispatcher or _dispatch_real
    return dispatcher(task_id=task_id, brief=brief, root=root, vendor=vendor, revision=revision,
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
    """One result per criterion, read from the ledger and validated by the ledger's own
    validator (`vl._fault`) for EVERY outcome: a row that is not a valid, attributable record
    for this criterion is `unknown` whatever it says, so a malformed amber cannot be reported as
    amber and a green the ledger would refuse cannot be reported as green."""
    printed = printed or {}
    path, _sub = vl._find_task(root, task_id)
    if path is None:
        return [{"ac": c["ac_index"], "outcome": UNKNOWN, "source": "no-task"} for c in criteria]
    ctx = vl._Ctx(root, task_id, path, path.read_text(encoding="utf-8", errors="replace"))
    crits = {c.index: c for c in human_criteria(ctx.text)}
    led = ctx.ledger
    rows = [(r, i) for r, i in led.entries()
            if r.get("task") == task_id and r.get("dispatch_id") == dispatch_id]
    out = []
    for c in criteria:
        mine = [(r, i) for r, i in rows if r.get("ac") == c["ac_index"]]
        res = {"ac": c["ac_index"], "outcome": UNKNOWN, "source": "no-ledger-row",
               "printed": printed.get(c["index"], UNKNOWN), "verdict_id": ""}
        if led.faults:
            res.update(source="ledger-integrity", why=led.faults[0])
        elif mine:
            row, intro = mine[-1]
            res.update(source="ledger", verdict_id=str(row.get("id", "")), rung=row.get("rung", ""))
            crit = crits.get(c["ac_index"])
            if crit is None:
                res.update(source="ledger-row-invalid", why="criterion gone")
            else:
                f = vl._fault(ctx, row, crit, intro)
                if f is None:
                    res["outcome"] = row["outcome"]
                else:
                    res.update(source="ledger-row-invalid", why=f"{f[0]}: {f[1]}")
                    if f[0] == "unseen-page":
                        res["flag"] = f"green-on-unseen-page: {f[1]}"
        out.append(res)
    return out


def _final(root: Path, task_id: str, judged: list[dict], dispatches: list[dict]) -> tuple[dict, dict]:
    """(outcomes, why) per criterion AFTER the whole run: green only if `satisfying_verdict` - the
    check `apply` uses, which requires every required seat and vendor - accepts it."""
    path, _ = vl._find_task(root, task_id)
    ctx = vl._Ctx(root, task_id, path, path.read_text(encoding="utf-8", errors="replace")) if path else None
    crits = {c.index: c for c in human_criteria(ctx.text)} if ctx else {}
    outcomes, whys = {}, {}
    for c in judged:
        seat_res = [r for d in dispatches if d.get("dispatch_id") for r in d["results"]
                    if r["ac"] == c["ac_index"]]
        last = seat_res[-1] if seat_res else {"outcome": UNKNOWN, "why": "no seat was dispatched"}
        if last["outcome"] == vl.GREEN:
            good, why = (vl.satisfying_verdict(ctx, crits[c["ac_index"]])
                         if ctx and c["ac_index"] in crits else (None, "criterion gone"))
            outcomes[c["ac_index"]] = vl.GREEN if good else UNKNOWN
            if not good:
                whys[c["ac_index"]] = why
        else:
            outcomes[c["ac_index"]] = last["outcome"]
            if last.get("why"):
                whys[c["ac_index"]] = last["why"]
    return outcomes, whys


def _log_spend(root: Path, task_id: str, rung: int, cost: float) -> None:
    p = root / SPEND_LOG
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a") as f:
        f.write(json.dumps({"ts": _now(), "task": task_id, "rung": rung, "cost": cost}) + "\n")


# ── orchestration ────────────────────────────────────────────────────────────

def _plan_seats(root: Path, rung: int, kinds: set[str], kind_vendors: dict | None = None) -> dict:
    """Which registry backends sit this run. {'seats': [...], 'required': N, 'dispatch': [...],
    'unfilled': [...], 'paid': [...]} — seats are {'seat', 'vendor', 'backend', 'kind'}."""
    seat_backends, paid = _backends(root)
    want = PANEL_SIZE if rung >= 5 else 1
    runnable = [b for b in seat_backends if b["kind"] in kinds]
    if rung >= 5:
        chosen = seat_backends[:want]        # the panel's vendors, in registry order
    else:
        chosen = (runnable or seat_backends)[:1]
    kv = kind_vendors or {}
    seats = [{"seat": b["id"], "vendor": b["id"], "backend": b["id"], "kind": b["kind"],
              "worker_vendor": kv.get(b["kind"], "")} for b in chosen]
    dispatch = [s for s in seats if s["kind"] in kinds]
    unfilled = [s for s in seats if s["kind"] not in kinds]
    for i in range(len(seats), want):     # the registry has fewer seat backends than the rung needs
        unfilled.append({"seat": f"seat-{i + 1}", "vendor": f"seat-{i + 1}", "backend": "", "kind": ""})
        seats.append(unfilled[-1])
    # Round 4: distinct VENDORS the dispatchable seats run, from the dispatcher's table — three
    # registry aliases for one worker kind are one vendor, whatever their backend ids.
    vendors = {s["worker_vendor"] for s in dispatch if s["worker_vendor"]}
    return {"seats": seats, "required": want, "dispatch": dispatch, "unfilled": unfilled,
            "paid": [b["id"] for b in paid], "vendors": sorted(vendors)}


def judge(task_id: str, root: Path, *, criterion_n: int | None = None, dry_run: bool = False,
          dispatcher: Dispatcher | None = None, capture: Capturer | None = None,
          now: datetime | None = None, worker_kinds: set[str] | None = None,
          kind_vendors: dict | None = None) -> dict:
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

    imp = _impact(task_data, judged)
    due = {"low": 1, "medium": 3, "high": 5}[imp["tier"]]
    reason = "; ".join(imp["reasons"]) if imp["reasons"] else "default"
    spent, ceiling = _weekly_spend(root, now), _ceiling(root)
    rung, reason, note = _apply_ceiling(due, reason, spent, ceiling)
    res.update(rung_due=due, rung=rung, rung_reason=reason, ceiling_note=note,
               impact=imp, weekly_spend=spent, ceiling=ceiling)

    try:
        plan = _plan_seats(root, rung,
                           _dispatchable_kinds(root) if worker_kinds is None else set(worker_kinds),
                           _kind_vendors(root) if kind_vendors is None else dict(kind_vendors))
    except Exception as e:  # noqa: BLE001 - an unreadable registry is a refusal, not a default
        res.update(error=f"review backend registry unavailable: {e}", code=1)
        return res
    seats, required = plan["seats"], plan["required"]
    degraded = (DEGRADED_SINGLE_VENDOR if rung >= 5 and (len(plan["dispatch"]) < required
                                                         or len(plan["vendors"]) < required) else "")
    res.update(seats=[s["seat"] for s in seats], dispatchable=[s["seat"] for s in plan["dispatch"]],
               unfilled=[s["seat"] for s in plan["unfilled"]], required_vendors=required,
               dispatch_vendors=plan["vendors"], degraded=degraded)

    # The revision under review is captured HERE, before any worker exists, and handed to the
    # dispatcher, which registers it with the dispatch (round 3).
    revision = vl._head_sha(root)
    res["revision"] = revision
    evidence = _gather_evidence(root, task_id, task_data, judged, capture or _capture_playwright,
                                dry_run=dry_run)
    res["evidence"] = evidence
    run_id = f"run-{task_id.lower()}-{uuid.uuid4().hex[:10]}"
    briefs = {s["seat"]: _build_brief(task_id, judged, rung=rung, rung_reason=reason,
                                      ceiling_note=note, evidence=evidence,
                                      seat=s["seat"] if rung >= 5 else "", operator_only=operator,
                                      run_id=run_id, degraded=degraded, revision=revision)
              for s in seats}
    res["brief"] = briefs[(plan["dispatch"] or seats)[0]["seat"]]
    if dry_run:
        res["code"] = 0
        return res
    if not revision:
        res.update(error="the repository has no commit: nothing to bind a review to", code=1)
        return res
    if not plan["dispatch"] and not plan["paid"]:
        res.update(error="no registered review backend can be dispatched here", code=1)
        return res

    # Register the run BEFORE any dispatch: what it requires (every seat, its vendors, the pages
    # each render criterion needs and how each capture went) is what the ledger later enforces.
    try:
        vl.register_run(
            run_id, task_id, acs=[c["ac_index"] for c in judged], rung=_rung_label(rung),
            seats=[{"seat": s["seat"], "vendor": s["vendor"]} for s in seats],
            required_vendors=required,
            pages={str(c["ac_index"]): evidence["pages"] for c in judged if c["render"]},
            captures=evidence["captures"],
            inputs=imp["inputs"], reason=reason + (f"; {note}" if note else ""),
            degraded=degraded, root=root)
    except Exception as e:  # noqa: BLE001
        res.update(error=f"could not register the review run: {e}", code=1)
        return res
    res["run_id"] = run_id

    res["dispatches"], res["cost_log_errors"], res["proposals"] = [], [], []
    per_seat = RUNG_COST.get(rung, 2.0) / (PANEL_SIZE if rung >= 5 else 1)
    for s in plan["dispatch"]:
        seat = s["seat"]
        try:
            did = _dispatch_reviewer(
                task_id, briefs[seat], rung, False, root, dispatcher,
                name=f"judge-{task_id.lower()}-r{rung}" + (f"-{seat}" if rung >= 5 else ""),
                vendor=s["kind"], revision=revision)
            vl.bind_dispatch(run_id, seat, did, s["vendor"], root=root)
        except Exception as e:  # noqa: BLE001
            res["dispatches"].append({"seat": seat, "error": str(e), "results": [
                {"ac": c["ac_index"], "outcome": UNKNOWN, "source": "dispatch-failed"} for c in judged]})
            break
        err = _log_seat_cost(root, task_id, s["backend"],
                             f"{COST_PURPOSE} {run_id} seat {seat} dispatch {did}", did)
        if err:
            res["cost_log_errors"].append({"seat": seat, "error": err})
        results = _collect(root, task_id, did, judged)
        _log_spend(root, task_id, rung, per_seat)
        res["dispatches"].append({"seat": seat, "backend": s["backend"], "dispatch_id": did,
                                  "results": results})
        # A panel is sequential and stops at the first seat that does not clear every criterion.
        if any(r["outcome"] != vl.GREEN for r in results):
            break

    # Seats no internal backend can fill: offer them to a paid backend, and WAIT. Never dispatched.
    stopped = any(d.get("error") or any(r["outcome"] != vl.GREEN for r in d["results"])
                  for d in res["dispatches"])
    for s in plan["unfilled"]:
        if stopped:
            break
        entry = {"seat": s["seat"], "results": [
            {"ac": c["ac_index"], "outcome": UNKNOWN, "source": "not-dispatched"} for c in judged]}
        if plan["paid"]:
            backend = plan["paid"][0]
            # No run id in `why`: a re-run for the same seat reuses the open proposal.
            why = (f"{task_id} AC#{','.join(str(c['ac_index']) for c in judged)}: rung {rung} "
                   f"({reason}) needs panel seat {s['seat']}; no internal backend can be "
                   f"dispatched for it")
            try:
                p = _propose_paid(root, task_id, backend, why, per_seat)
                status = ("awaiting-approval" if p.get("status", "pending") == "pending" else
                          "approved, not dispatched: the judge never dispatches a paid backend")
                entry.update(backend=backend, status=status, proposal_id=p["id"])
                res["proposals"].append({"seat": s["seat"], "backend": backend, "id": p["id"],
                                         "status": p.get("status", "pending")})
            except Exception as e:  # noqa: BLE001
                entry.update(backend=backend, status=f"proposal refused: {e}")
        else:
            entry["status"] = "no backend (internal or paid) can fill this seat"
        for r in entry["results"]:
            r["source"] = entry["status"]
        res["dispatches"].append(entry)
    res["outcomes"], res["why"] = _final(root, task_id, judged, res["dispatches"])
    res["code"] = 0
    return res


def _print_result(res: dict) -> None:
    print(f"Task: {res['task_id']}")
    print(f"Criteria: {len(res['criteria'])} REVIEWER_JUDGES")
    for o in res["operator_only"]:
        print(f"  operator-only (never dispatched): AC#{o['ac']} [{o['class']}]")
    print(f"Rung: {res['rung']} ({res['rung_reason']})")
    if res.get("degraded"):
        print(f"  {res['degraded']}: {', '.join(res.get('dispatchable') or []) or 'none'} of "
              f"{res['required_vendors']} vendors can be dispatched (T-3582); its verdict cannot "
              f"satisfy the criterion")
    for p in res.get("proposals") or []:
        print(f"  paid seat {p['seat']}: proposed {p['id']} on {p['backend']} ({p['status']}) - "
              f"waiting for the operator; not dispatched")
    for e in res.get("cost_log_errors") or []:
        print(f"  COST NOT LOGGED for seat {e['seat']}: {e['error']}")
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
              + (f" FAILED: {d['error']}" if d.get("error") else "")
              + (f" [{d['status']}]" if d.get("status") else ""))
        for r in d["results"]:
            print(f"  AC#{r['ac']}: {r['outcome']} ({r['source']}){' ' + r['flag'] if r.get('flag') else ''}")
    for ac, why in sorted((res.get("why") or {}).items()):
        print(f"  final AC#{ac}: {res['outcomes'][ac]} - {why}")


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
