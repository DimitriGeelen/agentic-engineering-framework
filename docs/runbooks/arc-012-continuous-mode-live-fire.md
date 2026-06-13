# Runbook: arc-012 Continuous-Mode Live-Fire Test

**Purpose:** run the continuous-run loop end-to-end and observe the
`headline_mechanic` firing — an agent that crosses the context-budget threshold
*without operator relay*, self-checkpoints, hands over, auto-restarts via
`claude-fw`, resumes with its directive re-injected, and repeats across multiple
cycles bounded by a tier-ceiling.

This is the one junction that cannot be self-tested by an agent: the live
`claude-fw` process restart needs an interactive session launched through the
wrapper. The automated parts of the loop are already covered by
`tests/integration/continuous_loop.bats` (resume→inject leg, T-2368) and
`tests/unit/test_inject_next_directive.py` (40 unit tests). **This runbook covers
the live restart that closes the gap** — and the operator's run of it is the
demo artefact `fw arc close continuous-run` requires (G-062).

Arc: `arc-012` (`continuous-run`). Anchor: `T-2158`. Slices: S0–S5.

---

## Prerequisites

1. **Launched via the wrapper.** The auto-restart only happens if the session
   runs under `claude-fw` (not plain `claude`). The wrapper watches for
   `.context/working/.restart-requested` on exit and relaunches `claude -c`.
2. **`claude-fw` on PATH.** Verify:
   ```
   cd /opt/999-Agentic-Engineering-Framework && command -v claude-fw && echo OK
   ```
3. **Run in an INTERACTIVE terminal — NOT a background job.** A background-job
   harness manages its own compaction (the transcript accrues multiple
   `compact_boundary` markers and can end on one, so the gauge legitimately reads
   ~0), and its process tree is not the plain `claude-fw → claude` lifecycle the
   restart watchdog expects. The live-fire must be an interactive `claude-fw`
   session you launched yourself in a normal terminal.
4. **Deployed-fix prerequisites (these make the lowered-window trigger actually
   fire).** The live-fire silently no-ops without them:
   - **T-2377** — the budget gauge reads the hook's stdin `transcript_path`. Before
     this fix the gauge was blind in any session whose cwd ≠ launch cwd (every git
     worktree, every background job), so critical was never detected. Deployed to
     master (`6c43bd5f0`).
   - **T-2376** — the `startup` SessionStart matcher is wired in `.claude/settings.json`.
     The auto-restart's `claude -c` emits source `startup` (not `resume`); without the
     matcher the loop restarts but never re-injects the directive / advances the counter.
     Verify: `grep -q '"matcher": "startup"' .claude/settings.json && echo OK`.
5. **Clean-ish git state.** The auto-handover commits and pushes. Run from a
   branch you're happy to receive handover commits on.
6. **Know the safety rails** (from the auto-restart design, T-179):
   - Restart signal has a **5-minute TTL** (stale signals are ignored).
   - Max **5 consecutive** auto-restarts, then the wrapper stops.
   - **3-second cancel window** before each restart (Ctrl-C to abort).
   - Opt out entirely with `claude-fw --no-restart`.
7. **Quiet repo — no OTHER `claude-fw` wrappers running on this repo** (OBS-075,
   discovered in the T-2381 controlled live-fire). The loop's coordination files
   are **repo-global, not per-session**: `.context/working/.restart-requested`,
   `.tool-counter`, and `.budget-status` are shared by every session on the repo.
   So when the gauge writes `.restart-requested`, the terminator in **every**
   running `claude-fw` wrapper sees the same "fresh" signal and SIGTERMs its claude
   child — restarting unrelated sessions, not just yours. Before a live-fire,
   confirm yours is the only wrapper:
   ```
   ps -eo pid,cmd | grep '[b]in/claude-fw'
   ```
   Expected: only the wrapper(s) of your own live-fire session. If you see others
   (e.g. other terminals or background jobs running `claude-fw` on this repo),
   either stop them first or run the live-fire on an isolated clone/worktree of the
   repo. (A per-session signal namespace would lift this constraint — tracked as a
   possible follow-up; today the file is global.)

---

## How the lowered-window trigger works

`checkpoint.sh` reads real token usage from the session transcript and fires the
critical auto-handover at:

```
TOKEN_CRITICAL = CONTEXT_WINDOW × 95%
```

`CONTEXT_WINDOW` defaults to 300000 but is overridable via the `FW_CONTEXT_WINDOW`
env var (`agents/context/checkpoint.sh:31`). So instead of burning ~285K tokens
to reach critical, set a small window and critical fires after a short session:

