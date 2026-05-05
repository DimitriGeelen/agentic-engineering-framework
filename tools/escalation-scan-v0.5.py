#!/usr/bin/env python3
"""
T-1727 — Layer B v0.5: per-candidate LLM augmentation of escalation-scan v0.

Reads .context/working/escalation-drift-LATEST.yaml (heuristic verdict from
v0). For each H1-flagged candidate in the last N days, dispatches one
escalation-triage workflow call via lib/resolver, executes the LLM call via
direct litellm POST (same path ollama-tool-loop.py uses), parses the YAML
verdict envelope, writes the merged result to escalation-drift-LATEST-v0.5.yaml,
and back-props the outcome to dispatch-outcomes.jsonl.

Idempotency: a candidate is skipped if it already has a v0.5 verdict in the
output YAML newer than IDEMPOTENCY_DAYS (default 7). Override with
ESCALATION_V05_FORCE=1.

Failure semantics (per workflow.cost_cap_usd=0.0): if the LLM call fails,
the candidate is recorded with verdict=ERROR and the scan continues. v0's
report (escalation-drift-LATEST.yaml) is never modified.

Output contract:
  .context/working/escalation-drift-LATEST-v0.5.yaml
  .context/dispatches.jsonl                 (one row per candidate dispatched)
  .context/dispatch-outcomes.jsonl          (one row per candidate with verdict)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd())).resolve()
sys.path.insert(0, str(ROOT / "lib"))

import resolver  # noqa: E402
import outcome  # noqa: E402

V0_LATEST = ROOT / ".context" / "working" / "escalation-drift-LATEST.yaml"
V05_LATEST = ROOT / ".context" / "working" / "escalation-drift-LATEST-v0.5.yaml"
COMPLETED = ROOT / ".tasks" / "completed"

# Mirror of v0 heuristic — kept here to avoid modifying v0's output contract.
# v0 emits only 10 candidates in recent_sample; for A6 we need 30-day full
# coverage (~175 candidates), so v0.5 re-walks completed/ with the same rules.
BUG_TITLE_RE = re.compile(
    r"\b(fix|bug|rca|broken|crash|error|regression|fail|hotfix)\b", re.I
)
BUG_TAG_RE = re.compile(r"\b(bug|bugfix|hotfix|rca|incident)\b", re.I)
RCA_SECTION_RE = re.compile(
    r"^##+\s*(RCA|Root\s*Cause|Why\s*This\s*Happened)\b", re.I | re.M
)
NON_BUG_WORKFLOWS = {"inception", "specification", "design"}

DEFAULT_BASE = "http://localhost:4000"
DEFAULT_KEY = "sk-litellm-local-dev"
DEFAULT_MODEL = "claude-3-5-sonnet-hermes3"
LLM_TIMEOUT = 60
IDEMPOTENCY_DAYS = int(os.environ.get("ESCALATION_V05_IDEMPOTENCY_DAYS", "7"))
MAX_CANDIDATES_PER_RUN = int(os.environ.get("ESCALATION_V05_MAX", "200"))
CANDIDATE_BODY_TRUNCATE = 6000  # chars; keeps prompts under ~8K tokens


def load_v0_yaml() -> dict:
    if not V0_LATEST.exists():
        sys.stderr.write(
            f"v0.5: {V0_LATEST.relative_to(ROOT)} missing — run "
            f"escalation-scan-v0.py first\n"
        )
        sys.exit(2)
    return yaml.safe_load(V0_LATEST.read_text()) or {}


def _parse_frontmatter(text: str) -> tuple[dict, str]:
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 4)
    if end == -1:
        return {}, text
    fm: dict = {}
    for line in text[4:end].splitlines():
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm, text[end + 4 :]


def _is_bug_class(fm: dict, title: str) -> bool:
    if BUG_TAG_RE.search(fm.get("tags", "") or ""):
        return True
    if fm.get("workflow_type", "") in NON_BUG_WORKFLOWS:
        return False
    return bool(BUG_TITLE_RE.search(title))


def _has_rca(body: str) -> bool:
    m = RCA_SECTION_RE.search(body)
    if not m:
        return False
    after = body[m.end() : m.end() + 800]
    cleaned = re.sub(r"<!--.*?-->", "", after, flags=re.S).strip()
    real_lines = [
        ln for ln in cleaned.splitlines()
        if ln.strip() and not ln.strip().startswith("#")
    ]
    return any(len(ln) > 30 for ln in real_lines[:5])


def _parse_finished(fm: dict) -> datetime | None:
    s = fm.get("date_finished") or fm.get("last_update")
    if not s or s == "null":
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None


def collect_candidates(window_days: int) -> list[dict]:
    """Walk completed/, return [{tid_full, name, body}] for bug-class tasks
    with no RCA finished within window_days. Mirrors v0's H1 heuristic, no
    contract dependency on v0's output."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=window_days)
    out: list[dict] = []
    for path in sorted(COMPLETED.glob("T-*.md")):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        fm, body = _parse_frontmatter(text)
        title = fm.get("name", path.stem)
        if not _is_bug_class(fm, title):
            continue
        if _has_rca(body):
            continue
        finished = _parse_finished(fm)
        if not finished or finished < cutoff:
            continue
        out.append({"tid_full": path.stem, "name": title, "body": body})
    return out


