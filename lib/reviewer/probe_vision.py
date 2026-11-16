"""T-5176: `fw reviewer probe-vision <kind>` — can this harness review seat read a supplied image?

T-4944 (operator ruling "vision-gated", 2026-11-01) credits a harness seat with a screenshot only
when policy/review-backends.yaml declares its kind `vision: true`. That flag is evidence about
the seat's harness and model, and was measured by hand for codex and opencode; antigravity,
added later, was never measured, so every render verdict it gave was refused (T-5175).

This probe measures it the same way every time:
  * one screenshot is copied into a throwaway folder (nothing else is in it);
  * the kind's REGISTERED binary is launched in the same form the review runtime uses for that
    kind (agents/termlink/termlink.sh, harness branch), with the fixed T-4944 questions;
  * the answer is graded against the screenshot's ground truth.

It writes one line to .context/reviews/vision-probes.jsonl and prints the suggested `vision:`
value. It never touches the verdict ledger and never edits the registry: a flag that widens
what counts as evidence is the operator's change to make.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

HARNESS_KINDS = ("codex", "opencode", "antigravity")
#: the review runtime runs antigravity as this user (termlink.sh: the operator-approved form, 2026-09-30)
ANTIGRAVITY_USER = "dimitri-mint-dev"

DEFAULT_IMAGE = ".context/visual/T-4947/arc-closure@1440.png"
DEFAULT_COUNT = 8
DEFAULT_TITLE = "Onboarding: fw init detects project shape by enumeration, not manifest allowlist"
RECORD = ".context/reviews/vision-probes.jsonl"
SUGGESTED = {"sees": "true", "cannot-view": "false", "wrong": "false", "no-answer": "unknown"}

PROMPT = """This is a capability probe, not a review. Do not edit, create or delete any file.

Look at the image file probe.png in the current directory.

Answer from the image itself:
1. How many cards carry a BLOCKED badge?
2. Quote exactly the first card's link title.
3. Which mechanism or tool did you use to look at the image?

If you cannot view the image's pixels, answer CANNOT VIEW and say why. Do not guess, and do not
answer from the file name or anything other than the image.

Reply in exactly this shape:
CARDS: <number or CANNOT VIEW>
TITLE: <exact title or CANNOT VIEW>
MECHANISM: <tool or reason>
"""


def _root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or Path(__file__).resolve().parents[2])


def launch_argv(kind: str, binary: str, prompt: str, workdir: Path) -> tuple[list[str], dict]:
    """The command line and extra env the review runtime uses for `kind` (termlink.sh harness
    branch), pointed at the probe folder. Read-only: the probe has nothing to write."""
    if kind == "codex":
        return ([binary, "exec", "-s", "read-only", "--skip-git-repo-check", "--ignore-user-config",
                 "--ignore-rules", "--ephemeral", "--color", "never", "-c", "project_doc_max_bytes=0",
                 "-o", str(workdir / "result.md"), prompt], {})
    if kind == "opencode":
        return ([binary, "run", "--agent", "plan", "--pure", "--format", "json", prompt],
                {"OPENCODE_DISABLE_PROJECT_CONFIG": "1"})
    if kind == "antigravity":
        return (["/usr/bin/sudo", "-n", "-u", ANTIGRAVITY_USER, "-H", binary, "-p", prompt,
                 "--mode", "plan", "--sandbox"], {})
    raise ValueError(f"{kind!r} is not a harness review kind ({', '.join(HARNESS_KINDS)})")


def _default_launcher(argv: list[str], env_extra: dict, cwd: Path, timeout: int) -> tuple[int, str, str]:
    env = {**os.environ, **env_extra}
    for k in ("PROJECT_ROOT", "FRAMEWORK_ROOT"):   # T-4999: the seat never sees the live project
        env.pop(k, None)
    try:
        p = subprocess.run(argv, cwd=str(cwd), env=env, capture_output=True, text=True,
                           timeout=timeout, stdin=subprocess.DEVNULL)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired as e:
        return 124, (e.stdout or "") if isinstance(e.stdout, str) else "", "timed out"
    except OSError as e:
        return 127, "", str(e)


def _answer_text(kind: str, stdout: str, workdir: Path) -> str:
    """The seat's final text: codex writes result.md; opencode prints JSON events."""
    if kind == "codex" and (workdir / "result.md").is_file():
        return (workdir / "result.md").read_text(errors="replace")
    if kind == "opencode":
        texts = []
        for line in stdout.splitlines():
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            part = ev.get("part") if isinstance(ev, dict) else None
            if isinstance(part, dict) and isinstance(part.get("text"), str):
                texts.append(part["text"])
        if texts:
            return "\n".join(texts)
    return stdout