```
FW_CONTEXT_WINDOW=20000   →   critical at ~19000 tokens   →   a few minutes of work
```

Everything downstream (auto-handover, restart signal, directive fold,
post-resume inject, iteration counter) is identical to a real 300K run — only the
threshold moves.

---

## Step-by-step

All commands assume you start from the framework repo root. Run them on **one
line** as written (copy-paste safe).

### 1. Enable continuous-mode and set caps

Write the unified config (`enabled: true`, a small cap, a tier-ceiling):

```
cd /opt/999-Agentic-Engineering-Framework && cat > .context/working/.continuous-mode.yaml <<'EOF'
enabled: true
max_iterations: 3
tier_ceiling: 1
expires_after_seconds: 86400
current_iteration: 0
EOF
```

### 2. File a directive for the loop to pick up on resume

The `directive:` text is what each resumed cycle surfaces. Reference a real
next task with `next_task:` to exercise the tier-ceiling (see step 5).

```
cd /opt/999-Agentic-Engineering-Framework && cat > .context/working/.next-directive.yaml <<'EOF'
directive: |
  Continuous-mode live-fire test. Each cycle: append one short line to
  /tmp/arc012-livefire.log with the current iteration, then commit nothing
  and let the budget climb again.
filed_by: operator-livefire
filed_at: 2026-06-13T00:00:00Z
expires_at: 2099-01-01T00:00:00Z
EOF
```

### 3. Launch through the wrapper with a small window

```
cd /opt/999-Agentic-Engineering-Framework && FW_CONTEXT_WINDOW=20000 claude-fw
```

### 3a. Verify the gauge can see tokens (do this FIRST, before relying on the loop)

This is the single most common silent-failure point (the T-2377 class). Inside the
session, after a couple of interactions, confirm the gauge is reading real tokens —
**not** `unavailable`:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw hook checkpoint status
```

Expected: `Context tokens: NNNNN (~XX% of context window)` with a **nonzero, climbing**
number. Cross-check the hook-written cache (authoritative — the real PreToolUse gate
writes it from the stdin transcript_path, correct even in edge cases):

```
cd /opt/999-Agentic-Engineering-Framework && cat .context/working/.budget-status
```

Expected: `"tokens"` is a nonzero number trending up toward your `FW_CONTEXT_WINDOW`.

- **If it says `unavailable` / stays `0`:** the gauge isn't reading the transcript.
  Most likely you're in a worktree or background job (see Prerequisite 3), or the
  T-2377 fix isn't deployed in this checkout (see Prerequisite 4). **Stop and fix
  before continuing** — otherwise critical will never fire and the loop will never arm.

### 4. Work a short session until critical fires

Inside the session, do light work (read a few files, ask a question). Watch for
the stderr banner:

```
Session wrapping up: NNNNN tokens (~9X% of context window).
AUTO-HANDOVER: Triggering handover...
AUTO-RESTART: Signal written — wrapper will auto-restart on exit.
```

When the session exits, the wrapper prints its 3-second cancel countdown and then
relaunches `claude -c`. **Do not relay anything** — the point is that the loop
continues without you. The resumed session's `SessionStart` hook injects the
`## Next Directive (iteration N/3, tier_ceiling 1)` block automatically.

Let it cycle at least twice (iteration 1 → 2). The `expires_after_seconds` and
`max_iterations: 3` cap bound the run.

### 5. (Optional) demonstrate the bounded-autonomy ceiling

To see the tier-ceiling refusal (S5), point the directive's planned next action
at a task whose BVP `cost_estimate.blast_radius` exceeds `tier_ceiling`. Add a
`next_task:` line referencing such a task, e.g.:

```
cd /opt/999-Agentic-Engineering-Framework && printf 'next_task: T-XXXX\n' >> .context/working/.next-directive.yaml
```

On the next resume, instead of the directive you'll see:

```
## Next Directive — TIER CEILING EXCEEDED (T-2367)
Operator continuation required: the planned next action T-XXXX has
blast-radius B, which exceeds the configured tier_ceiling 1.
```

and `current_iteration` will **freeze** (not advance) — the loop pauses for your
sign-off rather than continuing autonomously. That freeze is the bounded-autonomy
ceiling working as designed.

---

## Expected observations

Check after the run:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw resume status
```
```
cd /opt/999-Agentic-Engineering-Framework && cat .context/working/.continuous-mode.yaml
```

You should see:

- `current_iteration` advanced by the number of cycles that completed (≥2).
- `last_source: resume` (or `compact` if you manually `/compact`'d).
- `last_resumed_at` updated to each cycle's timestamp.
- A handover committed per cycle (`git log` shows `... Session handover ...`).
- The `## Next Directive (iteration N/...)` block present in each resumed
  session's injected context.
