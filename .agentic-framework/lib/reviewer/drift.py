"""Pass A drift detection (T-1483 v1.5).

Cheap signal layer: extract file references from a task's `## Verification`
block, hash the referenced files in the current repo, compare against
hashes recorded at completion time. Surfaces "verification target may
have drifted" without re-execution.

Used as a gate over Pass B (lib/reviewer/reverify.py): tasks where Pass A
sees no drift can skip the expensive worktree re-execution.

Public API:
    extract_file_refs(verification_text: str, repo_root: Path) -> set[Path]
    compute_hashes(refs: set[Path], repo_root: Path) -> dict[str, str]
    DriftReport (dataclass)
    detect_drift(task_path: Path, repo_root: Path) -> DriftReport
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from pathlib import Path

from .static_scan import extract_section, parse_task_file


# File reference extraction
# Matches: relative paths starting with ./ or just dir/file.ext, absolute paths,
# and common stems mentioned in test/grep/python -c contexts.
_FILE_REF_PATTERNS = [
    # quoted paths inside python -c '...'
    re.compile(r"""['"]([\w./_\-]+\.[a-zA-Z0-9]{1,8})['"]"""),
    # bare paths in test/grep/cat/etc — must contain a / or end with extension
    re.compile(r"\b([a-zA-Z0-9_./\-]+\.[a-zA-Z0-9]{1,8})\b"),
    # dir-style: bin/fw, agents/foo/bar.sh
    re.compile(r"\b((?:bin|lib|agents|policy|tests|docs|web|deploy|.context|.tasks)/[\w./\-]+)\b"),
]

# Tokens to filter out (e.g. shell builtins that look like paths)
_EXCLUDE = {
    ".",
    "..",
    "...",
    "/dev/null",
    "/tmp",
    "/etc",
}


@dataclass
class DriftReport:
    task_id: str
    referenced_files: list[str] = field(default_factory=list)
    unchanged: list[str] = field(default_factory=list)
    changed: list[str] = field(default_factory=list)
    missing: list[str] = field(default_factory=list)  # referenced but no longer in tree
    no_baseline: list[str] = field(default_factory=list)  # no recorded hash
    has_drift: bool = False  # True if changed or missing is non-empty

    def to_dict(self) -> dict:
        return {
            "task_id": self.task_id,
            "referenced_files": self.referenced_files,
            "unchanged": self.unchanged,
            "changed": self.changed,
            "missing": self.missing,
            "no_baseline": self.no_baseline,
            "has_drift": self.has_drift,
        }

    def render(self) -> str:
        """Human-readable report."""
        lines = [f"Drift report — {self.task_id}"]
        lines.append(f"  Referenced files: {len(self.referenced_files)}")
        lines.append(f"  Unchanged:        {len(self.unchanged)}")
        lines.append(f"  Changed:          {len(self.changed)}")
        lines.append(f"  Missing:          {len(self.missing)}")
        lines.append(f"  No baseline:      {len(self.no_baseline)}")
        if self.changed:
            lines.append("\n  Changed files:")
            for f in self.changed:
                lines.append(f"    - {f}")
        if self.missing:
            lines.append("\n  Missing files (referenced but no longer in tree):")
            for f in self.missing:
                lines.append(f"    - {f}")
        verdict = "DRIFT" if self.has_drift else "STABLE"
        lines.append(f"\n  Verdict: {verdict}")
        return "\n".join(lines)


