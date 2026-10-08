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

SINGLE-VENDOR HONESTY. T-3582 made codex (openai), opencode (zai) and antigravity (google) real
worker kinds, so a rung-5 panel of claude + codex + opencode can be dispatched; a harness seat gets
a brief that asks it to PRINT its verdicts, which its runtime records (verdict_ledger
record_for_worker). When fewer kinds can be dispatched than the panel needs, the run registers all
three seats as required, dispatches the ones it can, proposes the paid alternative for the others,
and is reported "degraded: single-vendor panel"; the ledger refuses to let it satisfy the criterion. We chose "leave the criterion open" over "downgrade the requirement":
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

from lib import review_policy  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import (  # noqa: E402
    OPERATOR_ONLY,
    REVIEWER_JUDGES,
    human_criteria,
)

COST_LEDGER = review_policy.COST_LEDGER
EVIDENCE_DIR = Path(".context/working/judge-evidence")
REPORT_DIR = ".context/reviews/evidence"
CEILING_KEY = review_policy.CEILING_KEY
DEFAULT_CEILING = review_policy.DEFAULT_CEILING
RUNG_COST = review_policy.RUNG_COST
#: IW-7: a rung-5 panel is three reviewers from three different vendors. WHICH vendors is the
#: registry's business (policy/review-backends.yaml), not this module's.
PANEL_SIZE = review_policy.PANEL_SIZE
#: Screenshots taken per run. Pages beyond the cap are still REQUIRED: they are registered as
#: not captured, so the ledger refuses a render green (round 3: no silent truncation).
MAX_CAPTURE_PAGES = 6
DEGRADED_SINGLE_VENDOR = "degraded: single-vendor panel"
UNKNOWN = "unknown"
#: Seat outcomes that let a sequential panel go on to its next seat (T-3986).
_CLEARS = (vl.GREEN, vl.NOT_EVALUATED)
#: How many times the judge reassigns a not-evaluated criterion to other seat kinds before it
#: hands it to the operator (operator ruling 2026-10-07: fix → upstream → reassign → operator).
MAX_REASSIGN = 2
COST_PURPOSE = review_policy.SPEND_PURPOSE


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


def _log_seat_cost(root: Path, task_id: str, backend: str, purpose: str, evidence: str,
                   cost: float | None = None) -> str:
    """One cost record per dispatched seat via the helper. '' on success, else the refusal.
    `cost` is the seat's ESTIMATED USD (RUNG_COST); once committed, it is the spend the weekly
    ceiling reads (round 7: the cost ledger replaced the untracked judge-spend log)."""
    try:
        with _Env(root) as rc:
            rc.log_cost(task=task_id, backend=backend, purpose=purpose, tokens=None, cost=cost,
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


# ── rung (IW-7): lib/review_policy.py, the ONE implementation the ledger also enforces ────────


def _impact(task_data: dict, criteria: list[dict] | None = None) -> dict:
    """IW-7 impact over the task's frontmatter and the criteria under review (review_policy)."""
    return review_policy.impact(task_data.get("frontmatter") or {},
                                [c.get("body", "") for c in (criteria or [])])


def _calculate_rung(task_data: dict, criteria: list[dict] | None = None) -> tuple[int, str]:
    """IW-7: low -> rung 1, medium -> rung 3, high -> rung 5. Returns (rung, reason)."""
    return review_policy.required_rung(task_data.get("frontmatter") or {},
                                       [c.get("body", "") for c in (criteria or [])])


_config_value = review_policy.config_value
_ceiling = review_policy.ceiling
_weekly_spend = review_policy.weekly_spend
_apply_ceiling = review_policy.apply_ceiling
_rung_label = review_policy.rung_label


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
            f'--digest <DIGEST> --evidence <REPORT> --commit')
    # T-3940: `--commit` appends AND commits this row under the ledger lock, as
    # reviewer-$FW_SIDECAR_AGENT_ID. The old separate `git add .context/reviews && git commit
    # -- .context/reviews` step could not separate rows inside the ONE shared verdicts.jsonl:
    # a worker that committed first took the rows of workers still running (ring20's
    # permanent 'introduced by other' FAILs). T-3654's pathspec and T-3655's per-dispatch
    # email still hold — they now live in verdict_ledger._commit_rows.