def load_existing_v05() -> dict:
    if not V05_LATEST.exists():
        return {"candidates": []}
    try:
        return yaml.safe_load(V05_LATEST.read_text()) or {"candidates": []}
    except yaml.YAMLError:
        return {"candidates": []}


def find_candidate_path(tid_full: str) -> Path | None:
    """tid_full is the full slug-form id like 'T-1014-fix-...'. Try exact stem
    first, then prefix on plain T-XXX form."""
    direct = COMPLETED / f"{tid_full}.md"
    if direct.exists():
        return direct
    short = tid_full.split("-")[0] + "-" + tid_full.split("-")[1]
    matches = sorted(COMPLETED.glob(f"{short}-*.md"))
    return matches[0] if matches else None


def read_candidate_body(tid_full: str) -> tuple[str, str]:
    """Return (short_id, body_truncated). short_id is 'T-XXX', body is the
    candidate task content with frontmatter stripped, truncated for prompt fit."""
    short = tid_full.split("-")[0] + "-" + tid_full.split("-")[1]
    path = find_candidate_path(tid_full)
    if not path:
        return short, ""
    text = path.read_text(encoding="utf-8")
    if text.startswith("---"):
        end = text.find("\n---", 4)
        if end > 0:
            text = text[end + 4 :]
    text = text.strip()
    if len(text) > CANDIDATE_BODY_TRUNCATE:
        text = text[:CANDIDATE_BODY_TRUNCATE] + "\n\n[...body truncated for triage prompt...]"
    return short, text


def is_recent_enough(verdict_ts: str) -> bool:
    """True if the recorded verdict is within IDEMPOTENCY_DAYS — caller skips."""
    try:
        ts = datetime.fromisoformat(verdict_ts.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return False
    cutoff = datetime.now(timezone.utc) - timedelta(days=IDEMPOTENCY_DAYS)
    return ts >= cutoff


def call_litellm(prompt: str, *, base: str, key: str, model: str) -> dict:
    """POST to litellm /v1/messages with the rendered prompt. Returns:
      {ok: bool, text: str, error: str|None, latency_s: float}"""
    payload = {
        "model": model,
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": prompt}],
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{base}/v1/messages",
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
            "anthropic-version": "2023-06-01",
        },
    )
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=LLM_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        latency = time.time() - t0
        text = ""
        for block in body.get("content", []):
            if block.get("type") == "text":
                text += block.get("text", "")
        return {"ok": True, "text": text, "error": None, "latency_s": latency}
    except urllib.error.HTTPError as e:
        return {
            "ok": False,
            "text": "",
            "error": f"http {e.code}: {e.read().decode('utf-8', 'replace')[:200]}",
            "latency_s": time.time() - t0,
        }
    except (urllib.error.URLError, OSError, json.JSONDecodeError) as e:
        return {
            "ok": False,
            "text": "",
            "error": f"{type(e).__name__}: {e}",
            "latency_s": time.time() - t0,
        }


