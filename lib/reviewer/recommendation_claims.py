#!/usr/bin/env python3
"""
T-100187: Recommendation-claims validator (T-100186 GO slice A).

Extracts verifiable evidence claims from an inception task's ## Recommendation
section (including its Evidence bullets), verifies each mechanically and
read-only, and writes a `## Recommendation Verdict` block into the task body
via the reviewer's atomic write path.

Claim types (reuses the ships_in referent grammar, T-1984):
  - file       `path/to/file.ext`      → exists at PROJECT_ROOT
  - file_line  `path/to/file.ext:123`  → exists AND line within range
  - task       `T-XXX`                 → task file in .tasks/{active,completed}/
  - module     `module.function`       → symbol grepped in lib/ agents/ bin/

Extraction sources: backticked spans for path/module claims (high precision —
prose tokens like "e.g." never match), bare `T-XXX` references anywhere in the
section. URLs and the task's own id are skipped.

Overall verdict:
  CONFIRMED     — ≥1 claim, all verifiable claims pass
  CONTRADICTED  — ≥1 claim fails
  UNVERIFIED    — no claims extracted, or none verifiable

Advisory only (invariants pinned by tests/unit/test_recommendation_claims.py):
  - never modifies ## Recommendation, ## Decision, or any AC checkbox
  - only the ## Recommendation Verdict section is replaced/appended
  - completed/ task files are never mutated
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

from lib.inception_decisions import check_ships_in_reachable

VERSION = "v1.0"

# ── Section extraction ────────────────────────────────────────────────────────

_RECOMMENDATION_SECTION_RE = re.compile(
    r"^##\s+Recommendation\s*\n(.*?)(?=^##\s|\Z)",
    re.MULTILINE | re.DOTALL,
)

_BACKTICK_SPAN_RE = re.compile(r"`([^`\n]+)`")
_TASK_REF_RE = re.compile(r"\bT-\d{2,6}\b")
_FILE_LINE_RE = re.compile(r"^([\w./-]+\.\w{1,8}):(\d+)$")
_MODULE_FUNC_RE = re.compile(r"^[A-Za-z_]\w*\.[A-Za-z_]\w*$")
# Extensions that mark a dotted token as a bare filename, not module.function.
_FILE_EXT_SUFFIXES = (
    ".py", ".sh", ".md", ".yaml", ".yml", ".json", ".bats", ".js", ".ts",
    ".html", ".css", ".txt", ".rs", ".go", ".rb", ".toml", ".cfg", ".ini",
)


def extract_recommendation_text(body: str) -> str | None:
    """Return the ## Recommendation section text (without heading), or None."""
    m = _RECOMMENDATION_SECTION_RE.search(body)
    return m.group(1) if m else None


# ── Claim model ───────────────────────────────────────────────────────────────


@dataclass
class Claim:
    kind: str          # file | file_line | task | module
    raw: str           # token as written
    status: str = ""   # pass | fail | unverifiable
    detail: str = ""   # short reason on fail/unverifiable


@dataclass
class ClaimsVerdict:
    task_id: str
    scan_id: str
    timestamp: str
    overall: str                       # CONFIRMED | CONTRADICTED | UNVERIFIED
    claims: list[Claim] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "task_id": self.task_id,
            "scan_id": self.scan_id,
            "timestamp": self.timestamp,
            "overall": self.overall,
            "claims": [
                {"kind": c.kind, "raw": c.raw, "status": c.status, "detail": c.detail}
                for c in self.claims
            ],
        }


# ── Extraction ────────────────────────────────────────────────────────────────


def _classify_span(span: str) -> Claim | None:
    """Classify one backticked span into a claim, or None if not a claim."""
    span = span.strip()
    if not span or "://" in span or " " in span:
        return None
    m = _FILE_LINE_RE.match(span)
    if m and "/" in m.group(1):
        return Claim(kind="file_line", raw=span)
    if _TASK_REF_RE.fullmatch(span):
        return Claim(kind="task", raw=span)
    if "/" in span and "." in span.rsplit("/", 1)[-1] and not span.endswith("/"):
        # strip a trailing :N handled above; reject globs/placeholders
        if any(ch in span for ch in "*?<>{}$"):
            return None
        return Claim(kind="file", raw=span)
    if _MODULE_FUNC_RE.match(span) and not span.lower().endswith(_FILE_EXT_SUFFIXES):
        return Claim(kind="module", raw=span)
    return None


