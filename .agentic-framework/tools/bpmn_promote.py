#!/usr/bin/env python3
"""fw bpmn promote — turn staged BPMN proposals into gated .tasks/ files.

The AEF compiler-side half of the write-out *promotion* layer (T-2542, joint with
832's T-201). Reads the T-2539 proposal manifest (`<stage>/<stem>/manifest.yaml`)
and, for each uid, delegates the `.tasks/` write to `fw task create` — the ONE
governed writer — forcing `owner: human` + `status: captured`, then stamping an
`aef_provenance:` frontmatter block. The `.tasks/` write NEVER leaves the task-gate
perimeter (G3): promote hard-codes owner/status and does not expose them to proposal
content, and the create runs through create-task.sh so it inherits the task-gate +
G-020 build-readiness.

Reconcile is keyed on `(uid, source_bpmn_sha)` per 832's IW-2 contract (T-201 §3b):
the task's `aef_provenance` frontmatter is authoritative; the uid↔T-ID mapping is a
derived, rebuildable cache (re-scanned from `.tasks/` each run — no split-brain, no
ledger file).

  new       (uid absent in .tasks/)           -> create (captured, owner:human) + stamp provenance
  unchanged (recorded sha == manifest sha)     -> NO-OP  (this is what makes re-promote idempotent)
  changed   (recorded sha != manifest sha)     -> PROPOSE-not-clobber: NEVER auto-write; flag for
                                                  human review regardless of captured/touched (T-2543)
  deleted   (uid in .tasks/ but not manifest)  -> orphan + flag (NEVER auto-delete)

Dry-run is the DEFAULT. `--write` executes. The content hash makes edit-detection a
bounded diff (not a fuzzy match), so the "unbounded reconciliation" NO-GO is
structurally excluded.

Gate-level enforcement (T-2543, Dimitri sovereignty bar): promote sets
`FW_TASK_ORIGIN=bpmn-promote` on each `fw task create`, and create-task.sh's gate refuses
any promote-origin create that is not owner:human + captured — so a future caller bug can't
reopen the hole. Every `--write` materialization also appends an audit line to
`.context/working/.bpmn-promote-audit.jsonl` (no silent .tasks/ writes).

Usage:
  fw bpmn promote all [--write] [--stage-dir DIR]
  fw bpmn promote <uid> [--write] [--stage-dir DIR]
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from datetime import datetime, timezone

# ── Manifest / staging discovery ─────────────────────────────────────────────


def _stage_dir(explicit: str | None = None) -> str:
    """Root staging dir: explicit flag > FW_BPMN_STAGE_DIR env > .context/bpmn-staged/.

    Mirrors tools/bpmn_to_tasks.py:_stage_dir so promote reads exactly what
    `fw bpmn compile --write` produced.
    """
    return (
        explicit
        or os.environ.get("FW_BPMN_STAGE_DIR")
        or os.path.join(".context", "bpmn-staged")
    )


def _parse_manifest(path: str) -> dict:
    """Parse a proposal manifest.yaml into {diagram, generated_from, proposals: {uid: {...}}}.

    Hand-rolled line parser (the manifest is a flat, known 2-level shape emitted by
    bpmn_to_tasks.write_proposals) — avoids a PyYAML dependency and the implicit-timestamp
    resolver hazard (L-495). sha values are always coerced to str so an all-numeric hex
    hash never round-trips as an int.
    """
    diagram = generated_from = ""
    proposals: dict[str, dict] = {}
    cur_uid: str | None = None
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line.strip():
                continue
            if line.startswith("diagram:"):
                diagram = _unquote(line.split(":", 1)[1].strip())
            elif line.startswith("generated_from:"):
                generated_from = _unquote(line.split(":", 1)[1].strip())
            elif line == "proposals:":
                continue
            elif re.match(r"^  [^ ].*:\s*$", line):
                # "  <uid>:"
                cur_uid = line.strip().rstrip(":")
                proposals[cur_uid] = {}
            elif re.match(r"^    \w", line) and cur_uid is not None:
                # "    key: value"
                k, _, v = line.strip().partition(":")
                proposals[cur_uid][k.strip()] = _unquote(v.strip())
    return {
        "diagram": diagram,
        "generated_from": generated_from,
        "proposals": proposals,
    }


def _unquote(s: str) -> str:
    """Reverse bpmn_to_tasks._yaml_q double-quoting."""
    s = s.strip()
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        return s[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    return s


def load_manifests(stage_dir: str) -> list[dict]:
    """Load every <stage_dir>/<stem>/manifest.yaml. Returns a list of manifest dicts,
    each augmented with `stem` and `dir`. Missing stage dir → empty list (not an error:
    nothing has been staged yet)."""
    out: list[dict] = []
    if not os.path.isdir(stage_dir):
        return out
    for stem in sorted(os.listdir(stage_dir)):
        d = os.path.join(stage_dir, stem)
        mpath = os.path.join(d, "manifest.yaml")
        if os.path.isfile(mpath):
            m = _parse_manifest(mpath)
            m["stem"] = stem
            m["dir"] = d
            out.append(m)
    return out


# ── Existing-task scan (rebuild the uid↔T-ID cache from frontmatter) ──────────

_UID_RE = re.compile(r"^\s*uid:\s*(\S+)\s*$", re.MULTILINE)
_SHA_RE = re.compile(r"^\s*source_bpmn_sha:\s*(\S+)\s*$", re.MULTILINE)
_STATUS_RE = re.compile(r"^status:\s*(\S+)\s*$", re.MULTILINE)
_ID_RE = re.compile(r"^id:\s*(\S+)\s*$", re.MULTILINE)
_TICKED_AC_RE = re.compile(r"^\s*-\s*\[x\]", re.MULTILINE | re.IGNORECASE)


def _tasks_dirs() -> list[str]:
    """Resolve .tasks/{active,completed} using the framework's canonical resolution
    (lib/paths.sh:69): TASKS_DIR env > PROJECT_ROOT/.tasks > ./.tasks. Sharing the
    same var as create-task.sh keeps the scan and the writer pointed at one tree."""
    root = (
        os.environ.get("TASKS_DIR")
        or os.path.join(os.environ.get("PROJECT_ROOT", "."), ".tasks")
    )
    return [os.path.join(root, "active"), os.path.join(root, "completed")]


def scan_existing() -> dict[str, dict]:
    """Scan .tasks/{active,completed} for promoted tasks (those carrying an
    `aef_provenance:` block). Returns uid -> {tid, path, status, sha, human_touched}.

    This IS the derived uid↔T-ID cache (832 §3b) — rebuilt every run from the
    authoritative frontmatter, so it can never drift from disk."""
    found: dict[str, dict] = {}
    for d in _tasks_dirs():
        if not os.path.isdir(d):
            continue
        for fname in os.listdir(d):
            if not (fname.startswith("T-") and fname.endswith(".md")):
                continue
            path = os.path.join(d, fname)
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
            if "aef_provenance:" not in text:
                continue
            um = _UID_RE.search(text)
            if not um:
                continue
            uid = um.group(1)
            sm = _SHA_RE.search(text)
            stm = _STATUS_RE.search(text)
            idm = _ID_RE.search(text)
            status = stm.group(1) if stm else "?"
            human_touched = status != "captured" or bool(_TICKED_AC_RE.search(text))
            found[uid] = {
                "tid": idm.group(1) if idm else "?",
                "path": path,
                "status": status,
                "sha": sm.group(1) if sm else "",
                "human_touched": human_touched,
            }
    return found


# ── Reconcile ────────────────────────────────────────────────────────────────

# action constants
NEW = "new"
UNCHANGED = "unchanged"
# T-2543 (Dimitri bar leg 3): changed → propose-not-clobber. A changed proposal is NEVER
# auto-written — no silent provenance refresh, regardless of captured/touched state. The
# materialized task is flagged for human review. (Supersedes T-2542's changed+captured→refresh.)
CHANGED_PROPOSE = "changed-propose"
ORPHAN = "orphan"


def reconcile(
    manifests: list[dict], existing: dict[str, dict], only_uid: str | None
) -> list[dict]:
    """Compute the action per uid. Returns a list of action dicts:
    {uid, action, diagram, source_diagram, sha, entry, existing}."""
    actions: list[dict] = []
    seen_uids: set[str] = set()

    for m in manifests:
        for uid, entry in m["proposals"].items():
            if only_uid and uid != only_uid:
                continue
            seen_uids.add(uid)
            sha = str(entry.get("sha", ""))
            ex = existing.get(uid)
            if ex is None:
                action = NEW
            elif ex["sha"] == sha:
                action = UNCHANGED
            else:
                # changed: propose-not-clobber (never auto-write), regardless of touched state
                action = CHANGED_PROPOSE
            actions.append(
                {
                    "uid": uid,
                    "action": action,
                    "source_diagram": m["diagram"],
                    "sha": sha,
                    "entry": entry,
                    "existing": ex,
                }
            )

    # Orphans: uids present in .tasks/ but absent from every manifest. Only flagged
    # in an `all` sweep (a single-uid promote can't know the full manifest set).
    if only_uid is None:
        manifest_uids = {u for m in manifests for u in m["proposals"]}
        for uid, ex in existing.items():
            if uid not in manifest_uids:
                actions.append(
                    {
                        "uid": uid,
                        "action": ORPHAN,
                        "source_diagram": "",
                        "sha": ex["sha"],
                        "entry": {},
                        "existing": ex,
                    }
                )
    return actions


# ── Write path (delegates to fw task create — the gated writer) ───────────────


def _fw() -> str:
    """Path to the fw shim. FW_BIN override, else bin/fw relative to repo root."""
    return os.environ.get("FW_BIN") or os.path.join("bin", "fw")


def _iso_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _audit_path() -> str:
    """Persistent materialization audit log (T-2543, Dimitri bar leg 2): every --write
    create leaves a traceable line — no silent .tasks/ writes."""
    root = os.environ.get("PROJECT_ROOT", ".")
    return os.path.join(root, ".context", "working", ".bpmn-promote-audit.jsonl")


def _audit(uid: str, task_id: str, sha: str, action: str, source_diagram: str) -> None:
    """Append one JSON line per materialization. Best-effort but never silent: a write
    that can't be audited raises rather than proceeding un-logged."""
    import json

    path = _audit_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    row = {
        "ts": _iso_now(),
        "uid": uid,
        "task_id": task_id,
        "sha": sha,
        "action": action,
        "source_diagram": source_diagram,
    }
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, sort_keys=True) + "\n")