VALID_VERDICTS = ("real_symptom_fix", "false_positive", "defer")


def _regex_fallback(text: str) -> dict:
    """Regex-extract verdict/rationale/confidence from sloppy LLM output.

    Activated when fenced+yaml parsing yields nothing OR when yaml.safe_load
    raises on syntactically intentful but unquoted output (e.g. `rationale:
    This is a fix: a clear bug response` — a colon in the rationale value
    aborts yaml). Per T-1748 / T-1727 5.9% PARSE-FAIL: the verdict word is
    sitting right there in plain text — extracting it is more useful than
    discarding the entire envelope.

    Returns {} when no valid verdict word is found (input is unsalvageable).
    """
    if not text:
        return {}
    # Verdict: constrained to the three valid words. Refusing arbitrary words
    # ("verdict: maybe") is the AC contract — better PARSE-FAIL than drift.
    verdict = ""
    m = re.search(
        r"verdict\s*[:=]\s*[\"']?(real_symptom_fix|false_positive|defer)\b",
        text, flags=re.IGNORECASE,
    )
    if m:
        verdict = m.group(1).lower()
    if not verdict:
        return {}
    confidence = 0.0
    cm = re.search(r"confidence\s*[:=]\s*([0-9]*\.?[0-9]+)", text, flags=re.IGNORECASE)
    if cm:
        try:
            confidence = float(cm.group(1))
        except ValueError:
            confidence = 0.0
        confidence = max(0.0, min(1.0, confidence))
    rationale = ""
    rm = re.search(
        r"rationale\s*[:=]\s*[\"']?(.+?)(?:\n\s*(?:confidence|verdict)\s*[:=]|\Z)",
        text, flags=re.IGNORECASE | re.DOTALL,
    )
    if rm:
        rationale = rm.group(1).strip().strip('"\'').strip()
    return {"verdict": verdict, "rationale": rationale, "confidence": confidence}