def extract_claims(text: str, self_task_id: str = "") -> list[Claim]:
    """Extract typed claims from recommendation text. Deduped, order-preserving."""
    claims: list[Claim] = []
    seen: set[tuple[str, str]] = set()

    def add(c: Claim | None) -> None:
        if c is None:
            return
        key = (c.kind, c.raw)
        if key in seen:
            return
        seen.add(key)
        claims.append(c)

    for m in _BACKTICK_SPAN_RE.finditer(text):
        add(_classify_span(m.group(1)))

    # Bare T-XXX references anywhere (outside backticks too); skip self.
    for m in _TASK_REF_RE.finditer(text):
        ref = m.group(0)
        if ref != self_task_id:
            add(Claim(kind="task", raw=ref))
    # Drop a self-reference that arrived via a backticked span as well.
    claims = [c for c in claims if not (c.kind == "task" and c.raw == self_task_id)]
    return claims


# ── Verification (read-only) ──────────────────────────────────────────────────


def verify_claim(claim: Claim, project_root: Path) -> None:
    """Set claim.status/detail in place. Never writes anything."""
    try:
        if claim.kind == "file":
            if (project_root / claim.raw).exists():
                claim.status = "pass"
            else:
                claim.status = "fail"
                claim.detail = "file not found at PROJECT_ROOT"
        elif claim.kind == "file_line":
            m = _FILE_LINE_RE.match(claim.raw)
            path = project_root / m.group(1)
            line_no = int(m.group(2))
            if not path.exists():
                claim.status = "fail"
                claim.detail = "file not found"
            else:
                n_lines = len(path.read_text(errors="replace").splitlines())
                if line_no <= n_lines:
                    claim.status = "pass"
                else:
                    claim.status = "fail"
                    claim.detail = f"line {line_no} > {n_lines} lines in file"
        elif claim.kind == "task":
            found = any(
                list((project_root / ".tasks" / sub).glob(f"{claim.raw}-*.md"))
                for sub in ("active", "completed")
                if (project_root / ".tasks" / sub).is_dir()
            )
            if found:
                claim.status = "pass"
            else:
                claim.status = "fail"
                claim.detail = "no task file in .tasks/{active,completed}/"
        elif claim.kind == "module":
            # ships_in reachability reuse (T-1984 grammar): symbol grep in
            # lib/ agents/ bin/. Returns None when reachable.
            err = check_ships_in_reachable(claim.raw, "claim", project_root)
            if err is None:
                claim.status = "pass"
            else:
                claim.status = "fail"
                claim.detail = "symbol not found in lib/ agents/ bin/"
        else:
            claim.status = "unverifiable"
            claim.detail = f"unknown claim kind {claim.kind}"
    except OSError as e:
        claim.status = "unverifiable"
        claim.detail = f"read error: {e}"


def compute_overall(claims: list[Claim]) -> str:
    verifiable = [c for c in claims if c.status in {"pass", "fail"}]
    if any(c.status == "fail" for c in verifiable):
        return "CONTRADICTED"
    if verifiable:
        return "CONFIRMED"
    return "UNVERIFIED"


def validate_task(task_path: Path, project_root: Path) -> ClaimsVerdict:
    """Extract + verify claims for one task file. Read-only."""
    text = task_path.read_text()
    stem_parts = task_path.stem.split("-")
    task_id = stem_parts[0] + "-" + stem_parts[1]
    rec_text = extract_recommendation_text(text)
    claims = extract_claims(rec_text or "", self_task_id=task_id)
    for c in claims:
        verify_claim(c, project_root)
    return ClaimsVerdict(
        task_id=task_id,
        scan_id=f"RC-{uuid.uuid4().hex[:8]}",
        timestamp=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        overall=compute_overall(claims),
        claims=claims,
    )


# ── Verdict rendering + atomic write ──────────────────────────────────────────

