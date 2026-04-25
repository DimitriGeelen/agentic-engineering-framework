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

VERSION = "v1.4"
SCHEMA_VERSION = 3


# ───────────────────────── Data classes ─────────────────────────


@dataclass
class Finding:
    pattern_id: str
    pattern_name: str
    detection_confidence: str
    lie_severity: str
    location: str  # e.g. "Verification:line 3" or "AC#2 (Agent)"
    evidence: str  # the offending line, trimmed
    # v1.3: per-AC linkage (None for verification-level findings)
    ac_index: int | None = None
    ac_subhead: str | None = None
    ac_text: str | None = None

    def to_dict(self) -> dict:
        return {
            "pattern_id": self.pattern_id,
            "pattern_name": self.pattern_name,
            "detection_confidence": self.detection_confidence,
            "lie_severity": self.lie_severity,
            "location": self.location,
            "evidence": self.evidence,
            "ac_index": self.ac_index,
            "ac_subhead": self.ac_subhead,
            "ac_text": self.ac_text,
        }


@dataclass
class EscalationTrigger:
    """A Layer 1 escalation pattern that fired against the task."""
    trigger_id: str
    trigger_name: str
    severity: str
    reason: str
    matched: str  # short snippet of the matching text

    def to_dict(self) -> dict:
        return {
            "trigger_id": self.trigger_id,
            "trigger_name": self.trigger_name,
            "severity": self.severity,
            "reason": self.reason,
            "matched": self.matched,
        }


