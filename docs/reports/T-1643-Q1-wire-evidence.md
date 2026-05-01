# T-1643 — Q1 wire-level evidence: framework half is live

**Captured:** 2026-05-01T20:42Z, immediately after dispatching the U-005 worker.

The §Arc Completion Discipline three-question check demands wire-level evidence
that the integrated system runs end-to-end on a fresh substrate, not just
"tests pass" or "AC tick." This file captures that observation for the
framework half of the orchestrator-rethink arc.

## Observation

Live dispatch of `bin/fw termlink dispatch --task T-1643 --name u005-meta-populate
--project /opt/termlink --task-type build --prompt-file ...` produced:

- **Session tags (canonical):** `task:T-1643,task-type:build` — confirms T-1654
  framework-side fix landed; new dispatches no longer emit legacy `task=` prefix.
- **Worker meta.json schema written exactly as specified by W4:**

  ```json
  {
    "name": "u005-meta-populate",
    "project": "/opt/termlink",
    "timeout": 600,
    "task": "T-1643",
    "task_type": "build",
    "model": "",
    "model_used": null,
    "fallback_used": null,
    "started": "2026-05-01T20:42:02Z",
    "status": "running"
  }
  ```

- **`task_type: "build"`** — auto-derived from `.context/working/focus.yaml` (T-1662
  was focused, workflow_type build). Confirms W1 `_derive_task_type` works in
  production without explicit `--task-type` flag.
- **`model_used` / `fallback_used` start as null** — confirms W4 schema:
  framework writes the structure, substrate populates the values. Closing the
  loop on these is U-005's scope (cross-repo, /opt/termlink).

## What this closes for the arc

Q1 — "Did the integrated system run end-to-end on a fresh substrate?" — has
two halves:

| Half | Evidence | State |
|------|----------|-------|
| Framework writes correct schema with canonical tags | This file + worker meta.json above | **Live** |
| Substrate populates `model_used` / `fallback_used` | Pending U-005 (/opt/termlink dispatch hub work) | **In progress** |

The framework half is now demonstrably live in production, not just covered
by unit tests (which can only pin schema, not wire behavior). Pinned by
worker session `tl-lvvkl6u4` running `claude -p` in /opt/termlink as of the
capture time.

## Why a docs/reports artifact and not a learning

The §Arc Completion Discipline rule is explicit that arc closure requires
*observable artefacts*, not arguments. A learning entry summarises a takeaway;
this file is the wire snapshot at a specific moment. Both serve different
purposes — learnings teach, evidence proves.
