"""T-5423: split the orchestrator MCP scan's warnings into one audit line per class.

agents/audit/orchestrator-mcp-scan.sh writes `warnings:` in
.context/audits/orchestrator-LATEST.yaml as a YAML list whose entries wrap over
several lines. The audit used to read it with `awk | head -1`, which took a fragment
of the first entry, and picked the title by grepping that text for TAG-FORMAT-DRIFT.
050-email-archive saw the tag-format title printed above tool-classification evidence.

Each entry starts with its class (`NEW:`, `RATCHET:`, `REMOVED:`, `TAG-FORMAT-DRIFT:`).
This prints one tab-separated line per entry: title, evidence, mitigation. Usage:

    python3 lib/orchestrator_warnings.py <orchestrator-LATEST.yaml>

Exit 0 always; an unreadable or malformed file prints one line saying so.
"""
from __future__ import annotations

import sys

CLASSES = {
    "TAG-FORMAT-DRIFT": (
        "Orchestrator-arc tag-format drift: live sessions carry non-canonical prefixes",
        "Fix at source: update spawn callers (see /orchestrator) or add validator (T-1649 cross-repo half)"),
    "NEW": (
        "Orchestrator-arc MCP scan: unclassified TermLink tool(s)",
        "Classify them in .context/audits/orchestrator-mcp-baseline.yaml (manual review, outside T-1761 convention)"),
    "RATCHET": (
        "Orchestrator-arc MCP scan: mutator(s) gained a governance gate",
        "Move them from mutators_ungated to gated in .context/audits/orchestrator-mcp-baseline.yaml"),
    "REMOVED": (
        "Orchestrator-arc MCP scan: tool(s) gone from TermLink",
        "Remove them from .context/audits/orchestrator-mcp-baseline.yaml if the removal is intended"),
}
OTHER = ("Orchestrator-arc MCP scan: drift detected",
         "Update .context/audits/orchestrator-mcp-baseline.yaml or investigate ratchet/new-tool")


def lines_for(warnings) -> list[tuple[str, str, str]]:
    """(title, evidence, mitigation) per warning entry, in scan order."""
    out = []
    for w in warnings or []:
        text = " ".join(str(w).split())
        cls = text.split(":", 1)[0].strip()
        title, fix = CLASSES.get(cls, OTHER)
        out.append((title, text, fix))
    return out


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(f"{OTHER[0]}\tno orchestrator LATEST path given\t{OTHER[1]}")
        return 0
    try:
        import yaml
        with open(argv[1], encoding="utf-8") as fh:
            doc = yaml.safe_load(fh) or {}
        warnings = doc.get("warnings") or []
    except Exception as exc:  # noqa: BLE001 — the audit line must still appear
        print(f"{OTHER[0]}\tcould not read {argv[1]}: {type(exc).__name__}\t{OTHER[1]}")
        return 0
    rows = lines_for(warnings)
    if not rows:
        print(f"{OTHER[0]}\tscan exited 1 but listed no warnings (see {argv[1]})\t{OTHER[1]}")
    for title, evidence, fix in rows:
        print(f"{title}\t{evidence.replace(chr(9), ' ')}\t{fix}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