- If you ran step 5: `last_terminated_reason` mentions the tier ceiling and the
  counter is frozen at the pre-breach value.

---

## Success criteria (mapped to the arc headline_mechanic)

The arc's `headline_mechanic` is:

> agent crosses the context-budget threshold without operator relay →
> checkpoint.sh fires self-trigger → handover + resume via claude-fw →
> operator observes multi-cycle continuous session whose iteration counter,
> directive, and bounded tier-ceiling are visible in `fw resume status`

The run PASSES when **all** hold:

1. **No operator relay** between cycles — you did nothing to continue the loop.
2. **≥2 iterations** — `current_iteration` advanced at least twice.
3. **Directive carried forward** — each resumed cycle surfaced the directive.
4. **Self-trigger** — checkpoint.sh fired the handover from budget pressure, not
   a manual `fw handover`.
5. **Bounded** — the tier-ceiling refusal (step 5) froze the loop, OR
   `max_iterations` terminated it with the LOOP TERMINATED notice.

Capture the terminal recording (or the per-cycle `.continuous-mode.yaml`
snapshots and the handover commit log) as the `--demo` artefact for closure:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc close continuous-run --demo <path-or-url>
```

(Closure is Sovereign — G-062; run from Watchtower `/arcs/continuous-run/close`.)

---

## Teardown

Restore normal operation:

```
cd /opt/999-Agentic-Engineering-Framework && cat > .context/working/.continuous-mode.yaml <<'EOF'
enabled: false
max_iterations: 10
tier_ceiling: 1
expires_after_seconds: 86400
current_iteration: 0
EOF
```
```
cd /opt/999-Agentic-Engineering-Framework && rm -f .context/working/.next-directive.yaml .context/working/.restart-requested
```

Drop the `FW_CONTEXT_WINDOW` override simply by launching without it next time
(it's an env var, not persisted). If you set it via `fw config set CONTEXT_WINDOW`,
reset with:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw config set CONTEXT_WINDOW 300000
```

---

## Troubleshooting

| Symptom | Likely cause | Check |
|---------|--------------|-------|
| Critical never fires (gauge says `unavailable` / tokens 0) | gauge can't find the transcript — worktree/bg-job (cwd ≠ launch cwd), or T-2377 fix not deployed | run step 3a; confirm interactive-not-bg-job (Prereq 3) and T-2377 deployed (Prereq 4); the gauge must read the hook's stdin `transcript_path` |
| Critical never fires (gauge reads real tokens but no banner) | window too high for the work done | lower `FW_CONTEXT_WINDOW`; do more interactions to climb past 95% |
| No auto-restart | launched via `claude`, not `claude-fw` | confirm the wrapper; check `.context/working/.restart-requested` was written |
| Restarts but directive/counter never advances | `startup` SessionStart matcher missing (T-2376) | `grep '"matcher": "startup"' .claude/settings.json` (Prereq 4) |
| Directive not surfaced | continuous-mode off, or no directive file | `enabled: true` in `.continuous-mode.yaml`; `.next-directive.yaml` present |
| Counter not advancing | ceiling breach freezing it (expected) | check `last_terminated_reason` for "tier ceiling" |
| Loop stops after a few cycles | `max_iterations` cap reached (expected) | LOOP TERMINATED notice; raise cap or reset counter |

---

## See also

**Per-link automated coverage** (everything except the live `claude -c` restart this
runbook covers — all four links of the loop are unit/integration tested):

- `tests/integration/budget_gauge_stdin_transcript.bats` — link #1: gauge reads stdin `transcript_path` (T-2377)
- `tests/integration/continuous_loop_critical_signal.bats` — link #2: critical → `.restart-requested` + directive fold (T-2378)
- `tests/integration/claude_fw_restart_terminator.bats` — link #3: terminator fires on the signal (T-2373)
- `tests/integration/continuous_loop_auto_restart_advance.bats` — link #4: restart → `startup` → advance (T-2376)
- `tests/integration/continuous_loop.bats` — resume→inject coverage (T-2368)

**Source:**

- `agents/context/checkpoint.sh` — critical trigger + restart signal + directive fold (T-2363 S1)
- `agents/context/post-compact-resume.sh` — resume-side directive inject (T-2364/T-2365 S2/S3)
- `agents/context/inject-next-directive.py` — iteration counter, caps, tier-ceiling (T-2367 S5)
- `.context/arcs/continuous-run.yaml` — arc definition + headline_mechanic