def create_via_gate(entry: dict) -> tuple[str, str]:
    """Delegate to `fw task create` with un-overridable owner:human + captured.

    Returns (task_id, filepath) parsed from create-task.sh success output. Raises
    RuntimeError on failure. owner/status are hard-coded here — proposal content
    can never override them (G2/G3)."""
    name = entry.get("name", "(unnamed BPMN proposal)")
    wtype = entry.get("workflow_type", "build")
    horizon = entry.get("horizon", "now")
    cmd = [
        _fw(),
        "task",
        "create",
        "--name",
        name,
        "--description",
        f"Promoted from BPMN proposal (fw bpmn promote). See aef_provenance for source.",
        "--type",
        wtype,
        "--owner",
        "human",  # un-overridable (G2)
        "--horizon",
        horizon,
        # NOTE: no --start → status defaults to captured (G2). Never pass --start.
    ]
    # T-2549: inception nodes hit the T-2204 recommendation-completeness gate
    # (fires under CLAUDECODE=1) — `fw task create --type inception` refuses without
    # a recommendation. A freshly-promoted inception is a captured, owner:human task
    # the human has not yet explored, so DEFER is the honest state (evidence gap:
    # human go/no-go pending), matching the T-2208 cron backstop's DEFER stub. Inject
    # it for inception ONLY — build/test/other types must not carry a recommendation.
    if wtype == "inception":
        cmd += [
            "--recommendation",
            "DEFER",
            "--rationale",
            "Promoted from BPMN workflow diagram (fw bpmn promote); human go/no-go pending.",
        ]
    # T-2543: mark this create as promote-origin so create-task.sh's GATE enforces
    # owner:human + captured (Dimitri sovereignty bar). Defense-in-depth: promote still
    # passes owner:human above, but the gate is the backstop — a caller bug is refused,
    # not silently written.
    env = dict(os.environ, FW_TASK_ORIGIN="bpmn-promote")
    proc = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if proc.returncode != 0:
        raise RuntimeError(
            f"fw task create failed (rc={proc.returncode}): {proc.stderr.strip() or proc.stdout.strip()}"
        )
    tid_m = re.search(r"^ID:\s*(\S+)", proc.stdout, re.MULTILINE)
    file_m = re.search(r"^File:\s*(\S+)", proc.stdout, re.MULTILINE)
    if not (tid_m and file_m):
        raise RuntimeError(f"could not parse task id/file from create output:\n{proc.stdout}")
    return tid_m.group(1), file_m.group(1)