def _build_brief(task_id: str, criteria: list[dict], *, rung: int = 1, rung_reason: str = "",
                 ceiling_note: str = "", evidence: dict | None = None, seat: str = "",
                 operator_only: list[dict] | None = None, run_id: str = "",
                 degraded: str = "", revision: str = "", kind: str = "") -> str:
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
        "- **not-evaluated:** you could NOT evaluate it (your sandbox could not run what it needs, "
        "you did not see the page, a tool failed). Say exactly why. This is not a verdict: it "
        "neither passes nor fails the criterion, which goes to a reviewer that can evaluate it.",
        "",
        "Never vote on what you did not see. A seat that could not evaluate and returns amber or "
        "red gives the operator a false judgement of work that may be perfectly good; return "
        "`not-evaluated` with the reason instead (operator ruling, T-3986).",
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
                             "page you did not see; the ledger refuses such a green. Return "
                             "`not-evaluated` for it, naming the pages you did not see.")
            lines.append("Cite EVERY screenshot above as `--evidence` (the copy in your report "
                         "directory); the ledger checks each required page's screenshot hash.")
        else:
            lines += [
                f"**SCREENSHOT CAPTURE FAILED: {ev['error'] or 'no screenshot captured'}.**",
                "You have NOT seen the rendered page. You MUST NOT return green on a page you "
                "did not see. Return `not-evaluated` (naming the capture failure) for every "
                "criterion that asks about rendering — not amber, not red.",
            ]
        if ev["pages"]:
            lines.append("Pages: " + ", ".join(f"`{p}`" for p in ev["pages"]))
        lines.append("")

    if kind in vl.HARNESS_KINDS:
        # T-3582: a harness reviewer (codex / opencode / antigravity) runs read-only in an export
        # of the reviewed revision. It prints; the dispatch runtime records what it printed.
        lines += [
            "## How your verdict is recorded",
            "",
            f"You review revision `{revision or 'the registered revision'}`. Your working directory is "
            "an export of exactly that revision (without `.context/`). Do NOT modify any file in "
            "it: it is fingerprinted, and a seat that changed it has none of its greens counted. "
            "Do not try to run `fw` or `git commit`: you need not.",
            "",
            "Scratch space: `$TMPDIR` is a writable directory of your own for this run (a test "
            "harness's temp files, a build cache). If what a criterion needs still cannot run, "
            "return `not-evaluated` with the reason — never a verdict on what you could not check.",
            "",
            "When you finish, the dispatch runtime records the verdicts you PRINT, under your own "
            "reviewer identity, with your full output as the evidence report, and signs your "
            "completion. Only the format below is read: a criterion you do not print exactly once, "
            "or print twice with different verdicts, gets no verdict at all.",
            "",
            "## Output format (printed — this IS your record)",
            "",
            "For each criterion print, starting at the beginning of a line:",
            "```",
            "N. [AC] <criterion short>",
            "VERDICT: green | amber | red | escalate | not-evaluated",
            "WHY: <what you checked, with evidence; why a human is needed; or why you could not evaluate>",
            "GUIDANCE: <what is needed next, mandatory for non-green>",
            "```",
            "N is the criterion number above (`### Criterion N`). End with: 'Summary: N green, M "
            "amber, K red, J escalate, I not-evaluated'. A green from a run that fails or times out "
            "does not count.",
        ]
        if operator_only:
            lines += ["", "Not yours (operator-only, never judge): " +
                      ", ".join(f"AC#{c['ac_index']}" for c in operator_only)]
        return "\n".join(lines)
    lines += [
        "## How you record your verdict (you write it; nobody writes it for you)",
        "",
        f"You review revision `{revision or '$FW_REVIEW_REVISION'}` (registered with your dispatch; "
        "your verdict is bound to it, not to whatever HEAD is when you record). Your dispatch id "
        "is `$FW_SIDECAR_AGENT_ID`. For EACH criterion above, in this order:",
        "",
        # T-3949 (832 7616ce48): <N> is the task's REAL Human AC number. With --criterion 3 the
        # only criterion is listed as "Criterion 1 (Human AC#3)"; a worker that used the local
        # position recorded its verdict on AC#1 — a green would have ticked the wrong criterion.
        "In every command below, `<N>` is the **Human AC number** (`Human AC#N` in the criterion "
        "heading), NOT the criterion's position in this brief:",
        "",
        *[f"- Criterion {c['index']} → `--ac {c['ac_index']}`" for c in criteria],
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
        "(mandatory unless green; for `not-evaluated` it is the reason you could not evaluate).",
        "",
        "   `record` does NOT sign anything. When you exit, the dispatch runtime signs your "
        "completion (your session, exit state, result stream and the exact rows you left). A row "
        "you did not leave by then never counts, and neither does a green if you exit non-zero.",
        "",
        "4. Do NOT run `git add` or `git commit` yourself: `record --commit` already committed "
        "exactly your row and its evidence, under your own identity, while holding the ledger "
        "lock. A separate commit would take other reviewers' rows and void them.",
        "",
        "Do not edit the task file, do not tick anything, do not touch any file outside "
        f"`{REPORT_DIR}/{task_id}/` and the ledger. Never use a bypass flag.",
        "",
        "## Output format (printed)",
        "",
        "After recording, print for each criterion:",
        "```",
        "N. [AC] <criterion short>",
        "VERDICT: green | amber | red | escalate | not-evaluated",
        "WHY: <what you checked, with evidence; why a human is needed; or why you could not evaluate>",
        "GUIDANCE: <what is needed next, mandatory for non-green>",
        "```",
        "End with: 'Summary: N green, M amber, K red, J escalate, I not-evaluated'. The printed "
        "text is for the "
        "operator's reading only; the ledger row is the record.",
    ]
    if operator_only:
        lines += ["", "Not yours (operator-only, never judge): " +
                  ", ".join(f"AC#{c['ac_index']}" for c in operator_only)]
    return "\n".join(lines)


