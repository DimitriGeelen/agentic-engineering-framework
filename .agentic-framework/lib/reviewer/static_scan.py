"""Static-scan reviewer (T-1443 v1.0 → v1.5).

Detects anti-patterns in completed task files. v1.0 scope:
- 4 seed patterns: tautology, empty-body, swallowed-errors, output-spoofing
- Verdict written to task body under `#{2,}Reviewer Verdict (v1.x)`
- Append-only feedback stream at `.context/working/feedback-stream.yaml`
- Sovereignty: NEVER modifies AC checkboxes for Human ACs or non-[REVIEWER] Agent ACs.
  v1.5 (T-1985): [REVIEWER]-prefixed Agent ACs in active/ tasks ARE auto-ticked
  when all five evidence conditions hold (PASS verdict + zero per-AC findings +
  AC unticked + no suppress override + [REVIEWER] prefix). Sovereignty rail:
  digest-keyed feedback-stream prevents re-ticking human-unticked ACs.

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

import hashlib
import json
import os
import re
import sys
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

import yaml

VERSION = "v1.5"
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
    # v1.5: [REVIEWER] Agent ACs auto-ticked in this scan (T-1985)
    auto_ticked: list[dict] = field(default_factory=list)  # {ac_index, digest, text_excerpt}

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
            "auto_ticked": self.auto_ticked,
        }


# ───────────────────────── Catalogue loading ─────────────────────────


def load_catalogue(catalogue_path: Path) -> dict:
    with open(catalogue_path) as fh:
        return yaml.safe_load(fh)


# ───────────────────────── Section extractors ─────────────────────────

_SECTION_RE = re.compile(r"^## ", re.MULTILINE)


# ───────────────────────── Auto-tick helpers (v1.5, T-1985) ─────────────────────────


@dataclass
class ParsedAC:
    """An AC entry parsed from the ## Acceptance Criteria section."""
    ac_index: int       # 1-based counter within the subhead
    ac_subhead: str     # e.g. "Agent" or "Human"
    ac_text: str        # body after `- [ ] ` or `- [x] `
    ticked: bool        # True when `[x]`
    raw_line: str       # exact line as it appears in the file


def _compute_ac_text_digest(ac_text: str) -> str:
    """SHA-256 of the AC text, first 12 hex characters."""
    return hashlib.sha256(ac_text.encode()).hexdigest()[:12]


def _feedback_stream_has_tick(
    task_id: str,
    ac_index: int,
    digest: str,
    fs_path: Path,
) -> bool:
    """True if the feedback stream already has an auto_tick entry for (task_id, ac_index, digest)."""
    if not fs_path.exists():
        return False
    target_key = f"auto_tick:{task_id}:{ac_index}:{digest}"
    return target_key in fs_path.read_text()


def _should_auto_tick(
    ac: ParsedAC,
    findings: list[Finding],
    task_overrides: list,
    verdict_overall: str,
) -> bool:
    """Conjunctive 5-condition gate for auto-ticking a [REVIEWER] Agent AC.

    Conditions (ALL must hold):
      1. overall verdict is PASS
      2. zero Finding entries reference this AC's ac_index (within same subhead)
      3. AC is currently unticked (- [ ])
      4. no active suppress override targets this ac_index
      5. AC text starts with [REVIEWER] prefix
    """
    # Condition 1
    if verdict_overall != "PASS":
        return False
    # Condition 3
    if ac.ticked:
        return False
    # Condition 5
    if not re.match(r"^\[REVIEWER\]", ac.ac_text.strip(), re.IGNORECASE):
        return False
    # Condition 2: no findings targeting this (ac_index, ac_subhead)
    for f in findings:
        if f.ac_index is None:
            continue
        if f.ac_index == ac.ac_index and (
            f.ac_subhead is None or f.ac_subhead == ac.ac_subhead
        ):
            return False
    # Condition 4: no active suppress override specifically targeting this ac_index
    # Wildcard overrides (ac_index=None) suppress findings for a pattern; they do NOT
    # block ticking an AC that happens to share the task. Only exact ac_index matches block.
    now = datetime.now(timezone.utc)
    for o in (task_overrides or []):
        if o.ac_index != ac.ac_index:
            continue
        if not o.is_expired(now):
            return False
    return True


# T-2156 (OBS-047): HTML-comment strip used before bullet iteration.
# Bullets inside `<!-- ... -->` are documentation examples (the default.md
# template's `### Human` block carries `- [ ] [REVIEWER] Block message …`
# as a worked example), NOT real ACs. Without this strip, when an author
# drops the `### Human` heading while editing the section in place (the
# L-449 anti-pattern), the parser counts the commented bullets as Agent
# ACs and the T-1985 auto-tick happily ticks them on PASS. 9+ closed tasks
# already carry that FP — see OBS-047 corpus walk.
#
# Implementation: Python `re.DOTALL` across `<!--…-->`. L-414 documents the
# sed-range alternative's pitfall (single-line opener directly followed
# by multi-line range can swallow content); Python `re.DOTALL` has no
# state-machine quirk and handles both shapes correctly.
def _strip_html_comments(text: str) -> str:
    """Strip <!-- … --> from text. Handles single-line and multi-line uniformly."""
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def _parse_agent_acs(ac_section: str) -> list[ParsedAC]:
    """Return ParsedAC entries from the `### Agent` subhead only.

    Tasks without an explicit `### Agent` subhead yield no results — sovereign
    default: no implicit Agent section means nothing gets auto-ticked.

    HTML-commented bullets are excluded (see `_strip_html_comments` docstring
    + T-2156 / OBS-047). The template's documentation examples live inside
    `<!-- … -->` and must never be parsed as real ACs.
    """
    # T-2156: strip HTML comments FIRST so commented-out bullets don't reach
    # the line iterator. This also drops any commented-out subhead-mimicking
    # lines (`<!-- ### Human -->`) so the in_agent flag tracks real structure.
    ac_section = _strip_html_comments(ac_section)
    results: list[ParsedAC] = []
    current_subhead = ""
    counter = 0
    in_agent = False
    for raw_line in ac_section.splitlines():
        stripped = raw_line.strip()
        if re.match(r"^#{2,}\s+\S", stripped):
            current_subhead = stripped.lstrip("# ").strip()
            in_agent = current_subhead.lower() == "agent"
            counter = 0
            continue
        m = _AC_LINE_RE.match(raw_line)
        if m:
            counter += 1
            if in_agent:
                results.append(
                    ParsedAC(
                        ac_index=counter,
                        ac_subhead=current_subhead,
                        ac_text=m.group("body"),
                        ticked=m.group("state").lower() == "x",
                        raw_line=raw_line,
                    )
                )
    return results


# ─────────────── Auto-tick orchestration (v1.5, T-1985) ───────────────


def _apply_ac_mutations(text: str, mutations: list[tuple[str, str]]) -> str:
    """Apply AC checkbox mutations line-by-line. Each entry is (old_raw_line, new_raw_line).

    Uses a queue per old-line to handle duplicate AC texts without double-replacing.
    """
    if not mutations:
        return text
    pending: dict[str, list[str]] = {}
    for old, new in mutations:
        key = old.rstrip("\n")
        pending.setdefault(key, []).append(new.rstrip("\n"))
    result_lines = []
    for line in text.splitlines(keepends=True):
        key = line.rstrip("\n")
        if key in pending and pending[key]:
            replacement = pending[key].pop(0)
            result_lines.append(replacement + ("\n" if line.endswith("\n") else ""))
        else:
            result_lines.append(line)
    return "".join(result_lines)


def _compute_auto_ticks(
    task_path: Path,
    task_id: str,
    verdict: Verdict,
    overrides: list,
    stream_path: Path,
) -> tuple[list[dict], list[tuple[str, str]]]:
    """Determine which [REVIEWER] Agent ACs to auto-tick.

    Only runs on active/ tasks (completed/ files are never mutated).

    Returns (ticked_acs_info, ac_mutations):
    - ticked_acs_info: [{ac_index, digest, text_excerpt}] for verdict block reporting
    - ac_mutations:    [(old_raw_line, new_raw_line)] pairs for _apply_ac_mutations
    """
    if verdict.overall != "PASS":
        return [], []
    if ".tasks/active/" not in str(task_path):
        return [], []

    _, body = parse_task_file(task_path)
    ac_section = extract_section(body, "Acceptance Criteria") or ""
    agent_acs = _parse_agent_acs(ac_section)

    # Pre-filter overrides for this task (non-expired)
    now = datetime.now(timezone.utc)
    task_overrides = [
        o for o in (overrides or [])
        if getattr(o, "task_id", None) == task_id and not o.is_expired(now)
    ]

    ticked_info: list[dict] = []
    mutations: list[tuple[str, str]] = []

    for ac in agent_acs:
        if not _should_auto_tick(ac, verdict.findings, task_overrides, verdict.overall):
            continue
        digest = _compute_ac_text_digest(ac.ac_text)
        if _feedback_stream_has_tick(task_id, ac.ac_index, digest, stream_path):
            continue  # sovereignty rail: respect human un-tick
        new_raw_line = ac.raw_line.replace("- [ ]", "- [x]", 1)
        mutations.append((ac.raw_line, new_raw_line))
        ticked_info.append(
            {
                "ac_index": ac.ac_index,
                "digest": digest,
                "text_excerpt": ac.ac_text[:80].replace("\n", " "),
            }
        )

    return ticked_info, mutations


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
        # T-1579: subhead detection — was `startswith("##{2,}")` (literal string,
        # never matches `### Agent` / `### Human`). The bug left current_subhead
        # stuck at "ACs", so Findings reported `ac_subhead="ACs"` and the
        # "skip Human ACs" branch in detect_ac_verify_mismatch never fired.
        if re.match(r"^#{2,}\s+\S", raw.strip()):
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