def parse_verdict_envelope(text: str) -> dict:
    """Find the fenced YAML block in the LLM response, parse verdict +
    rationale + confidence. Falls back to regex extraction when YAML parsing
    fails on syntactically intentful but unquoted output (T-1748). Returns
    {} only when nothing can be extracted at all (true PARSE-FAIL).
    """
    if not text:
        return {}
    fenced = None
    in_fence = False
    buf: list[str] = []
    for line in text.splitlines():
        if line.strip().startswith("```yaml"):
            in_fence = True
            continue
        if line.strip().startswith("```") and in_fence:
            fenced = "\n".join(buf)
            break
        if in_fence:
            buf.append(line)
    if fenced is None and buf:
        # Missing closing fence — use whatever we collected.
        fenced = "\n".join(buf)
    # Try strict YAML first.
    if fenced:
        try:
            parsed = yaml.safe_load(fenced) or {}
        except yaml.YAMLError:
            parsed = None
        if isinstance(parsed, dict):
            verdict = str(parsed.get("verdict", "")).strip()
            # Constrain verdict to known set even on the YAML path — a
            # rationale that started with "verdict: maybe" inside a fenced
            # YAML block could otherwise leak through.
            if verdict not in VALID_VERDICTS:
                verdict = ""
            rationale = str(parsed.get("rationale", "")).strip()
            try:
                confidence = float(parsed.get("confidence", 0.0))
            except (TypeError, ValueError):
                confidence = 0.0
            confidence = max(0.0, min(1.0, confidence))
            if verdict:
                return {"verdict": verdict, "rationale": rationale, "confidence": confidence}
    # Fall through to regex extraction — applied to the full text, not just
    # the fence content, so plain-text-no-fence inputs are handled too.
    return _regex_fallback(text)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="v0.5: per-candidate LLM triage of v0 heuristic flags."
    )
    parser.add_argument("--limit", type=int, default=MAX_CANDIDATES_PER_RUN,
                        help=f"max candidates per run (default {MAX_CANDIDATES_PER_RUN})")
    parser.add_argument("--force", action="store_true",
                        help="re-dispatch even if a recent v0.5 verdict exists")
    parser.add_argument("--dry-run", action="store_true",
                        help="print what would dispatch but make no LLM calls")
    parser.add_argument("--window-days", type=int, default=30,
                        help="how many days back to scan (default 30)")
    args = parser.parse_args()
    force = args.force or os.environ.get("ESCALATION_V05_FORCE") == "1"

    v0 = load_v0_yaml()
    existing = load_existing_v05()
    existing_by_id: dict[str, dict] = {
        c.get("task_id"): c for c in existing.get("candidates", []) if c.get("task_id")
    }

    # v0.5 self-walks completed/ for full window coverage (v0 only emits 10
    # candidates in recent_sample; A6 needs the full 30-day backlog ~175 tasks
    # to compute a meaningful disagreement rate). v0's headline numbers are
    # still surfaced for context.
    candidates_in = collect_candidates(args.window_days)
    if not candidates_in:
        sys.stdout.write(
            f"v0.5: no bug-class+no-RCA candidates in last {args.window_days}d — "
            "nothing to triage\n"
        )
        write_output({
            "generated": datetime.now(timezone.utc).isoformat(),
            "v0_corpus_total": v0.get("corpus_total", 0),
            "v0_h1_flagged": v0.get("h1_flagged", 0),
            "window_days": args.window_days,
            "dispatched": 0, "skipped_idempotent": 0, "errors": 0,
            "candidates": [],
        })
        return 0

    base = os.environ.get("ANTHROPIC_BASE_URL", DEFAULT_BASE)
    key = os.environ.get("ANTHROPIC_API_KEY", DEFAULT_KEY)
    model = os.environ.get("ESCALATION_V05_MODEL", DEFAULT_MODEL)

    out_candidates: list[dict] = []
    dispatched = 0
    skipped_idempotent = 0
    errors = 0

    for entry in candidates_in[: args.limit]:
        tid_full = entry.get("tid_full") or entry.get("tid", "")
        name = entry.get("name", "")
        if not tid_full:
            continue
        short_id = "-".join(tid_full.split("-")[:2])
        body = entry.get("body", "")
        if not body:
            short_id, body = read_candidate_body(tid_full)
        else:
            if len(body) > CANDIDATE_BODY_TRUNCATE:
                body = body[:CANDIDATE_BODY_TRUNCATE] + (
                    "\n\n[...body truncated for triage prompt...]"
                )

        # Idempotency: skip if recent verdict exists.
        prior = existing_by_id.get(short_id)
        if prior and not force and is_recent_enough(prior.get("ts", "")):
            skipped_idempotent += 1
            out_candidates.append(prior)
            continue

        if not body:
            out_candidates.append({
                "task_id": short_id, "tid_full": tid_full, "name": name,
                "ts": datetime.now(timezone.utc).isoformat(),
                "verdict": "ERROR", "rationale": "task body not found in completed/",
                "confidence": 0.0, "dispatch_id": None,
            })
            errors += 1
            continue

        # Build envelope via resolver (writes dispatches.jsonl + blob).
        task_context = resolver.load_task_frontmatter(short_id) or {}
        task_context.setdefault("TASK_ID", short_id)
        task_context.setdefault("TASK_TYPE", "escalation-triage")
        task_context.setdefault("TASK_NAME", name)
        task_context.setdefault("TASK_DESCRIPTION", "")
        task_context.setdefault("ACCEPTANCE_CRITERIA", "(none)")
        task_context["CANDIDATE_BODY"] = body

        try:
            envelope, _row = resolver.resolve(
                short_id, "escalation-triage", task_context, dry_run=args.dry_run,
            )
        except resolver.ResolverError as e:
            out_candidates.append({
                "task_id": short_id, "tid_full": tid_full, "name": name,
                "ts": datetime.now(timezone.utc).isoformat(),
                "verdict": "ERROR", "rationale": f"resolver: {e}",
                "confidence": 0.0, "dispatch_id": None,
            })
            errors += 1
            continue

        dispatch_id = envelope.get("dispatch_id")
        prompt_text = envelope.get("rendered_prompt") or envelope.get("prompt") or ""

        if args.dry_run:
            sys.stdout.write(
                f"v0.5: would dispatch {short_id} dispatch_id={dispatch_id} "
                f"prompt={len(prompt_text)}c\n"
            )
            out_candidates.append({
                "task_id": short_id, "tid_full": tid_full, "name": name,
                "ts": datetime.now(timezone.utc).isoformat(),
                "verdict": "DRY-RUN", "rationale": "dry-run requested",
                "confidence": 0.0, "dispatch_id": dispatch_id,
            })
            continue

        result = call_litellm(prompt_text, base=base, key=key, model=model)
        ts = datetime.now(timezone.utc).isoformat()
        if not result["ok"]:
            out_candidates.append({
                "task_id": short_id, "tid_full": tid_full, "name": name,
                "ts": ts, "verdict": "ERROR",
                "rationale": result["error"][:200], "confidence": 0.0,
                "latency_s": round(result["latency_s"], 3),
                "dispatch_id": dispatch_id,
            })
            errors += 1
            # Best-effort outcome row so the dispatch shows ERROR upstream too.
            try:
                outcome.backprop_outcome(short_id, {
                    "evaluator": "escalation-scan-v0.5",
                    "verdict": "ERROR",
                    "rationale": result["error"][:200],
                    "confidence": 0.0,
                })
            except Exception:
                pass
            continue

        parsed = parse_verdict_envelope(result["text"])
        verdict = parsed.get("verdict") or "PARSE-FAIL"
        rationale = parsed.get("rationale") or result["text"][:200]
        confidence = parsed.get("confidence", 0.0)

        out_candidates.append({
            "task_id": short_id, "tid_full": tid_full, "name": name,
            "ts": ts, "verdict": verdict, "rationale": rationale,
            "confidence": confidence,
            "latency_s": round(result["latency_s"], 3),
            "dispatch_id": dispatch_id,
        })
        dispatched += 1

        try:
            outcome.backprop_outcome(short_id, {
                "evaluator": "escalation-scan-v0.5",
                "verdict": verdict,
                "rationale": rationale,
                "confidence": confidence,
            })
        except Exception as e:
            sys.stderr.write(f"v0.5: backprop failed for {short_id}: {e}\n")

    summary = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "v0_source": str(V0_LATEST.relative_to(ROOT)),
        "v0_corpus_total": v0.get("corpus_total", 0),
        "v0_h1_flagged": v0.get("h1_flagged", 0),
        "window_days": args.window_days,
        "model": model,
        "idempotency_days": IDEMPOTENCY_DAYS,
        "dispatched": dispatched,
        "skipped_idempotent": skipped_idempotent,
        "errors": errors,
        "candidates": out_candidates,
    }
    write_output(summary)
    sys.stdout.write(
        f"v0.5: dispatched={dispatched} skipped_idempotent={skipped_idempotent} "
        f"errors={errors} → {V05_LATEST.relative_to(ROOT)}\n"
    )
    return 0


def write_output(summary: dict) -> None:
    V05_LATEST.parent.mkdir(parents=True, exist_ok=True)
    tmp = V05_LATEST.with_suffix(".yaml.tmp")
    tmp.write_text(yaml.safe_dump(summary, sort_keys=False, allow_unicode=True))
    tmp.replace(V05_LATEST)


if __name__ == "__main__":
    raise SystemExit(main())