def stamp_provenance(path: str, uid: str, source_diagram: str, sha: str) -> None:
    """Inject an `aef_provenance:` block into the task's frontmatter, immediately
    before the closing `---`. Idempotent: a re-stamp replaces an existing block.

    832 §3b: this block is the authoritative uid↔T-ID join record."""
    with open(path, encoding="utf-8") as fh:
        text = fh.read()

    block = (
        "aef_provenance:\n"
        f"  uid: {uid}\n"
        f"  source_diagram: {source_diagram}\n"
        f"  source_bpmn_sha: {sha}\n"
        f"  promoted_at: {_iso_now()}\n"
    )

    # Remove any prior block (idempotent refresh).
    text = re.sub(
        r"^aef_provenance:\n(?:  .*\n)*", "", text, count=1, flags=re.MULTILINE
    )

    # Insert before the closing frontmatter fence (the 2nd '---').
    fences = [m.start() for m in re.finditer(r"^---\s*$", text, re.MULTILINE)]
    if len(fences) < 2:
        raise RuntimeError(f"{path}: no frontmatter fence to stamp provenance into")
    insert_at = fences[1]
    text = text[:insert_at] + block + text[insert_at:]

    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


# ── Orchestration ────────────────────────────────────────────────────────────


def apply_actions(actions: list[dict], write: bool) -> list[str]:
    """Execute (write=True) or preview (write=False) each action. Returns human-readable
    report lines. NEW/CHANGED-REFRESH mutate under --write; UNCHANGED/CHANGED-REFUSE/ORPHAN
    never write."""
    lines: list[str] = []
    for a in actions:
        uid, action = a["uid"], a["action"]
        ex = a["existing"]
        if action == NEW:
            if write:
                tid, fpath = create_via_gate(a["entry"])
                stamp_provenance(fpath, uid, a["source_diagram"], a["sha"])
                _audit(uid, tid, a["sha"], "created", a["source_diagram"])
                lines.append(f"  [created]  {uid} -> {tid}  (owner:human, captured)  {fpath}")
            else:
                lines.append(f"  [would-create]  {uid}  (owner:human, captured)")
        elif action == UNCHANGED:
            lines.append(f"  [no-op]    {uid} -> {ex['tid']}  (sha unchanged)")
        elif action == CHANGED_PROPOSE:
            # T-2543 (Dimitri bar leg 3): never clobber a materialized task. A changed
            # proposal is flagged for human review — no write, in dry-run OR --write.
            touched = "human-touched" if ex["human_touched"] else "captured/untouched"
            lines.append(
                f"  [PROPOSE]  {uid} -> {ex['tid']}  (sha changed, status={ex['status']}, {touched}) — "
                f"NOT clobbered; review the proposal diff and re-materialize manually if intended"
            )
        elif action == ORPHAN:
            lines.append(
                f"  [ORPHAN]   {uid} -> {ex['tid']}  (no longer in any manifest) — "
                f"NOT auto-deleted; flag for human review"
            )
    return lines


