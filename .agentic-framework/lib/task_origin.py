"""T-3897: where did this task come from — for the approvals queue.

The operator asked (2026-10-05) that approvals born from a peer's pickup or an
external proposal be visibly tagged as such: T-3659, an unratified external
proposal ingested and queued, looked exactly like the operator's own request.

Order of truth:
  1. a recorded `origin:` frontmatter map ({kind, source, ref}), written by
     `fw task create|work-on|inception start --origin kind[:source[:ref]]`;
  2. otherwise a CONSERVATIVE inference from the task's name and description,
     marked `inferred: True` — only on explicit signals (a known peer project
     named next to a message id / report / pickup, the word "pickup", or an
     external/pasted proposal);
  3. otherwise kind "unknown" — never a silent "agent" (same rule as T-3078's
     Tier 0 cards).

Pure function, no I/O: callers pass the parsed frontmatter and nothing else.
"""
from __future__ import annotations

import re

KINDS = ("operator", "agent", "peer", "pickup", "proposal")

# Known peer projects: canonical name -> spellings seen in task text.
_PEERS = {
    "010-termlink": [r"010-termlink", r"\b010\b"],
    "055-agentic-fleet-cockpit": [r"055-agentic-fleet-cockpit", r"\b055\b"],
    "832-Workflow-designer": [r"832-Workflow-designer", r"\b832\b"],
    "1409-sprind": [r"1409-sprind", r"\b1409\b"],
    "050-email-archive": [r"050-email-archive", r"\b050\b"],
    "0506-Voxtype-extention": [r"0506-Voxtype-extention", r"\b0506\b"],
    "ring20-dashboard": [r"ring20-dashboard"],
    "ring20-manager": [r"ring20-manager", r"proxmox-ring20-management"],
}
# A peer name only counts when the text ties it to a message/report/pickup.
_PEER_CONTEXT = r"(msg\s+[0-9a-f]{6,}|\breport(ed)?\b|\bpickup\b|\bpatch\b|\bfinding\b|\bconsult\b)"


def _norm(fm: dict) -> dict | None:
    raw = fm.get("origin")
    if isinstance(raw, dict) and raw.get("kind") in KINDS:
        return {"kind": raw["kind"], "source": str(raw.get("source") or ""),
                "ref": str(raw.get("ref") or ""), "inferred": False}
    if isinstance(raw, str) and raw.split(":", 1)[0] in KINDS:
        kind, _, rest = raw.partition(":")
        source, _, ref = rest.partition(":")
        return {"kind": kind, "source": source, "ref": ref, "inferred": False}
    return None


_OPERATOR = re.compile(
    r"\bOperator(,| \(| asked| request| question| ruling)?[^.\n]{0,12}\b20\d\d-\d\d-\d\d", re.I)


def _infer(text: str) -> dict | None:
    t = text or ""
    # Operator is inferred LAST, on purpose. The two errors are not symmetric:
    # labelling an external proposal "from you" is the failure this module
    # exists to end (T-3659: "external proposal … unratified, pasted by the
    # operator on 2026-10-01" read as the operator's own request), while
    # labelling an operator task "peer (inferred)" only invites a look. A task
    # the inference gets wrong is fixed by recording `origin:`, not by tuning.
    if re.search(r"\b(external|pasted|unratified)\b[^.]{0,40}\bproposal\b|\bproposal\b[^.]{0,40}\b(pasted|unratified)\b",
                 t, re.I):
        return {"kind": "proposal", "source": "", "ref": "", "inferred": True}
    for name, spellings in _PEERS.items():
        for sp in spellings:
            for m in re.finditer(sp, t):
                window = t[max(0, m.start() - 60): m.end() + 60]
                if re.search(_PEER_CONTEXT, window, re.I):
                    ref = re.search(r"msg\s+([0-9a-f]{6,})", window)
                    kind = "pickup" if re.search(r"\bpickup\b", window, re.I) else "peer"
                    return {"kind": kind, "source": name, "ref": ref.group(1) if ref else "",
                            "inferred": True}
    if re.search(r"\bpickup\b", t, re.I):
        return {"kind": "pickup", "source": "", "ref": "", "inferred": True}
    if _OPERATOR.search(t):
        return {"kind": "operator", "source": "", "ref": "", "inferred": True}
    return None


def _recommendation(body: str) -> str:
    m = re.search(r"^## Recommendation\s*$(.*?)(?=^## |\Z)", body or "", re.M | re.S)
    return re.sub(r"<!--.*?-->", "", m.group(1), flags=re.S) if m else ""


def task_origin(fm: dict, body: str = "") -> dict:
    """{kind, source, ref, inferred, label} for one task. `body` is optional:
    inceptions carry their provenance in the Recommendation, not the description."""
    o = _norm(fm or {})
    if o is None:
        text = (f"{(fm or {}).get('name') or ''}\n{(fm or {}).get('description') or ''}\n"
                f"{_recommendation(body)}")
        o = _infer(text) or {"kind": "unknown", "source": "", "ref": "", "inferred": False}
    words = {"operator": "from you", "agent": "agent-initiated", "peer": "peer request",
             "pickup": "peer pickup", "proposal": "external proposal",
             "unknown": "origin unknown"}
    label = words[o["kind"]]
    if o["source"]:
        label += f": {o['source']}"
    if o["inferred"]:
        label += " (inferred)"
    o["label"] = label
    return o
