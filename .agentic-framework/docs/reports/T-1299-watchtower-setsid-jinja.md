# T-1299 — Codify Watchtower restart semantics (setsid + Jinja cache)

**Source:** termlink T-1117 pickup (learning)
**Status:** GO (bounded codification)

## Pickup summary

Termlink captured two restart-semantics learnings during the T-1117..T-1121 UI
work:

1. **setsid required.** Restarting Watchtower from inside a Claude Code `Bash`
   tool invocation must use:
   ```
   setsid python3 -m web.app > log 2>&1 < /dev/null &
   ```
   Plain `nohup ... &` or `... & disown` do NOT survive — the new process
   inherits the harness session and dies when the parent shell command
   completes. Symptom: "running" echoed, then curl immediately returns
   "not running". Took ~4 failed restart attempts to diagnose on termlink.

2. **Jinja cache survives .pyc deletion.** Flask production-mode caches
   compiled Jinja2 templates in memory. Editing a `.html` file is NOT
   picked up until the Python process is fully killed. `find __pycache__ -delete`
   is NOT sufficient — the cache is in-memory, not on disk. Symptom: template
   change invisible; curl shows old HTML; only `pkill + setsid start` loads
   the new template.

Proposed codification: `fw watchtower start` wrapper that (a) uses `setsid`
when it detects `CLAUDECODE=1`, (b) always kills any process already bound
to the target port, (c) documents the in-memory Jinja cache behaviour in
`docs/watchtower.md` or similar.

## Investigation (10 min time-box)

### Is the learning already captured?

Grep `.context/project/learnings.yaml` and CLAUDE.md for "setsid" and "Jinja".

- `learnings.yaml`: no existing entry for setsid or Jinja cache survival.
- CLAUDE.md: no mention.
- Agent memory (MEMORY.md): already notes
  `Flask template caching — Without debug=True, templates are cached in
  memory on first load. Must restart server after editing templates.` —
  captures part 2 but not the setsid part and not as a framework-level learning.

So the `setsid` learning is net-new; the Jinja cache behaviour is documented
in agent memory but not in the project's `learnings.yaml`.

### Is the codification scope bounded?

Yes. The proposed `fw watchtower start` behaviour is:

- If `CLAUDECODE=1` → prepend `setsid` to the launch command
- Before launching, `ss -tlnp | grep :PORT` or `pgrep -f web.app` and `kill`
  any existing process
- Write the startup log path to a known location
- Return 0 on successful bind (confirmed by port check after 1-2s)

That's ~30–50 lines in a new `lib/watchtower-start.sh` or extending
`fw serve`. Reversible, testable (bats can fake CLAUDECODE + verify
setsid in the command path).

### Where would the command live?

`bin/fw serve` already exists. Extending it is preferable to a new
subcommand — keeps the surface area small. The extension would read
`$CLAUDECODE` and adjust launch behaviour accordingly.

## Recommendation: GO

- Concrete operator pain: 4 failed restart attempts, real debugging time
- Learnings are not yet codified as framework defaults (only in agent memory)
- Fix is bounded: extend `fw serve` (or the shell-level launch wrapper it
  invokes) with CLAUDECODE-aware setsid + pre-kill
- Reversible (feature flag via env if needed)
- Testable via bats (mock CLAUDECODE, assert command path contains setsid)

## Build plan (separate task, not this inception)

1. Find where `fw serve` currently launches the web app
2. Detect `${CLAUDECODE:-0}` — if set to 1, prepend `setsid`
3. Before launch, kill any process bound to the target port (`fuser -k
   -TERM TCP/$PORT` or portable equivalent); sleep 1s; confirm port free
4. Launch with redirection to log
5. Poll `curl -sf http://localhost:$PORT/health` for up to 10s; fail if not
   ready
6. Add L-???: capture both findings as explicit learnings
7. Bats: `tests/unit/watchtower_start.bats` — fake CLAUDECODE + grep command
   history for setsid; test port-kill path
8. `docs/watchtower.md`: add "Restart from Claude Code sessions" section
   documenting both behaviours

## Conditions for reconsideration

N/A — this is GO; the build task can be created by the next session.

## Decision trail

- Source pickup: termlink T-1117 (learning)
- Artifact: this file
- Recommendation: GO — build sibling to be created as T-1326 (naming TBD
  by next session's allocation)
