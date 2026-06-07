# T-2201 — AEF pre-flight Claude CLI config before fw termlink dispatch

**Workflow:** inception
**Status:** started-work (research artifact, pre-decision)
**Origin:** T-2200 dispatch incident, 2026-06-04T07:24Z

## Why this artifact exists

C-001 inception discipline: the thinking trail IS the artifact. Conversations are ephemeral; this file persists. Updated incrementally as research lands.

## Incident summary (the data)

| Field | Value |
|---|---|
| Triggering task | T-2200 (`fan-dashboard-aef-setup` dispatch) |
| Dispatch command | `bin/fw termlink dispatch --task T-2200 --name fan-dashboard-aef-setup --project /opt/fan-dashboard --prompt-file ... --timeout 3600` |
| Worker session id | `tl-rbuxttlt` (first attempt), exited rc=1 in seconds |
| Spend before failure | tmux session, /tmp/tl-dispatch/<name>/ dir, prompt.md write, env.sh write, telemetry, worker.done event |
| Diagnostic surfaced | Only in worker stdout log; parent saw "Worker fan-dashboard-aef-setup finished (exit: 1)" |
| Actionable diagnostic location | `/tmp/tl-dispatch/<name>/<log>` — 3 file reads removed from the dispatch surface |
| Time to diagnose | ~3 minutes of agent forensics |

## The dispatch surface as it stands

`agents/termlink/termlink.sh::cmd_dispatch` (bin/fw termlink dispatch) flow:
1. Parse args (--task, --name, --project, --prompt[-file], --timeout, --model, --env, --tools, --worker-kind)
2. Resolve model via `_resolve_dispatch_model_and_fallback` (T-1669 route_cache)
3. Create worker dir under `$DISPATCH_DIR` (`/tmp/tl-dispatch/<name>`)
4. Write prompt.md, task, env.sh
5. tmux-spawn the worker via `run.sh`
6. Emit `worker.done` event

**Nowhere in this flow is `claude -p`'s configuration pre-flighted.** The first contact with `/root/.claude.json` is inside the spawned tmux session, after the dispatch surface has spent all of its setup cost.

## Root cause class

This is a **fail-late surface** in the sense of CLAUDE.md §Hypothesis-Driven Debugging. The actionable signal (config corruption) was produced; the framework just didn't put it in front of the agent. Adjacent classes already addressed:
- L-291 (toolchain build commands missing from Verification): same pattern — failure produced but not surfaced at the gate.
- L-364 (cron drift detection): failure produced but not surfaced at audit.

The fix shape from those: detect → refuse fast → name the specific bypass mechanism.

## Candidate solutions (working set, pre-grilling)

### A. In-place pre-flight in `cmd_dispatch` (line ~573)

Single python one-liner before tmux spawn:
```bash
if ! python3 -c "import json; json.load(open('/root/.claude.json'))" 2>/dev/null; then
    die "Claude CLI config /root/.claude.json failed to parse — worker would die. Restore from /root/.claude/backups/ or recreate via 'claude' interactive setup."
fi
```
Pros: minimal blast radius (one function), no new helper.
Cons: dispatch-surface-only; doesn't cover `fw reviewer --dispatch` and `fw peer subscribe` responder.

### B. Shared helper `lib/claude_cli_preflight.{sh,py}`

All claude-p spawn paths call `preflight_claude_cli` before any spend. Returns 0/non-0 with stderr diagnostic.
Pros: covers all three known spawn surfaces; future spawn surfaces inherit automatically.
Cons: larger surface — needs careful path-isolation handling (the helper reads `/root/.claude.json` which is outside any project root; must NOT be invoked from inside a project's task-gate-blocked context).

### C. `fw doctor` advisory only

Periodic check that surfaces stale-config WARN. No gating on dispatch.
Pros: no behaviour change at dispatch time; cheapest to ship.
Cons: doesn't help an agent who tries to dispatch right now — operator must read fw doctor proactively.

### D. Hybrid: B + C

Shared helper for blocking pre-flight at dispatch time, plus doctor check for "have you noticed your config is corrupted" proactive surface.
Pros: most defensive in depth.
Cons: doubles the surface area to maintain.

## Provisional recommendation (pre-decision)

Candidate **B** with a thin shell helper invoked from cmd_dispatch + reviewer dispatch + peer subscriber. Defer the doctor check (C) to a sibling task — separate concern, separate cadence.

## Dialogue Log

### 2026-06-04 — Operator question on config layering
- **Operator asked:** "regarding teh config, we dont want afull config right, beliewe we haver root as dummy then in project ./projectroot/Aef as master and and /project root ass delta , prjedtc specific to be merged with ./projectroot/Aef on update / upgrade ?"
- **Agent reply:** Distinguished two layers — `/root/.claude.json` is Claude Code CLI's OWN state (OAuth tokens, MCP registry), NOT the AEF vendoring model the operator described (master at `<project>/.agentic-framework/`, delta at `<project>/`, merged on `fw upgrade`). The two are independent. The dummy-on-root model doesn't apply to `/root/.claude.json` because the CLI needs valid auth + MCP registry from that file to start.
- **Outcome:** Operator said "ok lets execute". Inception filed (this artifact).

### Future entries land below
- (Dialogue continues here as research/decisions land.)

## Open work
- Test A1 (does `claude -p` always read /root/.claude.json?) via `strace` spike — 2 min.
- Test A2 (does python json.load catch all corruption modes?) via 3-mode corruption fuzzing — 5 min.
- Test A3 (boundary-hook posture on read-only /root/.claude.json inspection) via `bin/fw` boundary-hook trace — 2 min.
- Grill the IW-1..IW-4 questions before recommendation.

## Cross-refs
- T-2200 — the burning incident
- L-291 (analogous fail-late class)
- L-364 (analogous fail-late class)
- L-456 (this session's bats PROJECT_ROOT-leak learning — similar env-leak class)
- [[project_t2185_gauge_closure_surface]] (the gauge-driven gap closure surface — shape this inception's fix can reuse)
