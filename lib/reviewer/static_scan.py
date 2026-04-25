"""Static-scan reviewer (T-1443 v1.0).

Detects anti-patterns in completed task files. v1.0 scope:
- 4 seed patterns: tautology, empty-body, swallowed-errors, output-spoofing
- Verdict written to task body under `## Reviewer Verdict (v1.0)`
- Append-only feedback stream at `.context/working/feedback-stream.yaml`
- Sovereignty: NEVER modifies AC checkboxes (### Human or ### Agent)

Wired in v1.0:
- `bin/fw reviewer T-XXX` (manual)
- `update-task.sh --status work-completed` (auto, post-verification, non-blocking)

NOT in v1.0 (deferred):
- Layer 1/2 escalation (v1.1)
- Per-AC granular verdicts (v1.3)
- Override mechanism enforcement (v2.1)
- Orchestrator routing (v3+)
"""

from __future__ import annotations

import json
import os
import re
import sys
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

import yaml

VERSION = "v1.0"
SCHEMA_VERSION = 1


# ───────────────────────── Data classes ─────────────────────────


@dataclass
class Finding:
    pattern_id: str
    pattern_name: str
    detection_confidence: str
    lie_severity: str
    location: str  # e.g. "Verification:line 3" or "AC#2 (Agent)"
    evidence: str  # the offending line, trimmed

    def to_dict(self) -> dict:
        return {
            "pattern_id": self.pattern_id,
            "pattern_name": self.pattern_name,
            "detection_confidence": self.detection_confidence,
            "lie_severity": self.lie_severity,
            "location": self.location,
            "evidence": self.evidence,
        }


@dataclass
class Verdict:
    task_id: str
    scan_id: str
    timestamp: str
    overall: str  # PASS | CONCERN | FAIL
    findings: list[Finding] = field(default_factory=list)
    catalogue_version: str = ""

    def to_dict(self) -> dict:
        return {
            "task_id": self.task_id,
            "scan_id": self.scan_id,
            "timestamp": self.timestamp,
            "overall": self.overall,
            "catalogue_version": self.catalogue_version,
            "findings": [f.to_dict() for f in self.findings],
        }


# ───────────────────────── Catalogue loading ─────────────────────────


def load_catalogue(catalogue_path: Path) -> dict:
    with open(catalogue_path) as fh:
        return yaml.safe_load(fh)


# ───────────────────────── Section extractors ─────────────────────────

_SECTION_RE = re.compile(r"^## ", re.MULTILINE)


def extract_section(body: str, name: str) -> str | None:
    """Extract `## {name}` section content (until next `## ` or EOF)."""
    pattern = re.compile(rf"^## {re.escape(name)}\s*\n(.*?)(?=^## |\Z)", re.MULTILINE | re.DOTALL)
    match = pattern.search(body)
    return match.group(1) if match else None


def parse_task_file(task_path: Path) -> tuple[dict, str]:
    """Return (frontmatter_dict, body_str)."""
    text = task_path.read_text()
    if not text.startswith("---"):
        return {}, text
    try:
        _, fm, body = text.split("---", 2)
    except ValueError:
        return {}, text
    try:
        meta = yaml.safe_load(fm) or {}
    except yaml.YAMLError:
        meta = {}
    return meta, body.lstrip("\n")


# ───────────────────────── Detectors ─────────────────────────


_TAUTOLOGY_PATTERNS = [
    re.compile(r"^\s*true\s*(?:#.*)?$"),
    re.compile(r"^\s*:\s*(?:#.*)?$"),
    re.compile(r"^\s*\[\s*1\s*[-=]eq\s*1\s*\](?:\s*#.*)?$"),
    re.compile(r"^\s*\[\s*1\s*=\s*1\s*\](?:\s*#.*)?$"),
    re.compile(r".*&&\s*true\s*(?:#.*)?$"),
    re.compile(r"^\s*echo\s+['\"][^'\"]*['\"]\s*$"),  # echo without piping/comparing
]