# L-369: canonical negative-assertion pattern. `cmd && exit N || true` reads
# as "if cmd succeeds, force fail; otherwise (cmd failed naturally) pass" —
# i.e. asserting absence. This is the correct idiom for "verify pattern is
# NOT present" and must not be flagged as severe error-swallowing. Origin:
# T-1812 reviewer-pass + T-1815 precision tighten (14 corpus false positives
# eliminated, 9 real findings preserved).
_NEGATIVE_ASSERTION_RE = re.compile(r"&&\s+exit\s+\d+\s*\|\|\s*true\s*$")


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
        # L-369: suppress canonical `cmd && exit N || true` negative assertion
        if _NEGATIVE_ASSERTION_RE.search(line):
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

# T-2177: strip single/double-quoted substrings so skip-tokens inside grep/awk/sed
# PATTERN arguments do not fire. Empirical FP: T-1516 line 2
#   test -z "$(grep -E 'manual fix.*--skip-sovereignty|deserves RCA' agents/audit/audit.sh || true)"
# The `--skip-sovereignty` here is text inside a quoted regex, not a CLI flag.
# Shape mirrors `_GREP_LITERAL_RE` (L-264-(a)) — strip-then-search is cleaner
# than a lookbehind in `_SKIP_AS_PASS_RE` and survives nesting better.
_QUOTED_SUBSTR_RE = re.compile(r"'[^']*'|\"[^\"]*\"")

# T-2177: suppress when the line carries a real output assertion on the same
# logical command. A `--dry-run` followed by `| grep -q PAT` or `&& test -f X`
# is simulation-with-check, not skip-as-pass. Empirical FP: T-2072 line 9
#   out=$(bin/fw pickup promote-deferred --dry-run 2>&1); echo "$?" | grep -q "^0$"
# Note: the `;` chain still counts — the later `| grep -q` is the assertion.
_OUTPUT_ASSERTION_RE = re.compile(
    r"\|\s*(grep|test|cmp|diff|jq|awk|sed)\b|&&\s*(grep|test|cmp|diff|jq|awk|sed|\[)\b"
)


