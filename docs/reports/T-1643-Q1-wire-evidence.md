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

## 2026-05-01T20:52Z — dispatch timeout (postscript)

The U-005 worker dispatched at 20:42 hit the default 600s watchdog at 20:52
with `exit 143` (SIGTERM) and an empty `result.md`. PTY output shows no
streaming text from `claude -p` at any point — `run.sh` invokes claude with
`--output-format text` which buffers until completion, so a session that's
killed mid-think loses everything.

Two findings:

1. **`fw termlink dispatch` default timeout (600s) is too short for
   substantial cross-repo engineering work.** Reading framework schema files,
   exploring an unfamiliar Rust codebase, editing the dispatch hub, adding a
   regression test, running `cargo check`, and committing all in one shot is
   genuinely 20-30 min of agent time. Dispatcher should pass `--timeout 1800`
   (or higher) for cross-repo build tasks. See L-339-companion below.

2. **`--output-format text` makes timeouts forensically opaque.** When the
   watchdog kills the session, there's no record of what the agent was
   working on. Streaming output (`stream-json`) would preserve the trail.
   Possible follow-up to `agents/termlink/run.sh.tmpl` — out of scope here.

The Q1 wire-level evidence above (canonical tags, schema correctly written
with the four orchestrator-aware fields) stands regardless — that was
captured at dispatch time, before the worker did any real work. The
substrate-half half of Q1 remains blocked on U-005, now also blocked on
"give the worker enough wall-clock to finish." Do not re-dispatch in this
session.

## 2026-05-01T23:28Z — second dispatch retry also timed out

Re-dispatched as `u005-meta-populate-2` with `--timeout 1800` (30 min — 3x
the first attempt). Same outcome: `exit 143` SIGTERM at the watchdog
boundary, `result.md` zero bytes, PTY shows only the bash invocation.
Claude process was confirmed alive at 5 minutes (PID 3073183, normal CPU
usage), confirming it wasn't stuck on auth/handshake — it was doing real
work that just couldn't fit in 30 minutes of wall-clock.

This is now characterized as a **structural blocker** for U-005, not a
sizing oversight. Two changes are needed before retry:

1. **`agents/termlink/run.sh.tmpl`** — switch `claude -p ... --output-format
   text` to `--output-format stream-json` so the watchdog kill at timeout
   leaves a forensic trail in `result.md` (currently empty after timeout,
   useless for diagnosing whether the work was 90% done or 10% done).
2. **Higher default `TERMLINK_WORKER_TIMEOUT`** (or a per-task-type
   override) — `30 min` is enough for a single-file edit + cargo check, but
   a real cross-repo build task with task-creation ceremony, exploration,
   edit, test, commit, and report needs 60-90 min budget.

Both changes are framework-side (`/opt/999-Agentic-Engineering-Framework`),
not /opt/termlink-side, so they unblock U-005 dispatch without depending on
the cross-repo work itself. Filed as the forward path; do not retry U-005
dispatch from this session.