VERDICT_HEADER = f"## Recommendation Verdict ({VERSION})"
_CLAIMS_VERDICT_SECTION_RE = re.compile(
    r"^## Recommendation Verdict \(v[0-9.]+\)\s*\n(.*?)(?=^#{2,} |\Z)",
    re.MULTILINE | re.DOTALL,
)

_STATUS_GLYPH = {"pass": "✓ pass", "fail": "✗ fail", "unverifiable": "? unverifiable"}


def render_claims_verdict_md(verdict: ClaimsVerdict) -> str:
    lines = [
        VERDICT_HEADER,
        "",
        f"- **Scan ID:** {verdict.scan_id}",
        f"- **Timestamp:** {verdict.timestamp}",
        f"- **Overall:** {verdict.overall}",
        f"- **Claims:** {len(verdict.claims)}",
    ]
    if verdict.claims:
        lines += [
            "",
            "| Claim | Type | Status |",
            "|-------|------|--------|",
        ]
        for c in verdict.claims:
            status = _STATUS_GLYPH.get(c.status, c.status)
            if c.detail:
                status += f" — {c.detail}"
            lines.append(f"| `{c.raw}` | {c.kind} | {status} |")
    else:
        lines.append("- No verifiable claims found in ## Recommendation")
    lines.append("")
    return "\n".join(lines)


def write_claims_verdict_to_task(task_path: Path, verdict: ClaimsVerdict) -> None:
    """Replace/append the Recommendation Verdict section atomically.

    Invariant: only this section is touched — Recommendation, Decision and AC
    checkboxes pass through byte-identical. completed/ files are never mutated
    (caller guards; this function also refuses).
    """
    if task_path.parent.name == "completed":
        raise ValueError("refusing to mutate a completed/ task file")
    text = task_path.read_text()
    new_section = render_claims_verdict_md(verdict)
    if _CLAIMS_VERDICT_SECTION_RE.search(text):
        # T-2730: callable replacement — a rendered verdict is data, and passing
        # it as a string makes `re` parse its backslashes as template escapes.
        # Sibling of static_scan.write_verdict_to_task; same shape, same fix.
        new_text = _CLAIMS_VERDICT_SECTION_RE.sub(lambda _m: new_section, text)
    else:
        sep = "" if text.endswith("\n") else "\n"
        new_text = text + sep + "\n" + new_section
    tmp_path = task_path.with_suffix(".rctmp")
    try:
        tmp_path.write_text(new_text)
        os.replace(tmp_path, task_path)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink(missing_ok=True)
        raise


# ── CLI ───────────────────────────────────────────────────────────────────────


def find_task_file(project_root: Path, task_id: str) -> Path | None:
    for sub in ("active", "completed"):
        for candidate in (project_root / ".tasks" / sub).glob(f"{task_id}-*.md"):
            return candidate
    return None


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    if not argv or argv[0] in {"-h", "--help"}:
        print(
            "Usage: python -m lib.reviewer.recommendation_claims <T-XXX> [--json] [--no-write]\n"
            "  Verifies evidence claims in the task's ## Recommendation section\n"
            "  and writes a ## Recommendation Verdict block (active/ tasks only).\n"
            "  --json      emit machine-readable verdict on stdout\n"
            "  --no-write  do not modify the task file",
            file=sys.stderr,
        )
        return 2

    task_id = argv[0]
    emit_json = "--json" in argv
    no_write = "--no-write" in argv

    project_root = Path(os.environ.get("PROJECT_ROOT") or os.getcwd())
    task_file = find_task_file(project_root, task_id)
    if not task_file:
        print(f"ERROR: task file for {task_id} not found under {project_root}/.tasks/", file=sys.stderr)
        return 4

    verdict = validate_task(task_file, project_root)

    if not no_write and task_file.parent.name != "completed":
        write_claims_verdict_to_task(task_file, verdict)

    if emit_json:
        print(json.dumps(verdict.to_dict(), indent=2))
    else:
        print(render_claims_verdict_md(verdict))

    # advisory exit semantics: 0 CONFIRMED/UNVERIFIED, 1 CONTRADICTED
    return 1 if verdict.overall == "CONTRADICTED" else 0


if __name__ == "__main__":
    sys.exit(main())