# ── dispatch ─────────────────────────────────────────────────────────────────

Dispatcher = Callable[..., str]


def _dispatch_argv(fw: Path, *, task_id: str, name: str, prompt_file: Path, root: Path,
                   vendor: str, timeout: int, revision: str = "", run_id: str = "",
                   seat: str = "") -> list[str]:
    """The exact `fw termlink dispatch` argv: the wrapper takes --project (not --project-dir) and
    --worker-kind for the vendor. A vendor with no worker kind yet (codex/opencode, T-3582) makes
    the wrapper refuse loudly rather than silently run another vendor's worker."""
    argv = [str(fw), "termlink", "dispatch", "--name", name, "--task", task_id,
            "--task-type", "review", "--worker-kind", vendor, "--prompt-file", str(prompt_file),
            "--timeout", str(timeout), "--project", str(root)]
    if revision:
        argv += ["--review-revision", revision]
    if run_id:
        argv += ["--review-run", run_id, "--review-seat", seat]
    return argv


def _await_worker(fw: Path, did: str, root: Path, timeout: int) -> int:
    """Wait through `fw termlink wait`, which for a review dispatch returns only once the runtime
    has FINALISED it (completion signed or refused), not merely exited (round 4)."""
    r = subprocess.run([str(fw), "termlink", "wait", "--name", did, "--timeout", str(timeout)],
                       cwd=root, capture_output=True, text=True, timeout=timeout + 60)
    return r.returncode