def main(argv: list[str]) -> int:
    args = argv[1:]
    write = False
    stage_dir_arg: str | None = None
    positional: list[str] = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--write":
            write = True
            i += 1
        elif a == "--stage-dir":
            stage_dir_arg = args[i + 1] if i + 1 < len(args) else None
            i += 2
        elif a in ("-h", "--help"):
            sys.stdout.write(__doc__ or "")
            return 0
        else:
            positional.append(a)
            i += 1

    if len(positional) != 1:
        sys.stderr.write(
            "usage: bpmn_promote.py <uid|all> [--write] [--stage-dir DIR]\n"
            "  dry-run is the default; --write executes (delegates to fw task create)\n"
        )
        return 2

    target = positional[0]
    only_uid = None if target == "all" else target

    stage_dir = _stage_dir(stage_dir_arg)
    manifests = load_manifests(stage_dir)
    if not manifests:
        sys.stderr.write(
            f"no staged proposals under {stage_dir} — run `fw bpmn compile --write <file.bpmn>` first\n"
        )
        return 1

    existing = scan_existing()
    actions = reconcile(manifests, existing, only_uid)

    if only_uid is not None and not any(x["uid"] == only_uid for x in actions):
        sys.stderr.write(f"uid {only_uid!r} not found in any staged manifest under {stage_dir}\n")
        return 1

    mode = "WRITE" if write else "DRY-RUN (use --write to execute)"
    print(f"fw bpmn promote — {mode}")
    print(f"  stage-dir: {stage_dir}")
    print(f"  target:    {target}")
    print("")
    for line in apply_actions(actions, write):
        print(line)

    # A propose (changed-but-not-clobbered) is a non-fatal signal that human review is
    # needed — surface it in the exit code so callers/CI can gate on it, but only under
    # --write (dry-run is always advisory).
    proposed = any(x["action"] == CHANGED_PROPOSE for x in actions)
    if write and proposed:
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