def detect_skip_as_pass(verification_section: str) -> list[Finding]:
    """Verification command flags that collect/skip rather than execute.

    `pytest --collect-only` exits 0 if collection succeeds — does NOT run tests.
    `make test SKIP=true` typically skips. xfail-ed assertions count as passes.

    T-2177 suppressions:
      (a) skip-token appears only inside single/double quotes (text, not flag)
      (b) line carries an output assertion on the same logical command
          (`| grep`, `&& test`, etc.) — simulation-with-check is fine.
    """
    findings: list[Finding] = []
    if not verification_section:
        return findings
    for lineno, raw in enumerate(verification_section.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if not _SKIP_AS_PASS_RE.search(line):
            continue
        # T-2177 (a): if the match only exists inside quotes, suppress.
        stripped = _QUOTED_SUBSTR_RE.sub("", line)
        if not _SKIP_AS_PASS_RE.search(stripped):
            continue
        # T-2177 (b): if the line has an output assertion, the skip-flag is
        # part of a simulation-with-check, not an unverified skip.
        if _OUTPUT_ASSERTION_RE.search(line):
            continue
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


# T-1579: dotted Python imports (from a.b.c import X / import a.b.c) directly
# exercise a/b/c.py (or a/b/c/__init__.py). Substring match in verif_text
# misses these because slashes ≠ dots — eight FPs across the T-1576/77/78 arc.
_PYTHON_IMPORT_RE = re.compile(
    r"\b(?:from|import)\s+([a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*)+)",
    re.IGNORECASE,
)


def _path_python_import_covered(path: str, verif_text: str) -> bool:
    """Return True if `path` corresponds to a Python module imported in verif_text.

    Handles both module files (`a/b/c.py`) and package markers (`a/b/c/__init__.py`).
    """
    for m in _PYTHON_IMPORT_RE.finditer(verif_text):
        dotted = m.group(1)
        parts = dotted.split(".")
        as_module = "/".join(parts) + ".py"
        as_package = "/".join(parts) + "/__init__.py"
        if path == as_module or path == as_package:
            return True
    return False


# T-1896 (T-1878 B): mechanical-Expected catch for mis-classed [REVIEW] ACs.
#
# Fires when a `[REVIEW]` Human AC's **Expected:** clause reads as a
# deterministic shell check (grep/wc/exit/curl/HTTP-status/file-exists) AND
# the AC body contains no strategic markers (decide/approve/authorize/...)
# AND the Expected clause carries no taste signals (feels/reads/cleanly/...).
# Such ACs should be `[REVIEWER]` per the T-1811 conversion rule.
#
# Conservative by design — three gates must all line up before the finding
# fires, to avoid noise on genuine taste/judgment ACs. Override mechanism:
# `bin/fw reviewer override add --pattern human-ac-mechanical-signal`.

_HUMAN_AC_MECHANICAL_RE = re.compile(
    r"""(?ix)
    \b(
        # === I/O-checking dialect (T-1896 original) ===
        grep\s+-[qcv]?       |
        wc\s+-l              |
        \bexit\s+code\b      |
        returns?\s+\d        |
        returns?\s+0\b       |
        exits?\s+0\b         |
        \btest\s+-[fdeszr]\b |
        \[\s+-[fdeszr]\s     |
        \bcurl\s+-           |
        \bHTTP\s+\d{3}\b     |
        \b200\b              |
        \bappended\b         |
        \bfile\s+(exists|present|missing|contains) |
        \bstdout\s+contains  |
        \bset\s+-e\b         |
        bats\s+tests/        |
        pytest\s+tests/      |
        \brow\s+(written|appended) |
        \bstatus:\s*\w+      |
        # === Conformance-checking dialect (T-1897 widening) ===
        # "block message names X / names the X / names current focus"
        \bnames?\s+(the\s+|current\s+|missing\s+)?\S |
        # "shows X / shows the Y / shows current Z"  (NB: taste gate suppresses
        # "shows good", "shows rhythm" via _HUMAN_AC_TASTE_RE)
        \bshows?\s+(the\s+|current\s+|missing\s+)?\S |
        # "points at X / points to X"
        \bpoints?\s+(at|to)\b |
        # "contains the override flag / contains the focus name"
        \bcontains?\s+the\s+\S+ |
        # "override flag / bypass mechanism / override env var" — meta-vocabulary
        \b(override|bypass)\s+(flag|env\s+var|mechanism|syntax)\b |
        # "audit log row appended" / "audit row appended to .context/audits/..."
        \baudit\s+(log\s+)?row\s+(appended|written)\b |
        # "block-message names" / "gate refusal names" — composite conformance
        \b(block[- ]message|gate\s+(refusal|message))\s+(names?|shows?|contains?) |
        # "names missing X" (gate refusal pattern from T-1762)
        \bnames?\s+missing\s+\S
    )
    """
)

_HUMAN_AC_TASTE_RE = re.compile(
    r"""(?ix)
    \b(
        feels?\b        |
        reads?\b        |
        cleanly\b       |
        clean\s+enough  |
        \btone\b        |
        \bvoice\b       |
        intuitive       |
        naturally       |
        \bnatural\b     |
        rhythm          |
        \bjudgment\b    |
        \blands\b       |
        obvious\s+supersedes |
        acceptable\s+feel    |
        looks?\s+good   |
        UX              |
        cohesive
    )
    """
)

_HUMAN_AC_STRATEGIC_RE = re.compile(
    r"""(?ix)
    \b(
        decide\b        |
        approve\b       |
        authorize\b     |
        authorise\b     |
        sign[- ]off     |
        sovereignty     |
        escalate\b      |
        go\s*/\s*no-?go |
        confirm\s+intent
    )
    """
)


def detect_human_ac_mechanical_signal(ac_section: str) -> list[Finding]:
    """`[REVIEW]` Human AC whose Expected reads as a shell-grep-able check.

    Three gates, all must hold:
      1. AC sits under `### Human` subhead and body starts with `[REVIEW]`
      2. AC body has no strategic markers (decide/approve/authorize/...)
      3. The **Expected:** clause has at least one mechanical signal AND
         no taste signal (feels/reads/cleanly/intuitive/...)

    Heuristic, partial lie-severity → CONCERN, needs_human=no.
    Origin: T-1878 inception (13% mis-class rate); T-1894 manual remediation.
    """
    findings: list[Finding] = []
    if not ac_section:
        return findings

    current_subhead = "ACs"
    counter = 0
    # Accumulate the full multi-line body of the AC currently being parsed
    cur_ac_body: list[str] = []
    cur_ac_state: dict | None = None  # {"counter": N, "raw_line": str, "body_text": str, "is_review": bool}

    def _check_and_emit(ac_state: dict, body_lines: list[str]):
        """Run the three-gate check on a completed [REVIEW] Human AC."""
        if not ac_state or not ac_state.get("is_review"):
            return
        if "human" not in current_subhead.lower():
            return
        ac_body_text = ac_state["body_text"]
        # Gate 2a: strategic markers in AC line itself → suppress
        if _HUMAN_AC_STRATEGIC_RE.search(ac_body_text):
            return
        # Gate 2b (T-1897): taste markers in AC line itself → suppress.
        # An AC line like "[REVIEW] Block message reads usefully" is genuinely
        # taste-driven even if the Expected text incidentally uses mechanical
        # vocabulary ("names X / shows Y"). The AC header's voice wins.
        if _HUMAN_AC_TASTE_RE.search(ac_body_text):
            return
        # Find the Expected clause within the multi-line body
        joined = "\n".join(body_lines)
        expected_match = re.search(
            r"\*\*Expected:?\*\*\s*(.*?)(?=\n\s*\*\*(?:If\s+not|Steps|Why|Origin)|\Z)",
            joined,
            re.DOTALL | re.IGNORECASE,
        )
        if not expected_match:
            return
        expected_text = expected_match.group(1).strip()
        if not expected_text:
            return
        # Gate 3a: taste signals → suppress
        if _HUMAN_AC_TASTE_RE.search(expected_text):
            return
        # Gate 3b: mechanical signals must be present
        mech = _HUMAN_AC_MECHANICAL_RE.search(expected_text)
        if not mech:
            return
        snippet = expected_text[:140].replace("\n", " ")
        findings.append(
            Finding(
                pattern_id="human-ac-mechanical-signal",
                pattern_name="[REVIEW] Human AC has mechanical Expected clause (should be [REVIEWER])",
                detection_confidence="heuristic",
                lie_severity="partial",
                location=f"AC#{ac_state['counter']} ({current_subhead})",
                evidence=f"matched={mech.group(0)!r} in Expected: {snippet}",
                ac_index=ac_state["counter"],
                ac_subhead=current_subhead,
                ac_text=ac_body_text[:200],
            )
        )

    for raw in ac_section.splitlines():
        stripped = raw.strip()
        # Subhead transition
        if re.match(r"^#{2,}\s+\S", stripped):
            # close out any in-flight AC before switching subhead
            if cur_ac_state is not None:
                _check_and_emit(cur_ac_state, cur_ac_body)
            current_subhead = stripped.lstrip("# ").strip()
            counter = 0
            cur_ac_state = None
            cur_ac_body = []
            continue
        m = _AC_LINE_RE.match(raw)
        if m:
            # close prior AC
            if cur_ac_state is not None:
                _check_and_emit(cur_ac_state, cur_ac_body)
            counter += 1
            body = m.group("body")
            # `[REVIEW]` must be the literal prefix, NOT `[REVIEWER]` (which has its
            # own conversion semantics). Use a negative lookahead instead of `\b` —
            # `]` is non-word and the boundary after it is unreliable.
            is_review = bool(re.match(r"^\[REVIEW\](?!ER)", body.strip(), re.IGNORECASE))
            cur_ac_state = {
                "counter": counter,
                "body_text": body,
                "is_review": is_review,
            }
            cur_ac_body = []
            continue
        # continuation line (Expected/Steps/If-not/...)
        if cur_ac_state is not None:
            cur_ac_body.append(raw)
    # close the trailing AC
    if cur_ac_state is not None:
        _check_and_emit(cur_ac_state, cur_ac_body)
    return findings


def detect_reviewer_prose_mismatch(ac_section: str) -> list[Finding]:
    """`[REVIEWER]` Human AC whose Expected reads as a prose-quality check.

    The reviewer (this module) has 9 detectors — none evaluate natural-language
    prose quality. When an author files a prose-clarity AC as `[REVIEWER]`
    hoping `fw reviewer T-XXX` substitutes for human reading, the scanner
    silently ignores that AC (no detector fires) while reporting on other ACs.
    Overall verdict can be PASS / CONCERN-on-some-other-AC while the prose AC
    gets zero signal — false-success class (worse than acknowledged failure).

    Gates (all must hold):
      1. AC sits under `### Human` subhead and body starts with `[REVIEWER]`
      2. AC body or Expected clause contains taste / prose-quality vocabulary
         (reuses _HUMAN_AC_TASTE_RE: reads, tone, rhythm, intuitive, ...)

    Heuristic, partial lie-severity -> CONCERN, needs_human=no.
    Origin: T-1947 (L-409). T-1811 [REVIEWER] AC 'Updated CLAUDE.md section
    reads clearly' got no reviewer attention; scanner reported CONCERN on
    Agent AC#3 instead, leaving the prose dimension structurally invisible.

    Mirrors detect_human_ac_mechanical_signal but inverted: that one catches
    `[REVIEW]` ACs that should be `[REVIEWER]`; this one catches `[REVIEWER]`
    ACs that should be `[REVIEW]` (or paired with one).
    """
    findings: list[Finding] = []
    if not ac_section:
        return findings

    current_subhead = "ACs"
    counter = 0
    cur_ac_body: list[str] = []
    cur_ac_state: dict | None = None

    def _check_and_emit(ac_state: dict, body_lines: list[str]):
        if not ac_state or not ac_state.get("is_reviewer"):
            return
        if "human" not in current_subhead.lower():
            return
        ac_body_text = ac_state["body_text"]
        joined = "\n".join(body_lines)
        haystack = ac_body_text + "\n" + joined
        if not _HUMAN_AC_TASTE_RE.search(haystack):
            return
        taste_match = _HUMAN_AC_TASTE_RE.search(haystack)
        expected_match = re.search(
            r"\*\*Expected:?\*\*\s*(.*?)(?=\n\s*\*\*(?:If\s+not|Steps|Why|Origin)|\Z)",
            joined,
            re.DOTALL | re.IGNORECASE,
        )
        snippet_src = (
            expected_match.group(1).strip()[:140]
            if expected_match
            else ac_body_text[:140]
        ).replace("\n", " ")
        findings.append(
            Finding(
                pattern_id="reviewer-prose-mismatch",
                pattern_name="[REVIEWER] Human AC has prose-quality Expected (should be [REVIEW] or paired)",
                detection_confidence="heuristic",
                lie_severity="partial",
                location=f"AC#{ac_state['counter']} ({current_subhead})",
                evidence=f"matched={taste_match.group(0)!r} in: {snippet_src}",
                ac_index=ac_state["counter"],
                ac_subhead=current_subhead,
                ac_text=ac_body_text[:200],
            )
        )

    for raw in ac_section.splitlines():
        stripped = raw.strip()
        if re.match(r"^#{2,}\s+\S", stripped):
            if cur_ac_state is not None:
                _check_and_emit(cur_ac_state, cur_ac_body)
            current_subhead = stripped.lstrip("# ").strip()
            counter = 0
            cur_ac_state = None
            cur_ac_body = []
            continue
        m = _AC_LINE_RE.match(raw)
        if m:
            if cur_ac_state is not None:
                _check_and_emit(cur_ac_state, cur_ac_body)
            counter += 1
            body = m.group("body")
            is_reviewer = bool(re.match(r"^\[REVIEWER\]", body.strip(), re.IGNORECASE))
            cur_ac_state = {
                "counter": counter,
                "body_text": body,
                "is_reviewer": is_reviewer,
            }
            cur_ac_body = []
            continue
        if cur_ac_state is not None:
            cur_ac_body.append(raw)
    if cur_ac_state is not None:
        _check_and_emit(cur_ac_state, cur_ac_body)
    return findings


# ───────────── audience-mismatch detector (T-2147, T-2143 leg B) ─────────────
#
# Catches `[REVIEW]` Human ACs whose subject is *agent* experience (stderr the
# agent reads, gate prose the agent trips, CLI output the agent sees). The
# operator has no operational context for those — answering "does this read
# cleanly" requires being the system that hit the gate. The correct routing is
# `### Agent` self-eval, not any Human prefix.
#
# Origin: T-2143 RCA — T-2139 V1 keystone gate-message AC recursed 4 rounds
# because the agent's single-axis routing heuristic (subjective → Human) has
# no audience check. CLAUDE.md §AC Classification Guidance item #6 (T-2148
# shipped 2026-05-31) introduced the audience axis at author-time; this
# detector is the reviewer-time backstop for that rule.

# Agent-as-subject phrasing. Each alt is a *receptive* verb form a `[REVIEW]`
# AC uses when asking about the agent's experience of reading/processing/
# encountering something. The receptive class is the audience-mismatch class
# — only "what the agent *receives*" puts the operator in the wrong seat.
#
# Note (T-2147 corpus walk): "agent files <task|build|child|report|ticket>"
# is architectural NARRATIVE (the agent producing artefacts after a human
# decision), not an audience question. Corpus walk hit 4/5 false-positives
# on `agent files`; the verb was dropped from the regex. The task spec
# listed it; we deviate based on corpus evidence — see Evolution.
_AGENT_AS_SUBJECT_RE = re.compile(
    r"""(?ix)
    \b(
        agent\s+who                            |   # "agent who trips the gate"
        agent\s+(?:reads?|read)                |   # "agent reads stderr"
        agent\s+trips?                         |   # "agent trips"
        agent\s+sees?                          |   # "agent sees the prose"
        agent\s+gets?                          |   # "agent gets the message"
        agent\s+handles?                       |   # "agent handles the bypass"
        agent\s+(?:encounters?|hits?|receives?) |  # "agent encounters / hits / receives X"
        for\s+an\s+agent                       |   # "actionable for an agent"
        # "the agent will <receptive-verb>" — receptive only. "the agent will
        # adjust/fix/file" is architectural narrative (corpus FP class).
        the\s+agent\s+will\s+(?:see|read|get|receive|unblock|encounter|hit|trip) |
        # singular noun + receptive verb within 3 tokens
        \bthe\s+agent\s+\w+\s+(?:reads?|sees?|gets?|trips?|handles?|unblocks?|reading|seeing) |
        # tripping/reading agent — the actor as participial subject
        tripping\s+agent                       |
        reading\s+agent                        |
        # operator-seat phrasing inverted
        "?(?:to|by)\s+(?:a|an|the)\s+agent\s+(?:reading|tripping|seeing|handling)
    )
    """
)

# Human-subject phrasing in the Expected clause. If present, the AC has
# already re-anchored on the operator and audience is *not* mismatched even
# if the body describes the agent-side mechanic.
#
# Discriminator: operator/user/human/you must be the SUBJECT of a verb
# (indicative or passive), not just incidentally named. "stderr makes the
# agent unblock itself without operator help" — operator is a possessive
# modifier of `help`, not a verb subject; agent-audience stays mismatched.
# "you (the operator) confirm the message" — `you` is subject of `confirm`,
# re-anchor satisfied.
_HUMAN_SUBJECT_RE = re.compile(
    r"""(?ix)
    (
        # Subject + verb, with optional parenthetical between:
        \b(?:the\s+)?(?:operator|user|human|reviewer)(?:\s*\([^)]+\))?\s+
            (?:can|should|will|would|must|may|might|sees?|reads?|confirms?|decides?|judges?|approves?|reviews?|checks?|gets?|finds?|notices?|spots?|verifies?|inspects?) |
        # 2nd-person pronoun as subject:
        \byou(?:\s*\([^)]+\))?\s+
            (?:can|should|will|would|must|may|might|see|read|confirm|decide|judge|approve|review|check|get|find|notice|spot|verify|inspect) |
        # Question framing — "does the operator …" / "is the operator able to …"
        (?:does|is|are|can)\s+(?:the\s+)?(?:operator|user|human|you)\b |
        # Explicit audience marker
        audience:\s*operator
    )
    """
)

# Author opt-out markers. Allow the author to say "I know the body looks
# agent-shaped, but I've re-framed it as a question for the operator".
_AUDIENCE_OPT_OUT_RE = re.compile(
    r"""(?ix)
    (
        rewritten\s+to\s+ask\s+(?:the\s+)?human   |
        rewritten\s+to\s+ask\s+(?:the\s+)?operator |
        audience:\s*operator                       |
        framing[- ]question                        |
        meta:\s*audience-rechecked
    )
    """
)


def detect_audience_mismatch(ac_section: str) -> list[Finding]:
    """`[REVIEW]` Human AC whose subject is *agent* experience.

    Five gates, all must hold:
      1. AC sits under `### Human` subhead
      2. AC body starts with `[REVIEW]` (NOT `[REVIEWER]` — that's prose-mismatch's
         territory; the routing-discipline ladder routes `[REVIEWER]` first by
         prose vocabulary, then `[REVIEW]` here by subject audience)
      3. AC body or Expected contains agent-as-subject phrasing
         (`_AGENT_AS_SUBJECT_RE`)
      4. AC's `**Expected:**` clause does NOT describe a human-experience
         question (`_HUMAN_SUBJECT_RE` absent — operator/user/you/human
         haven't been used as subjects to re-anchor the question)
      5. Body has NO author opt-out marker (`_AUDIENCE_OPT_OUT_RE`)

    Heuristic, partial lie-severity → CONCERN, needs_human=no.

    Routing-discipline ladder (CLAUDE.md, T-2143):
      T-1878 — between Human prefixes by check-shape (grep-able → `[REVIEWER]`)
      T-1947 — between [REVIEW] and [REVIEWER] by Expected vocabulary
      T-2143 — out of Human prefixes entirely by audience (this detector)
      T-2147 — reviewer-time backstop (this code)

    Origin: T-2139 V1 keystone gate-message AC. 4 author rounds before the
    audience mismatch was named. Full diagnosis:
      docs/reports/T-2143-routing-recursion-rca.md
    """
    findings: list[Finding] = []
    if not ac_section:
        return findings

    current_subhead = "ACs"
    counter = 0
    cur_ac_body: list[str] = []
    cur_ac_state: dict | None = None

    def _check_and_emit(ac_state: dict, body_lines: list[str]):
        if not ac_state or not ac_state.get("is_review"):
            return
        if "human" not in current_subhead.lower():
            return
        ac_body_text = ac_state["body_text"]
        joined = "\n".join(body_lines)
        haystack = ac_body_text + "\n" + joined

        # Gate 5: author opt-out
        if _AUDIENCE_OPT_OUT_RE.search(haystack):
            return

        # Gate 3: agent-as-subject phrasing present somewhere
        agent_match = _AGENT_AS_SUBJECT_RE.search(haystack)
        if not agent_match:
            return

        # Gate 4: Expected clause does NOT have operator/human subject.
        # Pull the Expected text out separately because the body may describe
        # the agent-side mechanic legitimately as context while the Expected
        # re-anchors on the operator.
        expected_match = re.search(
            r"\*\*Expected:?\*\*\s*(.*?)(?=\n\s*\*\*(?:If\s+not|Steps|Why|Origin)|\Z)",
            joined,
            re.DOTALL | re.IGNORECASE,
        )
        expected_text = expected_match.group(1) if expected_match else ""
        # If Expected re-anchors on a human subject, the AC is correctly framed
        # as an operator question even though the body talks about the agent.
        if expected_text and _HUMAN_SUBJECT_RE.search(expected_text):
            return

        snippet_src = (
            expected_text.strip()[:140] if expected_text else ac_body_text[:140]
        ).replace("\n", " ")
        findings.append(
            Finding(
                pattern_id="audience-mismatch",
                pattern_name="[REVIEW] Human AC asks about agent experience (should be Agent self-eval)",
                detection_confidence="heuristic",
                lie_severity="partial",
                location=f"AC#{ac_state['counter']} ({current_subhead})",
                evidence=f"agent-subject={agent_match.group(0)!r} in: {snippet_src}",
                ac_index=ac_state["counter"],
                ac_subhead=current_subhead,
                ac_text=ac_body_text[:200],
            )
        )

    for raw in ac_section.splitlines():
        stripped = raw.strip()
        if re.match(r"^#{2,}\s+\S", stripped):
            if cur_ac_state is not None:
                _check_and_emit(cur_ac_state, cur_ac_body)
            current_subhead = stripped.lstrip("# ").strip()
            counter = 0
            cur_ac_state = None
            cur_ac_body = []
            continue
        m = _AC_LINE_RE.match(raw)
        if m:
            if cur_ac_state is not None:
                _check_and_emit(cur_ac_state, cur_ac_body)
            counter += 1
            body = m.group("body")
            # [REVIEW] but NOT [REVIEWER] — prose-mismatch handles the latter.
            # Anchor on word boundary so `[REVIEWER]` doesn't match `[REVIEW]`.
            stripped_body = body.strip()
            is_review = bool(re.match(r"^\[REVIEW\](?!\w)", stripped_body, re.IGNORECASE))
            cur_ac_state = {
                "counter": counter,
                "body_text": body,
                "is_review": is_review,
            }
            cur_ac_body = []
            continue
        if cur_ac_state is not None:
            cur_ac_body.append(raw)
    if cur_ac_state is not None:
        _check_and_emit(cur_ac_state, cur_ac_body)
    return findings


# ───────── defer-as-hedge detector (T-2145, T-2144 leg B) ─────────
#
# Catches inception tasks filed with `Recommendation: DEFER` despite the
# research artifact carrying substantive evidence (5-Whys, candidate matrix,
# dialogue log) and the Rationale block being >300 chars. The structural
# fingerprint: evidence-complete + recommendation-hedged. Operator caught
# this in T-2143 ("why do you recommend defer ???"); same family as T-679
# (blank decision) one layer deeper — decision-shaped placeholder.

# Recommendation values to flag. Case-insensitive match of `DEFER` after
# the `**Recommendation:**` marker (with optional bold/colon variations).
_RECOMMENDATION_LINE_RE = re.compile(
    r"\*\*Recommendation:?\*\*\s*[`*]*\s*([A-Za-z][A-Za-z/\- ]+)",
    re.IGNORECASE,
)

# Artifact path inside the Recommendation block — `docs/reports/T-NNNN-*.md`.
_ARTIFACT_PATH_RE = re.compile(
    r"(docs/reports/T-\d+[A-Za-z0-9_\-./]*\.md)",
)

# Evidence indicators inside the research artifact body.
_EVIDENCE_FIVE_WHYS_RE = re.compile(r"^#{1,3}\s*5[- ]Whys?\b", re.IGNORECASE | re.MULTILINE)
_EVIDENCE_DIALOGUE_LOG_RE = re.compile(r"^#{1,3}\s*Dialogue\s+Log\b", re.IGNORECASE | re.MULTILINE)
# Candidate matrix: a Markdown table with header `| Candidate` or
# `| Option` followed by at least 3 row-rule lines. Counted lazily —
# any markdown table with ≥4 rows (1 header + ≥3 data) qualifies.

# Rationale block inside Recommendation. Same lazy delimiter — ends at next
# **Foo:** marker or the section's end.
_RATIONALE_BLOCK_RE = re.compile(
    r"\*\*Rationale:?\*\*\s*(.*?)(?=\n\s*\*\*(?:Evidence|Handoff|Decision|Recommendation|Origin):|\Z)",
    re.DOTALL | re.IGNORECASE,
)


def _count_candidate_matrix_rows(text: str) -> int:
    """Return the largest count of data rows under any candidate/option table.

    A candidate matrix is a Markdown table whose header row mentions
    `Candidate` or `Option` (case-insensitive). Returns the maximum
    data-row count across all such tables in the file.
    """
    max_rows = 0
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        is_table_header = (
            "|" in line
            and re.search(r"\b(candidate|option)\b", line, re.IGNORECASE)
        )
        if is_table_header:
            # Next line should be the markdown rule line `|---|---|...`
            if i + 1 < len(lines) and re.match(r"^\s*\|\s*:?-+", lines[i + 1]):
                # Count consecutive data rows below
                j = i + 2
                rows = 0
                while j < len(lines) and lines[j].lstrip().startswith("|"):
                    rows += 1
                    j += 1
                if rows > max_rows:
                    max_rows = rows
                i = j
                continue
        i += 1
    return max_rows


def detect_defer_as_hedge(
    meta: dict | None,
    body: str,
    task_path: Path,
) -> list[Finding]:
    """Inception filed `DEFER` despite the evidence trail being complete.

    Five gates (all must hold):
      1. `workflow_type: inception` in frontmatter
      2. `## Recommendation` section exists and contains `DEFER` (case-insensitive)
         on the `**Recommendation:**` line
      3. Recommendation section references a `docs/reports/T-NNNN-*.md` artifact
      4. That artifact exists on disk AND contains ≥1 of:
         - `## 5-Whys` heading
         - `## Dialogue Log` heading
         - A candidate/option matrix with ≥3 data rows
      5. The `**Rationale:**` block inside Recommendation is >300 chars
         (substantive evidence-supported reasoning, not a one-line punt)

    Heuristic, partial lie-severity → CONCERN, needs_human=no.

    Origin: T-2144 RCA — T-2143 filed `DEFER` with full evidence (5-Whys,
    4-candidate matrix, dialogue log); operator caught in one question.
    Full diagnosis: `docs/reports/T-2144-defer-as-hedge-rca.md`.
    """
    findings: list[Finding] = []
    if not meta or meta.get("workflow_type") != "inception":
        return findings

    rec_section = extract_section(body, "Recommendation")
    if not rec_section:
        return findings

    # Gate 2: DEFER on the Recommendation line
    rec_match = _RECOMMENDATION_LINE_RE.search(rec_section)
    if not rec_match:
        return findings
    rec_value = rec_match.group(1).strip().upper()
    # "DEFER" or "DEFERRED" — anything that starts with DEFER. Exclude
    # forms like "DEFER (historical — …)" that explicitly mark themselves
    # as superseded; that pattern is the legitimate revisit-trigger shape.
    if not rec_value.startswith("DEFER"):
        return findings
    # Exempt "DEFER (historical" / "DEFER (superseded" / "DEFER — historical"
    rec_line_full = rec_match.group(0) + rec_section[rec_match.end():rec_match.end() + 120]
    if re.search(r"DEFER[^\n]{0,30}(historical|superseded)", rec_line_full, re.IGNORECASE):
        return findings

    # Gate 3: artifact path present
    artifact_match = _ARTIFACT_PATH_RE.search(rec_section)
    if not artifact_match:
        return findings
    artifact_rel = artifact_match.group(1)

    # Gate 4: artifact exists and contains ≥1 evidence indicator
    # Resolve relative to PROJECT_ROOT (task_path's repo root).
    repo_root = task_path.parent
    while repo_root != repo_root.parent and not (repo_root / "policy").is_dir():
        repo_root = repo_root.parent
    artifact_path = repo_root / artifact_rel
    if not artifact_path.is_file():
        return findings
    try:
        artifact_text = artifact_path.read_text()
    except OSError:
        return findings

    has_5whys = bool(_EVIDENCE_FIVE_WHYS_RE.search(artifact_text))
    has_dialogue = bool(_EVIDENCE_DIALOGUE_LOG_RE.search(artifact_text))
    candidate_rows = _count_candidate_matrix_rows(artifact_text)
    has_candidate_matrix = candidate_rows >= 3
    # Corpus walk (T-2147 lesson): the task spec said ≥1 indicator, but the
    # 2119-file walk found 4 false-positives at that threshold — all legitimate
    # DEFER-with-sequence-planning or sovereignty-pending cases that happened
    # to have a Dialogue Log. The T-2143 origin pattern had ≥2 indicators
    # (5-Whys + Dialogue Log + a matrix-shaped table). Require ≥2 to weed out
    # the false-positives. Deviation from task spec documented in Evolution.
    indicator_count = sum([has_5whys, has_dialogue, has_candidate_matrix])
    if indicator_count < 2:
        return findings

    # Gate 5: Rationale block >300 chars
    rationale_match = _RATIONALE_BLOCK_RE.search(rec_section)
    rationale_text = rationale_match.group(1).strip() if rationale_match else ""
    if len(rationale_text) <= 300:
        return findings

    evidence_parts = []
    if has_5whys:
        evidence_parts.append("5-Whys")
    if has_dialogue:
        evidence_parts.append("Dialogue Log")
    if has_candidate_matrix:
        evidence_parts.append(f"candidate matrix ({candidate_rows} rows)")
    evidence_summary = ", ".join(evidence_parts)

    findings.append(
        Finding(
            pattern_id="defer-as-hedge",
            pattern_name="Inception DEFER despite complete evidence trail (T-2144)",
            detection_confidence="heuristic",
            lie_severity="partial",
            location="## Recommendation",
            evidence=(
                f"artifact={artifact_rel}; "
                f"indicators=[{evidence_summary}]; "
                f"rationale={len(rationale_text)} chars"
            ),
            ac_index=None,
            ac_subhead=None,
            ac_text=None,
        )
    )
    return findings


# ───────── disposition-incomplete detector (T-2191, T-2186 slice 5) ─────────
#
# Inception `## Open Questions` discipline (per 050-Inceptions.md §Disposition
# Gate). Each declared `- **IW-N:**` entry must carry:
#   - `disposition:` line with value ∈ {answered, deferred, dissolved}
#   - `rationale:` line with content
#   - When disposition is `answered`, rationale must cite evidence (file:line,
#     T-NNNN, docs/reports/..., or G-/L-/D-NNN id)
#
# This catches the inception-side family that T-2145 catches in Recommendation:
# decision-without-evidence. defer-as-hedge fires on Recommendation DEFER + full
# artifact + substantive rationale; disposition-incomplete fires on per-question
# laxity (missing fields, bare yes/no, answered-without-citation). Sibling shape.
# Both are partial-CONCERN heuristics; the disposition gate (T-2190, completion-
# time) is the structural enforcement; this detector is the static-scan layer.

_IW_ENTRY_RE = re.compile(
    r"^\s*-\s*\*\*IW-(\d+):\s*(.*?)\*\*\s*$",
    re.MULTILINE,
)

_VALID_DISPOSITIONS = {"answered", "deferred", "dissolved"}

# Evidence citation patterns inside a rationale line.
_CITATION_PATTERNS = [
    re.compile(r"\bT-\d+\b"),                                   # task ref
    re.compile(r"docs/reports/T-\d+"),                          # research artifact
    re.compile(r"\b[GLD]-\d+\b"),                               # gap / learning / decision
    re.compile(r"[\w\-./]+\.\w+:\d+"),                          # file:line
    re.compile(r"[\w\-./]+\.\w+#L\d+"),                         # file#Lnnn
    re.compile(r"\bdialogue[\s-]?log\b", re.IGNORECASE),        # dialogue ref
    re.compile(r"\b(?:commit|sha|hash)[:\s][0-9a-f]{6,}", re.IGNORECASE),  # commit ref
]


def _has_citation(text: str) -> bool:
    return any(p.search(text) for p in _CITATION_PATTERNS)


def detect_disposition_completeness(
    meta: dict | None,
    body: str,
    task_path: Path,
) -> list[Finding]:
    """Per-question disposition-completeness check on inception Open Questions.

    Returns one Finding per malformed IW-N (verdict-level, ac_index=None).
    Severity: partial CONCERN, heuristic.

    Gates (file-level):
      1. `workflow_type: inception` in frontmatter
      2. `## Open Questions` section exists in body
      3. ≥1 `- **IW-N:**` entry declared (grandfathers empty/template sections)

    Per-entry checks:
      A. `disposition:` line exists
      B. disposition value ∈ {answered, deferred, dissolved}
      C. `rationale:` line exists with non-empty content
      D. When disposition=answered, rationale carries an evidence citation
    """
    findings: list[Finding] = []
    if not meta or meta.get("workflow_type") != "inception":
        return findings

    oq_section = extract_section(body, "Open Questions")
    if not oq_section:
        return findings

    # Find IW-N entries and slice each entry's lines
    entries: list[tuple[int, str, int]] = []  # (iw_n, entry_text, start_line)
    lines = oq_section.splitlines()
    current_iw: int | None = None
    current_lines: list[str] = []
    current_start = 0
    for idx, line in enumerate(lines):
        m = re.match(r"^\s*-\s*\*\*IW-(\d+):", line)
        if m:
            if current_iw is not None:
                entries.append((current_iw, "\n".join(current_lines), current_start))
            current_iw = int(m.group(1))
            current_lines = [line]
            current_start = idx
        elif current_iw is not None:
            # Stop accumulating at the next top-level list item (different IW or section)
            if re.match(r"^\s*-\s*\*\*[A-Z]", line) and not line.lstrip().startswith("- **IW-"):
                # not another IW — close out
                entries.append((current_iw, "\n".join(current_lines), current_start))
                current_iw = None
                current_lines = []
            else:
                current_lines.append(line)
    if current_iw is not None:
        entries.append((current_iw, "\n".join(current_lines), current_start))

    if not entries:
        return findings

    for iw_n, entry_text, _start in entries:
        # Check A/B: disposition line
        disp_match = re.search(r"^\s*disposition:\s*(\S+)", entry_text, re.MULTILINE)
        rat_match = re.search(r"^\s*rationale:\s*(.+?)$", entry_text, re.MULTILINE)

        if not disp_match:
            findings.append(
                Finding(
                    pattern_id="disposition-incomplete",
                    pattern_name="Inception IW-N missing disposition (T-2191)",
                    detection_confidence="heuristic",
                    lie_severity="partial",
                    location=f"## Open Questions: IW-{iw_n}",
                    evidence=f"IW-{iw_n}: no `disposition:` line",
                    ac_index=None,
                )
            )
            continue

        disp_value = disp_match.group(1).strip().lower().rstrip(",.;")
        if disp_value not in _VALID_DISPOSITIONS:
            findings.append(
                Finding(
                    pattern_id="disposition-incomplete",
                    pattern_name="Inception IW-N invalid disposition value (T-2191)",
                    detection_confidence="heuristic",
                    lie_severity="partial",
                    location=f"## Open Questions: IW-{iw_n}",
                    evidence=(
                        f"IW-{iw_n}: disposition='{disp_value}' "
                        f"(must be one of {sorted(_VALID_DISPOSITIONS)})"
                    ),
                    ac_index=None,
                )
            )
            continue

        # Check C: rationale present + non-empty
        if not rat_match or not rat_match.group(1).strip():
            findings.append(
                Finding(
                    pattern_id="disposition-incomplete",
                    pattern_name="Inception IW-N missing rationale (T-2191)",
                    detection_confidence="heuristic",
                    lie_severity="partial",
                    location=f"## Open Questions: IW-{iw_n}",
                    evidence=f"IW-{iw_n} disposition='{disp_value}': no/empty `rationale:` line",
                    ac_index=None,
                )
            )
            continue

        # Check D: answered without citation (sibling to T-2145 decision-without-evidence)
        rationale = rat_match.group(1).strip()
        if disp_value == "answered" and not _has_citation(rationale):
            findings.append(
                Finding(
                    pattern_id="disposition-incomplete",
                    pattern_name="Inception IW-N answered-without-citation (T-2191, sibling of T-2145)",
                    detection_confidence="heuristic",
                    lie_severity="partial",
                    location=f"## Open Questions: IW-{iw_n}",
                    evidence=(
                        f"IW-{iw_n} disposition='answered' but rationale has no "
                        f"evidence citation (T-NNNN, file:line, docs/reports/, "
                        f"G-/L-/D-id, dialogue-log, or commit hash)"
                    ),
                    ac_index=None,
                )
            )

    return findings


# ───────── review-link-homework detector (T-2140, T-2138 V2) ─────────
#
# Catches the review-handoff homework pattern in `### Human` ACs: Steps
# that ask the reviewer to construct a URL themselves (`URL from bin/fw
# watchtower url`, `base from bin/fw watchtower url`, `(Watchtower URL from`)
# instead of emitting a full clickable URL. Origin: T-2109 surfaced the
# pattern; T-2138 RCA documented 7 historical sites + same-session
# self-demonstration; T-2139 ships the transition-time blocking gate;
# this detector is the catch-before-handoff backstop (Candidate B in
# T-2138's matrix).
#
# Scope rules (corpus-tuned):
#   - Only fires under `### Human` subhead — Agent ACs and Verification
#     legitimately reference paths
#   - Three named patterns; opt-out marker for documentation-meta tasks
#     (the catalogue + RCA + V1 gate task themselves use the literals)
#   - Per-AC granularity so overrides can target a specific AC

# Three named homework-pattern literals from T-2138 §Symptom + 5-Whys.
# Case-insensitive; backtick around `bin/fw watchtower url` is optional
# (markdown rendering doesn't always preserve them across edits).
_REVIEW_LINK_HOMEWORK_RE = re.compile(
    r"""(?ix)
    (
        URL\s+from\s+`?bin/fw\s+watchtower\s+url`?      |
        base\s+from\s+`?bin/fw\s+watchtower\s+url`?     |
        \(\s*Watchtower\s+URL\s+from
    )
    """
)

# Author opt-out: documentation/RCA/gate-build tasks that legitimately
# discuss the pattern itself need a marker to avoid self-flagging.
# Mirror the audience-mismatch shape (T-2147).
_REVIEW_LINK_OPT_OUT_RE = re.compile(
    r"""(?ix)
    (
        review-link-homework-ok                |
        meta:\s*review-link-homework-discussed |
        documents\s+the\s+homework\s+pattern
    )
    """
)


def detect_review_link_homework(ac_section: str) -> list[Finding]:
    """`### Human` AC whose Steps/body contain review-handoff homework patterns.

    Three gates, all must hold per AC:
      1. AC sits under `### Human` subhead
      2. AC body or trailing Steps/Expected/If-not lines contain one of
         the three named homework patterns (`_REVIEW_LINK_HOMEWORK_RE`)
      3. AC has NO author opt-out marker (`_REVIEW_LINK_OPT_OUT_RE`) —
         for the documentation-meta task class (T-2138 RCA, T-2139
         gate-build, T-2140 catalogue, T-2030 origin all reference the
         literal strings in their own bodies)

    Heuristic, partial lie-severity → CONCERN, needs_human=no.

    Class lineage:
      T-2030 — origin inception (`/appearance` vs `/settings/appearance`,
               the wrong-URL class)
      T-2050 — Candidate C build (advisory app.url_map validation; left
               the absence-of-URL class unhandled, CTL-027)
      T-2109 — recurrence that prompted T-2138 RCA
      T-2138 — RCA + candidate matrix (DEFER until operator pick)
      T-2139 — V1 keystone: transition-time blocking gate (shipped)
      T-2140 — V2 companion: this detector (catch-before-handoff backstop)

    Origin diagnosis: docs/reports/T-2138-review-handoff-author-time-gap.md.
    """
    findings: list[Finding] = []
    if not ac_section:
        return findings

    current_subhead = "ACs"
    counter = 0
    cur_ac_body: list[str] = []
    cur_ac_state: dict | None = None

    def _check_and_emit(ac_state: dict, body_lines: list[str]):
        if not ac_state:
            return
        if "human" not in current_subhead.lower():
            return
        ac_body_text = ac_state["body_text"]
        joined = "\n".join(body_lines)
        haystack = ac_body_text + "\n" + joined

        # Gate 3: author opt-out (documentation-meta class)
        if _REVIEW_LINK_OPT_OUT_RE.search(haystack):
            return

        # Gate 2: homework pattern present
        match = _REVIEW_LINK_HOMEWORK_RE.search(haystack)
        if not match:
            return

        snippet = match.group(0).strip().replace("\n", " ")
        findings.append(
            Finding(
                pattern_id="review-link-homework",
                pattern_name="`### Human` AC Steps require constructing URL instead of clickable link (T-2138)",
                detection_confidence="heuristic",
                lie_severity="partial",
                location=f"AC#{ac_state['counter']} ({current_subhead})",
                evidence=f"homework-pattern={snippet!r}",
                ac_index=ac_state["counter"],
                ac_subhead=current_subhead,
                ac_text=ac_body_text[:200],
            )
        )

    for raw in ac_section.splitlines():
        stripped = raw.strip()
        if re.match(r"^#{2,}\s+\S", stripped):
            if cur_ac_state is not None:
                _check_and_emit(cur_ac_state, cur_ac_body)
            current_subhead = stripped.lstrip("# ").strip()
            counter = 0
            cur_ac_state = None
            cur_ac_body = []
            continue
        m = _AC_LINE_RE.match(raw)
        if m:
            if cur_ac_state is not None:
                _check_and_emit(cur_ac_state, cur_ac_body)
            counter += 1
            body = m.group("body")
            cur_ac_state = {
                "counter": counter,
                "body_text": body,
            }
            cur_ac_body = []
            continue
        if cur_ac_state is not None:
            cur_ac_body.append(raw)
    if cur_ac_state is not None:
        _check_and_emit(cur_ac_state, cur_ac_body)
    return findings


# ───────────────── L-387 SIGPIPE detector (T-2059) ─────────────────
#
# Catches the verification anti-pattern `<streaming-cmd> | grep -q "PATTERN"`
# which exits 141 under `set -eo pipefail` when grep matches early. Captured
# 7+ times in S-2026-0526..-0527 (T-1716, T-1838, T-1862, T-1863, T-2008,
# T-1701, T-1707) before T-2057 inception filed and T-2059 build shipped.
# Spike: docs/reports/T-2057-l-387-detector-spike.md.

# Terminal `| grep -q` (or `| grep -qE`, `| grep --quiet`) at end of line or
# followed only by quoted/regex argument. Captures the upstream text in g1.
_L387_TERMINAL_RE = re.compile(
    r"^(.*?)\|\s*grep\s+(?:-\w*[qQ]\w*|--quiet)\s+",
)

# Upstream forms that are SIGPIPE-immune (finite, bounded output):
#   - `echo "$..." | grep -q ...`       (already captured)
#   - `printf "..." | grep -q ...`      (formatted, bounded)
#   - `echo word | grep -q ...`         (literal word)
#   - `cat file | grep -q ...`          (cat from disk file — finite & seekable)
#   - leading `[`/`test`                — these are conditional, not pipelines
# Detector exempts these as the "safe form" / "irrelevant form".
_L387_SAFE_UPSTREAM_RE = re.compile(
    r"(?:^|\|\s*)(?:echo|printf)\s",
)


def detect_l387_sigpipe_risk(verification_section: str) -> list[Finding]:
    """L-387 SIGPIPE risk: streaming command piped into terminal `grep -q`.

    Heuristic: a verification line contains `| grep -q[E]?` (terminal grep
    silently-matching), AND the upstream of that pipe is NOT `echo`/`printf`
    (the SIGPIPE-immune capture pattern). Flagged because under `set -eo
    pipefail` the grep closing stdin propagates SIGPIPE → upstream exits 141
    → pipefail fails the verification command even though the pattern matched.

    Safe rewrite (documented in policy/anti-patterns.yaml description):
        out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
        # or
        cmd > /tmp/.out 2>&1; grep -q "PATTERN" /tmp/.out

    False-positive guard: lines starting with `#` (comments) and lines whose
    upstream is `echo`/`printf` are exempted.
    """
    findings: list[Finding] = []
    if not verification_section:
        return findings
    for lineno, raw in enumerate(verification_section.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = _L387_TERMINAL_RE.search(line)
        if not m:
            continue
        upstream = m.group(1).strip()
        # The "upstream" here is everything to the left of the terminal
        # `| grep -q`. Find the LAST stage of that pipeline — that is the
        # actual stdout source for grep.
        # Examples:
        #   "out=$(cmd); echo \"$out\""  → last stage = `echo "$out"`  → safe
        #   "bin/fw doctor 2>&1"          → last stage = `bin/fw doctor` → flag
        #   "bin/fw doctor 2>&1 | wc -l"  → last stage = `wc -l`         → flag (wc still streams)
        # Use the last `|` in the upstream to split, fall back to whole.
        # Note: `;` separator means previous statement already ran; the actual
        # upstream-of-grep is the part AFTER the last `;`.
        last_stmt = re.split(r";\s*", upstream)[-1].strip()
        # Last pipeline stage:
        last_stage = re.split(r"\|\s*(?![^(]*\))", last_stmt)[-1].strip()
        # Safe shapes — echo / printf last stage means grep reads a bounded buffer.
        if re.match(r"^(echo|printf)\b", last_stage):
            continue
        findings.append(
            Finding(
                pattern_id="l387-sigpipe-risk",
                pattern_name="L-387 SIGPIPE-prone pipe to terminal grep -q",
                detection_confidence="heuristic",
                # `partial` keeps the verdict at CONCERN, not FAIL. False-negative
                # class: commands with short bounded output (`fw upgrade --help`)
                # finish writing before grep closes stdin, so SIGPIPE never fires
                # in practice. A FAIL on all 280 corpus-flagged lines would be
                # too aggressive; CONCERN surfaces the risk without blocking close.
                lie_severity="partial",
                location=f"Verification:line {lineno}",
                evidence=line[:200],
            )
        )
    return findings


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
        # T-1579: subhead detection — was `startswith("##{2,}")` (literal string,
        # never matches `### Agent` / `### Human`). The bug left current_subhead
        # stuck at "ACs", so Findings reported `ac_subhead="ACs"` and the
        # "skip Human ACs" branch in detect_ac_verify_mismatch never fired.
        if re.match(r"^#{2,}\s+\S", raw.strip()):
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
                # T-1579: Python-import exemption — `from a.b.c import X` directly
                # exercises a/b/c.py (verbatim path doesn't appear in verif text).
                if _path_python_import_covered(path, verif_text):
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


# ───────── ac-evidence-untick detector (T-2155, T-1761 prevention) ─────────
#
# Catches the recurring "agent finishes the work, forgets the tick" pattern.
# T-1761 origin: an `### Agent` AC reading
#     "[ ] Inception: evaluate ... ; produce go/no-go in research artifact
#      docs/reports/T-1761-auto-classify-heuristic.md"
# pointed at an artifact that existed on disk with a complete
# `**Recommendation:** GO` block — yet the box stayed `[ ]`, and the
# Watchtower decide flow refused to record the decision. Agent ticked
# manually post-block (after-the-fact pattern T-1831 C-4 explicitly calls
# out).
#
# Gap analysis: the existing reviewer catalogue covers neighbour classes
# but not this one. `detect_ac_verify_mismatch` fires on **ticked** ACs
# whose path verification doesn't touch (opposite direction);
# `detect_defer_as_hedge` fires on inception `Recommendation:DEFER` with
# complete evidence; T-1985 auto-tick automatically ticks `[REVIEWER]`-
# prefix Agent ACs. None of them see an unticked **plain** Agent AC
# whose deliverable plainly exists.
#
# Scope rules (corpus-tuned):
#   - Only fires under `### Agent` subhead — Human ACs verify by hand
#   - Skips `[REVIEWER]`-prefix ACs (auto-tick T-1985 owns those)
#   - Requires a `docs/reports/T-NNNN-*.md` reference in the AC text —
#     narrows to the explicit-artifact pattern T-1761 exhibited
#   - Requires the referenced artifact to exist on disk AND show
#     substantive content (Recommendation marker OR ≥1500 bytes)
#   - Author opt-out marker `ac-evidence-untick-ok` exempts when the AC
#     genuinely wants to wait (e.g. the artifact exists but human review
#     is still in flight)


_REVIEWER_PREFIX_RE = re.compile(r"^\s*\[REVIEWER\]", re.IGNORECASE)

# Author opt-out marker — mirror defer-as-hedge / audience-mismatch shape.
_AC_EVIDENCE_OPT_OUT_RE = re.compile(
    r"""(?ix)
    (
        ac-evidence-untick-ok                  |
        meta:\s*ac-evidence-pending            |
        documents\s+the\s+untick\s+pattern
    )
    """
)

# Substantive-content markers inside the referenced artifact.
_ARTIFACT_RECOMMENDATION_RE = re.compile(
    r"\*\*Recommendation:?\*\*", re.IGNORECASE
)
_ARTIFACT_RECOMMENDATION_HEADING_RE = re.compile(
    r"^#{1,3}\s+Recommendation\b", re.IGNORECASE | re.MULTILINE
)


def detect_ac_evidence_untick(
    ac_section: str,
    task_path: Path,
) -> list[Finding]:
    """Unticked `### Agent` AC names an artifact that already carries substantive content.

    Six gates (all must hold per AC):
      1. AC sits under `### Agent` subhead
      2. AC line is unticked (`- [ ]`)
      3. AC text does NOT start with `[REVIEWER]` (T-1985 auto-tick territory)
      4. AC text references a `docs/reports/T-NNNN-*.md` path
      5. That artifact exists on disk AND shows substantive content:
         - contains a `**Recommendation:**` line, OR
         - contains a `## Recommendation` heading (or `### Recommendation`), OR
         - file size ≥ 1500 bytes (proxy for "non-skeleton")
      6. AC body has no opt-out marker (`ac-evidence-untick-ok`)

    Heuristic confidence, partial lie-severity → CONCERN, needs_human=no.

    Origin: T-1761 (S-2026-0601) — manual unblock after Watchtower decide
    flow refused. Closes the gap between `detect_ac_verify_mismatch`
    (ticked + path) and `_should_auto_tick` ([REVIEWER]-prefix only).
    """
    findings: list[Finding] = []
    if not ac_section:
        return findings

    # Resolve repo root once for artifact-path resolution.
    repo_root = task_path.parent
    while repo_root != repo_root.parent and not (repo_root / "policy").is_dir():
        repo_root = repo_root.parent

    counter = 0
    current_subhead = "ACs"
    in_agent = False
    for raw in ac_section.splitlines():
        # T-1579 subhead detection
        if re.match(r"^#{2,}\s+\S", raw.strip()):
            current_subhead = raw.strip().lstrip("# ").strip()
            in_agent = current_subhead.lower() == "agent"
            counter = 0
            continue
        m = _AC_LINE_RE.match(raw)
        if not m:
            continue
        counter += 1
        # Gate 1
        if not in_agent:
            continue
        # Gate 2
        if m.group("state").lower() == "x":
            continue
        body_text = m.group("body")
        # Gate 3
        if _REVIEWER_PREFIX_RE.match(body_text):
            continue
        # Gate 6 (cheap structural check on the AC body)
        if _AC_EVIDENCE_OPT_OUT_RE.search(body_text):
            continue
        # Gate 4
        art_match = _ARTIFACT_PATH_RE.search(body_text)
        if not art_match:
            continue
        artifact_rel = art_match.group(1)
        # Gate 5
        artifact_path = repo_root / artifact_rel
        if not artifact_path.is_file():
            continue
        try:
            stat_result = artifact_path.stat()
            artifact_text = artifact_path.read_text()
        except OSError:
            continue
        has_rec_line = bool(_ARTIFACT_RECOMMENDATION_RE.search(artifact_text))
        has_rec_heading = bool(
            _ARTIFACT_RECOMMENDATION_HEADING_RE.search(artifact_text)
        )
        is_substantive_size = stat_result.st_size >= 1500
        if not (has_rec_line or has_rec_heading or is_substantive_size):
            continue

        evidence_markers = []
        if has_rec_line:
            evidence_markers.append("Recommendation: line")
        if has_rec_heading:
            evidence_markers.append("## Recommendation heading")
        if is_substantive_size:
            evidence_markers.append(f"size={stat_result.st_size}B")

        findings.append(
            Finding(
                pattern_id="ac-evidence-untick",
                pattern_name="Agent AC references existing artifact but checkbox unticked (T-2155)",
                detection_confidence="heuristic",
                lie_severity="partial",
                location=f"AC#{counter} ({current_subhead})",
                evidence=(
                    f"artifact={artifact_rel}; "
                    f"markers=[{', '.join(evidence_markers)}]; "
                    f"ac={body_text[:140]}"
                ),
                ac_index=counter,
                ac_subhead=current_subhead,
                ac_text=body_text.strip()[:200],
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
    # v1.3-seed +1: T-1896 — [REVIEW] mechanical-Expected catch (T-1878 B)
    findings.extend(detect_human_ac_mechanical_signal(ac_section))
    # v1.4 +1: T-1947 — [REVIEWER] prose-Expected catch (L-409, inverse of above)
    findings.extend(detect_reviewer_prose_mismatch(ac_section))
    # v1.5 +1: T-2059 — L-387 SIGPIPE detector (closes 7+ historical captures)
    findings.extend(detect_l387_sigpipe_risk(verif_section))
    # v1.6 +1: T-2147 — audience-mismatch (T-2143 leg B); reviewer-time
    # backstop for CLAUDE.md §AC Classification audience axis (T-2148).
    findings.extend(detect_audience_mismatch(ac_section))
    # v1.6 +2: T-2145 — defer-as-hedge (T-2144 leg B); inception with
    # complete evidence but recommendation hedged to DEFER.
    findings.extend(detect_defer_as_hedge(meta, body, task_path))
    # v1.6 +2b: T-2191 — disposition-incomplete (T-2186 slice 5); per-question
    # discipline on inception ## Open Questions: missing/invalid disposition,
    # missing rationale, or `answered` without evidence citation.
    findings.extend(detect_disposition_completeness(meta, body, task_path))
    # v1.6 +3: T-2140 — review-link-homework (T-2138 V2); catch-before-handoff
    # backstop for Human AC Steps that ask the reviewer to construct a URL.
    findings.extend(detect_review_link_homework(ac_section))
    # v1.6 +4: T-2155 — ac-evidence-untick (T-1761 prevention); Agent AC
    # plainly references an existing artifact but the checkbox is still `[ ]`.
    findings.extend(detect_ac_evidence_untick(ac_section, task_path))

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
# T-1519: terminate at any heading level ≥ H2 (#{2,}or ### or deeper), not just
# H2. update-task.sh appends `##{2,}timestamp` Updates entries at EOF after the
# verdict was first written — re-scanning would otherwise nuke them.
_VERDICT_SECTION_RE = re.compile(
    r"^## Reviewer Verdict \(v[0-9.]+\)\s*\n(.*?)(?=^#{2,} |\Z)",
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
    # v1.5: auto-ticked [REVIEWER] Agent ACs (T-1985)
    if verdict.auto_ticked:
        lines.append("")
        lines.append(f"- **Auto-ticked:** {len(verdict.auto_ticked)} AC(s)")
        for entry in verdict.auto_ticked:
            excerpt = entry.get("text_excerpt", "")[:80]
            lines.append(f"  - AC #{entry['ac_index']}: {entry['digest']} [{excerpt}]")
    lines.append("")
    return "\n".join(lines)


def write_verdict_to_task(
    task_path: Path,
    verdict: Verdict,
    ac_mutations: list[tuple[str, str]] | None = None,
) -> None:
    """Replace Reviewer Verdict section and apply AC checkbox mutations atomically.

    v1.5 narrowed sovereignty invariant: Human ACs and non-[REVIEWER]-prefixed Agent
    ACs are NEVER modified. [REVIEWER]-prefixed Agent ACs in active/ tasks MAY be
    ticked when all five evidence conditions hold (see _should_auto_tick).
    Writes via os.replace for atomicity.
    """
    text = task_path.read_text()

    # Apply AC checkbox mutations first (before verdict replacement)
    if ac_mutations:
        text = _apply_ac_mutations(text, ac_mutations)

    new_section = render_verdict_md(verdict)
    if _VERDICT_SECTION_RE.search(text):
        new_text = _VERDICT_SECTION_RE.sub(new_section, text)
    else:
        sep = "" if text.endswith("\n") else "\n"
        new_text = text + sep + "\n" + new_section

    # Atomic write
    tmp_path = task_path.with_suffix(".tmp")
    try:
        tmp_path.write_text(new_text)
        os.replace(tmp_path, task_path)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink(missing_ok=True)
        raise


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
    stream = project_root / ".context" / "working" / "feedback-stream.yaml"

    if not no_write:
        # v1.5: compute auto-ticks for [REVIEWER] Agent ACs (active/ tasks only)
        ticked_info, ac_mutations = _compute_auto_ticks(
            task_file, verdict.task_id, verdict, overrides, stream
        )
        verdict.auto_ticked = ticked_info

        write_verdict_to_task(task_file, verdict, ac_mutations=ac_mutations or None)

        # Feedback-stream events
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
                    "auto_ticked_count": len(ticked_info),
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
        # v1.5: sovereignty-rail entries for each ticked AC
        for entry in ticked_info:
            digest = entry["digest"]
            ac_index = entry["ac_index"]
            append_feedback_event(
                stream,
                {
                    "kind": "auto_tick",
                    "timestamp": verdict.timestamp,
                    "scan_id": verdict.scan_id,
                    "task_id": verdict.task_id,
                    "payload": {
                        "key": f"auto_tick:{verdict.task_id}:{ac_index}:{digest}",
                        "ac_index": ac_index,
                        "digest": digest,
                        "text_excerpt": entry.get("text_excerpt", ""),
                    },
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