@dataclass
class Verdict:
    task_id: str
    scan_id: str
    timestamp: str
    overall: str  # PASS | CONCERN | FAIL
    findings: list[Finding] = field(default_factory=list)
    catalogue_version: str = ""
    # v1.1 additions:
    escalations: list[EscalationTrigger] = field(default_factory=list)
    needs_human: bool = False  # any escalation OR Layer 2 declaration
    risk_declared: str | None = None
    human_signoff_declared: str | None = None
    # v1.4 additions:
    suppressed: list[Finding] = field(default_factory=list)  # findings dropped by override
    expired_overrides: list[dict] = field(default_factory=list)  # surfaced for action

    def to_dict(self) -> dict:
        return {
            "task_id": self.task_id,
            "scan_id": self.scan_id,
            "timestamp": self.timestamp,
            "overall": self.overall,
            "catalogue_version": self.catalogue_version,
            "findings": [f.to_dict() for f in self.findings],
            "escalations": [e.to_dict() for e in self.escalations],
            "needs_human": self.needs_human,
            "risk_declared": self.risk_declared,
            "human_signoff_declared": self.human_signoff_declared,
            "suppressed": [f.to_dict() for f in self.suppressed],
            "expired_overrides": self.expired_overrides,
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
                    ac_index=counter,
                    ac_subhead=current_subhead,
                    ac_text=body.strip()[:200],
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

# L-264-(a): false positive when --no-verify appears inside a literal
# string argument to grep/awk/sed/jq — that's verifying the *presence* of
# the bypass marker, not using it.
_GREP_LITERAL_RE = re.compile(
    r"\b(grep|awk|sed|jq|rg|ag)\b[^|]*['\"][^'\"]*--no-verify[^'\"]*['\"]"
)


def detect_swallowed_errors(verification_section: str) -> list[Finding]:
    findings: list[Finding] = []
    if not verification_section:
        return findings
    for lineno, raw in enumerate(verification_section.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        # L-264-(a): suppress if --no-verify appears as a grep/awk/sed pattern
        if _GREP_LITERAL_RE.search(line):
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


# L-264-(b): widened — added more success markers + catch standalone
# success-printing lines as well as echo/printf forms.
_SUCCESS_TOKEN_RE = re.compile(
    r"\b(TESTS?\s+PASS(?:ED|ING)?|BUILD\s+(?:OK|SUCCESSF?UL)|ALL\s+GREEN|SUCCESS|PASSED|VERIFIED|DONE|GREEN)\b",
    re.IGNORECASE,
)
_ECHO_PRINTF_RE = re.compile(r"^\s*(echo|printf)\s+", re.IGNORECASE)


def detect_output_spoofing(verification_section: str) -> list[Finding]:
    """Heuristic: lines that print a success token without a real assertion.

    Conservative — only flags lines where echo/printf produces a success token
    AND the line is not piped into grep/test/awk/etc. (which would constitute
    a real assertion).

    v1.1 widening: more success tokens, also catches `echo "OK" >> file`.
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


# ───────────────────────── v1.1 detectors ─────────────────────────


def detect_empty_output_success(verification_section: str) -> list[Finding]:
    """Verification redirects all output to /dev/null and relies only on exit code.

    Risk: many commands exit 0 even when no real work happens (`grep` with
    `-q` is fine, but `command > /dev/null` without checking output is suspect).
    Heuristic — flag lines ending in `> /dev/null` (without 2>&1 + grep -q etc).
    """
    findings: list[Finding] = []
    if not verification_section:
        return findings
    for lineno, raw in enumerate(verification_section.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        # only flag if line is essentially `cmd > /dev/null` with no further check
        if not re.search(r">\s*/dev/null\s*(2>&1)?\s*$", line):
            continue
        # exempt grep -q (silent grep is the correct pattern)
        if re.search(r"\bgrep\s+(-\w*q\w*|--quiet)\b", line):
            continue
        # exempt test/[
        if re.match(r"^(test|\[)\b", line):
            continue
        findings.append(
            Finding(
                pattern_id="empty-output-success",
                pattern_name="Exit-code-only verification with discarded output",
                detection_confidence="heuristic",
                lie_severity="partial",
                location=f"Verification:line {lineno}",
                evidence=line[:200],
            )
        )
    return findings


_SKIP_AS_PASS_RE = re.compile(
    r"(--collect-only|--skip\b|SKIP=true|--dry-run|--check-only|pytest\.mark\.skip|@unittest\.skip|xfail|@xfail|--xfail)",
    re.IGNORECASE,
)


def detect_skip_as_pass(verification_section: str) -> list[Finding]:
    """Verification command flags that collect/skip rather than execute.

    `pytest --collect-only` exits 0 if collection succeeds — does NOT run tests.
    `make test SKIP=true` typically skips. xfail-ed assertions count as passes.
    """
    findings: list[Finding] = []
    if not verification_section:
        return findings
    for lineno, raw in enumerate(verification_section.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if _SKIP_AS_PASS_RE.search(line):
            findings.append(
                Finding(
                    pattern_id="skip-as-pass",
                    pattern_name="Skipped/collected tests treated as pass",
                    detection_confidence="deterministic",
                    lie_severity="severe",
                    location=f"Verification:line {lineno}",
                    evidence=line[:200],
                )
            )
    return findings


_INTEGRATION_AC_RE = re.compile(
    r"\b(integration|end[- ]to[- ]end|e2e|cross[- ](module|service|process)|live\s+(api|db))\b",
    re.IGNORECASE,
)
_UNIT_PATH_RE = re.compile(r"\btests?/unit\b|\bspec/unit\b|_unit_test|test_unit_")


def detect_mock_only_integration(ac_section: str, verification_section: str) -> list[Finding]:
    """AC promises integration but verification only exercises tests/unit/.

    Heuristic — fires when:
      - any AC mentions integration / e2e / cross-process, AND
      - verification commands only reference tests/unit/ paths (no integration).
    """
    findings: list[Finding] = []
    if not ac_section or not verification_section:
        return findings
    if not _INTEGRATION_AC_RE.search(ac_section):
        return findings
    # find any non-comment verification line referencing a test path
    test_path_lines = []
    has_integration_path = False
    for raw in verification_section.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if re.search(r"\btests?/", line):
            test_path_lines.append(line)
            if not _UNIT_PATH_RE.search(line) and re.search(r"\btests?/(integration|e2e|playwright|web)", line):
                has_integration_path = True
    if not test_path_lines:
        return findings  # no test paths referenced at all → not this pattern
    if has_integration_path:
        return findings  # actually runs integration tests
    # Only unit-test paths but AC promises integration
    findings.append(
        Finding(
            pattern_id="mock-only-integration",
            pattern_name="Integration AC verified only by unit tests",
            detection_confidence="heuristic",
            lie_severity="partial",
            location="AC vs Verification cross-check",
            evidence=(test_path_lines[0] if test_path_lines else "")[:200],
        )
    )
    return findings


_FILE_PATH_RE = re.compile(r"\b((?:[a-z0-9_./-]+/)+[a-z0-9_-]+\.[a-z]{1,6})\b", re.IGNORECASE)


# v1.2: transitive-coverage heuristic per L-265.
# A path is "transitively covered" if it sits under a tree exercised by a
# generic test runner that the verification section invokes.
_TRANSITIVE_RUNNERS = [
    # (regex matching verification line, list of dir prefixes whose contents are covered)
    (re.compile(r"\bbin/fw\s+test\s+(unit|all)\b"), ["tests/unit/", "lib/", "agents/"]),
    (re.compile(r"\bbin/fw\s+test\s+integration\b"), ["tests/integration/", "lib/", "agents/"]),
    (re.compile(r"\bbin/fw\s+audit\b"), ["agents/audit/", "lib/audit"]),
    (re.compile(r"\bbin/fw\s+doctor\b"), ["lib/", "bin/", "agents/"]),
    (re.compile(r"\bpytest\s+tests/(unit|integration|e2e)/"), ["tests/", "lib/"]),
    (re.compile(r"\bbats\s+tests/unit/"), ["tests/unit/", "lib/", "agents/"]),
]


def _path_transitively_covered(path: str, verif_text: str) -> bool:
    """Return True if any verification command is a generic runner that
    exercises code under any prefix that contains `path`."""
    for pat, prefixes in _TRANSITIVE_RUNNERS:
        if pat.search(verif_text):
            for prefix in prefixes:
                if path.startswith(prefix):
                    return True
    return False


def detect_ac_verify_mismatch(ac_section: str, verification_section: str) -> list[Finding]:
    """AC checked AND mentions a specific file path, but no verification line touches it.

    Heuristic — high false-positive risk if AC references aspirational paths.
    Conservative: only fires when:
      - the AC is checked ([x]) AND
      - it mentions a file path with a known source extension AND
      - no non-comment verification line mentions that path.
    """
    findings: list[Finding] = []
    if not ac_section or not verification_section:
        return findings
    verif_text = "\n".join(
        ln for ln in verification_section.splitlines()
        if ln.strip() and not ln.strip().startswith("#")
    )
    counter = 0
    current_subhead = "ACs"
    for raw in ac_section.splitlines():
        if raw.strip().startswith("### "):
            current_subhead = raw.strip().lstrip("# ").strip()
            counter = 0
            continue
        m = _AC_LINE_RE.match(raw)
        if not m:
            continue
        counter += 1
        if m.group("state").lower() != "x":
            continue
        body = m.group("body")
        # only check Agent ACs (humans verify their own)
        if "human" in current_subhead.lower():
            continue
        for fp_match in _FILE_PATH_RE.finditer(body):
            path = fp_match.group(1)
            # skip very short or generic paths
            if len(path) < 6 or path.endswith(".md") or "/" not in path:
                continue
            # if not referenced in verification section at all
            if path not in verif_text:
                # v1.2: transitive-coverage exemption per L-265
                if _path_transitively_covered(path, verif_text):
                    continue
                findings.append(
                    Finding(
                        pattern_id="AC-verify-mismatch",
                        pattern_name="Checked AC names a file path the verification never touches",
                        detection_confidence="heuristic",
                        lie_severity="narrow",
                        location=f"AC#{counter} ({current_subhead})",
                        evidence=f"path={path} in: {body[:150]}",
                        ac_index=counter,
                        ac_subhead=current_subhead,
                        ac_text=body.strip()[:200],
                    )
                )
                break  # one finding per AC line
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


def evaluate_escalations(
    ac_section: str,
    verif_section: str,
    meta: dict,
    escalation_catalogue: dict | None,
) -> list[EscalationTrigger]:
    """Layer 1: match Layer-1 escalation patterns against AC + verification text."""
    if not escalation_catalogue:
        return []
    triggers: list[EscalationTrigger] = []
    for trig in escalation_catalogue.get("triggers", []):
        for matcher in trig.get("match", []):
            kind = matcher.get("kind")
            pattern = matcher.get("pattern")
            if not kind or not pattern:
                continue
            haystack = ""
            if kind == "ac_text":
                haystack = ac_section
            elif kind == "verification_text":
                haystack = verif_section
            elif kind == "task_metadata":
                haystack = json.dumps(meta or {}, default=str)
            if not haystack:
                continue
            try:
                m = re.search(pattern, haystack, re.IGNORECASE)
            except re.error:
                continue
            if m:
                triggers.append(
                    EscalationTrigger(
                        trigger_id=trig["id"],
                        trigger_name=trig.get("name", trig["id"]),
                        severity=trig.get("severity", "medium"),
                        reason=trig.get("reason", ""),
                        matched=m.group(0)[:160],
                    )
                )
                break  # one finding per trigger id
    return triggers


def scan_task(
    task_path: Path,
    catalogue: dict,
    escalation_catalogue: dict | None = None,
    overrides: list | None = None,
) -> Verdict:
    meta, body = parse_task_file(task_path)
    ac_section = extract_section(body, "Acceptance Criteria") or ""
    verif_section = extract_section(body, "Verification") or ""

    findings: list[Finding] = []
    findings.extend(detect_tautology(verif_section))
    findings.extend(detect_empty_body(ac_section))
    findings.extend(detect_swallowed_errors(verif_section))
    findings.extend(detect_output_spoofing(verif_section))
    # v1.1 detectors
    findings.extend(detect_empty_output_success(verif_section))
    findings.extend(detect_skip_as_pass(verif_section))
    findings.extend(detect_mock_only_integration(ac_section, verif_section))
    findings.extend(detect_ac_verify_mismatch(ac_section, verif_section))

    task_id = task_path.stem.split("-")[0] + "-" + task_path.stem.split("-")[1]

    # v1.4: filter findings through overrides
    suppressed: list[Finding] = []
    expired: list[dict] = []
    if overrides:
        from lib.reviewer.overrides import is_overridden, find_expired
        kept: list[Finding] = []
        for f in findings:
            ov = is_overridden(overrides, task_id, f.pattern_id, f.ac_index)
            if ov is not None:
                suppressed.append(f)
            else:
                kept.append(f)
        findings = kept
        for o in find_expired(overrides):
            if o.task_id == task_id:
                expired.append({"id": o.id, "pattern_id": o.pattern_id, "expired_at": o.expires_at})

    overall = compute_overall(findings, catalogue.get("verdict_thresholds", {}))

    # v1.1: Layer 1 escalation
    escalations = evaluate_escalations(ac_section, verif_section, meta, escalation_catalogue)

    # v1.1: Layer 2 frontmatter
    risk_declared = (meta or {}).get("risk")
    human_signoff_declared = (meta or {}).get("human_signoff")

    needs_human = bool(escalations) or risk_declared in {"high", "medium"} or human_signoff_declared == "required"

    return Verdict(
        task_id=task_id,
        scan_id=f"R-{uuid.uuid4().hex[:8]}",
        timestamp=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        overall=overall,
        findings=findings,
        catalogue_version=catalogue.get("catalogue_version", "unknown"),
        escalations=escalations,
        needs_human=needs_human,
        risk_declared=risk_declared,
        human_signoff_declared=human_signoff_declared,
        suppressed=suppressed,
        expired_overrides=expired,
    )


# ───────────────────────── Verdict rendering ─────────────────────────

VERDICT_HEADER = f"## Reviewer Verdict ({VERSION})"
# v1.3: match any v* header so prior-version verdicts are cleanly replaced.
_VERDICT_SECTION_RE = re.compile(
    r"^## Reviewer Verdict \(v[0-9.]+\)\s*\n(.*?)(?=^## |\Z)",
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
        f"- **Needs Human:** {'yes' if verdict.needs_human else 'no'}",
    ]
    if verdict.risk_declared:
        lines.append(f"- **Risk (declared):** {verdict.risk_declared}")
    if verdict.human_signoff_declared:
        lines.append(f"- **Human signoff (declared):** {verdict.human_signoff_declared}")
    if verdict.findings:
        lines.append(f"- **Findings:** {len(verdict.findings)}")
        ac_bound = [f for f in verdict.findings if f.ac_index is not None]
        verif_bound = [f for f in verdict.findings if f.ac_index is None]
        # v1.3: per-AC grouping
        if ac_bound:
            lines.append("")
            lines.append("**Per-AC findings:**")
            lines.append("")
            grouped: dict[tuple[str, int], list[Finding]] = {}
            for f in ac_bound:
                grouped.setdefault((f.ac_subhead or "ACs", f.ac_index or 0), []).append(f)
            for (subhead, idx) in sorted(grouped.keys()):
                fs = grouped[(subhead, idx)]
                ac_text = fs[0].ac_text or ""
                lines.append(f"- **AC#{idx} ({subhead})** — {ac_text}")
                for f in fs:
                    lines.append(
                        f"  - **{f.pattern_id}** ({f.lie_severity}, {f.detection_confidence}) "
                        f"— `{f.evidence}`"
                    )
        if verif_bound:
            lines.append("")
            lines.append("**Verification-level findings:**")
            lines.append("")
            for i, f in enumerate(verif_bound, start=1):
                lines.append(
                    f"  {i}. **{f.pattern_id}** ({f.lie_severity}, {f.detection_confidence}) "
                    f"@ {f.location}"
                )
                lines.append(f"     - evidence: `{f.evidence}`")
    else:
        lines.append("- **Findings:** none")
    if verdict.escalations:
        lines.append("")
        lines.append(f"- **Layer-1 escalations:** {len(verdict.escalations)}")
        for i, e in enumerate(verdict.escalations, start=1):
            lines.append(f"  {i}. **{e.trigger_id}** ({e.severity}) — {e.trigger_name}")
            lines.append(f"     - matched: `{e.matched}`")
    if verdict.suppressed:
        lines.append("")
        lines.append(f"- **Suppressed:** {len(verdict.suppressed)} (by override)")
        for f in verdict.suppressed:
            ac_loc = f"AC#{f.ac_index} ({f.ac_subhead})" if f.ac_index is not None else f.location
            lines.append(f"  - {f.pattern_id} @ {ac_loc}")
    if verdict.expired_overrides:
        lines.append("")
        lines.append(f"- **Expired overrides:** {len(verdict.expired_overrides)}")
        for e in verdict.expired_overrides:
            lines.append(f"  - {e['id']} pattern={e['pattern_id']} expired_at={e['expired_at']}")
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
    # v1.1: Layer 1 escalation catalogue (optional — absence = no Layer 1)
    escalation_path = framework_root / "policy" / "escalation-patterns.yaml"
    if not escalation_path.exists():
        escalation_path = project_root / "policy" / "escalation-patterns.yaml"
    escalation_catalogue = load_catalogue(escalation_path) if escalation_path.exists() else None

    # v1.4: load active overrides from project working memory
    from lib.reviewer.overrides import load_overrides
    overrides = load_overrides()

    verdict = scan_task(task_file, catalogue, escalation_catalogue, overrides=overrides)

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
                    "suppressed_count": len(verdict.suppressed),
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
        for f in verdict.suppressed:
            append_feedback_event(
                stream,
                {
                    "kind": "override_applied",
                    "timestamp": verdict.timestamp,
                    "scan_id": verdict.scan_id,
                    "task_id": verdict.task_id,
                    "payload": {
                        "pattern_id": f.pattern_id,
                        "ac_index": f.ac_index,
                        "ac_subhead": f.ac_subhead,
                    },
                },
            )
        for e in verdict.expired_overrides:
            append_feedback_event(
                stream,
                {
                    "kind": "override_expired",
                    "timestamp": verdict.timestamp,
                    "scan_id": verdict.scan_id,
                    "task_id": verdict.task_id,
                    "payload": e,
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