def extract_file_refs(verification_text: str, repo_root: Path) -> set[Path]:
    """Pull plausible file references out of a verification block.

    Heuristic only — favours recall over precision. The caller filters
    by `path.exists()` so false positives are harmless (they show up as
    `missing` in the report, distinguishable from genuine deletions by
    not appearing in `referenced_files` baseline).
    """
    if not verification_text:
        return set()

    candidates: set[str] = set()
    for line in verification_text.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        for pat in _FILE_REF_PATTERNS:
            for m in pat.finditer(s):
                candidate = m.group(1)
                if candidate in _EXCLUDE:
                    continue
                # Strip leading ./
                if candidate.startswith("./"):
                    candidate = candidate[2:]
                # Filter trivial false positives
                if candidate.endswith("."):
                    continue
                if " " in candidate:
                    continue
                candidates.add(candidate)

    # Resolve to repo paths that exist; keep relative form
    resolved: set[Path] = set()
    for c in candidates:
        p = (repo_root / c) if not Path(c).is_absolute() else Path(c)
        try:
            if p.is_file():
                resolved.add(Path(c))
        except (OSError, ValueError):
            continue
    return resolved


def compute_hashes(refs: set[Path], repo_root: Path) -> dict[str, str]:
    """SHA-256 hash for each file. Missing files map to empty string."""
    out: dict[str, str] = {}
    for ref in refs:
        full = (repo_root / ref) if not ref.is_absolute() else ref
        try:
            h = hashlib.sha256()
            with open(full, "rb") as fh:
                for chunk in iter(lambda: fh.read(65536), b""):
                    h.update(chunk)
            out[str(ref)] = h.hexdigest()
        except (OSError, FileNotFoundError):
            out[str(ref)] = ""
    return out


# Baseline storage in task body
# We embed the baseline inside the existing `## Reviewer Verdict` section as
# a `<!-- drift-baseline: {json} -->` HTML comment so it's invisible in
# rendered Markdown but recoverable on re-scan.
_BASELINE_RE = re.compile(
    r"<!--\s*drift-baseline:\s*(\{.*?\})\s*-->", re.DOTALL
)


def read_baseline(task_text: str) -> dict[str, str]:
    """Extract recorded {file: hash} baseline, or {} if none."""
    m = _BASELINE_RE.search(task_text)
    if not m:
        return {}
    try:
        import json
        return json.loads(m.group(1))
    except (ValueError, ImportError):
        return {}


def write_baseline(task_text: str, baseline: dict[str, str]) -> str:
    """Insert/replace the drift baseline inside `## Reviewer Verdict`.

    If a verdict section exists, append the baseline marker after the
    section header. If a baseline already exists, replace it.
    """
    import json
    payload = json.dumps(baseline, sort_keys=True)
    marker = f"<!-- drift-baseline: {payload} -->"

    # Replace existing
    if _BASELINE_RE.search(task_text):
        return _BASELINE_RE.sub(marker, task_text)

    # Insert after `## Reviewer Verdict` header (any version)
    insert_re = re.compile(
        r"(^## Reviewer Verdict[^\n]*\n)", re.MULTILINE
    )
    if insert_re.search(task_text):
        return insert_re.sub(rf"\1{marker}\n", task_text, count=1)

    # No verdict section — append at end
    return task_text.rstrip() + f"\n\n## Reviewer Verdict (drift baseline only)\n{marker}\n"


def detect_drift(task_path: Path, repo_root: Path) -> DriftReport:
    """Compare current file hashes against task's recorded baseline."""
    text = task_path.read_text()
    fm, _ = parse_task_file(task_path)
    task_id = fm.get("id", task_path.stem.split("-")[0])

    body = text.split("---", 2)[2] if text.startswith("---") else text
    verification = extract_section(body, "Verification") or ""
    refs = extract_file_refs(verification, repo_root)
    current = compute_hashes(refs, repo_root)
    baseline = read_baseline(text)

    rep = DriftReport(task_id=task_id)
    rep.referenced_files = sorted(current.keys())

    for f, cur_hash in current.items():
        base_hash = baseline.get(f)
        if base_hash is None:
            rep.no_baseline.append(f)
        elif cur_hash == "":
            rep.missing.append(f)
        elif cur_hash == base_hash:
            rep.unchanged.append(f)
        else:
            rep.changed.append(f)

    # Files in baseline but not in current refs → also drift (file removed)
    for f in baseline:
        if f not in current:
            rep.missing.append(f)

    rep.has_drift = bool(rep.changed or rep.missing)
    return rep