def _dispatch_real(*, task_id: str, brief: str, root: Path, name: str, vendor: str,
                   timeout: int = 900, revision: str = "", run_id: str = "", seat: str = "") -> str:
    """Spawn the review worker via `fw termlink dispatch --task-type review`, wait for it, and
    return its dispatch id (the wrapper appends a random suffix and registers it)."""
    fw = Path(os.environ.get("FRAMEWORK_ROOT") or root) / "bin" / "fw"
    pf = root / ".context/working" / f"judge-brief-{name}.md"
    pf.parent.mkdir(parents=True, exist_ok=True)
    pf.write_text(brief)
    r = subprocess.run(_dispatch_argv(fw, task_id=task_id, name=name, prompt_file=pf, root=root,
                                      vendor=vendor, timeout=timeout, revision=revision,
                                      run_id=run_id, seat=seat),
                       cwd=root, capture_output=True, text=True, timeout=120)
    m = re.search(r"Worker spawned:\s*(\S+)", r.stdout)
    if r.returncode != 0 or not m:
        raise RuntimeError(f"dispatch failed (exit {r.returncode}): {(r.stderr or r.stdout)[-300:]}")
    did = m.group(1)
    _await_worker(fw, did, root, timeout)
    return did


def _dispatch_reviewer(task_id: str, brief: str, rung: int, dry_run: bool, root: Path,
                       dispatcher: Dispatcher | None = None, name: str | None = None,
                       vendor: str = "", revision: str = "", run_id: str = "",
                       seat: str = "") -> str | None:
    if dry_run:
        return None
    if not vendor:
        raise ValueError("no worker kind: the registry's seat backend names none")
    dispatcher = dispatcher or _dispatch_real
    return dispatcher(task_id=task_id, brief=brief, root=root, vendor=vendor, revision=revision,
                      name=name or f"judge-{task_id.lower()}-r{rung}", run_id=run_id, seat=seat)


# ── reading the result: the ledger is authoritative ──────────────────────────

_VERDICT_LINE = re.compile(r"^\s*(\d+)\.\s*\[[^\]]*\].*?\n\s*VERDICT:\s*([\w-]+)", re.M)


def _parse_printed(output: str, criteria: list[dict]) -> dict[int, str]:
    """Printed verdict per criterion `index`, for REPORTING only. Anything not exactly one
    of the outcomes (vl.OUTCOMES) is `unknown`."""
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
        # T-3986: the last seat that EVALUATED decides; not-evaluated seats only report.
        evaluated = [r for r in seat_res if r["outcome"] != vl.NOT_EVALUATED]
        last = (evaluated or seat_res or [{"outcome": UNKNOWN, "why": "no seat was dispatched"}])[-1]
        if last["outcome"] in _CLEARS:
            good, why = (vl.satisfying_verdict(ctx, crits[c["ac_index"]])
                         if ctx and c["ac_index"] in crits else (None, "criterion gone"))
            outcomes[c["ac_index"]] = (vl.GREEN if good else
                                       vl.NOT_EVALUATED if why.startswith("not-evaluated") else UNKNOWN)
            if not good:
                whys[c["ac_index"]] = why
        else:
            outcomes[c["ac_index"]] = last["outcome"]
            if last.get("why"):
                whys[c["ac_index"]] = last["why"]
    return outcomes, whys


# ── orchestration ────────────────────────────────────────────────────────────