def detect_tautology(verification_section: str) -> list[Finding]:
    findings: list[Finding] = []
    if not verification_section:
        return findings
    for lineno, raw in enumerate(verification_section.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        for pat in _TAUTOLOGY_PATTERNS:
            if pat.match(line):
                findings.append(
                    Finding(
                        pattern_id="tautology",
                        pattern_name="Tautological verification",
                        detection_confidence="deterministic",
                        lie_severity="severe",
                        location=f"Verification:line {lineno}",
                        evidence=line[:200],
                    )
                )
                break
    return findings


_EMPTY_BODY_MARKERS = {
    "[first criterion]",
    "[second criterion]",
    "[third criterion]",
    "[criterion]",
    "todo",
    "tbd",
    "...",
    "n/a",
    "...",
    "fill in",
    "placeholder",
}

_AC_LINE_RE = re.compile(r"^\s*-\s*\[(?P<state>[ xX])\]\s*(?P<body>.*?)\s*$")


def _ac_body_is_empty(body: str) -> bool:
    """Return True if the AC body is a placeholder, not real content."""
    stripped = body.strip()
    if not stripped:
        return True
    # strip optional [REVIEW] / [RUBBER-STAMP] prefix
    stripped = re.sub(r"^\[(REVIEW|RUBBER-STAMP)\]\s*", "", stripped, flags=re.IGNORECASE)
    if not stripped:
        return True
    # markdown-only / punctuation-only
    if re.fullmatch(r"[\-\.\*\s_]+", stripped):
        return True
    # known placeholder strings (case-insensitive, exact match after stripping)
    if stripped.lower() in _EMPTY_BODY_MARKERS:
        return True
    return False


def detect_empty_body(ac_section: str) -> list[Finding]:
    findings: list[Finding] = []
    if not ac_section:
        return findings
    current_subhead = "ACs"
    counter = 0
    for raw in ac_section.splitlines():
        if raw.strip().startswith("### "):
            current_subhead = raw.strip().lstrip("# ").strip()
            counter = 0
            continue
        m = _AC_LINE_RE.match(raw)
        if not m:
            continue
        counter += 1
        body = m.group("body")
        if _ac_body_is_empty(body):
            findings.append(
                Finding(
                    pattern_id="empty-body",
                    pattern_name="Empty acceptance-criterion body",
                    detection_confidence="deterministic",
                    lie_severity="severe",
                    location=f"AC#{counter} ({current_subhead})",
                    evidence=raw.strip()[:200],
                )
            )
    return findings


_SWALLOWED_PATTERNS = [
    (re.compile(r"--no-verify\b"), "--no-verify on git commit/push"),
    (re.compile(r"--no-gpg-sign\b"), "signing bypass"),
    (re.compile(r"\|\|\s*true\s*$"), "|| true at end of line"),
    (re.compile(r"2>/dev/null\s*\|\|\s*true\s*$"), "2>/dev/null || true"),
    (re.compile(r"^\s*set\s+\+e\s*$"), "set +e (errors disabled)"),
]


def detect_swallowed_errors(verification_section: str) -> list[Finding]:
    findings: list[Finding] = []
    if not verification_section:
        return findings
    for lineno, raw in enumerate(verification_section.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        for pat, _label in _SWALLOWED_PATTERNS:
            if pat.search(line):
                findings.append(
                    Finding(
                        pattern_id="swallowed-errors",
                        pattern_name="Errors swallowed or hooks bypassed",
                        detection_confidence="deterministic",
                        lie_severity="severe",
                        location=f"Verification:line {lineno}",
                        evidence=line[:200],
                    )
                )
                break
    return findings


_SUCCESS_TOKEN_RE = re.compile(
    r"\b(TESTS\s+PASS|BUILD\s+OK|ALL\s+GREEN|SUCCESS|PASSED|OK)\b",
    re.IGNORECASE,
)
_ECHO_PRINTF_RE = re.compile(r"^\s*(echo|printf)\s+", re.IGNORECASE)


def detect_output_spoofing(verification_section: str) -> list[Finding]:
    """Heuristic: lines that print a success token without a real assertion.

    Conservative — only flags lines where echo/printf produces a success token
    AND the line is not piped into grep/test/awk/etc. (which would constitute
    a real assertion).
    """
    findings: list[Finding] = []
    if not verification_section:
        return findings
    for lineno, raw in enumerate(verification_section.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if not _ECHO_PRINTF_RE.match(line):
            continue
        if not _SUCCESS_TOKEN_RE.search(line):
            continue
        # If the echo/printf is piped into a real verifier, do not flag.
        if re.search(r"\|\s*(grep|awk|sed|test|cmp|diff|jq)\b", line):
            continue
        # If followed by a real check on same line (e.g. && grep ...), skip.
        if re.search(r"&&\s*(grep|test|cmp|diff|jq|\[)", line):
            continue
        findings.append(
            Finding(
                pattern_id="output-spoofing",
                pattern_name="Output-spoofing success markers",
                detection_confidence="heuristic",
                lie_severity="partial",
                location=f"Verification:line {lineno}",
                evidence=line[:200],
            )
        )
    return findings


# ───────────────────────── Orchestration ─────────────────────────


def compute_overall(findings: list[Finding], thresholds: dict) -> str:
    fail_on = set(thresholds.get("fail_on_severities", ["complete", "severe"]))
    concern_on = set(thresholds.get("concern_on_severities", ["partial", "narrow", "staleness"]))
    if not findings:
        return "PASS"
    severities = {f.lie_severity for f in findings}
    if severities & fail_on:
        return "FAIL"
    if severities & concern_on:
        return "CONCERN"
    return "PASS"


def scan_task(task_path: Path, catalogue: dict) -> Verdict:
    _meta, body = parse_task_file(task_path)
    ac_section = extract_section(body, "Acceptance Criteria") or ""
    verif_section = extract_section(body, "Verification") or ""

    findings: list[Finding] = []
    findings.extend(detect_tautology(verif_section))
    findings.extend(detect_empty_body(ac_section))
    findings.extend(detect_swallowed_errors(verif_section))
    findings.extend(detect_output_spoofing(verif_section))

    overall = compute_overall(findings, catalogue.get("verdict_thresholds", {}))

    task_id = task_path.stem.split("-")[0] + "-" + task_path.stem.split("-")[1]
    return Verdict(
        task_id=task_id,
        scan_id=f"R-{uuid.uuid4().hex[:8]}",
        timestamp=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        overall=overall,
        findings=findings,
        catalogue_version=catalogue.get("catalogue_version", "unknown"),
    )


# ───────────────────────── Verdict rendering ─────────────────────────

VERDICT_HEADER = f"## Reviewer Verdict ({VERSION})"
_VERDICT_SECTION_RE = re.compile(
    rf"^{re.escape(VERDICT_HEADER)}\s*\n(.*?)(?=^## |\Z)",
    re.MULTILINE | re.DOTALL,
)


def render_verdict_md(verdict: Verdict) -> str:
    lines = [
        VERDICT_HEADER,
        "",
        f"- **Scan ID:** {verdict.scan_id}",
        f"- **Timestamp:** {verdict.timestamp}",
        f"- **Catalogue:** {verdict.catalogue_version}",
        f"- **Overall:** {verdict.overall}",
    ]
    if verdict.findings:
        lines.append(f"- **Findings:** {len(verdict.findings)}")
        lines.append("")
        for i, f in enumerate(verdict.findings, start=1):
            lines.append(
                f"  {i}. **{f.pattern_id}** ({f.lie_severity}, {f.detection_confidence}) "
                f"@ {f.location}"
            )
            lines.append(f"     - evidence: `{f.evidence}`")
    else:
        lines.append("- **Findings:** none")
    lines.append("")
    return "\n".join(lines)


def write_verdict_to_task(task_path: Path, verdict: Verdict) -> None:
    """Replace existing `## Reviewer Verdict (v1.0)` section, or append.

    Sovereignty invariant: this function ONLY touches the verdict section.
    It must not modify AC checkboxes or any other section.
    """
    text = task_path.read_text()
    new_section = render_verdict_md(verdict)

    if _VERDICT_SECTION_RE.search(text):
        new_text = _VERDICT_SECTION_RE.sub(new_section, text)
    else:
        # append before final newline
        sep = "" if text.endswith("\n") else "\n"
        new_text = text + sep + "\n" + new_section

    task_path.write_text(new_text)


# ───────────────────────── Feedback stream ─────────────────────────


def append_feedback_event(stream_path: Path, event: dict) -> None:
    """Append-only event log. Each event is a YAML doc separated by `---`.

    v1.0 events:
      - kind: scan_emitted     (reviewer ran)
      - kind: verdict_recorded (verdict written to task)

    v2.1+ adds: override_requested, override_revoked, override_expired.
    """
    stream_path.parent.mkdir(parents=True, exist_ok=True)
    if not stream_path.exists():
        header = (
            "# Reviewer feedback stream (T-1443 v1.0, Spike I)\n"
            "# Append-only. Events separated by ---.\n"
            "# Schema: kind, timestamp, scan_id, task_id, payload\n"
        )
        stream_path.write_text(header)
    with open(stream_path, "a") as fh:
        fh.write("---\n")
        yaml.safe_dump(event, fh, sort_keys=False)


# ───────────────────────── CLI entry ─────────────────────────


def find_task_file(project_root: Path, task_id: str) -> Path | None:
    for sub in ("active", "completed"):
        for candidate in (project_root / ".tasks" / sub).glob(f"{task_id}-*.md"):
            return candidate
    return None


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    if not argv or argv[0] in {"-h", "--help"}:
        print(
            "Usage: python -m lib.reviewer.static_scan <T-XXX> [--json] [--no-write]\n"
            "  Scans the named task for v1.0 anti-patterns and writes verdict.\n"
            "  --json      emit machine-readable verdict on stdout\n"
            "  --no-write  do not modify the task file or feedback stream",
            file=sys.stderr,
        )
        return 2

    task_id = argv[0]
    emit_json = "--json" in argv
    no_write = "--no-write" in argv

    project_root = Path(os.environ.get("PROJECT_ROOT") or os.getcwd())
    framework_root = Path(os.environ.get("FRAMEWORK_ROOT") or project_root)

    catalogue_path = framework_root / "policy" / "anti-patterns.yaml"
    if not catalogue_path.exists():
        # fall back to project-local for vendored consumers
        catalogue_path = project_root / "policy" / "anti-patterns.yaml"
    if not catalogue_path.exists():
        print(f"ERROR: catalogue not found at {catalogue_path}", file=sys.stderr)
        return 3

    task_file = find_task_file(project_root, task_id)
    if not task_file:
        print(f"ERROR: task file for {task_id} not found under {project_root}/.tasks/", file=sys.stderr)
        return 4

    catalogue = load_catalogue(catalogue_path)
    verdict = scan_task(task_file, catalogue)

    if not no_write:
        write_verdict_to_task(task_file, verdict)
        stream = project_root / ".context" / "working" / "feedback-stream.yaml"
        append_feedback_event(
            stream,
            {
                "kind": "scan_emitted",
                "timestamp": verdict.timestamp,
                "scan_id": verdict.scan_id,
                "task_id": verdict.task_id,
                "payload": {
                    "overall": verdict.overall,
                    "finding_count": len(verdict.findings),
                    "catalogue_version": verdict.catalogue_version,
                },
            },
        )
        append_feedback_event(
            stream,
            {
                "kind": "verdict_recorded",
                "timestamp": verdict.timestamp,
                "scan_id": verdict.scan_id,
                "task_id": verdict.task_id,
                "payload": {"task_file": str(task_file.relative_to(project_root))},
            },
        )

    if emit_json:
        print(json.dumps(verdict.to_dict(), indent=2))
    else:
        print(render_verdict_md(verdict))

    # exit code semantics: 0 PASS/CONCERN, 1 FAIL (informational; v1.0 is non-blocking)
    return 0 if verdict.overall != "FAIL" else 1


if __name__ == "__main__":
    sys.exit(main())
