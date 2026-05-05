#!/usr/bin/env python3
"""T-1736 Spike B run-harness.

Reads sampled prompts, invokes prompt-triage classifier per prompt via
litellm:4000 → ollama hermes3:8b, parses YAML envelope, captures verdict +
rationale + confidence + latency. Writes one JSON result per prompt to
.context/spikes/T-1736-results.jsonl.

The prompt template is read from prompts/prompt-triage.md and the
$PROMPT_UNDER_TRIAGE placeholder is substituted in shell — same path that
T-1733 (Spike A) used end-to-end.
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def load_template(path: Path) -> str:
    return path.read_text()


def build_user_prompt(template: str, prompt_text: str) -> str:
    """Substitute placeholders. Spike-grade: only $PROMPT_UNDER_TRIAGE is real."""
    body = template
    body = body.replace("$PROMPT_UNDER_TRIAGE", prompt_text)
    body = body.replace("$TASK_ID", "T-1736")
    body = body.replace("$TASK_TYPE", "build")
    body = body.replace("$TASK_NAME", "Spike B accuracy bench")
    body = body.replace(
        "$TASK_DESCRIPTION", "Measure prompt-triage classifier accuracy"
    )
    return body


def call_litellm(endpoint: str, api_key: str, model: str, user_prompt: str, timeout: int) -> tuple[str, float]:
    body = json.dumps(
        {
            "model": model,
            "messages": [{"role": "user", "content": user_prompt}],
            "temperature": 0.0,
            "max_tokens": 256,
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        endpoint,
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8")
    elapsed_ms = (time.monotonic() - t0) * 1000.0
    obj = json.loads(raw)
    content = obj["choices"][0]["message"]["content"]
    return content, elapsed_ms


VERDICT_RE = re.compile(r"verdict\s*:\s*([A-Z\-]+)", re.IGNORECASE)
CONF_RE = re.compile(r"confidence\s*:\s*([0-9.]+)", re.IGNORECASE)
RATIONALE_RE = re.compile(r"rationale\s*:\s*(?:>|\|)?\s*\n?\s*(.+?)(?=\n\s*\w+\s*:|\Z)", re.IGNORECASE | re.DOTALL)


def parse_envelope(text: str) -> dict:
    """Best-effort parse of the classifier output. Tolerates fenced-block or bare YAML."""
    # Strip ```yaml ... ``` fences if present
    m_fence = re.search(r"```(?:yaml)?\s*\n(.*?)\n```", text, re.DOTALL)
    body = m_fence.group(1) if m_fence else text
    out: dict = {"raw": text}
    m = VERDICT_RE.search(body)
    if m:
        out["verdict"] = m.group(1).upper().strip()
    else:
        out["verdict"] = "PARSE_FAIL"
    m = CONF_RE.search(body)
    if m:
        try:
            out["confidence"] = float(m.group(1))
        except ValueError:
            out["confidence"] = None
    else:
        out["confidence"] = None
    m = RATIONALE_RE.search(body)
    if m:
        out["rationale"] = m.group(1).strip().split("\n")[0][:200]
    else:
        out["rationale"] = ""
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompts", default=".context/spikes/T-1736-sampled.jsonl")
    ap.add_argument("--template", default="prompts/prompt-triage.md")
    ap.add_argument("--out", default=".context/spikes/T-1736-results.jsonl")
    ap.add_argument("--endpoint", default="http://localhost:4000/v1/chat/completions")
    ap.add_argument("--api-key", default=os.environ.get("LITELLM_API_KEY", "sk-litellm-local-dev"))
    ap.add_argument("--model", default="claude-3-5-sonnet-hermes3")
    ap.add_argument("--timeout", type=int, default=60)
    ap.add_argument("--limit", type=int, default=0, help="cap (0 = all)")
    args = ap.parse_args()

    template = load_template(Path(args.template))
    prompts = [json.loads(l) for l in Path(args.prompts).open()]
    if args.limit:
        prompts = prompts[: args.limit]
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    n_ok = n_err = 0
    with out_path.open("w") as fout:
        for i, p in enumerate(prompts):
            user_prompt = build_user_prompt(template, p["text"])
            try:
                content, elapsed = call_litellm(
                    args.endpoint, args.api_key, args.model, user_prompt, args.timeout
                )
                env = parse_envelope(content)
                row = {
                    "id": p["id"],
                    "verdict": env.get("verdict"),
                    "rationale": env.get("rationale"),
                    "confidence": env.get("confidence"),
                    "latency_ms": round(elapsed, 1),
                    "raw": content,
                    "ok": True,
                }
                n_ok += 1
            except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError) as e:
                row = {
                    "id": p["id"],
                    "verdict": "ERROR",
                    "rationale": str(e)[:200],
                    "confidence": None,
                    "latency_ms": None,
                    "raw": "",
                    "ok": False,
                }
                n_err += 1
            fout.write(json.dumps(row, ensure_ascii=False) + "\n")
            fout.flush()
            print(
                f"[{i+1:02d}/{len(prompts)}] {p['id']} → {row['verdict']:10s} "
                f"({row['latency_ms']}ms)" if row.get("latency_ms") else
                f"[{i+1:02d}/{len(prompts)}] {p['id']} → ERROR"
            )
    print(f"\nDone: {n_ok} ok, {n_err} errors → {out_path}")
    return 0 if n_err == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