def _field(text: str, name: str) -> str:
    m = re.search(rf"(?im)^\W*{name}\W*:\s*(.+?)\s*$", text)
    return m.group(1).strip() if m else ""


def _norm_title(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip().strip("`\"'“”‘’*_")).strip()


def grade(text: str, expect_count: int, expect_title: str, rc: int) -> tuple[str, dict]:
    cards, title, mech = _field(text, "CARDS"), _field(text, "TITLE"), _field(text, "MECHANISM")
    answer = {"cards": cards, "title": title, "mechanism": mech}
    if "CANNOT VIEW" in (cards + " " + title).upper():
        return "cannot-view", answer
    if not cards and not title:
        return "no-answer", answer
    n = re.search(r"\d+", cards)
    right = bool(n) and int(n.group()) == expect_count and _norm_title(title) == _norm_title(expect_title)
    return ("sees" if right else "wrong"), answer


def run_probe(kind: str, *, image: str = DEFAULT_IMAGE, expect_count: int = DEFAULT_COUNT,
              expect_title: str = DEFAULT_TITLE, timeout: int = 600, launcher=None,
              binary: str | None = None, root: Path | None = None) -> dict:
    root = Path(root or _root())
    if kind not in HARNESS_KINDS:
        raise ValueError(f"{kind!r} is not a harness review kind ({', '.join(HARNESS_KINDS)})")
    img = Path(image) if Path(image).is_absolute() else root / image
    if not img.is_file():
        raise FileNotFoundError(f"no screenshot at {img}")
    if binary is None:
        sys.path.insert(0, str(root))
        from lib import verdict_ledger as vl
        binary = (vl.kind_binaries(root) or {}).get(kind, "")
    if not binary:
        raise RuntimeError(f"the committed registry pins no binary for {kind!r}")
    work = Path(tempfile.mkdtemp(prefix=f"fw-probe-vision-{kind}-"))
    try:
        os.chmod(work, 0o755)              # the antigravity user must be able to read it
        shutil.copyfile(img, work / "probe.png")
        os.chmod(work / "probe.png", 0o644)
        argv, env_extra = launch_argv(kind, binary, PROMPT, work)
        rc, out, err = (launcher or _default_launcher)(argv, env_extra, work, timeout)
        text = _answer_text(kind, out, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    g, answer = grade(text, expect_count, expect_title, rc)
    if rc != 0 and g == "no-answer":
        answer["error"] = (err or "")[-400:]
    rec = {
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "kind": kind, "binary": binary, "rc": rc,
        "image": str(img.relative_to(root)) if img.is_relative_to(root) else str(img),
        "image_sha256": hashlib.sha256(img.read_bytes()).hexdigest(),
        "expect": {"cards": expect_count, "title": expect_title},
        "answer": answer, "grade": g, "suggested_vision": SUGGESTED[g],
        "output_tail": text.strip()[-600:],
    }
    path = root / RECORD
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    return rec


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="fw reviewer probe-vision",
                                 description="Can a harness review seat read a supplied screenshot? (T-5176)")
    ap.add_argument("kind", choices=HARNESS_KINDS)
    ap.add_argument("--image", default=DEFAULT_IMAGE)
    ap.add_argument("--expect-count", type=int, default=DEFAULT_COUNT)
    ap.add_argument("--expect-title", default=DEFAULT_TITLE)
    ap.add_argument("--timeout", type=int, default=600)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    try:
        rec = run_probe(a.kind, image=a.image, expect_count=a.expect_count,
                        expect_title=a.expect_title, timeout=a.timeout)
    except (ValueError, FileNotFoundError, RuntimeError) as e:
        print(f"fw reviewer probe-vision: {e}", file=sys.stderr)
        return 2
    if a.json:
        print(json.dumps(rec, ensure_ascii=False))
    else:
        ans = rec["answer"]
        print(f"{rec['kind']}: {rec['grade'].upper()} — cards {ans.get('cards') or '?'} "
              f"(expected {rec['expect']['cards']}), title {ans.get('title') or '?'!r}")
        print(f"  mechanism: {ans.get('mechanism') or '?'}")
        print(f"  suggested registry value: vision: {rec['suggested_vision']} "
              f"(recorded in {RECORD}; the registry is not changed by this command)")
    return 0 if rec["grade"] in ("sees", "cannot-view", "wrong") else 1


if __name__ == "__main__":
    sys.exit(main())