def _plan_seats(root: Path, rung: int, kinds: set[str], kind_vendors: dict | None = None,
                exclude_kinds: set[str] | frozenset = frozenset()) -> dict:
    """Which registry backends sit this run. {'seats': [...], 'required': N, 'dispatch': [...],
    'unfilled': [...], 'paid': [...]} — seats are {'seat', 'vendor', 'backend', 'kind'}.
    `exclude_kinds` (T-3986): worker kinds that could not evaluate this criterion in an earlier
    run; the reassigned run seats other kinds."""
    seat_backends, paid = _backends(root)
    seat_backends = [b for b in seat_backends if b["kind"] not in exclude_kinds]
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
          kind_vendors: dict | None = None,
          exclude_kinds: set[str] | frozenset = frozenset()) -> dict:
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

    # The SAME policy the ledger enforces at record and apply (round 6): the due rung, and — when
    # the weekly ceiling steps it down — the decision. This is a PREVIEW: the ledger computes the
    # binding decision itself when it registers the run (round 7) and refuses a mismatch.
    imp = _impact(task_data, judged)
    # Round 8 (codex 2): THE requirement the ledger enforces at registration, record and apply —
    # history-aware (every committed version of the task file, and HEAD, the revision this run
    # will review) — not the current frontmatter alone.
    revision = vl._head_sha(root)
    try:
        due, reason = vl.task_required_strength(root, task_id, [c.get("body", "") for c in judged],
                                                task_data.get("text") or "", revision)
    except vl.HistoryUnreadable as e:
        res.update(error=str(e), code=1)
        return res
    decision = review_policy.ceiling_decision(root, due, reason, now)
    rung, note = decision["granted"], decision["note"]
    spent, ceiling = decision["spent"], decision["ceiling"]
    res.update(rung_due=due, rung=rung, rung_reason=reason, ceiling_note=note,
               impact=imp, weekly_spend=spent, ceiling=ceiling)

    try:
        plan = _plan_seats(root, rung,
                           _dispatchable_kinds(root) if worker_kinds is None else set(worker_kinds),
                           _kind_vendors(root) if kind_vendors is None else dict(kind_vendors),
                           exclude_kinds=set(exclude_kinds))
    except Exception as e:  # noqa: BLE001 - an unreadable registry is a refusal, not a default
        res.update(error=f"review backend registry unavailable: {e}", code=1)
        return res
    seats, required = plan["seats"], plan["required"]
    degraded = (DEGRADED_SINGLE_VENDOR if rung >= 5 and (len(plan["dispatch"]) < required
                                                         or len(plan["vendors"]) < required) else "")
    res.update(seats=[s["seat"] for s in seats], dispatchable=[s["seat"] for s in plan["dispatch"]],
               unfilled=[s["seat"] for s in plan["unfilled"]], required_vendors=required,
               dispatch_vendors=plan["vendors"], degraded=degraded)

    # The revision under review is captured above, before any worker exists, and handed to the
    # dispatcher, which registers it with the dispatch (round 3).
    res["revision"] = revision
    evidence = _gather_evidence(root, task_id, task_data, judged, capture or _capture_playwright,
                                dry_run=dry_run)
    res["evidence"] = evidence
    run_id = f"run-{task_id.lower()}-{uuid.uuid4().hex[:10]}"
    briefs = {s["seat"]: _build_brief(task_id, judged, rung=rung, rung_reason=reason,
                                      ceiling_note=note, evidence=evidence,
                                      seat=s["seat"] if rung >= 5 else "", operator_only=operator,
                                      run_id=run_id, degraded=degraded, revision=revision,
                                      kind=s.get("kind", ""))
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
            seats=[{"seat": s["seat"], "vendor": s["vendor"],
                    "brief_sha256": vl.brief_digest(briefs[s["seat"]])} for s in seats],
            required_vendors=required,
            pages={str(c["ac_index"]): evidence["pages"] for c in judged if c["render"]},
            captures=evidence["captures"],
            inputs=imp["inputs"], reason=reason + (f"; {note}" if note else ""),
            degraded=degraded, rung_due=due, revision=revision, root=root)
    except Exception as e:  # noqa: BLE001
        res.update(error=f"could not register the review run: {e}", code=1)
        return res
    res["run_id"] = run_id

    res["dispatches"], res["cost_log_errors"], res["proposals"] = [], [], []
    per_seat = RUNG_COST.get(rung, 2.0) / (PANEL_SIZE if rung >= 5 else 1)
    for s in plan["dispatch"]:
        seat = s["seat"]
        try:
            # Round 6: the dispatch is bound to its run and seat AT REGISTRATION, before the
            # worker launches — the dispatcher registers run + seat with the signed dispatch.
            did = _dispatch_reviewer(
                task_id, briefs[seat], rung, False, root, dispatcher,
                name=f"judge-{task_id.lower()}-r{rung}" + (f"-{seat}" if rung >= 5 else ""),
                vendor=s["kind"], revision=revision, run_id=run_id, seat=seat)
        except Exception as e:  # noqa: BLE001
            res["dispatches"].append({"seat": seat, "error": str(e), "results": [
                {"ac": c["ac_index"], "outcome": UNKNOWN, "source": "dispatch-failed"} for c in judged]})
            break
        err = _log_seat_cost(root, task_id, s["backend"],
                             f"{COST_PURPOSE} {run_id} seat {seat} dispatch {did}", did, per_seat)
        if err:
            res["cost_log_errors"].append({"seat": seat, "error": err})
        results = _collect(root, task_id, did, judged)
        res["dispatches"].append({"seat": seat, "backend": s["backend"], "kind": s["kind"],
                                  "dispatch_id": did, "results": results})
        # A panel is sequential and stops at the first seat that does not clear every criterion.
        # T-3986: a seat that could not evaluate does not stop it — the next seat may evaluate.
        if any(r["outcome"] not in _CLEARS for r in results):
            break

    # Seats no internal backend can fill: offer them to a paid backend, and WAIT. Never dispatched.
    stopped = any(d.get("error") or any(r["outcome"] not in _CLEARS for r in d["results"])
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


def _not_evaluated_kinds(res: dict, ac: int) -> set[str]:
    """Worker kinds whose seat in `res` returned not-evaluated for Human AC#`ac`."""
    return {d.get("kind", "") for d in res.get("dispatches") or [] for r in d.get("results") or []
            if r["ac"] == ac and r["outcome"] == vl.NOT_EVALUATED and d.get("kind")}


def judge_with_reassign(task_id: str, root: Path, **kw) -> dict:
    """`judge`, then the operator's ladder for a criterion no seat could evaluate (T-3986):
    reassign it — a new run, per criterion, that seats no worker kind which could not evaluate
    it — up to MAX_REASSIGN times; whatever is still not-evaluated after that is the operator's,
    with the reasons. A not-evaluated seat never becomes amber or red on the way."""
    res = judge(task_id, root, **kw)
    if kw.get("dry_run") or res.get("error") or not res.get("outcomes"):
        return res
    res["reassigned"] = []
    for ac, outcome in list(res["outcomes"].items()):
        if outcome != vl.NOT_EVALUATED:
            continue
        excluded = _not_evaluated_kinds(res, ac)
        # No kind of THIS run said not-evaluated (the ledger's not-evaluated came from an older
        # run): an identical re-run would learn nothing, so it is not reassigned blind.
        for _ in range(MAX_REASSIGN if excluded else 0):
            sub = judge(task_id, root, **{**kw, "criterion_n": ac, "exclude_kinds": set(excluded)})
            step = {"ac": ac, "excluded": sorted(excluded), "run_id": sub.get("run_id", ""),
                    "outcome": (sub.get("outcomes") or {}).get(ac, UNKNOWN),
                    "why": sub.get("error") or (sub.get("why") or {}).get(ac, "")}
            res["reassigned"].append(step)
            res.setdefault("dispatches", []).extend(sub.get("dispatches") or [])
            if sub.get("error"):
                break
            res["outcomes"][ac] = step["outcome"]
            if step["why"]:
                res.setdefault("why", {})[ac] = step["why"]
            else:
                (res.get("why") or {}).pop(ac, None)
            if step["outcome"] != vl.NOT_EVALUATED:
                break
            new = _not_evaluated_kinds(sub, ac) - excluded
            if not new:
                break
            excluded |= new
        # Still not evaluated, or the reassigned run could not seat a panel at all: the last rung
        # of the ladder. An evaluating amber/red from a reassigned seat is a real verdict and
        # takes the normal path instead.
        if res["outcomes"][ac] in (vl.NOT_EVALUATED, UNKNOWN):
            res.setdefault("why", {})[ac] = (
                f"OPERATOR: no seat kind could evaluate this criterion (reassigned excluding "
                f"{', '.join(sorted(excluded)) or 'nothing'}) — "
                f"{res.get('why', {}).get(ac, '') or 'no evaluating verdict'}")
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
    for st in res.get("reassigned") or []:
        print(f"  reassigned AC#{st['ac']} (excluding {', '.join(st['excluded']) or 'none'}): "
              f"{st['outcome']}{' - ' + st['why'] if st['why'] else ''}")
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

    res = judge_with_reassign(args.task_id, _root(), criterion_n=args.criterion,
                              dry_run=args.dry_run, dispatcher=dispatcher, capture=capture)
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
