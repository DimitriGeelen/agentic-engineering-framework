"""T-1632 (B-3c of T-1626) — Watchtower /hooks page.

Surfaces per-hook fire/failure telemetry (T-1628) and threshold-rule
state (T-1631) on a dedicated page. Operator-friendly view of the
immune-system loop's evidence: which hooks are firing, which are
failing, which are over threshold.

Data sources:
  - .context/working/.hook-counter        (T-1628 — total fires)
  - .context/working/.hook-failure-counter (T-1628 — non-clean exits)

Threshold logic delegated to lib/hook-threshold.py via subprocess
so the rule is owned in exactly one place (single source of truth
across audit, register, and UI). Subprocess overhead is fine for a
human-pageload route.
"""

import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("hooks", __name__)


_HOOK_LINE_RE = re.compile(r"^([A-Za-z0-9_:.\-]+)=(\d+)\s*$")


def _read_counter(path: Path) -> dict[str, int]:
    """Sum counts per key; defensive against duplicates (T-1628 race)."""
    counts: dict[str, int] = defaultdict(int)
    if not path.is_file():
        return counts
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return counts
    for line in text.splitlines():
        m = _HOOK_LINE_RE.match(line)
        if m:
            counts[m.group(1)] += int(m.group(2))
    return counts


def _scan_via_helper() -> dict[str, str]:
    """Invoke lib/hook-threshold.py --all to learn which hooks are over
    threshold. Returns {hookname: 'FAIL'|'ok'}.

    Subprocess so the threshold rule lives in exactly one place
    (T-1631). If the helper is unreachable, fall back to {} (page
    still renders without threshold flags).
    """
    framework_root = Path(__file__).resolve().parents[2]
    helper = framework_root / "lib" / "hook-threshold.py"
    if not helper.is_file():
        return {}
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(PROJECT_ROOT)
    try:
        proc = subprocess.run(
            [sys.executable, str(helper), "--all", "--project-root", str(PROJECT_ROOT)],
            capture_output=True,
            text=True,
            timeout=5,
            env=env,
        )
    except (subprocess.TimeoutExpired, OSError):
        return {}
    out = {}
    for line in proc.stdout.splitlines():
        parts = line.split("|")
        if len(parts) >= 2 and parts[0] in ("FAIL", "ok"):
            out[parts[1]] = parts[0]
    return out


@bp.route("/hooks")
def hooks_page():
    """Per-hook telemetry and threshold dashboard."""
    fires = _read_counter(PROJECT_ROOT / ".context" / "working" / ".hook-counter")
    failures = _read_counter(PROJECT_ROOT / ".context" / "working" / ".hook-failure-counter")
    triggered = _scan_via_helper()

    rows = []
    for hook in sorted(set(fires) | set(failures)):
        total = fires.get(hook, 0)
        fails = failures.get(hook, 0)
        ratio = (fails / total) if total > 0 else 0.0
        status = triggered.get(hook, "ok")
        rows.append({
            "name": hook,
            "fires": total,
            "failures": fails,
            "ratio_pct": f"{ratio * 100:.1f}",
            "ratio_raw": ratio,
            "status": status,
        })

    rows.sort(key=lambda r: (
        0 if r["status"] == "FAIL" else 1,
        -r["failures"],
        r["name"],
    ))

    total_fires = sum(r["fires"] for r in rows)
    total_failures = sum(r["failures"] for r in rows)
    failing_count = sum(1 for r in rows if r["status"] == "FAIL")
    overall_ratio = (total_failures / total_fires * 100) if total_fires > 0 else 0.0

    min_fires = int(os.environ.get("FW_HOOK_THRESHOLD_MIN_FIRES", "20"))
    fail_ratio = float(os.environ.get("FW_HOOK_THRESHOLD_FAIL_RATIO", "0.10"))

    return render_page(
        "hooks.html",
        page_title="Hook Telemetry",
        rows=rows,
        total_hooks=len(rows),
        total_fires=total_fires,
        total_failures=total_failures,
        failing_count=failing_count,
        overall_ratio=f"{overall_ratio:.2f}",
        min_fires=min_fires,
        fail_ratio_pct=f"{fail_ratio * 100:.0f}",
    )
